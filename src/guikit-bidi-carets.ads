--  Where a caret stands in laid-out text: the column a byte offset is drawn
--  at, the byte offset a click lands on, and where an arrow key moves it.
--  Guikit.Bidi's caret subprograms are these.
private package Guikit.Bidi.Carets is

   --  See Guikit.Bidi.Caret_Column.
   --
   --  @param Content UTF-8 text, drawn from column 0.
   --  @param Cursor Byte offset into Content.
   --  @param Columns How many display cells the text is drawn in.
   --  @param Has_Glyph Whether the font can draw a code point; null asks Can_Draw_Form.
   --  @return Display column of the caret.
   function Caret_Column
     (Content   : String;
      Cursor    : Natural;
      Columns   : Natural := Natural'Last;
      Has_Glyph : access function (Codepoint : Natural) return Boolean := null)
      return Natural;

   --  See Guikit.Bidi.Cursor_At_Half_Column.
   --
   --  @param Content UTF-8 text, drawn from column 0.
   --  @param Half_Column Click position in half display cells.
   --  @param Columns How many display cells the text is drawn in.
   --  @param Has_Glyph Whether the font can draw a code point; null asks Can_Draw_Form.
   --  @return Zero-based byte offset into Content.
   function Cursor_At_Half_Column
     (Content     : String;
      Half_Column : Natural;
      Columns     : Natural := Natural'Last;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null)
      return Natural;

   --  See Guikit.Bidi.Caret_Step.
   --
   --  @param Content UTF-8 text.
   --  @param Cursor Zero-based byte offset of the caret.
   --  @param Rightward Whether the right arrow was pressed, not the left.
   --  @param By_Word Whether to step by word.
   --  @param Has_Glyph Whether the font can draw a code point; null asks Can_Draw_Form.
   --  @return The new zero-based byte offset; Cursor when nothing lies that way.
   function Caret_Step
     (Content   : String;
      Cursor    : Natural;
      Rightward : Boolean;
      By_Word   : Boolean := False;
      Has_Glyph : access function (Codepoint : Natural) return Boolean := null)
      return Natural;

   --  See Guikit.Bidi.Cut_Columns.
   --
   --  @param Laid A laid-out line.
   --  @param Columns How many display cells it is drawn in.
   --  @return The cells cut off on the left.
   function Cut_Columns (Laid : Line; Columns : Natural) return Natural;

   --  See Guikit.Bidi.Drawn_Columns.
   --
   --  @param Laid A laid-out line.
   --  @param Cut The cells cut off on the left.
   --  @param Columns How many display cells the box is.
   --  @return The cells drawn, at most Columns.
   function Drawn_Columns (Laid : Line; Cut, Columns : Natural) return Natural;

end Guikit.Bidi.Carets;
