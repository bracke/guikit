with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Guikit.Bidi;
with Guikit.Draw;
with Guikit.Mirroring;
with Guikit.Text_Fields;
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
   overriding procedure Set_Up (T : in out Bidi_Test_Case);

   procedure Test_Conformance (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Hebrew_Reads_Right_To_Left (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Arabic_Joins (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Lam_Alef (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Missing_Forms_Stay_Plain (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Brackets_Mirror (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Latin_Unchanged (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Arrows_Follow_The_Screen (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Mirrored_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Mirrored_Field (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ligature_Is_One_Stop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Undrawn_Ligature_Is_Two_Stops (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Wide_Character_Straddling_A_Mirrored_Field (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Default_Follows_Recorded_Forms (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Arrows_Follow_The_Screen'Access, "the arrow keys move the caret the way they point on the screen");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Mirrored_Layout'Access, "a mirrored frame reflects every box, and the caret follows the text");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Mirrored_Field'Access, "in a mirrored field the caret starts where its boundary is drawn");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ligature_Is_One_Stop'Access, "the arrow keys step over a lam-alef ligature whole");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Undrawn_Ligature_Is_Two_Stops'Access,
         "without the font's lam-alef ligature the caret stops between lam and alef");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Wide_Character_Straddling_A_Mirrored_Field'Access,
         "a mirrored field's caret counts the whole characters drawn");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Default_Follows_Recorded_Forms'Access,
         "given no Has_Glyph, carets and layout follow the forms the loaded fonts draw");
   end Register_Tests;

   --  Every test starts as before any font loaded -- every presentation
   --  form drawn -- whatever another suite's renderers recorded.
   overriding procedure Set_Up (T : in out Bidi_Test_Case) is
      pragma Unreferenced (T);
   begin
      Guikit.Bidi.Set_Drawable_Forms ([others => True]);
   end Set_Up;

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
      --  Only an alef makes the ligature: "ليس" (lam yeh seen) is three
      --  joined letters, not the optional lam-yeh ligature FC44.
      declare
         Laysa : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Utf8 ([Lam, 16#064A#, 16#0633#]));
      begin
         Assert
           (Drawn (Laysa) = Guikit.Bidi.Codepoint_Array'[16#FEB2#, 16#FEF4#, 16#FEDF#],
            "lam yeh seen drawn as" & Image (Drawn (Laysa)));
      end;
      --  Emoji joined by a ZWJ beside Hebrew keep their own cells, as they
      --  do in text that needs no layout.
      declare
         Family : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Utf8 ([16#1F468#, 16#200D#, 16#1F469#, Alef]));
         Wide   : Natural := 0;
      begin
         for Item of Family.Clusters loop
            if Item.Units = 2 then
               Wide := Wide + 1;
            end if;
         end loop;
         Assert (Wide = 2, "each emoji of a ZWJ sequence takes its own two cells:" & Wide'Image);
      end;
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

   procedure Test_Arrows_Follow_The_Screen (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Bidi;
      --  Drawn gimel bet alef: alef is on the right.
      Hebrew : constant String := Utf8 ([Alef, Bet, Gimel]);
      --  "ab", alef bet, " cd": drawn "ab" bet alef " cd", seven columns.
      Mixed  : constant String := "ab" & Utf8 ([Alef, Bet]) & " cd";
      Words  : constant String := Utf8 ([Alef, Bet]) & " " & Utf8 ([Gimel, Alef]);
   begin
      Assert (Caret_Step (Hebrew, 0, Rightward => False) = 2, "left from the right edge passes alef");
      Assert (Caret_Step (Hebrew, 2, Rightward => False) = 4, "and then bet");
      Assert (Caret_Step (Hebrew, 6, Rightward => False) = 6, "nothing lies left of the left edge");
      Assert (Caret_Step (Hebrew, 4, Rightward => True) = 2, "right steps back in the text");
      Assert (Caret_Step (Hebrew, 0, Rightward => True) = 0, "nothing lies right of the right edge");

      --  Walk the mixed line left to right: every stop once, columns never fall.
      declare
         Cursor  : Natural := 0;
         Seen    : array (0 .. Mixed'Length) of Boolean := [others => False];
         Column  : Natural := 0;
         Steps   : Natural := 0;
      begin
         Seen (0) := True;
         loop
            declare
               Next : constant Natural := Caret_Step (Mixed, Cursor, Rightward => True);
            begin
               exit when Next = Cursor;
               Assert (Caret_Column (Mixed, Next) >= Column, "columns never fall at" & Next'Image);
               Assert (not Seen (Next), "each stop once at" & Next'Image);
               Assert (Caret_Step (Mixed, Next, Rightward => False) = Cursor, "left undoes right at" & Next'Image);
               Column := Caret_Column (Mixed, Next);
               Seen (Next) := True;
               Cursor := Next;
               Steps := Steps + 1;
            end;
         end loop;
         Assert (Steps = 7, "eight stops, seven steps:" & Steps'Image);
         Assert (Column = 7, "the walk ends at the right edge");
      end;
      --  Before alef is drawn at alef's right edge, so right of 'b' the
      --  next stop is before bet, between bet and alef.
      Assert (Caret_Step (Mixed, 1, Rightward => True) = 4, "right from 'b' enters the run at its drawn left");
      Assert (Caret_Step (Mixed, 4, Rightward => True) = 2, "and goes on to alef's right edge");

      Assert (Caret_Step (Words, 0, Rightward => False, By_Word => True) = 4, "Ctrl+Left reads on");
      Assert (Caret_Step (Words, 4, Rightward => True, By_Word => True) = 0, "Ctrl+Right reads back");
      Assert (Caret_Step ("ab cd", 0, Rightward => True, By_Word => True) = 2, "Latin words unchanged");
      Assert (Caret_Step ("abc", 1, Rightward => True) = 2, "Latin steps unchanged");
   end Test_Arrows_Follow_The_Screen;

   procedure Test_Ligature_Is_One_Stop (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Bidi;
      --  Lam alef, one ligature cluster of four bytes; then beh before it,
      --  drawn left of it.
      Ligature : constant String := Utf8 ([Lam, Arabic_Alef]);
      Word     : constant String := Utf8 ([Beh, Lam, Arabic_Alef]);
   begin
      Assert (Caret_Step (Ligature, 0, Rightward => False) = 4, "left from the right edge passes the ligature");
      Assert (Caret_Step (Ligature, 0, Rightward => True) = 0, "nothing lies right of it, not its alef");
      Assert (Caret_Step (Ligature, 4, Rightward => True) = 0, "right from the left edge passes it back");
      Assert (Caret_Step (Word, 2, Rightward => True) = 0, "right from before lam goes on to before beh");
      Assert (Caret_Step (Word, 2, Rightward => False) = 6, "left from before lam passes the whole ligature");
   end Test_Ligature_Is_One_Stop;

   --  A font chain with no lam-alef ligature: drawing keeps lam and alef as
   --  two letters, and the caret has to as well.
   function Without_Lam_Alef (Codepoint : Natural) return Boolean is (Codepoint not in 16#FEF5# .. 16#FEFC#);

   --  A font chain drawing every form.
   function Always (Codepoint : Natural) return Boolean is
      pragma Unreferenced (Codepoint);
   begin
      return True;
   end Always;

   procedure Test_Undrawn_Ligature_Is_Two_Stops (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Bidi;
      --  Lam (bytes 0 .. 1) then alef (2 .. 3): drawn right to left, alef
      --  in cell 0 and lam in cell 1 when they are two letters.
      Pair : constant String := Utf8 ([Lam, Arabic_Alef]);
   begin
      Assert
        (Natural (Lay_Out (Pair, Without_Lam_Alef'Access).Clusters.Length) = 2,
         "laid out with the font's answer, the pair is two clusters");
      Assert
        (Caret_Step (Pair, 0, Rightward => False, Has_Glyph => Without_Lam_Alef'Access) = 2,
         "left from the right edge stops between lam and alef");
      Assert
        (Caret_Step (Pair, 2, Rightward => False, Has_Glyph => Without_Lam_Alef'Access) = 4,
         "and then passes the alef");
      Assert (Caret_Step (Pair, 0, Rightward => False) = 4, "with the ligature drawn it is one stop");
      Assert
        (Caret_Column (Pair, 2, Has_Glyph => Without_Lam_Alef'Access) = 1,
         "the caret between them stands between their cells");
      Assert (Caret_Column (Pair, 2) = 2, "inside the ligature it stands at its right edge");
      Assert
        (Cursor_At_Half_Column (Pair, 2, Has_Glyph => Without_Lam_Alef'Access) = 2,
         "a click on the near half of the lam puts the caret after it");
      Assert (Cursor_At_Half_Column (Pair, 2) = 0, "the same click on the ligature is before it");
      Assert
        (Guikit.Text_Fields.Caret_X (Pair, 2, 120, 20, 2, Mirrored => False, Has_Glyph => Without_Lam_Alef'Access)
         = 12,
         "a field passes the query on: the caret is one cell in");
      Assert
        (Guikit.Text_Fields.Cursor_At (Pair, 0, 12, 120, 20, Mirrored => False, Has_Glyph => Without_Lam_Alef'Access)
         = 2,
         "and a click there puts it back between the letters");
   end Test_Undrawn_Ligature_Is_Two_Stops;

   --  What the fonts Guikit.Text loaded draw is recorded in Guikit.Bidi, and
   --  a layout given no Has_Glyph asks it: a caller that passes nothing
   --  still agrees with the drawing.
   procedure Test_Default_Follows_Recorded_Forms (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Bidi;
      Pair     : constant String := Utf8 ([Lam, Arabic_Alef]);
      Coverage : Form_Coverage := [others => True];
   begin
      for Form in 16#FEF5# .. 16#FEFC# loop
         Coverage (Form) := False;
      end loop;
      Set_Drawable_Forms (Coverage);
      Assert (not Can_Draw_Form (16#FEFB#) and then Can_Draw_Form (16#FEFE#), "the recorded forms are answered");
      Assert (Can_Draw_Form (Lam) and then Can_Draw_Form (65), "a code point that is no form is always drawn");
      Assert (Natural (Lay_Out (Pair).Clusters.Length) = 2, "without the ligature the pair is two clusters");
      Assert (Caret_Step (Pair, 0, Rightward => False) = 2, "and the caret stops between lam and alef");
      Assert
        (Guikit.Text_Fields.Caret_X (Pair, 2, 120, 20, 2, Mirrored => False) = 12,
         "a field asked without Has_Glyph puts the caret one cell in");
      Assert
        (Natural (Lay_Out (Pair, Has_Glyph => Always'Access).Clusters.Length) = 1,
         "an explicit Has_Glyph still overrides the record");

      Set_Drawable_Forms ([others => True]);
      Assert (Natural (Lay_Out (Pair).Clusters.Length) = 1, "with the ligature recorded it is one cluster");
   end Test_Default_Follows_Recorded_Forms;

   procedure Test_Wide_Character_Straddling_A_Mirrored_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Text_Fields;
      --  Four two-cell characters in a field five cells (60 pixels) wide:
      --  two of them fit, drawn in the last four cells once mirrored.
      Kanji : constant String := Utf8 ([16#6F22#, 16#5B57#, 16#6F22#, 16#5B57#]);
   begin
      Assert
        (Caret_X (Kanji, 0, 60, 20, 2, Mirrored => True) = 46,
         "the caret before the first character starts where it does, four cells from the end:"
         & Caret_X (Kanji, 0, 60, 20, 2, Mirrored => True)'Image);
      Assert (Caret_X (Kanji, 6, 60, 20, 2, Mirrored => True) = 0, "after the second it is at the field's end");
      for Cursor in 0 .. 2 loop
         Assert
           (Cursor_At (Kanji, 0, Caret_X (Kanji, 3 * Cursor, 60, 20, 2, Mirrored => True), 60, 20, Mirrored => True)
            = 3 * Cursor,
            "a click where the caret is drawn puts it back at" & Natural'Image (3 * Cursor));
      end loop;
   end Test_Wide_Character_Straddling_A_Mirrored_Field;

   procedure Test_Mirrored_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Draw;
      use Guikit.Mirroring;
      Rectangles : Rectangle_Command_Vectors.Vector;
      Triangles  : Triangle_Command_Vectors.Vector;
      Text       : Text_Command_Vectors.Vector;
      Icons      : Icon_Command_Vectors.Vector;
   begin
      Rectangles.Append (Rectangle_Command'(X => 10, Y => 0, Width => 30, Height => 5, others => <>));
      Triangles.Append (Triangle_Command'(X1 => 0.0, X2 => 10.0, X3 => 10.0, others => <>));
      Text.Append (Text_Command'(X => 0, Y => 0, Width => 40, Height => 10, others => <>));
      Text.Append (Text_Command'(X => 0, Y => 0, Width => 40, Height => 10, Scale_To_Box => True, others => <>));
      Text.Append (Text_Command'(X => 0, Y => 0, Width => 10, Height => 10,
                                 Text => Ada.Strings.Unbounded.To_Unbounded_String (">"),
                                 Mirror_Glyph => True, others => <>));
      Text.Append (Text_Command'(X => 0, Y => 0, Width => 10, Height => 10,
                                 Text => Ada.Strings.Unbounded.To_Unbounded_String ("a>"),
                                 Mirror_Glyph => True, others => <>));
      Text.Append (Text_Command'(X => 0, Y => 0, Width => 10, Height => 10,
                                 Text => Ada.Strings.Unbounded.To_Unbounded_String ("("), others => <>));
      --  A fitted symbol wholly past the right edge.
      Text.Append (Text_Command'(X => 120, Y => 0, Width => 10, Height => 10, Scale_To_Box => True,
                                 Text => Ada.Strings.Unbounded.To_Unbounded_String ("x"), others => <>));
      Icons.Append (Icon_Command'(X => 0, Y => 0, Size => 16, others => <>));
      --  Wholly past the right edge, and sticking out past it.
      Icons.Append (Icon_Command'(X => 120, Y => 0, Size => 16, others => <>));
      Icons.Append (Icon_Command'(X => 100, Y => 0, Size => 16, Draw_Width => 30, Draw_Height => 20, others => <>));
      Icons.Append (Icon_Command'(X => 90, Y => 0, Size => 16, others => <>));
      Mirror (Rectangles, 100);
      Mirror (Triangles, 100);
      Mirror (Text, 100);
      Mirror (Icons, 100);
      Assert (Rectangles (1).X = 60, "a box 10 from the left ends 10 from the right");
      Assert (Triangles (1).X1 = 100.0 and then Triangles (1).X2 = 90.0, "a triangle's points are reflected");
      Assert (Text (1).X = 60 and then Text (1).Align_End, "text keeps to the edge its box starts at");
      Assert (not Text (2).Align_End, "text fitted to its box stays centred");
      Assert (Ada.Strings.Unbounded.To_String (Text (3).Text) = "<", "a lone '>' symbol points the other way");
      Assert (Ada.Strings.Unbounded.To_String (Text (4).Text) = "a>", "running text is left to Guikit.Bidi");
      Assert
        (Ada.Strings.Unbounded.To_String (Text (5).Text) = "(",
         "a one-character text that is not a symbol, a query of '(', is shown as typed");
      Assert
        (Text (6).Width = 0 and then Ada.Strings.Unbounded.Length (Text (6).Text) = 0,
         "text wholly past the right edge stays unseen, not drawn at the left");
      Assert (Icons (1).X = 84, "an icon moves with its box");
      Assert
        (Icons (2).Size = 0 and then Icons (2).Draw_Width = 0 and then Icons (2).Draw_Height = 0,
         "an icon wholly past the right edge stays unseen, not drawn at the left");
      Assert
        (Icons (3).Size = 0 and then Icons (3).Draw_Width = 0,
         "so does one starting right at the edge");
      Assert (Icons (4).X = 0 and then Icons (4).Size = 16, "one sticking out past it starts at the left edge");
      Assert (Mirror_X (0, 100) = 99 and then Mirror_X (99, 100) = 0, "the pointer is reflected too");

      --  A box sticking out past the frame is reflected by what shows of it.
      declare
         Wide : Rectangle_Command_Vectors.Vector;
      begin
         Wide.Append (Rectangle_Command'(X => 700, Y => 0, Width => 200, Height => 5, others => <>));
         Wide.Append (Rectangle_Command'(X => 900, Y => 0, Width => 50, Height => 5, others => <>));
         Mirror (Wide, 800);
         Assert
           (Wide (1).X = 0 and then Wide (1).Width = 100,
            "the visible hundred pixels go to the left edge:" & Wide (1).X'Image & Wide (1).Width'Image);
         Assert (Wide (2).Width = 0, "a box wholly past the frame stays unseen");
      end;

      Assert (Reflect_Column (0, 3) = 3 and then Reflect_Column (3, 3) = 0, "columns count from the other end");
      Assert (Reflect_Column (5, 3) = 0, "a column past the drawn text is its far end");
      Assert (Reflect_Half_Column (5, 3) = 0 and then Reflect_Half_Column (0, 3) = 5, "half cells too");
      Assert (Reflect_Half_Column (40, 3) = 0, "a click past the drawn text is before its first half cell");
   end Test_Mirrored_Layout;

   procedure Test_Mirrored_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Text_Fields;
      --  Line height 20: a cell is 12 pixels, so "abc" in a 120-pixel field
      --  is drawn in the last three of its ten cells once mirrored.
      Before_A : constant View := View_Of ("abc", 0, 120, 20, 2, Mirrored => True);
      At_End   : constant View := View_Of ("abc", 3, 120, 20, 2, Mirrored => True);
   begin
      --  Unmirrored, the frame's X 34 to 36 is, mirrored, a rectangle from
      --  36 pixels before the field's (mirrored) end: where 'a' starts.
      Assert (Before_A.Caret_X = 34, "the caret before 'a' starts where 'a' does:" & Before_A'Image);
      Assert (At_End.Caret_X = 0, "the caret at the end stays inside the field");
      Assert (View_Of ("abc", 0, 120, 20, 2, Mirrored => False).Caret_X = 0, "unmirrored, it is at the start");
      Assert
        (Caret_X ("abc", 1, 120, 20, 2, Mirrored => True) = 22,
         "an unscrolled field's caret is reflected the same way");

      Assert (Cursor_At ("abc", 0, 30, 120, 20, Mirrored => True) = 0, "a click on the far half of 'a' is before it");
      Assert (Cursor_At ("abc", 0, 108, 120, 20, Mirrored => True) = 0, "a click past the drawn text is before 'a'");
      Assert (Cursor_At ("abc", 0, 30, 120, 20, Mirrored => False) = 3, "unmirrored, the same click is after 'c'");
      for Cursor in 0 .. 3 loop
         Assert
           (Cursor_At ("abc", 0, Caret_X ("abc", Cursor, 120, 20, 2, Mirrored => True), 120, 20, Mirrored => True)
            = Cursor,
            "a click where the caret is drawn puts it back at" & Cursor'Image);
      end loop;
      Assert (Cursor_At ("xabc", 1, 0, 120, 20, Mirrored => False) = 1, "a scrolled field counts from what shows");
   end Test_Mirrored_Field;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
      Cases  : constant AUnit.Test_Cases.Test_Case_Access := new Bidi_Test_Case;
   begin
      Result.Add_Test (Cases);
      return Result;
   end Suite;

end Guikit_Suite.Bidi;
