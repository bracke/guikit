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
      Segs : constant SG.Segment_Vectors.Vector := Sample;
      SX1, SW1, SX3, SW3, CX, CW : Natural;
      Covered : Natural := 0;
   begin
      --  Hit-testing walks the same variable layout the renderer draws.
      Assert (SG.Cell_At (Segs, 0, 300, 20, 0) = 1, "the left edge is cell 1");
      Assert (SG.Cell_At (Segs, 0, 300, 20, 299) = 3, "the last pixel is cell 3");
      Assert (SG.Cell_At (Segs, 0, 300, 20, 300) = 0, "the right edge is exclusive");
      Assert (SG.Cell_At (Segs, 0, 300, 20, -1) = 0, "a coordinate left of the region is no cell");

      --  A round trip: the midpoint of each cell hit-tests back to that cell.
      for Cell in 1 .. 3 loop
         SG.Cell_Bounds (Segs, 0, 300, 20, Cell, CX, CW);
         Assert (SG.Cell_At (Segs, 0, 300, 20, CX + CW / 2) = Cell, "a cell midpoint hit-tests to itself");
         Covered := Covered + CW;
      end loop;
      Assert (Covered = 300, "the cells tile the region exactly");

      --  Variable width: the longer label ("Details") gets a wider cell than
      --  the shorter one ("Small").
      SG.Cell_Bounds (Segs, 0, 300, 20, 1, SX1, SW1);
      SG.Cell_Bounds (Segs, 0, 300, 20, 3, SX3, SW3);
      Assert (SW3 > SW1, "the longer label gets the wider cell");
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
      --  Connected control: three cell fills + two interior dividers + a single
      --  four-edge outer border = 9 rectangles (per-cell borders would give 15).
      Assert (Natural (Rects.Length) = 9,
              "three cells emit three fills, two shared dividers, and one outer border");
      Assert (not Text.Is_Empty, "Build_Frame emits the cell labels");
      Assert (Natural (Tips.Length) = 1, "only the tooltip-bearing cell emits a tooltip");
      Assert (Natural (Nodes.Length) = 3, "each cell emits one accessibility node");
      for N of Nodes loop
         if N.Selected then
            Selected_Count := Selected_Count + 1;
         end if;
      end loop;
      Assert (Selected_Count = 1, "exactly the active cell is marked selected");

      --  The label is centred within its (stretched) cell: equal gaps on each
      --  side, and inset further than the old fixed left padding.
      declare
         CX, CW : Natural;
         L      : constant Guikit.Draw.Text_Command := Text.Element (1);
      begin
         SG.Cell_Bounds (Sample, 0, 300, 20, 1, CX, CW);
         declare
            LG : constant Integer := Integer (L.X) - Integer (CX);
            RG : constant Integer := Integer (CX + CW) - Integer (L.X + L.Width);
         begin
            Assert (LG > 4, "the label is inset past the old left padding (it is centred)");
            Assert (abs (LG - RG) <= 1, "the label sits horizontally centred in its cell");
         end;
      end;
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
