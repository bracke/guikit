separate (Guikit.Settings_Panel.Build_Frame)
--  Close button (top-right), matching the common panel-close geometry and,
--  crucially, its glyph sizing/colour so every panel's close button is
--  identical: a narrow, line-height-tall glyph cell centred in the square, in
--  the regular text colour (the other panels use Files.Rendering's geometry).
procedure Draw_Close_Button is
   Inset : constant Natural := Edge_Inset;
   Btn   : constant Natural := LH;
   Bx    : constant Natural :=
     (if Region_Width > Inset + Btn then Region_X + Region_Width - Inset - Btn else Region_X);
   By    : constant Natural := Region_Y + Inset;
   Gw    : constant Natural := Guikit.Layout.Caret_Advance_Width (LH);
   Gx    : constant Natural := (if Btn > Gw then Bx + (Btn - Gw) / 2 else Bx);
begin
   Guikit.Widgets.Draw_Close_Button
     (Rectangles => Rectangles, Text => Text, Clip_Width => Clip_Width, Clip_Height => Clip_Height,
      Button_X => Bx, Button_Y => By, Button_Width => Btn, Button_Height => Btn,
      Fill_Color => Guikit.Draw.Pane_Color, Border_Color => Guikit.Draw.Border_Color,
      Glyph_X => Gx, Glyph_Y => By, Glyph_Width => Gw, Glyph_Height => Btn,
      --  U+00D7 (times): sits on the math axis so it centres in the button,
      --  unlike a lowercase "x" which sits low off-centre.
      Glyph => To_Unbounded_String (Character'Val (16#C3#) & Character'Val (16#97#)),
      Glyph_Color => Guikit.Draw.Text_Color,
      Show_Glyph => True);
   Accessibility.Append
     (Guikit.Draw.Accessibility_Node'
        (Role => Guikit.Draw.Role_Button, X => Bx, Y => By,
         Width => Btn, Height => Btn, Name => P.Config.Close_Label, others => <>));
end Draw_Close_Button;
