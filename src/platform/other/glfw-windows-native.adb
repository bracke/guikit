package body Glfw.Windows.Native is

   function Handle (Window : not null access Glfw.Windows.Window) return System.Address is
      pragma Unreferenced (Window);
   begin
      return System.Null_Address;
   end Handle;

end Glfw.Windows.Native;
