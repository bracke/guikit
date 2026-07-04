with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Layout;

--  Geometry tests for Guikit.Layout. Every calculator is exercised with known
--  inputs and asserted against hand-computed geometry, plus the saturating and
--  hit-test helpers and the monotonic/edge behavior of the toolbar layout.
package body Guikit_Suite.Layout is

   use AUnit.Assertions;
   use Guikit.Layout;

   type Layout_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Layout_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Layout_Test_Case);

   procedure Test_Within (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Saturating (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret_And_Label (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Toolbar_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Toolbar_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scope_Chip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Action_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Entry_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Pane (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Layout_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit layout geometry");
   end Name;

   overriding procedure Register_Tests (T : in out Layout_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Within'Access, "Within and Within_Rect test point containment");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Saturating'Access, "Saturating_Multiply and Saturating_Add clamp at Natural'Last");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Caret_And_Label'Access, "Caret_Advance_Width and Label_Pixel_Width measure as expected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Toolbar_Layout'Access, "Calculate_Toolbar_Layout splits a window into three sections");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Toolbar_Buttons'Access, "toolbar left-button X and width tile the left section");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scope_Chip'Access, "the filter scope chip fits or hides with the filter field width");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar'Access, "Calculate_Bottom_Bar_Layout partitions the bottom bar");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Action_Buttons'Access, "Calculate_Settings_Action_Button_Layout halves the text column");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Entry_Buttons'Access, "Calculate_Settings_Entry_Button_Layout right-aligns two buttons");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Pane'Access, "Calculate_Settings_Pane_Layout centers the settings pane");
   end Register_Tests;

   procedure Test_Within (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Within (5, 0, 10), "a coordinate inside the span is contained");
      Assert (Within (0, 0, 10), "the left edge is contained");
      Assert (not Within (10, 0, 10), "the right edge is exclusive");
      Assert (not Within (5, 0, 0), "a zero-width span contains nothing");
      Assert (not Within (2, 5, 10), "a coordinate left of the span is not contained");

      Assert (Within_Rect (5, 5, 0, 0, 10, 10), "a point inside the rectangle is contained");
      Assert (not Within_Rect (5, 10, 0, 0, 10, 10), "the bottom edge is exclusive");
      Assert (not Within_Rect (5, 5, 0, 0, 10, 0), "a zero-height rectangle contains nothing");
   end Test_Within;

   procedure Test_Saturating (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Saturating_Multiply (3, 4) = 12, "3 * 4 is 12");
      Assert (Saturating_Multiply (5, 0) = 0, "any value times zero is zero");
      Assert (Saturating_Multiply (Natural'Last, 2) = Natural'Last, "multiplication saturates at Natural'Last");
      Assert (Saturating_Add (3, 4) = 7, "3 + 4 is 7");
      Assert (Saturating_Add (Natural'Last, 1) = Natural'Last, "addition saturates at Natural'Last");
   end Test_Saturating;

   procedure Test_Caret_And_Label (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Caret_Advance_Width (20) = 12, "a 20px line height yields a 12px caret advance");
      Assert (Caret_Advance_Width (1) = 1, "the caret advance is never zero");
      Assert (Caret_Advance_Width (40) >= Caret_Advance_Width (20),
              "caret advance is monotonic in line height");
      Assert (Label_Pixel_Width ("abc", 10) = 30, "three cells at 10px each measure 30px");
      Assert (Label_Pixel_Width ("", 10) = 0, "an empty label measures zero pixels");
   end Test_Caret_And_Label;

   procedure Test_Toolbar_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Wide   : constant Toolbar_Layout := Calculate_Toolbar_Layout (1000);
      Narrow : constant Toolbar_Layout := Calculate_Toolbar_Layout (100);
   begin
      Assert (Wide.Left_X = 0, "the left section starts at the origin");
      Assert (Wide.Left_Width = 280, "the left section fits all seven 40px buttons");
      Assert (Wide.Right_Width = 250, "the right section is a quarter of the window");
      Assert (Wide.Right_X = 750, "the right section is right-aligned");
      Assert (Wide.Middle_X = 280, "the middle section follows the left section");
      Assert (Wide.Middle_Width = 470, "the middle section fills the remaining width");
      Assert
        (Wide.Left_Width + Wide.Middle_Width + Wide.Right_Width = 1000,
         "the three sections span the whole window");

      Assert (Narrow.Left_Width = 0, "a narrow window drops the fixed left section");
      Assert
        (Narrow.Left_Width + Narrow.Middle_Width + Narrow.Right_Width = 100,
         "the sections still span a narrow window");
   end Test_Toolbar_Layout;

   procedure Test_Toolbar_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Toolbar : constant Toolbar_Layout := Calculate_Toolbar_Layout (1000);
   begin
      Assert (Toolbar_Left_Button_X (Toolbar, 0) = 0, "the first button starts at the left edge");
      Assert (Toolbar_Left_Button_X (Toolbar, 3) = 120, "the fourth button starts at 3 * 40px");
      Assert (Toolbar_Left_Button_Width (Toolbar, 0) = 40, "each button in a full toolbar is 40px wide");
      Assert (Toolbar_Left_Button_Width (Toolbar, 7) = 0, "a button beyond the count has no width");
   end Test_Toolbar_Buttons;

   procedure Test_Scope_Chip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Wide_Toolbar : constant Toolbar_Layout :=
        (Right_X => 800, Right_Width => 200, others => 0);
      Narrow_Toolbar : constant Toolbar_Layout :=
        (Right_X => 900, Right_Width => 100, others => 0);
      Chip_W : constant Natural := 90;  --  caller-measured label width
      Chip : constant Scope_Chip_Region := Filter_Scope_Chip_Region_Of (Wide_Toolbar, Chip_W, 20);
   begin
      Assert (Chip.Visible, "a wide filter section shows the scope chip");
      Assert (Chip.Width = 90, "the chip is exactly the caller-measured label width");
      Assert (Chip.Height = 28, "the chip is one input-field tall");
      Assert (Chip.Y = 6, "the chip is vertically centered in the toolbar");
      Assert (Chip.X = 904, "the chip is right-aligned inside the filter section");
      Assert (Filter_Input_Field_Width (Wide_Toolbar, Chip_W, 20) = 92,
              "the filter field is narrowed to end before the chip");

      Assert (not Filter_Scope_Chip_Region_Of (Narrow_Toolbar, Chip_W, 20).Visible,
              "a narrow filter section hides the scope chip");
      Assert (Filter_Input_Field_Width (Narrow_Toolbar, Chip_W, 20) = 88,
              "with no chip the filter field spans the section less both margins");
      Assert (not Filter_Scope_Chip_Region_Of (Wide_Toolbar, 0, 20).Visible,
              "a zero-width chip is not shown");
   end Test_Scope_Chip;

   procedure Test_Bottom_Bar (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Bar : constant Bottom_Bar_Layout :=
        Calculate_Bottom_Bar_Layout
          (Width               => 800,
           Small_Label_Width   => 30,
           Large_Label_Width   => 30,
           Details_Label_Width => 30,
           Sort_Label_Width    => 30,
           Info_Label_Width    => 30,
           Line_Height         => 20);
   begin
      Assert (Bar.View_Mode_X = 8, "the view-mode section starts after the content padding");
      Assert (Bar.View_Mode_Width = 126, "the view-mode section holds the three 42px buttons");
      Assert (Bar.Small_Button_Width = 42, "the small-icons button is label + padding wide");
      Assert (Bar.Large_Button_Width = 42, "the large-icons button matches");
      Assert (Bar.Details_Button_Width = 42, "the details button matches");
      Assert
        (Bar.Small_Button_Width + Bar.Large_Button_Width + Bar.Details_Button_Width = Bar.View_Mode_Width,
         "the three view buttons tile the view-mode section");
      Assert (Bar.Sort_Button_Width = 46, "the sort button uses the input-field padding");
      Assert (Bar.Sort_Button_X = 134, "the sort button follows the view-mode section");
      Assert (Bar.Info_Pane_X = 750, "the info pane toggle is pushed to the right");
   end Test_Bottom_Bar;

   procedure Test_Settings_Action_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Buttons : constant Settings_Action_Button_Layout :=
        Calculate_Settings_Action_Button_Layout (Text_X => 10, Text_Width => 100);
   begin
      Assert (Buttons.First_Button_X = 10, "the first action button starts at the text column");
      Assert (Buttons.First_Button_Width = 48, "the first action button is half the column less the gap");
      Assert (Buttons.Second_Button_X = 62, "the second action button follows the gap");
      Assert (Buttons.Second_Button_Width = 48, "the second action button fills the rest of the column");
      Assert (Buttons.Total_Width = 100, "the two buttons and the gap span the column");
   end Test_Settings_Action_Buttons;

   procedure Test_Settings_Entry_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Buttons : constant Settings_Entry_Button_Layout :=
        Calculate_Settings_Entry_Button_Layout
          (Pane_X             => 0,
           Pane_Width         => 500,
           Add_Label_Width    => 30,
           Remove_Label_Width => 30);
   begin
      Assert (Buttons.Add_Button_Width = 46, "the add button is label + input padding wide");
      Assert (Buttons.Remove_Button_Width = 46, "the remove button matches");
      Assert (Buttons.Total_Width = 96, "both buttons and the gap span 96px");
      Assert (Buttons.Add_Button_X = 390, "the buttons are right-aligned in the pane");
      Assert (Buttons.Remove_Button_X = 440, "the remove button follows the add button and gap");
   end Test_Settings_Entry_Buttons;

   procedure Test_Settings_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pane : constant Settings_Pane_Layout :=
        Calculate_Settings_Pane_Layout
          (Width          => 1000,
           Height         => 800,
           Toolbar_Height => 40,
           Line_Height    => 20);
   begin
      Assert (Pane.Width = 800, "the pane is four fifths of a wide window");
      Assert (Pane.X = 100, "the pane is horizontally centered");
      Assert (Pane.Y = 133, "the pane starts below a proportional top margin");
      Assert (Pane.Height = 636, "the pane is tall enough for its content rows");
      Assert (Pane.Text_X = 114, "the inner text column is inset by the pane padding");
      Assert (Pane.Text_Y = 147, "the inner text top is inset by the pane padding");
      Assert (Pane.Text_Width = 772, "the inner text column spans the pane less both paddings");
   end Test_Settings_Pane;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Layout_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Layout;
