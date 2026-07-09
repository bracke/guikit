with Guikit.Utf8;

package body Guikit.Layout is

   function Within
     (X          : Natural;
      Start_X    : Natural;
      Rect_Width : Natural)
      return Boolean is
   begin
      return Rect_Width > 0
        and then X >= Start_X
        and then X - Start_X < Rect_Width;
   end Within;

   function Within_Rect
     (X           : Natural;
      Y           : Natural;
      Rect_X      : Natural;
      Rect_Y      : Natural;
      Rect_Width  : Natural;
      Rect_Height : Natural)
      return Boolean is
   begin
      return Within (X, Rect_X, Rect_Width)
        and then Rect_Height > 0
        and then Y >= Rect_Y
        and then Y - Rect_Y < Rect_Height;
   end Within_Rect;

   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural is
   begin
      if Factor = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Natural'Last;
      else
         return Value * Factor;
      end if;
   end Saturating_Multiply;

   --  Compute Value * Factor / Denominator without overflowing, via a 64-bit
   --  intermediate, saturating at Natural'Last.
   function Bounded_Product_Divide
     (Value       : Natural;
      Factor      : Natural;
      Denominator : Natural)
      return Natural
   is
   begin
      if Value = 0 or else Factor = 0 or else Denominator = 0 then
         return 0;
      end if;

      declare
         Product : constant Long_Long_Integer :=
           Long_Long_Integer (Value) * Long_Long_Integer (Factor) / Long_Long_Integer (Denominator);
      begin
         if Product > Long_Long_Integer (Natural'Last) then
            return Natural'Last;
         end if;
         return Natural (Product);
      end;
   end Bounded_Product_Divide;

   function Calculate_Scrollbar_Thumb
     (Track_Length    : Natural;
      Visible_Amount  : Natural;
      Total_Amount    : Natural;
      Scroll_Position : Natural;
      Max_Scroll      : Natural;
      Min_Length      : Natural)
      return Scrollbar_Thumb
   is
      Length : Natural;
      Travel : Natural;
   begin
      if Track_Length = 0 or else Total_Amount = 0 or else Total_Amount <= Visible_Amount then
         return (Length => 0, Offset => 0);
      end if;

      Length :=
        Natural'Min
          (Track_Length,
           Natural'Max
             (Min_Length,
              Bounded_Product_Divide (Track_Length, Visible_Amount, Total_Amount)));
      Travel := (if Track_Length > Length then Track_Length - Length else 0);

      return
        (Length => Length,
         Offset =>
           (if Max_Scroll > 0
            then Bounded_Product_Divide (Travel, Scroll_Position, Max_Scroll)
            else 0));
   end Calculate_Scrollbar_Thumb;

   function Visible_Row_Count
     (Available_Height : Natural;
      Row_Height       : Natural)
      return Natural is
   begin
      if Available_Height = 0 or else Row_Height = 0 then
         return 0;
      end if;
      return Available_Height / Row_Height;
   end Visible_Row_Count;

   function Caret_Advance_Width
     (Line_Height : Positive := 20)
      return Positive is
   begin
      return Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
   end Caret_Advance_Width;

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Scaled_Down
     (Value       : Natural;
      Numerator   : Natural;
      Denominator : Positive)
      return Natural is
   begin
      return
        Saturating_Add
          (Saturating_Multiply (Value / Denominator, Numerator),
           Saturating_Multiply (Value mod Denominator, Numerator) / Denominator);
   end Scaled_Down;

   function Label_Pixel_Width
     (Text   : String;
      Cell_W : Natural)
      return Natural is
   begin
      return Saturating_Multiply (Guikit.Utf8.Display_Units (Text), Cell_W);
   end Label_Pixel_Width;

   --  Horizontal gap between the filter field, the scope chip, and the right
   --  edge of the toolbar section, matching the renderer's field margin.
   Scope_Chip_Margin : constant Natural := 6;

   function Filter_Scope_Chip_Region_Of
     (Toolbar     : Toolbar_Layout;
      Chip_Width  : Natural;
      Line_Height : Positive := 20)
      return Scope_Chip_Region
   is
      Min_Input  : constant Natural := Saturating_Multiply (Line_Height, 2);
      Required   : constant Natural :=
        Saturating_Add
          (Saturating_Add (Chip_Width, Min_Input), Saturating_Multiply (Scope_Chip_Margin, 3));
   begin
      if Chip_Width = 0 or else Toolbar.Right_Width < Required then
         return (Visible => False, others => 0);
      end if;

      return
        (Visible => True,
         X       => Saturating_Add (Toolbar.Right_X, Toolbar.Right_Width)
                      - Scope_Chip_Margin - Chip_Width,
         Y       => Toolbar_Input_Y (Line_Height),
         Width   => Chip_Width,
         Height  => Toolbar_Input_Height (Line_Height));
   end Filter_Scope_Chip_Region_Of;

   function Filter_Input_Field_Width
     (Toolbar     : Toolbar_Layout;
      Chip_Width  : Natural;
      Line_Height : Positive := 20)
      return Natural
   is
      Chip : constant Scope_Chip_Region :=
        Filter_Scope_Chip_Region_Of (Toolbar, Chip_Width, Line_Height);
      Both_Margins : constant Natural := Saturating_Multiply (Scope_Chip_Margin, 2);
   begin
      if not Chip.Visible then
         return (if Toolbar.Right_Width > Both_Margins then Toolbar.Right_Width - Both_Margins else 0);
      end if;

      declare
         Filter_X : constant Natural := Saturating_Add (Toolbar.Right_X, Scope_Chip_Margin);
         Field_End : constant Natural :=
           (if Chip.X > Scope_Chip_Margin then Chip.X - Scope_Chip_Margin else 0);
      begin
         return (if Field_End > Filter_X then Field_End - Filter_X else 0);
      end;
   end Filter_Input_Field_Width;

   function Calculate_Toolbar_Layout
     (Width : Natural)
      return Toolbar_Layout
   is
      Preferred_Left : constant Natural := Saturating_Multiply (Toolbar_Button_Width, Toolbar_Button_Count);
      --  The right region holds the filter/search input plus a fixed-width scope
      --  chip; at Width/5 the chip left the input only a couple of characters
      --  wide. Give it a larger share so the search field stays usable, while
      --  still leaving the path bar (the middle) the majority of the width.
      Side           : constant Natural := Width / 4;
      Left           : constant Natural := (if Width >= Preferred_Left then Preferred_Left else 0);
      Right          : constant Natural := Natural'Min (Side, Width - Left);
   begin
      return
        (Left_X       => 0,
         Left_Width   => Left,
         Middle_X     => Left,
         Middle_Width => Width - Left - Right,
         Right_X      => Width - Right,
         Right_Width  => Right);
   end Calculate_Toolbar_Layout;

   function Toolbar_Input_Height
     (Line_Height : Positive := 20)
      return Natural
   is
      Toolbar_H : constant Natural := Saturating_Multiply (Line_Height, 2);
      Wanted_H  : constant Natural :=
        Saturating_Add (Line_Height, Input_Field_Padding);
   begin
      return Natural'Min (Toolbar_H, Wanted_H);
   end Toolbar_Input_Height;

   function Toolbar_Input_Y
     (Line_Height : Positive := 20)
      return Natural
   is
      Toolbar_H : constant Natural := Saturating_Multiply (Line_Height, 2);
      Input_H   : constant Natural := Toolbar_Input_Height (Line_Height);
   begin
      if Toolbar_H > Input_H then
         return (Toolbar_H - Input_H) / 2;
      end if;

      return 0;
   end Toolbar_Input_Y;

   function Toolbar_Left_Button_X
     (Toolbar      : Toolbar_Layout;
      Button_Index : Natural)
      return Natural
   is
      Clamped_Index : constant Natural := Natural'Min (Button_Index, Toolbar_Button_Count);
   begin
      if Toolbar.Left_Width >= Saturating_Multiply (Toolbar_Button_Width, Toolbar_Button_Count) then
         return Saturating_Add (Toolbar.Left_X, Saturating_Multiply (Toolbar_Button_Width, Clamped_Index));
      end if;

      return Saturating_Add (Toolbar.Left_X, Scaled_Down (Toolbar.Left_Width, Clamped_Index, Toolbar_Button_Count));
   end Toolbar_Left_Button_X;

   function Toolbar_Left_Button_Width
     (Toolbar      : Toolbar_Layout;
      Button_Index : Natural)
      return Natural
   is
      Button_X : constant Natural := Toolbar_Left_Button_X (Toolbar, Button_Index);
      Next_X   : constant Natural := Toolbar_Left_Button_X (Toolbar, Button_Index + 1);
   begin
      if Button_Index >= Toolbar_Button_Count or else Next_X <= Button_X then
         return 0;
      end if;

      return Next_X - Button_X;
   end Toolbar_Left_Button_Width;

   function Calculate_Bottom_Bar_Layout
     (Width               : Natural;
      Small_Label_Width   : Natural;
      Large_Label_Width   : Natural;
      Details_Label_Width : Natural;
      Sort_Label_Width    : Natural;
      Info_Label_Width    : Natural;
      Line_Height         : Positive := 20)
      return Bottom_Bar_Layout
   is
      Button_Padding : constant Natural := Saturating_Multiply (Bottom_Bar_Padding, 3);
      Minimum_Button : constant Natural := Saturating_Multiply (Line_Height, 2);
      Small_Needed   : constant Natural :=
        Natural'Max (Minimum_Button, Saturating_Add (Small_Label_Width, Button_Padding));
      Large_Needed   : constant Natural :=
        Natural'Max (Minimum_Button, Saturating_Add (Large_Label_Width, Button_Padding));
      Details_Needed : constant Natural :=
        Natural'Max (Minimum_Button, Saturating_Add (Details_Label_Width, Button_Padding));
      Sort_Needed    : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Sort_Label_Width,
              Saturating_Multiply (Input_Field_Padding, 2)));
      Info_Needed    : constant Natural :=
        Natural'Max (Minimum_Button, Saturating_Add (Info_Label_Width, Button_Padding));
      Preferred_View : constant Natural :=
        Saturating_Add (Small_Needed, Saturating_Add (Large_Needed, Details_Needed));
      Preferred_Sort : constant Natural := Sort_Needed;
      Toggle_Wanted  : constant Natural := Info_Needed;
      Content_X      : constant Natural := (if Width > Saturating_Multiply (Bottom_Bar_Padding, 2)
                                            then Bottom_Bar_Padding * 2 else 0);
      Content_W      : constant Natural :=
        (if Width > Saturating_Multiply (Content_X, 2) then Width - Saturating_Multiply (Content_X, 2)
         else Width);
      View_W         : constant Natural := Natural'Min (Content_W, Preferred_View);
      After_View     : constant Natural := Content_W - View_W;
      Sort_W         : constant Natural := (if After_View >= Preferred_Sort then Preferred_Sort else 0);
      Remaining      : constant Natural := After_View - Sort_W;
      Toggle_W       : constant Natural := Natural'Min (Remaining, Toggle_Wanted);
      Info_W         : constant Natural := Remaining - Toggle_W;
      Sort_X         : constant Natural := Content_X + View_W;
      Info_X         : constant Natural := Content_X + View_W + Sort_W;
      Toggle_X       : constant Natural := Content_X + View_W + Sort_W + Info_W;
   begin
      return
        (View_Mode_X          => Content_X,
         View_Mode_Width      => View_W,
         Sort_Button_X        => Sort_X,
         Sort_Button_Width    => Sort_W,
         Info_X               => Info_X,
         Info_Width           => Info_W,
         Info_Pane_X          => Toggle_X,
         Info_Pane_Width      => Toggle_W);
   end Calculate_Bottom_Bar_Layout;

   function Calculate_Settings_Entry_Button_Layout
     (Pane_X             : Natural;
      Pane_Width         : Natural;
      Add_Label_Width    : Natural;
      Remove_Label_Width : Natural)
      return Settings_Entry_Button_Layout
   is
      Edge_Padding   : constant Natural := Settings_Pane_Padding;
      Button_Gap     : constant Natural := 4;
      Minimum_Button : constant Natural := 34;
      Add_Wanted     : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Add_Label_Width,
              Saturating_Multiply (Input_Field_Padding, 2)));
      Remove_Wanted  : constant Natural :=
        Natural'Max
          (Minimum_Button,
           Saturating_Add
             (Remove_Label_Width,
              Saturating_Multiply (Input_Field_Padding, 2)));
      Available      : constant Natural :=
        (if Pane_Width > Saturating_Multiply (Edge_Padding, 2)
         then Pane_Width - Saturating_Multiply (Edge_Padding, 2)
         else Pane_Width);
      Desired_Total  : constant Natural := Saturating_Add (Add_Wanted, Saturating_Add (Button_Gap, Remove_Wanted));
      Usable_Total   : constant Natural := Natural'Min (Available, Desired_Total);
      Add_W          : Natural := 0;
      Remove_W       : Natural := 0;
      Gap_W          : Natural := 0;
      Total_W        : Natural := 0;
      Total_X        : Natural := Pane_X;
      Remove_X       : Natural := Pane_X;
   begin
      if Usable_Total = 0 then
         return (others => <>);
      elsif Usable_Total <= Button_Gap then
         Add_W := Usable_Total;
      elsif Desired_Total <= Available then
         Add_W := Add_Wanted;
         Remove_W := Remove_Wanted;
         Gap_W := Button_Gap;
      else
         Gap_W := Button_Gap;
         Add_W := Natural'Min (Add_Wanted, (Usable_Total - Gap_W) / 2);
         Remove_W := Usable_Total - Gap_W - Add_W;
      end if;

      Total_W := Saturating_Add (Add_W, Saturating_Add (Gap_W, Remove_W));
      if Pane_Width > Saturating_Add (Total_W, Edge_Padding) then
         Total_X := Saturating_Add (Pane_X, Pane_Width - Total_W - Edge_Padding);
      end if;

      Remove_X := Saturating_Add (Total_X, Saturating_Add (Add_W, Gap_W));

      return
        (Add_Button_X        => Total_X,
         Add_Button_Width    => Add_W,
         Remove_Button_X     => Remove_X,
         Remove_Button_Width => Remove_W,
         Total_X             => Total_X,
         Total_Width         => Total_W);
   end Calculate_Settings_Entry_Button_Layout;

   function Calculate_Settings_Action_Button_Layout
     (Text_X     : Natural;
      Text_Width : Natural)
      return Settings_Action_Button_Layout
   is
      Gap      : constant Natural := 4;
      First_W  : constant Natural := (if Text_Width > Gap then (Text_Width - Gap) / 2 else 0);
      Offset   : constant Natural := Saturating_Add (First_W, Gap);
      Second_W : constant Natural := (if Text_Width > Offset then Text_Width - Offset else 0);
      Second_X : constant Natural := Saturating_Add (Text_X, Offset);
      Total_W  : constant Natural := Saturating_Add (Offset, Second_W);
   begin
      return
        (First_Button_X      => Text_X,
         First_Button_Width  => First_W,
         Second_Button_X     => Second_X,
         Second_Button_Width => Second_W,
         Total_X             => Text_X,
         Total_Width         => Total_W);
   end Calculate_Settings_Action_Button_Layout;

   function Calculate_Settings_Pane_Layout
     (Width          : Natural;
      Height         : Natural;
      Toolbar_Height : Natural;
      Line_Height    : Positive := 20)
      return Settings_Pane_Layout
   is
      Wanted_W : constant Natural := Natural'Max (440, Scaled_Down (Width, 4, 5));
      Pane_W : constant Natural := Natural'Min (Width, Wanted_W);
      --  Height for a typical settings section's rows plus the title, tab
      --  switcher, and footer chrome. A section is one tab's worth of fields, not
      --  the whole form, so this stays compact; a section taller than this (or the
      --  Height / 3 floor below) scrolls inside the pane rather than growing it.
      Section_Rows : constant := 15;
      Content_H : constant Natural :=
        Saturating_Add
          (Saturating_Multiply (Line_Height, Section_Rows),
           Saturating_Multiply (Settings_Row_Gap, Section_Rows - 1));
      Wanted_H : constant Natural :=
        Natural'Max
          (Saturating_Add (Content_H, Saturating_Multiply (Settings_Pane_Padding, 2)),
           Height / 3);
      Top_Margin : constant Natural :=
        Natural'Max (Saturating_Add (Toolbar_Height, 8), Height / 6);
      Available_H : constant Natural :=
        (if Height > Top_Margin then Height - Top_Margin else 0);
      Pane_H : constant Natural := Natural'Min (Wanted_H, Available_H);
      Pane_X : constant Natural := (if Width > Pane_W then (Width - Pane_W) / 2 else 0);
      Pane_Y : constant Natural :=
        (if Available_H > 0 then Top_Margin else Toolbar_Height);
      Text_X : constant Natural := Saturating_Add (Pane_X, Settings_Pane_Padding);
      Text_Y : constant Natural := Saturating_Add (Pane_Y, Settings_Pane_Padding);
      Text_W : constant Natural :=
        (if Pane_W > Saturating_Multiply (Settings_Pane_Padding, 2)
         then Pane_W - Saturating_Multiply (Settings_Pane_Padding, 2)
         else 0);
   begin
      return
        (X          => Pane_X,
         Y          => Pane_Y,
         Width      => Pane_W,
         Height     => Pane_H,
         Text_X     => Text_X,
         Text_Y     => Text_Y,
         Text_Width => Text_W);
   end Calculate_Settings_Pane_Layout;

   function Calculate_Palette_Layout
     (Command_X      : Natural;
      Command_Y      : Natural;
      Command_Width  : Natural;
      Command_Height : Natural;
      Line_Height    : Positive := 20)
      return Palette_Layout
   is
      Search_H  : constant Natural :=
        Natural'Min
          (Saturating_Add (Line_Height, Saturating_Multiply (Input_Field_Padding, 2)),
           (if Command_Height > Saturating_Multiply (Palette_Padding, 2)
            then Command_Height - Saturating_Multiply (Palette_Padding, 2)
            else Command_Height));
      Content_X : constant Natural := Saturating_Add (Command_X, Palette_Padding);
      Content_Y : constant Natural := Saturating_Add (Command_Y, Palette_Padding);
      Content_W : constant Natural :=
        (if Command_Width > Saturating_Multiply (Palette_Padding, 2)
         then Command_Width - Saturating_Multiply (Palette_Padding, 2)
         else Command_Width);
      Content_H : constant Natural :=
        (if Command_Height > Saturating_Multiply (Palette_Padding, 2)
         then Command_Height - Saturating_Multiply (Palette_Padding, 2)
         else Command_Height);
      Results_Y : constant Natural :=
        Saturating_Add (Content_Y, Saturating_Add (Search_H, Palette_Padding));
      Used_H    : constant Natural := Saturating_Add (Search_H, Palette_Padding);
   begin
      return
        (X              => Command_X,
         Y              => Command_Y,
         Width          => Command_Width,
         Height         => Command_Height,
         Search_X       => Content_X,
         Search_Y       => Content_Y,
         Search_Width   => Content_W,
         Search_Height  => Search_H,
         Results_X      => Content_X,
         Results_Y      => Results_Y,
         Results_Width  => Content_W,
         Results_Height => (if Content_H > Used_H then Content_H - Used_H else 0),
         Row_Height     =>
           Saturating_Add
             (Saturating_Multiply (Line_Height, 2),
              Saturating_Multiply (Palette_Result_Row_Padding, 2)));
   end Calculate_Palette_Layout;

   function Calculate_Palette_Result_Rows
     (Layout   : Palette_Layout;
      Enabled  : Palette_Enabled_Vectors.Vector;
      Selected : Natural;
      Offset   : Natural)
      return Palette_Result_Row_Vectors.Vector
   is
      Result       : Palette_Result_Row_Vectors.Vector;
      Result_Count : constant Natural := Natural (Enabled.Length);
      Visible_Rows : constant Natural :=
        Visible_Row_Count (Layout.Results_Height, Layout.Row_Height);
      Max_Offset   : constant Natural :=
        (if Visible_Rows = 0 or else Result_Count <= Visible_Rows
         then 0 else Result_Count - Visible_Rows);
      First_Row    : constant Natural := Natural'Min (Offset, Max_Offset);
   begin
      if Layout.Row_Height = 0 then
         return Result;
      end if;

      for Index in First_Row + 1 .. Result_Count loop
         declare
            Row_Y : constant Natural :=
              Saturating_Add
                (Layout.Results_Y,
                 Saturating_Multiply (Natural (Index - First_Row - 1), Layout.Row_Height));
            Results_End_Y : constant Natural :=
              Saturating_Add (Layout.Results_Y, Layout.Results_Height);
         begin
            exit when Row_Y >= Results_End_Y;
            exit when Results_End_Y - Row_Y < Layout.Row_Height;
            Result.Append
              (Palette_Result_Row'
                 (Result_Index => Index,
                  X            => Layout.Results_X,
                  Y            => Row_Y,
                  Width        => Layout.Results_Width,
                  Height       => Layout.Row_Height,
                  Selected     => Index = Selected,
                  Enabled      => Enabled.Element (Index)));
         end;
      end loop;

      return Result;
   end Calculate_Palette_Result_Rows;

   function Scroll_Offset_For_Selection
     (Selected       : Natural;
      Result_Count   : Natural;
      Visible_Rows   : Natural;
      Current_Offset : Natural)
      return Natural
   is
      Offset : Natural := Current_Offset;
   begin
      if Result_Count = 0 or else Selected = 0 then
         return 0;
      end if;

      --  Clamp to the last full page, then pull the window onto the selection.
      if Visible_Rows = 0 or else Result_Count <= Visible_Rows then
         Offset := 0;
      elsif Offset > Result_Count - Visible_Rows then
         Offset := Result_Count - Visible_Rows;
      end if;

      if Selected <= Offset then
         Offset := Selected - 1;
      elsif Selected > Offset + Visible_Rows then
         Offset := Selected - Visible_Rows;
      end if;

      return Offset;
   end Scroll_Offset_For_Selection;

   function Palette_Result_At
     (Rows : Palette_Result_Row_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Within_Rect (X, Y, Row.X, Row.Y, Row.Width, Row.Height) then
            return Row.Result_Index;
         end if;
      end loop;

      return 0;
   end Palette_Result_At;

end Guikit.Layout;
