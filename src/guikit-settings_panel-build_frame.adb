separate (Guikit.Settings_Panel)
procedure Build_Frame
  (P             : in out Panel;
   Region_X      : Natural;
   Region_Y      : Natural;
   Region_Width  : Natural;
   Region_Height : Natural;
   Clip_Width    : Natural;
   Clip_Height   : Natural;
   Focused       : Boolean;
   Hover_X       : Integer;
   Hover_Y       : Integer;
   Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
   Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
   Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
is
   LH        : constant Positive := P.Config.Line_Height;
   --  The panel's spacing grows with its text (a 2x display, a larger font).
   Pad       : constant Natural  := Guikit.Layout.Scaled (Guikit.Layout.Settings_Pane_Padding, LH);
   Row_Gap   : constant Natural  := Guikit.Layout.Scaled (Guikit.Layout.Settings_Row_Gap, LH);
   Row_H     : constant Natural  := LH + Row_Gap;
   --  The rest of the chrome, at the reference line height, scaled alike:
   --  the scrollbar, a text field's (and a stepper value's) inset, a
   --  button's label padding on each side and the gap between buttons, and
   --  the title and close button's inset from the panel's top edge.
   Bar_W     : constant Natural  := Guikit.Layout.Scaled (Bar_W_Base, LH);
   Field_Inset : constant Natural := Guikit.Layout.Scaled (4, LH);
   Button_Pad  : constant Natural := Guikit.Layout.Scaled (6, LH);
   Button_Gap  : constant Natural := Guikit.Layout.Scaled (4, LH);
   Edge_Inset  : constant Natural := Natural'Max (Guikit.Layout.Scaled (4, LH), LH / 4);
   --  Shared height for interactive controls: fill the row band (leaving a
   --  small margin) so fields and buttons are comfortably tall, not a short
   --  fraction of the line height.
   Ctrl_H    : constant Natural  := Row_H - Guikit.Layout.Scaled (4, LH);
   Cell_W    : constant Natural  := Guikit.Layout.Caret_Advance_Width (LH);
   N         : constant Natural  := Natural (P.Fields.Length);
   Tab_Count : constant Natural  := Section_Count (P);
   Content_X : constant Natural  := Region_X + Pad;
   --  Equal padding on both sides. The scrollbar (Bar_W, narrower than Pad) sits
   --  within the right padding at the panel edge, so the content still clears it
   --  without reserving extra width on the right.
   Content_W : constant Natural  :=
     (if Region_Width > 2 * Pad then Region_Width - 2 * Pad else 0);

   --  Whether sections First_Ord .. Last_Ord fit on one row at their natural
   --  widths. The segmented control already measures localized labels and
   --  their padding; using that same measurement here prevents translated
   --  tabs from being scaled down into clipped fragments. A lone section
   --  always "fits": there is nowhere narrower to put it.
   function Tabs_Fit (First_Ord, Last_Ord : Positive) return Boolean is
      Segments : Guikit.Segmented.Segment_Vectors.Vector;
   begin
      if First_Ord = Last_Ord then
         return True;
      end if;
      for Ord in First_Ord .. Last_Ord loop
         Segments.Append
           (Guikit.Segmented.Segment'
              (Label => Section_Label (P, Ord), others => <>));
      end loop;
      return Guikit.Segmented.Natural_Width (Segments, LH) <= Content_W;
   end Tabs_Fit;

   --  How many sections row Row (0-based) of Rows holds: the sections split
   --  as evenly as they go, any extra one going to the earlier rows.
   function Row_Size (Row, Rows : Natural) return Natural is
     (Tab_Count / Rows + (if Row < Tab_Count mod Rows then 1 else 0));

   --  The fewest tab rows in which every row fits, with the sections split
   --  evenly. Filling each row greedily left a last row holding one tab
   --  stretched across the whole panel, which read as a button.
   function Balanced_Tab_Rows return Natural is
   begin
      if Tab_Count <= 1 then
         return 0;
      end if;
      for Rows in 1 .. Tab_Count loop
         declare
            First_Ord : Positive := 1;
            All_Fit   : Boolean := True;
         begin
            for Row in 0 .. Rows - 1 loop
               if not Tabs_Fit (First_Ord, First_Ord + Row_Size (Row, Rows) - 1) then
                  All_Fit := False;
                  exit;
               end if;
               First_Ord := First_Ord + Row_Size (Row, Rows);
            end loop;
            if All_Fit then
               return Rows;
            end if;
         end;
      end loop;
      return Tab_Count;
   end Balanced_Tab_Rows;

   --  Extra tab rows are naturally accounted for by the scrolling body.
   Tab_Rows : constant Natural := Balanced_Tab_Rows;
   Switch_H  : constant Natural :=
     Guikit.Layout.Saturating_Multiply (Tab_Rows, Row_H);
   --  Align the title header with the close icon (same top inset), forming a
   --  title bar at the very top of the panel; keep its text clear of the icon.
   Title_Y   : constant Natural  := Region_Y + Edge_Inset;
   Title_W   : constant Natural  :=
     (if Region_Width > Pad + LH + 2 * Edge_Inset
      then Region_Width - Pad - LH - 2 * Edge_Inset
      else Content_W);
   Switch_Y  : constant Natural  := Title_Y + Row_H;
   --  Leave a gap between the tab bar and the first row (the action buttons)
   --  when the tabs are shown.
   Lead_Gap  : constant Natural  := (if Switch_H > 0 then Row_Gap else 0);
   Rows_Top  : constant Natural  := Title_Y + Row_H + Switch_H + Lead_Gap;
   --  Field indices rendered as rows now (preamble + active section), compact.
   Visible   : Index_Array (1 .. Natural'Max (1, N)) := (others => 0);
   Vis_N     : Natural := 0;
   --  Number of leading visible rows belonging to the preamble (Section 0),
   --  which precede all of the active section's rows.
   Preamble_Rows : Natural := 0;
   --  Footer content: a status/validation line takes precedence; otherwise the
   --  focused field's help is shown, so per-field descriptions are visible and
   --  not merely exposed to assistive tech.
   Focused_Help : constant UString :=
     (if P.Focused in 1 .. Natural (P.Fields.Length)
      then P.Fields.Element (P.Focused).Help else Null_Unbounded_String);
   Has_Status : constant Boolean := Length (P.Config.Status) > 0;
   Has_Help   : constant Boolean := (not Has_Status) and then Length (Focused_Help) > 0;

   --  The footer text broken at spaces into lines that fit the content width,
   --  at most Max_Foot_Lines of them; the last takes whatever remains and is
   --  clipped there. One line used to cut off any longer help mid-word.
   Max_Foot_Lines : constant := 3;
   function Footer_Lines (Value : String) return UString_Vectors.Vector is
      Fit_Units : constant Natural := (if Cell_W > 0 then Content_W / Cell_W else 0);
      Lines     : UString_Vectors.Vector;
      Line      : UString;
      First     : Natural := Value'First;
   begin
      while First <= Value'Last loop
         declare
            Space : constant Natural := Ada.Strings.Fixed.Index (Value (First .. Value'Last), " ");
            Last  : constant Natural := (if Space = 0 then Value'Last else Space - 1);
            Word  : constant String := Value (First .. Last);
            Joined : constant String := (if Length (Line) = 0 then Word else To_String (Line) & " " & Word);
         begin
            if Length (Line) = 0
              or else Guikit.Utf8.Display_Units (Joined) <= Fit_Units
              or else Natural (Lines.Length) = Max_Foot_Lines - 1
            then
               Line := To_Unbounded_String (Joined);
            else
               Lines.Append (Line);
               Line := To_Unbounded_String (Word);
            end if;
            First := (if Space = 0 then Value'Last + 1 else Space + 1);
         end;
      end loop;
      if Length (Line) > 0 then
         Lines.Append (Line);
      end if;
      return Lines;
   end Footer_Lines;

   Foot_Lines : constant UString_Vectors.Vector :=
     (if Has_Status then Footer_Lines (To_String (P.Config.Status))
      elsif Has_Help then Footer_Lines (To_String (Focused_Help))
      else UString_Vectors.Empty_Vector);
   Foot_H    : constant Natural  :=
     (if Foot_Lines.Is_Empty then 0
      else Row_H + (Natural (Foot_Lines.Length) - 1) * LH);
   Rows_Bot  : constant Natural  :=
     (if Region_Height > Pad + Foot_H then Region_Y + Region_Height - Pad - Foot_H else Region_Y);
   Avail_H   : constant Natural  := (if Rows_Bot > Rows_Top then Rows_Bot - Rows_Top else 0);
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

   function Max_Value_Width return Natural is
      Max : Natural := 2 * LH;  --  never narrower than a toggle
   begin
      --  Every field, not just the visible section, so the column is stable
      --  across sections (Section fields report width 0 and never raise it).
      for I in P.Fields.First_Index .. P.Fields.Last_Index loop
         Max := Natural'Max (Max, Control_Width (P.Fields.Element (I)));
      end loop;
      return Max;
   end Max_Value_Width;

   --  Keep at least this much for the label column, so a very wide control cannot
   --  crowd the labels out entirely.
   Min_Label : constant Natural  := Content_W * 45 / 100;
   Value_Cap : constant Natural  :=
     (if Content_W > Min_Label + Pad then Content_W - Min_Label - Pad else 0);
   Ctrl_W    : constant Natural  := Natural'Min (Max_Value_Width, Value_Cap);
   --  The label column takes all the width the value column leaves; the value
   --  column is thereby right-aligned against the content's right edge.
   Label_W   : constant Natural  :=
     (if Content_W > Ctrl_W + Pad then Content_W - Ctrl_W - Pad else Content_W);
   Ctrl_X    : constant Natural  := Content_X + Label_W + Pad;
   --  Row highlight aligns with the content: the fill spans exactly the content
   --  columns (no left padding, clear of the scrollbar) and the accent bar hugs
   --  the content's left edge.
   Hl_X      : constant Natural  := Content_X;
   Hl_W      : constant Natural  := Content_W;
   --  The focused row's accent bar: this wide, in the padding just left of the content.
   Accent_W  : constant Natural  := Guikit.Layout.Scaled (3, LH);
   Accent_X  : constant Natural  := (if Content_X >= Accent_W then Content_X - Accent_W else Content_X);
   --  Extra vertical breathing room separating the preamble (the action buttons)
   --  from the active section's fields below it.
   Group_Gap : constant Natural  := Row_Gap + Guikit.Layout.Scaled (4, LH);

   procedure Add_Rect (X, Y, W, H : Natural; Color : Guikit.Draw.Render_Color) is
   begin
      if W > 0 and then H > 0 then
         Rectangles.Append
           (Guikit.Draw.Rectangle_Command'(X => X, Y => Y, Width => W, Height => H, Color => Color));
      end if;
   end Add_Rect;

   procedure Add_Text (X, Y, W : Natural; S : UString; Color : Guikit.Draw.Render_Color) is
   begin
      if W > 0 and then Length (S) > 0 then
         Text.Append
           (Guikit.Draw.Text_Command'
              (X => X, Y => Y, Width => W, Height => LH, Text => S, Color => Color, others => <>));
      end if;
   end Add_Text;

   procedure Add_Hit (Kind : Hit_Kind; Field_Index, Option, X, Y, W, H : Natural) is
   begin
      P.Hits.Append
        (Hit_Rect'(Kind => Kind, Field_Index => Field_Index, Option => Option,
                   X => X, Y => Y, W => W, H => H));
   end Add_Hit;

   --  The frame's parts, each its own subunit, drawn in this order (later parts
   --  sit above earlier ones): the panel chrome, the section tabs, the field
   --  rows, the footer, the scrollbar, the close button and the tab tooltip.
   procedure Draw_Chrome is separate;
   procedure Draw_Tabs is separate;
   procedure Draw_Control (I : Positive; F : Field; Row_Y : Natural) is separate;
   procedure Draw_Rows is separate;
   procedure Draw_Footer is separate;
   procedure Draw_Scrollbar is separate;
   procedure Draw_Close_Button is separate;
   procedure Draw_Switch_Tooltip is separate;
begin
   P.Hits.Clear;
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
        (if Split and then Avail_H > Group_Gap then Avail_H - Group_Gap else Avail_H);
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

   Draw_Chrome;
   Draw_Tabs;
   Draw_Rows;
   Draw_Footer;
   Draw_Scrollbar;
   Draw_Close_Button;
   Draw_Switch_Tooltip;
end Build_Frame;
