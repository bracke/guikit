separate (Guikit.Settings_Panel.Build_Frame)
--  Panel chrome: shadow, panel, accent bar, dialog role and title (the close
--  button is drawn later, by Draw_Close_Button, above the rows).
procedure Draw_Chrome is
begin
   Guikit.Widgets.Draw_Drop_Shadow
     (Rectangles, Clip_Width, Clip_Height, Region_X, Region_Y, Region_Width, Region_Height,
      Guikit.Draw.Shadow_Color, LH);
   Guikit.Widgets.Draw_Menu_Panel
     (Rectangles, Clip_Width, Clip_Height, Region_X, Region_Y, Region_Width, Region_Height,
      Guikit.Draw.Pane_Color, Guikit.Draw.Border_Color);
   Add_Rect
     (Region_X, Region_Y, Region_Width, Natural'Min (Guikit.Layout.Scaled (3, LH), Region_Height),
      Guikit.Draw.Selection_Color);
   Accessibility.Append
     (Guikit.Draw.Accessibility_Node'
        (Role => Guikit.Draw.Role_Dialog, X => Region_X, Y => Region_Y,
         Width => Region_Width, Height => Region_Height, Name => P.Config.Title, others => <>));
   Add_Text (Content_X, Title_Y, Title_W, P.Config.Title, Guikit.Draw.Text_Color);
end Draw_Chrome;
