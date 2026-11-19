
with Guikit.Layout;
with Guikit.Utf8;
with Guikit.Widgets;

package body Guikit.List_Panel is

   use Ada.Strings.Unbounded;
   use Guikit.Draw;
   use Guikit.Widgets;

   --  Text fitted to Capacity display columns with a trailing ellipsis.
   function Fit_Text (Text : UString; Capacity : Natural) return UString is
     (To_Unbounded_String (Guikit.Utf8.Fit_With_Ellipsis (To_String (Text), Capacity)));

   --  Where one Draw_Frame call places things: the clip, the panel region,
   --  the row height, and the text column every row's label starts in.
   type Panel_Geometry is record
      Clip_Width, Clip_Height : Natural := 0;
      Region_X, Region_Y      : Natural := 0;
      Region_Width            : Natural := 0;
      Region_Height           : Natural := 0;
      Line_Height             : Positive := 20;
      --  Each row's height: at least one Line_Height.
      Row_Height              : Positive := 20;
      --  One display cell's width.
      Cell_Width              : Positive := 1;
      --  The title's, the empty state's and the labels' left edge, and the
      --  width and display columns they have.
      Text_X                  : Natural := 0;
      Text_Width              : Natural := 0;
      Text_Columns            : Natural := 0;
      --  Where the first row starts, below the title when there is one.
      Rows_Y                  : Natural := 0;
      Leading_Icon_Width      : Natural := 0;
   end record;

   --  The panel, unless the caller draws it (Draw_Chrome), its list node,
   --  and the title with its heading node.
   procedure Draw_Panel_And_Title
     (Rectangles    : in out Rectangle_Command_Vectors.Vector;
      Text          : in out Text_Command_Vectors.Vector;
      Accessibility : in out Accessibility_Node_Vectors.Vector;
      G             : Panel_Geometry;
      Config        : List_Panel_Configuration;
      Draw_Chrome   : Boolean)
   is
      Title_Text : constant UString := Fit_Text (Config.Title, G.Text_Columns);
   begin
      if Draw_Chrome then
         Draw_Menu_Panel
           (Rectangles,
            Clip_Width   => G.Clip_Width,
            Clip_Height  => G.Clip_Height,
            X            => G.Region_X,
            Y            => G.Region_Y,
            Width        => G.Region_Width,
            Height       => G.Region_Height,
            Fill_Color   => Pane_Color,
            Border_Color => Border_Color);
      end if;

      Accessibility.Append
        (Accessibility_Node'
           (Role        => Role_List,
            X           => G.Region_X,
            Y           => G.Region_Y,
            Width       => G.Region_Width,
            Height      => G.Region_Height,
            Name        => Config.Title,
            Description => Config.Empty_State,
            Enabled     => True,
            Selected    => False,
            Focused     => False));

      if Length (Config.Title) > 0 then
         Text.Append
           (Text_Command'
              (X            => G.Text_X,
               Y            => G.Region_Y,
               Width        => G.Text_Width,
               Height       => G.Line_Height,
               Text         => Title_Text,
               Color        => Text_Color,
               Truncated    => Guikit.Utf8.Display_Units (To_String (Config.Title)) > G.Text_Columns,
               others       => <>));
         Accessibility.Append
           (Accessibility_Node'
              (Role        => Role_Heading,
               X           => G.Text_X,
               Y           => G.Region_Y,
               Width       => G.Text_Width,
               Height      => G.Line_Height,
               Name        => Title_Text,
               Description => Title_Text,
               Enabled     => False,
               Selected    => False,
               Focused     => False));
      end if;
   end Draw_Panel_And_Title;

   --  The empty-state message, when there is one, one line below where the
   --  rows start, and its status node.
   procedure Draw_Empty_State
     (Text          : in out Text_Command_Vectors.Vector;
      Accessibility : in out Accessibility_Node_Vectors.Vector;
      G             : Panel_Geometry;
      Config        : List_Panel_Configuration)
   is
      Empty_Y         : constant Natural := G.Rows_Y + G.Line_Height;
      Empty_Text      : constant UString := Fit_Text (Config.Empty_State, G.Text_Columns);
      Empty_Truncated : constant Boolean :=
        Guikit.Utf8.Display_Units (To_String (Config.Empty_State)) > G.Text_Columns;
   begin
      if Length (Config.Empty_State) = 0 then
         return;
      end if;
      Text.Append
        (Text_Command'
           (X            => G.Text_X,
            Y            => Empty_Y,
            Width        => G.Text_Width,
            Height       => G.Line_Height,
            Text         => Empty_Text,
            Color        => Muted_Text_Color,
            Truncated    => Empty_Truncated,
            others       => <>));
      Accessibility.Append
        (Accessibility_Node'
           (Role        => Role_Status,
            X           => G.Text_X,
            Y           => Empty_Y,
            Width       => G.Text_Width,
            Height      => G.Line_Height,
            Name        => Empty_Text,
            Description => Empty_Text,
            Enabled     => False,
            Selected    => False,
            Focused     => False));
   end Draw_Empty_State;

   --  Row I of the panel: its background, label and shortcut, and its list
   --  item node.
   procedure Draw_Row
     (Rectangles    : in out Rectangle_Command_Vectors.Vector;
      Text          : in out Text_Command_Vectors.Vector;
      Accessibility : in out Accessibility_Node_Vectors.Vector;
      G             : Panel_Geometry;
      Config        : List_Panel_Configuration;
      Row           : List_Panel_Row;
      I             : Positive)
   is
      Cell_W : constant Positive := G.Cell_Width;
      Row_Y : constant Natural := G.Rows_Y + ((I - 1) * G.Row_Height);
      --  Label is one Line_Height tall, vertically centred in the row.
      Label_Y : constant Natural := Row_Y + (G.Row_Height - G.Line_Height) / 2;
      --  Width available to the label after the reserved leading-icon column.
      Avail_W : constant Natural :=
        (if G.Text_Width > G.Leading_Icon_Width then G.Text_Width - G.Leading_Icon_Width else 0);
      Combined : constant String :=
        (if Length (Row.Detail) = 0 then To_String (Row.Label)
         else To_String (Row.Label) & " - " & To_String (Row.Detail));
      Shortcut_W : constant Natural :=
        (if Length (Row.Shortcut) > 0 and then Avail_W > 14 * Cell_W then 10 * Cell_W else 0);
      Label_W : constant Natural :=
        (if Shortcut_W > 0 and then Avail_W > Shortcut_W + Cell_W
         then Avail_W - Shortcut_W - Cell_W
         else Avail_W);
      Label_Columns : constant Natural := Label_W / Cell_W;
      Shortcut_Columns : constant Natural := Shortcut_W / Cell_W;
      Combined_Text : constant UString := Fit_Text (To_Unbounded_String (Combined), Label_Columns);
      Shortcut_Text : constant UString := Fit_Text (Row.Shortcut, Shortcut_Columns);
      Truncated : constant Boolean := Guikit.Utf8.Display_Units (Combined) > Label_Columns;
      Shortcut_X : constant Natural :=
        (if Shortcut_W > 0 then G.Region_X + G.Region_Width - Shortcut_W - Config.Text_Padding else 0);
      Background : constant Render_Color :=
        (if Row.Has_Background then Row.Background_Color
         elsif Row.Selected then Selection_Color
         elsif Config.Show_Alternate_Rows and then I mod 2 = 0 then Alternate_Row_Color
         else Pane_Color);
   begin
      Draw_Palette_Row
        (Rectangles            => Rectangles,
         Text                  => Text,
         Clip_Width            => G.Clip_Width,
         Clip_Height           => G.Clip_Height,
         Row_X                 => G.Region_X,
         Row_Y                 => Row_Y,
         Row_Width             => G.Region_Width,
         Row_Height            => G.Row_Height,
         Background_Color      => Background,
         Selected              => Row.Selected,
         Accent_Color          => Row.Accent_Color,
         Accent_Width          => Guikit.Layout.Scaled (3, G.Line_Height),
         Label_X               => G.Text_X + G.Leading_Icon_Width,
         Label_Y               => Label_Y,
         Label_Width           => Label_W,
         Label_Height          => G.Line_Height,
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
            X           => G.Region_X,
            Y           => Row_Y,
            Width       => G.Region_Width,
            Height      => G.Row_Height,
            Name        => To_Unbounded_String (Combined),
            Description => Row.Detail,
            Enabled     => Row.Enabled,
            Selected    => Row.Selected,
            Focused     => False));
   end Draw_Row;

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
      Draw_Chrome   : Boolean := True;
      Row_Height         : Natural := 0;
      Leading_Icon_Width : Natural := 0)
   is
      Line_Height : constant Positive := Config.Line_Height;
      Text_Width  : constant Natural :=
        (if Region_Width > Config.Text_Padding then Region_Width - Config.Text_Padding else 0);
      Title_Rows  : constant Natural := (if Length (Config.Title) > 0 then 1 else 0);
      G : constant Panel_Geometry :=
        (Clip_Width         => Clip_Width,
         Clip_Height        => Clip_Height,
         Region_X           => Region_X,
         Region_Y           => Region_Y,
         Region_Width       => Region_Width,
         Region_Height      => Region_Height,
         Line_Height        => Line_Height,
         --  Rows are Row_Height tall when a larger height is configured,
         --  otherwise one Line_Height each (historic behaviour).
         Row_Height         => (if Row_Height > Line_Height then Row_Height else Line_Height),
         Cell_Width         => Guikit.Layout.Caret_Advance_Width (Line_Height),
         Text_X             => Region_X + Config.Text_Padding,
         Text_Width         => Text_Width,
         Text_Columns       => Text_Width / Guikit.Layout.Caret_Advance_Width (Line_Height),
         Rows_Y             => Region_Y + (Title_Rows * Line_Height),
         Leading_Icon_Width => Leading_Icon_Width);
      Rows_Area_H : constant Natural :=
        (if Region_Height > Title_Rows * Line_Height then Region_Height - Title_Rows * Line_Height else 0);
      Rows_To_Render : constant Natural := Natural'Min (Natural (Rows.Length), Rows_Area_H / G.Row_Height);
   begin
      if Region_Width = 0 or else Region_Height = 0 then
         return;
      end if;

      Draw_Panel_And_Title (Rectangles, Text, Accessibility, G, Config, Draw_Chrome);
      if Rows.Is_Empty then
         Draw_Empty_State (Text, Accessibility, G, Config);
      end if;
      for I in 1 .. Rows_To_Render loop
         Draw_Row (Rectangles, Text, Accessibility, G, Config, Rows (I), I);
      end loop;
   end Draw_Frame;

end Guikit.List_Panel;
