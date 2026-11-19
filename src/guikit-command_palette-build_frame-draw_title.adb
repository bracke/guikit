separate (Guikit.Command_Palette.Build_Frame)
procedure Draw_Title is
begin
   if Title_H > 0 then
      declare
         Title_X : constant Natural := Layout.X + Pad;
         Title_Y : constant Natural := Layout.Y + Close_Inset;
         Title_W : constant Natural :=
           (if Layout.Width > Pad + Close_Reserve
            then Layout.Width - Pad - Close_Reserve else 0);
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
end Draw_Title;
