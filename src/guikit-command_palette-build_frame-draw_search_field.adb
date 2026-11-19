separate (Guikit.Command_Palette.Build_Frame)
procedure Draw_Search_Field is
begin
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
end Draw_Search_Field;
