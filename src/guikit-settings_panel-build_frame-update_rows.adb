separate (Guikit.Settings_Panel.Build_Frame)
--  Collect the fields shown as rows now (the preamble, then the active
--  section) into Visible, record how many there are and how many fit, clamp
--  the scroll and, when the focus has moved since the last frame, scroll the
--  focused row into view.
procedure Update_Rows is
begin
   for I in P.Fields.First_Index .. P.Fields.Last_Index loop
      if Field_Is_Visible (P, I) then
         Vis_N := Vis_N + 1;
         Visible (Vis_N) := I;
         if Field_Section (P, I) = 0 then
            Preamble_Rows := Preamble_Rows + 1;
         end if;
      end if;
   end loop;
   P.Content_Rows := Vis_N;
   declare
      --  The preamble→section gap consumes vertical space; discount it so the
      --  visible-row count (hence scrolling) reflects the taller layout.
      Split    : constant Boolean := Preamble_Rows > 0 and then Preamble_Rows < Vis_N;
      Gapped_H : constant Natural :=
        (if Split and then G.Avail_H > G.Group_Gap then G.Avail_H - G.Group_Gap else G.Avail_H);
   begin
      P.Visible_Rows := (if Row_H > 0 then Gapped_H / Row_H else 0);
   end;

   --  Clamp scroll and bring the focused row on screen when the focus has
   --  moved since the last frame (rows are the compact positions of the
   --  visible fields, not raw field indices). Only then: pulling the offset
   --  back to the focus every frame undid every wheel scroll away from it.
   declare
      Max_Scroll : constant Natural := (if Vis_N > P.Visible_Rows then Vis_N - P.Visible_Rows else 0);
      Focus_Row  : Natural := 0;
   begin
      for VR in 1 .. Vis_N loop
         if Visible (VR) = P.Focused then
            Focus_Row := VR - 1;
         end if;
      end loop;
      if P.Offset > Max_Scroll then
         P.Offset := Max_Scroll;
      end if;
      if P.Focused > 0 and then P.Focused /= P.Followed then
         if Focus_Row < P.Offset then
            P.Offset := Focus_Row;
         elsif P.Visible_Rows > 0 and then Focus_Row >= P.Offset + P.Visible_Rows then
            P.Offset := Focus_Row - P.Visible_Rows + 1;
         end if;
      end if;
      P.Followed := P.Focused;
   end;
end Update_Rows;
