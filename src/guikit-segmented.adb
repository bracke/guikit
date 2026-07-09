with Guikit.Layout;

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
      return Positive'Max (Line_Height, Guikit.Layout.Saturating_Add (Base, 2 * Segment_Padding));
   end Desired_Width;

   --  Sum of the desired widths of the first Upto cells (0 .. length), saturating
   --  so an extreme line height cannot overflow the running total.
   function Prefix_Width
     (Segments : Segment_Vectors.Vector; Line_Height : Positive; Upto : Natural) return Natural
   is
      Sum : Natural := 0;
   begin
      for Cell in 1 .. Upto loop
         Sum := Guikit.Layout.Saturating_Add (Sum, Desired_Width (Segments.Element (Cell), Line_Height));
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
         X := Guikit.Layout.Saturating_Add (Region_X, Left);
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

   --  The visible extent of a span [Start, Start + Size) clamped to [0, Limit).
   function Clip_Extent (Start, Size, Limit : Natural) return Natural is
     (if Start >= Limit then 0
      elsif Start + Size > Limit then Limit - Start
      else Size);

   Label_Padding : constant Natural := 4;

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

      --  Append one rectangle clamped to the drawable clip rectangle.
      procedure Add_Rect (X, Y, W, H : Natural; Color : Guikit.Draw.Render_Color) is
         RW : constant Natural := Clip_Extent (X, W, Clip_Width);
         RH : constant Natural := Clip_Extent (Y, H, Clip_Height);
      begin
         if RW > 0 and then RH > 0 then
            Rectangles.Append (Guikit.Draw.Rectangle_Command'(X => X, Y => Y, Width => RW, Height => RH,
                                                              Color => Color));
         end if;
      end Add_Rect;

      Label_H : constant Natural := Natural'Min (Line_Height, Region_Height);
      Inset   : constant Natural := (if Region_Height > Label_H then (Region_Height - Label_H) / 2 else 0);
   begin
      --  Cell fills and labels.
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
               Label_X : constant Natural := CX + Label_Padding;
               Label_Y : constant Natural := Region_Y + Inset;
               Label_W : constant Natural := (if CW > 2 * Label_Padding then CW - 2 * Label_Padding else 0);
               Draw_W  : constant Natural := Clip_Extent (Label_X, Label_W, Clip_Width);
               Draw_H  : constant Natural := Clip_Extent (Label_Y, Label_H, Clip_Height);
            begin
               Add_Rect (CX, Region_Y, CW, Region_Height, Fill);

               if Draw_W > 0 and then Draw_H > 0 and then Length (S.Label) > 0 then
                  Text.Append
                    (Guikit.Draw.Text_Command'
                       (X => Label_X, Y => Label_Y, Width => Draw_W, Height => Draw_H, Text => S.Label,
                        Color => (if S.Enabled then Guikit.Draw.Text_Color else Guikit.Draw.Muted_Text_Color),
                        Truncated => False, Scale_To_Box => False, Italic => False));
               end if;

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

      --  A single one-pixel divider on each interior cell boundary, drawn over
      --  the fills so adjacent cells share one line rather than abutting borders.
      for Cell in 2 .. Count loop
         declare
            CX, CW : Natural;
         begin
            Cell_Bounds (Segments, Region_X, Region_Width, Line_Height, Cell, CX, CW);
            Add_Rect (CX, Region_Y, 1, Region_Height, Guikit.Draw.Border_Color);
         end;
      end loop;

      --  One outer border framing the whole control.
      if Count > 0 and then Region_Width > 0 and then Region_Height > 0 then
         Add_Rect (Region_X, Region_Y, Region_Width, 1, Guikit.Draw.Border_Color);
         Add_Rect (Region_X, Region_Y + Region_Height - 1, Region_Width, 1, Guikit.Draw.Border_Color);
         Add_Rect (Region_X, Region_Y, 1, Region_Height, Guikit.Draw.Border_Color);
         Add_Rect (Region_X + Region_Width - 1, Region_Y, 1, Region_Height, Guikit.Draw.Border_Color);
      end if;
   end Build_Frame;

end Guikit.Segmented;
