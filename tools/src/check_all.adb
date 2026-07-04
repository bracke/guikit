with Ada.Command_Line;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Ada_Source;
with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;
with Project_Tools.Tree_Checks;
use Project_Tools.Text;

--  Guikit project checks. This mirrors the files check_all helper, but only
--  ports the checks that apply to any Ada crate and points them at the guikit
--  source trees. The Ada_Source helpers are brought in by explicit renames
--  rather than a use clause so that its Unbounded_String subtype cannot become
--  ambiguous against Ada.Strings.Unbounded.
procedure Check_All is
   use Ada.Strings.Unbounded;
   use Ada.Text_IO;
   use type Ada.Directories.File_Kind;

   Max_Line_Length : constant Natural := 120;

   --  Local renames of the Ada_Source helpers keep call sites short without a
   --  use clause (which would collide on Unbounded_String).
   function Token_After (Text : String; Prefix : String) return String
     renames Project_Tools.Ada_Source.Token_After;
   function Is_Ada_Reserved_Word (Name : String) return Boolean
     renames Project_Tools.Ada_Source.Is_Ada_Reserved_Word;
   function Is_Single_Identifier (Text : String) return Boolean
     renames Project_Tools.Ada_Source.Is_Single_Identifier;

   function Project_Root return String is
      Here : constant String := Ada.Directories.Current_Directory;
   begin
      if Ada.Directories.Exists (Here & "/guikit.gpr") then
         return Here;
      elsif Ada.Directories.Exists (Here & "/../guikit.gpr") then
         return Ada.Directories.Full_Name (Here & "/..");
      else
         return Here;
      end if;
   end Project_Root;

   Root : constant String := Project_Root;
   Alr  : constant String := Project_Tools.Processes.Locate_Command ("alr");

   function Is_Text_Project_File (Name : String) return Boolean is
   begin
      return Name = ".gitignore"
        or else Ends_With (Name, ".adb")
        or else Ends_With (Name, ".ads")
        or else Ends_With (Name, ".gpr")
        or else Ends_With (Name, ".h")
        or else Ends_With (Name, ".toml")
        or else Ends_With (Name, ".xml")
        or else Ends_With (Name, ".svg");
   end Is_Text_Project_File;

   function Is_Generated_Directory_Name (Name : String) return Boolean is
   begin
      return Name = "bin" or else Name = "obj";
   end Is_Generated_Directory_Name;

   procedure Require_Command (Name : String) is
   begin
      Project_Tools.Processes.Require_Command
        (Name,
         Name & " is required for the guikit project check tool");
   end Require_Command;

   procedure Run
     (Label   : String;
      Dir     : String;
      Program : String;
      Args    : GNAT.OS_Lib.Argument_List;
      Quiet   : Boolean := False) renames Project_Tools.Processes.Run;

   procedure Check_Line_Lengths_In_File (Path : String) is
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line    : Natural := 1;
      Column  : Natural := 0;
   begin
      for Char of Content loop
         if Char = ASCII.LF then
            Line := Line + 1;
            Column := 0;
         else
            Column := Column + 1;
            if Column > Max_Line_Length then
               Put_Line
                 (Standard_Error,
                  Path & ":" & Natural'Image (Line) & ": line exceeds"
                  & Natural'Image (Max_Line_Length) & " characters");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end if;
      end loop;
   end Check_Line_Lengths_In_File;

   procedure Check_Line_Lengths_In_Tree (Path : String);

   procedure Check_Line_Lengths_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if Project_Tools.Files.File_Exists (Path) then
         Check_Line_Lengths_In_File (Path);
         return;
      elsif not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               case Ada.Directories.Kind (Dir_Entry) is
                  when Ada.Directories.Ordinary_File =>
                     if Is_Text_Project_File (Name) then
                        Check_Line_Lengths_In_File (Full);
                     end if;
                  when Ada.Directories.Directory =>
                     if not Is_Generated_Directory_Name (Name) then
                        Check_Line_Lengths_In_Tree (Full);
                     end if;
                  when Ada.Directories.Special_File =>
                     null;
               end case;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Line_Lengths_In_Tree;

   procedure Check_Line_Lengths is
   begin
      Check_Line_Lengths_In_Tree (Root & "/config");
      Check_Line_Lengths_In_Tree (Root & "/src");
      Check_Line_Lengths_In_Tree (Root & "/tests/tests/src");
      Check_Line_Lengths_In_Tree (Root & "/tools/config");
      Check_Line_Lengths_In_Tree (Root & "/tools/src");
      Check_Line_Lengths_In_File (Root & "/.gitignore");
      Check_Line_Lengths_In_File (Root & "/alire.toml");
      Check_Line_Lengths_In_File (Root & "/guikit.gpr");
      Check_Line_Lengths_In_File (Root & "/tests/.gitignore");
      Check_Line_Lengths_In_File (Root & "/tests/alire.toml");
      Check_Line_Lengths_In_File (Root & "/tests/guikit_tests.gpr");
      Check_Line_Lengths_In_File (Root & "/tools/.gitignore");
      Check_Line_Lengths_In_File (Root & "/tools/alire.toml");
      Check_Line_Lengths_In_File (Root & "/tools/guikit_check_all.gpr");
   end Check_Line_Lengths;

   procedure Check_Consecutive_Empty_Lines_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;
      Empty_Run   : Natural := 0;

      procedure Check_Line (Raw : String) is
      begin
         if Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both) = "" then
            Empty_Run := Empty_Run + 1;
            if Empty_Run > 1 then
               Put_Line
                 (Standard_Error,
                  Path & ":" & Natural'Image (Line_Number) & ": multiple consecutive empty lines");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         else
            Empty_Run := 0;
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Consecutive_Empty_Lines_In_File;

   procedure Check_Consecutive_Empty_Lines_In_Tree (Path : String);

   procedure Check_Consecutive_Empty_Lines_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if Project_Tools.Files.File_Exists (Path) then
         Check_Consecutive_Empty_Lines_In_File (Path);
         return;
      elsif not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               case Ada.Directories.Kind (Dir_Entry) is
                  when Ada.Directories.Ordinary_File =>
                     if Is_Text_Project_File (Name) then
                        Check_Consecutive_Empty_Lines_In_File (Full);
                     end if;
                  when Ada.Directories.Directory =>
                     if not Is_Generated_Directory_Name (Name) then
                        Check_Consecutive_Empty_Lines_In_Tree (Full);
                     end if;
                  when Ada.Directories.Special_File =>
                     null;
               end case;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Consecutive_Empty_Lines_In_Tree;

   procedure Check_Consecutive_Empty_Lines is
   begin
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/config");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/src");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tests/tests/src");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tools/config");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tools/src");
      Check_Consecutive_Empty_Lines_In_File (Root & "/.gitignore");
      Check_Consecutive_Empty_Lines_In_File (Root & "/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/guikit.gpr");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/.gitignore");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/guikit_tests.gpr");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tools/.gitignore");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tools/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tools/guikit_check_all.gpr");
   end Check_Consecutive_Empty_Lines;

   function Is_Whitespace_Checked_File (Name : String) return Boolean is
   begin
      return Name = ".gitignore"
        or else Ends_With (Name, ".adb")
        or else Ends_With (Name, ".ads")
        or else Ends_With (Name, ".gpr")
        or else Ends_With (Name, ".h")
        or else Ends_With (Name, ".toml")
        or else Ends_With (Name, ".xml")
        or else Ends_With (Name, ".svg");
   end Is_Whitespace_Checked_File;

   procedure Check_Whitespace_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Fail (Message : String) is
      begin
         Put_Line
           (Standard_Error,
            Path & ":" & Natural'Image (Line_Number) & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      procedure Check_Line (Raw : String) is
      begin
         if Raw'Length = 0 then
            return;
         end if;

         for Character_Value of Raw loop
            if Character_Value = ASCII.HT then
               Fail ("tab character is not allowed");
            end if;
         end loop;

         if Raw (Raw'Last) = ' ' or else Raw (Raw'Last) = ASCII.HT then
            Fail ("trailing whitespace is not allowed");
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Whitespace_In_File;

   procedure Check_Whitespace_In_Tree (Path : String);

   procedure Check_Whitespace_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if Project_Tools.Files.File_Exists (Path) then
         Check_Whitespace_In_File (Path);
         return;
      elsif not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               case Ada.Directories.Kind (Dir_Entry) is
                  when Ada.Directories.Ordinary_File =>
                     if Is_Whitespace_Checked_File (Name) then
                        Check_Whitespace_In_File (Full);
                     end if;
                  when Ada.Directories.Directory =>
                     if not Is_Generated_Directory_Name (Name) then
                        Check_Whitespace_In_Tree (Full);
                     end if;
                  when Ada.Directories.Special_File =>
                     null;
               end case;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Whitespace_In_Tree;

   procedure Check_Whitespace is
   begin
      Check_Whitespace_In_Tree (Root & "/config");
      Check_Whitespace_In_Tree (Root & "/src");
      Check_Whitespace_In_Tree (Root & "/tests/tests/src");
      Check_Whitespace_In_Tree (Root & "/tools/config");
      Check_Whitespace_In_Tree (Root & "/tools/src");
      Check_Whitespace_In_File (Root & "/.gitignore");
      Check_Whitespace_In_File (Root & "/alire.toml");
      Check_Whitespace_In_File (Root & "/guikit.gpr");
      Check_Whitespace_In_File (Root & "/tests/.gitignore");
      Check_Whitespace_In_File (Root & "/tests/alire.toml");
      Check_Whitespace_In_File (Root & "/tests/guikit_tests.gpr");
      Check_Whitespace_In_File (Root & "/tools/.gitignore");
      Check_Whitespace_In_File (Root & "/tools/alire.toml");
      Check_Whitespace_In_File (Root & "/tools/guikit_check_all.gpr");
   end Check_Whitespace;

   procedure Check_GNATdoc_In_File (Path : String) is
   begin
      Project_Tools.Ada_Source.Require_Public_GNATdoc_Tags (Path);
   end Check_GNATdoc_In_File;

   procedure Check_GNATdoc_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_GNATdoc_In_Tree (Full);
               end if;
            elsif Name'Length >= 4 and then Name (Name'Last - 3 .. Name'Last) = ".ads" then
               Check_GNATdoc_In_File (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_GNATdoc_In_Tree;

   procedure Check_GNATdoc_Comments is
   begin
      Check_GNATdoc_In_Tree (Root & "/src");
      Check_GNATdoc_In_Tree (Root & "/tests/tests/src");
      Check_GNATdoc_In_Tree (Root & "/tools/src");
   end Check_GNATdoc_Comments;

   procedure Check_Ada_Keyword_Identifier_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Fail (Name : String) is
      begin
         Put_Line
           (Standard_Error,
            Path & ":" & Natural'Image (Line_Number)
            & ": Ada reserved word used as identifier: " & Name);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      procedure Check_Name (Name : String) is
      begin
         if Name /= "" and then Is_Ada_Reserved_Word (Name) then
            Fail (Name);
         end if;
      end Check_Name;

      procedure Check_Line (Raw : String) is
         Line     : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Colon    : constant Natural := Ada.Strings.Fixed.Index (Line, ":");
         Assign   : constant Natural := Ada.Strings.Fixed.Index (Line, "=>");
      begin
         if Line = "" or else Starts_With (Line, "--") then
            return;
         elsif Starts_With (Line, "overriding function ") then
            Check_Name (Token_After (Line, "overriding function "));
         elsif Starts_With (Line, "overriding procedure ") then
            Check_Name (Token_After (Line, "overriding procedure "));
         elsif Starts_With (Line, "function ") then
            Check_Name (Token_After (Line, "function "));
         elsif Starts_With (Line, "procedure ") then
            Check_Name (Token_After (Line, "procedure "));
         elsif Starts_With (Line, "type ") then
            Check_Name (Token_After (Line, "type "));
         elsif Starts_With (Line, "subtype ") then
            Check_Name (Token_After (Line, "subtype "));
         elsif Starts_With (Line, "package body ") then
            null;
         elsif Starts_With (Line, "package ") then
            Check_Name (Token_After (Line, "package "));
         elsif Colon > 0 and then (Assign = 0 or else Colon < Assign) then
            declare
               Name : constant String :=
                 Ada.Strings.Fixed.Trim (Line (Line'First .. Colon - 1), Ada.Strings.Both);
            begin
               if Is_Single_Identifier (Name) then
                  Check_Name (Name);
               end if;
            end;
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Ada_Keyword_Identifier_In_File;

   procedure Check_Ada_Keyword_Identifiers_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_Ada_Keyword_Identifiers_In_Tree (Full);
               end if;
            elsif Name'Length >= 4
              and then (Name (Name'Last - 3 .. Name'Last) = ".ads"
                        or else Name (Name'Last - 3 .. Name'Last) = ".adb")
            then
               Check_Ada_Keyword_Identifier_In_File (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Ada_Keyword_Identifiers_In_Tree;

   procedure Check_Ada_Keyword_Identifiers is
   begin
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/src");
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/tests/tests/src");
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/tools/src");
   end Check_Ada_Keyword_Identifiers;

   procedure Check_AUnit_Test_Registration is
   begin
      Project_Tools.AUnit_Checks.Require_Registered_Test_Packages
        (Test_Dir         => Root & "/tests/tests/src",
         Spec_Pattern     => "guikit_suite-*.ads",
         Suite_Path       => Root & "/tests/tests/src/guikit_suite.adb",
         Suite_Add_Prefix => "Result.Add_Test (",
         Suite_Add_Suffix => ".Suite)",
         Section_Marker   => "function Suite");
   end Check_AUnit_Test_Registration;

   function Has_Non_Ada_Tooling_Extension (Name : String) return Boolean is
      Lower_Name : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      --  Python (.py/.pyc/__pycache__) is owned by
      --  Project_Tools.Tree_Checks.Check_No_Generated_Python; see
      --  Check_Ada_Only_Tooling below.
      return
        Ends_With (Lower_Name, ".sh")
        or else Ends_With (Lower_Name, ".bash")
        or else Ends_With (Lower_Name, ".zsh")
        or else Ends_With (Lower_Name, ".fish")
        or else Ends_With (Lower_Name, ".ps1")
        or else Ends_With (Lower_Name, ".bat")
        or else Ends_With (Lower_Name, ".cmd")
        or else Ends_With (Lower_Name, ".pl")
        or else Ends_With (Lower_Name, ".rb")
        or else Ends_With (Lower_Name, ".awk")
        or else Ends_With (Lower_Name, ".sed")
        or else Ends_With (Lower_Name, ".lua")
        or else Ends_With (Lower_Name, ".php")
        or else Ends_With (Lower_Name, ".js")
        or else Ends_With (Lower_Name, ".ts");
   end Has_Non_Ada_Tooling_Extension;

   function Has_Parser_Generator_Extension (Name : String) return Boolean is
      Lower_Name : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      return
        Ends_With (Lower_Name, ".y")
        or else Ends_With (Lower_Name, ".yy")
        or else Ends_With (Lower_Name, ".l")
        or else Ends_With (Lower_Name, ".ll")
        or else Ends_With (Lower_Name, ".g4")
        or else Ends_With (Lower_Name, ".peg");
   end Has_Parser_Generator_Extension;

   function Has_Shebang (Path : String) return Boolean is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 2);
      Last   : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if not Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Get_Line (File, Buffer, Last);
      end if;
      Ada.Text_IO.Close (File);
      return Last = 2 and then Buffer = "#!";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return False;
   end Has_Shebang;

   procedure Check_Ada_Only_Tooling_In_Tree (Path : String);

   procedure Check_Ada_Only_Tooling_File
     (Name : String;
      Full : String) is
   begin
      if Has_Non_Ada_Tooling_Extension (Name) then
         Put_Line (Standard_Error, Full & ": non-Ada helper tooling is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      elsif Has_Parser_Generator_Extension (Name) then
         Put_Line (Standard_Error, Full & ": external parser generator input is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      elsif Has_Shebang (Full) then
         Put_Line (Standard_Error, Full & ": shebang helper tooling is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Check_Ada_Only_Tooling_File;

   procedure Check_Ada_Only_Tooling_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_Ada_Only_Tooling_In_Tree (Full);
               end if;
            else
               Check_Ada_Only_Tooling_File (Name, Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Ada_Only_Tooling_In_Tree;

   procedure Check_Ada_Only_Tooling_At_Project_Root is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      Ada.Directories.Start_Search
        (Search,
         Directory => Root,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => False,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            Check_Ada_Only_Tooling_File (Name, Full);
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Ada_Only_Tooling_At_Project_Root;

   procedure Check_Ada_Only_Tooling is
      Python_Errors : Natural := 0;
   begin
      Check_Ada_Only_Tooling_At_Project_Root;
      Check_Ada_Only_Tooling_In_Tree (Root & "/config");
      Check_Ada_Only_Tooling_In_Tree (Root & "/src");
      Check_Ada_Only_Tooling_In_Tree (Root & "/tests");
      Check_Ada_Only_Tooling_In_Tree (Root & "/tools");

      --  Reject generated Python artifacts (.py/.pyc/__pycache__) with the
      --  shared Tree_Checks helper instead of a local reimplementation.
      Project_Tools.Tree_Checks.Check_No_Generated_Python (Python_Errors, Root & "/config");
      Project_Tools.Tree_Checks.Check_No_Generated_Python (Python_Errors, Root & "/src");
      Project_Tools.Tree_Checks.Check_No_Generated_Python (Python_Errors, Root & "/tests");
      Project_Tools.Tree_Checks.Check_No_Generated_Python (Python_Errors, Root & "/tools");
      if Python_Errors > 0 then
         raise Program_Error;
      end if;
   end Check_Ada_Only_Tooling;

   --  Internal layering gate. Each Guikit.* package may only `with` the
   --  Guikit.* units listed in its allowlist; the shared helper raises when a
   --  package imports a disallowed sibling. Allowlists are derived from the
   --  current internal withs, so the gate passes as-is and locks the layering:
   --    * Guikit.Draw / Frame_Analysis / Input / Utf8 are leaves (no deps).
   --    * Guikit.Layout  -> Guikit.Utf8
   --    * Guikit.Widgets -> Guikit.Draw
   --    * Guikit.Vulkan  -> Guikit.Draw, Guikit.Frame_Analysis
   procedure Check_Layering is
      No_Deps : constant Project_Tools.Ada_Source.String_List (1 .. 0) :=
        [others => <>];

      procedure Require_Layer
        (Stem    : String;
         Allowed : Project_Tools.Ada_Source.String_List)
      is
         Spec : constant String := Root & "/src/" & Stem & ".ads";
         Impl : constant String := Root & "/src/" & Stem & ".adb";
      begin
         if Project_Tools.Files.File_Exists (Spec) then
            Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
              (Spec, "Guikit.", Allowed);
         end if;
         if Project_Tools.Files.File_Exists (Impl) then
            Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
              (Impl, "Guikit.", Allowed);
         end if;
      end Require_Layer;
   begin
      Require_Layer ("guikit-draw", No_Deps);
      Require_Layer ("guikit-frame_analysis", No_Deps);
      Require_Layer ("guikit-input", No_Deps);
      Require_Layer ("guikit-utf8", No_Deps);
      Require_Layer ("guikit-layout", [1 => To_Unbounded_String ("Guikit.Utf8")]);
      Require_Layer ("guikit-widgets", [1 => To_Unbounded_String ("Guikit.Draw")]);
      Require_Layer
        ("guikit-vulkan",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Frame_Analysis")]);
   end Check_Layering;

begin
   if not Project_Tools.Files.File_Exists (Root & "/guikit.gpr") then
      Put_Line (Standard_Error, "check_all must be run from the guikit project root or tools directory");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Require_Command ("alr");

   Check_Line_Lengths;
   Check_Consecutive_Empty_Lines;
   Check_Whitespace;
   Check_GNATdoc_Comments;
   Check_Ada_Keyword_Identifiers;
   Check_AUnit_Test_Registration;
   Check_Ada_Only_Tooling;
   Check_Layering;
   Run ("guikit build", Root, Alr, [1 => new String'("build")]);
   Run ("tests build", Root & "/tests", Alr, [1 => new String'("build")]);
   Run ("AUnit tests", Root & "/tests", "./bin/guikit_tests", []);

   Put_Line ("guikit project checks passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when Program_Error =>
      null;
   when E : others =>
      Put_Line
        (Standard_Error,
         "guikit project checks failed: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Check_All;
