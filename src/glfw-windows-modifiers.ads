with Guikit.Input;

--  The modifier keys a window sees held now.
package Glfw.Windows.Modifiers is

   --  Shift, Control, Alt and Super (Meta), each held on either side.
   --
   --  @param Window GLFW window to ask about.
   --  @return The modifiers held now.
   function Held (Window : not null access Glfw.Windows.Window) return Guikit.Input.Modifier_Set;

end Glfw.Windows.Modifiers;
