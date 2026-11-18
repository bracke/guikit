with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Guikit.Bidi;
with Guikit.Utf8;

--  Right-to-left text: the bidi algorithm against Unicode's own conformance
--  data, Arabic joining, and the caret and click mapping over reordered text.
package body Guikit_Suite.Bidi is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use type Guikit.Bidi.Codepoint_Array;

   type Bidi_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Bidi_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Bidi_Test_Case);

   procedure Test_Conformance (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Hebrew_Reads_Right_To_Left (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Arabic_Joins (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Lam_Alef (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Missing_Forms_Stay_Plain (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Brackets_Mirror (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Latin_Unchanged (T : in out AUnit.Test_Cases.Test_Case'Class);

   function Utf8 (Codes : Guikit.Bidi.Codepoint_Array) return String is
      Result : Unbounded_String;
   begin
      for Code of Codes loop
         Append (Result, Guikit.Utf8.Encode (Code));
      end loop;
      return To_String (Result);
   end Utf8;

   --  The glyphs of a laid-out line, left to right.
   function Drawn (Laid : Guikit.Bidi.Line) return Guikit.Bidi.Codepoint_Array is
      Result : Guikit.Bidi.Codepoint_Array (1 .. Natural (Laid.Glyphs.Length));
      Next   : Natural := 0;
   begin
      for Item of Laid.Clusters loop
         for G in Item.Glyph_First .. Item.Glyph_First + Item.Glyph_Count - 1 loop
            Next := Next + 1;
            Result (Next) := Laid.Glyphs (G);
         end loop;
      end loop;
      return Result (1 .. Next);
   end Drawn;

   function Image (Codes : Guikit.Bidi.Codepoint_Array) return String is
      Result : Unbounded_String;
   begin
      for Code of Codes loop
         Append (Result, Natural'Image (Code));
      end loop;
      return To_String (Result);
   end Image;

   overriding function Name (T : Bidi_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit bidi");
   end Name;

   overriding procedure Register_Tests (T : in out Bidi_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Conformance'Access, "levels and order match Unicode's BidiCharacterTest");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Hebrew_Reads_Right_To_Left'Access, "a Hebrew name draws right to left, a Latin run in it stays");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Arabic_Joins'Access, "Arabic letters take initial, medial, final and isolated forms");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Lam_Alef'Access, "lam then alef draw as one ligature across both cells");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Missing_Forms_Stay_Plain'Access, "a form the font lacks is drawn as the plain letter");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Brackets_Mirror'Access, "brackets in a right-to-left run are mirrored");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Caret_And_Click'Access, "the caret and a click land where the character is drawn");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Latin_Unchanged'Access, "text with nothing right-to-left needs no layout");
   end Register_Tests;

   --  Runs every test line of File; returns how many failed and describes
   --  the first.
   procedure Run_File (Path : String; Lines, Failures : out Natural; First_Failure : out Unbounded_String) is
      File : Ada.Text_IO.File_Type;

      function Field (Line : String; Number : Positive) return String is
         Start : Positive := Line'First;
         Seen  : Natural := 1;
      begin
         for I in Line'Range loop
            if Line (I) = ';' then
               if Seen = Number then
                  return Line (Start .. I - 1);
               end if;
               Seen := Seen + 1;
               Start := I + 1;
            end if;
         end loop;
         return Line (Start .. Line'Last);
      end Field;

      function Words (Text : String) return Natural is
         Count : Natural := 0;
         In_Word : Boolean := False;
      begin
         for C of Text loop
            if C = ' ' then
               In_Word := False;
            elsif not In_Word then
               In_Word := True;
               Count := Count + 1;
            end if;
         end loop;
         return Count;
      end Words;

      function Word (Text : String; Number : Positive) return String is
         Count : Natural := 0;
         Start : Positive := Text'First;
      begin
         for I in Text'Range loop
            if Text (I) /= ' ' and then (I = Text'First or else Text (I - 1) = ' ') then
               Count := Count + 1;
               Start := I;
            end if;
            if Count = Number and then (I = Text'Last or else Text (I + 1) = ' ') and then Text (I) /= ' ' then
               return Text (Start .. I);
            end if;
         end loop;
         return "";
      end Word;
   begin
      Lines := 0;
      Failures := 0;
      First_Failure := Null_Unbounded_String;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            if Line'Length > 0 and then Line (Line'First) /= '#' then
               Lines := Lines + 1;
               declare
                  Codes_Text : constant String := Field (Line, 1);
                  Count      : constant Natural := Words (Codes_Text);
                  Codes      : Guikit.Bidi.Codepoint_Array (1 .. Count);
                  Levels     : Guikit.Bidi.Level_Array (1 .. Count);
                  Para       : Natural;
                  Direction  : constant Guikit.Bidi.Paragraph_Direction :=
                    (case Natural'Value (Field (Line, 2)) is
                        when 0 => Guikit.Bidi.Left_To_Right,
                        when 1 => Guikit.Bidi.Right_To_Left,
                        when others => Guikit.Bidi.Auto);
                  Expected_Para   : constant Natural := Natural'Value (Field (Line, 3));
                  Expected_Levels : constant String := Field (Line, 4);
                  Expected_Order  : constant String := Field (Line, 5);
                  Good : Boolean;
               begin
                  for I in 1 .. Count loop
                     Codes (I) := Natural'Value ("16#" & Word (Codes_Text, I) & "#");
                  end loop;
                  Guikit.Bidi.Resolve_Levels (Codes, Direction, Levels, Para);
                  Good := Para = Expected_Para;
                  for I in 1 .. Count loop
                     declare
                        Want : constant String := Word (Expected_Levels, I);
                     begin
                        if Want = "x" then
                           Good := Good and then Levels (I) = Guikit.Bidi.Removed;
                        else
                           Good := Good and then Levels (I) = Natural'Value (Want);
                        end if;
                     end;
                  end loop;
                  declare
                     Order : constant Guikit.Bidi.Index_Array := Guikit.Bidi.Visual_Order (Levels);
                  begin
                     if Order'Length /= Words (Expected_Order) then
                        Good := False;
                     else
                        for K in Order'Range loop
                           Good := Good and then Order (K) - 1 = Natural'Value (Word (Expected_Order, K));
                        end loop;
                     end if;
                  end;
                  if not Good then
                     Failures := Failures + 1;
                     if Failures = 1 then
                        declare
                           Got : Unbounded_String;
                        begin
                           for I in 1 .. Count loop
                              Append
                                (Got,
                                 (if Levels (I) = Guikit.Bidi.Removed then " x" else Natural'Image (Levels (I))));
                           end loop;
                           First_Failure := To_Unbounded_String
                             (Line & " | got para" & Natural'Image (Para) & " levels" & To_String (Got));
                        end;
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Run_File;

   procedure Test_Conformance (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Full   : constant String := "/usr/share/unicode/BidiCharacterTest.txt";
      Sample : constant String := "fixtures/BidiCharacterTest-sample.txt";

      --  The full file only when it is the version the tables follow: another
      --  version's expectations differ where the data does.
      function Same_Version (Path : String) return Boolean is
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
         declare
            Header : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Ada.Text_IO.Close (File);
            return Ada.Strings.Fixed.Index (Header, "BidiCharacterTest-15.1.0") > 0;
         end;
      end Same_Version;

      Path : constant String :=
        (if Ada.Directories.Exists (Full) and then Same_Version (Full) then Full else Sample);
      Lines, Failures : Natural;
      First_Failure   : Unbounded_String;
   begin
      Run_File (Path, Lines, Failures, First_Failure);
      Assert (Lines > 2_000, "too few conformance lines in " & Path & ":" & Natural'Image (Lines));
      Assert
        (Failures = 0,
         "failed" & Natural'Image (Failures) & " of" & Natural'Image (Lines) & " lines of " & Path
         & "; first: " & To_String (First_Failure));
   end Test_Conformance;

   Alef  : constant := 16#05D0#;
   Bet   : constant := 16#05D1#;
   Gimel : constant := 16#05D2#;

   procedure Test_Hebrew_Reads_Right_To_Left (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Name : constant String := Utf8 ([Alef, Bet, Gimel, 16#2E#, Character'Pos ('t'), Character'Pos ('x')]);
      Laid : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Name);
   begin
      Assert (Laid.Right_To_Left, "a name opening with Hebrew is a right-to-left paragraph");
      Assert
        (Drawn (Laid) = Guikit.Bidi.Codepoint_Array'
           [Character'Pos ('t'), Character'Pos ('x'), 16#2E#, Gimel, Bet, Alef],
         "drawn as" & Image (Drawn (Laid)));

      declare
         Mixed : constant Guikit.Bidi.Line :=
           Guikit.Bidi.Lay_Out ("ab " & Utf8 ([Alef, Bet]) & " c");
      begin
         Assert (not Mixed.Right_To_Left, "a name opening with Latin stays left to right");
         Assert
           (Drawn (Mixed) = Guikit.Bidi.Codepoint_Array'
              [Character'Pos ('a'), Character'Pos ('b'), 32, Bet, Alef, 32, Character'Pos ('c')],
            "mixed drawn as" & Image (Drawn (Mixed)));
      end;
   end Test_Hebrew_Reads_Right_To_Left;

   Beh  : constant := 16#0628#;
   Lam  : constant := 16#0644#;
   Arabic_Alef : constant := 16#0627#;

   procedure Test_Arabic_Joins (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Three behs: initial, medial, final -- drawn right to left, so the
      --  final form comes first.
      Three : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Utf8 ([Beh, Beh, Beh]));
      One   : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Utf8 ([Beh]));
      --  Fatha (a transparent mark) between two behs does not break the join.
      Marked : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Utf8 ([Beh, 16#064E#, Beh]));
   begin
      Assert
        (Drawn (Three) = Guikit.Bidi.Codepoint_Array'[16#FE90#, 16#FE92#, 16#FE91#],
         "three behs drawn as" & Image (Drawn (Three)));
      Assert (Drawn (One) = Guikit.Bidi.Codepoint_Array'[16#FE8F#], "one beh drawn as" & Image (Drawn (One)));
      Assert
        (Drawn (Marked) = Guikit.Bidi.Codepoint_Array'[16#FE90#, 16#FE91#, 16#064E#],
         "beh fatha beh drawn as" & Image (Drawn (Marked)));
      Assert (Natural (Marked.Clusters.Length) = 2, "the mark stays in its letter's cell");
   end Test_Arabic_Joins;

   procedure Test_Lam_Alef (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Alone : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Utf8 ([Lam, Arabic_Alef]));
      After : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Utf8 ([Beh, Lam, Arabic_Alef]));
   begin
      Assert (Drawn (Alone) = Guikit.Bidi.Codepoint_Array'[16#FEFB#], "lam alef drawn as" & Image (Drawn (Alone)));
      Assert (Natural (Alone.Clusters.Length) = 1, "one cluster");
      Assert (Alone.Clusters (1).Ligature and then Alone.Clusters (1).Units = 2, "spans both letters' cells");
      Assert
        (Drawn (After) = Guikit.Bidi.Codepoint_Array'[16#FEFC#, 16#FE91#],
         "beh lam alef drawn as" & Image (Drawn (After)));
   end Test_Lam_Alef;

   function Only_Basic_Arabic (Codepoint : Natural) return Boolean is (Codepoint < 16#FB50#);

   procedure Test_Missing_Forms_Stay_Plain (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Laid : constant Guikit.Bidi.Line :=
        Guikit.Bidi.Lay_Out (Utf8 ([Beh, Beh, Lam, Arabic_Alef]), Only_Basic_Arabic'Access);
   begin
      Assert
        (Drawn (Laid) = Guikit.Bidi.Codepoint_Array'[Arabic_Alef, Lam, Beh, Beh],
         "drawn as" & Image (Drawn (Laid)));
      Assert (Natural (Laid.Clusters.Length) = 4, "no ligature without its glyph");
   end Test_Missing_Forms_Stay_Plain;

   procedure Test_Brackets_Mirror (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  "(alef)" in a right-to-left paragraph: drawn ")alef(" mirrored back
      --  to "(alef)" on screen.
      Laid : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Utf8 ([Alef, 32, 16#28#, Bet, 16#29#]));
   begin
      Assert
        (Drawn (Laid) = Guikit.Bidi.Codepoint_Array'[16#28#, Bet, 16#29#, 32, Alef],
         "drawn as" & Image (Drawn (Laid)));
      Assert (Guikit.Bidi.Mirror_Of (16#28#) = 16#29#, "( mirrors to )");
      Assert (Guikit.Bidi.Mirror_Of (Character'Pos ('a')) = Character'Pos ('a'), "a letter does not mirror");
   end Test_Brackets_Mirror;

   procedure Test_Caret_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Alef, bet, gimel: two bytes each, drawn gimel bet alef.
      Hebrew : constant String := Utf8 ([Alef, Bet, Gimel]);
      Mixed  : constant String := "ab" & Utf8 ([Alef, Bet]);
   begin
      Assert (Guikit.Bidi.Caret_Column (Hebrew, 0) = 3, "before alef is the right edge");
      Assert (Guikit.Bidi.Caret_Column (Hebrew, 2) = 2, "before bet is between bet and alef");
      Assert (Guikit.Bidi.Caret_Column (Hebrew, 6) = 0, "at the end is the left edge");

      --  A click on the right half of alef (column 2) is before it.
      Assert (Guikit.Bidi.Cursor_At_Half_Column (Hebrew, 5) = 0, "right half of alef");
      Assert (Guikit.Bidi.Cursor_At_Half_Column (Hebrew, 4) = 2, "left half of alef");
      Assert (Guikit.Bidi.Cursor_At_Half_Column (Hebrew, 0) = 6, "left half of gimel");
      Assert (Guikit.Bidi.Cursor_At_Half_Column (Hebrew, 40) = 0, "past the left-to-right end of the text");

      --  "ab" then alef bet, drawn "ab" bet alef.
      Assert (Guikit.Bidi.Caret_Column (Mixed, 2) = 4, "before alef is its right edge");
      Assert (Guikit.Bidi.Caret_Column (Mixed, 1) = 1, "Latin carets are unchanged");
      Assert (Guikit.Bidi.Cursor_At_Half_Column (Mixed, 7) = 2, "right half of alef is before it");

      for Cursor in 0 .. Hebrew'Length loop
         if Cursor mod 2 = 0 then
            declare
               Column : constant Natural := Guikit.Bidi.Caret_Column (Hebrew, Cursor);
            begin
               --  Just inside the caret, on the side of the character it precedes.
               Assert
                 (Guikit.Bidi.Cursor_At_Half_Column (Hebrew, (if Column = 0 then 0 else 2 * Column - 1)) = Cursor,
                  "round trip at" & Natural'Image (Cursor));
            end;
         end if;
      end loop;
   end Test_Caret_And_Click;

   procedure Test_Latin_Unchanged (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (not Guikit.Bidi.Needs_Layout ("report (final).txt"), "Latin needs no layout");
      Assert (not Guikit.Bidi.Needs_Layout (Utf8 ([16#00E9#, 16#4E2D#])), "accented and CJK need no layout");
      Assert (Guikit.Bidi.Needs_Layout (Utf8 ([16#0661#])), "an Arabic digit does");
      Assert (Guikit.Bidi.Caret_Column ("abc", 2) = 2, "caret");
      Assert (Guikit.Bidi.Cursor_At_Half_Column ("abc", 3) = 2, "click rounds to the nearer boundary");
   end Test_Latin_Unchanged;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
      Cases  : constant AUnit.Test_Cases.Test_Case_Access := new Bidi_Test_Case;
   begin
      Result.Add_Test (Cases);
      return Result;
   end Suite;

end Guikit_Suite.Bidi;
