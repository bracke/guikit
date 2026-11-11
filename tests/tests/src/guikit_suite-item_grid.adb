with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Item_Grid;
with Guikit.Draw;
with Guikit.Layout;

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
   procedure Test_Group_Header (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Details_Row (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Name_Field (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Name_Field_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Indicators (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Line_Height_Scaling (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Group_Header'Access, "Draw_Group_Header emits fill, caption, separator and a disabled node");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Details_Row'Access, "Draw_Details_Row emits the separator, visible columns and time tooltips");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Name_Field'Access, "Draw_Name_Field draws the label and, when renaming+focused, chrome and a caret");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Name_Field_Scroll'Access,
         "Draw_Name_Field scrolls a long focused rename so its caret shows, and fits other labels");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Indicators'Access, "Draw_Item_Indicators draws the favorite star and color-label dot per flag");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Line_Height_Scaling'Access,
         "the grid's gaps, paddings and small-cell width scale with the line height in layout and drawing");
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
      Small_2 : constant IG.Cell_Metrics := IG.Cell_Metrics_For (IG.Icons_Small, 800, 40);
   begin
      Assert (Small.Width = IG.Small_Icon_Cell_Width and then not Small.Large,
              "small-icon cells are Small_Icon_Cell_Width single-line rows at the reference line height");
      Assert (Small_2.Width = 2 * IG.Small_Icon_Cell_Width,
              "small-icon cells double with the line height, like their padding and icon");
      Assert (Small_2.Height = 2 * Small.Height and then Small_2.Icon_Size = 2 * Small.Icon_Size,
              "a small-icon cell's height and icon double at line height 40");
      Assert (IG.Small_Cell_Width (Positive'Last) = Natural'Last,
              "the small-icon width saturates instead of overflowing");
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

      --  Through accessors, only the cells on screen read their label, and
      --  the others are all-zero cells: a large list costs a screenful.
      declare
         Labels_Read : Natural := 0;

         function Index_At (Position : Positive) return Natural is (Position);
         function Header_At (Position : Positive) return Boolean is (False);
         function Label_At (Position : Positive) return String is
         begin
            Labels_Read := Labels_Read + 1;
            return "item" & Position'Image;
         end Label_At;

         L : constant IG.Item_Layout_Vectors.Vector :=
           IG.Calculate_Layout
             (10_000, Index_At'Access, Header_At'Access, Label_At'Access, IG.Icons_Large,
              Content_X => 0, Content_Y => 0, Content_W => 400, Content_H => 400, Columns => Cols,
              Scroll_Pixels => 5_000, Line_Height => 20);
         On_Screen : Natural := 0;
      begin
         Assert (Natural (L.Length) = 10_000, "every item still gets a cell");
         for Cell of L loop
            if Cell.Height > 0 then
               On_Screen := On_Screen + 1;
            else
               Assert (Cell.Y = 0 and then Cell.Width = 0, "a cell off screen is all zero");
            end if;
         end loop;
         Assert (On_Screen > 0 and then On_Screen < 20, "only a screenful is on screen");
         Assert (Labels_Read = On_Screen, "only the cells on screen read their label");
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

   procedure Test_Group_Header (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Cell : constant IG.Item_Layout :=
        (Visible_Index => 0, X => 0, Y => 0, Width => 200, Height => 24,
         Text_X => 4, Text_Y => 4, Text_Width => 190, others => 0);
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;

      --  A too-narrow box truncates a long caption with an ellipsis.
      Fitted : Guikit.Draw.Text_Command_Vectors.Vector;
   begin
      IG.Draw_Group_Header (Rects, Text, Nodes, 400, 400, Cell, To_Unbounded_String ("Images"),
                            20, Guikit.Draw.Pane_Color, Guikit.Draw.Muted_Text_Color, Guikit.Draw.Border_Color);
      Assert (Natural (Rects.Length) = 2, "a header draws its fill and a bottom separator");
      Assert (Natural (Text.Length) = 1, "a header draws its caption");
      Assert (Natural (Nodes.Length) = 1 and then not Nodes.First_Element.Enabled,
              "a header emits one non-selectable accessibility node");

      IG.Draw_Fitted_Text (Fitted, 400, 400, X => 0, Y => 0, Width => 30, Height => 20,
                           Text => To_Unbounded_String ("a-very-long-file-name.txt"),
                           Color => Guikit.Draw.Text_Color, Line_Height => 20, Fit => True);
      Assert (Natural (Fitted.Length) = 1 and then Fitted.First_Element.Truncated,
              "text wider than its box is fitted and marked truncated");
   end Test_Group_Header;

   procedure Test_Details_Row (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      --  Two visible columns: Modified (with a tooltip) and Size (no tooltip);
      --  the other three columns have zero width and are skipped.
      Cell : constant IG.Item_Layout :=
        (Visible_Index => 1, X => 0, Y => 0, Width => 400, Height => 20, Text_Y => 4,
         Modified_X => 40, Modified_Width => 120, Size_X => 160, Size_Width => 80, others => 0);
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Tips  : Guikit.Draw.Tooltip_Command_Vectors.Vector;

      function U (S : String) return Unbounded_String renames To_Unbounded_String;
   begin
      IG.Draw_Details_Row
        (Rects, Text, Tips, 800, 800, Cell, 20,
         Modified => U ("2 days ago"), Size => U ("1.4 MB"), Filetype => U (""),
         Created => U (""), Permissions => U (""),
         Modified_Tooltip => U ("Mon 7 Jul 2026 10:00"), Created_Tooltip => U (""),
         Dim => False, Value_Color => Guikit.Draw.Muted_Text_Color,
         Dim_Color => Guikit.Draw.Muted_Text_Color, Border_Color => Guikit.Draw.Border_Color);
      Assert (Natural (Rects.Length) = 1, "the row draws one bottom separator");
      Assert (Natural (Text.Length) = 2, "only the two non-zero-width columns emit text");
      Assert (Natural (Tips.Length) = 1, "only the modified column emits a tooltip");
   end Test_Details_Row;

   procedure Test_Name_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Cell : constant IG.Item_Layout :=
        (Visible_Index => 1, X => 0, Y => 0, Width => IG.Small_Icon_Cell_Width, Height => 24, Text_X => 30,
         Text_Y => 4, Text_Width => 180, others => 0);
      FX, FW, WX, WW : Natural;

      function Text_Count (Renaming, Focused : Boolean) return Natural is
         R : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Tx : Guikit.Draw.Text_Command_Vectors.Vector;
      begin
         IG.Draw_Name_Field (R, Tx, 400, 400, Cell, IG.Icons_Small, Renaming, Focused, Dim => False,
                             Text => To_Unbounded_String ("readme.txt"), Cursor => 4, Line_Height => 20,
                             Text_Color => Guikit.Draw.Text_Color, Dim_Color => Guikit.Draw.Muted_Text_Color,
                             Border_Color => Guikit.Draw.Border_Color, Focus_Ring_Color => Guikit.Draw.Selection_Color,
                             Caret_Color => Guikit.Draw.Text_Color);
         return Natural (Tx.Length) * 1000 + Natural (R.Length);
      end Text_Count;
   begin
      --  Small-icons uses the cell's text box; renaming large-icons widens it.
      IG.Rename_Field_Extent (Cell, IG.Icons_Small, Renaming => True, Field_X => FX, Field_W => FW);
      IG.Rename_Field_Extent (Cell, IG.Icons_Large, Renaming => True, Field_X => WX, Field_W => WW);
      Assert (FX = 30 and then FW = 180, "small-icons rename edits the label box");
      Assert (WX < FX and then WW > FW, "large-icons rename widens the field across the inner cell");

      --  A plain label is one text command, no chrome; renaming+focused adds the
      --  border, focus ring and caret rectangles on top of the label.
      Assert (Text_Count (Renaming => False, Focused => False) = 1000,
              "a non-renaming item draws just its label");
      Assert (Text_Count (Renaming => True, Focused => True) > 1000,
              "renaming with focus adds chrome and a caret");
   end Test_Name_Field;

   procedure Test_Name_Field_Scroll (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Line_Height : constant := 20;
      Cell        : constant IG.Item_Layout :=
        (Visible_Index => 1, X => 0, Y => 0, Width => IG.Small_Icon_Cell_Width, Height => 24, Text_X => 30,
         Text_Y => 4, Text_Width => 180, others => 0);
      Char_W      : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Long_Name   : constant String := "a-very-long-file-name-that-never-fits-the-label-box-0123456789.txt";
      Field_X     : Natural;
      Field_W     : Natural;

      procedure Draw
        (Renaming, Focused : Boolean;
         Cursor            : Natural;
         Rects             : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Texts             : out Guikit.Draw.Text_Command_Vectors.Vector) is
      begin
         Rects.Clear;
         Texts.Clear;
         IG.Draw_Name_Field (Rects, Texts, 1_000, 1_000, Cell, IG.Icons_Small, Renaming, Focused, Dim => False,
                             Text => To_Unbounded_String (Long_Name), Cursor => Cursor,
                             Line_Height => Line_Height, Text_Color => Guikit.Draw.Text_Color,
                             Dim_Color => Guikit.Draw.Muted_Text_Color, Border_Color => Guikit.Draw.Border_Color,
                             Focus_Ring_Color => Guikit.Draw.Selection_Color, Caret_Color => Guikit.Draw.Text_Color);
      end Draw;

      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Texts : Guikit.Draw.Text_Command_Vectors.Vector;
   begin
      IG.Rename_Field_Extent (Cell, IG.Icons_Small, True, Field_X, Field_W, Line_Height);
      Assert (Long_Name'Length * Char_W > Field_W, "the sample name is wider than the rename field");

      --  Caret at the end of a long name: the text scrolls so the caret, the
      --  last rectangle drawn, sits inside the field at its true position.
      Draw (Renaming => True, Focused => True, Cursor => Long_Name'Length, Rects => Rects, Texts => Texts);
      declare
         Shown    : constant String := To_String (Texts.First_Element.Text);
         Caret    : constant Guikit.Draw.Rectangle_Command := Rects.Last_Element;
         Skipped  : constant Natural :=
           Guikit.Layout.Input_Scroll_Columns (Long_Name'Length, Field_W, Line_Height);
      begin
         Assert (Natural (Texts.Length) = 1, "the rename field draws one text command");
         Assert (Skipped > 0, "a caret past the field's capacity scrolls the text");
         Assert (Shown = Long_Name (Long_Name'First + Skipped .. Long_Name'Last),
                 "the focused field shows the name minus its scrolled-off leading columns");
         Assert (not Texts.First_Element.Truncated, "the focused field is clipped, not ellipsised");
         Assert (Caret.X >= Field_X and then Caret.X + Caret.Width <= Field_X + Field_W,
                 "the caret at the end of a long name stays inside the field");
         Assert (Caret.X = Field_X + (Long_Name'Length - Skipped) * Char_W,
                 "the caret sits after the last shown character");
      end;

      --  Caret at the start: nothing scrolls, and the caret is at the field's left edge.
      Draw (Renaming => True, Focused => True, Cursor => 0, Rects => Rects, Texts => Texts);
      Assert (To_String (Texts.First_Element.Text) = Long_Name, "a caret at the start shows the name from its start");
      Assert (Rects.Last_Element.X = Field_X, "a caret at the start sits at the field's left edge");

      --  Not focused (another field of a multi-rename has focus, or a plain
      --  label): the name keeps the fitted ellipsis form.
      Draw (Renaming => True, Focused => False, Cursor => Long_Name'Length, Rects => Rects, Texts => Texts);
      Assert (Texts.First_Element.Truncated, "an unfocused rename field keeps the fitted ellipsis");
      Draw (Renaming => False, Focused => False, Cursor => 0, Rects => Rects, Texts => Texts);
      Assert (Texts.First_Element.Truncated, "a plain long label keeps the fitted ellipsis");
   end Test_Name_Field_Scroll;

   procedure Test_Indicators (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Cell : constant IG.Item_Layout :=
        (Visible_Index => 1, X => 0, Y => 0, Width => 60, Height => 60,
         Icon_X => 6, Icon_Y => 6, Icon_Size => 48, others => 0);

      --  Returns text-count * 1000 + rect-count.
      function Drawn (Favorite, Has_Label : Boolean) return Natural is
         R  : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Tx : Guikit.Draw.Text_Command_Vectors.Vector;
      begin
         IG.Draw_Item_Indicators (R, Tx, 400, 400, Cell, 20, Favorite, To_Unbounded_String ("*"),
                                 Guikit.Draw.Selection_Color, Has_Label, Guikit.Draw.Selection_Color);
         return Natural (Tx.Length) * 1000 + Natural (R.Length);
      end Drawn;
   begin
      Assert (Drawn (False, False) = 0, "no indicators when neither flag is set");
      Assert (Drawn (True, False) = 1000, "the favorite star is a glyph, no rect");
      Assert (Drawn (False, True) = 1, "the color-label dot is a rect, no glyph");
      Assert (Drawn (True, True) = 1001, "both indicators draw together");
   end Test_Indicators;

   procedure Test_Line_Height_Scaling (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;

      Items : IG.Layout_Item_Vectors.Vector;
      Cols  : IG.Detail_Column_Bounds;

      --  The spacing functions at one line height, against their expected
      --  values there.
      procedure Check_Spacing (LH : Positive; Gap, Content, Icon_Gap, Row, Column, Small_W : Natural) is
         Where : constant String := " at line height" & LH'Image;
      begin
         Assert (IG.Grid_Gap (LH) = Gap, "the grid gap scales" & Where);
         Assert (IG.Content_Padding (LH) = Content, "the cell content padding scales" & Where);
         Assert (IG.Icon_Text_Gap (LH) = Icon_Gap, "the icon-to-label gap scales" & Where);
         Assert (IG.Row_Padding (LH) = Row, "the details row padding scales" & Where);
         Assert (IG.Column_Padding (LH) = Column, "the details column padding scales" & Where);
         Assert (IG.Small_Cell_Width (LH) = Small_W, "the small-icon cell width scales" & Where);
      end Check_Spacing;

      --  Lay out two small-icon cells and two details rows at one line height
      --  and check the spacing the layout and the details drawing use.
      procedure Check_Layout (LH : Positive) is
         Where   : constant String := " at line height" & LH'Image;
         Gap     : constant Natural := IG.Grid_Gap (LH);
         Pad     : constant Natural := IG.Content_Padding (LH);
         Small   : constant IG.Item_Layout_Vectors.Vector :=
           IG.Calculate_Layout (Items, IG.Icons_Small, Content_X => 0, Content_Y => 0, Content_W => 1000,
                                Content_H => 600, Columns => Cols, Scroll_Pixels => 0, Line_Height => LH);
         Details : constant IG.Item_Layout_Vectors.Vector :=
           IG.Calculate_Layout (Items, IG.Details, Content_X => 0, Content_Y => 0, Content_W => 1000,
                                Content_H => 600, Columns => Cols, Scroll_Pixels => 0, Line_Height => LH);
         Row_H   : constant Natural := LH + 2 * IG.Row_Padding (LH);
         Cell    : constant IG.Item_Layout :=
           (Visible_Index => 1, X => 0, Y => 0, Width => 1000, Height => 2 * LH, Text_Y => 4,
            Modified_X => 300, Modified_Width => 200, others => 0);
         Rects   : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text    : Guikit.Draw.Text_Command_Vectors.Vector;
         Tips    : Guikit.Draw.Tooltip_Command_Vectors.Vector;
         Wide    : constant IG.Item_Layout :=
           (Visible_Index => 1, X => 50, Y => 0, Width => 7 * LH, Height => 5 * LH, others => 0);
         Field_X, Field_W : Natural;
      begin
         --  Small icons: a padded icon, the icon-to-label gap, then the label;
         --  the next cell one scaled grid gap along.
         Assert (Small (1).Width = IG.Small_Cell_Width (LH) and then Small (1).Height = LH + 2 * Pad,
                 "a small-icon cell is the scaled width and a line plus two paddings tall" & Where);
         Assert (Small (1).Icon_X = Pad and then Small (1).Icon_Y = Pad and then Small (1).Icon_Size = LH,
                 "a small-icon cell's icon is inset by the scaled padding" & Where);
         Assert (Small (1).Text_X = Pad + LH + IG.Icon_Text_Gap (LH),
                 "a small-icon label follows the icon by the scaled gap" & Where);
         Assert (Small (1).Text_Width = IG.Small_Cell_Width (LH) - 2 * Pad - LH - IG.Icon_Text_Gap (LH),
                 "a small-icon label takes the rest of the padded cell" & Where);
         Assert (Small (2).X = IG.Small_Cell_Width (LH) + Gap and then Small (2).Y = 0,
                 "the next small-icon cell is one scaled grid gap along" & Where);

         --  Details: a header band, then rows padded above and below.
         Assert (Details (1).Y = Row_H and then Details (1).Height = Row_H,
                 "a details row is a line plus two scaled row paddings, below an equal header" & Where);
         Assert (Details (2).Y = 2 * Row_H, "details rows stack one scaled row apart" & Where);
         Assert (Details (1).Icon_X = IG.Row_Padding (LH),
                 "a details row's icon is inset by the scaled row padding" & Where);
         Assert (Details (1).Text_X = Cols (IG.Name_Column).X + IG.Column_Padding (LH),
                 "a details name is inset into its column by the scaled column padding" & Where);

         --  The other details columns are inset by the same scaled padding.
         IG.Draw_Details_Row
           (Rects, Text, Tips, 2000, 2000, Cell, LH,
            Modified => To_Unbounded_String ("today"), Size => Null_Unbounded_String,
            Filetype => Null_Unbounded_String, Created => Null_Unbounded_String,
            Permissions => Null_Unbounded_String, Modified_Tooltip => Null_Unbounded_String,
            Created_Tooltip => Null_Unbounded_String, Dim => False, Value_Color => Guikit.Draw.Text_Color,
            Dim_Color => Guikit.Draw.Muted_Text_Color, Border_Color => Guikit.Draw.Border_Color);
         Assert (Natural (Text.Length) = 1, "the one non-empty column draws its value" & Where);
         Assert (Text (1).X = 300 + IG.Column_Padding (LH),
                 "a details column value is inset by the scaled column padding" & Where);

         --  A large-icon rename field spans the cell less the scaled padding.
         IG.Rename_Field_Extent (Wide, IG.Icons_Large, Renaming => True, Field_X => Field_X, Field_W => Field_W,
                                 Line_Height => LH);
         Assert (Field_X = 50 + Pad and then Field_W = 7 * LH - 2 * Pad,
                 "a large-icon rename field is inset by the scaled content padding" & Where);
      end Check_Layout;
   begin
      Check_Spacing (20, Gap => 8, Content => 4, Icon_Gap => 12, Row => 4, Column => 6, Small_W => 216);
      Check_Spacing (30, Gap => 12, Content => 6, Icon_Gap => 18, Row => 6, Column => 9, Small_W => 324);
      Check_Spacing (40, Gap => 16, Content => 8, Icon_Gap => 24, Row => 8, Column => 12, Small_W => 432);
      Assert (IG.Grid_Gap (10) = IG.Main_Grid_Gap and then IG.Small_Cell_Width (10) = IG.Small_Icon_Cell_Width,
              "below the reference line height the grid keeps its base spacing");

      Items.Append (IG.Layout_Item'(Visible_Index => 1, Group_Header => False, Label => To_Unbounded_String ("a")));
      Items.Append (IG.Layout_Item'(Visible_Index => 2, Group_Header => False, Label => To_Unbounded_String ("b")));
      Cols (IG.Name_Column) := (X => 20, Width => 380);
      Check_Layout (20);
      Check_Layout (30);
      Check_Layout (40);

      --  At twice the line height the small-icon geometry is exactly doubled.
      declare
         Base   : constant IG.Item_Layout_Vectors.Vector :=
           IG.Calculate_Layout (Items, IG.Icons_Small, 0, 0, 1000, 600, Cols, 0, 20);
         Double : constant IG.Item_Layout_Vectors.Vector :=
           IG.Calculate_Layout (Items, IG.Icons_Small, 0, 0, 1000, 600, Cols, 0, 40);
      begin
         for Index in 1 .. 2 loop
            Assert (Double (Index).X = 2 * Base (Index).X and then Double (Index).Width = 2 * Base (Index).Width
                      and then Double (Index).Height = 2 * Base (Index).Height
                      and then Double (Index).Icon_X = 2 * Base (Index).Icon_X
                      and then Double (Index).Text_X = 2 * Base (Index).Text_X
                      and then Double (Index).Text_Width = 2 * Base (Index).Text_Width,
                    "every small-icon cell measure doubles at twice the line height");
         end loop;
      end;
   end Test_Line_Height_Scaling;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Grid_Test_Case));
      return Result;
   end Suite;

end Guikit_Suite.Item_Grid;
