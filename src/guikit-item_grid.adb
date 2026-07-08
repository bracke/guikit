with Guikit.Layout;

package body Guikit.Item_Grid is

   --  Cell padding constants (pixels), matching the file-manager grid metrics.
   Item_Content_Padding : constant Natural := 4;
   Details_Row_Padding  : constant Natural := 4;
   Details_Row_Gap      : constant Natural := 0;

   function Cell_Metrics_For
     (View        : View_Kind;
      Main_Width  : Natural;
      Line_Height : Positive)
      return Cell_Metrics
   is
      function Mul (Value, Factor : Natural) return Natural renames Guikit.Layout.Saturating_Multiply;
      function Add (Left, Right : Natural) return Natural renames Guikit.Layout.Saturating_Add;
   begin
      case View is
         when Icons_Small =>
            return
              (Width     => 216,
               Height    => Add (Line_Height, Mul (Item_Content_Padding, 2)),
               Icon_Size => Line_Height,
               Large     => False);
         when Icons_Large =>
            return
              (Width     => Mul (Line_Height, 7),
               Height    => Mul (Line_Height, 5),
               Icon_Size => Mul (Line_Height, 3),
               Large     => True);
         when Details =>
            return
              (Width     => Main_Width,
               Height    => Add (Add (Line_Height, Mul (Details_Row_Padding, 2)), Details_Row_Gap),
               Icon_Size => Line_Height,
               Large     => False);
      end case;
   end Cell_Metrics_For;

   --  Whether point (Px, Py) lies inside the half-open rectangle
   --  [X, X + W) x [Y, Y + H).
   function Contains_Point (X, Y, W, H, Px, Py : Natural) return Boolean is
     (W > 0 and then H > 0
      and then Px >= X and then Px < X + W
      and then Py >= Y and then Py < Y + H);

   function Item_At
     (Items : Item_Layout_Vectors.Vector;
      X     : Natural;
      Y     : Natural)
      return Natural is
   begin
      for Item of Items loop
         if Contains_Point (Item.X, Item.Y, Item.Width, Item.Height, X, Y) then
            return Item.Visible_Index;
         end if;
      end loop;
      return 0;
   end Item_At;

   procedure Marquee_Rect
     (Start_X   : Natural;
      Start_Y   : Natural;
      Current_X : Natural;
      Current_Y : Natural;
      X         : out Natural;
      Y         : out Natural;
      Width     : out Natural;
      Height    : out Natural) is
   begin
      X := Natural'Min (Start_X, Current_X);
      Y := Natural'Min (Start_Y, Current_Y);
      Width := Natural'Max (Start_X, Current_X) - X;
      Height := Natural'Max (Start_Y, Current_Y) - Y;
   end Marquee_Rect;

   function Items_In_Rect
     (Items  : Item_Layout_Vectors.Vector;
      X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural)
      return Visible_Index_Vectors.Vector
   is
      Hits : Visible_Index_Vectors.Vector;

      --  Half-open rectangle overlap on both axes. A zero-width or zero-height
      --  marquee touches nothing, so a plain click never selects here.
      function Overlaps (Item : Item_Layout) return Boolean is
      begin
         return Width > 0
           and then Height > 0
           and then Item.Width > 0
           and then Item.Height > 0
           and then Item.X < Guikit.Layout.Saturating_Add (X, Width)
           and then X < Guikit.Layout.Saturating_Add (Item.X, Item.Width)
           and then Item.Y < Guikit.Layout.Saturating_Add (Y, Height)
           and then Y < Guikit.Layout.Saturating_Add (Item.Y, Item.Height);
      end Overlaps;
   begin
      for Item of Items loop
         if Item.Visible_Index > 0 and then Overlaps (Item) then
            Hits.Append (Item.Visible_Index);
         end if;
      end loop;
      return Hits;
   end Items_In_Rect;

end Guikit.Item_Grid;
