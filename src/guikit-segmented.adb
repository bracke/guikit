with Guikit.Widgets;

package body Guikit.Segmented is

   use Ada.Strings.Unbounded;

   --  The left edge and width of one cell, dividing the region into Cell_Count
   --  equal parts (the last cell absorbs any rounding remainder).
   procedure Cell_Bounds
     (Region_X, Region_Width, Cell_Count, Cell : Natural;
      X : out Natural;
      W : out Natural) is
   begin
      if Cell_Count = 0 then
         X := Region_X;
         W := 0;
         return;
      end if;
      X := Region_X + ((Cell - 1) * Region_Width) / Cell_Count;
      W := (Region_X + (Cell * Region_Width) / Cell_Count) - X;
   end Cell_Bounds;

   function Cell_At
     (Region_X     : Natural;
      Region_Width : Natural;
      Cell_Count   : Natural;
      X            : Integer)
      return Natural
   is
      CX, CW : Natural;
   begin
      if X < Region_X or else X >= Region_X + Region_Width then
         return 0;
      end if;
      for Cell in 1 .. Cell_Count loop
         Cell_Bounds (Region_X, Region_Width, Cell_Count, Cell, CX, CW);
         if X >= CX and then X < CX + CW then
            return Cell;
         end if;
      end loop;
      return 0;
   end Cell_At;

   procedure Build_Frame
     (Segments      : Segment_Vectors.Vector;
      Active        : Natural;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Hover_X       : Integer;
      Hover_Y       : Integer;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Tooltips      : out Guikit.Draw.Tooltip_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      Count : constant Natural := Natural (Segments.Length);
   begin
      for Cell in 1 .. Count loop
         declare
            S      : constant Segment := Segments.Element (Cell);
            CX, CW : Natural;
         begin
            Cell_Bounds (Region_X, Region_Width, Count, Cell, CX, CW);
            declare
               Hovered : constant Boolean :=
                 Hover_X >= CX and then Hover_X < CX + CW
                 and then Hover_Y >= Region_Y and then Hover_Y < Region_Y + Region_Height;
               Fill : constant Guikit.Draw.Render_Color :=
                 (if Cell = Active then Guikit.Draw.Selection_Color
                  elsif Hovered then Guikit.Draw.Hover_Color
                  else Guikit.Draw.Input_Color);
            begin
               Guikit.Widgets.Draw_Button
                 (Rectangles      => Rectangles,
                  Text            => Text,
                  Clip_Width      => Clip_Width,
                  Clip_Height     => Clip_Height,
                  X               => CX,
                  Y               => Region_Y,
                  Width           => CW,
                  Height          => Region_Height,
                  Fill_Color      => Fill,
                  Border_Color    => Guikit.Draw.Border_Color,
                  Padding         => 4,
                  Label_Text      => S.Label,
                  Label_Truncated => False,
                  Label_Height    => Natural'Min (Line_Height, Region_Height),
                  Label_Color     =>
                    (if S.Enabled then Guikit.Draw.Text_Color else Guikit.Draw.Muted_Text_Color));

               if Length (S.Tooltip) > 0 then
                  Tooltips.Append
                    (Guikit.Draw.Tooltip_Command'
                       (X => CX, Y => Region_Y, Width => CW, Height => Region_Height, Text => S.Tooltip));
               end if;

               Accessibility.Append
                 (Guikit.Draw.Accessibility_Node'
                    (Role => Guikit.Draw.Role_Button, X => CX, Y => Region_Y,
                     Width => CW, Height => Region_Height, Name => S.Label,
                     Enabled => S.Enabled, Selected => Cell = Active, others => <>));
            end;
         end;
      end loop;
   end Build_Frame;

end Guikit.Segmented;
