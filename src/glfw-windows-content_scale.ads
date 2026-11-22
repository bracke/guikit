--  The window system's content scale for a GLFW window: how much larger
--  than its nominal size the desktop asks content to be drawn (a display
--  set to 150% on Windows or X11, where the framebuffer is not enlarged).
package Glfw.Windows.Content_Scale is

   --  The window's content scale, 1.0 on each axis where the window system
   --  reports none.
   --
   --  @param Window GLFW window whose scale is wanted.
   --  @param X_Scale Horizontal scale.
   --  @param Y_Scale Vertical scale.
   procedure Get
     (Window  : not null access Glfw.Windows.Window;
      X_Scale : out Float;
      Y_Scale : out Float);

   --  Count the window's content-scale changes (moved to a display with
   --  another scale, the desktop's scale changed) from now on.
   --
   --  @param Window GLFW window to watch.
   procedure Watch (Window : not null access Glfw.Windows.Window);

   --  How many content-scale changes any watched window has reported; it
   --  moves when a scale is worth reading again.
   --
   --  @return The count, wrapping at Natural'Last.
   function Changes return Natural;

end Glfw.Windows.Content_Scale;
