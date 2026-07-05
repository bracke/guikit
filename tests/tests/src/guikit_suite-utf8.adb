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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Utf8_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Utf8;
