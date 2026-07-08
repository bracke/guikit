with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Item_Grid;

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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Grid_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Item_Grid;
