separate (Guikit.Settings_Panel.Build_Frame)
--  Where this frame puts the tabs, the title, the rows, the footer and the
--  label and value columns, from the region, the fields and the footer text.
function Compute_Geometry return Frame_Geometry is

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

   --  Footer content: a status/validation line takes precedence; otherwise
   --  the focused field's help is shown, so per-field descriptions are
   --  visible and not merely exposed to assistive tech.
   Focused_Help : constant UString :=
     (if P.Focused in 1 .. Natural (P.Fields.Length)
      then P.Fields.Element (P.Focused).Help else Null_Unbounded_String);
   Has_Status : constant Boolean := Length (P.Config.Status) > 0;
   Has_Help   : constant Boolean := (not Has_Status) and then Length (Focused_Help) > 0;

   G : Frame_Geometry;
begin
   G.Has_Status := Has_Status;

   --  Extra tab rows are naturally accounted for by the scrolling body.
   G.Tab_Rows := Balanced_Tab_Rows;
   G.Switch_H := Guikit.Layout.Saturating_Multiply (G.Tab_Rows, Row_H);
   --  Align the title header with the close icon (same top inset), forming a
   --  title bar at the very top of the panel; keep its text clear of the icon.
   G.Title_Y := Region_Y + Edge_Inset;
   G.Title_W :=
     (if Region_Width > Pad + Guikit.Layout.Close_Button_Reserve (LH)
      then Region_Width - Pad - Guikit.Layout.Close_Button_Reserve (LH)
      else Content_W);
   G.Switch_Y := G.Title_Y + Row_H;
   --  Leave a gap between the tab bar and the first row (the action buttons)
   --  when the tabs are shown.
   G.Rows_Top := G.Title_Y + Row_H + G.Switch_H + (if G.Switch_H > 0 then Row_Gap else 0);

   G.Foot_Lines :=
     (if Has_Status then Footer_Lines (To_String (P.Config.Status))
      elsif Has_Help then Footer_Lines (To_String (Focused_Help))
      else UString_Vectors.Empty_Vector);
   G.Foot_H :=
     (if G.Foot_Lines.Is_Empty then 0
      else Row_H + (Natural (G.Foot_Lines.Length) - 1) * LH);
   G.Rows_Bot :=
     (if Region_Height > Pad + G.Foot_H then Region_Y + Region_Height - Pad - G.Foot_H else Region_Y);
   G.Avail_H := (if G.Rows_Bot > G.Rows_Top then G.Rows_Bot - G.Rows_Top else 0);

   declare
      --  Keep at least this much for the label column, so a very wide
      --  control cannot crowd the labels out entirely.
      Min_Label : constant Natural := Content_W * 45 / 100;
      Value_Cap : constant Natural :=
        (if Content_W > Min_Label + Pad then Content_W - Min_Label - Pad else 0);
   begin
      G.Ctrl_W := Natural'Min (Max_Value_Width, Value_Cap);
   end;
   --  The label column takes all the width the value column leaves; the value
   --  column is thereby right-aligned against the content's right edge.
   G.Label_W := (if Content_W > G.Ctrl_W + Pad then Content_W - G.Ctrl_W - Pad else Content_W);
   G.Ctrl_X := Content_X + G.Label_W + Pad;
   --  Row highlight aligns with the content: the fill spans exactly the
   --  content columns (no left padding, clear of the scrollbar) and the
   --  accent bar hugs the content's left edge, in the padding just left of it.
   G.Hl_X := Content_X;
   G.Hl_W := Content_W;
   G.Accent_W := Guikit.Layout.Scaled (3, LH);
   G.Accent_X := (if Content_X >= G.Accent_W then Content_X - G.Accent_W else Content_X);
   --  Extra vertical breathing room separating the preamble (the action
   --  buttons) from the active section's fields below it.
   G.Group_Gap := Row_Gap + Guikit.Layout.Scaled (4, LH);
   return G;
end Compute_Geometry;
