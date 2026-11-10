--  The key a press means under the active keyboard layout.
package Glfw.Input.Keys.Layout is

   --  GLFW names keys by their place on a US keyboard, so on QWERTZ the key
   --  labelled Z arrives as Y, and Ctrl+Z ran Redo. A printable key whose
   --  layout character is a letter is taken as that letter; every other key
   --  keeps its place (digits and punctuation keep place-based bindings,
   --  such as zoom keys).
   --
   --  @param Pressed The key GLFW reports.
   --  @param Code The press's scancode.
   --  @return The letter key the layout puts there, or Pressed.
   function Layout_Key (Pressed : Key; Code : Scancode) return Key;

end Glfw.Input.Keys.Layout;
