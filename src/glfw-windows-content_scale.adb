with Interfaces.C;
with System;

package body Glfw.Windows.Content_Scale is

   use type Interfaces.C.C_float;

   type Raw_Scale_Callback is access procedure
     (Window  : System.Address;
      X_Scale : Interfaces.C.C_float;
      Y_Scale : Interfaces.C.C_float)
   with Convention => C;

   procedure Raw_Get_Content_Scale
     (Window  : System.Address;
      X_Scale : out Interfaces.C.C_float;
      Y_Scale : out Interfaces.C.C_float)
   with Import, Convention => C, External_Name => "glfwGetWindowContentScale";

   function Raw_Set_Content_Scale_Callback
     (Window   : System.Address;
      Callback : Raw_Scale_Callback)
      return Raw_Scale_Callback
   with Import, Convention => C, External_Name => "glfwSetWindowContentScaleCallback";

   --  Written by the callback, which GLFW runs on the thread polling events,
   --  and read by the window loop.
   Change_Count : Natural := 0 with Atomic;

   procedure Scale_Changed
     (Window  : System.Address;
      X_Scale : Interfaces.C.C_float;
      Y_Scale : Interfaces.C.C_float)
   with Convention => C;

   procedure Scale_Changed
     (Window  : System.Address;
      X_Scale : Interfaces.C.C_float;
      Y_Scale : Interfaces.C.C_float)
   is
      pragma Unreferenced (Window, X_Scale, Y_Scale);
   begin
      Change_Count := (if Change_Count = Natural'Last then 0 else Change_Count + 1);
   end Scale_Changed;

   --  A scale the window system cannot give (0, negative, not a number)
   --  reads as none.
   function Usable (Value : Interfaces.C.C_float) return Float is
     (if Value >= 0.25 and then Value <= 16.0 then Float (Value) else 1.0);

   procedure Get
     (Window  : not null access Glfw.Windows.Window;
      X_Scale : out Float;
      Y_Scale : out Float)
   is
      Raw_X : Interfaces.C.C_float := 1.0;
      Raw_Y : Interfaces.C.C_float := 1.0;
   begin
      Raw_Get_Content_Scale (Window.Handle, Raw_X, Raw_Y);
      X_Scale := Usable (Raw_X);
      Y_Scale := Usable (Raw_Y);
   end Get;

   procedure Watch (Window : not null access Glfw.Windows.Window) is
      Previous : constant Raw_Scale_Callback :=
        Raw_Set_Content_Scale_Callback (Window.Handle, Scale_Changed'Access);
   begin
      pragma Unreferenced (Previous);
   end Watch;

   function Changes return Natural is (Change_Count);

end Glfw.Windows.Content_Scale;
