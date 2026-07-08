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
   end Register_Tests;

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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new SP_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Settings_Panel;
