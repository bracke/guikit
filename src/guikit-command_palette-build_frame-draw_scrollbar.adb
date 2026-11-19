separate (Guikit.Command_Palette.Build_Frame)
procedure Draw_Scrollbar is
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
end Draw_Scrollbar;
