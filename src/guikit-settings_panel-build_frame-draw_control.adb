separate (Guikit.Settings_Panel.Build_Frame)
--  The value control of one field row -- toggle, segmented choice, number
--  stepper, text or shortcut box, or button row -- and its hit rects. I is
--  the field's index, F the field, Row_Y the top of its row.
procedure Draw_Control (I : Positive; F : Field; Row_Y : Natural) is
begin
   case F.Kind is
      when Toggle =>
         declare
            TW : constant Natural := Natural'Min (Ctrl_W, 2 * LH);
            TH : constant Natural := Ctrl_H;
            TX : constant Natural := Ctrl_X + Ctrl_W - TW;
            TY : constant Natural := Row_Y + (Row_H - TH) / 2;
         begin
            Guikit.Widgets.Draw_Toggle
              (Rectangles, Clip_Width, Clip_Height, TX, TY, TW, TH, Is_True (F.Value),
               --  Muted text is the faintest colour that still
               --  clears 3:1 against the panel in every theme.
               Guikit.Draw.Selection_Color, Guikit.Draw.Input_Color,
               Guikit.Draw.Muted_Text_Color, Guikit.Draw.Text_Color);
            Add_Hit (Hit_Toggle, I, 0, TX, TY, TW, TH);
         end;

      when Choice =>
         declare
            Count : constant Natural := Natural (F.Option_Labels.Length);
         begin
            if Count > 0 and then Ctrl_W > 0 then
               declare
                  --  Fill the field row (leaving a small margin) so
                  --  the choice buttons are comfortably tall.
                  SH    : constant Natural := Ctrl_H;
                  SY    : constant Natural := Row_Y + (Row_H - SH) / 2;
                  Segs  : Guikit.Segmented.Segment_Vectors.Vector;
                  R     : Guikit.Draw.Rectangle_Command_Vectors.Vector;
                  T     : Guikit.Draw.Text_Command_Vectors.Vector;
                  Tips  : Guikit.Draw.Tooltip_Command_Vectors.Vector;
                  Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
                  CX, CW : Natural;

                  --  A choice whose options do not fit the shared value
                  --  column grows to the left, as far as its own label's
                  --  text leaves room, instead of squeezing its options
                  --  into clipped fragments ("Dateity", "Größ").
                  Need       : constant Natural := Control_Width (F);
                  Label_Need : constant Natural :=
                    Guikit.Layout.Label_Pixel_Width (To_String (F.Label), Cell_W) + Pad;
                  Room       : constant Natural :=
                    (if Content_W > Label_Need then Content_W - Label_Need else 0);
                  Row_W      : constant Natural :=
                    (if Need > Ctrl_W then Natural'Min (Need, Natural'Max (Ctrl_W, Room))
                     else Ctrl_W);
                  Row_X      : constant Natural := Content_X + Content_W - Row_W;
               begin
                  for J in 1 .. Count loop
                     Segs.Append
                       (Guikit.Segmented.Segment'
                          (Label => F.Option_Labels.Element (J), others => <>));
                  end loop;
                  --  Render the variable-width segmented control; the field-level
                  --  accessibility node below covers it, so its per-cell nodes and
                  --  (empty) tooltips are dropped.
                  Guikit.Segmented.Build_Frame
                    (Segments => Segs, Active => Option_Index (F),
                     Region_X => Row_X, Region_Y => SY, Region_Width => Row_W,
                     Region_Height => SH, Clip_Width => Clip_Width, Clip_Height => Clip_Height,
                     Line_Height => LH, Hover_X => Hover_X, Hover_Y => Hover_Y,
                     Rectangles => R, Text => T, Tooltips => Tips, Accessibility => Nodes);
                  for C of R loop
                     Rectangles.Append (C);
                  end loop;
                  for C of T loop
                     Text.Append (C);
                  end loop;
                  for J in 1 .. Count loop
                     Guikit.Segmented.Cell_Bounds (Segs, Row_X, Row_W, LH, J, CX, CW);
                     Add_Hit (Hit_Choice, I, J, CX, SY, CW, SH);
                  end loop;
               end;
            end if;
         end;

      when Number =>
         declare
            Btn : constant Natural := LH;
            BH  : constant Natural := Ctrl_H;
            BY  : constant Natural := Row_Y + (Row_H - BH) / 2;
            Val_X : constant Natural := Ctrl_X + Btn;
            Val_W : constant Natural := (if Ctrl_W > 2 * Btn then Ctrl_W - 2 * Btn else 0);
            Up_X  : constant Natural := Ctrl_X + Ctrl_W - Btn;
         begin
            Guikit.Widgets.Draw_Number_Stepper
              (Rectangles, Text, Clip_Width, Clip_Height, BY, BH, BY + (BH - LH) / 2, LH, Field_Inset,
               Val_X, Val_W, F.Value, Ctrl_X, Up_X, Btn,
               To_Unbounded_String ("-"), To_Unbounded_String ("+"),
               Guikit.Draw.Input_Color, Guikit.Draw.Border_Color, Guikit.Draw.Text_Color);
            Add_Hit (Hit_Step_Down, I, 0, Ctrl_X, BY, Btn, BH);
            Add_Hit (Hit_Step_Up, I, 0, Up_X, BY, Btn, BH);
         end;

      when Settings_Panel.Text =>
         declare
            TH : constant Natural := Ctrl_H;
            TY : constant Natural := Row_Y + (Row_H - TH) / 2;
            VY : constant Natural := Row_Y + (Row_H - LH) / 2;
         begin
            Guikit.Widgets.Draw_Input_Field
              (Rectangles, Clip_Width, Clip_Height, Ctrl_X, TY, Ctrl_W, TH,
               Guikit.Draw.Input_Color, Guikit.Draw.Border_Color);
            Add_Text (Ctrl_X + Field_Inset, VY,
                      (if Ctrl_W > 2 * Field_Inset then Ctrl_W - 2 * Field_Inset else 0), F.Value,
                      Guikit.Draw.Text_Color);
            if Focused and then I = P.Focused then
               Guikit.Widgets.Draw_Caret
                 (Rectangles, Clip_Width, Clip_Height,
                  Ctrl_X + Field_Inset + Guikit.Utf8.Display_Units (To_String (F.Value)) * Cell_W, VY,
                  Natural'Max (1, Cell_W / 6), LH, Guikit.Draw.Text_Color);
            end if;
         end;

      when Shortcut =>
         --  A chord box like Text, but edited press-to-capture: a
         --  click on the row arms the field (handled in Click via the
         --  row-level Hit_Focus), and while armed it is drawn with the
         --  selection accent plus a caret so the user sees it is
         --  waiting for a chord.
         declare
            Armed : constant Boolean := I = P.Capturing;
            TH : constant Natural := Ctrl_H;
            TY : constant Natural := Row_Y + (Row_H - TH) / 2;
            VY : constant Natural := Row_Y + (Row_H - LH) / 2;
            Shown : constant UString := (if Length (F.Display) > 0 then F.Display else F.Value);
         begin
            Guikit.Widgets.Draw_Input_Field
              (Rectangles, Clip_Width, Clip_Height, Ctrl_X, TY, Ctrl_W, TH,
               Guikit.Draw.Input_Color,
               (if Armed then Guikit.Draw.Selection_Color else Guikit.Draw.Border_Color));
            Add_Text (Ctrl_X + Field_Inset, VY,
                      (if Ctrl_W > 2 * Field_Inset then Ctrl_W - 2 * Field_Inset else 0), Shown,
                      (if F.Enabled then Guikit.Draw.Text_Color
                       else Guikit.Draw.Disabled_Text_Color));
            if Armed then
               Guikit.Widgets.Draw_Caret
                 (Rectangles, Clip_Width, Clip_Height,
                  Ctrl_X + Field_Inset + Guikit.Utf8.Display_Units (To_String (Shown)) * Cell_W, VY,
                  Natural'Max (1, Cell_W / 6), LH, Guikit.Draw.Selection_Color);
            end if;
         end;

      when Buttons =>
         declare
            Count : constant Natural := Natural (F.Option_Labels.Length);
         begin
            if Count > 0 and then Ctrl_W > 0 then
               declare
                  Even_W : constant Natural := (Ctrl_W - (Count - 1) * Button_Gap) / Count;
                  BH : constant Natural := Ctrl_H;
                  BY : constant Natural := Row_Y + (Row_H - BH) / 2;

                  --  A row with no label of its own is a row of
                  --  actions: its buttons take their natural width
                  --  and line up at the right edge, as dialog
                  --  buttons do, rather than stretching across the
                  --  value column beside an empty label.
                  function Natural_W (J : Positive) return Natural is
                    (Guikit.Layout.Label_Pixel_Width
                       (To_String (F.Option_Labels.Element (J)), Cell_W) + 2 * Button_Pad);

                  function Total_W return Natural is
                     Sum : Natural := (Count - 1) * Button_Gap;
                  begin
                     for J in 1 .. Count loop
                        Sum := Sum + Natural_W (J);
                     end loop;
                     return Sum;
                  end Total_W;

                  Compact : constant Boolean :=
                    Length (F.Label) = 0 and then Total_W <= Content_W;
                  Next_X  : Natural :=
                    (if Compact then Content_X + Content_W - Total_W else Ctrl_X);
               begin
                  for J in 1 .. Count loop
                     declare
                        This_W : constant Natural := (if Compact then Natural_W (J) else Even_W);
                        BX     : constant Natural := Next_X;
                        BW     : constant Natural := This_W;
                     begin
                        Next_X := Next_X + This_W + Button_Gap;
                        Guikit.Widgets.Draw_Button
                          (Rectangles, Text, Clip_Width, Clip_Height, BX, BY, BW, BH,
                           Guikit.Draw.Input_Color, Guikit.Draw.Border_Color, Button_Pad,
                           F.Option_Labels.Element (J), False, LH,
                           (if F.Enabled then Guikit.Draw.Text_Color
                            else Guikit.Draw.Disabled_Text_Color));
                        Add_Hit (Hit_Button, I, J, BX, BY, BW, BH);
                     end;
                  end loop;
               end;
            end if;
         end;

      when Section =>
         null;
   end case;
end Draw_Control;
