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
   --  Recognises ASCII spaces and controls (space, HT..CR), the C1 next-line
   --  control (encoded, or as a stray legacy byte that is not the tail of a
   --  well-formed sequence before it), and the Unicode space separators (NBSP,
   --  the U+2000..200A range, line/paragraph separators, ideographic space,
   --  etc.). Used to split a query string into search tokens; step Position by
   --  whole sequences.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Position Byte offset into Content (zero-based) to test.
   --  @return Byte length of the separator at Position, or 0 if none.
   function Whitespace_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural;

   --  Decode the UTF-8 codepoint starting at Content (Index), advancing Index
   --  past it. Invalid sequences yield Replacement_Codepoint and advance one
   --  byte. Used by the text renderer to iterate a string's codepoints.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Index In: first byte of the codepoint; out: first byte after it.
   --  @param Codepoint The decoded Unicode codepoint.
   --  @param Replacement_Codepoint Value used for an invalid sequence.
   procedure Decode_Next_Codepoint
     (Content               : String;
      Index                 : in out Integer;
      Codepoint             : out Natural;
      Replacement_Codepoint : Natural := 16#FFFD#);

   --  Whether a codepoint is a required zero-width combining mark (so a text
   --  renderer can count it as intentionally invisible rather than missing).
   --
   --  @param Codepoint A Unicode codepoint.
   --  @return True for the required zero-width combining ranges.
   function Is_Required_Zero_Width_Codepoint
     (Codepoint : Natural)
      return Boolean;

   --  Whether a codepoint takes no cell of its own: a required zero-width
   --  combining mark, or a variation selector.
   --
   --  @param Codepoint A Unicode codepoint.
   --  @return True when it combines with the codepoint before it.
   function Is_Combining_Codepoint
     (Codepoint : Natural)
      return Boolean;

   --  How many monospace cells a codepoint takes: 0 when it combines or is
   --  an invisible format character (zero-width space, non-joiner and joiner,
   --  directional marks, word joiner, byte-order mark, emoji tags), 2 for an
   --  East Asian wide (including CJK Extension B and later) or emoji
   --  codepoint, else 1. Display_Units sums this.
   --
   --  @param Codepoint A Unicode codepoint.
   --  @return Its width in cells.
   function Codepoint_Display_Units
     (Codepoint : Natural)
      return Natural;

   --  Encode a Unicode codepoint as its UTF-8 byte sequence (1-4 bytes). A
   --  surrogate (U+D800..U+DFFF) or a value above U+10FFFF has no UTF-8 encoding
   --  and yields the empty string. This is the inverse of Decode_Next_Codepoint.
   --
   --  @param Codepoint A Unicode codepoint.
   --  @return The UTF-8 bytes, or "" when Codepoint is not encodable.
   function Encode (Codepoint : Natural) return String;

   --  The longest prefix of Content whose display width does not exceed
   --  Max_Units display columns, cut on a cluster boundary: never between a
   --  codepoint and the combining marks after it, nor inside an emoji
   --  zero-width-joiner sequence. Empty when Max_Units is 0 or Content is
   --  empty.
   --
   --  @param Content UTF-8 text.
   --  @param Max_Units Maximum display columns.
   --  @return The fitting prefix of Content.
   function Prefix_By_Units
     (Content   : String;
      Max_Units : Natural)
      return String;

   --  Content fitted into Max_Units display columns: unchanged when it fits;
   --  otherwise cut on a cluster boundary (see Prefix_By_Units) to leave one
   --  column for a trailing U+2026 ellipsis, dropping a dangling '.' or ' '
   --  before it. Short of two columns, or when nothing but such a dangling
   --  character would precede the ellipsis, it hard-cuts without one. The one
   --  truncation rule every guikit component that shortens a label uses.
   --
   --  @param Content UTF-8 text.
   --  @param Max_Units Maximum display columns.
   --  @return The fitted text.
   function Fit_With_Ellipsis
     (Content   : String;
      Max_Units : Natural)
      return String;

   --  The display width, in columns, of the first Cursor bytes of Content
   --  (clamped to Content's length). Used to place a text caret at a byte
   --  offset. Measured in whole clusters: a Cursor inside a combining or
   --  zero-width-joiner sequence measures to the end of that sequence.
   --
   --  @param Content UTF-8 text.
   --  @param Cursor Byte offset into Content.
   --  @return Display columns before the cursor.
   function Display_Units_Before
     (Content : String;
      Cursor  : Natural)
      return Natural;

   --  Return the byte offset corresponding to a display-cell column: the
   --  inverse of Display_Units_Before, for placing a caret where a click
   --  landed. Zero-width codepoints after the column stay with the cluster
   --  before it; a wide codepoint straddling the column is not entered.
   --
   --  Invalid bytes count as one replacement display cell.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @param Column Zero-based display-cell column.
   --  @return Zero-based byte offset at the requested display-cell column.
   function Byte_Offset_For_Display_Column
     (Content : String;
      Column  : Natural)
      return Natural;

   --  Return whether Content is well-formed UTF-8.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @return True when every byte belongs to a valid UTF-8 sequence.
   function Is_Valid
     (Content : String)
      return Boolean;

end Guikit.Utf8;
