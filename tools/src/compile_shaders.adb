with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces;

with Project_Tools.Files;
with Project_Tools.Processes;

--  Regenerate the SPIR-V embedded in guikit-vulkan.adb from the GLSL beside it.
--
--  The shaders are compiled into the body as arrays of 32-bit words, because the
--  library has no assets directory and a caller should not have to ship files
--  next to their binary. That is fine, but for a long time it was ALL there was:
--  the words were committed with no source, so nobody could read what the GPU ran
--  or change it. This keeps the loop -- edit the GLSL, run this, commit both.
--
--  The word arrays this writes are the exact output of glslangValidator, so a run
--  with no shader edit leaves the file untouched.
--
--  Run from anywhere inside the guikit checkout. Requires glslangValidator
--  (Debian/Ubuntu: glslang-tools).
procedure Compile_Shaders is
   use Ada.Strings.Unbounded;

   Tool : constant String := "compile_shaders";

   Failed : exception;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Tool & ": " & Message);
      raise Failed;
   end Fail;

   Root : constant String :=
     Project_Tools.Files.Find_Root_Upward (Ada.Directories.Current_Directory, "guikit.gpr");

   --  Spawning takes a path, not a name to look up on PATH.
   Glslang : constant String := Project_Tools.Processes.Locate_Command ("glslangValidator");

   --  Compile one stage and return its SPIR-V bytes.
   function Compile (Stage : String) return String is
      Source : constant String := Project_Tools.Files.Join (Root, "shaders/guikit." & Stage);
      Output : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "guikit." & Stage & ".spv");
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label   => "glslangValidator " & Stage,
           Dir     => Root,
           Program => Glslang,
           Args    => Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument ("-V"),
               Project_Tools.Processes.Argument (Source),
               Project_Tools.Processes.Argument ("-o"),
               Project_Tools.Processes.Argument (Output)]));
   begin
      if Status /= 0 then
         Fail ("glslangValidator failed for " & Source);
      end if;
      declare
         Bytes : constant String := Project_Tools.Files.Read_Raw_File (Output);
      begin
         Project_Tools.Files.Delete_File_If_Present (Output);
         if Bytes'Length mod 4 /= 0 then
            Fail (Output & " is not a whole number of 32-bit words");
         end if;
         return Bytes;
      end;
   end Compile;

   --  The array declaration for Name holding the little-endian words of Code,
   --  comma-separated and wrapped greedily at 72 columns.
   function Render (Name : String; Code : String) return String is
      Width : constant := 72;
      Text  : Unbounded_String :=
        To_Unbounded_String ("   " & Name & " : aliased constant Shader_Code_Array :=" & ASCII.LF & "     [");
      Line  : Unbounded_String;
      Index : Natural := Code'First;
   begin
      while Index <= Code'Last loop
         declare
            use type Interfaces.Unsigned_32;
            Word : constant Interfaces.Unsigned_32 :=
              Interfaces.Unsigned_32 (Character'Pos (Code (Index)))
              or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Character'Pos (Code (Index + 1))), 8)
              or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Character'Pos (Code (Index + 2))), 16)
              or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Character'Pos (Code (Index + 3))), 24);
            Chunk : constant String :=
              Ada.Strings.Fixed.Trim (Interfaces.Unsigned_32'Image (Word), Ada.Strings.Left)
              & (if Index + 3 < Code'Last then "," else "");
         begin
            if Length (Line) = 0 then
               Line := To_Unbounded_String (Chunk);
            elsif Length (Line) + 1 + Chunk'Length <= Width then
               Append (Line, " " & Chunk);
            else
               Append (Text, To_String (Line) & ASCII.LF & "      ");
               Line := To_Unbounded_String (Chunk);
            end if;
         end;
         Index := Index + 4;
      end loop;
      return To_String (Text) & To_String (Line) & "];";
   end Render;

   --  Body with the declaration of Name replaced by Code's rendering.
   function Replace (Body_Text : String; Name : String; Code : String) return String is
      Start : constant Natural :=
        Ada.Strings.Fixed.Index (Body_Text, "   " & Name & " : aliased constant Shader_Code_Array :=");
   begin
      if Start = 0 then
         Fail ("no declaration of " & Name);
      end if;
      declare
         Close : constant Natural := Ada.Strings.Fixed.Index (Body_Text (Start .. Body_Text'Last), "];");
      begin
         if Close = 0 then
            Fail ("unterminated declaration of " & Name);
         end if;
         return Body_Text (Body_Text'First .. Start - 1) & Render (Name, Code)
           & Body_Text (Close + 2 .. Body_Text'Last);
      end;
   end Replace;

begin
   if Root = "" then
      Fail ("run this inside the guikit checkout (no guikit.gpr above the current directory)");
   end if;
   if Glslang = "" then
      Fail ("glslangValidator not found (install glslang-tools)");
   end if;
   declare
      Path     : constant String := Project_Tools.Files.Join (Root, "src/guikit-vulkan.adb");
      Vertex   : constant String := Compile ("vert");
      Fragment : constant String := Compile ("frag");
      Before   : constant String := Project_Tools.Files.Read_Raw_File (Path);
      After    : constant String :=
        Replace (Replace (Before, "Vertex_Shader_Code", Vertex), "Fragment_Shader_Code", Fragment);
   begin
      if After = Before then
         Ada.Text_IO.Put_Line (Tool & ": " & Path & " already matches the shaders");
      else
         Project_Tools.Files.Write_Raw_File (Path, After);
         Ada.Text_IO.Put_Line (Tool & ": " & Path & " updated");
      end if;
   end;
exception
   when Failed =>
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Compile_Shaders;
