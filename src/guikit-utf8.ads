--  Renderer-agnostic UTF-8 measurement helpers.
--
--  A small, domain-free copy of the UTF-8 display-width logic the GUI layout
--  needs, so Guikit stays independent of the application's Files.UTF8
--  package.
package Guikit.Utf8 is

   --  Return the display-cell count for a UTF-8 byte string.
   --
   --  Invalid bytes count as one replacement display cell.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @return Number of display cells represented by Content.
   function Display_Units
     (Content : String)
      return Natural;

   --  Return the byte length of the whitespace token separator that starts at
   --  Position, or zero when the codepoint there is not whitespace.
   --
   --  Recognises ASCII spaces and controls (space, HT..CR), the raw C1
   --  next-line byte, and the Unicode space separators (NBSP, the U+2000..200A
   --  range, line/paragraph separators, ideographic space, etc.). Used to split
   --  a query string into search tokens.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Position Byte offset into Content (zero-based) to test.
   --  @return Byte length of the separator at Position, or 0 if none.
   function Whitespace_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural;

end Guikit.Utf8;
