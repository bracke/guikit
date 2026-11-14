private with Ada.Containers.Vectors;
private with Ada.Real_Time;

with Glfw.Input.Keys;
with Glfw.Input.Mouse;
with Glfw.Windows;

--  A GLFW window that keeps its input for the main loop: every character,
--  key, mouse button and wheel step its callbacks are given goes into one
--  queue, in the order it arrived, and the loop takes it from there once per
--  frame. The pointer's position is kept as its latest value, and Dirty says
--  whether anything arrived since the last frame was drawn.
--
--  One queue rather than a field per kind, so the order survives: typing "ab",
--  Backspace, "c" is "ac" only if the Backspace is handled between "b" and
--  "c". Counters for each key, and one string of typed text, handled all the
--  text first.
--
--  openglada calls these overrides straight from GLFW's C callbacks, and
--  an exception that leaves one would unwind through C, which no Ada
--  handler can catch past. Every override here therefore ends in a handler
--  that tells Guikit.Errors (Note) and returns: the event is lost, the
--  program is not. A window type that extends this one and overrides a
--  callback again needs the same guard.
package Guikit.Input.Pending is

   --  What an event is.
   type Event_Kind is
     (Character_Input,
      --  A key was pressed or auto-repeated (releases are not queued).
      Key_Input,
      --  A mouse button went down or up.
      Button_Input,
      --  The wheel (or a touchpad) moved by whole notches.
      Scroll_Input);

   --  One input event. Only the fields of its Kind mean anything.
   type Event is record
      Kind      : Event_Kind := Character_Input;
      --  Character_Input: the code point typed. Control characters (below
      --  U+0020, and U+007F) are not queued: a text field takes them as keys.
      Code      : Natural := 0;
      --  Key_Input: the key, and whether this is an auto-repeat.
      Key       : Glfw.Input.Keys.Key := Glfw.Input.Keys.Unknown;
      Repeat    : Boolean := False;
      --  Key_Input and Button_Input: the modifiers held when it happened.
      Modifiers : Glfw.Input.Keys.Modifiers := (others => False);
      --  Button_Input: which button, whether it went down, and where the
      --  pointer was, in window coordinates.
      Button    : Glfw.Input.Mouse.Button := Glfw.Input.Mouse.Left_Button;
      Pressed   : Boolean := False;
      X         : Glfw.Input.Mouse.Coordinate := 0.0;
      Y         : Glfw.Input.Mouse.Coordinate := 0.0;
      --  Scroll_Input: whole notches, positive away from the user (wheel up).
      Notches   : Integer := 0;
   end record;

   --  How many events wait at most; later ones are dropped until the loop
   --  takes some. A frame takes them all, so only a stalled loop meets this.
   Max_Pending_Events : constant := 256;

   --  The window. Use it as it is, or extend it with an application's own
   --  state.
   type Pending_Window is new Glfw.Windows.Window with private;

   --  Take the oldest event waiting.
   --
   --  @param Object The window.
   --  @param Item The event, when Taken.
   --  @param Taken False when nothing waits.
   procedure Take (Object : in out Pending_Window; Item : out Event; Taken : out Boolean);

   --  Whether events wait.
   --
   --  @param Object The window.
   --  @return True when Take would take one.
   function Has_Events (Object : Pending_Window) return Boolean;

   --  The pointer's latest position, in window coordinates; -1 before it has
   --  been over the window.
   --
   --  @param Object The window.
   --  @return Its X, truncated to a whole pixel.
   function Mouse_X (Object : Pending_Window) return Integer;

   --  @param Object The window.
   --  @return The pointer's latest Y, as Mouse_X.
   function Mouse_Y (Object : Pending_Window) return Integer;

   --  Whether anything arrived -- an event, a pointer move -- since Clear_Dirty,
   --  or Mark_Dirty was called. True for a new window, so its first frame draws.
   --
   --  @param Object The window.
   --  @return True when the loop should draw again.
   function Dirty (Object : Pending_Window) return Boolean;

   --  Say the window's frame is drawn.
   --
   --  @param Object The window.
   procedure Clear_Dirty (Object : in out Pending_Window);

   --  Ask for another frame, for a change that did not come through input (a
   --  resize, a finished search).
   --
   --  @param Object The window.
   procedure Mark_Dirty (Object : in out Pending_Window);

   overriding procedure Character_Entered
     (Object : not null access Pending_Window;
      Char   : Wide_Wide_Character);

   overriding procedure Key_Changed
     (Object   : not null access Pending_Window;
      Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode;
      Action   : Glfw.Input.Keys.Action;
      Mods     : Glfw.Input.Keys.Modifiers);

   --  A left press within Guikit.Input.Mouse_Buttons.Left_Press_Debounce of
   --  the last one queued is a switch bounce: it is dropped, and so is the
   --  release that ends it.
   overriding procedure Mouse_Button_Changed
     (Object : not null access Pending_Window;
      Button : Glfw.Input.Mouse.Button;
      State  : Glfw.Input.Button_State;
      Mods   : Glfw.Input.Keys.Modifiers);

   overriding procedure Mouse_Position_Changed
     (Object : not null access Pending_Window;
      X, Y   : Glfw.Input.Mouse.Coordinate);

   --  The vertical travel, in whole notches. A touchpad reports a swipe as
   --  many small offsets; the part not yet a whole notch is kept for the next
   --  one, so they add up rather than each truncating to nothing.
   overriding procedure Mouse_Scrolled
     (Object : not null access Pending_Window;
      X, Y   : Glfw.Input.Mouse.Scroll_Offset);

private

   package Event_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Event);

   type Pending_Window is new Glfw.Windows.Window with record
      Queue              : Event_Vectors.Vector;
      Pointer_X          : Integer := -1;
      Pointer_Y          : Integer := -1;
      Pointer_Fx         : Glfw.Input.Mouse.Coordinate := 0.0;
      Pointer_Fy         : Glfw.Input.Mouse.Coordinate := 0.0;
      Scroll_Remainder   : Float := 0.0;
      Have_Left_Press    : Boolean := False;
      Last_Left_Press    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Drop_Left_Release  : Boolean := False;
      Is_Dirty           : Boolean := True;
   end record;

end Guikit.Input.Pending;
