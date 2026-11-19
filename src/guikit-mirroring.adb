with Ada.Strings.Unbounded;

with Guikit.Bidi;
with Guikit.Utf8;

package body Guikit.Mirroring is

   use Ada.Strings.Unbounded;

   --  Where a box W wide at X starts once reflected in a frame Width wide.
   function Reflected (X, W, Width : Natural) return Natural is
     (if X >= Width then 0
      elsif W >= Width - X then 0
      else Width - X - W);

   function Reflected (X : Float; Width : Natural) return Float is (Float (Width) - X);

   procedure Mirror (Items : in out Rectangle_Command_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Item.X := Reflected (Item.X, Item.Width, Width);
      end loop;
   end Mirror;

   procedure Mirror (Items : in out Triangle_Command_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Item.X1 := Reflected (Item.X1, Width);
         Item.X2 := Reflected (Item.X2, Width);
         Item.X3 := Reflected (Item.X3, Width);
      end loop;
   end Mirror;

   --  A box holding one character with a mirror image ('>', a bracket) is
   --  a picture pointing one way, as a breadcrumb's separator is: the mirror
   --  image points the other. In running text Guikit.Bidi already mirrors
   --  what a right-to-left run holds.
   function Mirrored_Glyph (Text : UString) return UString is
      Content   : constant String := To_String (Text);
      Index     : Integer := Content'First;
      Codepoint : Natural;
   begin
      if Content'Length = 0 or else Content'Length > 4 then
         return Text;
      end if;
      Guikit.Utf8.Decode_Next_Codepoint (Content, Index, Codepoint);
      if Index <= Content'Last or else Guikit.Bidi.Mirror_Of (Codepoint) = Codepoint then
         return Text;
      end if;
      return To_Unbounded_String (Guikit.Utf8.Encode (Guikit.Bidi.Mirror_Of (Codepoint)));
   end Mirrored_Glyph;

   procedure Mirror (Items : in out Text_Command_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Item.X := Reflected (Item.X, Item.Width, Width);
         Item.Text := Mirrored_Glyph (Item.Text);
         if not Item.Scale_To_Box then
            Item.Align_End := not Item.Align_End;
         end if;
      end loop;
   end Mirror;

   procedure Mirror (Items : in out Tooltip_Command_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Item.X := Reflected (Item.X, Item.Width, Width);
      end loop;
   end Mirror;

   procedure Mirror (Items : in out Icon_Command_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Item.X := Reflected (Item.X, (if Item.Draw_Width > 0 then Item.Draw_Width else Item.Size), Width);
      end loop;
   end Mirror;

   procedure Mirror (Items : in out Accessibility_Node_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Item.X := Reflected (Item.X, Item.Width, Width);
      end loop;
   end Mirror;

   procedure Mirror (Layout : in out Layout_Metrics) is
   begin
      Layout.Main_X := Reflected (Layout.Main_X, Layout.Main_Width, Layout.Width);
      Layout.Command_X := Reflected (Layout.Command_X, Layout.Command_Width, Layout.Width);
   end Mirror;

end Guikit.Mirroring;
