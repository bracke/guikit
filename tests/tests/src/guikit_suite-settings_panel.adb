with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Settings_Panel;
with Guikit.Draw;
with Guikit.Layout;

--  Exercises the settings-panel state machine (typed field editing, change
--  emission, focus navigation) and a headless Build_Frame that emits draw
--  commands and lays out clickable hit rects without a GPU.
package body Guikit_Suite.Settings_Panel is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   package SP renames Guikit.Settings_Panel;
   use type SP.Change_Kind;
   use type SP.Field_Kind;

   type SP_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : SP_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out SP_Test_Case);

   procedure Test_Edit_And_Emit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Build_Frame (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sections (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shortcut_Capture (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Switch_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Field_Help (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Choice_Fits_Options (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Line_Height_Scaling (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Button_Layouts_Scale (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Wheel_Scroll_Sticks (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Disabled_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class);

   function U (S : String) return Unbounded_String renames To_Unbounded_String;

   function Options (A, B : String; C : String := "") return SP.UString_Vectors.Vector is
      V : SP.UString_Vectors.Vector;
   begin
      V.Append (U (A));
      V.Append (U (B));
      if C /= "" then
         V.Append (U (C));
      end if;
      return V;
   end Options;

   --  A section header plus one field of each editable kind.
   function Sample return SP.Field_Vectors.Vector is
      V : SP.Field_Vectors.Vector;
   begin
      V.Append (SP.Field'(Key => U ("sec"), Label => U ("View"), Kind => SP.Section, others => <>));
      V.Append
        (SP.Field'(Key => U ("hidden"), Label => U ("Hidden"), Kind => SP.Toggle,
                   Value => U ("false"), others => <>));
      V.Append
        (SP.Field'(Key => U ("view"), Label => U ("View mode"), Kind => SP.Choice, Value => U ("small"),
                   Option_Values => Options ("small", "large", "details"),
                   Option_Labels => Options ("Small", "Large", "Details"), others => <>));
      V.Append
        (SP.Field'(Key => U ("font"), Label => U ("Font"), Kind => SP.Number, Value => U ("16"),
                   Min => 10, Max => 32, others => <>));
      V.Append
        (SP.Field'(Key => U ("icon"), Label => U ("Icon theme"), Kind => SP.Text,
                   Value => U ("basic"), others => <>));
      V.Append
        (SP.Field'(Key => U ("entry"), Label => U ("Entries"), Kind => SP.Buttons,
                   Option_Values => Options ("add", "remove"),
                   Option_Labels => Options ("Add", "Remove"), others => <>));
      return V;
   end Sample;

   overriding function Name (T : SP_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit settings panel component");
   end Name;

   overriding procedure Register_Tests (T : in out SP_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Edit_And_Emit'Access, "editing each field kind emits the right change; focus skips sections");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Build_Frame'Access, "Build_Frame emits draw commands and lays out clickable hit rects");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Choice_Fits_Options'Access,
         "a choice too wide for the value column widens instead of clipping its options");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sections'Access, "sections act as tabs: focus stays in the active section, a tab click switches");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shortcut_Capture'Access,
         "a Shortcut row arms press-to-capture; commit emits the chord, cancel and focus-move disarm");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Switch_Tooltip'Access,
         "hovering the tab switcher draws the configured tooltip; hovering elsewhere does not");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Field_Help'Access,
         "the focused field's help renders in the footer, not only in the accessibility node");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Line_Height_Scaling'Access,
         "the panel padding, row gap and preamble gap scale with the line height");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Button_Layouts_Scale'Access,
         "the settings pane, entry and action button layouts scale their padding and gaps with the line height");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Wheel_Scroll_Sticks'Access,
         "the wheel scrolls away from an unchanged focus and stays; scrolling stops at the shown rows' end");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Disabled_Buttons'Access,
         "a disabled button row draws muted and its buttons do not press");
   end Register_Tests;

   --  Two sections, one field each side, to exercise the section switcher.
   function Two_Sections return SP.Field_Vectors.Vector is
      V : SP.Field_Vectors.Vector;
   begin
      V.Append (SP.Field'(Key => U ("sa"), Label => U ("Alpha"), Kind => SP.Section, others => <>));
      V.Append (SP.Field'(Key => U ("a1"), Label => U ("A1"), Kind => SP.Toggle, Value => U ("false"),
                          others => <>));
      V.Append (SP.Field'(Key => U ("sb"), Label => U ("Beta"), Kind => SP.Section, others => <>));
      V.Append (SP.Field'(Key => U ("b1"), Label => U ("B1"), Kind => SP.Toggle, Value => U ("false"),
                          others => <>));
      V.Append (SP.Field'(Key => U ("b2"), Label => U ("B2"), Kind => SP.Toggle, Value => U ("false"),
                          others => <>));
      return V;
   end Two_Sections;

   function Seven_Sections return SP.Field_Vectors.Vector is
      V : SP.Field_Vectors.Vector;
      Labels : constant array (Positive range 1 .. 7) of Unbounded_String :=
        [U ("View"), U ("Sort"), U ("Appearance"), U ("Behavior"),
         U ("Details"), U ("Filetypes"), U ("Shortcuts")];
   begin
      for Index in Labels'Range loop
         V.Append
           (SP.Field'
              (Key => U ("section" & Integer'Image (Index)),
               Label => Labels (Index),
               Kind => SP.Section,
               others => <>));
         V.Append
           (SP.Field'
              (Key => U ("field" & Integer'Image (Index)),
               Label => U ("Field"),
               Kind => SP.Toggle,
               Value => U ("false"),
               others => <>));
      end loop;
      return V;
   end Seven_Sections;

   function Seven_Long_Sections return SP.Field_Vectors.Vector is
      V : SP.Field_Vectors.Vector;
      Labels : constant array (Positive range 1 .. 7) of Unbounded_String :=
        [U ("Ansicht"), U ("Sortierung"), U ("Darstellung"), U ("Verhalten"),
         U ("Details"), U ("Dateitypen"), U ("Tastenkurzel")];
   begin
      for Index in Labels'Range loop
         V.Append
           (SP.Field'
              (Key => U ("long_section" & Integer'Image (Index)),
               Label => Labels (Index),
               Kind => SP.Section,
               others => <>));
         V.Append
           (SP.Field'
              (Key => U ("long_field" & Integer'Image (Index)),
               Label => U ("Dateiendungen anzeigen"),
               Kind => SP.Toggle,
               Value => U ("false"),
               others => <>));
      end loop;
      return V;
   end Seven_Long_Sections;

   procedure Test_Edit_And_Emit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P : SP.Panel;
   begin
      SP.Set_Fields (P, Sample);
      Assert (SP.Focused_Key (P) = "hidden", "focus lands on the first focusable field, skipping the section");

      SP.Cycle_Choice (P, Forward => True);
      declare
         Ch : constant SP.Change := SP.Take_Change (P);
      begin
         Assert (Ch.Kind = SP.Value_Changed, "toggling emits a value change");
         Assert (To_String (Ch.Key) = "hidden" and then To_String (Ch.Value) = "true", "toggle flips to true");
      end;
      Assert (SP.Take_Change (P).Kind = SP.No_Change, "reading a change clears it");

      SP.Move_Focus (P, 1);
      Assert (SP.Focused_Key (P) = "view", "move-focus advances to the next focusable field");
      SP.Cycle_Choice (P, Forward => True);
      Assert (To_String (SP.Take_Change (P).Value) = "large", "cycling a choice advances to the next option");

      SP.Move_Focus (P, 1);
      Assert (SP.Focused_Key (P) = "font", "move-focus reaches the number field");
      SP.Step_Number (P, Up => True);
      Assert (To_String (SP.Take_Change (P).Value) = "17", "stepping a number increments within bounds");

      SP.Move_Focus (P, 1);
      Assert (SP.Focused_Kind (P) = SP.Text, "move-focus reaches the text field");
      SP.Set_Focused_Value (P, "high-contrast");
      declare
         Ch : constant SP.Change := SP.Take_Change (P);
      begin
         Assert (To_String (Ch.Key) = "icon" and then To_String (Ch.Value) = "high-contrast",
                 "editing a text field emits its whole new value");
      end;
   end Test_Edit_And_Emit;

   procedure Test_Build_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P     : SP.Panel;
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
   begin
      SP.Set_Fields (P, Sample);
      SP.Build_Frame (P, 0, 0, 500, 400, 500, 400, True, -1, -1, Rects, Text, Nodes);
      Assert (not Rects.Is_Empty, "Build_Frame emits rectangles (panel, widgets)");
      Assert (not Text.Is_Empty, "Build_Frame emits text (labels)");
      Assert (not Nodes.Is_Empty, "Build_Frame emits accessibility nodes");

      --  A click on the toggle row hits a laid-out field.
      Assert (SP.Click (P, 250, 75), "a click inside the panel hits a laid-out field");

      --  A click on the toggle's switch flips it, rather than only focusing
      --  the row the switch sits in. Sweep the "Hidden" row from the right
      --  edge until the switch is under the pointer.
      declare
         Flipped : Boolean := False;
      begin
         for Node of Nodes loop
            if Ada.Strings.Unbounded.To_String (Node.Name) = "Hidden" then
               for X in reverse Node.X .. Node.X + Node.Width - 1 loop
                  declare
                     Hit    : constant Boolean := SP.Click (P, X, Node.Y + Node.Height / 2);
                     Change : constant SP.Change := SP.Take_Change (P);
                  begin
                     if Hit and then Change.Kind = SP.Value_Changed
                       and then Ada.Strings.Unbounded.To_String (Change.Key) = "hidden"
                     then
                        Flipped := True;
                        exit;
                     end if;
                  end;
               end loop;
            end if;
         end loop;
         Assert (Flipped, "a click on a toggle's switch flips the toggle");
      end;
   end Test_Build_Frame;

   --  German sort options are wider than the shared value column (capped at
   --  55% of the panel). Squeezed into it they clipped to "Dateity", "Größ";
   --  the row now takes the room its short label leaves.
   procedure Test_Choice_Fits_Options (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P       : SP.Panel;
      Fields  : SP.Field_Vectors.Vector;
      Toks, Labels : SP.UString_Vectors.Vector;
      Rects   : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text    : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes   : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Cell_W  : constant Natural := Guikit.Layout.Caret_Advance_Width (20);
      Options : constant array (1 .. 5) of Unbounded_String :=
        [U ("Name"), U ("Dateityp"), U ("Größe"), U ("Erstellt"), U ("Geändert")];
      Seen    : Natural := 0;
   begin
      for Option of Options loop
         Toks.Append (Option);
         Labels.Append (Option);
      end loop;
      Fields.Append
        (SP.Field'(Key => U ("sort"), Label => U ("Sortieren nach"), Kind => SP.Choice,
                   Value => U ("Name"), Option_Values => Toks, Option_Labels => Labels, others => <>));
      SP.Set_Fields (P, Fields);
      SP.Build_Frame (P, 0, 0, 800, 300, 800, 300, True, -1, -1, Rects, Text, Nodes);
      for Command of Text loop
         for Option of Options loop
            if Command.Text = Option then
               Seen := Seen + 1;
               Assert
                 (Command.Width >= Guikit.Layout.Label_Pixel_Width (To_String (Option), Cell_W),
                  "the option " & To_String (Option) & " keeps its full width");
            end if;
         end loop;
      end loop;
      Assert (Seen = 5, "every option is drawn");
   end Test_Choice_Fits_Options;

   procedure Test_Sections (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P     : SP.Panel;
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;

      --  Wrapped tabs are split evenly: no row is left holding a single tab,
      --  which stretched across the whole panel and read as a button.
      function Every_Tab_Row_Shared (Tab_Labels : String) return Boolean is
         Rows : array (1 .. 7) of Natural := [others => 0];
         Ys   : array (1 .. 7) of Natural := [others => Natural'Last];
         Used : Natural := 0;
      begin
         for Command of Text loop
            if Ada.Strings.Fixed.Index (Tab_Labels, "|" & To_String (Command.Text) & "|") > 0 then
               declare
                  Slot : Natural := 0;
               begin
                  for Row in 1 .. Used loop
                     if Ys (Row) = Command.Y then
                        Slot := Row;
                     end if;
                  end loop;
                  if Slot = 0 then
                     Used := Used + 1;
                     Slot := Used;
                     Ys (Slot) := Command.Y;
                  end if;
                  Rows (Slot) := Rows (Slot) + 1;
               end;
            end if;
         end loop;
         for Row in 1 .. Used loop
            if Used > 1 and then Rows (Row) < 2 then
               return False;
            end if;
         end loop;
         return Used > 0;
      end Every_Tab_Row_Shared;
   begin
      SP.Set_Fields (P, Two_Sections);
      Assert (SP.Section_Count (P) = 2, "two Section fields make two tabs");
      Assert (SP.Active_Section (P) = 1, "the first section is active initially");
      Assert (SP.Focused_Key (P) = "a1", "focus lands on the active section's first field");

      --  Focus stays inside the active section (b1/b2 are not reachable yet).
      SP.Move_Focus (P, 1);
      Assert (SP.Focused_Key (P) = "a1", "move-focus does not leave the active section");

      --  Switch to section 2: focus moves there, and its fields become reachable.
      SP.Set_Active_Section (P, 2);
      Assert (SP.Active_Section (P) = 2 and then SP.Focused_Key (P) = "b1",
              "switching section moves focus to its first field");
      SP.Move_Focus (P, 1);
      Assert (SP.Focused_Key (P) = "b2", "focus navigates within the newly active section");

      --  A click on the far-right of the tab switcher selects the last tab.
      SP.Set_Active_Section (P, 1);
      SP.Build_Frame (P, 0, 0, 400, 400, 400, 400, True, -1, -1, Rects, Text, Nodes);
      Assert (SP.Click (P, 370, 50), "a click in the switcher row lands");
      Assert (SP.Active_Section (P) = 2, "clicking the right tab switches to section 2");

      --  Dense tab sets wrap at compact widths, keeping full labels legible and
      --  every cell clickable instead of collapsing them to two-letter fragments.
      SP.Set_Fields (P, Seven_Sections);
      SP.Build_Frame (P, 0, 0, 440, 300, 440, 300, True, -1, -1, Rects, Text, Nodes);
      declare
         Found_Shortcuts : Boolean := False;
      begin
         for Command of Text loop
            if To_String (Command.Text) = "Shortcuts" then
               Found_Shortcuts := True;
            end if;
         end loop;
         Assert (Found_Shortcuts, "compact wrapped tabs retain the full Shortcuts label");
      end;
      Assert (Every_Tab_Row_Shared ("|View|Sort|Appearance|Behavior|Details|Filetypes|Shortcuts|"),
              "wrapped tabs are split evenly, with no tab alone on a row");
      Assert (SP.Click (P, 400, 75), "a click in the second compact tab row lands");
      Assert (SP.Active_Section (P) = 7, "the second-row tab maps back to its original section");

      --  Longer localized labels need a third row at the same width.  Every
      --  emitted label box must retain its natural text width, and the final
      --  row must map back to the original seventh section.
      SP.Set_Fields (P, Seven_Long_Sections);
      SP.Build_Frame (P, 0, 0, 440, 300, 440, 300, True, -1, -1, Rects, Text, Nodes);
      declare
         Cell_W : constant Natural := Guikit.Layout.Caret_Advance_Width (20);
         Seen_Ansicht, Seen_Sortierung, Seen_Darstellung, Seen_Verhalten : Boolean := False;
         Seen_Details, Seen_Dateitypen, Seen_Tastenkurzel : Boolean := False;
         Seen_Long_Field : Boolean := False;
      begin
         for Command of Text loop
            declare
               Label : constant String := To_String (Command.Text);
            begin
               if Label = "Ansicht" or else Label = "Sortierung"
                 or else Label = "Darstellung" or else Label = "Verhalten"
                 or else Label = "Details" or else Label = "Dateitypen"
                 or else Label = "Tastenkurzel"
               then
                  Assert
                    (Command.Width >= Guikit.Layout.Label_Pixel_Width (Label, Cell_W),
                     "a localized compact tab retains its natural label width");
                  if Label = "Ansicht" then
                     Seen_Ansicht := True;
                  elsif Label = "Sortierung" then
                     Seen_Sortierung := True;
                  elsif Label = "Darstellung" then
                     Seen_Darstellung := True;
                  elsif Label = "Verhalten" then
                     Seen_Verhalten := True;
                  elsif Label = "Details" then
                     Seen_Details := True;
                  elsif Label = "Dateitypen" then
                     Seen_Dateitypen := True;
                  else
                     Seen_Tastenkurzel := True;
                  end if;
               elsif Label = "Dateiendungen anzeigen" then
                  Seen_Long_Field := True;
                  Assert
                    (Command.Width >= Guikit.Layout.Label_Pixel_Width (Label, Cell_W),
                     "a compact toggle label uses the blank value-column space");
               end if;
            end;
         end loop;
         Assert
           (Seen_Ansicht and then Seen_Sortierung and then Seen_Darstellung
            and then Seen_Verhalten and then Seen_Details and then Seen_Dateitypen
            and then Seen_Tastenkurzel and then Seen_Long_Field,
            "all localized compact tabs are rendered");
      end;
      Assert (Every_Tab_Row_Shared
                ("|Ansicht|Sortierung|Darstellung|Verhalten|Details|Dateitypen|Tastenkurzel|"),
              "three rows of localized tabs are split evenly too");
      Assert (SP.Click (P, 220, 100), "a click in the third localized tab row lands");
      Assert (SP.Active_Section (P) = 7, "the third-row tab maps to the final section");
   end Test_Sections;

   --  A Toggle then a Shortcut field (no section), to exercise press-to-capture.
   function Shortcut_Fields return SP.Field_Vectors.Vector is
      V : SP.Field_Vectors.Vector;
   begin
      V.Append (SP.Field'(Key => U ("flag"), Label => U ("Flag"), Kind => SP.Toggle,
                          Value => U ("false"), others => <>));
      V.Append (SP.Field'(Key => U ("copy"), Label => U ("Copy"), Kind => SP.Shortcut,
                          Value => U ("control+c"), others => <>));
      return V;
   end Shortcut_Fields;

   procedure Test_Shortcut_Capture (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P : SP.Panel;
   begin
      SP.Set_Fields (P, Shortcut_Fields);
      Assert (not SP.Is_Capturing (P), "a freshly-supplied panel is not capturing");
      Assert (SP.Capturing_Key (P) = "", "no armed field means an empty capturing key");

      --  Arming only takes on a focused Shortcut field.
      SP.Begin_Capture (P);
      Assert (not SP.Is_Capturing (P), "arming does nothing while a non-Shortcut field is focused");

      SP.Move_Focus (P, 1);
      Assert (SP.Focused_Kind (P) = SP.Shortcut, "focus reaches the Shortcut field");
      SP.Begin_Capture (P);
      Assert (SP.Is_Capturing (P), "arming a focused Shortcut field enters capture");
      Assert (SP.Capturing_Key (P) = "copy", "the armed field's key is reported");

      --  Capture survives an every-frame re-supply of the same field list.
      SP.Set_Fields (P, Shortcut_Fields);
      Assert (SP.Is_Capturing (P) and then SP.Capturing_Key (P) = "copy",
              "re-supplying the same fields keeps the capture armed");

      --  Committing a captured chord sets the value, disarms, and emits the change.
      SP.Set_Captured_Shortcut (P, "control+shift+k");
      Assert (not SP.Is_Capturing (P), "committing a chord disarms the field");
      declare
         Ch : constant SP.Change := SP.Take_Change (P);
      begin
         Assert (Ch.Kind = SP.Value_Changed, "committing a chord emits a value change");
         Assert (To_String (Ch.Key) = "copy" and then To_String (Ch.Value) = "control+shift+k",
                 "the change carries the field key and the captured chord");
      end;

      --  Cancel disarms without emitting a change.
      SP.Begin_Capture (P);
      Assert (SP.Is_Capturing (P), "the Shortcut field re-arms");
      SP.Cancel_Capture (P);
      Assert (not SP.Is_Capturing (P), "cancel disarms the field");
      Assert (SP.Take_Change (P).Kind = SP.No_Change, "cancel emits no change");

      --  An empty commit records an unbind.
      SP.Begin_Capture (P);
      SP.Set_Captured_Shortcut (P, "");
      Assert (To_String (SP.Take_Change (P).Value) = "", "an empty commit unbinds the shortcut");

      --  Moving focus away cancels an in-progress capture.
      SP.Begin_Capture (P);
      Assert (SP.Is_Capturing (P), "re-arm before the focus-move check");
      SP.Move_Focus (P, -1);
      Assert (not SP.Is_Capturing (P), "moving focus cancels the capture");

      --  A click on the panel lands (the row-level hit that arms a Shortcut row).
      declare
         Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text  : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      begin
         SP.Build_Frame (P, 0, 0, 500, 400, 500, 400, True, -1, -1, Rects, Text, Nodes);
         Assert (SP.Click (P, 250, 60) or else SP.Click (P, 250, 90),
                 "a click inside the panel lands on a laid-out row");
      end;
   end Test_Shortcut_Capture;

   procedure Test_Switch_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P     : SP.Panel;
      Cfg   : SP.Configuration;

      function Rect_Count (Hover_X, Hover_Y : Integer) return Natural is
         Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text  : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      begin
         SP.Build_Frame (P, 0, 0, 500, 400, 500, 400, True, Hover_X, Hover_Y, Rects, Text, Nodes);
         return Natural (Rects.Length);
      end Rect_Count;
   begin
      Cfg.Switch_Tooltip := U ("Ctrl+Tab switches sections");
      SP.Set_Configuration (P, Cfg);
      SP.Set_Fields (P, Two_Sections);   --  two sections => the switcher is shown

      --  The switcher row sits just below the title; a hover there adds the
      --  tooltip's box/border rectangles over the off-window baseline.
      declare
         Off  : constant Natural := Rect_Count (-1, -1);
         Over : constant Natural := Rect_Count (100, 50);
      begin
         Assert (Over > Off, "hovering the tab switcher draws the tooltip (extra rectangles)");
         Assert (Rect_Count (100, 300) = Off,
                 "hovering a field row (not the switcher) draws no tooltip");
      end;

      --  With wrapped compact tabs, the tooltip clears every tab row instead
      --  of obscuring the second row's labels.
      SP.Set_Fields (P, Seven_Sections);
      declare
         Rects     : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text      : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes     : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Last_Tab_Y : Natural := 0;
         Tooltip_Y  : Natural := 0;
      begin
         SP.Build_Frame (P, 0, 0, 440, 300, 440, 300, True, 50, 50, Rects, Text, Nodes);
         for Command of Text loop
            if To_String (Command.Text) = "Ctrl+Tab switches sections" then
               Tooltip_Y := Command.Y;
            elsif To_String (Command.Text) = "Shortcuts" then
               Last_Tab_Y := Command.Y;
            end if;
         end loop;
         Assert (Last_Tab_Y > 0 and then Tooltip_Y >= Last_Tab_Y + Cfg.Line_Height,
                 "the compact tab tooltip is positioned below the wrapped tab labels");
      end;
   end Test_Switch_Tooltip;

   procedure Test_Field_Help (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P     : SP.Panel;
      Fields : SP.Field_Vectors.Vector;
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;

      function Has_Text (S : String) return Boolean is
      begin
         for C of Text loop
            if To_String (C.Text) = S then
               return True;
            end if;
         end loop;
         return False;
      end Has_Text;
   begin
      Fields.Append
        (SP.Field'(Key => U ("flag"), Label => U ("Flag"), Kind => SP.Toggle, Value => U ("false"),
                   Help => U ("Toggle this to change behaviour."), others => <>));
      SP.Set_Fields (P, Fields);
      SP.Build_Frame (P, 0, 0, 500, 400, 500, 400, True, -1, -1, Rects, Text, Nodes);
      Assert (Has_Text ("Toggle this to change behaviour."),
              "the focused field's help is drawn as footer text");

      --  Help wider than the panel wraps at spaces instead of being cut off.
      Fields.Clear;
      Fields.Append
        (SP.Field'(Key => U ("flag"), Label => U ("Flag"), Kind => SP.Toggle, Value => U ("false"),
                   Help => U ("Left and right switch between every one of the available views here."),
                   others => <>));
      SP.Set_Fields (P, Fields);
      Rects.Clear;
      Text.Clear;
      SP.Build_Frame (P, 0, 0, 400, 400, 400, 400, True, -1, -1, Rects, Text, Nodes);
      declare
         Cell_W : constant Natural := Guikit.Layout.Caret_Advance_Width (20);
         Joined : Unbounded_String;
         Lines  : Natural := 0;
      begin
         for C of Text loop
            if Ada.Strings.Fixed.Index (To_String (C.Text), "views") > 0
              or else Ada.Strings.Fixed.Index (To_String (C.Text), "Left and") = 1
              or else Ada.Strings.Fixed.Index (To_String (C.Text), "every") > 0
            then
               Lines := Lines + 1;
               Append (Joined, C.Text & " ");
               Assert (Guikit.Layout.Label_Pixel_Width (To_String (C.Text), Cell_W) <= C.Width,
                       "each wrapped help line fits the footer width");
            end if;
         end loop;
         Assert (Lines >= 2, "long help wraps onto more than one line");
         Assert (Ada.Strings.Fixed.Index (To_String (Joined), "views here.") > 0,
                 "no word of the help is lost to clipping");
      end;
   end Test_Field_Help;

   procedure Test_Line_Height_Scaling (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Accessibility_Role;

      Region_X : constant := 50;
      Region_Y : constant := 40;

      --  A preamble toggle, then one section (so no tab switcher) of two toggles:
      --  the preamble and the section are split by the extra group gap.
      function Fields return SP.Field_Vectors.Vector is
         V : SP.Field_Vectors.Vector;
      begin
         V.Append (SP.Field'(Key => U ("pre"), Label => U ("Pre"), Kind => SP.Toggle, Value => U ("false"),
                             others => <>));
         V.Append (SP.Field'(Key => U ("sec"), Label => U ("Sec"), Kind => SP.Section, others => <>));
         V.Append (SP.Field'(Key => U ("two"), Label => U ("Two"), Kind => SP.Toggle, Value => U ("false"),
                             others => <>));
         V.Append (SP.Field'(Key => U ("three"), Label => U ("Three"), Kind => SP.Toggle, Value => U ("false"),
                             others => <>));
         return V;
      end Fields;

      --  Render at Line_Height and check the row geometry against the expected
      --  panel padding (14 at 20 px), row gap (8) and preamble-to-section gap
      --  (row gap plus 4). Title_Inset is the title's top inset, max (4, LH / 4).
      procedure Check (LH : Positive; Pad, Row_Gap, Group_Gap, Title_Inset : Natural) is
         Where    : constant String := " at line height" & LH'Image;
         Row_H    : constant Natural := LH + Row_Gap;
         Rows_Top : constant Natural := Region_Y + Title_Inset + Row_H;
         P        : SP.Panel;
         Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text     : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Seen_Pre, Seen_Two, Seen_Three, Seen_Label : Boolean := False;
      begin
         SP.Set_Configuration (P, SP.Configuration'(Line_Height => LH, Title => U ("Settings"), others => <>));
         SP.Set_Fields (P, Fields);
         SP.Build_Frame (P, Region_X, Region_Y, 600, 500, 1000, 1000, False, -1, -1, Rects, Text, Nodes);
         for Node of Nodes loop
            if Node.Role = Guikit.Draw.Role_Text_Input then
               Assert (Node.Height = Row_H, "a field row is a line plus the scaled row gap" & Where);
               if Node.Name = "Pre" then
                  Seen_Pre := True;
                  Assert (Node.Y = Rows_Top, "the preamble row follows the title row" & Where);
               elsif Node.Name = "Two" then
                  Seen_Two := True;
                  Assert (Node.Y = Rows_Top + Row_H + Group_Gap,
                          "the section's first row sits one scaled group gap below the preamble" & Where);
               elsif Node.Name = "Three" then
                  Seen_Three := True;
                  Assert (Node.Y = Rows_Top + 2 * Row_H + Group_Gap,
                          "the section's rows are one scaled row apart" & Where);
               end if;
            end if;
         end loop;
         for Command of Text loop
            if Command.Text = "Pre" then
               Seen_Label := True;
               Assert (Command.X = Region_X + Pad, "a field label is inset by the scaled panel padding" & Where);
               Assert (Command.Y = Rows_Top + Row_Gap / 2, "a field label is centred in its row" & Where);
            elsif Command.Text = "Settings" then
               Assert (Command.X = Region_X + Pad, "the title is inset by the scaled panel padding" & Where);
            end if;
         end loop;
         Assert (Seen_Pre and then Seen_Two and then Seen_Three and then Seen_Label,
                 "every field row and the preamble label are rendered" & Where);
      end Check;
      --  The controls' own chrome, at 20 px: a text field is its row less 4 px
      --  tall and insets its value 4 px; a button pads its label 6 px a side
      --  and sits 4 px from the next; the scrollbar is 12 px wide; the panel's
      --  top accent band is 3 px tall and its shadow starts 3 px in.
      procedure Check_Chrome (LH : Positive; Margin, Inset, Button_Pad, Button_Gap, Bar, Accent, Shadow : Natural) is
         use type Guikit.Draw.Render_Color;

         Where    : constant String := " at line height" & LH'Image;
         Row_H    : constant Natural := LH + Guikit.Layout.Scaled (Guikit.Layout.Settings_Row_Gap, LH);
         Cell_W   : constant Natural := Guikit.Layout.Caret_Advance_Width (LH);
         V        : SP.Field_Vectors.Vector;
         P        : SP.Panel;
         Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text     : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         One_X, Two_X, Value_X : Integer := -1;
         Seen_Field, Seen_Bar, Seen_Accent, Seen_Shadow : Boolean := False;
      begin
         --  A row of actions (no label of its own, so its buttons take their
         --  natural widths), then more text fields than fit, so it scrolls.
         V.Append
           (SP.Field'(Key => U ("act"), Label => U (""), Kind => SP.Buttons,
                      Option_Values => Options ("one", "two"), Option_Labels => Options ("One", "Two"),
                      others => <>));
         for I in 1 .. 30 loop
            V.Append
              (SP.Field'(Key => U ("f" & I'Image), Label => U ("Field" & I'Image), Kind => SP.Text,
                         Value => U ("abc"), others => <>));
         end loop;
         SP.Set_Configuration (P, SP.Configuration'(Line_Height => LH, others => <>));
         SP.Set_Fields (P, V);
         SP.Build_Frame (P, Region_X, Region_Y, 600, 500, 1000, 1000, False, -1, -1, Rects, Text, Nodes);
         for Command of Text loop
            if Command.Text = "One" and then One_X < 0 then
               One_X := Command.X;
            elsif Command.Text = "Two" and then Two_X < 0 then
               Two_X := Command.X;
            elsif Command.Text = "abc" and then Value_X < 0 then
               Value_X := Command.X;
            end if;
         end loop;
         Assert (One_X >= 0 and then Two_X >= 0 and then Value_X >= 0,
                 "the buttons and a field value are drawn" & Where);
         Assert (Two_X - One_X = 3 * Cell_W + 2 * Button_Pad + Button_Gap,
                 "a button pads its label and is followed by the gap" & Where);
         for R of Rects loop
            if R.Color = Guikit.Draw.Input_Color and then R.X = Value_X - Inset then
               Seen_Field := True;
               Assert (R.Height = Row_H - Margin, "a text field is its row less the scaled margin" & Where);
            elsif R.Color = Guikit.Draw.Border_Color and then R.X = Region_X + 600 - Bar and then R.Width = Bar then
               Seen_Bar := True;
            elsif R.Color = Guikit.Draw.Selection_Color and then R.X = Region_X and then R.Y = Region_Y
              and then R.Width = 600 and then R.Height = Accent
            then
               Seen_Accent := True;
            elsif R.Color = Guikit.Draw.Shadow_Color and then R.X = Region_X + Shadow and then R.Y = Region_Y + 500 then
               Seen_Shadow := True;
            end if;
         end loop;
         Assert (Seen_Field, "a text field's value is inset by the scaled inset" & Where);
         Assert (Seen_Bar, "the scrollbar track is the scaled width, at the panel's right edge" & Where);
         Assert (Seen_Accent, "the panel's top accent band is the scaled height" & Where);
         Assert (Seen_Shadow, "the panel's shadow starts the scaled offset in" & Where);
      end Check_Chrome;

      --  The tab switcher's tooltip: 4 px below the switcher and padding its
      --  text 6 px, at 20 px. Title_Inset is the title row's top inset.
      procedure Check_Tooltip (LH : Positive; Title_Inset, Tip_Pad, Tip_Gap : Natural) is
         Where    : constant String := " at line height" & LH'Image;
         Row_H    : constant Natural := LH + Guikit.Layout.Scaled (Guikit.Layout.Settings_Row_Gap, LH);
         Switch_Y : constant Natural := Region_Y + Title_Inset + Row_H;
         Hover_X  : constant Natural := Region_X + Guikit.Layout.Scaled (Guikit.Layout.Settings_Pane_Padding, LH) + 10;
         V        : SP.Field_Vectors.Vector;
         P        : SP.Panel;
         Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text     : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Seen     : Boolean := False;
      begin
         V.Append (SP.Field'(Key => U ("a"), Label => U ("A"), Kind => SP.Section, others => <>));
         V.Append (SP.Field'(Key => U ("one"), Label => U ("One"), Kind => SP.Toggle, Value => U ("false"),
                             others => <>));
         V.Append (SP.Field'(Key => U ("b"), Label => U ("B"), Kind => SP.Section, others => <>));
         V.Append (SP.Field'(Key => U ("two"), Label => U ("Two"), Kind => SP.Toggle, Value => U ("false"),
                             others => <>));
         SP.Set_Configuration
           (P, SP.Configuration'(Line_Height => LH, Switch_Tooltip => U ("Switch tabs"), others => <>));
         SP.Set_Fields (P, V);
         SP.Build_Frame
           (P, Region_X, Region_Y, 600, 500, 1000, 1000, False, Hover_X, Switch_Y + 2, Rects, Text, Nodes);
         for Command of Text loop
            if Command.Text = "Switch tabs" then
               Seen := True;
               Assert (Command.X = Hover_X + Tip_Pad, "the tooltip pads its text by the scaled padding" & Where);
               Assert (Command.Y = Switch_Y + Row_H + Tip_Gap + Tip_Pad,
                       "the tooltip sits the scaled gap below the switcher" & Where);
            end if;
         end loop;
         Assert (Seen, "hovering the tab switcher shows its tooltip" & Where);
      end Check_Tooltip;
   begin
      Check (20, Pad => 14, Row_Gap => 8, Group_Gap => 12, Title_Inset => 5);
      Check (30, Pad => 21, Row_Gap => 12, Group_Gap => 18, Title_Inset => 7);
      Check (40, Pad => 28, Row_Gap => 16, Group_Gap => 24, Title_Inset => 10);
      Check_Chrome
        (20, Margin => 4, Inset => 4, Button_Pad => 6, Button_Gap => 4, Bar => 12, Accent => 3, Shadow => 3);
      Check_Chrome
        (40, Margin => 8, Inset => 8, Button_Pad => 12, Button_Gap => 8, Bar => 24, Accent => 6, Shadow => 6);
      Check_Tooltip (20, Title_Inset => 5, Tip_Pad => 6, Tip_Gap => 4);
      Check_Tooltip (40, Title_Inset => 10, Tip_Pad => 12, Tip_Gap => 8);
   end Test_Line_Height_Scaling;

   procedure Test_Button_Layouts_Scale (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  The entry buttons for a pane and labels that grow with the text, as a
      --  caller measures them at the line height in use.
      function Entry_At
        (LH      : Positive;
         Pane_W  : Natural;
         Label_W : Natural)
         return Guikit.Layout.Settings_Entry_Button_Layout
      is (Guikit.Layout.Calculate_Settings_Entry_Button_Layout
            (Pane_X             => 0,
             Pane_Width         => Pane_W,
             Add_Label_Width    => Label_W,
             Remove_Label_Width => Label_W,
             Line_Height        => LH));

      Entry_1   : constant Guikit.Layout.Settings_Entry_Button_Layout := Entry_At (20, 500, 30);
      Entry_15  : constant Guikit.Layout.Settings_Entry_Button_Layout := Entry_At (30, 750, 45);
      Entry_2   : constant Guikit.Layout.Settings_Entry_Button_Layout := Entry_At (40, 1000, 60);
      Narrow_2  : constant Guikit.Layout.Settings_Entry_Button_Layout := Entry_At (40, 1000, 30);
      Action_1  : constant Guikit.Layout.Settings_Action_Button_Layout :=
        Guikit.Layout.Calculate_Settings_Action_Button_Layout (10, 100, 20);
      Action_15 : constant Guikit.Layout.Settings_Action_Button_Layout :=
        Guikit.Layout.Calculate_Settings_Action_Button_Layout (15, 150, 30);
      Action_2  : constant Guikit.Layout.Settings_Action_Button_Layout :=
        Guikit.Layout.Calculate_Settings_Action_Button_Layout (20, 200, 40);
      Pane_15   : constant Guikit.Layout.Settings_Pane_Layout :=
        Guikit.Layout.Calculate_Settings_Pane_Layout (1000, 800, 40, 30);
      Pane_2    : constant Guikit.Layout.Settings_Pane_Layout :=
        Guikit.Layout.Calculate_Settings_Pane_Layout (1000, 800, 40, 40);
   begin
      --  Entry buttons: label + two input paddings, a gap, an edge padding.
      Assert (Entry_1.Add_Button_Width = 46 and then Entry_1.Remove_Button_Width = 46,
              "at 20 px each entry button is the label plus two 8 px paddings");
      Assert (Entry_1.Total_Width = 96 and then Entry_1.Add_Button_X = 390 and then Entry_1.Remove_Button_X = 440,
              "at 20 px the entry buttons are 4 px apart and 14 px from the pane edge");
      Assert (Entry_15.Add_Button_Width = 69 and then Entry_15.Remove_Button_Width = 69,
              "at 1.5x each entry button is the label plus two 12 px paddings");
      Assert (Entry_15.Total_Width = 144 and then Entry_15.Add_Button_X = 585
                and then Entry_15.Remove_Button_X = 660,
              "at 1.5x the entry buttons are 6 px apart and 21 px from the pane edge");
      Assert (Entry_2.Add_Button_Width = 2 * Entry_1.Add_Button_Width
                and then Entry_2.Remove_Button_Width = 2 * Entry_1.Remove_Button_Width,
              "at 2x each entry button is exactly twice as wide");
      Assert (Entry_2.Total_Width = 2 * Entry_1.Total_Width
                and then Entry_2.Add_Button_X = 2 * Entry_1.Add_Button_X
                and then Entry_2.Remove_Button_X = 2 * Entry_1.Remove_Button_X,
              "at 2x the entry gap and edge padding are exactly doubled");
      Assert (Narrow_2.Add_Button_Width = 68,
              "at 2x a short label is floored at the doubled 34 px minimum button width");

      --  Action buttons: two halves of the text column split by a 4 px gap.
      Assert (Action_1.First_Button_Width = 48 and then Action_1.Second_Button_X = 62,
              "at 20 px the action buttons are split by a 4 px gap");
      Assert (Action_15.First_Button_X = 15 and then Action_15.First_Button_Width = 72
                and then Action_15.Second_Button_X = 93 and then Action_15.Second_Button_Width = 72,
              "at 1.5x the action buttons are split by a 6 px gap");
      Assert (Action_2.First_Button_X = 2 * Action_1.First_Button_X
                and then Action_2.First_Button_Width = 2 * Action_1.First_Button_Width
                and then Action_2.Second_Button_X = 2 * Action_1.Second_Button_X
                and then Action_2.Second_Button_Width = 2 * Action_1.Second_Button_Width
                and then Action_2.Total_Width = 2 * Action_1.Total_Width,
              "at 2x the action buttons and their gap are exactly doubled");

      --  The settings pane insets its text column by the scaled pane padding.
      Assert (Pane_15.Text_X = Pane_15.X + 21 and then Pane_15.Text_Y = Pane_15.Y + 21
                and then Pane_15.Text_Width = Pane_15.Width - 42,
              "at 1.5x the pane's text column is inset by a 21 px padding");
      Assert (Pane_15.Height = 660,
              "at 1.5x the pane fits 15 lines, 14 scaled row gaps and two scaled paddings");
      Assert (Pane_2.Text_X = Pane_2.X + 28 and then Pane_2.Text_Y = Pane_2.Y + 28
                and then Pane_2.Text_Width = Pane_2.Width - 56,
              "at 2x the pane's text column is inset by a doubled 28 px padding");
      Assert (Pane_2.Height = 667, "at 2x the taller pane is clamped to the height below the top margin");
   end Test_Button_Layouts_Scale;

   --  Section "A" with three toggles A1..A3, then section "B" with fifteen
   --  toggles B1..B15: the hidden section and both headers are fields too,
   --  which the scroll limit must not count.
   function Long_Section return SP.Field_Vectors.Vector is
      V : SP.Field_Vectors.Vector;

      procedure Add_Section (Name : String; Count : Positive) is
      begin
         V.Append (SP.Field'(Key => U ("s" & Name), Label => U (Name), Kind => SP.Section, others => <>));
         for Index in 1 .. Count loop
            declare
               Label : constant String := Name & Ada.Strings.Fixed.Trim (Index'Image, Ada.Strings.Left);
            begin
               V.Append (SP.Field'(Key => U (Label), Label => U (Label), Kind => SP.Toggle,
                                   Value => U ("false"), others => <>));
            end;
         end loop;
      end Add_Section;
   begin
      Add_Section ("A", 3);
      Add_Section ("B", 15);
      return V;
   end Long_Section;

   procedure Test_Wheel_Scroll_Sticks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P     : SP.Panel;
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;

      --  At line height 20 a 500x300 panel with two tabs shows seven rows.
      --  Build_Frame appends; each render starts from empty lists.
      procedure Render is
      begin
         Rects.Clear;
         Text.Clear;
         Nodes.Clear;
         SP.Build_Frame (P, 0, 0, 500, 300, 500, 300, True, -1, -1, Rects, Text, Nodes);
      end Render;

      function Drawn (Label : String) return Boolean is
      begin
         for Command of Text loop
            if To_String (Command.Text) = Label then
               return True;
            end if;
         end loop;
         return False;
      end Drawn;
   begin
      SP.Set_Fields (P, Long_Section);
      SP.Set_Active_Section (P, 2);
      Render;
      Assert (SP.Focused_Key (P) = "B1", "switching to section B focuses its first row");
      Assert (Drawn ("B1") and then Drawn ("B7") and then not Drawn ("B8"),
              "section B shows its first seven rows");

      SP.Scroll (P, 3);
      Render;
      Assert (Drawn ("B4") and then not Drawn ("B1"),
              "a wheel scroll away from the focused row sticks instead of snapping back to it");
      Render;
      Assert (Drawn ("B4") and then not Drawn ("B1"), "and it still sticks on the frame after");

      SP.Scroll (P, 100);
      SP.Scroll (P, -2);
      Render;
      Assert (Drawn ("B13") and then not Drawn ("B14") and then not Drawn ("B15"),
              "the scroll limit is the shown rows' end (15 rows, 7 visible), not the field count, "
              & "so scrolling back up from the bottom moves at once");

      SP.Move_Focus (P, 1);
      Render;
      Assert (SP.Focused_Key (P) = "B2" and then Drawn ("B2"),
              "moving the focus brings the newly focused row back into view");

      SP.Scroll (P, 5);
      Render;
      Assert (not Drawn ("B2"), "the wheel scrolls away from the focus again");
      SP.Cycle_Choice (P, Forward => True);
      Assert (SP.Take_Change (P).Kind = SP.Value_Changed, "editing the focused row emits its change");
      Render;
      Assert (Drawn ("B2"), "editing the scrolled-away focused row brings it back into view");
   end Test_Wheel_Scroll_Sticks;

   procedure Test_Disabled_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Render_Color;

      --  Render one buttons row, click its "Add" label, and report the label's
      --  colour and the change the click produced.
      procedure Press_Add (Enabled : Boolean; Colour : out Guikit.Draw.Render_Color; Result : out SP.Change) is
         P      : SP.Panel;
         Fields : SP.Field_Vectors.Vector;
         Rects  : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text   : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes  : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Found  : Boolean := False;
      begin
         Fields.Append
           (SP.Field'(Key => U ("entry"), Label => U ("Entries"), Kind => SP.Buttons,
                      Option_Values => Options ("add", "remove"),
                      Option_Labels => Options ("Add", "Remove"), Enabled => Enabled, others => <>));
         SP.Set_Fields (P, Fields);
         SP.Build_Frame (P, 0, 0, 500, 300, 500, 300, True, -1, -1, Rects, Text, Nodes);
         Colour := Guikit.Draw.Text_Color;
         Result := (Kind => SP.No_Change, others => <>);
         for Command of Text loop
            if To_String (Command.Text) = "Add" then
               Found := True;
               Colour := Command.Color;
               Assert (SP.Click (P, Command.X + 1, Command.Y + 1), "a click on the button lands on the panel");
               Result := SP.Take_Change (P);
            end if;
         end loop;
         Assert (Found, "the Add button's label is drawn");
      end Press_Add;

      Colour : Guikit.Draw.Render_Color;
      Change : SP.Change;
   begin
      Press_Add (True, Colour, Change);
      Assert (Change.Kind = SP.Button_Pressed and then To_String (Change.Value) = "add",
              "an enabled button presses");
      Assert (Colour = Guikit.Draw.Text_Color, "an enabled button's label uses the text colour");

      Press_Add (False, Colour, Change);
      Assert (Change.Kind = SP.No_Change, "a disabled button does not press");
      Assert (Colour = Guikit.Draw.Disabled_Text_Color, "a disabled button's label is muted");
   end Test_Disabled_Buttons;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new SP_Test_Case));
      return Result;
   end Suite;

end Guikit_Suite.Settings_Panel;
