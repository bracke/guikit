with Ada.Strings.Unbounded;

with Guikit.Layout;
with Guikit.Utf8;
with Guikit.Widgets;

package body Guikit.List_Panel is

   use Ada.Strings.Unbounded;
   use Guikit.Draw;
   use Guikit.Widgets;

   Ellipsis : constant String := Guikit.Utf8.Encode (16#2026#);

   function Fit_Text (Text : UString; Capacity : Natural) return UString is
      Raw : constant String := To_String (Text);
   begin
      if Capacity = 0 then
         return Null_Unbounded_String;
      elsif Guikit.Utf8.Display_Units (Raw) <= Capacity then
         return Text;
      elsif Capacity < 2 then
         return To_Unbounded_String (Guikit.Utf8.Prefix_By_Units (Raw, Capacity));
      else
         declare
            Prefix  : constant String := Guikit.Utf8.Prefix_By_Units (Raw, Capacity - 1);
            Trimmed : constant String :=
              (if Prefix'Length > 0
                 and then (Prefix (Prefix'Last) = '.' or else Prefix (Prefix'Last) = ' ')
               then Prefix (Prefix'First .. Prefix'Last - 1)
               else Prefix);
         begin
            if Trimmed = "" then
               return To_Unbounded_String (Guikit.Utf8.Prefix_By_Units (Raw, Capacity));
            else
               return To_Unbounded_String (Trimmed & Ellipsis);
            end if;
         end;
      end if;
   end Fit_Text;

   procedure Draw_Frame
     (Rectangles    : in out Rectangle_Command_Vectors.Vector;
      Text          : in out Text_Command_Vectors.Vector;
      Accessibility : in out Accessibility_Node_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Config        : List_Panel_Configuration;
      Rows          : List_Panel_Row_Vectors.Vector;
      Draw_Chrome   : Boolean := True)
   is
      Line_Height : constant Positive := Config.Line_Height;
      Cell_W      : constant Positive :=
        Positive'Max (1, Guikit.Layout.Saturating_Multiply (Line_Height, 12) / 20);
      Text_Width  : constant Natural :=
        (if Region_Width > Config.Text_Padding then Region_Width - Config.Text_Padding else 0);
      Text_Columns : constant Natural := Text_Width / Cell_W;
      Has_Title    : constant Boolean := Length (Config.Title) > 0;
      Title_Rows   : constant Natural := (if Has_Title then 1 else 0);
      Max_Rows     : constant Natural :=
        (if Region_Height / Line_Height > Title_Rows then Region_Height / Line_Height - Title_Rows else 0);
      Rows_To_Render : constant Natural := Natural'Min (Natural (Rows.Length), Max_Rows);
      Title_Text : constant UString := Fit_Text (Config.Title, Text_Columns);
      Title_Truncated : constant Boolean :=
        Guikit.Utf8.Display_Units (To_String (Config.Title)) > Text_Columns;
      Title_X : constant Natural := Region_X + Config.Text_Padding;
      Title_Y : constant Natural := Region_Y;
      Title_Width : constant Natural := Text_Width;
      Title_Height : constant Natural := Line_Height;
      Row_Base_Y : constant Natural := Region_Y + (Title_Rows * Line_Height);
      Empty_Y : constant Natural := Region_Y + ((Title_Rows + 1) * Line_Height);
      Panel_Role_Name : constant UString := Config.Title;
   begin
      if Region_Width = 0 or else Region_Height = 0 then
         return;
      end if;

      if Draw_Chrome then
         Draw_Menu_Panel
           (Rectangles,
            Clip_Width   => Clip_Width,
            Clip_Height  => Clip_Height,
            X            => Region_X,
            Y            => Region_Y,
            Width        => Region_Width,
            Height       => Region_Height,
            Fill_Color   => Pane_Color,
            Border_Color => Border_Color);
      end if;

      Accessibility.Append
        (Accessibility_Node'
           (Role        => Role_List,
            X           => Region_X,
            Y           => Region_Y,
            Width       => Region_Width,
            Height      => Region_Height,
            Name        => Panel_Role_Name,
            Description => Config.Empty_State,
            Enabled     => True,
            Selected    => False,
            Focused     => False));

      if Has_Title then
         Text.Append
           (Text_Command'
              (X            => Title_X,
               Y            => Title_Y,
               Width        => Title_Width,
               Height       => Title_Height,
               Text         => Title_Text,
               Color        => Text_Color,
               Truncated    => Title_Truncated,
               Scale_To_Box => False,
               Italic       => False));
         Accessibility.Append
           (Accessibility_Node'
              (Role        => Role_Heading,
               X           => Title_X,
               Y           => Title_Y,
               Width       => Title_Width,
               Height      => Title_Height,
               Name        => Title_Text,
               Description => Title_Text,
               Enabled     => False,
               Selected    => False,
               Focused     => False));
      end if;

      if Rows_To_Render = 0 then
         if Length (Config.Empty_State) > 0 then
            declare
               Empty_Text : constant UString := Fit_Text (Config.Empty_State, Text_Columns);
               Empty_Truncated : constant Boolean :=
                 Guikit.Utf8.Display_Units (To_String (Config.Empty_State)) > Text_Columns;
            begin
               Text.Append
                 (Text_Command'
                    (X            => Title_X,
                     Y            => Empty_Y,
                     Width        => Text_Width,
                     Height       => Line_Height,
                     Text         => Empty_Text,
                     Color        => Muted_Text_Color,
                     Truncated    => Empty_Truncated,
                     Scale_To_Box => False,
                     Italic       => False));
               Accessibility.Append
                 (Accessibility_Node'
                    (Role        => Role_Status,
                     X           => Title_X,
                     Y           => Empty_Y,
                     Width       => Text_Width,
                     Height      => Line_Height,
                     Name        => Empty_Text,
                     Description => Empty_Text,
                     Enabled     => False,
                     Selected    => False,
                     Focused     => False));
            end;
         end if;
         return;
      end if;

      for I in 1 .. Rows_To_Render loop
         declare
            Row : constant List_Panel_Row := Rows (I);
            Row_Y : constant Natural := Row_Base_Y + ((I - 1) * Line_Height);
            Combined : constant String :=
              (if Length (Row.Detail) = 0 then To_String (Row.Label)
               else To_String (Row.Label) & " - " & To_String (Row.Detail));
            Shortcut_W : constant Natural :=
              (if Length (Row.Shortcut) > 0 and then Text_Width > 14 * Cell_W then 10 * Cell_W else 0);
            Label_W : constant Natural :=
              (if Shortcut_W > 0 and then Text_Width > Shortcut_W + Cell_W
               then Text_Width - Shortcut_W - Cell_W
               else Text_Width);
            Label_Columns : constant Natural := Label_W / Cell_W;
            Shortcut_Columns : constant Natural := Shortcut_W / Cell_W;
            Combined_Text : constant UString := Fit_Text (To_Unbounded_String (Combined), Label_Columns);
            Shortcut_Text : constant UString := Fit_Text (Row.Shortcut, Shortcut_Columns);
            Truncated : constant Boolean := Guikit.Utf8.Display_Units (Combined) > Label_Columns;
            Shortcut_X : constant Natural :=
              (if Shortcut_W > 0 then Region_X + Region_Width - Shortcut_W - Config.Text_Padding else 0);
            Background : constant Render_Color :=
              (if Row.Has_Background then Row.Background_Color
               elsif Row.Selected then Selection_Color
               elsif Config.Show_Alternate_Rows and then I mod 2 = 0 then Detail_Alternate_Color
               else Pane_Color);
         begin
            Draw_Palette_Row
              (Rectangles            => Rectangles,
               Text                  => Text,
               Clip_Width            => Clip_Width,
               Clip_Height           => Clip_Height,
               Row_X                 => Region_X,
               Row_Y                 => Row_Y,
               Row_Width             => Region_Width,
               Row_Height            => Line_Height,
               Background_Color      => Background,
               Selected              => Row.Selected,
               Accent_Color          => Row.Accent_Color,
               Label_X               => Title_X,
               Label_Y               => Row_Y,
               Label_Width           => Label_W,
               Label_Height          => Line_Height,
               Label_Text            => Combined_Text,
               Label_Truncated       => Truncated,
               Label_Color           => Row.Label_Color,
               Shortcut_X            => Shortcut_X,
               Shortcut_Width        => Shortcut_W,
               Shortcut_Text         => Shortcut_Text,
               Shortcut_Truncated    => Guikit.Utf8.Display_Units (To_String (Row.Shortcut)) > Shortcut_Columns,
               Shortcut_Color        => Row.Shortcut_Color,
               Description_Y         => 0,
               Description_Width     => 0,
               Description_Height    => 0,
               Description_Text      => Null_Unbounded_String,
               Description_Truncated => False,
               Description_Color     => Muted_Text_Color);

            Accessibility.Append
              (Accessibility_Node'
                 (Role        => Role_List_Item,
                  X           => Region_X,
                  Y           => Row_Y,
                  Width       => Region_Width,
                  Height      => Line_Height,
                  Name        => To_Unbounded_String (Combined),
                  Description => Row.Detail,
                  Enabled     => Row.Enabled,
                  Selected    => Row.Selected,
                  Focused     => False));
         end;
      end loop;
   end Draw_Frame;

end Guikit.List_Panel;
