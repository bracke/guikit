with Guikit.Layout;
with Guikit.Palette;
with Guikit.Utf8;
with Guikit.Widgets;

package body Guikit.Command_Palette is

   use Ada.Strings.Unbounded;
   use type Guikit.Draw.Render_Color;

   Icon_Slot : constant Natural := 36;
   --  Match the grid/list scrollbar width so panels look consistent.
   Bar_Width : constant Natural := 12;
   Ellipsis  : constant String :=
     Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#A6#);  --  U+2026

   --  The commands matching the current query, ranked best-first (an empty query
   --  keeps input order). Each Guikit.Palette item's Id is the one-based index
   --  into Commands, so results map straight back.
   function Filtered (P : Palette) return Command_Vectors.Vector is
      Items  : Guikit.Palette.Item_Vectors.Vector;
      Result : Command_Vectors.Vector;
   begin
      for I in P.Commands.First_Index .. P.Commands.Last_Index loop
         declare
            C : constant Command := P.Commands.Element (I);
         begin
            Items.Append
              (Guikit.Palette.Item'
                 (Id          => I,
                  Identifier  => C.Identifier,
                  Label       => C.Label,
                  Description => C.Description,
                  Shortcut    => C.Shortcut,
                  Enabled     => C.Enabled,
                  Score       => 0));
         end;
      end loop;
      for Item of Guikit.Palette.Search (To_String (P.Query), Items) loop
         Result.Append (P.Commands.Element (Item.Id));
      end loop;
      return Result;
   end Filtered;

   --  Reset the selection to the first result (or none) after the query changes.
   procedure Reset_Selection (P : in out Palette) is
   begin
      P.Selected := (if Filtered (P).Is_Empty then 0 else 1);
      P.Offset   := 0;
   end Reset_Selection;

   --  Fit Text into Max_Cells display cells, appending an ellipsis when it does
   --  not fit; Truncated reports whether it was shortened.
   function Fit_To_Cells
     (Text      : String;
      Max_Cells : Natural;
      Truncated : out Boolean)
      return String
   is
      Index    : Integer := Text'First;
      Cells    : Natural := 0;
      Last_Fit : Integer := Text'First - 1;
   begin
      Truncated := False;
      if Max_Cells = 0 then
         Truncated := Text'Length > 0;
         return "";
      elsif Guikit.Utf8.Display_Units (Text) <= Max_Cells then
         return Text;
      end if;

      Truncated := True;
      while Index <= Text'Last loop
         declare
            Start : constant Integer := Index;
            CP    : Natural;
         begin
            Guikit.Utf8.Decode_Next_Codepoint (Text, Index, CP);
            declare
               W : constant Natural := Guikit.Utf8.Display_Units (Text (Start .. Index - 1));
            begin
               exit when Cells + W > Max_Cells - 1;
               Cells := Cells + W;
               Last_Fit := Index - 1;
            end;
         end;
      end loop;
      return Text (Text'First .. Last_Fit) & Ellipsis;
   end Fit_To_Cells;

   procedure Set_Configuration (P : in out Palette; Config : Configuration) is
   begin
      P.Config := Config;
   end Set_Configuration;

   procedure Set_Commands (P : in out Palette; Commands : Command_Vectors.Vector) is
      Count : Natural;
   begin
      P.Commands := Commands;
      Count := Natural (Filtered (P).Length);
      if Count = 0 then
         P.Selected := 0;
      elsif P.Selected = 0 or else P.Selected > Count then
         P.Selected := 1;
      end if;
   end Set_Commands;

   procedure Insert (P : in out Palette; Text : String) is
   begin
      Append (P.Query, Text);
      Reset_Selection (P);
   end Insert;

   procedure Backspace (P : in out Palette) is
      S    : constant String := To_String (P.Query);
      Last : Integer := S'Last;
   begin
      if S'Length = 0 then
         return;
      end if;
      while Last > S'First and then Character'Pos (S (Last)) in 16#80# .. 16#BF# loop
         Last := Last - 1;
      end loop;
      P.Query := To_Unbounded_String (S (S'First .. Last - 1));
      Reset_Selection (P);
   end Backspace;

   procedure Set_Query (P : in out Palette; Query : String) is
   begin
      P.Query := To_Unbounded_String (Query);
      Reset_Selection (P);
   end Set_Query;

   procedure Reset (P : in out Palette) is
   begin
      P.Query    := Null_Unbounded_String;
      P.Selected := 0;
      P.Offset   := 0;
      P.Rows.Clear;
   end Reset;

   procedure Move_Selection (P : in out Palette; Delta_Rows : Integer) is
      Count : constant Natural := Natural (Filtered (P).Length);
      Next  : Integer;
   begin
      if Count = 0 then
         P.Selected := 0;
         return;
      end if;
      if P.Config.Wrap_Selection then
         --  Wrap around the 1 .. Count range.
         Next := (if P.Selected = 0 then 1 else P.Selected) + Delta_Rows;
         while Next < 1 loop
            Next := Next + Count;
         end loop;
         while Next > Count loop
            Next := Next - Count;
         end loop;
      else
         Next := Integer'Max (1, Integer'Min (Integer (P.Selected) + Delta_Rows, Count));
      end if;
      P.Selected := Natural (Next);
   end Move_Selection;

   procedure Select_First (P : in out Palette) is
   begin
      P.Selected := (if Filtered (P).Is_Empty then 0 else 1);
   end Select_First;

   procedure Select_Last (P : in out Palette) is
   begin
      P.Selected := Natural (Filtered (P).Length);
   end Select_Last;

   procedure Page (P : in out Palette; Down : Boolean) is
      Step : constant Integer := Integer'Max (1, P.Visible_Rows);
   begin
      Move_Selection (P, (if Down then Step else -Step));
   end Page;

   function Click (P : in out Palette; X : Integer; Y : Integer) return Boolean is
   begin
      for Row of P.Rows loop
         if X >= Row.X and then X < Row.X + Row.W
           and then Y >= Row.Y and then Y < Row.Y + Row.H
         then
            P.Selected := Row.Result_Index;
            return True;
         end if;
      end loop;
      return False;
   end Click;

   function Query (P : Palette) return String is (To_String (P.Query));

   function Selected_Index (P : Palette) return Natural is (P.Selected);

   function Result_Count (P : Palette) return Natural is (Natural (Filtered (P).Length));

   function Selected_Id (P : Palette) return Natural is
      Results_View : constant Command_Vectors.Vector := Filtered (P);
   begin
      if P.Selected in 1 .. Natural (Results_View.Length) then
         return Results_View.Element (P.Selected).Id;
      end if;
      return 0;
   end Selected_Id;

   function Results (P : Palette) return Command_Vectors.Vector is (Filtered (P));

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
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      LH      : constant Positive := P.Config.Line_Height;
      Layout  : constant Guikit.Layout.Palette_Layout :=
        Guikit.Layout.Calculate_Palette_Layout (Region_X, Region_Y, Region_Width, Region_Height, LH);
      Pad     : constant Natural := Guikit.Layout.Palette_Padding;
      Row_Pad : constant Natural := Guikit.Layout.Palette_Result_Row_Padding;
      Cell_W  : constant Natural := Guikit.Layout.Caret_Advance_Width (LH);
      Gutter  : constant Natural := (if P.Config.Show_Icons then Pad + Icon_Slot else 0);
      Ranked  : constant Command_Vectors.Vector := Filtered (P);
      Count   : constant Natural := Natural (Ranked.Length);
      Q       : constant String := To_String (P.Query);
      Text_Y  : constant Natural :=
        (if Layout.Search_Height > LH
         then Layout.Search_Y + (Layout.Search_Height - LH) / 2
         else Layout.Search_Y);
      Enabled : Guikit.Layout.Palette_Enabled_Vectors.Vector;
      --  Overlay close-button geometry (top-right). The search field is shortened
      --  to end before it so the input does not run under the close icon.
      Close_Btn   : constant Natural := LH;
      Close_Inset : constant Natural := Natural'Max (4, LH / 4);
      Search_W    : constant Natural :=
        (if P.Config.Overlay
           and then Layout.X + Layout.Width > Layout.Search_X + Close_Btn + 2 * Close_Inset
         then (Layout.X + Layout.Width - Close_Btn - 2 * Close_Inset) - Layout.Search_X
         else Layout.Search_Width);
      Field_W : constant Natural :=
        (if Search_W > 2 * Pad then Search_W - 2 * Pad else 0);
   begin
      P.Rows.Clear;
      P.Visible_Rows := Guikit.Layout.Visible_Row_Count (Layout.Results_Height, Layout.Row_Height);

      --  Keep the selection on screen for the current layout.
      P.Offset :=
        Guikit.Layout.Scroll_Offset_For_Selection
          (Selected       => P.Selected,
           Result_Count   => Count,
           Visible_Rows   => P.Visible_Rows,
           Current_Offset => P.Offset);

      --  Panel chrome.
      if P.Config.Overlay then
         Guikit.Widgets.Draw_Drop_Shadow
           (Rectangles, Clip_Width, Clip_Height, Layout.X, Layout.Y, Layout.Width, Layout.Height,
            Guikit.Draw.Overlay_Color);
      end if;
      Guikit.Widgets.Draw_Menu_Panel
        (Rectangles, Clip_Width, Clip_Height, Layout.X, Layout.Y, Layout.Width, Layout.Height,
         Guikit.Draw.Pane_Color, Guikit.Draw.Border_Color);
      Rectangles.Append
        (Guikit.Draw.Rectangle_Command'
           (X => Layout.X, Y => Layout.Y, Width => Layout.Width,
            Height => Natural'Min (3, Layout.Height), Color => Guikit.Draw.Selection_Color));
      Accessibility.Append
        (Guikit.Draw.Accessibility_Node'
           (Role => Guikit.Draw.Role_Dialog, X => Layout.X, Y => Layout.Y,
            Width => Layout.Width, Height => Layout.Height, others => <>));

      --  Search box + query/placeholder + caret.
      Guikit.Widgets.Draw_Input_Field
        (Rectangles, Clip_Width, Clip_Height, Layout.Search_X, Layout.Search_Y,
         Search_W, Layout.Search_Height, Guikit.Draw.Input_Color, Guikit.Draw.Border_Color);
      if Q'Length > 0 then
         Text.Append
           (Guikit.Draw.Text_Command'
              (X => Layout.Search_X + Pad, Y => Text_Y, Width => Field_W, Height => LH,
               Text => P.Query, Color => Guikit.Draw.Text_Color, others => <>));
      elsif Length (P.Config.Placeholder) > 0 then
         Text.Append
           (Guikit.Draw.Text_Command'
              (X => Layout.Search_X + Pad, Y => Text_Y, Width => Field_W, Height => LH,
               Text => P.Config.Placeholder, Color => Guikit.Draw.Muted_Text_Color, others => <>));
      end if;
      if Focused then
         Guikit.Widgets.Draw_Focus_Ring
           (Rectangles, Clip_Width, Clip_Height, Layout.Search_X, Layout.Search_Y,
            Search_W, Layout.Search_Height, Guikit.Draw.Selection_Color);
         Guikit.Widgets.Draw_Caret
           (Rectangles, Clip_Width, Clip_Height,
            Layout.Search_X + Pad + Guikit.Utf8.Display_Units (Q) * Cell_W, Text_Y,
            Natural'Max (1, Cell_W / 6), LH, Guikit.Draw.Text_Color);
      end if;
      Accessibility.Append
        (Guikit.Draw.Accessibility_Node'
           (Role => Guikit.Draw.Role_Text_Input, X => Layout.Search_X, Y => Layout.Search_Y,
            Width => Search_W, Height => Layout.Search_Height,
            Name => P.Query, Focused => Focused, others => <>));

      --  Result rows.
      for C of Ranked loop
         Enabled.Append (C.Enabled);
      end loop;
      declare
         Row_List : constant Guikit.Layout.Palette_Result_Row_Vectors.Vector :=
           Guikit.Layout.Calculate_Palette_Result_Rows (Layout, Enabled, P.Selected, P.Offset);
      begin
         for Row of Row_List loop
            declare
               C          : constant Command := Ranked.Element (Row.Result_Index);
               Hovered    : constant Boolean :=
                 Hover_X >= Row.X and then Hover_X < Row.X + Row.Width
                 and then Hover_Y >= Row.Y and then Hover_Y < Row.Y + Row.Height;
               Sc_Cells   : constant Natural :=
                 (if P.Config.Show_Shortcuts then Guikit.Utf8.Display_Units (To_String (C.Shortcut)) else 0);
               Sc_W       : constant Natural := (if Sc_Cells > 0 then Sc_Cells * Cell_W else 0);
               Sc_X       : constant Natural :=
                 (if Sc_W > 0 and then Row.Width > Sc_W + 2 * Pad then Row.X + Row.Width - Pad - Sc_W else 0);
               Label_X    : constant Natural := Row.X + Pad + Gutter;
               Label_Y    : constant Natural := Row.Y + Row_Pad;
               Right_Edge : constant Natural := (if Sc_X > 0 then Sc_X else Row.X + Row.Width - Pad);
               Label_W    : constant Natural :=
                 (if Right_Edge > Label_X + Pad then Right_Edge - Label_X - Pad else 0);
               Label_Trunc : Boolean;
               Desc_Trunc  : Boolean;
               Label_Fit  : constant String :=
                 Fit_To_Cells (To_String (C.Label), Label_W / Natural'Max (1, Cell_W), Label_Trunc);
               Has_Desc   : constant Boolean := Row.Height > LH and then Length (C.Description) > 0;
               Desc_Fit   : constant String :=
                 (if Has_Desc
                  then Fit_To_Cells (To_String (C.Description), Label_W / Natural'Max (1, Cell_W), Desc_Trunc)
                  else "");
            begin
               P.Rows.Append
                 (Row_Rect'(Result_Index => Row.Result_Index,
                            X => Row.X, Y => Row.Y, W => Row.Width, H => Row.Height));

               if P.Config.Show_Icons and then C.Icon.Width > 0 then
                  declare
                     Display : constant Natural :=
                       Natural'Min (Icon_Slot, (if Row.Height > 8 then Row.Height - 8 else Row.Height));
                  begin
                     Icons.Append
                       (Guikit.Draw.Icon_Command'
                          (X                => Row.X + Pad + (Icon_Slot - Display) / 2,
                           Y                => Row.Y + (if Row.Height > Display then (Row.Height - Display) / 2 else 0),
                           Size             => Display,
                           Thumbnail_Width  => C.Icon.Width,
                           Thumbnail_Height => C.Icon.Height,
                           Thumbnail_Pixels => C.Icon.Pixels,
                           others           => <>));
                  end;
               end if;

               Guikit.Widgets.Draw_Palette_Row
                 (Rectangles         => Rectangles,
                  Text               => Text,
                  Clip_Width         => Clip_Width,
                  Clip_Height        => Clip_Height,
                  Row_X              => Row.X,
                  Row_Y              => Row.Y,
                  Row_Width          => Row.Width,
                  Row_Height         => Row.Height,
                  Background_Color   =>
                    (if Row.Selected then Guikit.Draw.Selection_Color
                     elsif Hovered then Guikit.Draw.Hover_Color
                     else Guikit.Draw.Pane_Color),
                  Selected           => Row.Selected,
                  Accent_Color       => Guikit.Draw.Border_Color,
                  Label_X            => Label_X,
                  Label_Y            => Label_Y,
                  Label_Width        => Label_W,
                  Label_Height       => Natural'Min (LH, Row.Height),
                  Label_Text         => To_Unbounded_String (Label_Fit),
                  Label_Truncated    => Label_Trunc,
                  Label_Color        =>
                    (if C.Enabled then Guikit.Draw.Text_Color else Guikit.Draw.Muted_Text_Color),
                  Shortcut_X         => Sc_X,
                  Shortcut_Width     => Sc_W,
                  Shortcut_Text      => (if Sc_W > 0 then C.Shortcut else Null_Unbounded_String),
                  Shortcut_Truncated => False,
                  Shortcut_Color     => Guikit.Draw.Muted_Text_Color,
                  Description_Y      => Label_Y + LH,
                  Description_Width  => (if Has_Desc then Label_W else 0),
                  Description_Height =>
                    (if Has_Desc then Natural'Min (LH, Row.Height - Row_Pad - LH) else 0),
                  Description_Text   => To_Unbounded_String (Desc_Fit),
                  Description_Truncated => Desc_Trunc,
                  Description_Color  => Guikit.Draw.Muted_Text_Color);

               Accessibility.Append
                 (Guikit.Draw.Accessibility_Node'
                    (Role => Guikit.Draw.Role_List_Item, X => Row.X, Y => Row.Y,
                     Width => Row.Width, Height => Row.Height, Name => C.Label,
                     Description => C.Description, Enabled => C.Enabled, Selected => Row.Selected,
                     others => <>));
            end;
         end loop;
      end;

      --  Empty state.
      if Count = 0 then
         if Length (P.Config.Empty_State) > 0 then
            Text.Append
              (Guikit.Draw.Text_Command'
                 (X => Layout.Results_X + Pad, Y => Layout.Results_Y + Row_Pad,
                  Width => (if Layout.Results_Width > 2 * Pad then Layout.Results_Width - 2 * Pad else 0),
                  Height => LH, Text => P.Config.Empty_State, Color => Guikit.Draw.Muted_Text_Color,
                  others => <>));
         end if;
         Accessibility.Append
           (Guikit.Draw.Accessibility_Node'
              (Role => Guikit.Draw.Role_Status, X => Layout.Results_X, Y => Layout.Results_Y,
               Width => Layout.Results_Width, Height => Layout.Row_Height,
               Name => P.Config.Empty_State, others => <>));
      end if;

      --  Scrollbar.
      declare
         Max_Scroll : constant Natural :=
           (if Count > P.Visible_Rows then Count - P.Visible_Rows else 0);
         Thumb : constant Guikit.Layout.Scrollbar_Thumb :=
           Guikit.Layout.Calculate_Scrollbar_Thumb
             (Track_Length    => Layout.Results_Height,
              Visible_Amount  => P.Visible_Rows,
              Total_Amount    => Count,
              Scroll_Position => P.Offset,
              Max_Scroll      => Max_Scroll,
              Min_Length      => Layout.Row_Height);
      begin
         if Thumb.Length > 0 and then Layout.Results_Width > Bar_Width then
            Guikit.Widgets.Draw_Scrollbar
              (Rectangles   => Rectangles,
               Clip_Width   => Clip_Width,
               Clip_Height  => Clip_Height,
               Track_X      => Layout.X + Layout.Width - Bar_Width,
               Track_Y      => Layout.Results_Y,
               Track_Width  => Bar_Width,
               Track_Height => Layout.Results_Height,
               Thumb_Y      => Layout.Results_Y + Thumb.Offset,
               Thumb_Height => Thumb.Length,
               Track_Color  => Guikit.Draw.Border_Color,
               Thumb_Color  => Guikit.Draw.Selection_Color,
               Grip_Color   => Guikit.Draw.Muted_Text_Color);
         end if;
      end;

      --  Overlay close button, at the panel's top-right (matching the common
      --  panel-close geometry: inset = max(4, line/4), a line-height square).
      if P.Config.Overlay then
         declare
            Inset : constant Natural := Close_Inset;
            Btn   : constant Natural := Close_Btn;
            Bx    : constant Natural :=
              (if Layout.Width > Inset + Btn then Layout.X + Layout.Width - Inset - Btn else Layout.X);
            By    : constant Natural := Layout.Y + Inset;
         begin
            Guikit.Widgets.Draw_Close_Button
              (Rectangles => Rectangles, Text => Text, Clip_Width => Clip_Width, Clip_Height => Clip_Height,
               Button_X => Bx, Button_Y => By, Button_Width => Btn, Button_Height => Btn,
               Fill_Color => Guikit.Draw.Pane_Color, Border_Color => Guikit.Draw.Border_Color,
               Glyph_X => Bx, Glyph_Y => By, Glyph_Width => Btn, Glyph_Height => Btn,
               --  U+00D7 (times), which sits on the math axis so it centres in
               --  the button, matching the other panels' close glyph.
               Glyph => To_Unbounded_String (Character'Val (16#C3#) & Character'Val (16#97#)),
               Glyph_Color => Guikit.Draw.Muted_Text_Color,
               Show_Glyph => True);
            Accessibility.Append
              (Guikit.Draw.Accessibility_Node'
                 (Role => Guikit.Draw.Role_Button, X => Bx, Y => By,
                  Width => Btn, Height => Btn, Name => To_Unbounded_String ("Close"), others => <>));
         end;
      end if;
   end Build_Frame;

end Guikit.Command_Palette;
