separate (Guikit.Settings_Panel.Build_Frame)
--  The unstretched width a field's control needs. The value column is sized to
--  the widest control across every section (not just the visible one), so the
--  column -- and hence each control's right edge, e.g. toggles -- stays put
--  when switching sections, while still being no wider than necessary.
function Control_Width (F : Field) return Natural is
begin
   case F.Kind is
      when Toggle =>
         return 2 * LH;
      when Choice =>
         declare
            Segs : Guikit.Segmented.Segment_Vectors.Vector;
         begin
            for J in F.Option_Labels.First_Index .. F.Option_Labels.Last_Index loop
               Segs.Append
                 (Guikit.Segmented.Segment'(Label => F.Option_Labels.Element (J), others => <>));
            end loop;
            return Guikit.Segmented.Natural_Width (Segs, LH);
         end;
      when Buttons =>
         declare
            Count : constant Natural := Natural (F.Option_Labels.Length);
            Sum   : Natural := 0;
         begin
            for J in 1 .. Count loop
               Sum := Sum
                 + Guikit.Layout.Label_Pixel_Width (To_String (F.Option_Labels.Element (J)), Cell_W)
                 + 2 * Button_Pad;
            end loop;
            if Count > 1 then
               Sum := Sum + (Count - 1) * Button_Gap;
            end if;
            return Sum;
         end;
      when Number =>
         --  Two steppers plus room for a few digits.
         return 2 * LH + 5 * Cell_W;
      when Settings_Panel.Text | Shortcut =>
         --  An input field grows with its value but keeps a sensible minimum.
         return Natural'Max
                  (16 * Cell_W,
                   Guikit.Utf8.Display_Units
                     (To_String (if F.Kind = Shortcut and then Length (F.Display) > 0
                                 then F.Display else F.Value)) * Cell_W + 2 * Field_Inset);
      when Section =>
         return 0;
   end case;
end Control_Width;
