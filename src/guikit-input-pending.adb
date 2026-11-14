with Guikit.Errors;
with Guikit.Input.Mouse_Buttons;

package body Guikit.Input.Pending is
   use type Ada.Containers.Count_Type;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Glfw.Input.Keys.Action;
   use type Glfw.Input.Mouse.Button;
   use type Glfw.Input.Button_State;

   Unit_Name : constant String := "Guikit.Input.Pending";

   --  Enqueue Item, and ask for a frame; past Max_Pending_Events it is dropped.
   procedure Enqueue (Object : in out Pending_Window'Class; Item : Event) is
   begin
      if Object.Queue.Length < Max_Pending_Events then
         Object.Queue.Append (Item);
      end if;
      Object.Is_Dirty := True;
   end Enqueue;

   procedure Take (Object : in out Pending_Window; Item : out Event; Taken : out Boolean) is
   begin
      Taken := not Object.Queue.Is_Empty;
      if Taken then
         Item := Object.Queue.First_Element;
         Object.Queue.Delete_First;
      else
         Item := (others => <>);
      end if;
   end Take;

   function Has_Events (Object : Pending_Window) return Boolean is (not Object.Queue.Is_Empty);

   function Mouse_X (Object : Pending_Window) return Integer is (Object.Pointer_X);

   function Mouse_Y (Object : Pending_Window) return Integer is (Object.Pointer_Y);

   function Dirty (Object : Pending_Window) return Boolean is (Object.Is_Dirty);

   procedure Clear_Dirty (Object : in out Pending_Window) is
   begin
      Object.Is_Dirty := False;
   end Clear_Dirty;

   procedure Mark_Dirty (Object : in out Pending_Window) is
   begin
      Object.Is_Dirty := True;
   end Mark_Dirty;

   overriding procedure Character_Entered
     (Object : not null access Pending_Window;
      Char   : Wide_Wide_Character)
   is
      Code : constant Natural := Wide_Wide_Character'Pos (Char);
   begin
      if Code >= Character'Pos (' ') and then Code /= 16#7F# then
         Enqueue (Object.all, (Kind => Character_Input, Code => Code, others => <>));
      end if;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, Unit_Name & ".Character_Entered");
   end Character_Entered;

   overriding procedure Key_Changed
     (Object   : not null access Pending_Window;
      Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode;
      Action   : Glfw.Input.Keys.Action;
      Mods     : Glfw.Input.Keys.Modifiers)
   is
      pragma Unreferenced (Scancode);
   begin
      if Action /= Glfw.Input.Keys.Release then
         Enqueue
           (Object.all,
            (Kind      => Key_Input,
             Key       => Key,
             Repeat    => Action = Glfw.Input.Keys.Repeat,
             Modifiers => Mods,
             others    => <>));
      end if;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, Unit_Name & ".Key_Changed");
   end Key_Changed;

   overriding procedure Mouse_Button_Changed
     (Object : not null access Pending_Window;
      Button : Glfw.Input.Mouse.Button;
      State  : Glfw.Input.Button_State;
      Mods   : Glfw.Input.Keys.Modifiers)
   is
      --  Everything in the handled part: an exception raised while declaring
      --  would leave the body past its handler, into C.
      Now     : Ada.Real_Time.Time;
      Pressed : Boolean;
   begin
      Now := Ada.Real_Time.Clock;
      Pressed := State = Glfw.Input.Pressed;
      if Button = Glfw.Input.Mouse.Left_Button then
         if Pressed then
            if Object.Have_Left_Press
              and then Now - Object.Last_Left_Press < Guikit.Input.Mouse_Buttons.Left_Press_Debounce
            then
               --  A bounce: neither it nor the release that ends it happened.
               Object.Drop_Left_Release := True;
               return;
            end if;
            Object.Have_Left_Press := True;
            Object.Last_Left_Press := Now;
         elsif Object.Drop_Left_Release then
            Object.Drop_Left_Release := False;
            return;
         end if;
      end if;
      Enqueue
        (Object.all,
         (Kind      => Button_Input,
          Button    => Button,
          Pressed   => Pressed,
          Modifiers => Mods,
          X         => Object.Pointer_Fx,
          Y         => Object.Pointer_Fy,
          others    => <>));
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, Unit_Name & ".Mouse_Button_Changed");
   end Mouse_Button_Changed;

   overriding procedure Mouse_Position_Changed
     (Object : not null access Pending_Window;
      X, Y   : Glfw.Input.Mouse.Coordinate) is
   begin
      Object.Pointer_Fx := X;
      Object.Pointer_Fy := Y;
      Object.Pointer_X := Integer (Glfw.Input.Mouse.Coordinate'Truncation (X));
      Object.Pointer_Y := Integer (Glfw.Input.Mouse.Coordinate'Truncation (Y));
      Object.Is_Dirty := True;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, Unit_Name & ".Mouse_Position_Changed");
   end Mouse_Position_Changed;

   overriding procedure Mouse_Scrolled
     (Object : not null access Pending_Window;
      X, Y   : Glfw.Input.Mouse.Scroll_Offset)
   is
      pragma Unreferenced (X);
   begin
      declare
         Travel  : constant Float := Object.Scroll_Remainder + Float (Y);
         --  Whole notches, toward zero, so the remainder keeps the travel's sign.
         Notches : constant Integer := Integer (Float'Truncation (Travel));
      begin
         Object.Scroll_Remainder := Travel - Float (Notches);
         if Notches /= 0 then
            Enqueue (Object.all, (Kind => Scroll_Input, Notches => Notches, others => <>));
         end if;
      end;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, Unit_Name & ".Mouse_Scrolled");
   end Mouse_Scrolled;

end Guikit.Input.Pending;
