with System;

--  The window system's own handle for a GLFW window, for a library that must
--  talk to the window system about it directly (a screen-reader provider
--  answering through the application's window).
package Glfw.Windows.Native is

   --  The HWND on Windows, the NSWindow on macOS; null where the window
   --  system needs no handle for that (X11 and Wayland reach the screen
   --  reader over the accessibility bus).
   function Handle (Window : not null access Glfw.Windows.Window) return System.Address;

end Glfw.Windows.Native;
