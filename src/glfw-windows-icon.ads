with Interfaces;

--  Native GLFW window icon helper.
package Glfw.Windows.Icon is

   --  Pixels of a square or rectangular icon, row by row from the top-left,
   --  four bytes each: red, green, blue, alpha.
   type RGBA_Pixels is array (Positive range <>) of aliased Interfaces.Unsigned_8
   with Convention => C;

   --  Set Window's icon (where the window system shows one).
   --
   --  @param Window GLFW window receiving the icon.
   --  @param Pixels The icon's pixels: Width x Height x 4 bytes.
   --  @param Width The icon's width in pixels.
   --  @param Height The icon's height in pixels.
   procedure Set_Icon
     (Window : not null access Glfw.Windows.Window;
      Pixels : RGBA_Pixels;
      Width  : Positive;
      Height : Positive)
   with Pre => Pixels'Length = Width * Height * 4;

end Glfw.Windows.Icon;
