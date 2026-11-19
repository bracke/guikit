separate (Guikit.Command_Palette.Build_Frame)
procedure Draw_Close_Button is
begin
   if P.Config.Overlay then
      declare
         Button : constant Guikit.Layout.Close_Button_Layout :=
           Guikit.Layout.Panel_Close_Button (Layout.X, Layout.Y, Layout.Width, Layout.Height, LH);
         Bx     : constant Natural := Button.X;
         By     : constant Natural := Button.Y;
         Btn    : constant Natural := Button.Width;
      begin
         if Button.Visible then
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
         end if;
      end;
   end if;
end Draw_Close_Button;
