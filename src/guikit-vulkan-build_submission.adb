separate (Guikit.Vulkan)
function Build_Submission
  (Rectangles         : Guikit.Draw.Rectangle_Command_Vectors.Vector;
   Triangles          : Guikit.Draw.Triangle_Command_Vectors.Vector;
   Icons              : Guikit.Draw.Icon_Command_Vectors.Vector;
   Overlay_Rectangles : Guikit.Draw.Rectangle_Command_Vectors.Vector;
   Layout             : Guikit.Draw.Layout_Metrics;
   Theme              : Guikit.Draw.Theme_Kind;
   Text               : Guikit.Draw.Text_Render_Result)
   return Submission_Batch
is
   --  A glyph's texture coordinates from its pixel rectangle and the atlas
   --  as this frame has it: the atlas grows taller, and a glyph command
   --  kept from an earlier frame still has the U and V of the old height.
   --  Glyphs without a rectangle (0 wide) keep the U and V they came with.
   function Glyph_U (Pixel, Known_Width : Natural; Given : Float) return Float is
     (if Known_Width = 0 or else Text.Atlas_Width = 0 then Given
      else Float (Pixel) / Float (Text.Atlas_Width));

   function Glyph_V (Pixel, Known_Width : Natural; Given : Float) return Float is
     (if Known_Width = 0 or else Text.Atlas_Height = 0 then Given
      else Float (Pixel) / Float (Text.Atlas_Height));

   Result : Submission_Batch;

   function Clip_X (Pixel_X : Float) return Float is
   begin
      if Layout.Width = 0 then
         return -1.0;
      else
         return (Pixel_X / Float (Layout.Width)) * 2.0 - 1.0;
      end if;
   end Clip_X;

   function Clip_Y (Pixel_Y : Float) return Float is
   begin
      if Layout.Height = 0 then
         return 1.0;
      else
         return 1.0 - (Pixel_Y / Float (Layout.Height)) * 2.0;
      end if;
   end Clip_Y;

   procedure Append_Quad
     (X        : Float;
      Y        : Float;
      Width    : Float;
      Height   : Float;
      U0       : Float;
      V0       : Float;
      U1       : Float;
      V1       : Float;
      Color    : Guikit.Draw.Render_Color;
      Textured : Boolean;
      Texture  : Texture_Source := Texture_None)
   is
      Left   : constant Float := Clip_X (X);
      Right  : constant Float := Clip_X (X + Width);
      Top    : constant Float := Clip_Y (Y);
      Bottom : constant Float := Clip_Y (Y + Height);

      procedure Append
        (VX : Float;
         VY : Float;
         VU : Float;
         VV : Float) is
      begin
         Result.Vertices.Append
           (Vertex'
              (X        => VX,
               Y        => VY,
               U        => VU,
               V        => VV,
               Color    => Color,
               Textured => Textured,
               Texture  => Texture));
      end Append;
   begin
      if Width <= 0.0 or else Height <= 0.0 then
         return;
      elsif Natural (Result.Vertices.Length) > Max_Batch_Vertices - 6 then
         return;
      end if;

      Append (Left, Top, U0, V0);
      Append (Right, Top, U1, V0);
      Append (Right, Bottom, U1, V1);
      Append (Left, Top, U0, V0);
      Append (Right, Bottom, U1, V1);
      Append (Left, Bottom, U0, V1);
   end Append_Quad;

   procedure Append_Triangle
     (X1    : Float;
      Y1    : Float;
      X2    : Float;
      Y2    : Float;
      X3    : Float;
      Y3    : Float;
      Color : Guikit.Draw.Render_Color)
   is
   begin
      if Natural (Result.Vertices.Length) > Max_Batch_Vertices - 3 then
         return;
      end if;

      Result.Vertices.Append
        (Vertex'
           (X        => Clip_X (X1),
            Y        => Clip_Y (Y1),
            U        => 0.0,
            V        => 0.0,
            Color    => Color,
            Textured => False,
            Texture  => Texture_None));
      Result.Vertices.Append
        (Vertex'
           (X        => Clip_X (X2),
            Y        => Clip_Y (Y2),
            U        => 0.0,
            V        => 0.0,
            Color    => Color,
            Textured => False,
            Texture  => Texture_None));
      Result.Vertices.Append
        (Vertex'
           (X        => Clip_X (X3),
            Y        => Clip_Y (Y3),
            U        => 0.0,
            V        => 0.0,
            Color    => Color,
            Textured => False,
            Texture  => Texture_None));
   end Append_Triangle;

   --  The icons to draw, plus the colour glyphs the text layer could not draw
   --  as glyphs. An emoji is a picture, so it arrives here rather than in the
   --  glyph quads, and from this point on it is an icon like any other.
   All_Icons : constant Guikit.Draw.Icon_Command_Vectors.Vector :=
     (if Text.Colour_Icons.Is_Empty then Icons else Icons & Text.Colour_Icons);

   --  Atlas tile placement, filled by Build_Icon_Atlas and read by the main
   --  and overlay icon vertex passes. Indexed by tile, not by icon: icons
   --  that would rasterize to the same pixels share one.
   Icon_Tile_Layout : Icon_Tile_Rect_Vectors.Vector;

   --  The tile each atlas icon draws from (index = 1-based atlas
   --  icon, value = 1-based index into Icon_Tile_Layout).
   Icon_Tile_Of : Natural_Vectors.Vector;

   --  Fill Result's icon atlas from All_Icons: the tile each atlas icon
   --  draws from (Icon_Tile_Of, Icon_Tile_Layout) and the pixels, reused
   --  from Icon_Atlas_Cache when an identical atlas was built before. Leaves
   --  the atlas clean when there are no atlas icons or too many tiles.
   procedure Build_Icon_Atlas is separate;

   --  The frame's size and theme, the text atlas as Text hands it over, the
   --  icon atlas, and which of the two textures this frame uploads.
   procedure Describe_Textures is
   begin
      Result.Width := Layout.Width;
      Result.Height := Layout.Height;
      Result.Palette_Theme := Theme;
      Result.Atlas_Width := Text.Atlas_Width;
      Result.Atlas_Height := Text.Atlas_Height;
      Result.Atlas_Pixels := Text.Atlas_Pixels;
      Result.Atlas_Bytes := Text.Atlas_Bytes;
      Result.Atlas_Dirty := Text.Atlas_Dirty;
      Result.Atlas_Version := Text.Atlas_Version;
      Result.Text_Atlas_Used :=
        Text.Status = Guikit.Draw.Text_Render_Success
        and then
          (not Text.Glyphs.Is_Empty
           or else not Text.Overlay_Glyphs.Is_Empty);
      Build_Icon_Atlas;
      Result.Icon_Texture_Format := Icon_Upload_Texture_Format (Result);
      Result.Texture_Count :=
        (if Result.Atlas_Dirty and then Result.Icon_Atlas_Dirty then 2
         elsif Result.Atlas_Dirty or else Result.Icon_Atlas_Dirty then 1
         else 0);
      Result.Uses_Separate_Text_And_Icon_Textures :=
        Result.Text_Atlas_Used and then Result.Icon_Atlas_Dirty;
   end Describe_Textures;

   --  Each rectangle of List as an untextured quad; Counter grows by the
   --  vertices they add.
   procedure Emit_Rectangles
     (List    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Counter : in out Natural) is
   begin
      for Rectangle of List loop
         declare
            Before : constant Natural := Natural (Result.Vertices.Length);
         begin
            Append_Quad
              (X        => Float (Rectangle.X),
               Y        => Float (Rectangle.Y),
               Width    => Float (Rectangle.Width),
               Height   => Float (Rectangle.Height),
               U0       => 0.0,
               V0       => 0.0,
               U1       => 0.0,
               V1       => 0.0,
               Color    => Rectangle.Color,
               Textured => False,
               Texture  => Texture_None);
            Counter := Counter + Natural (Result.Vertices.Length) - Before;
         end;
      end loop;
   end Emit_Rectangles;

   --  Each triangle as three untextured vertices.
   procedure Emit_Triangles is
   begin
      for Triangle of Triangles loop
         declare
            Before : constant Natural := Natural (Result.Vertices.Length);
         begin
            Append_Triangle
              (X1    => Triangle.X1,
               Y1    => Triangle.Y1,
               X2    => Triangle.X2,
               Y2    => Triangle.Y2,
               X3    => Triangle.X3,
               Y3    => Triangle.Y3,
               Color => Triangle.Color);
            Result.Triangle_Vertex_Count :=
              Result.Triangle_Vertex_Count + Natural (Result.Vertices.Length) - Before;
         end;
      end loop;
   end Emit_Triangles;

   --  One atlas icon as a quad textured with its tile; Atlas_Icon is its
   --  1-based place among the atlas icons, which picks the tile.
   procedure Emit_Atlas_Icon
     (Icon       : Guikit.Draw.Icon_Command;
      Atlas_Icon : Positive)
   is
      Atlas_W : constant Natural := Result.Icon_Atlas_Width;
      Atlas_H : constant Natural := Result.Icon_Atlas_Height;
      Tile    : constant Icon_Tile_Rect :=
        Icon_Tile_Layout.Element (Icon_Tile_Of.Element (Atlas_Icon));
      Draw_W  : constant Natural :=
        (if Icon.Draw_Width > 0 then Icon.Draw_Width else Icon.Size);
      Draw_H  : constant Natural :=
        (if Icon.Draw_Height > 0 then Icon.Draw_Height else Icon.Size);
   begin
      Append_Quad
        (X        => Float (Icon.X),
         Y        => Float (Icon.Y),
         Width    => Float (Draw_W),
         Height   => Float (Draw_H),
         U0       => (if Atlas_W = 0 then 0.0 else Float (Tile.X) / Float (Atlas_W)),
         V0       => (if Atlas_H = 0 then 0.0 else Float (Tile.Y) / Float (Atlas_H)),
         U1       => (if Atlas_W = 0 then 0.0 else Float (Tile.X + Tile.W) / Float (Atlas_W)),
         V1       => (if Atlas_H = 0 then 0.0 else Float (Tile.Y + Tile.H) / Float (Atlas_H)),
         Color    => Guikit.Draw.Icon_Document_Color,
         Textured => True,
         Texture  => Texture_Icon_Atlas);
   end Emit_Atlas_Icon;

   --  Main-layer icons only. Overlay icons keep their atlas slot in the
   --  index sequence (so every icon's UV still matches its atlas tile)
   --  but are emitted later, in the overlay pass, so they sit on top of
   --  an opaque overlay panel.
   procedure Emit_Main_Icons is
      Source_Icon_Index : Natural := 0;
   begin
      for Icon of All_Icons loop
         if Is_Atlas_Icon (Icon) then
            if not Icon.Overlay then
               declare
                  Before : constant Natural := Natural (Result.Vertices.Length);
               begin
                  Emit_Atlas_Icon (Icon, Source_Icon_Index + 1);
                  Result.Icon_Vertex_Count :=
                    Result.Icon_Vertex_Count + Natural (Result.Vertices.Length) - Before;
                  if Natural (Result.Vertices.Length) > Before then
                     Result.Icon_Quad_Count := Result.Icon_Quad_Count + 1;
                  end if;
               end;
            end if;
            Source_Icon_Index := Source_Icon_Index + 1;
         end if;
      end loop;
   end Emit_Main_Icons;

   --  Overlay-layer icons (e.g. the Quick Look image preview): emitted
   --  after the overlay rectangles so they sit on top of the opaque panel,
   --  using the same atlas index sequence as the main icon pass.
   procedure Emit_Overlay_Icons is
      Source_Icon_Index : Natural := 0;
   begin
      for Icon of All_Icons loop
         if Is_Atlas_Icon (Icon) then
            if Icon.Overlay then
               declare
                  Before : constant Natural := Natural (Result.Vertices.Length);
               begin
                  Emit_Atlas_Icon (Icon, Source_Icon_Index + 1);
                  Result.Overlay_Vertex_Count :=
                    Result.Overlay_Vertex_Count + Natural (Result.Vertices.Length) - Before;
               end;
            end if;
            Source_Icon_Index := Source_Icon_Index + 1;
         end if;
      end loop;
   end Emit_Overlay_Icons;

   --  Each glyph of List as a quad textured from the text atlas; Counter
   --  grows by the vertices they add.
   procedure Emit_Glyphs
     (List    : Guikit.Draw.Glyph_Command_Vectors.Vector;
      Counter : in out Natural) is
   begin
      for Glyph of List loop
         declare
            Before : constant Natural := Natural (Result.Vertices.Length);
         begin
            Append_Quad
              (X        => Glyph.X,
               Y        => Glyph.Y,
               Width    => Glyph.Width,
               Height   => Glyph.Height,
               U0       => Glyph_U (Glyph.Atlas_X, Glyph.Atlas_W, Glyph.U0),
               V0       => Glyph_V (Glyph.Atlas_Y, Glyph.Atlas_W, Glyph.V0),
               U1       => Glyph_U (Glyph.Atlas_X + Glyph.Atlas_W, Glyph.Atlas_W, Glyph.U1),
               V1       => Glyph_V (Glyph.Atlas_Y + Glyph.Atlas_H, Glyph.Atlas_W, Glyph.V1),
               Color    => Glyph.Color,
               Textured => True,
               Texture  => Texture_Text_Atlas);
            Counter := Counter + Natural (Result.Vertices.Length) - Before;
         end;
      end loop;
   end Emit_Glyphs;
begin
   Describe_Textures;

   --  The main layer, back to front: rectangles, triangles, icons, glyphs.
   Emit_Rectangles (Rectangles, Result.Rectangle_Vertex_Count);
   Emit_Triangles;
   if Result.Icon_Atlas_Dirty then
      Emit_Main_Icons;
   end if;

   if Text.Status = Guikit.Draw.Text_Render_Success then
      Emit_Glyphs (Text.Glyphs, Result.Glyph_Vertex_Count);

      --  The overlay layer on top of it, in the same order.
      Emit_Rectangles (Overlay_Rectangles, Result.Overlay_Vertex_Count);
      if Result.Icon_Atlas_Dirty then
         Emit_Overlay_Icons;
      end if;
      Emit_Glyphs (Text.Overlay_Glyphs, Result.Overlay_Vertex_Count);
   end if;

   return Result;
end Build_Submission;
