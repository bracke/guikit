with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Segmented;
with Guikit.Draw;

--  Exercises the stateless segmented control: cell hit-testing across a region
--  and a headless Build_Frame that emits draw commands, tooltips and one
--  accessibility node per cell with the active cell marked selected.
package body Guikit_Suite.Segmented is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   package SG renames Guikit.Segmented;

   type Seg_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Seg_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Seg_Test_Case);

   procedure Test_Cell_At (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Build_Frame (T : in out AUnit.Test_Cases.Test_Case'Class);

   function Sample return SG.Segment_Vectors.Vector is
      V : SG.Segment_Vectors.Vector;
   begin
      V.Append (SG.Segment'(Label => To_Unbounded_String ("Small"),
                            Tooltip => To_Unbounded_String ("Small icons"), Enabled => True));
      V.Append (SG.Segment'(Label => To_Unbounded_String ("Large"), others => <>));
      V.Append (SG.Segment'(Label => To_Unbounded_String ("Details"), others => <>));
      return V;
   end Sample;

   overriding function Name (T : Seg_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit segmented control");
   end Name;

   overriding procedure Register_Tests (T : in out Seg_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cell_At'Access, "Cell_At maps a coordinate to a cell and 0 outside the region");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Build_Frame'Access, "Build_Frame emits cells, tooltips, and a selected accessibility node");
   end Register_Tests;

   procedure Test_Cell_At (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (SG.Cell_At (0, 300, 3, 50) = 1, "the left third is cell 1");
      Assert (SG.Cell_At (0, 300, 3, 150) = 2, "the middle third is cell 2");
      Assert (SG.Cell_At (0, 300, 3, 250) = 3, "the right third is cell 3");
      Assert (SG.Cell_At (0, 300, 3, 0) = 1, "the left edge is inclusive");
      Assert (SG.Cell_At (0, 300, 3, 299) = 3, "the last pixel is cell 3");
      Assert (SG.Cell_At (0, 300, 3, 300) = 0, "the right edge is exclusive");
      Assert (SG.Cell_At (0, 300, 3, -1) = 0, "a coordinate left of the region is no cell");
   end Test_Cell_At;

   procedure Test_Build_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Tips  : Guikit.Draw.Tooltip_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Selected_Count : Natural := 0;
   begin
      SG.Build_Frame (Sample, Active => 3, Region_X => 0, Region_Y => 0, Region_Width => 300,
                      Region_Height => 24, Clip_Width => 300, Clip_Height => 24, Line_Height => 20,
                      Hover_X => -1, Hover_Y => -1,
                      Rectangles => Rects, Text => Text, Tooltips => Tips, Accessibility => Nodes);
      Assert (not Rects.Is_Empty, "Build_Frame emits rectangles (cell fills/borders)");
      Assert (not Text.Is_Empty, "Build_Frame emits the cell labels");
      Assert (Natural (Tips.Length) = 1, "only the tooltip-bearing cell emits a tooltip");
      Assert (Natural (Nodes.Length) = 3, "each cell emits one accessibility node");
      for N of Nodes loop
         if N.Selected then
            Selected_Count := Selected_Count + 1;
         end if;
      end loop;
      Assert (Selected_Count = 1, "exactly the active cell is marked selected");
   end Test_Build_Frame;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Seg_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Segmented;
