with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

--  Writes src/guikit-bidi-data.ads from the Unicode character database: the
--  bidi class of every code point, the mirrored glyph and bracket pairs the
--  bidi algorithm needs, and the Arabic joining types and presentation forms
--  the shaper needs.
--
--  Usage: generate_bidi_tables <ucd directory> <output file>
--
--  The UCD directory holds UnicodeData.txt, BidiMirroring.txt,
--  BidiBrackets.txt, ArabicShaping.txt and extracted/DerivedBidiClass.txt, all
--  from the one Unicode version the tables are meant to follow.
procedure Generate_Bidi_Tables is

   use Ada.Strings.Unbounded;

   Last_Code : constant := 16#10_FFFF#;

   type Class_Name is
     (L, R, AL, EN, ES, ET, AN, CS, NSM, BN, B, S, WS, ON,
      LRE, LRO, RLE, RLO, PDF, LRI, RLI, FSI, PDI);

   type Join_Name is (U, T, D, R_Join, L_Join, C);

   type Class_Table is array (0 .. Last_Code) of Class_Name;
   type Join_Table is array (0 .. Last_Code) of Join_Name;
   type Category_Table is array (0 .. Last_Code) of String (1 .. 2);

   type Class_Access is access Class_Table;
   type Join_Access is access Join_Table;
   type Category_Access is access Category_Table;

   Classes    : constant Class_Access := new Class_Table'[others => L];
   Joins      : constant Join_Access := new Join_Table'[others => U];
   Categories : constant Category_Access := new Category_Table'[others => "Cn"];

   type Forms is record
      Isolated, Final, Initial, Medial : Natural := 0;
   end record;
   type Form_Table is array (0 .. Last_Code) of Forms;
   type Form_Access is access Form_Table;
   Shapes : constant Form_Access := new Form_Table'[others => (others => 0)];

   --  Lam-alef ligatures, by alef.
   Ligatures : constant Form_Access := new Form_Table'[others => (others => 0)];

   Directory : constant String := Ada.Command_Line.Argument (1);
   Output    : Ada.Text_IO.File_Type;

   function Trim (Value : String) return String is
     (Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both));

   function Hex (Value : String) return Natural is
     (Natural'Value ("16#" & Trim (Value) & "#"));

   function Image (Value : Natural) return String is
      Digits_Of : constant String := "0123456789ABCDEF";
      Result    : String (1 .. 6) := [others => '0'];
      Rest      : Natural := Value;
   begin
      for Index in reverse Result'Range loop
         Result (Index) := Digits_Of (Rest mod 16 + 1);
         Rest := Rest / 16;
      end loop;
      return "16#" & Result & "#";
   end Image;

   --  The fields of a data line with its comment removed, split at ';'.
   type Field_List is array (1 .. 16) of Unbounded_String;

   procedure Split (Line : String; Fields : out Field_List; Count : out Natural) is
      Hash  : constant Natural := Ada.Strings.Fixed.Index (Line, "#");
      Body_Text : constant String := (if Hash = 0 then Line else Line (Line'First .. Hash - 1));
      Start : Positive := Body_Text'First;
   begin
      Fields := [others => Null_Unbounded_String];
      Count := 0;
      if Trim (Body_Text) = "" then
         return;
      end if;
      for Index in Body_Text'Range loop
         if Body_Text (Index) = ';' then
            Count := Count + 1;
            Fields (Count) := To_Unbounded_String (Trim (Body_Text (Start .. Index - 1)));
            Start := Index + 1;
         end if;
      end loop;
      Count := Count + 1;
      Fields (Count) := To_Unbounded_String (Trim (Body_Text (Start .. Body_Text'Last)));
   end Split;

   procedure Code_Range (Text : String; First, Last : out Natural) is
      Dots : constant Natural := Ada.Strings.Fixed.Index (Text, "..");
   begin
      if Dots = 0 then
         First := Hex (Text);
         Last := First;
      else
         First := Hex (Text (Text'First .. Dots - 1));
         Last := Hex (Text (Dots + 2 .. Text'Last));
      end if;
   end Code_Range;

   function Class_Of_Long_Name (Name : String) return Class_Name is
   begin
      if Name = "Left_To_Right" then
         return L;
      elsif Name = "Right_To_Left" then
         return R;
      elsif Name = "Arabic_Letter" then
         return AL;
      elsif Name = "European_Terminator" then
         return ET;
      elsif Name = "Boundary_Neutral" then
         return BN;
      else
         raise Constraint_Error with "unknown_default_class=" & Name;
      end if;
   end Class_Of_Long_Name;

   procedure Read_Classes is
      File   : Ada.Text_IO.File_Type;
      Fields : Field_List;
      Count  : Natural;
      First, Last : Natural;
      Missing : constant String := "# @missing:";
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Directory & "/extracted/DerivedBidiClass.txt");
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            if Line'Length > Missing'Length
              and then Line (Line'First .. Line'First + Missing'Length - 1) = Missing
            then
               Split (Line (Line'First + Missing'Length .. Line'Last), Fields, Count);
               Code_Range (To_String (Fields (1)), First, Last);
               Classes (First .. Last) := [others => Class_Of_Long_Name (To_String (Fields (2)))];
            else
               Split (Line, Fields, Count);
               if Count >= 2 then
                  Code_Range (To_String (Fields (1)), First, Last);
                  Classes (First .. Last) := [others => Class_Name'Value (To_String (Fields (2)))];
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Read_Classes;

   procedure Read_Unicode_Data is
      File   : Ada.Text_IO.File_Type;
      Fields : Field_List;
      Count  : Natural;
      Range_Start : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Directory & "/UnicodeData.txt");
      while not Ada.Text_IO.End_Of_File (File) loop
         Split (Ada.Text_IO.Get_Line (File), Fields, Count);
         if Count >= 6 then
            declare
               Code      : constant Natural := Hex (To_String (Fields (1)));
               Name      : constant String := To_String (Fields (2));
               Category  : constant String := To_String (Fields (3));
               Decompose : constant String := To_String (Fields (6));
               Space_At  : constant Natural := Ada.Strings.Fixed.Index (Decompose, " ");
            begin
               if Ada.Strings.Fixed.Index (Name, ", First>") > 0 then
                  Range_Start := Code;
               elsif Ada.Strings.Fixed.Index (Name, ", Last>") > 0 then
                  Categories (Range_Start .. Code) := [others => Category];
               else
                  Categories (Code) := Category;
               end if;

               if Decompose'Length > 0 and then Decompose (Decompose'First) = '<' and then Space_At > 0 then
                  declare
                     Tag   : constant String := Decompose (Decompose'First .. Space_At - 1);
                     Parts : constant String := Trim (Decompose (Space_At + 1 .. Decompose'Last));
                     Gap   : constant Natural := Ada.Strings.Fixed.Index (Parts, " ");
                  begin
                     if Gap = 0 then
                        declare
                           Base : constant Natural := Hex (Parts);
                        begin
                           if Tag = "<isolated>" then
                              Shapes (Base).Isolated := Code;
                           elsif Tag = "<final>" then
                              Shapes (Base).Final := Code;
                           elsif Tag = "<initial>" then
                              Shapes (Base).Initial := Code;
                           elsif Tag = "<medial>" then
                              Shapes (Base).Medial := Code;
                           end if;
                        end;
                     elsif Hex (Parts (Parts'First .. Gap - 1)) = 16#0644#
                       and then Ada.Strings.Fixed.Index (Parts (Gap + 1 .. Parts'Last), " ") = 0
                     then
                        declare
                           Alef : constant Natural := Hex (Parts (Gap + 1 .. Parts'Last));
                        begin
                           if Tag = "<isolated>" then
                              Ligatures (Alef).Isolated := Code;
                           elsif Tag = "<final>" then
                              Ligatures (Alef).Final := Code;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
   end Read_Unicode_Data;

   procedure Read_Joining is
      File   : Ada.Text_IO.File_Type;
      Fields : Field_List;
      Count  : Natural;
   begin
      --  ArabicShaping.txt: unlisted Mn, Me and Cf are transparent, the rest
      --  non-joining.
      for Code in Categories'Range loop
         if Categories (Code) in "Mn" | "Me" | "Cf" then
            Joins (Code) := T;
         end if;
      end loop;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Directory & "/ArabicShaping.txt");
      while not Ada.Text_IO.End_Of_File (File) loop
         Split (Ada.Text_IO.Get_Line (File), Fields, Count);
         if Count >= 3 then
            declare
               Code : constant Natural := Hex (To_String (Fields (1)));
               Kind : constant String := To_String (Fields (3));
            begin
               Joins (Code) :=
                 (if Kind = "U" then U
                  elsif Kind = "T" then T
                  elsif Kind = "D" then D
                  elsif Kind = "R" then R_Join
                  elsif Kind = "L" then L_Join
                  elsif Kind = "C" then C
                  else raise Constraint_Error with "unknown_joining_type=" & Kind);
            end;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
   end Read_Joining;

   procedure Put (Text : String) is
   begin
      Ada.Text_IO.Put_Line (Output, Text);
   end Put;

   --  Writes entries three or four to a line, each followed by a comma except
   --  the last.
   Pending : Unbounded_String;
   Written : Natural := 0;

   procedure Entry_Item (Text : String; Total : Natural) is
   begin
      Written := Written + 1;
      if Length (Pending) > 0 and then Length (Pending) + Text'Length + 2 > 112 then
         Put ("      " & To_String (Pending));
         Pending := Null_Unbounded_String;
      end if;
      if Length (Pending) > 0 then
         Append (Pending, " ");
      end if;
      Append (Pending, Text & (if Written = Total then "" else ","));
      if Written = Total then
         Put ("      " & To_String (Pending));
         Pending := Null_Unbounded_String;
         Written := 0;
      end if;
   end Entry_Item;

   procedure Write_Classes is
      Total : Natural := 0;
      procedure Each (Emit : Boolean) is
         Start : Natural := 0;
      begin
         for Code in 1 .. Last_Code + 1 loop
            if Code > Last_Code or else Classes (Code) /= Classes (Start) then
               if Classes (Start) /= L then
                  if Emit then
                     Entry_Item
                       ("(" & Image (Start) & ", " & Image (Code - 1) & ", "
                        & Class_Name'Image (Classes (Start)) & ")",
                        Total);
                  else
                     Total := Total + 1;
                  end if;
               end if;
               Start := Code;
            end if;
         end loop;
      end Each;
   begin
      Each (Emit => False);
      Put ("   --  Every code point not in a range here is L.");
      Put ("   Classes : constant Class_Range_Array :=");
      Put ("     [");
      Each (Emit => True);
      Put ("     ];");
      Put ("");
   end Write_Classes;

   procedure Write_Pairs (Name, File_Name : String; With_Kind : Boolean) is
      File   : Ada.Text_IO.File_Type;
      Fields : Field_List;
      Count  : Natural;
      Items  : array (1 .. 2_000) of Unbounded_String;
      Used   : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Directory & "/" & File_Name);
      while not Ada.Text_IO.End_Of_File (File) loop
         Split (Ada.Text_IO.Get_Line (File), Fields, Count);
         if Count >= 2 then
            Used := Used + 1;
            if With_Kind then
               Items (Used) := To_Unbounded_String
                 ("(" & Image (Hex (To_String (Fields (1)))) & ", " & Image (Hex (To_String (Fields (2))))
                  & ", " & (if To_String (Fields (3)) = "o" then "Opening" else "Closing") & ")");
            else
               Items (Used) := To_Unbounded_String
                 ("(" & Image (Hex (To_String (Fields (1)))) & ", " & Image (Hex (To_String (Fields (2)))) & ")");
            end if;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      Put ("   " & Name & " : constant " & (if With_Kind then "Bracket_Array" else "Pair_Array") & " :=");
      Put ("     [");
      for Index in 1 .. Used loop
         Entry_Item (To_String (Items (Index)), Used);
      end loop;
      Put ("     ];");
      Put ("");
   end Write_Pairs;

   function Join_Image (Kind : Join_Name) return String is
     (case Kind is
         when U => "Non_Joining", when T => "Transparent", when D => "Dual",
         when R_Join => "Right", when L_Join => "Left", when C => "Causing");

   procedure Write_Joins is
      Total : Natural := 0;
      procedure Each (Emit : Boolean) is
         Start : Natural := 0;
      begin
         for Code in 1 .. Last_Code + 1 loop
            if Code > Last_Code or else Joins (Code) /= Joins (Start) then
               if Joins (Start) /= U then
                  if Emit then
                     Entry_Item
                       ("(" & Image (Start) & ", " & Image (Code - 1) & ", " & Join_Image (Joins (Start)) & ")",
                        Total);
                  else
                     Total := Total + 1;
                  end if;
               end if;
               Start := Code;
            end if;
         end loop;
      end Each;
   begin
      Each (Emit => False);
      Put ("   --  Every code point not in a range here is Non_Joining.");
      Put ("   Joins : constant Join_Range_Array :=");
      Put ("     [");
      Each (Emit => True);
      Put ("     ];");
      Put ("");
   end Write_Joins;

   procedure Write_Forms (Name : String; Table : Form_Table) is
      Total : Natural := 0;
   begin
      for Code in Table'Range loop
         if Table (Code) /= (others => 0) then
            Total := Total + 1;
         end if;
      end loop;
      Put ("   " & Name & " : constant Form_Array :=");
      Put ("     [");
      for Code in Table'Range loop
         if Table (Code) /= (others => 0) then
            Entry_Item
              ("(" & Image (Code) & ", " & Image (Table (Code).Isolated) & ", " & Image (Table (Code).Final)
               & ", " & Image (Table (Code).Initial) & ", " & Image (Table (Code).Medial) & ")",
               Total);
         end if;
      end loop;
      Put ("     ];");
      Put ("");
   end Write_Forms;

   Version : Unbounded_String;

   procedure Read_Version is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Directory & "/extracted/DerivedBidiClass.txt");
      declare
         Line : constant String := Ada.Text_IO.Get_Line (File);
         Dash : constant Natural := Ada.Strings.Fixed.Index (Line, "-");
         Dot  : constant Natural := Ada.Strings.Fixed.Index (Line, ".txt");
      begin
         Version := To_Unbounded_String (Line (Dash + 1 .. Dot - 1));
      end;
      Ada.Text_IO.Close (File);
   end Read_Version;

begin
   Read_Version;
   Read_Classes;
   Read_Unicode_Data;
   Read_Joining;

   Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (2));
   Put ("--  Generated by tools/src/generate_bidi_tables.adb from the Unicode " & To_String (Version));
   Put ("--  character database. Do not edit: run the generator again.");
   Put ("private package Guikit.Bidi.Data is");
   Put ("");
   Put ("   Unicode_Version : constant String := """ & To_String (Version) & """;");
   Put ("");
   Put ("   type Class_Range is record");
   Put ("      First, Last : Natural;");
   Put ("      Class       : Bidi_Class;");
   Put ("   end record;");
   Put ("   type Class_Range_Array is array (Positive range <>) of Class_Range;");
   Put ("");
   Put ("   type Pair is record");
   Put ("      From, To : Natural;");
   Put ("   end record;");
   Put ("   type Pair_Array is array (Positive range <>) of Pair;");
   Put ("");
   Put ("   type Bracket_Kind is (Opening, Closing);");
   Put ("   type Bracket is record");
   Put ("      Code, Pair : Natural;");
   Put ("      Kind       : Bracket_Kind;");
   Put ("   end record;");
   Put ("   type Bracket_Array is array (Positive range <>) of Bracket;");
   Put ("");
   Put ("   type Joining_Type is (Non_Joining, Transparent, Dual, Right, Left, Causing);");
   Put ("   type Join_Range is record");
   Put ("      First, Last : Natural;");
   Put ("      Kind        : Joining_Type;");
   Put ("   end record;");
   Put ("   type Join_Range_Array is array (Positive range <>) of Join_Range;");
   Put ("");
   Put ("   --  The presentation forms of one letter (or, in Lam_Alef, of lam");
   Put ("   --  followed by this alef); 0 where there is none.");
   Put ("   type Form is record");
   Put ("      Code, Isolated, Final, Initial, Medial : Natural;");
   Put ("   end record;");
   Put ("   type Form_Array is array (Positive range <>) of Form;");
   Put ("");
   Write_Classes;
   Write_Pairs ("Mirrors", "BidiMirroring.txt", With_Kind => False);
   Write_Pairs ("Brackets", "BidiBrackets.txt", With_Kind => True);
   Write_Joins;
   Write_Forms ("Shapes", Shapes.all);
   Write_Forms ("Lam_Alef", Ligatures.all);
   Put ("end Guikit.Bidi.Data;");
   Ada.Text_IO.Close (Output);
end Generate_Bidi_Tables;
