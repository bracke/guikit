package body Glfw.Windows.Native is

   function Glfw_Get_Cocoa_Window (Window : System.Address) return System.Address
     with Import, Convention => C, External_Name => "glfwGetCocoaWindow";

   function Handle (Window : not null access Glfw.Windows.Window) return System.Address is
     (Glfw_Get_Cocoa_Window (Window.Handle));

end Glfw.Windows.Native;
