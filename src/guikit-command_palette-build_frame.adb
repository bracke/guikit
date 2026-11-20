separate (Guikit.Command_Palette)
procedure Build_Frame
  (P             : in out Palette;
   Region_X      : Natural;
   Region_Y      : Natural;
   Region_Width  : Natural;
   Region_Height : Natural;
   Clip_Width    : Natural;
   Clip_Height   : Natural;
   Focused       : Boolean;
   Hover_X       : Integer;
   Hover_Y       : Integer;
   Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
   Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
   Icons         : out Guikit.Draw.Icon_Command_Vectors.Vector;
   Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector;
   Has_Glyph     : access function (Codepoint : Natural) return Boolean := null)
is
   LH      : constant Positive := P.Config.Line_Height;
   --  Reserve a title band (one line plus a gap) at the top when a heading is
   --  configured, so the search box and results sit below it.
   Title_H : constant Natural :=
     (if Length (P.Config.Title) > 0
      then Guikit.Layout.Palette_Title_Height (LH) else 0);
   Layout  : constant Guikit.Layout.Palette_Layout :=
     Guikit.Layout.Calculate_Palette_Layout
       (Region_X, Region_Y, Region_Width, Region_Height, LH, Title_H);
   Pad     : constant Natural := Guikit.Layout.Scaled (Guikit.Layout.Palette_Padding, LH);
   Row_Pad : constant Natural := Guikit.Layout.Scaled (Guikit.Layout.Palette_Result_Row_Padding, LH);
   Cell_W  : constant Natural := Guikit.Layout.Caret_Advance_Width (LH);
   Icon_Slot : constant Natural := Guikit.Layout.Scaled (Icon_Slot_Base, LH);
   Bar_Width : constant Natural := Guikit.Layout.Scaled (Bar_Width_Base, LH);
   --  The icon's margin above and below it within a row, together.
   Icon_Margins : constant Natural := Guikit.Layout.Scaled (8, LH);
   Gutter  : constant Natural := (if P.Config.Show_Icons then Pad + Icon_Slot else 0);
   Count   : constant Natural := Ranked_Count (P);
   Q       : constant String := To_String (P.Query);
   Text_Y  : constant Natural :=
     (if Layout.Search_Height > LH
      then Layout.Search_Y + (Layout.Search_Height - LH) / 2
      else Layout.Search_Y);
   --  Overlay close-button geometry (top-right). Without a title the close icon
   --  shares the search row, so the search field is shortened to end before it;
   --  with a title the close icon sits in the title row and the search is full
   --  width.
   Close_Inset   : constant Natural := Guikit.Layout.Panel_Edge_Inset (LH);
   Close_Reserve : constant Natural := Guikit.Layout.Close_Button_Reserve (LH);
   Search_W    : constant Natural :=
     (if Title_H > 0 then Layout.Search_Width
      elsif P.Config.Overlay
        and then Layout.X + Layout.Width > Layout.Search_X + Close_Reserve
      then (Layout.X + Layout.Width - Close_Reserve) - Layout.Search_X
      else Layout.Search_Width);
   Field_W : constant Natural :=
     (if Search_W > 2 * Pad then Search_W - 2 * Pad else 0);
   Field_X : constant Natural := Layout.Search_X + Pad;
   Caret_W : constant Natural := Natural'Max (1, Cell_W / 6);
   --  The caret sits at the end of the query. A query longer than the field
   --  scrolls its leading columns off the left edge (Guikit.Text_Fields,
   --  as every field does) so the caret, and the text being typed, stay in
   --  the field instead of running on under the close button.
   Field       : constant Guikit.Text_Fields.View :=
     Guikit.Text_Fields.View_Of (Q, Q'Length, Field_W, LH, Caret_W, Has_Glyph => Has_Glyph);
   Shown_Query : constant String := Q (Q'First + Field.Skip_Bytes .. Q'Last);
   Caret_X     : constant Natural := Field_X + Field.Caret_X;

   --  Forget the last frame's row rectangles, count the rows that fit,
   --  and keep the selection on screen for the current layout.
   procedure Scroll_To_Selection is
   begin
      P.Rows.Clear;
      P.Visible_Rows := Guikit.Layout.Visible_Row_Count (Layout.Results_Height, Layout.Row_Height);

      P.Offset :=
        Guikit.Layout.Scroll_Offset_For_Selection
          (Selected       => P.Selected,
           Result_Count   => Count,
           Visible_Rows   => P.Visible_Rows,
           Current_Offset => P.Offset);
   end Scroll_To_Selection;

   --  The panel: its shadow when it floats, background, accent band and
   --  dialog node.
   procedure Draw_Chrome is separate;

   --  Panel title (heading): top-left, aligned with the close icon and matching
   --  the settings panel's title; the search box sits below it.
   procedure Draw_Title is separate;

   --  The search box with the query or its placeholder, and the caret
   --  and focus ring while it has focus.
   procedure Draw_Search_Field is separate;

   --  One result row: its icon, label, shortcut and description, and
   --  the rectangle a click on it hits.
   procedure Draw_Result_Row (Row : Guikit.Layout.Palette_Result_Row) is separate;

   --  The visible result rows, from the scroll offset on.
   procedure Draw_Result_Rows is separate;

   --  What the results area says when nothing matches.
   procedure Draw_Empty_State is separate;

   --  The results' scrollbar, when they do not all fit.
   procedure Draw_Scrollbar is separate;

   --  Overlay close button, at the panel's top-right: drawn exactly where,
   --  and only when, Guikit.Layout.Panel_Close_Button says a click hits it.
   procedure Draw_Close_Button is separate;
begin
   --  Out vectors are passed by reference: drop what the caller's held.
   Rectangles.Clear;
   Text.Clear;
   Icons.Clear;
   Accessibility.Clear;
   Scroll_To_Selection;
   Draw_Chrome;
   Draw_Title;
   Draw_Search_Field;
   Draw_Result_Rows;
   Draw_Empty_State;
   Draw_Scrollbar;
   Draw_Close_Button;
end Build_Frame;
