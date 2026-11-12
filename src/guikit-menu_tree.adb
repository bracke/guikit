with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Guikit.Layout;
with Guikit.Utf8;
with Guikit.Widgets;

package body Guikit.Menu_Tree is

   use Guikit.Draw;

   --  Text fitted to Capacity display columns with a trailing ellipsis.
   function Fit_Text (Text : UString; Capacity : Natural) return UString is
     (To_Unbounded_String (Guikit.Utf8.Fit_With_Ellipsis (To_String (Text), Capacity)));

   procedure Draw_Frame
     (Rectangles    : in out Rectangle_Command_Vectors.Vector;
      Text          : in out Text_Command_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Title         : UString;
      Config        : Menu_Tree_Configuration;
      Rows          : Menu_Tree_Row_Vectors.Vector;
      Buttons       : Menu_Tree_Button_Vectors.Vector;
      Draw_Chrome   : Boolean := True)
   is
      Line_Height : constant Positive := Config.Line_Height;
      Cell_W      : constant Positive :=
        Guikit.Layout.Caret_Advance_Width (Line_Height);

      function Clipped (Start, Size, Limit : Natural) return Natural is
        (if Start >= Limit or else Size = 0 then 0 else Natural'Min (Size, Limit - Start));

      procedure Add_Rect (X, Y, W, H : Natural; Color : Render_Color) is
         Draw_W : constant Natural := Clipped (X, W, Clip_Width);
         Draw_H : constant Natural := Clipped (Y, H, Clip_Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Rectangles.Append
              (Rectangle_Command'(X => X, Y => Y, Width => Draw_W, Height => Draw_H, Color => Color));
         end if;
      end Add_Rect;

      procedure Add_Text (X, Y, W, H : Natural; Content : UString; Color : Render_Color; Fit : Boolean) is
         Draw_W   : constant Natural := Clipped (X, W, Clip_Width);
         Draw_H   : constant Natural := Clipped (Y, H, Clip_Height);
         Capacity : constant Natural := Draw_W / Cell_W;
         Fitted   : constant UString := (if Fit then Fit_Text (Content, Capacity) else Content);
      begin
         if Draw_W > 0 and then Draw_H > 0 and then Length (Fitted) > 0 then
            Text.Append
              (Text_Command'
                 (X            => X,
                  Y            => Y,
                  Width        => Draw_W,
                  Height       => Draw_H,
                  Text         => Fitted,
                  Color        => Color,
                  Truncated    => Fit and then Fitted /= Content,
                  Scale_To_Box => False,
                  Italic       => False));
         end if;
      end Add_Text;

   begin
      if Draw_Chrome and then Region_Width > 0 and then Region_Height > 0 then
         --  Right drop-shadow, fill, border.
         Add_Rect
           (Guikit.Layout.Saturating_Add (Region_X, Region_Width),
            Guikit.Layout.Saturating_Add (Region_Y, Guikit.Layout.Scaled (3, Line_Height)),
            Guikit.Layout.Scaled (3, Line_Height), Region_Height, Pane_Color);
         Add_Rect (Region_X, Region_Y, Region_Width, Region_Height, Overlay_Color);
         Guikit.Widgets.Draw_Border
           (Rectangles, Clip_Width, Clip_Height,
            Region_X, Region_Y, Region_Width, Region_Height, Border_Color);

         --  Title band: filled strip, a one-pixel divider, then the title text.
         Add_Rect (Region_X, Region_Y, Region_Width, Config.Title_Height, Pane_Color);
         Add_Rect
           (Region_X, Guikit.Layout.Saturating_Add (Region_Y, Config.Title_Height),
            Region_Width, 1, Border_Color);
         Add_Text
           (Guikit.Layout.Saturating_Add (Region_X, Config.Text_Padding),
            Guikit.Layout.Saturating_Add
              (Region_Y,
               (if Config.Title_Height > Line_Height
                then (Config.Title_Height - Line_Height) / 2 else 0)),
            (if Region_Width > Guikit.Layout.Saturating_Multiply (Config.Text_Padding, 2)
             then Region_Width - Guikit.Layout.Saturating_Multiply (Config.Text_Padding, 2)
             else 0),
            Line_Height, Title, Text_Color, Fit => True);
      end if;

      for Row of Rows loop
         declare
            Label_X : constant Natural := Guikit.Layout.Saturating_Add (Row.Triangle_X, Line_Height);
            Right   : constant Natural := Guikit.Layout.Saturating_Add (Label_X, Config.Text_Padding);
            Row_End : constant Natural := Guikit.Layout.Saturating_Add (Row.X, Row.Width);
            Label_W : constant Natural := (if Row_End > Right then Row_End - Right else 0);
            Text_Y  : constant Natural :=
              (if Row.Height > Line_Height
               then Guikit.Layout.Saturating_Add (Row.Y, (Row.Height - Line_Height) / 2)
               else Row.Y);
         begin
            Add_Rect
              (Row.X, Row.Y, Row.Width, Row.Height,
               (if Row.Selected then Selection_Color
                elsif Row.Pressed then Pressed_Color
                elsif Row.Hovered then Hover_Color
                else Overlay_Color));
            if Row.Has_Children and then Row.Triangle_Width > 0 then
               Add_Text
                 (Row.Triangle_X, Text_Y, Row.Triangle_Width, Line_Height,
                  (if Row.Expanded then Config.Expanded_Glyph else Config.Collapsed_Glyph),
                  Muted_Text_Color, Fit => False);
            end if;
            Add_Text (Label_X, Text_Y, Label_W, Line_Height, Row.Label, Text_Color, Fit => True);
         end;
      end loop;

      for Button of Buttons loop
         Guikit.Widgets.Draw_Button
           (Rectangles      => Rectangles,
            Text            => Text,
            Clip_Width      => Clip_Width,
            Clip_Height     => Clip_Height,
            X               => Button.X,
            Y               => Button.Y,
            Width           => Button.Width,
            Height          => Button.Height,
            Fill_Color      =>
              (if Button.Pressed then Pressed_Color
               elsif Button.Hovered then Hover_Color
               else Pane_Color),
            Border_Color    => Border_Color,
            Padding         => Guikit.Layout.Scaled (Guikit.Layout.Input_Field_Padding, Line_Height),
            Label_Text      => Button.Label,
            Label_Truncated => False,
            Label_Height    => Line_Height,
            Label_Color     => Text_Color);
      end loop;
   end Draw_Frame;

end Guikit.Menu_Tree;
