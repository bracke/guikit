separate (Guikit.Command_Palette.Build_Frame)
procedure Draw_Empty_State is
begin
   if Count = 0 then
      if Length (P.Config.Empty_State) > 0 then
         Text.Append
           (Guikit.Draw.Text_Command'
              (X => Layout.Results_X + Pad, Y => Layout.Results_Y + Row_Pad,
               Width => (if Layout.Results_Width > 2 * Pad then Layout.Results_Width - 2 * Pad else 0),
               Height => LH, Text => P.Config.Empty_State, Color => Guikit.Draw.Muted_Text_Color,
               others => <>));
      end if;
      Accessibility.Append
        (Guikit.Draw.Accessibility_Node'
           (Role => Guikit.Draw.Role_Status, X => Layout.Results_X, Y => Layout.Results_Y,
            Width => Layout.Results_Width, Height => Layout.Row_Height,
            Name => P.Config.Empty_State, others => <>));
   end if;
end Draw_Empty_State;
