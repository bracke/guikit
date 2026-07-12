with Ada.Strings.Fixed;

with Guikit.Layout;
with Guikit.Segmented;
with Guikit.Utf8;
with Guikit.Widgets;

package body Guikit.Settings_Panel is

   use Ada.Strings.Unbounded;

   Pad     : constant Natural := 14;   --  panel inner padding
   Row_Gap : constant Natural := 8;    --  gap between field rows
   Bar_W   : constant Natural := 12;   --  scrollbar width (matches the grid/list)

   --  ----- small value helpers -------------------------------------------------

   function Is_True (Value : UString) return Boolean is (To_String (Value) = "true");

   function To_Int (Value : UString; Default : Integer) return Integer is
   begin
      return Integer'Value (To_String (Value));
   exception
      when others => return Default;
   end To_Int;

   --  The 1-based index of Value within a field's Option_Values, or 0.
   function Option_Index (F : Field) return Natural is
   begin
      for I in F.Option_Values.First_Index .. F.Option_Values.Last_Index loop
         if F.Option_Values.Element (I) = F.Value then
            return I;
         end if;
      end loop;
      return 0;
   end Option_Index;

   function Is_Focusable (F : Field) return Boolean is (F.Kind /= Section);

   --  ----- sections (tabs) ------------------------------------------------------

   function Section_Count (P : Panel) return Natural is
      Count : Natural := 0;
   begin
      for F of P.Fields loop
         if F.Kind = Section then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Section_Count;

   function Active_Section (P : Panel) return Natural is (P.Active);

   --  The one-based section ordinal enclosing a field, or 0 for a field that
   --  precedes the first Section (the always-visible preamble).
   function Field_Section (P : Panel; Index : Positive) return Natural is
      Ord : Natural := 0;
   begin
      for I in P.Fields.First_Index .. Index loop
         if P.Fields.Element (I).Kind = Section then
            Ord := Ord + 1;
         end if;
      end loop;
      return Ord;
   end Field_Section;

   --  Whether a field is rendered as a row now: never a Section header (those are
   --  the tabs), and only when it is in the preamble or the active section.
   function Field_Is_Visible (P : Panel; Index : Positive) return Boolean is
   begin
      if Index not in 1 .. Natural (P.Fields.Length)
        or else P.Fields.Element (Index).Kind = Section
      then
         return False;
      end if;
      declare
         Ord : constant Natural := Field_Section (P, Index);
      begin
         return Ord = 0 or else Ord = P.Active;
      end;
   end Field_Is_Visible;

   --  The label of the Ordinal-th Section field.
   function Section_Label (P : Panel; Ordinal : Positive) return UString is
      Count : Natural := 0;
   begin
      for F of P.Fields loop
         if F.Kind = Section then
            Count := Count + 1;
            if Count = Ordinal then
               return F.Label;
            end if;
         end if;
      end loop;
      return Null_Unbounded_String;
   end Section_Label;

   procedure Set_Active_Section (P : in out Panel; Ordinal : Natural) is
      Count : constant Natural := Section_Count (P);
   begin
      if Count = 0 then
         P.Active := 1;
         return;
      end if;
      P.Active    := Natural'Max (1, Natural'Min (Ordinal, Count));
      P.Offset    := 0;
      P.Focused   := 0;
      P.Capturing := 0;
      for I in P.Fields.First_Index .. P.Fields.Last_Index loop
         if Field_Is_Visible (P, I) and then Field_Section (P, I) = P.Active then
            P.Focused := I;
            exit;
         end if;
      end loop;
   end Set_Active_Section;

   --  ----- configuration + fields ----------------------------------------------

   procedure Set_Configuration (P : in out Panel; Config : Configuration) is
   begin
      P.Config := Config;
   end Set_Configuration;

   procedure Set_Fields (P : in out Panel; Fields : Field_Vectors.Vector) is
      Count : Natural;
   begin
      P.Fields := Fields;
      --  Capture is deliberately preserved across a re-supply: the caller
      --  rebuilds the field list every frame, and the armed field keeps its
      --  index (the field list is stable while capturing). Capture is ended
      --  explicitly instead -- on commit, cancel, focus move, or tab switch.
      if P.Capturing > Natural (P.Fields.Length)
        or else (P.Capturing > 0 and then P.Fields.Element (P.Capturing).Kind /= Shortcut)
      then
         P.Capturing := 0;
      end if;
      Count := Section_Count (P);
      P.Active := (if Count = 0 then 1 else Natural'Max (1, Natural'Min (P.Active, Count)));
      if P.Focused > Natural (P.Fields.Length) then
         P.Focused := 0;
      end if;
      --  Keep focus on a still-visible field; otherwise land on the first field of
      --  the active section, so opening the panel focuses a setting rather than the
      --  preamble action buttons. Fall back to the first visible field (the
      --  preamble) only when the active section has none.
      if P.Focused = 0 or else not Field_Is_Visible (P, P.Focused) then
         P.Focused := 0;
         for I in P.Fields.First_Index .. P.Fields.Last_Index loop
            if Field_Is_Visible (P, I) and then Field_Section (P, I) = P.Active then
               P.Focused := I;
               exit;
            end if;
         end loop;
         if P.Focused = 0 then
            for I in P.Fields.First_Index .. P.Fields.Last_Index loop
               if Field_Is_Visible (P, I) then
                  P.Focused := I;
                  exit;
               end if;
            end loop;
         end if;
      end if;
   end Set_Fields;

   procedure Reset (P : in out Panel) is
   begin
      P.Focused   := 0;
      P.Capturing := 0;
      P.Active    := 1;
      P.Offset    := 0;
      P.Hits.Clear;
      P.Pending := (Kind => No_Change, others => <>);
   end Reset;

   --  ----- change plumbing ------------------------------------------------------

   procedure Emit_Value (P : in out Panel; Key, Value : UString) is
   begin
      P.Pending := (Kind => Value_Changed, Key => Key, Value => Value);
   end Emit_Value;

   procedure Emit_Button (P : in out Panel; Key, Button : UString) is
   begin
      P.Pending := (Kind => Button_Pressed, Key => Key, Value => Button);
   end Emit_Button;

   function Take_Change (P : in out Panel) return Change is
      Result : constant Change := P.Pending;
   begin
      P.Pending := (Kind => No_Change, others => <>);
      return Result;
   end Take_Change;

   --  ----- queries --------------------------------------------------------------

   function Focused_Field (P : Panel; Ok : out Boolean) return Field is
   begin
      Ok := P.Focused in 1 .. Natural (P.Fields.Length);
      if Ok then
         return P.Fields.Element (P.Focused);
      end if;
      return (others => <>);
   end Focused_Field;

   function Focused_Kind (P : Panel) return Field_Kind is
      Ok : Boolean;
      F  : constant Field := Focused_Field (P, Ok);
   begin
      return (if Ok then F.Kind else Section);
   end Focused_Kind;

   function Focused_Key (P : Panel) return String is
      Ok : Boolean;
      F  : constant Field := Focused_Field (P, Ok);
   begin
      return (if Ok then To_String (F.Key) else "");
   end Focused_Key;

   function Focused_Value (P : Panel) return String is
      Ok : Boolean;
      F  : constant Field := Focused_Field (P, Ok);
   begin
      return (if Ok then To_String (F.Value) else "");
   end Focused_Value;

   --  ----- navigation + editing -------------------------------------------------

   procedure Move_Focus (P : in out Panel; Delta_Rows : Integer) is
      N    : constant Natural := Natural (P.Fields.Length);
      Step : constant Integer := (if Delta_Rows >= 0 then 1 else -1);
      I    : Integer := (if P.Focused = 0 then (if Step > 0 then 0 else N + 1) else P.Focused);
   begin
      if N = 0 then
         return;
      end if;
      for Unused in 1 .. Integer'Max (1, abs Delta_Rows) loop
         loop
            I := I + Step;
            exit when I < 1 or else I > N;
            exit when Field_Is_Visible (P, I);
         end loop;
         exit when I < 1 or else I > N;
      end loop;
      if I in 1 .. N and then Field_Is_Visible (P, I) then
         P.Focused   := I;
         P.Capturing := 0;   --  moving focus cancels any in-progress capture
      end if;
   end Move_Focus;

   procedure Cycle_Choice (P : in out Panel; Forward : Boolean) is
      Ok : Boolean;
      F  : Field := Focused_Field (P, Ok);
   begin
      if not Ok or else not F.Enabled then
         return;
      end if;
      case F.Kind is
         when Toggle =>
            F.Value := To_Unbounded_String (if Is_True (F.Value) then "false" else "true");
            P.Fields.Replace_Element (P.Focused, F);
            Emit_Value (P, F.Key, F.Value);
         when Choice =>
            declare
               Count : constant Natural := Natural (F.Option_Values.Length);
               Cur   : constant Natural := Option_Index (F);
               Next  : Integer;
            begin
               if Count = 0 then
                  return;
               end if;
               Next := (if Cur = 0 then 1 else Cur) + (if Forward then 1 else -1);
               if Next < 1 then
                  Next := Count;
               elsif Next > Count then
                  Next := 1;
               end if;
               F.Value := F.Option_Values.Element (Next);
               P.Fields.Replace_Element (P.Focused, F);
               Emit_Value (P, F.Key, F.Value);
            end;
         when Number =>
            Step_Number (P, Up => Forward);
         when others =>
            null;
      end case;
   end Cycle_Choice;

   procedure Step_Number (P : in out Panel; Up : Boolean) is
      Ok : Boolean;
      F  : Field := Focused_Field (P, Ok);
   begin
      if not Ok or else F.Kind /= Number or else not F.Enabled then
         return;
      end if;
      declare
         Cur  : constant Integer := To_Int (F.Value, F.Min);
         Next : constant Integer :=
           Integer'Max (F.Min, Integer'Min (F.Max, Cur + (if Up then 1 else -1)));
      begin
         if Next /= Cur then
            F.Value := To_Unbounded_String (Ada.Strings.Fixed.Trim (Integer'Image (Next), Ada.Strings.Left));
            P.Fields.Replace_Element (P.Focused, F);
            Emit_Value (P, F.Key, F.Value);
         end if;
      end;
   end Step_Number;

   procedure Set_Focused_Value (P : in out Panel; Text : String) is
      Ok : Boolean;
      F  : Field := Focused_Field (P, Ok);
   begin
      if not Ok or else F.Kind /= Settings_Panel.Text then
         return;
      end if;
      F.Value := To_Unbounded_String (Text);
      P.Fields.Replace_Element (P.Focused, F);
      Emit_Value (P, F.Key, F.Value);
   end Set_Focused_Value;

   procedure Begin_Capture (P : in out Panel) is
      Ok : Boolean;
      F  : constant Field := Focused_Field (P, Ok);
   begin
      if Ok and then F.Enabled and then F.Kind = Shortcut then
         P.Capturing := P.Focused;
      end if;
   end Begin_Capture;

   function Is_Capturing (P : Panel) return Boolean is
     (P.Capturing in 1 .. Natural (P.Fields.Length));

   function Capturing_Key (P : Panel) return String is
   begin
      if P.Capturing in 1 .. Natural (P.Fields.Length) then
         return To_String (P.Fields.Element (P.Capturing).Key);
      end if;
      return "";
   end Capturing_Key;

   procedure Set_Captured_Shortcut (P : in out Panel; Text : String) is
   begin
      if P.Capturing not in 1 .. Natural (P.Fields.Length) then
         return;
      end if;
      declare
         F : Field := P.Fields.Element (P.Capturing);
      begin
         F.Value := To_Unbounded_String (Text);
         P.Fields.Replace_Element (P.Capturing, F);
         P.Capturing := 0;
         Emit_Value (P, F.Key, F.Value);
      end;
   end Set_Captured_Shortcut;

   procedure Cancel_Capture (P : in out Panel) is
   begin
      P.Capturing := 0;
   end Cancel_Capture;

   procedure Scroll (P : in out Panel; Lines : Integer) is
      Max_Scroll : constant Natural :=
        (if Natural (P.Fields.Length) > P.Visible_Rows
         then Natural (P.Fields.Length) - P.Visible_Rows else 0);
      Next : constant Integer := Integer (P.Offset) + Lines;
   begin
      P.Offset := Natural (Integer'Max (0, Integer'Min (Next, Max_Scroll)));
   end Scroll;

   function Click (P : in out Panel; X : Integer; Y : Integer) return Boolean is
   begin
      for H of P.Hits loop
         if X >= H.X and then X < H.X + H.W and then Y >= H.Y and then Y < H.Y + H.H then
            if H.Kind = Hit_Tab then
               Set_Active_Section (P, H.Option);
               return True;
            elsif H.Field_Index in 1 .. Natural (P.Fields.Length) then
               declare
                  F : Field := P.Fields.Element (H.Field_Index);
               begin
                  P.Focused := H.Field_Index;
                  --  Any click disarms a pending capture; a click on a Shortcut
                  --  row re-arms it below (the row-level Hit_Focus is the reliable
                  --  hit, since it shadows any control-box hit within the row).
                  P.Capturing := 0;
                  case H.Kind is
                     when Hit_Focus =>
                        if F.Enabled and then F.Kind = Shortcut then
                           P.Capturing := H.Field_Index;
                        end if;
                     when Hit_Toggle =>
                        if F.Enabled then
                           F.Value := To_Unbounded_String (if Is_True (F.Value) then "false" else "true");
                           P.Fields.Replace_Element (H.Field_Index, F);
                           Emit_Value (P, F.Key, F.Value);
                        end if;
                     when Hit_Choice =>
                        if F.Enabled and then H.Option in 1 .. Natural (F.Option_Values.Length) then
                           F.Value := F.Option_Values.Element (H.Option);
                           P.Fields.Replace_Element (H.Field_Index, F);
                           Emit_Value (P, F.Key, F.Value);
                        end if;
                     when Hit_Step_Down =>
                        Step_Number (P, Up => False);
                     when Hit_Step_Up =>
                        Step_Number (P, Up => True);
                     when Hit_Button =>
                        if H.Option in 1 .. Natural (F.Option_Values.Length) then
                           Emit_Button (P, F.Key, F.Option_Values.Element (H.Option));
                        end if;
                     when Hit_Tab =>
                        null;  --  handled above, before the field-index branch
                  end case;
               end;
            end if;
            return True;
         end if;
      end loop;
      return False;
   end Click;

   --  ----- rendering ------------------------------------------------------------

   type Index_Array is array (Positive range <>) of Natural;

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
      Row_H     : constant Natural  := LH + Row_Gap;
      --  Shared height for interactive controls: fill the row band (leaving a
      --  small margin) so fields and buttons are comfortably tall, not a short
      --  fraction of the line height.
      Ctrl_H    : constant Natural  := Row_H - 4;
      Cell_W    : constant Natural  := Guikit.Layout.Caret_Advance_Width (LH);
      N         : constant Natural  := Natural (P.Fields.Length);
      Tab_Count : constant Natural  := Section_Count (P);
      Switch_H  : constant Natural  := (if Tab_Count > 1 then Row_H else 0);
      Content_X : constant Natural  := Region_X + Pad;
      Content_W : constant Natural  :=
        (if Region_Width > 2 * Pad + Bar_W then Region_Width - 2 * Pad - Bar_W else 0);
      --  Align the title header with the close icon (same top inset), forming a
      --  title bar at the very top of the panel; keep its text clear of the icon.
      Title_Y   : constant Natural  := Region_Y + Natural'Max (4, LH / 4);
      Title_W   : constant Natural  :=
        (if Region_Width > Pad + LH + 2 * Natural'Max (4, LH / 4)
         then Region_Width - Pad - LH - 2 * Natural'Max (4, LH / 4)
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
      Foot_H    : constant Natural  := (if Has_Status or else Has_Help then Row_H else 0);
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
                       + 2 * 6;
                  end loop;
                  if Count > 1 then
                     Sum := Sum + (Count - 1) * 4;
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
                         Guikit.Utf8.Display_Units (To_String (F.Value)) * Cell_W + 8);
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
      Accent_X  : constant Natural  := (if Content_X >= 3 then Content_X - 3 else Content_X);
      --  Extra vertical breathing room separating the preamble (the action buttons)
      --  from the active section's fields below it.
      Group_Gap : constant Natural  := Row_Gap + 4;

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

      --  Clamp scroll and keep the focused row on screen (rows are the compact
      --  positions of the visible fields, not raw field indices).
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
         if P.Focused > 0 then
            if Focus_Row < P.Offset then
               P.Offset := Focus_Row;
            elsif P.Visible_Rows > 0 and then Focus_Row >= P.Offset + P.Visible_Rows then
               P.Offset := Focus_Row - P.Visible_Rows + 1;
            end if;
         end if;
      end;

      --  Panel chrome: shadow, panel, accent bar, dialog role, title, close.
      Guikit.Widgets.Draw_Drop_Shadow
        (Rectangles, Clip_Width, Clip_Height, Region_X, Region_Y, Region_Width, Region_Height,
         Guikit.Draw.Overlay_Color);
      Guikit.Widgets.Draw_Menu_Panel
        (Rectangles, Clip_Width, Clip_Height, Region_X, Region_Y, Region_Width, Region_Height,
         Guikit.Draw.Pane_Color, Guikit.Draw.Border_Color);
      Add_Rect (Region_X, Region_Y, Region_Width, Natural'Min (3, Region_Height), Guikit.Draw.Selection_Color);
      Accessibility.Append
        (Guikit.Draw.Accessibility_Node'
           (Role => Guikit.Draw.Role_Dialog, X => Region_X, Y => Region_Y,
            Width => Region_Width, Height => Region_Height, Name => P.Config.Title, others => <>));
      Add_Text (Content_X, Title_Y, Title_W, P.Config.Title, Guikit.Draw.Text_Color);

      --  Section switcher (the tabs): a segmented control of the section labels,
      --  the active one highlighted, each cell clickable to switch section.
      if Tab_Count > 1 then
         declare
            Segs    : Guikit.Segmented.Segment_Vectors.Vector;
            S_Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
            S_Text  : Guikit.Draw.Text_Command_Vectors.Vector;
            S_Tips  : Guikit.Draw.Tooltip_Command_Vectors.Vector;
            S_Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
            CX, CW  : Natural;
         begin
            for Ord in 1 .. Tab_Count loop
               Segs.Append
                 (Guikit.Segmented.Segment'(Label => Section_Label (P, Ord), others => <>));
            end loop;
            Guikit.Segmented.Build_Frame
              (Segments => Segs, Active => P.Active,
               Region_X => Content_X, Region_Y => Switch_Y + 2, Region_Width => Content_W,
               --  Fill the tab band (leaving a small margin) rather than a short
               --  line-height strip, so the tabs are comfortably tall.
               Region_Height => Ctrl_H, Clip_Width => Clip_Width, Clip_Height => Clip_Height,
               Line_Height => LH, Hover_X => Hover_X, Hover_Y => Hover_Y,
               Rectangles => S_Rects, Text => S_Text, Tooltips => S_Tips, Accessibility => S_Nodes);
            for C of S_Rects loop
               Rectangles.Append (C);
            end loop;
            for C of S_Text loop
               Text.Append (C);
            end loop;
            for Node of S_Nodes loop
               Accessibility.Append (Node);
            end loop;
            for Ord in 1 .. Tab_Count loop
               Guikit.Segmented.Cell_Bounds (Segs, Content_X, Content_W, LH, Ord, CX, CW);
               Add_Hit (Hit_Tab, 0, Ord, CX, Switch_Y, CW, Row_H);
            end loop;
         end;
      end if;

      --  Rows (the active section's fields, compact).
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
            Row_Y : constant Natural := Rows_Top + (R - P.Offset) * Row_H + Extra;
            Mid_Y : constant Natural := Row_Y + (Row_H - LH) / 2;
         begin
            exit when not Vis and then R >= P.Offset + P.Visible_Rows;
            if Vis then
               if I = P.Focused then
                  Add_Rect (Hl_X, Row_Y, Hl_W, Row_H, Guikit.Draw.Hover_Color);
                  Add_Rect (Accent_X, Row_Y, 3, Row_H, Guikit.Draw.Selection_Color);
                  if Focused then
                     Guikit.Widgets.Draw_Focus_Ring
                       (Rectangles, Clip_Width, Clip_Height, Hl_X, Row_Y,
                        Hl_W, Row_H, Guikit.Draw.Selection_Color);
                  end if;
               end if;

               if F.Kind = Section then
                  Add_Text (Content_X, Mid_Y, Content_W, F.Label, Guikit.Draw.Muted_Text_Color);
                  Add_Rect (Content_X, Row_Y + Row_H - 2, Content_W, 1, Guikit.Draw.Border_Color);
                  Accessibility.Append
                    (Guikit.Draw.Accessibility_Node'
                       (Role => Guikit.Draw.Role_Heading, X => Content_X, Y => Row_Y,
                        Width => Content_W, Height => Row_H, Name => F.Label, others => <>));
               else
                  Add_Text
                    (Content_X, Mid_Y, Label_W, F.Label,
                     (if F.Enabled then Guikit.Draw.Text_Color else Guikit.Draw.Disabled_Text_Color));
                  Add_Hit (Hit_Focus, I, 0, Region_X, Row_Y, Region_Width, Row_H);

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
                              Guikit.Draw.Selection_Color, Guikit.Draw.Input_Color,
                              Guikit.Draw.Border_Color, Guikit.Draw.Pane_Color);
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
                                    Region_X => Ctrl_X, Region_Y => SY, Region_Width => Ctrl_W,
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
                                    Guikit.Segmented.Cell_Bounds (Segs, Ctrl_X, Ctrl_W, LH, J, CX, CW);
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
                             (Rectangles, Text, Clip_Width, Clip_Height, BY, BH, BY + (BH - LH) / 2, LH, 4,
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
                           Add_Text (Ctrl_X + 4, VY, (if Ctrl_W > 8 then Ctrl_W - 8 else 0), F.Value,
                                     Guikit.Draw.Text_Color);
                           if Focused and then I = P.Focused then
                              Guikit.Widgets.Draw_Caret
                                (Rectangles, Clip_Width, Clip_Height,
                                 Ctrl_X + 4 + Guikit.Utf8.Display_Units (To_String (F.Value)) * Cell_W, VY,
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
                        begin
                           Guikit.Widgets.Draw_Input_Field
                             (Rectangles, Clip_Width, Clip_Height, Ctrl_X, TY, Ctrl_W, TH,
                              Guikit.Draw.Input_Color,
                              (if Armed then Guikit.Draw.Selection_Color else Guikit.Draw.Border_Color));
                           Add_Text (Ctrl_X + 4, VY, (if Ctrl_W > 8 then Ctrl_W - 8 else 0), F.Value,
                                     (if F.Enabled then Guikit.Draw.Text_Color
                                      else Guikit.Draw.Disabled_Text_Color));
                           if Armed then
                              Guikit.Widgets.Draw_Caret
                                (Rectangles, Clip_Width, Clip_Height,
                                 Ctrl_X + 4 + Guikit.Utf8.Display_Units (To_String (F.Value)) * Cell_W, VY,
                                 Natural'Max (1, Cell_W / 6), LH, Guikit.Draw.Selection_Color);
                           end if;
                        end;

                     when Buttons =>
                        declare
                           Count : constant Natural := Natural (F.Option_Labels.Length);
                        begin
                           if Count > 0 and then Ctrl_W > 0 then
                              declare
                                 BW : constant Natural := (Ctrl_W - (Count - 1) * 4) / Count;
                                 BH : constant Natural := Ctrl_H;
                                 BY : constant Natural := Row_Y + (Row_H - BH) / 2;
                              begin
                                 for J in 1 .. Count loop
                                    declare
                                       BX : constant Natural := Ctrl_X + (J - 1) * (BW + 4);
                                    begin
                                       Guikit.Widgets.Draw_Button
                                         (Rectangles, Text, Clip_Width, Clip_Height, BX, BY, BW, BH,
                                          Guikit.Draw.Input_Color, Guikit.Draw.Border_Color, 6,
                                          F.Option_Labels.Element (J), False, LH, Guikit.Draw.Text_Color);
                                       Add_Hit (Hit_Button, I, J, BX, BY, BW, BH);
                                    end;
                                 end loop;
                              end;
                           end if;
                        end;

                     when Section =>
                        null;
                  end case;

                  Accessibility.Append
                    (Guikit.Draw.Accessibility_Node'
                       (Role => (if F.Kind = Buttons then Guikit.Draw.Role_Button else Guikit.Draw.Role_Text_Input),
                        X => Region_X, Y => Row_Y, Width => Region_Width, Height => Row_H,
                        Name => F.Label, Description => (if Length (F.Help) > 0 then F.Help else F.Value),
                        Enabled => F.Enabled, Selected => I = P.Focused, others => <>));
               end if;
            end if;
         end;
      end loop;

      --  Footer: the status line, else the focused field's help.
      declare
         Foot_Y : constant Natural := Rows_Bot + (Foot_H - LH) / 2;
      begin
         if Has_Status then
            Add_Text (Content_X, Foot_Y, Content_W, P.Config.Status,
                      (if P.Config.Status_Is_Error then Guikit.Draw.Error_Text_Color
                       else Guikit.Draw.Muted_Text_Color));
         elsif Has_Help then
            Add_Text (Content_X, Foot_Y, Content_W, Focused_Help, Guikit.Draw.Muted_Text_Color);
         end if;
      end;

      --  Scrollbar.
      declare
         Max_Scroll : constant Natural := (if Vis_N > P.Visible_Rows then Vis_N - P.Visible_Rows else 0);
         Thumb : constant Guikit.Layout.Scrollbar_Thumb :=
           Guikit.Layout.Calculate_Scrollbar_Thumb
             (Track_Length    => Avail_H,
              Visible_Amount  => P.Visible_Rows,
              Total_Amount    => Vis_N,
              Scroll_Position => P.Offset,
              Max_Scroll      => Max_Scroll,
              Min_Length      => Row_H);
      begin
         if Thumb.Length > 0 and then Avail_H > 0 then
            Guikit.Widgets.Draw_Scrollbar
              (Rectangles   => Rectangles,
               Clip_Width   => Clip_Width,
               Clip_Height  => Clip_Height,
               Track_X      => Region_X + Region_Width - Bar_W,
               Track_Y      => Rows_Top,
               Track_Width  => Bar_W,
               Track_Height => Avail_H,
               Thumb_Y      => Rows_Top + Thumb.Offset,
               Thumb_Height => Thumb.Length,
               Track_Color  => Guikit.Draw.Border_Color,
               Thumb_Color  => Guikit.Draw.Selection_Color,
               Grip_Color   => Guikit.Draw.Muted_Text_Color);
         end if;
      end;

      --  Close button (top-right), matching the common panel-close geometry.
      declare
         Inset : constant Natural := Natural'Max (4, LH / 4);
         Btn   : constant Natural := LH;
         Bx    : constant Natural :=
           (if Region_Width > Inset + Btn then Region_X + Region_Width - Inset - Btn else Region_X);
         By    : constant Natural := Region_Y + Inset;
      begin
         Guikit.Widgets.Draw_Close_Button
           (Rectangles => Rectangles, Text => Text, Clip_Width => Clip_Width, Clip_Height => Clip_Height,
            Button_X => Bx, Button_Y => By, Button_Width => Btn, Button_Height => Btn,
            Fill_Color => Guikit.Draw.Pane_Color, Border_Color => Guikit.Draw.Border_Color,
            Glyph_X => Bx, Glyph_Y => By, Glyph_Width => Btn, Glyph_Height => Btn,
            --  U+00D7 (times): sits on the math axis so it centres in the button,
            --  unlike a lowercase "x" which sits low off-centre.
            Glyph => To_Unbounded_String (Character'Val (16#C3#) & Character'Val (16#97#)),
            Glyph_Color => Guikit.Draw.Muted_Text_Color,
            Show_Glyph => True);
         Accessibility.Append
           (Guikit.Draw.Accessibility_Node'
              (Role => Guikit.Draw.Role_Button, X => Bx, Y => By,
               Width => Btn, Height => Btn, Name => To_Unbounded_String ("Close"), others => <>));
      end;

      --  Tab-switcher hover tooltip: surfaces the keyboard tab-switch shortcut.
      --  Drawn last so it sits above the rows; simple below-cursor placement is
      --  enough because the switcher sits near the top of the pane.
      if Tab_Count > 1 and then Length (P.Config.Switch_Tooltip) > 0
        and then Hover_X >= Content_X and then Hover_X < Content_X + Content_W
        and then Hover_Y >= Switch_Y and then Hover_Y < Switch_Y + Row_H
      then
         declare
            Tip_Pad : constant Natural := 6;
            Tip_Txt : constant String := To_String (P.Config.Switch_Tooltip);
            Tip_TW  : constant Natural := Guikit.Utf8.Display_Units (Tip_Txt) * Cell_W;
            Tip_W   : constant Natural := Tip_TW + 2 * Tip_Pad;
            Tip_H   : constant Natural := LH + 2 * Tip_Pad;
            Tip_X   : constant Natural :=
              (if Clip_Width > Tip_W then Natural'Min (Natural'Max (Hover_X, 0), Clip_Width - Tip_W) else 0);
            Tip_Y   : constant Natural := Natural'Max (Hover_Y, 0) + LH;
         begin
            Guikit.Widgets.Draw_Tooltip
              (Rectangles      => Rectangles,
               Text            => Text,
               Clip_Width      => Clip_Width,
               Clip_Height     => Clip_Height,
               Box_X           => Tip_X,
               Box_Y           => Tip_Y,
               Box_Width       => Tip_W,
               Box_Height      => Tip_H,
               Fill_Color      => Guikit.Draw.Overlay_Color,
               Border_Color    => Guikit.Draw.Border_Color,
               Label_X         => Tip_X + Tip_Pad,
               Label_Y         => Tip_Y + Tip_Pad,
               Label_Width     => Tip_TW,
               Label_Height    => LH,
               Label_Text      => P.Config.Switch_Tooltip,
               Label_Truncated => False,
               Label_Color     => Guikit.Draw.Text_Color);
         end;
      end if;
   end Build_Frame;

end Guikit.Settings_Panel;
