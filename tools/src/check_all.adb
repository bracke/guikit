with Ada.Command_Line;
with Ada.Containers.Indefinite_Vectors;
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

   procedure Require_Alire_GNAT_15 is
      Output : Unbounded_String;
      Status : Integer;
   begin
      Status :=
        Project_Tools.Processes.Run_Status
          (Label   => "GNAT 15 version check",
           Dir     => Root,
           Program => Alr,
           Args    => GNAT.OS_Lib.Argument_List'
             [1 => new String'("exec"),
              2 => new String'("--"),
              3 => new String'("gnatls"),
              4 => new String'("--version")],
           Output  => Output,
           Quiet   => True);

      if Status /= 0 then
         Put_Line
           (Standard_Error,
            "could not run `alr exec -- gnatls --version`");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      elsif Ada.Strings.Fixed.Index (To_String (Output), "GNATLS 15.") = 0 then
         Put_Line
           (Standard_Error,
            "wrong Ada compiler: guikit validation must use Alire GNAT 15; got: "
            & To_String (Output));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Require_Alire_GNAT_15;

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

   --  An exception handler that carries on must say why: re-raise as its
   --  last statement, hand its occurrence on (Guikit.Errors.Note, a
   --  receiver's Failed), or explain in a comment why nothing is lost. A
   --  silent "when others => return False;" hid every Vulkan failure.
   procedure Check_Swallowing_Handlers is
      package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      function Indent (Line : String) return Natural is
      begin
         for Index in Line'Range loop
            if Line (Index) /= ' ' then
               return Index - Line'First;
            end if;
         end loop;
         return Line'Length;
      end Indent;

      function Trimmed (Line : String) return String is (Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both));
      function Blank (Line : String) return Boolean is (Trimmed (Line) = "");
      function Comment (Line : String) return Boolean is
        (Trimmed (Line)'Length >= 2 and then Trimmed (Line) (Trimmed (Line)'First .. Trimmed (Line)'First + 1) = "--");
      function Lower (Text : String) return String renames Ada.Characters.Handling.To_Lower;

      procedure Check_File (Path : String) is
         Text  : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
         Lines : Line_Vectors.Vector;
         First : Positive := Text'First;
      begin
         for Index in Text'Range loop
            if Text (Index) = ASCII.LF then
               Lines.Append (Text (First .. Index - 1));
               First := Index + 1;
            end if;
         end loop;
         for Number in Lines.First_Index .. Lines.Last_Index loop
            declare
               Line   : constant String := Lines (Number);
               Code   : constant String := Lower (Trimmed (Line));
               Arrow  : constant Natural := Ada.Strings.Fixed.Index (Code, "=>");
               Margin : constant Natural := Indent (Line);
               Above  : Natural := 0;
            begin
               if Code'Length > 5 and then Code (Code'First .. Code'First + 4) = "when " and then Arrow > 0 then
                  for Back in reverse Lines.First_Index .. Number - 1 loop
                     if not Blank (Lines (Back)) and then not Comment (Lines (Back))
                       and then Indent (Lines (Back)) < Margin
                     then
                        Above := Back;
                        exit;
                     end if;
                  end loop;
                  if Above > 0 and then Lower (Trimmed (Lines (Above))) = "exception" then
                     declare
                        Colon     : constant Natural := Ada.Strings.Fixed.Index (Code (Code'First .. Arrow), ":");
                        Name      : constant String :=
                          (if Colon = 0 then "" else Trimmed (Code (Code'First + 5 .. Colon - 1)));
                        Others_Of : constant Boolean :=
                          Ada.Strings.Fixed.Index (Code (Code'First .. Arrow), "others") > 0;
                        Body_Code : Unbounded_String := To_Unbounded_String (Code (Arrow + 2 .. Code'Last));
                        Last_Code : Unbounded_String := To_Unbounded_String (Trimmed (Code (Arrow + 2 .. Code'Last)));
                        Explained : Boolean := Number > Lines.First_Index and then Comment (Lines (Number - 1));
                     begin
                        for Below in Number + 1 .. Lines.Last_Index loop
                           exit when not Blank (Lines (Below)) and then Indent (Lines (Below)) <= Margin;
                           if Comment (Lines (Below)) then
                              Explained := True;
                           elsif not Blank (Lines (Below)) then
                              Append (Body_Code, " " & Lower (Trimmed (Lines (Below))));
                              Last_Code := To_Unbounded_String (Lower (Trimmed (Lines (Below))));
                           end if;
                        end loop;
                        declare
                           Last_Text : constant String := To_String (Last_Code);
                           Re_Raised : constant Boolean :=
                             (Last_Text'Length >= 5
                              and then Last_Text (Last_Text'First .. Last_Text'First + 4) = "raise")
                             or else Ada.Strings.Fixed.Index (Last_Text, "reraise_occurrence") > 0;
                           Used : constant Boolean :=
                             Name /= ""
                             and then (Ada.Strings.Fixed.Index (To_String (Body_Code), "(" & Name & ")") > 0
                                       or else Ada.Strings.Fixed.Index (To_String (Body_Code), "(" & Name & ",") > 0
                                       or else Ada.Strings.Fixed.Index (To_String (Body_Code), ", " & Name & ")") > 0);
                        begin
                           if Re_Raised or else Used then
                              null;
                           elsif Name /= "" then
                              Put_Line (Standard_Error, Path & ":" & Natural'Image (Number)
                                        & ": a handler names " & Name & " and carries on without using it");
                              Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                              raise Program_Error;
                           elsif Others_Of and then not Explained then
                              Put_Line (Standard_Error, Path & ":" & Natural'Image (Number)
                                        & ": a 'when others' handler carries on without noting or explaining it");
                              Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                              raise Program_Error;
                           end if;
                        end;
                     end;
                  end if;
               end if;
            end;
         end loop;
      end Check_File;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         Check_File (Ada.Directories.Full_Name (Item));
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Swallowing_Handlers;

   --  Internal layering gate. Each unit in src may only `with` the Guikit.*
   --  units listed in its allowlist -- and each glfw-* unit, besides, only
   --  the Glfw.* units in its own -- checked in its spec, body, platform
   --  bodies (src/platform/*/) and subunits (in src or a platform folder);
   --  the shared helper raises when a unit imports a disallowed one. Every
   --  library unit must have a layer and every subunit an owner that has
   --  one. Allowlists are derived from the current withs, so the gate
   --  locks the layering:
   --    * Guikit, Shared_Bytes, Errors, Frame_Analysis, Input,
   --      Input.Mouse_Buttons, Utf8, Utf8.Editing and Bidi.Data are leaves.
   --    * Guikit.Draw       -> Errors, Shared_Bytes (the pixels its icons carry)
   --    * Guikit.Layout     -> Utf8
   --    * Guikit.Bidi       -> its children (Carets, Data, Levels, Shaping), Utf8
   --    * Guikit.Mirroring  -> Bidi, Draw, Utf8
   --    * Guikit.Text       -> Bidi, Draw, Layout, Shared_Bytes, Utf8
   --    * Guikit.Text_Fields -> Bidi, Draw, Layout, Mirroring, Utf8
   --    * Guikit.Widgets    -> Draw, Layout (label text metrics), Utf8 (text fitting)
   --    * Guikit.Vulkan     -> Draw, Errors, Frame_Analysis, Shared_Bytes
   --      (an icon atlas is uploaded again only when its pixels' serial moves)
   --    * Guikit.Fonts      -> Errors, Text
   --    * the components    -> Draw, Layout, Widgets and the helpers below them
   --    * Glfw.*            -> at most Guikit.Input and Glfw.Input.Keys
   procedure Check_Layering is
      No_Deps : constant Project_Tools.Ada_Source.String_List (1 .. 0) :=
        [others => <>];

      package Stem_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

      --  The units given a layer, so a unit without one is caught.
      Layered : Stem_Vectors.Vector;

      --  Whether the body at Path is a subunit: the first code after its
      --  context clause is `separate`.
      function Is_Subunit (Path : String) return Boolean is
         File      : File_Type;
         In_Clause : Boolean := False;
         Result    : Boolean := False;
      begin
         Open (File, In_File, Path);
         while not End_Of_File (File) loop
            declare
               Raw  : constant String := Get_Line (File);
               Dash : constant Natural := Ada.Strings.Fixed.Index (Raw, "--");
               Code : constant String :=
                 Ada.Characters.Handling.To_Lower
                   (Ada.Strings.Fixed.Trim
                      ((if Dash = 0 then Raw else Raw (Raw'First .. Dash - 1)), Ada.Strings.Both));
               Clause : constant Boolean :=
                 Starts_With (Code, "with ") or else Starts_With (Code, "use ")
                 or else Starts_With (Code, "limited ") or else Starts_With (Code, "private with ")
                 or else Starts_With (Code, "pragma ");
            begin
               if Code = "" then
                  null;
               elsif In_Clause or else Clause then
                  In_Clause := Ada.Strings.Fixed.Index (Code, ";") = 0;
               else
                  Result := Starts_With (Code, "separate");
                  exit;
               end if;
            end;
         end loop;
         Close (File);
         return Result;
      end Is_Subunit;

      --  Whether src holds library unit Stem: its spec, or a body that is
      --  not a subunit.
      function Is_Library_Unit (Stem : String) return Boolean is
        (Project_Tools.Files.File_Exists (Root & "/src/" & Stem & ".ads")
         or else (Project_Tools.Files.File_Exists (Root & "/src/" & Stem & ".adb")
                  and then not Is_Subunit (Root & "/src/" & Stem & ".adb")));

      --  The library unit a subunit file named Stem belongs to: Stem with
      --  its trailing "-name" parts dropped until a library unit is left.
      function Owner_Of (Stem : String) return String is
      begin
         for Cut in reverse Stem'Range loop
            if Stem (Cut) = '-' and then Is_Library_Unit (Stem (Stem'First .. Cut - 1)) then
               return Stem (Stem'First .. Cut - 1);
            end if;
         end loop;
         return "";
      end Owner_Of;

      --  Call Process with each platform folder (src/platform/*/).
      procedure For_Each_Platform_Folder (Process : not null access procedure (Folder : String)) is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
      begin
         if not Project_Tools.Files.Directory_Exists (Root & "/src/platform") then
            return;
         end if;
         Ada.Directories.Start_Search
           (Search, Root & "/src/platform", "*", [Ada.Directories.Directory => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            if Ada.Directories.Simple_Name (Item) not in "." | ".." then
               Process (Ada.Directories.Full_Name (Item));
            end if;
         end loop;
         Ada.Directories.End_Search (Search);
      end For_Each_Platform_Folder;

      --  Require Stem's spec, body, platform bodies (src/platform/*/) and
      --  subunits (Stem-*.adb in src or a platform folder, starting with
      --  `separate`, belonging to Stem rather than to a child) to name only
      --  Allowed of guikit's units -- and, for a glfw-* unit, only
      --  Glfw_Allowed of the Glfw.* units.
      procedure Require_Layer
        (Stem         : String;
         Allowed      : Project_Tools.Ada_Source.String_List;
         Glfw_Allowed : Project_Tools.Ada_Source.String_List := No_Deps)
      is
         Is_Glfw : constant Boolean := Starts_With (Stem, "glfw-");

         procedure Require (Path : String) is
         begin
            Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses (Path, "Guikit.", Allowed);
            if Is_Glfw then
               Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses (Path, "Glfw.", Glfw_Allowed);
            end if;
         end Require;

         --  Stem's subunits in Folder.
         procedure Require_Subunits (Folder : String) is
            Search : Ada.Directories.Search_Type;
            Item   : Ada.Directories.Directory_Entry_Type;
         begin
            Ada.Directories.Start_Search
              (Search, Folder, Stem & "-*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Item);
               declare
                  Path : constant String := Ada.Directories.Full_Name (Item);
               begin
                  if Is_Subunit (Path) and then Owner_Of (Ada.Directories.Base_Name (Path)) = Stem then
                     Require (Path);
                  end if;
               end;
            end loop;
            Ada.Directories.End_Search (Search);
         end Require_Subunits;

         --  Stem's body and subunits in a platform folder.
         procedure Require_Platform (Folder : String) is
         begin
            if Project_Tools.Files.File_Exists (Folder & "/" & Stem & ".adb") then
               Require (Folder & "/" & Stem & ".adb");
            end if;
            Require_Subunits (Folder);
         end Require_Platform;

         Spec : constant String := Root & "/src/" & Stem & ".ads";
         Impl : constant String := Root & "/src/" & Stem & ".adb";
      begin
         Layered.Append (Stem);
         if Project_Tools.Files.File_Exists (Spec) then
            Require (Spec);
         end if;
         if Project_Tools.Files.File_Exists (Impl) then
            Require (Impl);
         end if;
         Require_Subunits (Root & "/src");
         For_Each_Platform_Folder (Require_Platform'Access);
      end Require_Layer;

      --  Every library unit in src has a layer, and every subunit, in src
      --  or a platform folder, an owner: a subunit no unit owns would be
      --  checked by no layer.
      procedure Require_Every_Unit_Layered is
         Missed : Boolean := False;

         procedure Check_Folder (Folder : String) is
            Search : Ada.Directories.Search_Type;
            Item   : Ada.Directories.Directory_Entry_Type;
         begin
            Ada.Directories.Start_Search
              (Search, Folder, "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Item);
               declare
                  Name : constant String := Ada.Directories.Simple_Name (Item);
                  Path : constant String := Ada.Directories.Full_Name (Item);
                  Stem : constant String := Ada.Directories.Base_Name (Name);
               begin
                  if Ada.Directories.Extension (Name) = "adb" and then Is_Subunit (Path) then
                     if Owner_Of (Stem) = "" then
                        Put_Line (Standard_Error, "error: " & Path
                                  & " is a subunit of no library unit in src, so no layer checks it");
                        Missed := True;
                     end if;
                  elsif Is_Library_Unit (Stem) and then not Layered.Contains (Stem) then
                     Put_Line (Standard_Error, "error: " & Path
                               & " belongs to a unit Check_Layering gives no layer");
                     Missed := True;
                  end if;
               end;
            end loop;
            Ada.Directories.End_Search (Search);
         end Check_Folder;
      begin
         Check_Folder (Root & "/src");
         For_Each_Platform_Folder (Check_Folder'Access);
         if Missed then
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Require_Every_Unit_Layered;
   begin
      Require_Layer ("guikit-shared_bytes", No_Deps);
      --  Where any layer reports what it caught: a leaf every layer may name.
      Require_Layer ("guikit-errors", No_Deps);
      Require_Layer
        ("guikit-draw",
         [To_Unbounded_String ("Guikit.Errors"),
          To_Unbounded_String ("Guikit.Shared_Bytes")]);
      Require_Layer ("guikit-frame_analysis", No_Deps);
      Require_Layer ("guikit-input", No_Deps);
      Require_Layer ("guikit-input-mouse_buttons", No_Deps);
      Require_Layer ("guikit-utf8", No_Deps);
      Require_Layer ("guikit-utf8-editing", No_Deps);
      Require_Layer ("guikit-layout", [1 => To_Unbounded_String ("Guikit.Utf8")]);
      --  Right-to-left text is pure text processing: the bidi algorithm and
      --  its children name only their own tables and the UTF-8 helpers,
      --  never anything that draws or lays out.
      Require_Layer
        ("guikit-bidi",
         [To_Unbounded_String ("Guikit.Bidi.Carets"),
          To_Unbounded_String ("Guikit.Bidi.Data"),
          To_Unbounded_String ("Guikit.Bidi.Levels"),
          To_Unbounded_String ("Guikit.Bidi.Shaping"),
          To_Unbounded_String ("Guikit.Utf8")]);
      Require_Layer ("guikit-bidi-data", No_Deps);
      Require_Layer
        ("guikit-bidi-carets",
         [To_Unbounded_String ("Guikit.Utf8"),
          To_Unbounded_String ("Guikit.Utf8.Editing")]);
      Require_Layer ("guikit-bidi-levels", [1 => To_Unbounded_String ("Guikit.Bidi.Data")]);
      Require_Layer ("guikit-bidi-shaping", [1 => To_Unbounded_String ("Guikit.Bidi.Data")]);
      --  Mirroring reflects draw commands and holds the application's
      --  layout direction; text fields place carets and clicks with it.
      Require_Layer
        ("guikit-mirroring",
         [To_Unbounded_String ("Guikit.Bidi"),
          To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Utf8")]);
      Require_Layer
        ("guikit-text",
         [To_Unbounded_String ("Guikit.Bidi"),
          To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Shared_Bytes"),
          To_Unbounded_String ("Guikit.Utf8")]);
      Require_Layer
        ("guikit-text_fields",
         [To_Unbounded_String ("Guikit.Bidi"),
          To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Mirroring"),
          To_Unbounded_String ("Guikit.Utf8")]);
      Require_Layer
        ("guikit-widgets",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Utf8")]);
      Require_Layer
        ("guikit-vulkan",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Errors"),
          To_Unbounded_String ("Guikit.Frame_Analysis"),
          To_Unbounded_String ("Guikit.Shared_Bytes")]);
      --  Font discovery feeds the text layer and reports what it carries on
      --  past; it draws nothing itself.
      Require_Layer
        ("guikit-fonts",
         [To_Unbounded_String ("Guikit.Errors"),
          To_Unbounded_String ("Guikit.Text")]);
      --  The GLFW glue is the bottom layer: it may name only the input
      --  vocabulary (the modifiers it reports), nothing that draws, and of
      --  the GLFW binding only the key vocabulary the modifiers are read
      --  from.
      Require_Layer ("glfw-input-keys-codes", [1 => To_Unbounded_String ("Guikit.Input")]);
      Require_Layer ("glfw-input-keys-layout", No_Deps);
      Require_Layer ("glfw-windows-drop", No_Deps);
      Require_Layer ("glfw-windows-drop-paths", No_Deps);
      Require_Layer ("glfw-windows-icon", No_Deps);
      Require_Layer
        ("glfw-windows-modifiers",
         [1 => To_Unbounded_String ("Guikit.Input")],
         Glfw_Allowed => [1 => To_Unbounded_String ("Glfw.Input.Keys")]);
      Require_Layer ("glfw-windows-native", No_Deps);
      Require_Layer ("glfw-windows-vulkan", No_Deps);
      --  The root package names nothing.
      Require_Layer ("guikit", No_Deps);
      --  Queued input reports what it carries on past and names the mouse
      --  button vocabulary.
      Require_Layer
        ("guikit-input-pending",
         [To_Unbounded_String ("Guikit.Errors"),
          To_Unbounded_String ("Guikit.Input.Mouse_Buttons")]);
      --  The fuzzy matcher the command palette ranks with is text only.
      Require_Layer ("guikit-palette", [1 => To_Unbounded_String ("Guikit.Utf8")]);
      --  The components draw through the widgets and lay out with the
      --  layout helpers; a stateful one may build on a stateless one, never
      --  the reverse, and none of them reaches the backend or the text layer.
      Require_Layer
        ("guikit-segmented",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Widgets")]);
      Require_Layer
        ("guikit-list_panel",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Utf8"),
          To_Unbounded_String ("Guikit.Widgets")]);
      Require_Layer
        ("guikit-menu_tree",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Widgets")]);
      Require_Layer
        ("guikit-tree_panel",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.List_Panel")]);
      Require_Layer
        ("guikit-item_grid",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Text_Fields"),
          To_Unbounded_String ("Guikit.Utf8"),
          To_Unbounded_String ("Guikit.Widgets")]);
      Require_Layer
        ("guikit-command_palette",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Palette"),
          To_Unbounded_String ("Guikit.Shared_Bytes"),
          To_Unbounded_String ("Guikit.Text_Fields"),
          To_Unbounded_String ("Guikit.Utf8"),
          To_Unbounded_String ("Guikit.Utf8.Editing"),
          To_Unbounded_String ("Guikit.Widgets")]);
      Require_Layer
        ("guikit-settings_panel",
         [To_Unbounded_String ("Guikit.Draw"),
          To_Unbounded_String ("Guikit.Layout"),
          To_Unbounded_String ("Guikit.Segmented"),
          To_Unbounded_String ("Guikit.Text_Fields"),
          To_Unbounded_String ("Guikit.Utf8"),
          To_Unbounded_String ("Guikit.Widgets")]);
      Require_Every_Unit_Layered;
   end Check_Layering;

begin
   if not Project_Tools.Files.File_Exists (Root & "/guikit.gpr") then
      Put_Line (Standard_Error, "check_all must be run from the guikit project root or tools directory");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Require_Command ("alr");
   Require_Alire_GNAT_15;

   Check_Line_Lengths;
   Check_Consecutive_Empty_Lines;
   Check_Whitespace;
   Check_GNATdoc_Comments;
   Check_Ada_Keyword_Identifiers;
   Check_AUnit_Test_Registration;
   Check_Ada_Only_Tooling;
   Check_Layering;
   Check_Swallowing_Handlers;
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
