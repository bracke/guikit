separate (Guikit.Settings_Panel.Build_Frame)
--  Section switcher (the tabs): a segmented control of the section labels,
--  the active one highlighted, each cell clickable to switch section.
procedure Draw_Tabs is
begin
   if Tab_Count > 1 then
      declare
         First_Ord : Positive := 1;
         Last_Ord  : Positive;
      begin
         for Tab_Row in 0 .. Tab_Rows - 1 loop
            Last_Ord := First_Ord + Row_Size (Tab_Row, Tab_Rows) - 1;
            declare
               Row_Y     : constant Natural := Switch_Y + Tab_Row * Row_H;
               Segs      : Guikit.Segmented.Segment_Vectors.Vector;
               S_Rects   : Guikit.Draw.Rectangle_Command_Vectors.Vector;
               S_Text    : Guikit.Draw.Text_Command_Vectors.Vector;
               S_Tips    : Guikit.Draw.Tooltip_Command_Vectors.Vector;
               S_Nodes   : Guikit.Draw.Accessibility_Node_Vectors.Vector;
               CX, CW    : Natural;
               Local_Active : constant Natural :=
                 (if P.Active in First_Ord .. Last_Ord
                  then P.Active - First_Ord + 1
                  else 0);
            begin
               for Ord in First_Ord .. Last_Ord loop
                  Segs.Append
                    (Guikit.Segmented.Segment'
                       (Label => Section_Label (P, Ord), others => <>));
               end loop;
               Guikit.Segmented.Build_Frame
                 (Segments => Segs, Active => Local_Active,
                  Region_X => Content_X, Region_Y => Row_Y + Guikit.Layout.Scaled (2, LH), Region_Width => Content_W,
                  --  Fill each tab band (leaving a small margin) rather than a
                  --  short line-height strip, so the tabs are comfortably tall.
                  Region_Height => Ctrl_H, Clip_Width => Clip_Width, Clip_Height => Clip_Height,
                  Line_Height => LH, Hover_X => Hover_X, Hover_Y => Hover_Y,
                  Rectangles => S_Rects, Text => S_Text, Tooltips => S_Tips,
                  Accessibility => S_Nodes);
               for C of S_Rects loop
                  Rectangles.Append (C);
               end loop;
               for C of S_Text loop
                  Text.Append (C);
               end loop;
               for Node of S_Nodes loop
                  Accessibility.Append (Node);
               end loop;
               for Ord in First_Ord .. Last_Ord loop
                  Guikit.Segmented.Cell_Bounds
                    (Segs, Content_X, Content_W, LH, Ord - First_Ord + 1, CX, CW);
                  Add_Hit (Hit_Tab, 0, Ord, CX, Row_Y, CW, Row_H);
               end loop;
            end;

            if Last_Ord < Tab_Count then
               First_Ord := Last_Ord + 1;
            end if;
         end loop;
      end;
   end if;
end Draw_Tabs;
