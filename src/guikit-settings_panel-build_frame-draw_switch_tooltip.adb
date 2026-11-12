separate (Guikit.Settings_Panel.Build_Frame)
--  Tab-switcher hover tooltip: surfaces the keyboard tab-switch shortcut.
--  Drawn last so it sits above the rows; simple below-cursor placement is
--  enough because the switcher sits near the top of the pane.
procedure Draw_Switch_Tooltip is
begin
   if Tab_Count > 1 and then Length (P.Config.Switch_Tooltip) > 0
     and then Hover_X >= Content_X and then Hover_X < Content_X + Content_W
     and then Hover_Y >= Switch_Y and then Hover_Y < Switch_Y + Switch_H
   then
      declare
         Tip_Pad : constant Natural := Guikit.Layout.Scaled (6, LH);
         Tip_Gap : constant Natural := Guikit.Layout.Scaled (4, LH);
         Tip_Txt : constant String := To_String (P.Config.Switch_Tooltip);
         Tip_TW  : constant Natural := Guikit.Utf8.Display_Units (Tip_Txt) * Cell_W;
         Tip_W   : constant Natural := Tip_TW + 2 * Tip_Pad;
         Tip_H   : constant Natural := LH + 2 * Tip_Pad;
         Tip_X   : constant Natural :=
           (if Clip_Width > Tip_W then Natural'Min (Natural'Max (Hover_X, 0), Clip_Width - Tip_W) else 0);
         Below_Switch : constant Natural :=
           Guikit.Layout.Saturating_Add
             (Guikit.Layout.Saturating_Add (Switch_Y, Switch_H), Tip_Gap);
         Tip_Y   : constant Natural :=
           (if Below_Switch <= Clip_Height
              and then Tip_H <= Clip_Height - Below_Switch
            then Below_Switch
            elsif Switch_Y >= Tip_H + Tip_Gap
            then Switch_Y - Tip_H - Tip_Gap
            else 0);
      begin
         Guikit.Widgets.Draw_Tooltip
           (Rectangles      => Rectangles,
            Text            => Text,
            Clip_Width      => Clip_Width,
            Clip_Height     => Clip_Height,
            Box_X           => Tip_X,
            Box_Y           => Tip_Y,
            Box_Width       => Tip_W,
            Box_Height      => Tip_H,
            --  Tooltips cover live controls in compact layouts, so use an
            --  opaque surface: a translucent overlay lets labels beneath
            --  bleed into the tooltip text and become unreadable.
            Fill_Color      => Guikit.Draw.Pane_Color,
            Border_Color    => Guikit.Draw.Border_Color,
            Label_X         => Tip_X + Tip_Pad,
            Label_Y         => Tip_Y + Tip_Pad,
            Label_Width     => Tip_TW,
            Label_Height    => LH,
            Label_Text      => P.Config.Switch_Tooltip,
            Label_Truncated => False,
            Label_Color     => Guikit.Draw.Text_Color);
      end;
   end if;
end Draw_Switch_Tooltip;
