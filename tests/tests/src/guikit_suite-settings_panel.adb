with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Settings_Panel;
with Guikit.Draw;

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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new SP_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Settings_Panel;
