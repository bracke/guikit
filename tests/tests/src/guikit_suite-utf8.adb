with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Utf8;

--  Display-width tests for Guikit.Utf8.Display_Units. UTF-8 sequences are
--  built from explicit bytes (Character'Val) so the assertions do not depend on
--  the source-file encoding: ASCII counts one cell per character, two- and
--  three-byte codepoints count one cell, combining and zero-width codepoints
--  count zero, and wide (CJK/emoji) codepoints count two.
package body Guikit_Suite.Utf8 is

   use AUnit.Assertions;

   type Utf8_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Utf8_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Utf8_Test_Case);

   procedure Test_Ascii_And_Empty (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multibyte_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Zero_Width (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Wide_And_Mixed (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Encode (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Joiners_And_Planes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cluster_Boundaries (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Fit_With_Ellipsis (T : in out AUnit.Test_Cases.Test_Case'Class);

   type Byte_Values is array (Positive range <>) of Natural;

   --  Build a String from a list of byte values.
   function Bytes (Values : Byte_Values) return String;

   function Bytes (Values : Byte_Values) return String is
      Result : String (Values'Range);
   begin
      for I in Values'Range loop
         Result (I) := Character'Val (Values (I));
      end loop;
      return Result;
   end Bytes;

   overriding function Name (T : Utf8_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit utf8 display-width measurement");
   end Name;

   overriding procedure Register_Tests (T : in out Utf8_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ascii_And_Empty'Access, "ASCII counts one cell per character; empty is zero");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Multibyte_Narrow'Access, "two- and three-byte narrow codepoints count one cell");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Zero_Width'Access, "combining and zero-width codepoints count zero cells");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Wide_And_Mixed'Access, "wide codepoints count two cells; mixed runs sum");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Encode'Access, "codepoints encode to 1-4 UTF-8 bytes and round-trip through decode");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Joiners_And_Planes'Access,
         "joiners and other format characters take no cell; CJK Extension B is wide; a ZWJ emoji "
         & "sequence measures as the glyphs drawn");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cluster_Boundaries'Access,
         "truncation and caret measurement never split a ZWJ sequence or strand a combining mark");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Fit_With_Ellipsis'Access,
         "Fit_With_Ellipsis keeps text that fits, trims a dangling '.'/' ' before the ellipsis, hard-cuts tiny widths");
   end Register_Tests;

   procedure Test_Ascii_And_Empty (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Guikit.Utf8.Display_Units ("") = 0, "an empty string measures zero cells");
      Assert (Guikit.Utf8.Display_Units ("hello") = 5, "5 ASCII characters measure five cells");
      Assert (Guikit.Utf8.Display_Units ("a b") = 3, "ASCII with a space measures three cells");
      --  A lone invalid byte counts as one replacement cell.
      Assert (Guikit.Utf8.Display_Units (Bytes ([1 => 16#FF#])) = 1,
              "a lone invalid byte counts as one replacement cell");
   end Test_Ascii_And_Empty;

   procedure Test_Multibyte_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  U+00E9 (e-acute), a two-byte sequence.
      Two_Byte : constant String := Bytes ([16#C3#, 16#A9#]);
      --  U+20AC (euro sign), a three-byte sequence.
      Three_Byte : constant String := Bytes ([16#E2#, 16#82#, 16#AC#]);
   begin
      Assert (Guikit.Utf8.Display_Units (Two_Byte) = 1,
              "a two-byte narrow codepoint measures one cell");
      Assert (Guikit.Utf8.Display_Units (Three_Byte) = 1,
              "a three-byte narrow codepoint measures one cell");
   end Test_Multibyte_Narrow;

   procedure Test_Zero_Width (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  U+0301 combining acute accent.
      Combining : constant String := Bytes ([16#CC#, 16#81#]);
      --  U+FE00 variation selector, a required zero-width codepoint.
      Zero_Width : constant String := Bytes ([16#EF#, 16#B8#, 16#80#]);
   begin
      Assert (Guikit.Utf8.Display_Units (Combining) = 0,
              "a combining mark measures zero cells");
      Assert (Guikit.Utf8.Display_Units (Zero_Width) = 0,
              "a zero-width codepoint measures zero cells");
      --  A base character followed by a combining mark measures one cell.
      Assert (Guikit.Utf8.Display_Units ("a" & Combining) = 1,
              "a base character plus a combining mark measures one cell");
   end Test_Zero_Width;

   procedure Test_Wide_And_Mixed (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  U+4E00 CJK ideograph, a wide three-byte sequence.
      Wide : constant String := Bytes ([16#E4#, 16#B8#, 16#80#]);
   begin
      Assert (Guikit.Utf8.Display_Units (Wide) = 2,
              "a wide CJK codepoint measures two cells");
      Assert (Guikit.Utf8.Display_Units ("a" & Wide) = 3,
              "one ASCII cell plus one wide (two) cell measures three");
      Assert (Guikit.Utf8.Display_Units (Wide & Wide) = 4,
              "two wide codepoints measure four cells");
   end Test_Wide_And_Mixed;

   procedure Test_Encode (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Guikit.Utf8.Encode (Character'Pos ('A')) = "A",
              "an ASCII codepoint encodes to one byte");
      Assert (Guikit.Utf8.Encode (16#E9#) = Bytes ([16#C3#, 16#A9#]),
              "U+00E9 encodes to two bytes");
      Assert (Guikit.Utf8.Encode (16#20AC#) = Bytes ([16#E2#, 16#82#, 16#AC#]),
              "U+20AC encodes to three bytes");
      Assert (Guikit.Utf8.Encode (16#1F600#) = Bytes ([16#F0#, 16#9F#, 16#98#, 16#80#]),
              "U+1F600 encodes to four bytes");
      Assert (Guikit.Utf8.Encode (16#D800#) = "",
              "a surrogate codepoint has no UTF-8 encoding");
      Assert (Guikit.Utf8.Encode (16#11_0000#) = "",
              "a codepoint above U+10FFFF has no UTF-8 encoding");

      --  Encoding then decoding returns the original codepoint.
      declare
         Encoded : constant String := Guikit.Utf8.Encode (16#20AC#);
         Index   : Integer := Encoded'First;
         Decoded : Natural;
      begin
         Guikit.Utf8.Decode_Next_Codepoint (Encoded, Index, Decoded);
         Assert (Decoded = 16#20AC# and then Index = Encoded'Last + 1,
                 "encode then decode round-trips the codepoint");
      end;
   end Test_Encode;

   --  U+1F468 MAN, U+1F469 WOMAN, U+1F467 GIRL joined by U+200D ZERO WIDTH
   --  JOINER: the "family" emoji ZWJ sequence. The text renderer has no ZWJ
   --  composition, so it draws the three emoji side by side (two cells each)
   --  and the joiners as nothing.
   function Family return String is
     (Guikit.Utf8.Encode (16#1F468#) & Guikit.Utf8.Encode (16#200D#)
      & Guikit.Utf8.Encode (16#1F469#) & Guikit.Utf8.Encode (16#200D#)
      & Guikit.Utf8.Encode (16#1F467#));

   procedure Test_Joiners_And_Planes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function E (Codepoint : Natural) return String renames Guikit.Utf8.Encode;
      --  ZWSP, ZWNJ, ZWJ, word joiner, byte-order mark, VS15, VS16.
      Invisible : constant array (Positive range 1 .. 7) of Natural :=
        [16#200B#, 16#200C#, 16#200D#, 16#2060#, 16#FEFF#, 16#FE0E#, 16#FE0F#];
   begin
      for Codepoint of Invisible loop
         Assert (Guikit.Utf8.Codepoint_Display_Units (Codepoint) = 0,
                 "U+" & Codepoint'Image & " (decimal) takes no cell");
      end loop;
      Assert (Guikit.Utf8.Display_Units ("a" & E (16#200B#) & "b") = 2,
              "a zero-width space between two letters adds nothing");
      --  U+2764 HEAVY BLACK HEART + VS16 (emoji presentation): one glyph.
      Assert (Guikit.Utf8.Display_Units (E (16#2764#) & E (16#FE0F#)) = 1,
              "a variation selector adds nothing to its base");
      --  Hebrew shin + shin dot, Arabic beh + fatha: the marks add nothing.
      Assert (Guikit.Utf8.Display_Units (E (16#05E9#) & E (16#05C1#)) = 1,
              "a Hebrew point adds nothing to its letter");
      Assert (Guikit.Utf8.Display_Units (E (16#0628#) & E (16#064E#)) = 1,
              "an Arabic haraka adds nothing to its letter");

      Assert (Guikit.Utf8.Codepoint_Display_Units (16#20000#) = 2,
              "U+20000, the first CJK Extension B ideograph, is wide");
      Assert (Guikit.Utf8.Codepoint_Display_Units (16#2A6DF#) = 2,
              "U+2A6DF, the last CJK Extension B ideograph, is wide");
      Assert (Guikit.Utf8.Codepoint_Display_Units (16#30000#) = 2,
              "U+30000, the first CJK Extension G ideograph, is wide");

      Assert (Guikit.Utf8.Display_Units (Family) = 6,
              "a ZWJ family sequence measures its three drawn emoji (2 cells each), not its joiners");
   end Test_Joiners_And_Planes;

   procedure Test_Cluster_Boundaries (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Acute  : constant String := Guikit.Utf8.Encode (16#0301#);
      Man    : constant String := Guikit.Utf8.Encode (16#1F468#);
   begin
      Assert (Guikit.Utf8.Prefix_By_Units ("a" & Family & "b", 3) = "a",
              "a ZWJ sequence that does not fit whole is left out whole, not cut after its first emoji");
      Assert (Guikit.Utf8.Prefix_By_Units ("a" & Family & "b", 7) = "a" & Family,
              "a ZWJ sequence that fits is kept whole");
      Assert (Guikit.Utf8.Prefix_By_Units ("e" & Acute & "x", 1) = "e" & Acute,
              "a combining mark stays with its base at the cut");
      Assert (Guikit.Utf8.Prefix_By_Units (Man & Man, 3) = Man,
              "unjoined emoji are separate clusters");

      Assert (Guikit.Utf8.Display_Units_Before (Family, Man'Length) = 6,
              "a caret inside a ZWJ sequence measures to the sequence's end");
      Assert (Guikit.Utf8.Display_Units_Before ("e" & Acute & "x", 1) = 1,
              "a caret between a base and its mark measures to the mark's end");
      Assert (Guikit.Utf8.Display_Units_Before ("ab" & Family, 2) = 2,
              "a caret before a ZWJ sequence measures only what precedes it");
   end Test_Cluster_Boundaries;

   procedure Test_Fit_With_Ellipsis (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ellipsis : constant String := Guikit.Utf8.Encode (16#2026#);
   begin
      Assert (Guikit.Utf8.Fit_With_Ellipsis ("Hello", 5) = "Hello", "text that fits is unchanged");
      Assert (Guikit.Utf8.Fit_With_Ellipsis ("Hello", 0) = "", "no room fits nothing");
      Assert (Guikit.Utf8.Fit_With_Ellipsis ("Hello", 1) = "H", "one column hard-cuts without an ellipsis");
      Assert (Guikit.Utf8.Fit_With_Ellipsis ("Hello", 4) = "Hel" & Ellipsis,
              "a long text keeps one column for the ellipsis");
      Assert (Guikit.Utf8.Fit_With_Ellipsis ("Hello world", 7) = "Hello" & Ellipsis,
              "a dangling space before the ellipsis is trimmed");
      Assert (Guikit.Utf8.Fit_With_Ellipsis ("Done. More", 6) = "Done" & Ellipsis,
              "a dangling full stop before the ellipsis is trimmed");
      Assert (Guikit.Utf8.Fit_With_Ellipsis ("a" & Family & "b", 5) = "a" & Ellipsis,
              "the ellipsis never splits a ZWJ sequence");
   end Test_Fit_With_Ellipsis;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Utf8_Test_Case));
      return Result;
   end Suite;

end Guikit_Suite.Utf8;
