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

   --  The letter key a layout's name for a key means: the name of one ASCII
   --  letter, either case, is that letter; any other name (a digit, a sign,
   --  a longer name, none) leaves the key as it was.
   --
   --  @param Name What the layout calls the key.
   --  @param Otherwise The key to keep when Name is not a letter.
   --  @return The letter key, or Otherwise.
   function Letter_Named (Name : String; Otherwise : Key) return Key is
     (if Name'Length = 1 and then Name (Name'First) in 'a' .. 'z'
      then Key'Val (Key'Pos (A) + Character'Pos (Name (Name'First)) - Character'Pos ('a'))
      elsif Name'Length = 1 and then Name (Name'First) in 'A' .. 'Z'
      then Key'Val (Key'Pos (A) + Character'Pos (Name (Name'First)) - Character'Pos ('A'))
      else Otherwise);

end Glfw.Input.Keys.Layout;
