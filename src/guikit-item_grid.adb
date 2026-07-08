with Guikit.Layout;
with Guikit.Utf8;

package body Guikit.Item_Grid is

   use Ada.Strings.Unbounded;

   --  Cell padding/gap constants (pixels), matching the file-manager grid metrics.
   Main_Grid_Gap          : constant Natural := 8;
   Item_Content_Padding   : constant Natural := 4;
   Item_Icon_Text_Gap     : constant Natural := 12;
   Details_Row_Padding    : constant Natural := 4;
   Details_Row_Gap        : constant Natural := 0;
   Details_Column_Padding : constant Natural := 6;

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

   function Calculate_Layout
     (Items         : Layout_Item_Vectors.Vector;
      View          : View_Kind;
      Content_X     : Natural;
      Content_Y     : Natural;
      Content_W     : Natural;
      Content_H     : Natural;
      Columns       : Detail_Column_Bounds;
      Scroll_Pixels : Natural;
      Line_Height   : Positive := 20)
      return Item_Layout_Vectors.Vector
   is
      Result : Item_Layout_Vectors.Vector;

      function Add (L, R : Natural) return Natural renames Guikit.Layout.Saturating_Add;
      function Mul (V, F : Natural) return Natural renames Guikit.Layout.Saturating_Multiply;
      function Sub (Left, Right : Natural) return Natural is (if Left > Right then Left - Right else 0);

      function Columns_For (Main_Width : Natural; Cell_Width : Positive) return Positive is
         Stride : constant Positive := Positive (Add (Cell_Width, Main_Grid_Gap));
      begin
         if Main_Width < Cell_Width then
            return 1;
         else
            return Positive'Max (1, Positive (Add (Main_Width, Main_Grid_Gap) / Stride));
         end if;
      end Columns_For;

      procedure Append_Grid_Item
        (Index     : Positive;
         Cell_W    : Positive;
         Cell_H    : Positive;
         Icon_Size : Positive;
         Large     : Boolean)
      is
         Grid_Cols   : constant Positive := Columns_For (Content_W, Cell_W);
         Offset      : constant Natural := Natural (Index - 1);
         Column      : constant Natural := Offset mod Grid_Cols;
         Row         : constant Natural := Offset / Grid_Cols;
         Cell_Stride : constant Natural := Add (Cell_W, Main_Grid_Gap);
         Row_Stride  : constant Natural := Add (Cell_H, Main_Grid_Gap);
         Cell_Offset : constant Natural := Mul (Column, Cell_Stride);
         Row_Offset  : constant Natural := Mul (Row, Row_Stride);
         Hidden_Px   : constant Natural :=
           (if Row_Offset < Scroll_Pixels then Natural'Min (Cell_H, Scroll_Pixels - Row_Offset) else 0);
         Visible_Row : constant Natural := Sub (Row_Offset, Scroll_Pixels);
         Cell_X      : constant Natural := Add (Content_X, Cell_Offset);
         Cell_Y      : constant Natural := Add (Content_Y, Visible_Row);
         Cell_Width  : constant Natural :=
           (if Content_W > Cell_Offset then Natural'Min (Cell_W, Content_W - Cell_Offset) else 0);
         Cell_Height : constant Natural :=
           (if Hidden_Px = 0 and then Content_H >= Add (Visible_Row, Cell_H) then Cell_H else 0);
         Draw_Icon   : constant Natural := Natural'Min (Icon_Size, Natural'Min (Cell_Width, Cell_Height));
         Content_Pad : constant Natural :=
           Natural'Min (Item_Content_Padding, Natural'Min (Cell_Width, Cell_Height));
         Inner_X     : constant Natural := Add (Cell_X, Content_Pad);
         Inner_Y     : constant Natural := Add (Cell_Y, Content_Pad);
         Inner_W     : constant Natural :=
           (if Cell_Width > Mul (Content_Pad, 2) then Cell_Width - Mul (Content_Pad, 2) else Cell_Width);
         Inner_H     : constant Natural :=
           (if Cell_Height > Mul (Content_Pad, 2) then Cell_Height - Mul (Content_Pad, 2) else Cell_Height);
         Padded_Icon : constant Natural := Natural'Min (Draw_Icon, Natural'Min (Inner_W, Inner_H));
         Used_X      : constant Natural :=
           (if Large then 0 else Natural'Min (Inner_W, Add (Padded_Icon, Item_Icon_Text_Gap)));
         Icon_X      : constant Natural :=
           (if Large then Add (Inner_X, (if Inner_W > Padded_Icon then (Inner_W - Padded_Icon) / 2 else 0))
            else Inner_X);
         Icon_Y       : constant Natural := Inner_Y;
         Name_Units   : constant Natural := Guikit.Utf8.Display_Units (To_String (Items.Element (Index).Label));
         Name_Pixels  : constant Natural := Mul (Name_Units, Mul (Line_Height, 12) / 20);
         Large_Text_W : constant Natural := Natural'Min (Inner_W, Name_Pixels);
         Text_X       : constant Natural :=
           (if Large then Add (Inner_X, (if Inner_W > Large_Text_W then (Inner_W - Large_Text_W) / 2 else 0))
            else Add (Inner_X, Used_X));
         Text_Y       : constant Natural :=
           (if Large then Add (Add (Inner_Y, Padded_Icon), Item_Content_Padding) else Inner_Y);
         Text_W       : constant Natural := (if Large then Large_Text_W else Sub (Inner_W, Used_X));
      begin
         Result.Append
           (Item_Layout'
              (Visible_Index => Items.Element (Index).Visible_Index,
               X             => Cell_X,
               Y             => Cell_Y,
               Width         => Cell_Width,
               Height        => Cell_Height,
               Icon_X        => Icon_X,
               Icon_Y        => Icon_Y,
               Icon_Size     => Padded_Icon,
               Text_X        => Text_X,
               Text_Y        => Text_Y,
               Text_Width    => Text_W,
               Name_X        => Text_X,
               Name_Width    => Text_W,
               others        => 0));
      end Append_Grid_Item;
   begin
      for Index in 1 .. Natural (Items.Length) loop
         case View is
            when Icons_Small | Icons_Large =>
               declare
                  Metrics : constant Cell_Metrics := Cell_Metrics_For (View, Content_W, Line_Height);
               begin
                  Append_Grid_Item
                    (Positive (Index), Positive (Metrics.Width), Positive (Metrics.Height),
                     Positive (Metrics.Icon_Size), Metrics.Large);
               end;
            when Details =>
               declare
                  It          : constant Layout_Item := Items.Element (Positive (Index));
                  Metrics     : constant Cell_Metrics := Cell_Metrics_For (View, Content_W, Line_Height);
                  Row_Step    : constant Natural := Metrics.Height;
                  Header_H    : constant Natural :=
                    Natural'Min (Add (Line_Height, Mul (Details_Row_Padding, 2)), Content_H);
                  Rows_Y      : constant Natural := Add (Content_Y, Header_H);
                  Rows_H      : constant Natural := Sub (Content_H, Header_H);
                  Row_Offset  : constant Natural := Mul (Natural (Index - 1), Row_Step);
                  Hidden_Px   : constant Natural :=
                    (if Row_Offset < Scroll_Pixels then Natural'Min (Row_Step, Scroll_Pixels - Row_Offset) else 0);
                  Visible_Row : constant Natural := Sub (Row_Offset, Scroll_Pixels);
                  Row_Y       : constant Natural := Add (Rows_Y, Visible_Row);
                  Row_H       : constant Natural :=
                    (if Hidden_Px = 0 and then Rows_H >= Add (Visible_Row, Row_Step) then Row_Step else 0);
                  Row_Draw_H  : constant Natural :=
                    (if Row_H > Details_Row_Gap then Row_H - Details_Row_Gap else Row_H);
                  Row_Pad     : constant Natural := Natural'Min (Details_Row_Padding, Row_Draw_H);
                  Inner_H     : constant Natural :=
                    (if Row_Draw_H > Mul (Row_Pad, 2) then Row_Draw_H - Mul (Row_Pad, 2) else Row_Draw_H);
                  Row_Inner_X : constant Natural := Add (Content_X, Row_Pad);
                  Text_Pad    : constant Natural := Natural'Min (Details_Column_Padding, Row_Draw_H);
                  Name_X      : constant Natural := Columns (Name_Column).X;
                  Name_W      : constant Natural := Columns (Name_Column).Width;
                  Header_Name_W : constant Natural :=
                    (if Add (Content_X, Content_W) > Name_X then Add (Content_X, Content_W) - Name_X else 0);
               begin
                  if It.Group_Header then
                     Result.Append
                       (Item_Layout'
                          (Visible_Index => 0,
                           X             => Content_X,
                           Y             => Row_Y,
                           Width         => Content_W,
                           Height        => Row_Draw_H,
                           Text_X        => Add (Name_X, Text_Pad),
                           Text_Y        => Add (Row_Y, Sub (Row_Pad, 2)),
                           Text_Width    => Sub (Header_Name_W, Text_Pad),
                           Name_X        => Name_X,
                           Name_Width    => Header_Name_W,
                           others        => 0));
                  else
                     Result.Append
                       (Item_Layout'
                          (Visible_Index     => It.Visible_Index,
                           X                 => Content_X,
                           Y                 => Row_Y,
                           Width             => Content_W,
                           Height            => Row_Draw_H,
                           Icon_X            => Row_Inner_X,
                           Icon_Y            => Add (Row_Y, Sub (Row_Pad, 2)),
                           Icon_Size         => Natural'Min (Line_Height, Inner_H),
                           Text_X            => Add (Name_X, Text_Pad),
                           Text_Y            => Add (Row_Y, Sub (Row_Pad, 2)),
                           Text_Width        => Sub (Name_W, Text_Pad),
                           Name_X            => Add (Name_X, Text_Pad),
                           Name_Width        => Sub (Name_W, Text_Pad),
                           Modified_X        => Columns (Modified_Column).X,
                           Modified_Width    => Columns (Modified_Column).Width,
                           Size_X            => Columns (Size_Column).X,
                           Size_Width        => Columns (Size_Column).Width,
                           Filetype_X        => Columns (Filetype_Column).X,
                           Filetype_Width    => Columns (Filetype_Column).Width,
                           Created_X         => Columns (Created_Column).X,
                           Created_Width     => Columns (Created_Column).Width,
                           Permissions_X     => Columns (Permissions_Column).X,
                           Permissions_Width => Columns (Permissions_Column).Width));
                  end if;
               end;
         end case;
      end loop;
      return Result;
   end Calculate_Layout;

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
