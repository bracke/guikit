separate (Guikit.Settings_Panel.Build_Frame)
--  Rows (the active section's fields, compact).
procedure Draw_Rows is
begin
   for VR in 1 .. Vis_N loop
      declare
         I   : constant Positive := Visible (VR);
         F   : constant Field := P.Fields.Element (I);
         R   : constant Natural := VR - 1;
         Vis : constant Boolean :=
           R >= P.Offset and then (P.Visible_Rows = 0 or else R < P.Offset + P.Visible_Rows);
         --  Section rows sit below an extra gap that separates them from the
         --  preamble (the action buttons) above.
         Extra : constant Natural :=
           (if Preamble_Rows > 0 and then Preamble_Rows < Vis_N and then VR > Preamble_Rows
            then Group_Gap else 0);
         --  Rows scrolled above the view are not drawn; their Y is never read.
         Row_Y : constant Natural := (if R >= P.Offset then Rows_Top + (R - P.Offset) * Row_H + Extra else 0);
         Mid_Y : constant Natural := Row_Y + (Row_H - LH) / 2;
         --  A toggle occupies only the far-right end of the shared value
         --  column. Let its label use the otherwise blank space up to that
         --  switch, which keeps localized labels legible without moving the
         --  aligned controls used by the other field kinds.
         Field_Label_W : constant Natural :=
           (if F.Kind = Toggle and then Content_W > 2 * LH + Pad
            then Content_W - 2 * LH - Pad
            else Label_W);
      begin
         exit when not Vis and then R >= P.Offset + P.Visible_Rows;
         if Vis then
            if I = P.Focused then
               Add_Rect (Hl_X, Row_Y, Hl_W, Row_H, Guikit.Draw.Hover_Color);
               Add_Rect (Accent_X, Row_Y, Accent_W, Row_H, Guikit.Draw.Selection_Color);
               if Focused then
                  Guikit.Widgets.Draw_Focus_Ring
                    (Rectangles, Clip_Width, Clip_Height, Hl_X, Row_Y,
                     Hl_W, Row_H, Guikit.Draw.Selection_Color);
               end if;
            end if;

            if F.Kind = Section then
               Add_Text (Content_X, Mid_Y, Content_W, F.Label, Guikit.Draw.Muted_Text_Color);
               Add_Rect
                 (Content_X, Row_Y + Row_H - Guikit.Layout.Scaled (2, LH), Content_W, 1, Guikit.Draw.Border_Color);
               Accessibility.Append
                 (Guikit.Draw.Accessibility_Node'
                    (Role => Guikit.Draw.Role_Heading, X => Content_X, Y => Row_Y,
                     Width => Content_W, Height => Row_H, Name => F.Label, others => <>));
            else
               Add_Text
                 (Content_X, Mid_Y, Field_Label_W, F.Label,
                  (if F.Enabled then Guikit.Draw.Text_Color else Guikit.Draw.Disabled_Text_Color));
               Add_Hit (Hit_Focus, I, 0, Region_X, Row_Y, Region_Width, Row_H);

               Draw_Control (I, F, Row_Y);

               Accessibility.Append
                 (Guikit.Draw.Accessibility_Node'
                    (Role => (if F.Kind = Buttons then Guikit.Draw.Role_Button else Guikit.Draw.Role_Text_Input),
                     X => Region_X, Y => Row_Y, Width => Region_Width, Height => Row_H,
                     Name => F.Label,
                     Description =>
                       (if Length (F.Help) > 0 then F.Help
                        elsif Length (F.Display) > 0 then F.Display
                        else F.Value),
                     Enabled => F.Enabled, Selected => I = P.Focused,
                     --  The keyboard is on this field while the panel has it,
                     --  which a screen reader follows and announces.
                     Focused => Focused and then I = P.Focused));
            end if;
         end if;
      end;
   end loop;
end Draw_Rows;
