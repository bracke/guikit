separate (Guikit.Settings_Panel.Build_Frame)
--  Footer: the status line, else the focused field's help.
procedure Draw_Footer is
   Text_H : constant Natural := Natural (Foot_Lines.Length) * LH;
   Foot_Y : constant Natural := Rows_Bot + (if Foot_H > Text_H then (Foot_H - Text_H) / 2 else 0);
   Colour : constant Guikit.Draw.Render_Color :=
     (if Has_Status and then P.Config.Status_Is_Error then Guikit.Draw.Error_Text_Color
      else Guikit.Draw.Muted_Text_Color);
   Line_Y : Natural := Foot_Y;
begin
   for Line of Foot_Lines loop
      Add_Text (Content_X, Line_Y, Content_W, Line, Colour);
      Line_Y := Line_Y + LH;
   end loop;
end Draw_Footer;
