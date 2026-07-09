with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Item_Grid;
with Guikit.Draw;

--  Exercises the item-grid geometry: pointer-to-item hit-testing, marquee
--  rectangle normalisation, and the items a marquee rectangle covers.
package body Guikit_Suite.Item_Grid is

   use AUnit.Assertions;
   package IG renames Guikit.Item_Grid;

   type Grid_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Grid_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Grid_Test_Case);

   procedure Test_Item_At (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cell_Metrics (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Calculate_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Background (T : in out AUnit.Test_Cases.Test_Case'Class);

   --  Three stacked 100x20 rows, plus a non-selectable header row (index 0).
   function Sample return IG.Item_Layout_Vectors.Vector is
      V : IG.Item_Layout_Vectors.Vector;
   begin
      V.Append (IG.Item_Layout'(Visible_Index => 0, X => 0, Y => 0, Width => 100, Height => 20, others => <>));
      V.Append (IG.Item_Layout'(Visible_Index => 1, X => 0, Y => 20, Width => 100, Height => 20, others => <>));
      V.Append (IG.Item_Layout'(Visible_Index => 2, X => 0, Y => 40, Width => 100, Height => 20, others => <>));
      V.Append (IG.Item_Layout'(Visible_Index => 3, X => 0, Y => 60, Width => 100, Height => 20, others => <>));
      return V;
   end Sample;

   overriding function Name (T : Grid_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit item grid geometry");
   end Name;

   overriding procedure Register_Tests (T : in out Grid_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_At'Access, "Item_At maps a point to its visible index and 0 off any item");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Marquee'Access, "Marquee_Rect normalises a drag; Items_In_Rect covers the overlapped rows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cell_Metrics'Access, "Cell_Metrics_For sizes the cell per view mode");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Calculate_Layout'Access, "Calculate_Layout stacks rows, scrolls, and keeps details columns");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Background'Access, "Draw_Item_Background paints per state and nothing when bare");
   end Register_Tests;

   procedure Test_Item_At (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Items : constant IG.Item_Layout_Vectors.Vector := Sample;
   begin
      Assert (IG.Item_At (Items, 50, 30) = 1, "a point in the first data row hits index 1");
      Assert (IG.Item_At (Items, 50, 50) = 2, "a point in the second data row hits index 2");
      Assert (IG.Item_At (Items, 50, 10) = 0, "the header row (visible index 0) is not selectable");
      Assert (IG.Item_At (Items, 50, 200) = 0, "a point below every row hits nothing");
      Assert (IG.Item_At (Items, 100, 30) = 0, "the right edge is exclusive");
   end Test_Item_At;

   procedure Test_Marquee (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Items      : constant IG.Item_Layout_Vectors.Vector := Sample;
      X, Y, W, H : Natural;
   begin
      --  A drag from bottom-right to top-left normalises to the same rectangle.
      IG.Marquee_Rect (Start_X => 80, Start_Y => 70, Current_X => 10, Current_Y => 25,
                       X => X, Y => Y, Width => W, Height => H);
      Assert (X = 10 and then Y = 25 and then W = 70 and then H = 45, "the marquee normalises to a canonical rect");

      declare
         Hits : constant IG.Visible_Index_Vectors.Vector := IG.Items_In_Rect (Items, X, Y, W, H);
      begin
         --  Covers data rows 1, 2 and 3 (Y 20..80); the header row is excluded.
         Assert (Natural (Hits.Length) = 3, "the marquee covers the three data rows");
         Assert (Hits.First_Element = 1 and then Hits.Last_Element = 3, "covered rows are reported in order");
      end;

      --  A zero-area marquee (a plain click) selects nothing.
      declare
         Hits : constant IG.Visible_Index_Vectors.Vector := IG.Items_In_Rect (Items, 50, 30, 0, 0);
      begin
         Assert (Hits.Is_Empty, "a zero-area marquee touches nothing");
      end;
   end Test_Marquee;

   procedure Test_Cell_Metrics (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Small   : constant IG.Cell_Metrics := IG.Cell_Metrics_For (IG.Icons_Small, 800, 20);
      Large   : constant IG.Cell_Metrics := IG.Cell_Metrics_For (IG.Icons_Large, 800, 20);
      Details : constant IG.Cell_Metrics := IG.Cell_Metrics_For (IG.Details, 800, 20);
   begin
      Assert (Small.Width = 216 and then not Small.Large, "small-icon cells are a fixed 216px single-line row");
      Assert (Large.Width = 140 and then Large.Icon_Size = 60 and then Large.Large,
              "large-icon cells are 7x wide with a 3x icon and centre the label");
      Assert (Details.Width = 800 and then not Details.Large, "details rows span the full main width");
   end Test_Cell_Metrics;

   procedure Test_Calculate_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;

      function Row (Index : Natural; Header : Boolean := False) return IG.Layout_Item is
        (IG.Layout_Item'(Visible_Index => Index, Group_Header => Header,
                         Label => To_Unbounded_String ("item")));

      Items : IG.Layout_Item_Vectors.Vector;
      Cols  : IG.Detail_Column_Bounds;
   begin
      Items.Append (Row (1));
      Items.Append (Row (2));
      Items.Append (Row (0, Header => True));
      Items.Append (Row (3));

      --  Details: rows stack under a header band, in order, full width. With no
      --  scroll the first data row is visible; the group-header keeps index 0.
      Cols (IG.Name_Column) := (X => 20, Width => 380);
      declare
         L : constant IG.Item_Layout_Vectors.Vector :=
           IG.Calculate_Layout (Items, IG.Details, Content_X => 0, Content_Y => 0, Content_W => 400,
                                Content_H => 400, Columns => Cols, Scroll_Pixels => 0, Line_Height => 20);
      begin
         Assert (Natural (L.Length) = 4, "every item gets a row");
         Assert (L (1).Visible_Index = 1 and then L (1).Width = 400, "first data row spans the content width");
         Assert (L (3).Visible_Index = 0, "the group-header row keeps visible index 0");
         Assert (L (2).Y > L (1).Y, "rows stack downward");
      end;

      --  Small icons scrolled past the first row: row 1 clips to zero height.
      declare
         L : constant IG.Item_Layout_Vectors.Vector :=
           IG.Calculate_Layout (Items, IG.Icons_Small, Content_X => 0, Content_Y => 0, Content_W => 240,
                                Content_H => 400, Columns => Cols, Scroll_Pixels => 1000, Line_Height => 20);
      begin
         Assert (L (1).Height = 0, "a row scrolled fully above the viewport has zero height");
      end;
   end Test_Calculate_Layout;

   procedure Test_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Cell : constant IG.Item_Layout :=
        (Visible_Index => 1, X => 0, Y => 0, Width => 100, Height => 20, others => 0);
      Sel  : constant Guikit.Draw.Render_Color := Guikit.Draw.Selection_Color;
      Hov  : constant Guikit.Draw.Render_Color := Guikit.Draw.Hover_Color;
      Bor  : constant Guikit.Draw.Render_Color := Guikit.Draw.Border_Color;
      Alt  : constant Guikit.Draw.Render_Color := Guikit.Draw.Pane_Color;

      function Painted (Kind : IG.Background_Kind) return Natural is
         R : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      begin
         IG.Draw_Item_Background (R, 200, 200, Cell, Kind, Sel, Hov, Bor, Alt);
         return Natural (R.Length);
      end Painted;
   begin
      Assert (Painted (IG.No_Background) = 0, "a bare cell paints nothing");
      Assert (Painted (IG.Alternate) = 1, "an alternate row is a single fill");
      Assert (Painted (IG.Hovered) = 5, "hover is a fill plus a four-edge border");
      Assert (Painted (IG.Selected) = 6, "selection adds a left accent stripe over the fill+border");
      Assert (Painted (IG.Drop_Target) = 6, "a drop target is fill, border, and an accent stripe");
   end Test_Background;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Grid_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Item_Grid;
