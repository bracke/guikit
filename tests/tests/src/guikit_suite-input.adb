with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Input;

--  Smoke tests for the domain-free input value types. They confirm the empty
--  modifier set holds no modifiers, that setting one modifier reads back
--  independently of the others, and that the key/direction enumerations expose
--  the expected ordering.
package body Guikit_Suite.Input is

   use AUnit.Assertions;
   use Guikit.Input;

   type Input_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Input_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Input_Test_Case);

   procedure Test_No_Modifiers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Modifier_Set_Roundtrip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Enumerations (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Input_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit input value types");
   end Name;

   overriding procedure Register_Tests (T : in out Input_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_No_Modifiers'Access, "No_Modifiers holds no modifier keys");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Modifier_Set_Roundtrip'Access, "setting one modifier reads back without touching the rest");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Enumerations'Access, "key and navigation enumerations expose the expected ordering");
   end Register_Tests;

   procedure Test_No_Modifiers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for Key in Modifier_Key loop
         Assert (not No_Modifiers (Key), "No_Modifiers has no modifier held");
      end loop;
   end Test_No_Modifiers;

   procedure Test_Modifier_Set_Roundtrip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Modifiers : Modifier_Set := No_Modifiers;
   begin
      Modifiers (Control_Key) := True;
      Assert (Modifiers (Control_Key), "the set control modifier reads back as held");
      Assert (not Modifiers (Shift_Key), "the shift modifier stays unheld");
      Assert (not Modifiers (Alt_Key), "the alt modifier stays unheld");
      Assert (not Modifiers (Meta_Key), "the meta modifier stays unheld");

      Modifiers (Shift_Key) := True;
      Assert (Modifiers (Shift_Key) and then Modifiers (Control_Key),
              "a second modifier can be held alongside the first");
   end Test_Modifier_Set_Roundtrip;

   procedure Test_Enumerations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Navigation_Direction'First = Move_Left, "Move_Left is the first navigation direction");
      Assert (Navigation_Direction'Last = Move_Down, "Move_Down is the last navigation direction");
      Assert (Key_Code'First = Key_Unknown, "Key_Unknown is the first key code");
      Assert (Modifier_Key'Pos (Shift_Key) < Modifier_Key'Pos (Control_Key),
              "the shift modifier precedes the control modifier");
      Assert (Key_Code'Pos (Key_Return) /= Key_Code'Pos (Key_Escape),
              "distinct keys have distinct positions");
   end Test_Enumerations;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Input_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Input;
