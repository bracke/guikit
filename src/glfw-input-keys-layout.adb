with Interfaces.C.Strings;

package body Glfw.Input.Keys.Layout is

   function Get_Key_Name
     (Key_Value : Interfaces.C.int; Scancode_Value : Interfaces.C.int)
      return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "glfwGetKeyName";

   function Layout_Key (Pressed : Key; Code : Scancode) return Key is
      use type Interfaces.C.Strings.chars_ptr;
      Name : Interfaces.C.Strings.chars_ptr;
   begin
      if Pressed = Unknown then
         return Pressed;
      end if;
      Name := Get_Key_Name (Interfaces.C.int (Key'Enum_Rep (Pressed)), Interfaces.C.int (Code));
      if Name = Interfaces.C.Strings.Null_Ptr then
         return Pressed;
      end if;
      return Letter_Named (Interfaces.C.Strings.Value (Name), Otherwise => Pressed);
   end Layout_Key;

end Glfw.Input.Keys.Layout;
