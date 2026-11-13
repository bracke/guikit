with Ada.Strings.Unbounded;

--  Caret movement and deletion over UTF-8 text: the character (a codepoint
--  with the combining marks after it) and word boundaries a text field steps
--  and deletes by, and the one deletion rule every field shares. All offsets
--  are zero-based byte offsets into the text; invalid bytes are standalone
--  units, so a malformed name can still be edited byte by byte.
package Guikit.Utf8.Editing is

   --  Return the previous UTF-8 text boundary before or at Cursor.
   --
   --  Invalid bytes are treated as standalone boundary units.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the previous text boundary.
   function Previous_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the next UTF-8 text boundary after or at Cursor.
   --
   --  Invalid bytes are treated as standalone boundary units.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the next text boundary.
   function Next_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the nearest UTF-8 text boundary at or before Cursor.
   --
   --  Invalid bytes are treated as standalone boundary units.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the nearest earlier text boundary.
   function Boundary_At_Or_Before
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the byte length of a word separator at Position.
   --
   --  Separators are the whitespace of Guikit.Utf8.Whitespace_Separator_Length
   --  plus the path/name punctuation a text field's word movement stops at
   --  ('/', '\', '.', '-', '_').
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Position Zero-based byte offset into Content.
   --  @return Separator byte length, or zero when no separator starts there.
   function Word_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural;

   --  Return the previous word boundary before or at Cursor.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the previous word boundary.
   function Previous_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the next word boundary after or at Cursor.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Cursor Zero-based byte cursor offset.
   --  @return Byte offset of the next word boundary.
   function Next_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return Content with the byte range [First, Last) removed.
   --
   --  First and Last are clamped to the string length; an empty string or a
   --  non-positive-width range returns Content unchanged.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param First Zero-based byte offset of the first byte to remove.
   --  @param Last Zero-based byte offset just past the last byte to remove.
   --  @return Content with the [First, Last) byte range deleted.
   function Remove_Range
     (Content : String;
      First   : Natural;
      Last    : Natural)
      return String;

   --  Delete from a text field at its caret: the character (or, By_Word, the
   --  word) before the caret when Backward, else the one after it. The one
   --  deletion rule every text field shares.
   --
   --  At the near edge (Backward at 0, forward at or past the end) nothing is
   --  deleted: New_Text is Text and New_Cursor is Cursor.
   --
   --  @param Text UTF-8 encoded field text.
   --  @param Cursor Zero-based byte offset of the caret.
   --  @param Backward Whether to delete before the caret rather than after it.
   --  @param By_Word Whether to delete to a word boundary, not a character's.
   --  @param New_Text The text after the deletion.
   --  @param New_Cursor The caret after the deletion.
   procedure Delete_At
     (Text       : String;
      Cursor     : Natural;
      Backward   : Boolean;
      By_Word    : Boolean;
      New_Text   : out Ada.Strings.Unbounded.Unbounded_String;
      New_Cursor : out Natural);

end Guikit.Utf8.Editing;
