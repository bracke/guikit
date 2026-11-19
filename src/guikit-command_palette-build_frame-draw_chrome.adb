separate (Guikit.Command_Palette.Build_Frame)
procedure Draw_Chrome is
begin
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
         Height => Natural'Min (Guikit.Layout.Scaled (3, LH), Layout.Height),
         Color => Guikit.Draw.Selection_Color));
   Accessibility.Append
     (Guikit.Draw.Accessibility_Node'
        (Role => Guikit.Draw.Role_Dialog, X => Layout.X, Y => Layout.Y,
         Width => Layout.Width, Height => Layout.Height, others => <>));
end Draw_Chrome;
