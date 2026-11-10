with Glfw.Input.Keys;

package body Glfw.Windows.Modifiers is

   function Held (Window : not null access Glfw.Windows.Window) return Guikit.Input.Modifier_Set is
      use type Glfw.Input.Button_State;
      function Down (Key : Glfw.Input.Keys.Key) return Boolean is
        (Glfw.Windows.Key_State (Window, Key) = Glfw.Input.Pressed);
   begin
      return
        [Guikit.Input.Shift_Key   => Down (Glfw.Input.Keys.Left_Shift) or else Down (Glfw.Input.Keys.Right_Shift),
         Guikit.Input.Control_Key =>
           Down (Glfw.Input.Keys.Left_Control) or else Down (Glfw.Input.Keys.Right_Control),
         Guikit.Input.Alt_Key     => Down (Glfw.Input.Keys.Left_Alt) or else Down (Glfw.Input.Keys.Right_Alt),
         Guikit.Input.Meta_Key    => Down (Glfw.Input.Keys.Left_Super) or else Down (Glfw.Input.Keys.Right_Super)];
   end Held;

end Glfw.Windows.Modifiers;
