with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Interfaces;

with Guikit.Layout;
with Guikit.Utf8;

package body Guikit.Text is

   use type Textrender.Status_Code;

   function Loaded (R : Renderer) return Boolean is (R.Is_Loaded);

   function Initialize
     (R              : in out Renderer;
      Font_Path      : String;
      Fallback_Paths : Font_Path_Vectors.Vector;
      Pixel_Size     : Positive := 16;
      Cell_Width     : Positive := 10;
      Cell_Height    : Positive := 20;
      Atlas_Width    : Positive := 1024;
      Atlas_Height   : Positive := 1024)
      return Guikit.Draw.Text_Render_Status
   is
      Status : Textrender.Status_Code;
   begin
      R.Is_Loaded := False;

      if Font_Path = "" then
         Textrender.Reset (R.Backend);
         return Guikit.Draw.Text_Render_Font_Load_Failed;
      end if;

      Status :=
        Textrender.Load_Font
          (R            => R.Backend,
           Path         => Font_Path,
           Pixel_Size   => Pixel_Size,
           Cell_Width   => Cell_Width,
           Cell_Height  => Cell_Height,
           Atlas_Width  => Atlas_Width,
           Atlas_Height => Atlas_Height);
      if Status /= Textrender.Success then
         return Guikit.Draw.Text_Render_Font_Load_Failed;
      end if;

      --  Best-effort: a missing or unloadable fallback is non-fatal, so the
      --  per-font status is intentionally discarded.
      for Path of Fallback_Paths loop
         declare
            Added : constant Textrender.Status_Code := Textrender.Add_Fallback_Font (R.Backend, Path);
            pragma Unreferenced (Added);
         begin
            null;
         end;
      end loop;

      R.Is_Loaded    := True;
      R.Cell_Width   := Cell_Width;
      R.Cell_Height  := Cell_Height;
      R.Atlas_Width  := Atlas_Width;
      R.Atlas_Height := Atlas_Height;
      return Guikit.Draw.Text_Render_Success;
   end Initialize;

   procedure Set_Image_Decoder
     (R      : in out Renderer;
      Extent : Textrender.Image_Extent_Reader;
      Decode : Textrender.Image_Decoder) is
   begin
      Textrender.Set_Image_Decoder (R.Backend, Extent, Decode);
   end Set_Image_Decoder;

   package Codepoint_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Natural);

   function Build_Glyphs
     (R        : in out Renderer;
      Commands : Guikit.Draw.Text_Command_Vectors.Vector;
      Overlay  : Guikit.Draw.Text_Command_Vectors.Vector)
      return Guikit.Draw.Text_Render_Result
   is
      use Ada.Strings.Unbounded;
      use Guikit.Draw;
      function Sat_Add (Left, Right : Natural) return Natural
        renames Guikit.Layout.Saturating_Add;
      function Sat_Mul (Value, Factor : Natural) return Natural
        renames Guikit.Layout.Saturating_Multiply;

      Result : Text_Render_Result;

      --  Spans both layers: an overlay emoji shares the main layer's tile.
      Carried : Codepoint_Vectors.Vector;

      function Pixel_Snapped (Value : Float) return Float is
      begin
         if Value <= 0.0 then
            return 0.0;
         elsif Value >= Float (Integer'Last - 1) then
            return Float (Integer'Last - 1);
         else
            return Float (Integer (Value + 0.5));
         end if;
      end Pixel_Snapped;

      procedure Append_Glyphs
        (Cmds    : Text_Command_Vectors.Vector;
         Glyphs  : in out Glyph_Command_Vectors.Vector;
         Overlay : Boolean)
      is
         --  Whether this codepoint has already handed its picture over.
         --
         --  Icons naming the same identity share one tile, and the backend
         --  rasterizes it from the first of them, so every copy after that was
         --  allocated, filled and never read. Twenty of one emoji on a line came
         --  to thirty thousand bytes of which fifteen hundred were used.
         function Already_Carried (Code : Textrender.Codepoint) return Boolean is
         begin
            for Seen of Carried loop
               if Seen = Natural (Code) then
                  return True;
               end if;
            end loop;

            return False;
         end Already_Carried;

         --  A codepoint the font holds as a picture leaves as an icon rather
         --  than a glyph quad. The quads read the alpha atlas, and a coverage
         --  value has nowhere to keep a colour; the icon pass already draws
         --  arbitrary RGBA, so the picture goes there instead.
         --
         --  False when there is no decoder installed, no picture for this
         --  codepoint, or it decodes to nothing -- in which case the caller
         --  carries on and looks for an outline as it always did.
         function Emit_Colour_Glyph
           (Code     : Textrender.Codepoint;
            Origin_X : Float;
            Cell_Y   : Float)
            return Boolean
         is
            Colour    : Textrender.Colour_Glyph;
            Pixels    : access constant Textrender.Rgba_Buffer;
            Synthetic : Textrender.Glyph_Metric;
            Place     : Textrender.Glyph_Placement;
            Icon      : Guikit.Draw.Icon_Command;
         begin
            if Textrender.Get_Colour_Glyph (R.Backend, Code, Colour) /= Textrender.Success
              or else Colour.Width = 0
              or else Colour.Height = 0
            then
               return False;
            end if;

            Pixels := Textrender.Colour_Sheet_Pixels (R.Backend);

            if Pixels = null then
               return False;
            end if;

            --  Placed by the same arithmetic an outlined glyph is, so it sits on
            --  the line with the text beside it rather than at the top of a cell.
            Synthetic :=
              (X => 0, Y => 0, W => Colour.Width, H => Colour.Height,
               U0 => 0.0, V0 => 0.0, U1 => 0.0, V1 => 0.0,
               Advance_X => Colour.Advance_X,
               Bearing_X => 0.0,
               Bearing_Y => Colour.Bearing_Y);
            Place := Textrender.Place_Glyph_In_Cell (R.Backend, Synthetic, Origin_X, Cell_Y);

            Icon.X := Natural (Float'Max (0.0, Pixel_Snapped (Place.X)));
            Icon.Y := Natural (Float'Max (0.0, Pixel_Snapped (Place.Y)));
            Icon.Size := Colour.Width;
            Icon.Draw_Width := Colour.Width;
            Icon.Draw_Height := Colour.Height;
            Icon.Thumbnail_Width := Colour.Width;
            Icon.Thumbnail_Height := Colour.Height;
            Icon.Overlay := Overlay;

            --  The same emoji twice is the same picture, so it is one tile.
            Icon.Shared_Tile_Id :=
              To_Unbounded_String ("colour-glyph:" & Textrender.Codepoint'Image (Code));

            --  Only the first of an identity needs to carry the picture; the
            --  rest are drawn from the tile it produced.
            if not Already_Carried (Code) then
               Icon.Thumbnail_Pixels.Reserve_Capacity
                 (Ada.Containers.Count_Type (Colour.Width * Colour.Height * 4));

               --  Copied out of the sheet: this backend has no binding to spare
               --  for one, so the picture rides the icon atlas instead.
               for Row in 0 .. Colour.Height - 1 loop
                  for Column in 0 .. Colour.Width - 1 loop
                     declare
                        At_Sheet : constant Natural :=
                          ((Colour.Y + Row) * Textrender.Colour_Sheet_Width (R.Backend)
                           + Colour.X + Column) * 4;
                     begin
                        for Channel in 0 .. 3 loop
                           Icon.Thumbnail_Pixels.Append
                             (Interfaces.Unsigned_8 (Pixels (At_Sheet + Channel)));
                        end loop;
                     end;
                  end loop;
               end loop;

               Carried.Append (Natural (Code));
            end if;

            Result.Colour_Icons.Append (Icon);
            return True;
         end Emit_Colour_Glyph;
      begin
         for Text of Cmds loop
            declare
               Content : constant String := To_String (Text.Text);
               Cell_X  : Float := Float (Text.X);
               Cell_Y  : constant Float := Float (Text.Y);
               Limit_X : constant Float := Float (Sat_Add (Text.X, Text.Width));
               Base_X  : Float := Float (Text.X);
               Index   : Integer := Content'First;
            begin
               while Index <= Content'Last loop
                  declare
                     Unit_Start        : constant Integer := Index;
                     Decoded_Codepoint : Natural;
                     Codepoint         : Textrender.Codepoint;
                     Metrics           : Textrender.Glyph_Metric;
                     Placement         : Textrender.Glyph_Placement;
                     Status            : Textrender.Status_Code;
                     Unit_Width        : Natural;
                     In_Colour         : Boolean := False;
                  begin
                     Guikit.Utf8.Decode_Next_Codepoint (Content, Index, Decoded_Codepoint);
                     Unit_Width := Guikit.Utf8.Display_Units (Content (Unit_Start .. Index - 1));
                     if Unit_Width > 0
                       and then Cell_X + Float (Sat_Mul (Unit_Width, R.Cell_Width)) > Limit_X
                     then
                        exit;
                     end if;

                     Codepoint := Textrender.Codepoint (Decoded_Codepoint);

                     if Textrender.Has_Colour_Glyph (R.Backend, Codepoint) then
                        In_Colour :=
                          Emit_Colour_Glyph
                            (Codepoint,
                             (if Unit_Width = 0 then Base_X else Cell_X),
                             Cell_Y);
                     end if;

                     if In_Colour then
                        --  Drawn as an icon; leave nothing for the glyph pass.
                        Metrics :=
                          (X => 0, Y => 0, W => 0, H => 0,
                           U0 => 0.0, V0 => 0.0, U1 => 0.0, V1 => 0.0,
                           Advance_X => 0.0, Bearing_X => 0.0, Bearing_Y => 0.0);
                        Status := Textrender.Success;
                     else
                        Status :=
                          Textrender.Get_Glyph
                            (R.Backend, Codepoint, Metrics,
                             Style => (if Text.Italic then Textrender.Italic else Textrender.Regular));
                     end if;

                     if not In_Colour and then Status /= Textrender.Success then
                        if Unit_Width > 0 then
                           Result.Missing_Glyph_Count := Sat_Add (Result.Missing_Glyph_Count, 1);
                           Codepoint := Textrender.Codepoint (Character'Pos ('?'));
                           Status :=
                             Textrender.Get_Glyph
                               (R.Backend, Codepoint, Metrics,
                                Style => (if Text.Italic then Textrender.Italic else Textrender.Regular));
                           if Status /= Textrender.Success then
                              Metrics :=
                                (X => 0, Y => 0, W => 0, H => 0,
                                 U0 => 0.0, V0 => 0.0, U1 => 0.0, V1 => 0.0,
                                 Advance_X => 0.0, Bearing_X => 0.0, Bearing_Y => 0.0);
                           end if;
                        else
                           if Guikit.Utf8.Is_Required_Zero_Width_Codepoint (Decoded_Codepoint) then
                              Result.Missing_Glyph_Count := Sat_Add (Result.Missing_Glyph_Count, 1);
                           end if;
                           Metrics :=
                             (X => 0, Y => 0, W => 0, H => 0,
                              U0 => 0.0, V0 => 0.0, U1 => 0.0, V1 => 0.0,
                              Advance_X => 0.0, Bearing_X => 0.0, Bearing_Y => 0.0);
                        end if;
                     end if;

                     if Metrics.W > 0 and then Metrics.H > 0 then
                        declare
                           Origin_X : constant Float := (if Unit_Width = 0 then Base_X else Cell_X);

                           --  How much of the box a fitted glyph fills, before
                           --  rounding: 86% of the tighter of the two axes.
                           Box_Fit  : constant Float :=
                             (if Text.Scale_To_Box
                              then Float'Max
                                (1.0,
                                 0.86 * Float'Min
                                   (Float (Text.Width) / Float (Metrics.W),
                                    Float (Text.Height) / Float (Metrics.H)))
                              else 1.0);

                           --  Whole numbers only, because the atlas is sampled
                           --  with FILTER_NEAREST. A fractional magnification
                           --  duplicates some source columns and not others: at
                           --  1.29x an 8-pixel glyph becomes 10 pixels by using
                           --  two of its columns twice, which on a diagonal like
                           --  the close button's multiplication sign makes one
                           --  stroke visibly thicker than the other. At a whole
                           --  factor every source pixel becomes the same size
                           --  block and the shape survives; below 2x that means
                           --  drawing it at its rasterized size, which is sharp
                           --  rather than merely bigger.
                           --
                           --  Linear filtering would be the other answer and is
                           --  not available per quad: the sampler is fixed in the
                           --  descriptor set, the shaders are embedded SPIR-V
                           --  with no source to branch in, and making the one
                           --  sampler linear would soften every 1:1 glyph in the
                           --  interface to fix magnified ones.
                           Scale    : constant Float := Float (Natural (Float'Floor (Box_Fit)));
                           Scaled_W : constant Float := Float (Metrics.W) * Scale;
                           Scaled_H : constant Float := Float (Metrics.H) * Scale;
                           Draw_X   : Float;
                           Draw_Y   : Float;
                        begin
                           Placement := Textrender.Place_Glyph_In_Cell (R.Backend, Metrics, Origin_X, Cell_Y);
                           if Text.Scale_To_Box then
                              Draw_X := Float (Text.X) + (Float (Text.Width) - Scaled_W) / 2.0;
                              Draw_Y := Float (Text.Y) + (Float (Text.Height) - Scaled_H) / 2.0;
                           elsif Decoded_Codepoint = 16#2026# then
                              --  Snap the ellipsis to the left of its cell so it
                              --  hugs the preceding character.
                              Draw_X := Origin_X;
                              Draw_Y := Placement.Y;
                           else
                              Draw_X := Placement.X;
                              Draw_Y := Placement.Y;
                           end if;
                           Glyphs.Append
                             (Glyph_Command'
                                (X         => Pixel_Snapped (Draw_X),
                                 Y         => Pixel_Snapped (Draw_Y),
                                 Width     => Pixel_Snapped (Scaled_W),
                                 Height    => Pixel_Snapped (Scaled_H),
                                 U0        => Metrics.U0,
                                 V0        => Metrics.V0,
                                 U1        => Metrics.U1,
                                 V1        => Metrics.V1,
                                 Color     => Text.Color,
                                 Codepoint => Natural (Codepoint)));
                        end;
                     end if;

                     if Unit_Width > 0 then
                        Base_X := Cell_X;
                        Cell_X := Cell_X + Float (Sat_Mul (Unit_Width, R.Cell_Width));
                     end if;
                  end;
               end loop;
            end;
         end loop;
      end Append_Glyphs;
   begin
      if not R.Is_Loaded then
         return Result;
      end if;

      Result.Status       := Text_Render_Success;
      Result.Atlas_Width  := R.Atlas_Width;
      Result.Atlas_Height := R.Atlas_Height;
      Result.Atlas_Bytes  := Sat_Mul (R.Atlas_Width, R.Atlas_Height);

      Append_Glyphs (Commands, Result.Glyphs, Overlay => False);
      Append_Glyphs (Overlay, Result.Overlay_Glyphs, Overlay => True);

      Result.Atlas_Dirty := Textrender.Atlas_Dirty (R.Backend);
      if Textrender.Atlas_Pixels (R.Backend) /= null then
         Result.Atlas_Pixels := Textrender.Atlas_Pixels (R.Backend).all'Address;
      end if;
      return Result;
   end Build_Glyphs;

end Guikit.Text;
