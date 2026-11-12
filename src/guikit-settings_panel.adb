with Ada.Strings.Fixed;

with Guikit.Layout;
with Guikit.Segmented;
with Guikit.Utf8;
with Guikit.Widgets;

package body Guikit.Settings_Panel is

   use Ada.Strings.Unbounded;

   --  Scrollbar width at Guikit.Layout.Reference_Line_Height (matches the
   --  grid/list); scaled with the text like the rest of the panel's chrome.
   Bar_W_Base : constant Natural := 12;

   --  ----- small value helpers -------------------------------------------------

   function Is_True (Value : UString) return Boolean is (To_String (Value) = "true");

   function To_Int (Value : UString; Default : Integer) return Integer is
   begin
      return Integer'Value (To_String (Value));
   exception
      --  Not a number: the field's default stands, as for an empty value.
      when others =>
         return Default;
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
      P.Followed  := 0;
      P.Hits.Clear;
      P.Pending := (Kind => No_Change, others => <>);
   end Reset;

   --  ----- change plumbing ------------------------------------------------------

   --  An edit brings the focused row back into view on the next frame, even
   --  when the wheel had scrolled away from it: the user is acting on it.
   procedure Emit_Value (P : in out Panel; Key, Value : UString) is
   begin
      P.Pending  := (Kind => Value_Changed, Key => Key, Value => Value);
      P.Followed := 0;
   end Emit_Value;

   procedure Emit_Button (P : in out Panel; Key, Button : UString) is
   begin
      P.Pending  := (Kind => Button_Pressed, Key => Key, Value => Button);
      P.Followed := 0;
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

   --  How many fields are rendered as rows now (Field_Is_Visible, counted in
   --  one pass): the preamble plus the active section, never a header.
   function Visible_Field_Count (P : Panel) return Natural is
      Ord   : Natural := 0;
      Count : Natural := 0;
   begin
      for F of P.Fields loop
         if F.Kind = Section then
            Ord := Ord + 1;
         elsif Ord = 0 or else Ord = P.Active then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Visible_Field_Count;

   procedure Scroll (P : in out Panel; Lines : Integer) is
      --  Against the rows actually shown -- not every field, which counts the
      --  section headers and the hidden sections' rows and let the wheel run
      --  past the end into blank space.
      Rows       : constant Natural := Visible_Field_Count (P);
      Max_Scroll : constant Natural :=
        (if Rows > P.Visible_Rows then Rows - P.Visible_Rows else 0);
      Next : constant Integer := Integer (P.Offset) + Lines;
   begin
      P.Offset := Natural (Integer'Max (0, Integer'Min (Next, Max_Scroll)));
   end Scroll;

   function Click (P : in out Panel; X : Integer; Y : Integer) return Boolean is
   begin
      --  Latest first: a control's box (toggle, choice cell, stepper) is
      --  registered after the row it sits in and must win over that row's
      --  focus hit, or a click on the control only focuses the row.
      for H of reverse P.Hits loop
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
                        if F.Enabled and then H.Option in 1 .. Natural (F.Option_Values.Length) then
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
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector) is separate;

end Guikit.Settings_Panel;
