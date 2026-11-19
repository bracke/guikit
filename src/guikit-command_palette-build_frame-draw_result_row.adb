separate (Guikit.Command_Palette.Build_Frame)
procedure Draw_Result_Row (Row : Guikit.Layout.Palette_Result_Row) is
   C          : constant Command := P.Ranked.Element (Row.Result_Index);
   Hovered    : constant Boolean :=
     Hover_X >= Row.X and then Hover_X < Row.X + Row.Width
     and then Hover_Y >= Row.Y and then Hover_Y < Row.Y + Row.Height;
   Sc_Cells   : constant Natural :=
     (if P.Config.Show_Shortcuts then Guikit.Utf8.Display_Units (To_String (C.Shortcut)) else 0);
   Sc_W       : constant Natural := (if Sc_Cells > 0 then Sc_Cells * Cell_W else 0);
   Sc_X       : constant Natural :=
     (if Sc_W > 0 and then Row.Width > Sc_W + 2 * Pad then Row.X + Row.Width - Pad - Sc_W else 0);
   Label_X    : constant Natural := Row.X + Pad + Gutter;
   Label_Y    : constant Natural := Row.Y + Row_Pad;
   Right_Edge : constant Natural := (if Sc_X > 0 then Sc_X else Row.X + Row.Width - Pad);
   Label_W    : constant Natural :=
     (if Right_Edge > Label_X + Pad then Right_Edge - Label_X - Pad else 0);
   Label_Trunc : Boolean;
   --  A row with no description has nothing to truncate, and nothing
   --  assigns this: Fit_To_Cells sets it, and it is only called when
   --  Has_Desc. The aggregate below reads it either way, so without a
   --  value here it read whatever the stack happened to hold -- and a
   --  Boolean whose byte is neither 0 nor 1 raises Constraint_Error
   --  ("invalid data"). It only ever showed up once the optimiser
   --  stopped hiding it.
   Desc_Trunc  : Boolean := False;
   Label_Fit  : constant String :=
     Fit_To_Cells (To_String (C.Label), Label_W / Natural'Max (1, Cell_W), Label_Trunc);
   Has_Desc   : constant Boolean := Row.Height > LH and then Length (C.Description) > 0;
   Desc_Fit   : constant String :=
     (if Has_Desc
      then Fit_To_Cells (To_String (C.Description), Label_W / Natural'Max (1, Cell_W), Desc_Trunc)
      else "");
begin
   P.Rows.Append
     (Row_Rect'(Result_Index => Row.Result_Index,
                X => Row.X, Y => Row.Y, W => Row.Width, H => Row.Height));

   if P.Config.Show_Icons and then C.Icon.Width > 0 then
      declare
         Display : constant Natural :=
           Natural'Min
             (Icon_Slot, (if Row.Height > Icon_Margins then Row.Height - Icon_Margins else Row.Height));
      begin
         Icons.Append
           (Guikit.Draw.Icon_Command'
              (X                => Row.X + Pad + (Icon_Slot - Display) / 2,
               Y                => Row.Y + (if Row.Height > Display then (Row.Height - Display) / 2 else 0),
               Size             => Display,
               Thumbnail_Width  => C.Icon.Width,
               Thumbnail_Height => C.Icon.Height,
               Thumbnail_Pixels => C.Icon.Pixels,
               others           => <>));
      end;
   end if;

   Guikit.Widgets.Draw_Palette_Row
     (Rectangles         => Rectangles,
      Text               => Text,
      Clip_Width         => Clip_Width,
      Clip_Height        => Clip_Height,
      Row_X              => Row.X,
      Row_Y              => Row.Y,
      Row_Width          => Row.Width,
      Row_Height         => Row.Height,
      Background_Color   =>
        (if Row.Selected then Guikit.Draw.Selection_Color
         elsif Hovered then Guikit.Draw.Hover_Color
         else Guikit.Draw.Pane_Color),
      Selected           => Row.Selected,
      Accent_Color       => Guikit.Draw.Border_Color,
      Accent_Width       => Guikit.Layout.Scaled (3, LH),
      Label_X            => Label_X,
      Label_Y            => Label_Y,
      Label_Width        => Label_W,
      Label_Height       => Natural'Min (LH, Row.Height),
      Label_Text         => To_Unbounded_String (Label_Fit),
      Label_Truncated    => Label_Trunc,
      Label_Color        =>
        (if C.Enabled then Guikit.Draw.Text_Color else Guikit.Draw.Muted_Text_Color),
      Shortcut_X         => Sc_X,
      Shortcut_Width     => Sc_W,
      Shortcut_Text      => (if Sc_W > 0 then C.Shortcut else Null_Unbounded_String),
      Shortcut_Truncated => False,
      Shortcut_Color     => Guikit.Draw.Muted_Text_Color,
      Description_Y      => Label_Y + LH,
      Description_Width  => (if Has_Desc then Label_W else 0),
      Description_Height =>
        (if Has_Desc then Natural'Min (LH, Row.Height - Row_Pad - LH) else 0),
      Description_Text   => To_Unbounded_String (Desc_Fit),
      Description_Truncated => Desc_Trunc,
      Description_Color  => Guikit.Draw.Muted_Text_Color);

   Accessibility.Append
     (Guikit.Draw.Accessibility_Node'
        (Role => Guikit.Draw.Role_List_Item, X => Row.X, Y => Row.Y,
         Width => Row.Width, Height => Row.Height, Name => C.Label,
         Description => C.Description, Enabled => C.Enabled, Selected => Row.Selected,
         others => <>));
end Draw_Result_Row;
