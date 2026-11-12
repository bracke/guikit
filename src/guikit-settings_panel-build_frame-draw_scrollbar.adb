separate (Guikit.Settings_Panel.Build_Frame)
--  Scrollbar.
procedure Draw_Scrollbar is
   Max_Scroll : constant Natural := (if Vis_N > P.Visible_Rows then Vis_N - P.Visible_Rows else 0);
   Thumb : constant Guikit.Layout.Scrollbar_Thumb :=
     Guikit.Layout.Calculate_Scrollbar_Thumb
       (Track_Length    => Avail_H,
        Visible_Amount  => P.Visible_Rows,
        Total_Amount    => Vis_N,
        Scroll_Position => P.Offset,
        Max_Scroll      => Max_Scroll,
        Min_Length      => Row_H);
begin
   if Thumb.Length > 0 and then Avail_H > 0 then
      Guikit.Widgets.Draw_Scrollbar
        (Rectangles   => Rectangles,
         Clip_Width   => Clip_Width,
         Clip_Height  => Clip_Height,
         Track_X      => Region_X + Region_Width - Bar_W,
         Track_Y      => Rows_Top,
         Track_Width  => Bar_W,
         Track_Height => Avail_H,
         Thumb_Y      => Rows_Top + Thumb.Offset,
         Thumb_Height => Thumb.Length,
         Track_Color  => Guikit.Draw.Border_Color,
         Thumb_Color  => Guikit.Draw.Selection_Color,
         Grip_Color   => Guikit.Draw.Muted_Text_Color);
   end if;
end Draw_Scrollbar;
