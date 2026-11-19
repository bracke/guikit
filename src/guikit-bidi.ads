with Ada.Containers.Vectors;

--  Right-to-left text: the Unicode Bidirectional Algorithm (UAX #9) for one
--  paragraph, Arabic joining (UAX #9's companion, ArabicShaping.txt) through
--  the presentation forms fonts carry, and the mapping between where a
--  character is stored and where it is drawn.
--
--  Each text guikit draws is one paragraph whose direction is that of its
--  first strong character, so a Hebrew name reads right to left and a Latin
--  sentence with a Hebrew word in it stays left to right. The text is laid
--  out in display cells exactly as before -- only their order and, for
--  Arabic, the glyph each one shows change -- so every width already measured
--  with Guikit.Utf8 still holds.
package Guikit.Bidi is

   type Bidi_Class is
     (L, R, AL, EN, ES, ET, AN, CS, NSM, BN, B, S, WS, ON,
      LRE, LRO, RLE, RLO, PDF, LRI, RLI, FSI, PDI);

   --  The Bidi_Class property of a code point.
   --
   --  @param Codepoint A Unicode code point.
   --  @return Its bidi class.
   function Class_Of (Codepoint : Natural) return Bidi_Class;

   --  The Bidi_Mirroring_Glyph of a code point: ')' for '(' and so on.
   --
   --  @param Codepoint A Unicode code point.
   --  @return Its mirrored counterpart, or Codepoint itself when it has none.
   function Mirror_Of (Codepoint : Natural) return Natural;

   type Paragraph_Direction is (Auto, Left_To_Right, Right_To_Left);

   type Codepoint_Array is array (Positive range <>) of Natural;
   type Level_Array is array (Positive range <>) of Natural;
   type Index_Array is array (Positive range <>) of Positive;

   --  The level of a character rule X9 removes (embedding and override
   --  controls, boundary neutrals): it is not displayed.
   Removed : constant Natural := Natural'Last;

   --  Resolve the embedding level of every character of one paragraph: rules
   --  P2 to I2 and L1 of UAX #9.
   --
   --  @param Text The paragraph's code points, in stored order.
   --  @param Direction Auto takes the first strong character's (rules P2, P3).
   --  @param Levels Each character's level, or Removed.
   --  @param Paragraph_Level 0 for a left-to-right paragraph, 1 for right-to-left.
   procedure Resolve_Levels
     (Text            : Codepoint_Array;
      Direction       : Paragraph_Direction;
      Levels          : out Level_Array;
      Paragraph_Level : out Natural)
     with Pre => Levels'First = Text'First and then Levels'Length = Text'Length;

   --  The display order of a line (rule L2): the indices of Levels that are
   --  not Removed, left to right.
   --
   --  @param Levels The resolved levels of the line.
   --  @return Indices into Levels in the order they are drawn.
   function Visual_Order (Levels : Level_Array) return Index_Array;

   --  Whether Content holds anything that draws in another order or shape
   --  than stored: a right-to-left or Arabic letter, an Arabic digit, or a
   --  right-to-left control. Text without one draws as it always has.
   --
   --  @param Content UTF-8 text.
   --  @return True when Content needs Lay_Out.
   function Needs_Layout (Content : String) return Boolean;

   --  One drawn cell group: a base character with the marks on it. Byte
   --  offsets are zero-based from Content'First.
   type Cluster is record
      --  Where the cluster is stored: Length bytes from First.
      First, Length : Natural := 0;
      --  How many display cells it takes.
      Units : Natural := 0;
      --  It is part of a right-to-left run.
      Right_To_Left : Boolean := False;
      --  Its glyphs: Glyph_Count code points from Glyph_First in Line.Glyphs.
      Glyph_First, Glyph_Count : Natural := 0;
      --  Its first glyph is a lam-alef ligature drawn across both letters' cells.
      Ligature : Boolean := False;
   end record;

   package Cluster_Vectors is new Ada.Containers.Vectors (Positive, Cluster);
   package Codepoint_Vectors is new Ada.Containers.Vectors (Positive, Natural);

   --  A paragraph laid out for drawing.
   type Line is record
      Right_To_Left : Boolean := False;
      --  Left to right as drawn.
      Clusters : Cluster_Vectors.Vector;
      --  The code points to draw, shaped and mirrored; Cluster.Glyph_First
      --  indexes this from 1.
      Glyphs : Codepoint_Vectors.Vector;
   end record;

   --  The Arabic presentation forms (U+FB50 .. U+FDFF, U+FE70 .. U+FEFF)
   --  and the code points between them, which are answered for alike.
   subtype Form_Codepoint is Natural range 16#FB50# .. 16#FEFF#;

   --  Which code points of Form_Codepoint a font chain draws.
   type Form_Coverage is array (Form_Codepoint) of Boolean
     with Pack;

   --  Whether a code point is an Arabic presentation form, the only code
   --  points whose drawability changes how text is laid out.
   --
   --  @param Codepoint A Unicode code point.
   --  @return True for U+FB50 .. U+FDFF and U+FE70 .. U+FEFF.
   function Is_Presentation_Form (Codepoint : Natural) return Boolean is
     (Codepoint in 16#FB50# .. 16#FDFF# | 16#FE70# .. 16#FEFF#);

   --  Record which presentation forms the text is drawn with, for
   --  Can_Draw_Form and so for every layout given no Has_Glyph.
   --  Guikit.Text.Initialize records its renderer's fonts here when they
   --  load, and every form as drawable when a load fails. It may be called
   --  from any task.
   --
   --  @param Coverage Whether each presentation form is drawn; entries for
   --  code points that are not forms are ignored.
   procedure Set_Drawable_Forms (Coverage : Form_Coverage);

   --  Whether the fonts last recorded (Set_Drawable_Forms) draw Codepoint:
   --  for a presentation form, what those fonts answer; for any other code
   --  point, and before anything was recorded, True. With several text
   --  renderers it answers for the one whose Initialize ran last. It may be
   --  called from any task.
   --
   --  @param Codepoint A Unicode code point.
   --  @return Whether the recorded fonts draw it, for a presentation form.
   function Can_Draw_Form (Codepoint : Natural) return Boolean;

   --  Lay Content out for drawing: shape Arabic letters, resolve levels,
   --  mirror what a right-to-left run mirrors, and put the clusters in
   --  display order.
   --
   --  @param Content UTF-8 text, one paragraph.
   --  @param Has_Glyph Whether the font can draw a code point; a presentation
   --  form it cannot draw is left as the plain letter. Null asks
   --  Can_Draw_Form -- the fonts Guikit.Text loaded -- so a caller laying
   --  out text drawn by Guikit.Text need not pass anything.
   --  @return The laid-out line.
   function Lay_Out
     (Content   : String;
      Has_Glyph : access function (Codepoint : Natural) return Boolean := null)
      return Line;

   --  The display column at which to draw a caret standing Cursor bytes into
   --  Content: before the character it precedes -- on its right side when
   --  that character is right-to-left -- or, at the end, after the last one.
   --  Equal to Guikit.Utf8.Display_Units_Before for text that needs no layout.
   --  The column counts from the start of the drawn text; a frame mirrored
   --  for a right-to-left layout counts it from the other end
   --  (Guikit.Mirroring.Reflect_Column, applied by Guikit.Text_Fields).
   --
   --  A right-to-left paragraph wider than Columns is drawn without its end,
   --  on the left (see Guikit.Text.Build_Glyphs): the columns are counted as
   --  drawn, from what is left.
   --
   --  @param Content UTF-8 text, drawn from column 0.
   --  @param Cursor Byte offset into Content.
   --  @param Columns How many display cells the text is drawn in.
   --  @param Has_Glyph Whether the font can draw a code point, as Lay_Out
   --  takes it, so a lam-alef pair the font has no ligature for is two
   --  characters here too. Null asks Can_Draw_Form, which answers for the
   --  fonts Guikit.Text draws with.
   --  @return Display column of the caret.
   function Caret_Column
     (Content   : String;
      Cursor    : Natural;
      Columns   : Natural := Natural'Last;
      Has_Glyph : access function (Codepoint : Natural) return Boolean := null)
      return Natural;

   --  The byte offset a click at Half_Column half-cells from the start of
   --  the drawn Content puts the caret at: before the clicked character when
   --  the click is on the half of it that comes first in reading order, after
   --  it otherwise. The inverse of Caret_Column.
   --
   --  @param Content UTF-8 text, drawn from column 0.
   --  @param Half_Column Click position in half display cells.
   --  @param Columns How many display cells the text is drawn in, as for
   --  Caret_Column.
   --  @param Has_Glyph Whether the font can draw a code point, as for
   --  Caret_Column.
   --  @return Zero-based byte offset into Content.
   function Cursor_At_Half_Column
     (Content     : String;
      Half_Column : Natural;
      Columns     : Natural := Natural'Last;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null)
      return Natural;

   --  Where an arrow key moves a caret standing Cursor bytes into Content:
   --  to the next character boundary on the screen in the arrow's
   --  direction, not in reading order. In a right-to-left run the right
   --  arrow therefore steps back through the text. By_Word, it moves to the
   --  next word boundary in reading order, which runs leftward when the
   --  paragraph is right to left.
   --
   --  The caret stops are ordered by drawn column (Caret_Column) and, where
   --  two stops share a column -- at the seam between runs -- by byte offset,
   --  so every stop is reachable and the two arrows undo each other. The
   --  stops are where the laid-out clusters start, so a lam-alef ligature the
   --  font draws is stepped over whole. Text that needs no layout steps exactly as
   --  Guikit.Utf8.Editing does.
   --
   --  @param Content UTF-8 text.
   --  @param Cursor Zero-based byte offset of the caret.
   --  @param Rightward Whether the right arrow was pressed, not the left.
   --  @param By_Word Whether to step by word.
   --  @param Has_Glyph Whether the font can draw a code point, as for
   --  Caret_Column: a lam-alef pair drawn as two letters is two stops.
   --  @return The new zero-based byte offset; Cursor when nothing lies that way.
   function Caret_Step
     (Content   : String;
      Cursor    : Natural;
      Rightward : Boolean;
      By_Word   : Boolean := False;
      Has_Glyph : access function (Codepoint : Natural) return Boolean := null)
      return Natural;

   --  How many display cells a right-to-left Laid paragraph loses on the
   --  left when drawn in Columns cells; 0 when it fits or is left to right.
   --
   --  @param Laid A laid-out line.
   --  @param Columns How many display cells it is drawn in.
   --  @return The cells cut off on the left.
   function Cut_Columns (Laid : Line; Columns : Natural) return Natural;

private

   --  Whether a level is right to left.
   --
   --  @param Level An embedding level.
   --  @return True for an odd level.
   function Is_Odd (Level : Natural) return Boolean is (Level mod 2 = 1);

end Guikit.Bidi;
