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
   end Test_Build_Frame;

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
   end Test_Field_Help;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new SP_Test_Case));
      return Result;
   end Suite;

end Guikit_Suite.Settings_Panel;
