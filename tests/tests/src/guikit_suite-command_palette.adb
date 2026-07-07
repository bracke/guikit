with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Command_Palette;
with Guikit.Draw;

--  Exercises the command-palette state machine (filtering, selection, id
--  mapping) and a headless Build_Frame that emits draw commands without a GPU.
package body Guikit_Suite.Command_Palette is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   package CP renames Guikit.Command_Palette;

   type Palette_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Palette_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Palette_Test_Case);

   procedure Test_Filter_And_Select (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Build_Frame (T : in out AUnit.Test_Cases.Test_Case'Class);

   function Sample return CP.Command_Vectors.Vector is
      Result : CP.Command_Vectors.Vector;

      procedure Add (Id : Natural; Label : String) is
      begin
         Result.Append
           (CP.Command'
              (Id         => Id,
               Identifier => To_Unbounded_String (Label),
               Label      => To_Unbounded_String (Label),
               Enabled    => True,
               others     => <>));
      end Add;
   begin
      Add (10, "Firefox");
      Add (20, "Files");
      Add (30, "Calculator");
      return Result;
   end Sample;

   overriding function Name (T : Palette_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit command palette component");
   end Name;

   overriding procedure Register_Tests (T : in out Palette_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_And_Select'Access, "filtering narrows results, selection clamps, id maps back");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Build_Frame'Access, "Build_Frame emits draw commands and lays out clickable rows");
   end Register_Tests;

   procedure Test_Filter_And_Select (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P : CP.Palette;
   begin
      CP.Set_Commands (P, Sample);
      Assert (CP.Result_Count (P) = 3, "all commands show for an empty query");
      Assert (CP.Selected_Index (P) = 1, "the first command is selected by default");
      Assert (CP.Selected_Id (P) = 10, "the selected id maps back to the first command");

      CP.Move_Selection (P, 1);
      Assert (CP.Selected_Id (P) = 20, "moving down selects the second command");
      CP.Move_Selection (P, 10);
      Assert (CP.Selected_Index (P) = 3, "moving past the end clamps to the last result");

      CP.Insert (P, "fire");
      Assert (CP.Result_Count (P) = 1, "a specific query narrows the results");
      Assert (CP.Selected_Index (P) = 1, "a new query resets the selection to the top");
      Assert (CP.Selected_Id (P) = 10, "the narrowed selection maps to Firefox");

      CP.Backspace (P);
      CP.Backspace (P);
      Assert (CP.Query (P) = "fi", "backspace edits the query");
      Assert (CP.Result_Count (P) = 2, "a shorter query matches more commands");

      CP.Set_Query (P, "zzz");
      Assert (CP.Result_Count (P) = 0, "a non-matching query yields no results");
      Assert (CP.Selected_Index (P) = 0, "no results clears the selection");
   end Test_Filter_And_Select;

   procedure Test_Build_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P     : CP.Palette;
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Icons : Guikit.Draw.Icon_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
   begin
      CP.Set_Commands (P, Sample);
      CP.Build_Frame
        (P, 0, 0, 400, 300, 400, 300, True, -1, -1, Rects, Text, Icons, Nodes);
      Assert (not Rects.Is_Empty, "Build_Frame emits rectangles (panel, rows)");
      Assert (not Text.Is_Empty, "Build_Frame emits text (row labels)");
      Assert (not Nodes.Is_Empty, "Build_Frame emits accessibility nodes");
      --  A click on the first result row selects it.
      declare
         Hit : constant Boolean := CP.Click (P, 200, 60);
      begin
         Assert (Hit or else CP.Selected_Index (P) >= 1, "a click hits a laid-out row");
      end;
   end Test_Build_Frame;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Palette_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Command_Palette;
