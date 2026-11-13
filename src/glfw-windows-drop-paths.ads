with Ada.Containers.Indefinite_Vectors;
with Ada.Exceptions;
with Interfaces.C.Strings;

--  Dropped paths for an app's windows, as Ada strings: the C callback, its
--  path array and the window it fired for are handled here once for every
--  app. A window watched for drops hands what is dropped on it to its
--  Receiver.
package Glfw.Windows.Drop.Paths is

   package Path_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   --  What a window does with the paths dropped on it.
   type Receiver is limited interface;

   --  Called on the thread that polls GLFW's events, in the order dropped.
   --  An exception here goes to Failed: it must not unwind into C.
   --
   --  @param Into The receiver Watch was given.
   --  @param Dropped The paths, at most Watch's Limit of them.
   procedure Receive (Into : in out Receiver; Dropped : Path_Vectors.Vector) is abstract;

   --  Told of a drop that failed, in Receive or in reading the paths, so the
   --  app can record it; the drop itself is lost. The default ignores it.
   --
   --  @param Into The receiver of the window the drop was for.
   --  @param Occurrence What was raised.
   procedure Failed (Into : in out Receiver; Occurrence : Ada.Exceptions.Exception_Occurrence) is null;

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

   --  The paths a C array holds, by the rule Receive is given them by: at
   --  most Limit, in order, null entries left out. The drop callback applies
   --  the same rule reading GLFW's array in place, without copying it.
   --
   --  @param Raw The array GLFW passes, as many entries as it says.
   --  @param Limit The most paths to keep.
   --  @return The paths.
   function Collect
     (Raw   : Interfaces.C.Strings.chars_ptr_array;
      Limit : Positive)
      return Path_Vectors.Vector;

   --  Stop watching Window (before it is destroyed).
   --
   --  @param Window A watched window; others are ignored.
   procedure Forget (Window : not null access Glfw.Windows.Window);

end Glfw.Windows.Drop.Paths;
