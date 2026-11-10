with Ada.Containers.Indefinite_Vectors;

--  Dropped paths for an app's windows, as Ada strings: the C callback, its
--  path array and the window it fired for are handled here once for every
--  app. A window watched for drops hands what is dropped on it to its
--  Receiver.
package Glfw.Windows.Drop.Paths is

   package Path_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   --  What a window does with the paths dropped on it.
   type Receiver is limited interface;

   --  Called on the thread that polls GLFW's events, in the order dropped.
   --  An exception here is swallowed (it must not unwind into C).
   --
   --  @param Into The receiver Watch was given.
   --  @param Dropped The paths, at most Watch's Limit of them.
   procedure Receive (Into : in out Receiver; Dropped : Path_Vectors.Vector) is abstract;

   --  Hand what is dropped on Window to Into from now on.
   --
   --  @param Window Window to watch.
   --  @param Into Its receiver; it must outlive the watch (Forget first).
   --  @param Limit The most paths handed over for one drop; pass one more
   --    than a caller accepts to let it tell an oversized drop apart.
   procedure Watch
     (Window : not null access Glfw.Windows.Window;
      Into   : not null access Receiver'Class;
      Limit  : Positive);

   --  Stop watching Window (before it is destroyed).
   --
   --  @param Window A watched window; others are ignored.
   procedure Forget (Window : not null access Glfw.Windows.Window);

end Glfw.Windows.Drop.Paths;
