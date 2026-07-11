with Ada.Strings.Unbounded;

package body Guikit.Widgets is

   use Guikit.Draw;

   --  Saturating sum: never overflows past Natural'Last.
   function Saturating_Add (Left : Natural; Right : Natural) return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   --  Saturating product: never overflows past Natural'Last.
   function Saturating_Mul (Value : Natural; Factor : Natural) return Natural is
   begin
      if Factor = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Natural'Last;
      else
         return Value * Factor;
      end if;
   end Saturating_Mul;

   --  Clip a run starting at Start with the given Size to Limit, mirroring the
   --  renderer: fully off-screen or empty runs clip to zero.
   function Clipped_Size
     (Start : Natural;
      Size  : Natural;
      Limit : Natural)
      return Natural is
   begin
      if Start >= Limit or else Size = 0 then
         return 0;
      else
         return Natural'Min (Size, Limit - Start);
      end if;
   end Clipped_Size;

   --  Append one rectangle, clipped to the window bounds and dropped when empty.
   procedure Add_Clipped_Rect
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color)
   is
      Draw_W : constant Natural := Clipped_Size (X, Width, Clip_Width);
      Draw_H : constant Natural := Clipped_Size (Y, Height, Clip_Height);
   begin
      if Draw_W > 0 and then Draw_H > 0 then
         Rectangles.Append
           (Rectangle_Command'
              (X      => X,
               Y      => Y,
               Width  => Draw_W,
               Height => Draw_H,
               Color  => Color));
      end if;
   end Add_Clipped_Rect;

   --  Append a one-pixel border (top, left, bottom, right) around a box.
   procedure Add_Border
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color) is
   begin
      if Width = 0 or else Height = 0 then
         return;
      end if;

      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, Width, 1, Color);
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, 1, Height, Color);
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, X, Saturating_Add (Y, Height - 1), Width, 1, Color);
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, Saturating_Add (X, Width - 1), Y, 1, Height, Color);
   end Add_Border;

   procedure Draw_Focus_Ring
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color) is
   begin
      if Width = 0 or else Height = 0 then
         return;
      end if;

      Add_Border (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Color);
      if X > 0 and then Y > 0 then
         Add_Border
           (Rectangles,
            Clip_Width,
            Clip_Height,
            X - 1,
            Y - 1,
            Saturating_Add (Width, 2),
            Saturating_Add (Height, 2),
            Color);
      end if;
   end Draw_Focus_Ring;

   procedure Draw_Drop_Shadow
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color)
   is
      Shadow_Offset : constant Natural := 3;
   begin
      if Width = 0 or else Height = 0 then
         return;
      end if;

      Add_Clipped_Rect
        (Rectangles,
         Clip_Width,
         Clip_Height,
         Saturating_Add (X, Shadow_Offset),
         Saturating_Add (Y, Height),
         Width,
         Shadow_Offset,
         Color);
      Add_Clipped_Rect
        (Rectangles,
         Clip_Width,
         Clip_Height,
         Saturating_Add (X, Width),
         Saturating_Add (Y, Shadow_Offset),
         Shadow_Offset,
         Height,
         Color);
   end Draw_Drop_Shadow;

   procedure Draw_Close_Button
     (Rectangles    : in out Rectangle_Command_Vectors.Vector;
      Text          : in out Text_Command_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Button_X      : Natural;
      Button_Y      : Natural;
      Button_Width  : Natural;
      Button_Height : Natural;
      Fill_Color    : Render_Color;
      Border_Color  : Render_Color;
      Glyph_X       : Natural;
      Glyph_Y       : Natural;
      Glyph_Width   : Natural;
      Glyph_Height  : Natural;
      Glyph         : UString;
      Glyph_Color   : Render_Color;
      Show_Glyph    : Boolean)
   is
      Draw_W : constant Natural := Clipped_Size (Glyph_X, Glyph_Width, Clip_Width);
      Draw_H : constant Natural := Clipped_Size (Glyph_Y, Glyph_Height, Clip_Height);
   begin
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height,
         Button_X, Button_Y, Button_Width, Button_Height, Fill_Color);
      Add_Border
        (Rectangles, Clip_Width, Clip_Height,
         Button_X, Button_Y, Button_Width, Button_Height, Border_Color);

      if Show_Glyph
        and then Draw_W > 0
        and then Draw_H > 0
        and then Ada.Strings.Unbounded.Length (Glyph) > 0
      then
         Text.Append
           (Text_Command'
              (X            => Glyph_X,
               Y            => Glyph_Y,
               Width        => Draw_W,
               Height       => Draw_H,
               Text         => Glyph,
               Color        => Glyph_Color,
               Truncated    => False,
               --  Center the glyph's box within the button: a lone symbol (the
               --  close "x") is otherwise baseline-placed and sits off-centre.
               Scale_To_Box => True,
               Italic       => False));
      end if;
   end Draw_Close_Button;

   procedure Draw_Scrollbar
     (Rectangles   : in out Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      Track_X      : Natural;
      Track_Y      : Natural;
      Track_Width  : Natural;
      Track_Height : Natural;
      Thumb_Y      : Natural;
      Thumb_Height : Natural;
      Track_Color  : Render_Color;
      Thumb_Color  : Render_Color;
      Grip_Color   : Render_Color)
   is
      Grip_W : constant Natural := (if Track_Width > 2 then Track_Width - 2 else 0);
      Grip_X : constant Natural := Saturating_Add (Track_X, 1);
      Mid_Y  : constant Natural := Saturating_Add (Thumb_Y, Thumb_Height / 2);
   begin
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, Track_X, Track_Y, Track_Width, Track_Height, Track_Color);
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, Track_X, Thumb_Y, Track_Width, Thumb_Height, Thumb_Color);
      Add_Border
        (Rectangles, Clip_Width, Clip_Height, Track_X, Thumb_Y, Track_Width, Thumb_Height, Track_Color);

      if Grip_W > 0 and then Thumb_Height >= 7 then
         Add_Clipped_Rect
           (Rectangles, Clip_Width, Clip_Height, Grip_X, Mid_Y - 2, Grip_W, 1, Grip_Color);
         Add_Clipped_Rect
           (Rectangles, Clip_Width, Clip_Height, Grip_X, Mid_Y, Grip_W, 1, Grip_Color);
         Add_Clipped_Rect
           (Rectangles, Clip_Width, Clip_Height, Grip_X, Saturating_Add (Mid_Y, 2), Grip_W, 1, Grip_Color);
      end if;
   end Draw_Scrollbar;

   procedure Draw_Menu_Panel
     (Rectangles   : in out Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      X            : Natural;
      Y            : Natural;
      Width        : Natural;
      Height       : Natural;
      Fill_Color   : Render_Color;
      Border_Color : Render_Color) is
   begin
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Fill_Color);
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, Width, 1, Border_Color);
      if Height > 0 then
         Add_Clipped_Rect
           (Rectangles, Clip_Width, Clip_Height, X, Saturating_Add (Y, Height - 1), Width, 1, Border_Color);
      end if;
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, 1, Height, Border_Color);
      if Width > 0 then
         Add_Clipped_Rect
           (Rectangles, Clip_Width, Clip_Height, Saturating_Add (X, Width - 1), Y, 1, Height, Border_Color);
      end if;
   end Draw_Menu_Panel;

   procedure Draw_Input_Field
     (Rectangles   : in out Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      X            : Natural;
      Y            : Natural;
      Width        : Natural;
      Height       : Natural;
      Fill_Color   : Render_Color;
      Border_Color : Render_Color) is
   begin
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Fill_Color);
      Add_Border (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Border_Color);
   end Draw_Input_Field;

   procedure Draw_Menu_Row
     (Rectangles      : in out Rectangle_Command_Vectors.Vector;
      Text            : in out Text_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      Row_X           : Natural;
      Row_Y           : Natural;
      Row_Width       : Natural;
      Row_Height      : Natural;
      Is_Separator    : Boolean;
      Separator_X     : Natural;
      Separator_Y     : Natural;
      Separator_Width : Natural;
      Separator_Color : Render_Color;
      Highlight       : Boolean;
      Highlight_Color : Render_Color;
      Label_X         : Natural;
      Label_Y         : Natural;
      Label_Width     : Natural;
      Label_Height    : Natural;
      Label_Text      : UString;
      Label_Truncated : Boolean;
      Label_Color     : Render_Color)
   is
      Draw_W : constant Natural := Clipped_Size (Label_X, Label_Width, Clip_Width);
      Draw_H : constant Natural := Clipped_Size (Label_Y, Label_Height, Clip_Height);
   begin
      if Is_Separator then
         Add_Clipped_Rect
           (Rectangles, Clip_Width, Clip_Height, Separator_X, Separator_Y, Separator_Width, 1, Separator_Color);
         return;
      end if;

      if Highlight then
         Add_Clipped_Rect
           (Rectangles, Clip_Width, Clip_Height, Row_X, Row_Y, Row_Width, Row_Height, Highlight_Color);
      end if;

      if Draw_W > 0
        and then Draw_H > 0
        and then Ada.Strings.Unbounded.Length (Label_Text) > 0
      then
         Text.Append
           (Text_Command'
              (X            => Label_X,
               Y            => Label_Y,
               Width        => Draw_W,
               Height       => Draw_H,
               Text         => Label_Text,
               Color        => Label_Color,
               Truncated    => Label_Truncated,
               Scale_To_Box => False,
               Italic       => False));
      end if;
   end Draw_Menu_Row;

   procedure Draw_Palette_Row
     (Rectangles            : in out Rectangle_Command_Vectors.Vector;
      Text                  : in out Text_Command_Vectors.Vector;
      Clip_Width            : Natural;
      Clip_Height           : Natural;
      Row_X                 : Natural;
      Row_Y                 : Natural;
      Row_Width             : Natural;
      Row_Height            : Natural;
      Background_Color      : Render_Color;
      Selected              : Boolean;
      Accent_Color          : Render_Color;
      Label_X               : Natural;
      Label_Y               : Natural;
      Label_Width           : Natural;
      Label_Height          : Natural;
      Label_Text            : UString;
      Label_Truncated       : Boolean;
      Label_Color           : Render_Color;
      Shortcut_X            : Natural;
      Shortcut_Width        : Natural;
      Shortcut_Text         : UString;
      Shortcut_Truncated    : Boolean;
      Shortcut_Color        : Render_Color;
      Description_Y         : Natural;
      Description_Width     : Natural;
      Description_Height    : Natural;
      Description_Text      : UString;
      Description_Truncated : Boolean;
      Description_Color     : Render_Color)
   is
      procedure Emit_Text
        (X         : Natural;
         Y         : Natural;
         W         : Natural;
         H         : Natural;
         Content   : UString;
         Color     : Render_Color;
         Truncated : Boolean)
      is
         Draw_W : constant Natural := Clipped_Size (X, W, Clip_Width);
         Draw_H : constant Natural := Clipped_Size (Y, H, Clip_Height);
      begin
         if Draw_W > 0
           and then Draw_H > 0
           and then Ada.Strings.Unbounded.Length (Content) > 0
         then
            Text.Append
              (Text_Command'
                 (X            => X,
                  Y            => Y,
                  Width        => Draw_W,
                  Height       => Draw_H,
                  Text         => Content,
                  Color        => Color,
                  Truncated    => Truncated,
                  Scale_To_Box => False,
                  Italic       => False));
         end if;
      end Emit_Text;
   begin
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, Row_X, Row_Y, Row_Width, Row_Height, Background_Color);
      if Selected then
         Add_Clipped_Rect
           (Rectangles, Clip_Width, Clip_Height,
            Row_X, Row_Y, Natural'Min (3, Row_Width), Row_Height, Accent_Color);
      end if;

      Emit_Text (Label_X, Label_Y, Label_Width, Label_Height, Label_Text, Label_Color, Label_Truncated);
      if Shortcut_Width > 0 then
         Emit_Text
           (Shortcut_X, Label_Y, Shortcut_Width, Label_Height, Shortcut_Text, Shortcut_Color, Shortcut_Truncated);
      end if;
      if Description_Width > 0 and then Description_Height > 0 then
         Emit_Text
           (Label_X, Description_Y, Description_Width, Description_Height,
            Description_Text, Description_Color, Description_Truncated);
      end if;
   end Draw_Palette_Row;

   procedure Draw_Toggle
     (Rectangles   : in out Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      X            : Natural;
      Y            : Natural;
      Width        : Natural;
      Height       : Natural;
      Is_On        : Boolean;
      On_Color     : Render_Color;
      Off_Color    : Render_Color;
      Border_Color : Render_Color;
      Knob_Color   : Render_Color)
   is
      Knob_Pad  : constant Natural := Natural'Max (1, Height / 8);
      Knob_Size : constant Natural :=
        (if Height > 2 * Knob_Pad then Height - 2 * Knob_Pad else Height);
      Knob_X    : constant Natural :=
        (if Is_On and then Width > Knob_Pad + Knob_Size
         then Saturating_Add (X, Width - Knob_Pad - Knob_Size)
         else Saturating_Add (X, Knob_Pad));
   begin
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height,
         (if Is_On then On_Color else Off_Color));
      Add_Border (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Border_Color);
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height,
         Knob_X, Saturating_Add (Y, Knob_Pad), Knob_Size, Knob_Size, Knob_Color);
   end Draw_Toggle;

   procedure Draw_Number_Stepper
     (Rectangles      : in out Rectangle_Command_Vectors.Vector;
      Text            : in out Text_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      Box_Y           : Natural;
      Box_Height      : Natural;
      Text_Y          : Natural;
      Text_Height     : Natural;
      Padding         : Natural;
      Value_X         : Natural;
      Value_Width     : Natural;
      Value_Text      : UString;
      Down_X          : Natural;
      Up_X            : Natural;
      Button_Width    : Natural;
      Decrement_Label : UString;
      Increment_Label : UString;
      Fill_Color      : Render_Color;
      Border_Color    : Render_Color;
      Text_Color      : Render_Color)
   is
      procedure Box (X : Natural; Width : Natural; Label : UString) is
         Text_X  : constant Natural := Saturating_Add (X, Padding);
         Field_W : constant Natural := (if Width > 2 * Padding then Width - 2 * Padding else 0);
         Draw_W  : constant Natural := Clipped_Size (Text_X, Field_W, Clip_Width);
         Draw_H  : constant Natural := Clipped_Size (Text_Y, Text_Height, Clip_Height);
      begin
         Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Box_Y, Width, Box_Height, Fill_Color);
         Add_Border (Rectangles, Clip_Width, Clip_Height, X, Box_Y, Width, Box_Height, Border_Color);
         if Draw_W > 0
           and then Draw_H > 0
           and then Ada.Strings.Unbounded.Length (Label) > 0
         then
            Text.Append
              (Text_Command'
                 (X            => Text_X,
                  Y            => Text_Y,
                  Width        => Draw_W,
                  Height       => Draw_H,
                  Text         => Label,
                  Color        => Text_Color,
                  Truncated    => False,
                  Scale_To_Box => False,
                  Italic       => False));
         end if;
      end Box;
   begin
      Box (Value_X, Value_Width, Value_Text);
      Box (Down_X, Button_Width, Decrement_Label);
      Box (Up_X, Button_Width, Increment_Label);
   end Draw_Number_Stepper;

   procedure Draw_Button
     (Rectangles      : in out Rectangle_Command_Vectors.Vector;
      Text            : in out Text_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      X               : Natural;
      Y               : Natural;
      Width           : Natural;
      Height          : Natural;
      Fill_Color      : Render_Color;
      Border_Color    : Render_Color;
      Padding         : Natural;
      Label_Text      : UString;
      Label_Truncated : Boolean;
      Label_Height    : Natural;
      Label_Color     : Render_Color)
   is
      Inset   : constant Natural :=
        (if Height > Label_Height then (Height - Label_Height) / 2 else 0);
      Label_X : constant Natural := Saturating_Add (X, Padding);
      Label_Y : constant Natural := Saturating_Add (Y, Inset);
      Label_W : constant Natural := (if Width > 2 * Padding then Width - 2 * Padding else 0);
      Draw_W  : constant Natural := Clipped_Size (Label_X, Label_W, Clip_Width);
      Draw_H  : constant Natural := Clipped_Size (Label_Y, Label_Height, Clip_Height);
   begin
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Fill_Color);
      Add_Border (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Border_Color);
      if Draw_W > 0
        and then Draw_H > 0
        and then Ada.Strings.Unbounded.Length (Label_Text) > 0
      then
         Text.Append
           (Text_Command'
              (X            => Label_X,
               Y            => Label_Y,
               Width        => Draw_W,
               Height       => Draw_H,
               Text         => Label_Text,
               Color        => Label_Color,
               Truncated    => Label_Truncated,
               Scale_To_Box => False,
               Italic       => False));
      end if;
   end Draw_Button;

   procedure Draw_Tooltip
     (Rectangles      : in out Rectangle_Command_Vectors.Vector;
      Text            : in out Text_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      Box_X           : Natural;
      Box_Y           : Natural;
      Box_Width       : Natural;
      Box_Height      : Natural;
      Fill_Color      : Render_Color;
      Border_Color    : Render_Color;
      Label_X         : Natural;
      Label_Y         : Natural;
      Label_Width     : Natural;
      Label_Height    : Natural;
      Label_Text      : UString;
      Label_Truncated : Boolean;
      Label_Color     : Render_Color)
   is
      Draw_W : constant Natural := Clipped_Size (Label_X, Label_Width, Clip_Width);
      Draw_H : constant Natural := Clipped_Size (Label_Y, Label_Height, Clip_Height);
   begin
      Add_Clipped_Rect
        (Rectangles, Clip_Width, Clip_Height, Box_X, Box_Y, Box_Width, Box_Height, Fill_Color);
      Add_Border
        (Rectangles, Clip_Width, Clip_Height, Box_X, Box_Y, Box_Width, Box_Height, Border_Color);

      if Draw_W > 0
        and then Draw_H > 0
        and then Ada.Strings.Unbounded.Length (Label_Text) > 0
      then
         Text.Append
           (Text_Command'
              (X            => Label_X,
               Y            => Label_Y,
               Width        => Draw_W,
               Height       => Draw_H,
               Text         => Label_Text,
               Color        => Label_Color,
               Truncated    => Label_Truncated,
               Scale_To_Box => False,
               Italic       => False));
      end if;
   end Draw_Tooltip;

   procedure Draw_Caret
     (Rectangles  : in out Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Render_Color) is
   begin
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Color);
   end Draw_Caret;

   procedure Draw_Marquee
     (Rectangles   : in out Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      X            : Natural;
      Y            : Natural;
      Width        : Natural;
      Height       : Natural;
      Fill_Color   : Render_Color;
      Border_Color : Render_Color) is
   begin
      Add_Clipped_Rect (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Fill_Color);
      Add_Border (Rectangles, Clip_Width, Clip_Height, X, Y, Width, Height, Border_Color);
   end Draw_Marquee;

end Guikit.Widgets;
