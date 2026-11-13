with Guikit.Layout;
with Guikit.Palette;
with Guikit.Utf8;
with Guikit.Utf8.Editing;
with Guikit.Widgets;

package body Guikit.Command_Palette is

   use Ada.Strings.Unbounded;
   use type Guikit.Draw.Render_Color;

   --  The width of a row's icon column at Guikit.Layout.Reference_Line_Height;
   --  it grows with the text like the rest of the chrome.
   Icon_Slot_Base : constant Natural := 36;
   --  Match the grid/list scrollbar width so panels look consistent (at the
   --  reference line height, scaled with the text).
   Bar_Width_Base : constant Natural := 12;
   --  Re-rank the commands for the current query unless the cached results
   --  already belong to this query and command list. Each Guikit.Palette
   --  item's Id is the one-based index into Commands, so results map straight
   --  back. An empty query keeps input order. A new ranking also drops the
   --  rows the last Build_Frame laid out: they map screen positions to the
   --  old ranking's indexes, so a click before the next frame must not pick
   --  from them.
   procedure Refresh_Results (P : in out Palette) is
      Items : Guikit.Palette.Item_Vectors.Vector;
   begin
      if P.Ranked_Revision = P.Revision and then P.Ranked_Query = P.Query then
         return;
      end if;
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
      P.Ranked.Clear;
      for Item of Guikit.Palette.Search (To_String (P.Query), Items) loop
         P.Ranked.Append (P.Commands.Element (Item.Id));
      end loop;
      P.Ranked_Query    := P.Query;
      P.Ranked_Revision := P.Revision;
      P.Rows.Clear;
   end Refresh_Results;

   --  The number of commands matching the current query: the cached ranking,
   --  which every query or command-list edit keeps current.
   function Ranked_Count (P : Palette) return Natural is (Natural (P.Ranked.Length));

   --  After the query changes: re-rank, and reset the selection to the first
   --  result (or none).
   procedure Reset_Selection (P : in out Palette) is
   begin
      Refresh_Results (P);
      P.Selected := (if Ranked_Count (P) = 0 then 0 else 1);
      P.Offset   := 0;
   end Reset_Selection;

   --  Fit Text into Max_Cells display cells with the toolkit's one truncation
   --  rule; Truncated reports whether it was shortened.
   function Fit_To_Cells
     (Text      : String;
      Max_Cells : Natural;
      Truncated : out Boolean)
      return String is
   begin
      Truncated := Guikit.Utf8.Display_Units (Text) > Max_Cells;
      return Guikit.Utf8.Fit_With_Ellipsis (Text, Max_Cells);
   end Fit_To_Cells;

   procedure Set_Configuration (P : in out Palette; Config : Configuration) is
   begin
      P.Config := Config;
   end Set_Configuration;

   procedure Set_Commands (P : in out Palette; Commands : Command_Vectors.Vector) is
      Count : Natural;
   begin
      P.Commands := Commands;
      P.Revision := P.Revision + 1;
      Refresh_Results (P);
      Count := Ranked_Count (P);
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
      S          : constant String := To_String (P.Query);
      New_Cursor : Natural;
   begin
      if S'Length = 0 then
         return;
      end if;
      --  The shared text-field rule: a whole character, with any combining
      --  marks after it, at the caret (which is the query's end).
      Guikit.Utf8.Editing.Delete_At
        (Text       => S,
         Cursor     => S'Length,
         Backward   => True,
         By_Word    => False,
         New_Text   => P.Query,
         New_Cursor => New_Cursor);
      pragma Unreferenced (New_Cursor);
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
      Refresh_Results (P);
      P.Selected := 0;
      P.Offset   := 0;
      P.Rows.Clear;
   end Reset;

   procedure Move_Selection (P : in out Palette; Delta_Rows : Integer) is
      Count : constant Natural := Ranked_Count (P);
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
      P.Selected := (if Ranked_Count (P) = 0 then 0 else 1);
   end Select_First;

   procedure Select_Last (P : in out Palette) is
   begin
      P.Selected := Ranked_Count (P);
   end Select_Last;

   procedure Page (P : in out Palette; Down : Boolean) is
      Step : constant Integer := Integer'Max (1, P.Visible_Rows);
   begin
      Move_Selection (P, (if Down then Step else -Step));
   end Page;

   function Click (P : in out Palette; X : Integer; Y : Integer) return Boolean is
   begin
      for Row of P.Rows loop
         --  Rows always belong to the current ranking (a re-rank clears them),
         --  but a row that names no current result is never a hit.
         if Row.Result_Index <= Ranked_Count (P)
           and then X >= Row.X and then X < Row.X + Row.W
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

   function Result_Count (P : Palette) return Natural is (Ranked_Count (P));

   function Selected_Id (P : Palette) return Natural is
   begin
      if P.Selected in 1 .. Ranked_Count (P) then
         return P.Ranked.Element (P.Selected).Id;
      end if;
      return 0;
   end Selected_Id;

   function Results (P : Palette) return Command_Vectors.Vector is (P.Ranked);

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
      --  Reserve a title band (one line plus a gap) at the top when a heading is
      --  configured, so the search box and results sit below it.
      Title_H : constant Natural :=
        (if Length (P.Config.Title) > 0
         then Guikit.Layout.Saturating_Add (LH, Guikit.Layout.Scaled (Guikit.Layout.Palette_Padding, LH)) else 0);
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
      Enabled : Guikit.Layout.Palette_Enabled_Vectors.Vector;
      --  Overlay close-button geometry (top-right). Without a title the close icon
      --  shares the search row, so the search field is shortened to end before it;
      --  with a title the close icon sits in the title row and the search is full
      --  width.
      Close_Btn   : constant Natural := LH;
      Close_Inset : constant Natural := Natural'Max (Guikit.Layout.Scaled (4, LH), LH / 4);
      Search_W    : constant Natural :=
        (if Title_H > 0 then Layout.Search_Width
         elsif P.Config.Overlay
           and then Layout.X + Layout.Width > Layout.Search_X + Close_Btn + 2 * Close_Inset
         then (Layout.X + Layout.Width - Close_Btn - 2 * Close_Inset) - Layout.Search_X
         else Layout.Search_Width);
      Field_W : constant Natural :=
        (if Search_W > 2 * Pad then Search_W - 2 * Pad else 0);
      Field_X : constant Natural := Layout.Search_X + Pad;
      Caret_W : constant Natural := Natural'Max (1, Cell_W / 6);
      --  The caret sits at the end of the query. A query longer than the field
      --  scrolls its leading columns off the left edge (as the item grid's
      --  rename field does) so the caret, and the text being typed, stay in the
      --  field instead of running on under the close button.
      Caret_Column : constant Natural := Guikit.Utf8.Display_Units (Q);
      Scroll_Columns : constant Natural :=
        Guikit.Layout.Input_Scroll_Columns (Caret_Column, Field_W, LH);

      --  The leading text that scrolls off: at least Scroll_Columns columns,
      --  cut on a cluster boundary. A cluster straddling the cut goes too,
      --  however wide it is -- a wide character, or an emoji family several
      --  columns wide -- rather than leaving the tail too wide for the field:
      --  the prefix widens a column at a time until it takes that cluster.
      function Scrolled_Off return String is
      begin
         for Columns in Scroll_Columns .. Caret_Column loop
            declare
               Prefix : constant String := Guikit.Utf8.Prefix_By_Units (Q, Columns);
            begin
               if Guikit.Utf8.Display_Units (Prefix) >= Scroll_Columns then
                  return Prefix;
               end if;
            end;
         end loop;
         return Q;
      end Scrolled_Off;

      Hidden       : constant String := Scrolled_Off;
      Shown_Query  : constant String := Q (Q'First + Hidden'Length .. Q'Last);
      Shown_Column : constant Natural := Caret_Column - Guikit.Utf8.Display_Units (Hidden);
      Caret_X      : constant Natural :=
        Field_X + Natural'Min (Shown_Column * Cell_W, (if Field_W > Caret_W then Field_W - Caret_W else 0));
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
            Guikit.Draw.Shadow_Color, LH);
      end if;
      Guikit.Widgets.Draw_Menu_Panel
        (Rectangles, Clip_Width, Clip_Height, Layout.X, Layout.Y, Layout.Width, Layout.Height,
         Guikit.Draw.Pane_Color, Guikit.Draw.Border_Color);
      Rectangles.Append
        (Guikit.Draw.Rectangle_Command'
           (X => Layout.X, Y => Layout.Y, Width => Layout.Width,
            Height => Natural'Min (Guikit.Layout.Scaled (3, LH), Layout.Height), Color => Guikit.Draw.Selection_Color));
      Accessibility.Append
        (Guikit.Draw.Accessibility_Node'
           (Role => Guikit.Draw.Role_Dialog, X => Layout.X, Y => Layout.Y,
            Width => Layout.Width, Height => Layout.Height, others => <>));

      --  Panel title (heading): top-left, aligned with the close icon and matching
      --  the settings panel's title; the search box sits below it.
      if Title_H > 0 then
         declare
            Title_X : constant Natural := Layout.X + Pad;
            Title_Y : constant Natural := Layout.Y + Natural'Max (Guikit.Layout.Scaled (4, LH), LH / 4);
            Title_W : constant Natural :=
              (if Layout.Width > Pad + Close_Btn + 2 * Close_Inset
               then Layout.Width - Pad - Close_Btn - 2 * Close_Inset else 0);
         begin
            if Title_W > 0 then
               Text.Append
                 (Guikit.Draw.Text_Command'
                    (X => Title_X, Y => Title_Y, Width => Title_W, Height => LH,
                     Text => P.Config.Title, Color => Guikit.Draw.Text_Color, others => <>));
               Accessibility.Append
                 (Guikit.Draw.Accessibility_Node'
                    (Role => Guikit.Draw.Role_Heading, X => Title_X, Y => Title_Y,
                     Width => Title_W, Height => LH, Name => P.Config.Title, others => <>));
            end if;
         end;
      end if;

      --  Search box + query/placeholder + caret.
      Guikit.Widgets.Draw_Input_Field
        (Rectangles, Clip_Width, Clip_Height, Layout.Search_X, Layout.Search_Y,
         Search_W, Layout.Search_Height, Guikit.Draw.Input_Color, Guikit.Draw.Border_Color);
      if Q'Length > 0 then
         --  Clipped to the field: the text command's width bounds the glyphs.
         Text.Append
           (Guikit.Draw.Text_Command'
              (X => Field_X, Y => Text_Y, Width => Field_W, Height => LH,
               Text => To_Unbounded_String (Shown_Query), Color => Guikit.Draw.Text_Color, others => <>));
      elsif Length (P.Config.Placeholder) > 0 then
         Text.Append
           (Guikit.Draw.Text_Command'
              (X => Field_X, Y => Text_Y, Width => Field_W, Height => LH,
               Text => P.Config.Placeholder, Color => Guikit.Draw.Muted_Text_Color, others => <>));
      end if;
      if Focused then
         Guikit.Widgets.Draw_Focus_Ring
           (Rectangles, Clip_Width, Clip_Height, Layout.Search_X, Layout.Search_Y,
            Search_W, Layout.Search_Height, Guikit.Draw.Selection_Color);
         Guikit.Widgets.Draw_Caret
           (Rectangles, Clip_Width, Clip_Height, Caret_X, Text_Y, Caret_W, LH, Guikit.Draw.Text_Color);
      end if;
      Accessibility.Append
        (Guikit.Draw.Accessibility_Node'
           (Role => Guikit.Draw.Role_Text_Input, X => Layout.Search_X, Y => Layout.Search_Y,
            Width => Search_W, Height => Layout.Search_Height,
            Name => P.Query, Focused => Focused, others => <>));

      --  Result rows.
      for C of P.Ranked loop
         Enabled.Append (C.Enabled);
      end loop;
      declare
         Row_List : constant Guikit.Layout.Palette_Result_Row_Vectors.Vector :=
           Guikit.Layout.Calculate_Palette_Result_Rows (Layout, Enabled, P.Selected, P.Offset);
      begin
         for Row of Row_List loop
            declare
               C          : constant Command := P.Ranked.Element (Row.Result_Index);
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
               --  A row with no description has nothing to truncate, and nothing
               --  assigns this: Fit_To_Cells sets it, and it is only called when
               --  Has_Desc. The aggregate below reads it either way, so without a
               --  value here it read whatever the stack happened to hold -- and a
               --  Boolean whose byte is neither 0 nor 1 raises Constraint_Error
               --  ("invalid data"). It only ever showed up once the optimiser
               --  stopped hiding it.
               Desc_Trunc  : Boolean := False;
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
                       Natural'Min
                         (Icon_Slot, (if Row.Height > Icon_Margins then Row.Height - Icon_Margins else Row.Height));
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
                  Accent_Width       => Guikit.Layout.Scaled (3, LH),
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
      --  panel-close geometry: inset = max(4 scaled, line/4), a line-height square).
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
                  Width => Btn, Height => Btn, Name => P.Config.Close_Label, others => <>));
         end;
      end if;
   end Build_Frame;

end Guikit.Command_Palette;
