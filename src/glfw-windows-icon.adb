with Interfaces.C;
with System;

package body Glfw.Windows.Icon is
   type GLFW_Image is record
      Width  : Interfaces.C.int;
      Height : Interfaces.C.int;
      Pixels : System.Address;
   end record
   with Convention => C;

   type GLFW_Image_Array is array (Positive range <>) of GLFW_Image
   with Convention => C;

   procedure Raw_Set_Window_Icon
     (Window : System.Address;
      Count  : Interfaces.C.int;
      Images : System.Address)
   with Import, Convention => C, External_Name => "glfwSetWindowIcon";

   procedure Set_Icon
     (Window : not null access Glfw.Windows.Window;
      Pixels : RGBA_Pixels;
      Width  : Positive;
      Height : Positive)
   is
      Images : aliased GLFW_Image_Array (1 .. 1);
   begin
      --  GLFW copies the pixels before it returns.
      Images (1) :=
        (Width  => Interfaces.C.int (Width),
         Height => Interfaces.C.int (Height),
         Pixels => Pixels (Pixels'First)'Address);
      Raw_Set_Window_Icon (Window.Handle, 1, Images'Address);
   end Set_Icon;

end Glfw.Windows.Icon;
