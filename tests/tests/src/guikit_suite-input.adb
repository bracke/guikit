with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Interfaces.C.Strings;

with Glfw.Input.Keys.Codes;
with Glfw.Input.Keys.Layout;
with Glfw.Windows.Drop.Paths;
with Guikit.Errors;
with Guikit.Input;
with Guikit.Input.Mouse_Buttons;

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
   procedure Test_Layout_Letters (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Glfw_Codes (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Collect (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Error_Reporter (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Mouse_Debounce (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Mouse_Queue_Order (T : in out AUnit.Test_Cases.Test_Case'Class);

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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Layout_Letters'Access, "a layout's letter names its key; other names keep the pressed key");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Glfw_Codes'Access, "GLFW keys and modifiers map to guikit's, the + and - families included");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Collect'Access, "a drop's paths are kept in order, nulls left out, up to the limit");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Error_Reporter'Access, "a noted exception reaches the application's reporter, and never raises");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Mouse_Debounce'Access,
         "mouse changes queue in order; a bounce press withdraws its held-back release");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Mouse_Queue_Order'Access,
         "mouse changes keep their order, place and modifiers; bounces are dropped; the queue is bounded");
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
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Input_Test_Case));
      return Result;
   end Suite;

   --  QWERTZ: the key GLFW calls Y is named "z" there, so Ctrl+Z is Undo.
   procedure Test_Layout_Letters (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Glfw.Input.Keys;
      function Named (Name : String; Pressed : Key) return Key renames Glfw.Input.Keys.Layout.Letter_Named;
   begin
      Assert (Named ("z", Y) = Z and then Named ("Z", Y) = Z, "the layout's z is Z, either case");
      Assert (Named ("a", Q) = A, "a is A");
      Assert (Named ("1", Key_1) = Key_1, "a digit keeps the pressed key");
      Assert (Named ("", Y) = Y, "no name keeps it");
      Assert (Named ("ab", Y) = Y, "a longer name keeps it");
      Assert (Named ("-", Minus) = Minus, "a sign keeps it");
      Assert (Named (Character'Val (16#C3#) & Character'Val (16#BC#), Semicolon) = Semicolon,
              "a letter outside ASCII (u-umlaut) keeps it");
   end Test_Layout_Letters;

   procedure Test_Glfw_Codes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Codes renames Glfw.Input.Keys.Codes;
      Mods : Glfw.Input.Keys.Modifiers := (others => False);
   begin
      Assert (Codes.To_Key_Code (Glfw.Input.Keys.A) = Key_A, "a letter is its letter");
      Assert (Codes.To_Key_Code (Glfw.Input.Keys.Numpad_Enter) = Key_Return, "both Enter keys are Return");
      Assert (Codes.To_Key_Code (Glfw.Input.Keys.Right_Bracket) = Key_Equal, "] is in the + family (German +)");
      Assert (Codes.To_Key_Code (Glfw.Input.Keys.Numpad_Add) = Key_Equal, "so is the numpad +");
      Assert (Codes.To_Key_Code (Glfw.Input.Keys.Slash) = Key_Minus, "/ is in the - family (German -)");
      Assert (Codes.To_Key_Code (Glfw.Input.Keys.Caps_Lock) = Key_Unknown, "a key guikit does not name is unknown");
      Assert (Codes.To_Modifiers (Mods) = No_Modifiers, "no modifiers held");
      Mods.Super := True;
      Mods.Shift := True;
      Assert (Codes.To_Modifiers (Mods) (Meta_Key) and then Codes.To_Modifiers (Mods) (Shift_Key)
              and then not Codes.To_Modifiers (Mods) (Control_Key),
              "Super is Meta, and each modifier reads back alone");
   end Test_Glfw_Codes;

   procedure Test_Drop_Collect (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Interfaces.C.Strings;
      use type Interfaces.C.size_t;
      Raw : chars_ptr_array := [New_String ("/a"), Null_Ptr, New_String ("/b"), New_String ("/c")];

      --  The drop callback reads GLFW's array the same way: entry by entry.
      function Entry_At (Index : Positive) return chars_ptr is (Raw (Raw'First + Interfaces.C.size_t (Index - 1)));

      All_Kept : constant Glfw.Windows.Drop.Paths.Path_Vectors.Vector :=
        Glfw.Windows.Drop.Paths.Collect (Raw'Length, Entry_At'Access, 10);
      Two      : constant Glfw.Windows.Drop.Paths.Path_Vectors.Vector :=
        Glfw.Windows.Drop.Paths.Collect (Raw'Length, Entry_At'Access, 2);
      None     : constant Glfw.Windows.Drop.Paths.Path_Vectors.Vector :=
        Glfw.Windows.Drop.Paths.Collect (0, Entry_At'Access, 10);
   begin
      Assert (Natural (All_Kept.Length) = 3 and then All_Kept (1) = "/a" and then All_Kept (3) = "/c",
              "every path, in order, the null left out");
      Assert (Natural (Two.Length) = 2 and then Two (2) = "/b", "no more than the limit");
      Assert (None.Is_Empty, "an empty drop has no paths");
      for Item of Raw loop
         Free (Item);
      end loop;
   end Test_Drop_Collect;

   Reported : Ada.Strings.Unbounded.Unbounded_String;

   procedure Record_Report (Occurrence : Ada.Exceptions.Exception_Occurrence; Where : String) is
   begin
      Reported := Ada.Strings.Unbounded.To_Unbounded_String
        (Where & ":" & Ada.Exceptions.Exception_Name (Occurrence));
   end Record_Report;

   procedure Fail_Report (Occurrence : Ada.Exceptions.Exception_Occurrence; Where : String) is
   begin
      raise Program_Error with Where & Ada.Exceptions.Exception_Name (Occurrence);
   end Fail_Report;

   procedure Test_Error_Reporter (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Strings.Unbounded.Unbounded_String;
   begin
      Reported := Ada.Strings.Unbounded.Null_Unbounded_String;
      begin
         raise Constraint_Error;
      exception
         when Error : Constraint_Error =>
            Guikit.Errors.Note (Error, "Before");
            Guikit.Errors.Set_Reporter (Record_Report'Access);
            Guikit.Errors.Note (Error, "Guikit.Test");
            Assert (Reported = "Guikit.Test:CONSTRAINT_ERROR", "the reporter is told what and where");
            Guikit.Errors.Set_Reporter (Fail_Report'Access);
            Guikit.Errors.Note (Error, "Guikit.Test");
            Guikit.Errors.Set_Reporter (null);
            Reported := Ada.Strings.Unbounded.Null_Unbounded_String;
            Guikit.Errors.Note (Error, "After");
            Assert (Reported = "", "without a reporter nothing is told");
      end;
   end Test_Error_Reporter;

   procedure Test_Mouse_Debounce (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package MB renames Guikit.Input.Mouse_Buttons;
      use type Ada.Real_Time.Time;
      use type Ada.Real_Time.Time_Span;
      use type MB.Button_Kind;
      Queue   : MB.Button_Event_Vectors.Vector;
      Last    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Start   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Bounced : Boolean;
      Taken   : Boolean;
      Drained : MB.Button_Event;

      function Millis (Count : Natural) return Ada.Real_Time.Time is (Start + Ada.Real_Time.Milliseconds (Count));

      function Change (Button : MB.Button_Kind; Pressed : Boolean; At_Millis : Natural) return MB.Button_Event is
        (Button => Button, Pressed => Pressed, X => 5.0, Y => 5.0, Modifiers => No_Modifiers, Dragged => False,
         At_Time => Millis (At_Millis));
   begin
      Assert (MB.Left_Press_Debounce < MB.Double_Click_Interval, "the debounce never swallows a double click");
      MB.Queue_Event (Queue, Last, Change (MB.Left_Mouse_Button, True, 0), Bounced);
      Assert (not Bounced, "a first press is no bounce");
      MB.Next_Ready (Queue, Millis (1), Drained, Taken);
      Assert (Taken and then Drained.Pressed, "a press drains at once");

      MB.Queue_Event (Queue, Last, Change (MB.Left_Mouse_Button, False, 5), Bounced);
      MB.Next_Ready (Queue, Millis (6), Drained, Taken);
      Assert (not Taken, "a release inside its debounce window is held back");
      MB.Queue_Event (Queue, Last, Change (MB.Left_Mouse_Button, True, 10), Bounced);
      Assert (Bounced and then Queue.Is_Empty, "a bounce press withdraws the held-back release with itself");

      MB.Queue_Event (Queue, Last, Change (MB.Left_Mouse_Button, False, 500), Bounced);
      MB.Queue_Event (Queue, Last, Change (MB.Right_Mouse_Button, True, 510), Bounced);
      MB.Next_Ready (Queue, Millis (500) + MB.Left_Press_Debounce, Drained, Taken);
      Assert (Taken and then Drained.Button = MB.Left_Mouse_Button, "an old enough release drains first");
      MB.Next_Ready (Queue, Millis (600), Drained, Taken);
      Assert (Taken and then Drained.Button = MB.Right_Mouse_Button, "the change after it follows, in order");
      Assert (MB.Ready_At (Queue) = Ada.Real_Time.Time_Last, "an empty queue never wakes the loop");
   end Test_Mouse_Debounce;

   --  Mouse button changes wait in arrival order, each with where it happened
   --  and the modifiers held then; a bounce's press is dropped together with
   --  its release, so a held drag is not ended by it; and no more than
   --  Max_Pending_Events wait.
   procedure Test_Mouse_Queue_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package MB renames Guikit.Input.Mouse_Buttons;
      use type Ada.Real_Time.Time;
      --  Glfw.Input.Mouse.Coordinate, named by its type: this suite's project
      --  imports guikit, not the GLFW binding that declares the subtype.
      subtype Coordinate is Interfaces.C.double;
      use type Interfaces.C.double;
      use type MB.Button_Kind;
      Queue   : MB.Button_Event_Vectors.Vector;
      Last    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Start   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Bounced : Boolean;
      Ctrl    : Modifier_Set := No_Modifiers;

      function Millis (Count : Natural) return Ada.Real_Time.Time is (Start + Ada.Real_Time.Milliseconds (Count));

      function Event
        (Button    : MB.Button_Kind;
         Pressed   : Boolean;
         X         : Coordinate;
         At_Millis : Natural;
         Modifiers : Modifier_Set := No_Modifiers)
         return MB.Button_Event is
        (Button => Button, Pressed => Pressed, X => X, Y => X + 1.0, Modifiers => Modifiers, Dragged => False,
         At_Time => Millis (At_Millis));
   begin
      Ctrl (Control_Key) := True;
      MB.Queue_Event (Queue, Last, Event (MB.Left_Mouse_Button, True, 10.0, 0, Ctrl), Bounced);
      Assert (not Bounced, "a first press is no bounce");
      MB.Queue_Event (Queue, Last, Event (MB.Left_Mouse_Button, False, 10.0, 100), Bounced);
      MB.Queue_Event (Queue, Last, Event (MB.Right_Mouse_Button, True, 20.0, 200), Bounced);
      MB.Queue_Event (Queue, Last, Event (MB.Left_Mouse_Button, True, 30.0, 300), Bounced);
      Assert (not Bounced, "a press well after the last one is no bounce");

      Assert (Natural (Queue.Length) = 4, "every change waits");
      Assert (Queue (1).Button = MB.Left_Mouse_Button and then Queue (1).Pressed and then Queue (1).X = 10.0,
              "the first press comes first, where it went down");
      Assert (Queue (1).Modifiers (Control_Key), "a press keeps the modifiers held when it happened");
      Assert (Queue (2).Button = MB.Left_Mouse_Button and then not Queue (2).Pressed,
              "its release follows it");
      Assert (Queue (3).Button = MB.Right_Mouse_Button and then Queue (3).X = 20.0
              and then not Queue (3).Modifiers (Control_Key),
              "a right click keeps its place between the left clicks, with its own modifiers");
      Assert (Queue (4).X = 30.0 and then Queue (4).Y = 31.0, "the second left press keeps its own position");

      --  A switch bounce: release and press again within the debounce window.
      MB.Queue_Event (Queue, Last, Event (MB.Left_Mouse_Button, False, 30.0, 305), Bounced);
      MB.Queue_Event (Queue, Last, Event (MB.Left_Mouse_Button, True, 30.0, 310), Bounced);
      Assert (Bounced, "a press within the debounce window is a bounce");
      Assert (Natural (Queue.Length) = 4, "the bounce's press and its release are both dropped");
      Assert (Queue.Last_Element.Pressed, "the held press stays the last change");

      --  A bounce with no release waiting withdraws nothing else.
      MB.Queue_Event (Queue, Last, Event (MB.Left_Mouse_Button, True, 30.0, 320), Bounced);
      Assert (Bounced and then Natural (Queue.Length) = 4, "a bounce never withdraws a press");

      Queue.Clear;
      for Index in 1 .. MB.Max_Pending_Events + 4 loop
         MB.Queue_Event (Queue, Last, Event (MB.Right_Mouse_Button, True, Coordinate (Index), 1_000),
                         Bounced);
      end loop;
      Assert (Natural (Queue.Length) = MB.Max_Pending_Events, "the queue is bounded");
      Assert (Queue (1).X = 1.0 and then Queue.Last_Element.X = Coordinate (MB.Max_Pending_Events),
              "the oldest changes are the ones kept; later ones are dropped");
   end Test_Mouse_Queue_Order;

end Guikit_Suite.Input;
