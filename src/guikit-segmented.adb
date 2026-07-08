with Guikit.Layout;
with Guikit.Widgets;

package body Guikit.Segmented is

   use Ada.Strings.Unbounded;

   --  Horizontal breathing room added to each side of a cell's measured label
   --  when computing its desired (pre-scaling) width.
   Segment_Padding : constant Natural := 8;

   --  A cell's desired width before scaling to the region: its measured label
   --  width plus padding, never narrower than one line height.
   function Desired_Width (S : Segment; Line_Height : Positive) return Positive is
      Cell_W : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Base   : constant Natural := Guikit.Layout.Label_Pixel_Width (To_String (S.Label), Cell_W);
   begin
      return Positive'Max (Line_Height, Base + 2 * Segment_Padding);
   end Desired_Width;

   --  Sum of the desired widths of the first Upto cells (0 .. length).
   function Prefix_Width
     (Segments : Segment_Vectors.Vector; Line_Height : Positive; Upto : Natural) return Natural
   is
      Sum : Natural := 0;
   begin
      for Cell in 1 .. Upto loop
         Sum := Sum + Desired_Width (Segments.Element (Cell), Line_Height);
      end loop;
      return Sum;
   end Prefix_Width;

   procedure Cell_Bounds
     (Segments     : Segment_Vectors.Vector;
      Region_X     : Natural;
      Region_Width : Natural;
      Line_Height  : Positive;
      Cell         : Positive;
      X            : out Natural;
      Width        : out Natural)
   is
      Count : constant Natural := Natural (Segments.Length);
      Total : constant Natural := Prefix_Width (Segments, Line_Height, Count);

      --  Desired-width offset scaled onto the region, in 64-bit so a large
      --  region width cannot overflow the product.
      function Scaled (Offset : Natural) return Natural is
        (if Total = 0 then 0
         else Natural (Long_Long_Integer (Offset) * Long_Long_Integer (Region_Width)
                       / Long_Long_Integer (Total)));
   begin
      if Cell > Count then
         X := Region_X;
         Width := 0;
         return;
      end if;
      declare
         Left  : constant Natural := Scaled (Prefix_Width (Segments, Line_Height, Cell - 1));
         Right : constant Natural := Scaled (Prefix_Width (Segments, Line_Height, Cell));
      begin
         X := Region_X + Left;
         Width := Right - Left;
      end;
   end Cell_Bounds;

   function Cell_At
     (Segments     : Segment_Vectors.Vector;
      Region_X     : Natural;
      Region_Width : Natural;
      Line_Height  : Positive;
      X            : Integer)
      return Natural
   is
      CX, CW : Natural;
   begin
      if X < Region_X or else X >= Region_X + Region_Width then
         return 0;
      end if;
      for Cell in 1 .. Natural (Segments.Length) loop
         Cell_Bounds (Segments, Region_X, Region_Width, Line_Height, Cell, CX, CW);
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
            Cell_Bounds (Segments, Region_X, Region_Width, Line_Height, Cell, CX, CW);
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
