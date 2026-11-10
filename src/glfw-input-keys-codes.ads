with Guikit.Input;

--  GLFW's keys and modifiers as guikit's own input types, so an application
--  dispatches on Guikit.Input and keeps no GLFW table of its own.
package Glfw.Input.Keys.Codes is

   --  The key code a GLFW key stands for. The '+' family (=, ] and numpad +)
   --  is Key_Equal and the '-' family (-, / and numpad -) Key_Minus, so
   --  Ctrl+plus and Ctrl+minus zoom on layouts (German) that put + and - on
   --  the ] and / keys; both Enter keys are Key_Return.
   --
   --  @param Pressed The key GLFW reports (after Layout.Layout_Key, if used).
   --  @return Its key code, or Key_Unknown for a key guikit does not name.
   function To_Key_Code (Pressed : Key) return Guikit.Input.Key_Code;

   --  The modifiers GLFW reports with a key event.
   --
   --  @param Mods The event's modifier record.
   --  @return Shift, Control, Alt and Super (as Meta) held.
   function To_Modifiers (Mods : Modifiers) return Guikit.Input.Modifier_Set;

end Glfw.Input.Keys.Codes;
