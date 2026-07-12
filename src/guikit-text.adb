with Ada.Strings.Unbounded;

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
        (Cmds   : Text_Command_Vectors.Vector;
         Glyphs : in out Glyph_Command_Vectors.Vector)
      is
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
                  begin
                     Guikit.Utf8.Decode_Next_Codepoint (Content, Index, Decoded_Codepoint);
                     Unit_Width := Guikit.Utf8.Display_Units (Content (Unit_Start .. Index - 1));
                     --  The overflow check compares against the glyph's native cell
                     --  width; a Scale_To_Box glyph is rescaled to its box afterwards,
                     --  so a box narrower than a native cell must not suppress it.
                     if not Text.Scale_To_Box
                       and then not Text.Shrink_To_Box
                       and then Unit_Width > 0
                       and then Cell_X + Float (Sat_Mul (Unit_Width, R.Cell_Width)) > Limit_X
                     then
                        exit;
                     end if;

                     Codepoint := Textrender.Codepoint (Decoded_Codepoint);
                     Status :=
                       Textrender.Get_Glyph
                         (R.Backend, Codepoint, Metrics,
                          Style => (if Text.Italic then Textrender.Italic else Textrender.Regular));
                     if Status /= Textrender.Success then
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
                           Fit_Ratio : constant Float :=
                             0.86 * Float'Min
                               (Float (Text.Width) / Float (Metrics.W),
                                Float (Text.Height) / Float (Metrics.H));
                           --  Scale_To_Box fits one glyph to its box (optionally down,
                           --  with Shrink_To_Box). Shrink_To_Box alone uniformly scales
                           --  a whole run down to the box height (Cell_Height is the
                           --  native line height), keeping the run on one baseline.
                           Scale    : constant Float :=
                             (if Text.Scale_To_Box then
                                (if Text.Shrink_To_Box then Float'Max (0.30, Fit_Ratio)
                                 else Float'Max (1.0, Fit_Ratio))
                              elsif Text.Shrink_To_Box then
                                Float'Min (1.0, Float (Text.Height) / Float (R.Cell_Height))
                              else 1.0);
                           Scaled_W : constant Float := Float (Metrics.W) * Scale;
                           Scaled_H : constant Float := Float (Metrics.H) * Scale;
                           Draw_X   : Float;
                           Draw_Y   : Float;
                        begin
                           Placement := Textrender.Place_Glyph_In_Cell (R.Backend, Metrics, Origin_X, Cell_Y);
                           if Text.Scale_To_Box then
                              Draw_X := Float (Text.X) + (Float (Text.Width) - Scaled_W) / 2.0;
                              Draw_Y := Float (Text.Y) + (Float (Text.Height) - Scaled_H) / 2.0;
                           elsif Text.Shrink_To_Box then
                              --  Scale each glyph's native offset from the box top-left
                              --  by the run scale, so the run shrinks as a unit on a
                              --  shared baseline.
                              Draw_X := Float (Text.X) + (Placement.X - Float (Text.X)) * Scale;
                              Draw_Y := Float (Text.Y) + (Placement.Y - Float (Text.Y)) * Scale;
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

      Append_Glyphs (Commands, Result.Glyphs);
      Append_Glyphs (Overlay, Result.Overlay_Glyphs);

      Result.Atlas_Dirty := Textrender.Atlas_Dirty (R.Backend);
      if Textrender.Atlas_Pixels (R.Backend) /= null then
         Result.Atlas_Pixels := Textrender.Atlas_Pixels (R.Backend).all'Address;
      end if;
      return Result;
   end Build_Glyphs;

end Guikit.Text;
