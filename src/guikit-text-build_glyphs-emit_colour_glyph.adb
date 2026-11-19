separate (Guikit.Text.Build_Glyphs)
function Emit_Colour_Glyph
  (Code     : Textrender.Codepoint;
   Origin_X : Float;
   Cell_Y   : Float;
   Overlay  : Boolean)
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
      declare
         Picture : Guikit.Draw.Byte_Vectors.Vector;
      begin
         Picture.Reserve_Capacity
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
                     Picture.Append
                       (Interfaces.Unsigned_8 (Pixels (At_Sheet + Channel)));
                  end loop;
               end;
            end loop;
         end loop;
         Icon.Thumbnail_Pixels := Guikit.Shared_Bytes.To_Shared (Picture);
      end;

      Carried.Append (Natural (Code));
   end if;

   Result.Colour_Icons.Append (Icon);
   return True;
end Emit_Colour_Glyph;
