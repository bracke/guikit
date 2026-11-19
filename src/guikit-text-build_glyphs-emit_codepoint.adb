separate (Guikit.Text.Build_Glyphs)
procedure Emit_Codepoint
  (Glyphs            : in out Glyph_Command_Vectors.Vector;
   Overlay           : Boolean;
   Text              : Text_Command;
   Decoded_Codepoint : Natural;
   Unit_Width        : Natural;
   Origin_X          : Float;
   Cell_Y            : Float;
   Hug_Right         : Boolean)
is
   Codepoint : Textrender.Codepoint;
   Metrics   : Textrender.Glyph_Metric;
   Placement : Textrender.Glyph_Placement;
   Status    : Textrender.Status_Code;
   In_Colour : Boolean := False;
begin
   Codepoint := Textrender.Codepoint (Decoded_Codepoint);

   if Textrender.Has_Colour_Glyph (R.Backend, Codepoint) then
      In_Colour :=
        Emit_Colour_Glyph
          (Codepoint,
           Origin_X,
           Cell_Y,
           Overlay);
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

   Note_Atlas_Generation;

   if Metrics.W > 0 and then Metrics.H > 0 then
      declare

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
               Codepoint => Natural (Codepoint),
               Atlas_X   => Metrics.X,
               Atlas_Y   => Metrics.Y,
               Atlas_W   => Metrics.W,
               Atlas_H   => Metrics.H));
      end;
   end if;
end Emit_Codepoint;
