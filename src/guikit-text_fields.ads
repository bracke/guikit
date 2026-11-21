with Guikit.Draw;
with Guikit.Mirroring;

--  A single-line text field's view of its text: how much of the start is
--  scrolled off so the caret stays inside the field, where the caret is
--  drawn, and which byte offset a click puts the caret at. The one rule
--  every field shares -- the command palette's query, the item grid's
--  rename field, the settings panel's text values, and an application's
--  own fields -- so drawing and click-to-caret mapping agree.
--
--  Positions are pixels from the field's left edge in the frame as drawn
--  before mirroring. In a mirrored frame (Mirrored, which defaults to
--  Guikit.Mirroring.Mirrored_Layout) the text keeps its reading order and
--  stands against the field's other edge, so a caret and a click are
--  counted back from the end of the drawn text
--  (Guikit.Mirroring.Reflect_Column) -- the whole characters that fit, as
--  Guikit.Text.Build_Glyphs sizes a box aligned to its end -- and the
--  caret's rectangle is placed so that, once mirrored, it starts where the
--  boundary it marks is drawn, as it does in an unmirrored frame.
--
--  Text that needs bidi layout (Guikit.Bidi.Needs_Layout) is not scrolled by
--  dropping leading bytes -- what is left would be laid out differently --
--  but by display cells of the whole laid-out text: the field draws all of
--  it with View.Cut_Columns cells cut off its left
--  (Guikit.Draw.Text_Command.Cut_Columns), and a click is mapped back with
--  the same cut.
package Guikit.Text_Fields is

   type View is record
      --  Leading bytes of the text not drawn: whole characters, at least
      --  the columns Guikit.Layout.Input_Scroll_Columns asks for. Always 0
      --  for text that needs bidi layout.
      Skip_Bytes  : Natural := 0;
      --  Where the caret is drawn, in pixels from the field's left edge,
      --  kept inside the field.
      Caret_X     : Natural := 0;
      --  For text that needs bidi layout, the display cells of the laid-out
      --  text cut off its left so the caret is inside the field: the field's
      --  text command carries it (Guikit.Draw.Text_Command.Cut_Columns) and
      --  Cursor_At takes it back. Guikit.Draw.Auto_Cut for any other text,
      --  which Skip_Bytes scrolls.
      Cut_Columns : Natural := Guikit.Draw.Auto_Cut;
   end record;

   --  Where the caret Cursor bytes into Text is drawn when the text is
   --  drawn from the field's start, unscrolled: where the drawn text has it
   --  (Guikit.Bidi.Caret_Column: right-to-left runs included), reflected in
   --  a mirrored frame, and kept inside the field.
   --
   --  @param Text UTF-8 text as drawn in the field.
   --  @param Cursor Zero-based byte offset of the caret.
   --  @param Field_Width Pixel width the text is drawn in.
   --  @param Line_Height Text line height in pixels.
   --  @param Caret_Width Pixel width of the caret mark.
   --  @param Mirrored Whether the frame is mirrored.
   --  @param Has_Glyph Whether the font can draw a code point
   --  (Guikit.Bidi.Caret_Column), so the caret and the drawn text lay Arabic
   --  out alike. Null asks Guikit.Bidi.Can_Draw_Form, which answers for the
   --  fonts Guikit.Text draws with.
   --  @return The caret's left edge, in pixels from the field's left edge.
   function Caret_X
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null)
      return Natural;

   --  The view of Text in a field Field_Width pixels wide with the caret
   --  Cursor bytes in. A character straddling the scroll cut goes whole, so
   --  what is left fits the field. The caret is placed as Caret_X places it
   --  in the text left after the scroll.
   --
   --  Text that needs bidi layout is scrolled by the caret's drawn column
   --  instead (Guikit.Bidi.Caret_Column over the whole text): the cut is the
   --  one the text is drawn with unscrolled (Guikit.Bidi.Cut_Columns) while
   --  the caret is inside the field, and otherwise the least change to it
   --  that brings the caret to the field's nearer edge -- keeping, as plain
   --  text does, a cell beside it on the side the paragraph is typed
   --  towards: its right in a left-to-right paragraph, its left in a
   --  right-to-left one. Skip_Bytes is then 0 and Cut_Columns holds the cut.
   --  A field narrower than one cell shows none of it: the cut is the
   --  unscrolled one and the caret stands at the field's start.
   --
   --  @param Text UTF-8 field text.
   --  @param Cursor Zero-based byte offset of the caret.
   --  @param Field_Width Pixel width the text is drawn in.
   --  @param Line_Height Text line height in pixels.
   --  @param Caret_Width Pixel width of the caret mark.
   --  @param Mirrored Whether the frame is mirrored.
   --  @param Has_Glyph Whether the font can draw a code point, as for Caret_X.
   --  @return The scroll and the caret position.
   function View_Of
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null)
      return View;

   --  The byte offset a click puts the caret at: before the clicked
   --  character when the click is on the half of it that comes first in
   --  reading order, after it otherwise (Guikit.Bidi.Cursor_At_Half_Column),
   --  counted back from the end of the drawn text in a mirrored frame. The
   --  inverse of Caret_X, and of View_Of given the view's Skip_Bytes and
   --  Cut_Columns.
   --
   --  @param Text UTF-8 field text.
   --  @param Skip_Bytes Leading bytes scrolled off (View.Skip_Bytes; 0 for a
   --  field drawn unscrolled).
   --  @param Click_X The click, in pixels from the field's left edge.
   --  @param Field_Width Pixel width the text is drawn in; Natural'Last when
   --  the text is not cut.
   --  @param Line_Height Text line height in pixels.
   --  @param Mirrored Whether the frame is mirrored.
   --  @param Has_Glyph Whether the font can draw a code point, as for Caret_X.
   --  @param Cut_Columns The cells of laid-out text cut off its left
   --  (View.Cut_Columns); Guikit.Draw.Auto_Cut for text drawn with the
   --  default cut. Ignored for text that needs no bidi layout.
   --  @return Zero-based byte offset into Text.
   function Cursor_At
     (Text        : String;
      Skip_Bytes  : Natural;
      Click_X     : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null;
      Cut_Columns : Natural := Guikit.Draw.Auto_Cut)
      return Natural;

end Guikit.Text_Fields;
