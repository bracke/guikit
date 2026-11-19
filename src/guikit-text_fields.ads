--  A single-line text field's view of its text: how much of the start is
--  scrolled off so the caret stays inside the field, and where the caret is
--  drawn. The one rule every field shares -- the command palette's query,
--  the item grid's rename field, the settings panel's text values, and an
--  application's own fields -- so drawing and click-to-caret mapping agree.
package Guikit.Text_Fields is

   type View is record
      --  Leading bytes of the text not drawn: whole characters, at least
      --  the columns Guikit.Layout.Input_Scroll_Columns asks for.
      Skip_Bytes : Natural := 0;
      --  Where the caret is drawn, in pixels from the field's left edge,
      --  kept inside the field.
      Caret_X    : Natural := 0;
   end record;

   --  The view of Text in a field Field_Width pixels wide with the caret
   --  Cursor bytes in. A character straddling the scroll cut goes whole, so
   --  what is left fits the field. The caret is placed where the drawn text
   --  has it (Guikit.Bidi.Caret_Column: right-to-left runs and a mirrored
   --  layout included).
   --
   --  @param Text UTF-8 field text.
   --  @param Cursor Zero-based byte offset of the caret.
   --  @param Field_Width Pixel width the text is drawn in.
   --  @param Line_Height Text line height in pixels.
   --  @param Caret_Width Pixel width of the caret mark.
   --  @return The scroll and the caret position.
   function View_Of
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural)
      return View;

end Guikit.Text_Fields;
