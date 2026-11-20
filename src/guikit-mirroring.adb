with Ada.Strings.Unbounded;

with Guikit.Bidi;
with Guikit.Utf8;

package body Guikit.Mirroring is

   use Ada.Strings.Unbounded;

   Mirrored : Boolean := False
     with Atomic;

   procedure Set_Mirrored_Layout (On : Boolean) is
   begin
      Mirrored := On;
   end Set_Mirrored_Layout;

   function Mirrored_Layout return Boolean is (Mirrored);

   --  Where a box W wide at X starts once reflected in a frame Width wide;
   --  a box sticking out past the frame's right edge stops at its left edge.
   function Reflected (X, W, Width : Natural) return Natural is
     (if X >= Width then 0
      elsif W >= Width - X then 0
      else Width - X - W);

   --  Reflect the visible part of a box W wide at X in a frame Width wide:
   --  W shrinks to what lies inside the frame (0 for a box wholly past it).
   procedure Reflect (X, W : in out Natural; Width : Natural) is
      Visible : constant Natural := (if X >= Width then 0 else Natural'Min (W, Width - X));
   begin
      X := Reflected (X, Visible, Width);
      W := Visible;
   end Reflect;

   function Reflected (X : Float; Width : Natural) return Float is (Float (Width) - X);

   procedure Mirror (Items : in out Rectangle_Command_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Reflect (Item.X, Item.Width, Width);
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

   --  A symbol (Text_Command.Mirror_Glyph) of one character with a mirror
   --  image ('>', a bracket) is a picture pointing one way, as a
   --  breadcrumb's separator is: the mirror image points the other. Other
   --  text keeps its characters -- a query of just '>' is still '>' -- and
   --  in running text Guikit.Bidi already mirrors what a right-to-left run
   --  holds.
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
         Reflect (Item.X, Item.Width, Width);
         if Item.Width = 0 then
            --  Wholly past the frame: nothing of it shows, mirrored or not.
            Item.Text := Null_Unbounded_String;
         elsif Item.Mirror_Glyph then
            Item.Text := Mirrored_Glyph (Item.Text);
         end if;
         if not Item.Scale_To_Box then
            Item.Align_End := not Item.Align_End;
         end if;
      end loop;
   end Mirror;

   procedure Mirror (Items : in out Tooltip_Command_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Reflect (Item.X, Item.Width, Width);
      end loop;
   end Mirror;

   procedure Mirror (Items : in out Icon_Command_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         declare
            Drawn : constant Natural := (if Item.Draw_Width > 0 then Item.Draw_Width else Item.Size);
         begin
            if Item.X >= Width or else Drawn > Width - Item.X then
               --  Wholly past the frame, or sticking out past its right edge:
               --  reflected, it would start left of the frame, which no X
               --  says, and an icon is not cut. It is left unseen rather than
               --  drawn whole at the left edge, shifted from where it belongs.
               Item.X := 0;
               Item.Size := 0;
               Item.Draw_Width := 0;
               Item.Draw_Height := 0;
            else
               Item.X := Width - Item.X - Drawn;
            end if;
         end;
      end loop;
   end Mirror;

   procedure Mirror (Items : in out Accessibility_Node_Vectors.Vector; Width : Natural) is
   begin
      for Item of Items loop
         Reflect (Item.X, Item.Width, Width);
      end loop;
   end Mirror;

   procedure Mirror (Layout : in out Layout_Metrics) is
   begin
      Layout.Main_X := Reflected (Layout.Main_X, Layout.Main_Width, Layout.Width);
      Layout.Command_X := Reflected (Layout.Command_X, Layout.Command_Width, Layout.Width);
   end Mirror;

end Guikit.Mirroring;
