separate (Guikit.Text)
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

   --  The atlas generation the glyphs appended so far were placed in, and
   --  how many of each layer's glyphs were appended before the atlas was
   --  last emptied: those index cells that may since have been reused.
   Placed_Generation : Natural := 0;
   Stale_Glyphs      : Ada.Containers.Count_Type := 0;
   Stale_Overlay     : Ada.Containers.Count_Type := 0;

   --  Called once a glyph's metrics are in hand and before it is appended:
   --  if fetching them emptied the atlas, every glyph already appended, in
   --  either layer, is stale, and this one -- packed after the emptying --
   --  is not.
   procedure Note_Atlas_Generation is
      Now : constant Natural := Textrender.Atlas_Generation (R.Backend);
   begin
      if Now /= Placed_Generation then
         Placed_Generation := Now;
         Stale_Glyphs := Result.Glyphs.Length;
         Stale_Overlay := Result.Overlay_Glyphs.Length;
      end if;
   end Note_Atlas_Generation;

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
      Cell_Y   : Float;
      Overlay  : Boolean)
      return Boolean is separate;

   --  Draw one code point of Text: its colour picture or outline glyph,
   --  or the '?' standing in for a missing one. Origin_X is the left
   --  edge of its cell -- of the cell before it for a zero-width mark.
   procedure Emit_Codepoint
     (Glyphs            : in out Glyph_Command_Vectors.Vector;
      Overlay           : Boolean;
      Text              : Text_Command;
      Decoded_Codepoint : Natural;
      Unit_Width        : Natural;
      Origin_X          : Float;
      Cell_Y            : Float;
      Hug_Right         : Boolean) is separate;

   --  Whether the font chain can draw a code point: the shaper keeps an
   --  Arabic letter plain rather than pick a form drawn as '?'.
   function Font_Has (Codepoint : Natural) return Boolean is
     (Codepoint <= Natural (Textrender.Codepoint'Last)
      and then Textrender.Can_Draw (R.Backend, Textrender.Codepoint (Codepoint)));

   --  Text that draws in another order or shape than stored: lay it
   --  out with Guikit.Bidi and draw its clusters left to right. A
   --  right-to-left paragraph too long for its box loses its end -- the
   --  left -- not its start, unless the command names its own cut
   --  (Cut_Columns).
   procedure Append_Laid_Out
     (Glyphs  : in out Glyph_Command_Vectors.Vector;
      Overlay : Boolean;
      Text    : Text_Command;
      Content : String) is separate;

   --  Text aligned to its box's right edge (Align_End) is drawn in a
   --  box just as wide as the whole characters of it that fit, standing
   --  against that edge: a wide character the box's start would cut goes
   --  whole, so no blank cell is left at the edge the text stands against.
   --  Laid-out text with a cut of its own (Cut_Columns) fills the cells
   --  from the cut on that fit (Guikit.Bidi.Drawn_Columns).
   function Aligned (Given : Text_Command) return Text_Command is
   begin
      if not Given.Align_End or else Given.Scale_To_Box then
         return Given;
      end if;
      declare
         Content : constant String := To_String (Given.Text);
         Columns : constant Natural := Given.Width / R.Cell_Width;
         Fit     : constant Natural :=
           (if Given.Cut_Columns /= Auto_Cut and then Guikit.Bidi.Needs_Layout (Content)
            then Guikit.Bidi.Drawn_Columns
                   (Guikit.Bidi.Lay_Out (Content, Font_Has'Access), Given.Cut_Columns, Columns)
            else Guikit.Utf8.Display_Units (Guikit.Utf8.Prefix_By_Units (Content, Columns)));
         Used    : constant Natural := Sat_Mul (Fit, R.Cell_Width);
         Result  : Text_Command := Given;
      begin
         Result.X := Sat_Add (Given.X, Given.Width - Used);
         Result.Width := Used;
         return Result;
      end;
   end Aligned;

   --  Each command of Cmds, aligned, as glyphs appended to Glyphs: laid out
   --  by Guikit.Bidi when it needs it, otherwise one cell per code point
   --  until the box is full. A command with no width draws nothing -- not
   --  even a leading zero-width mark, which would otherwise land beside
   --  its empty box (or, fitted to the box, at the frame's left edge).
   procedure Append_Glyphs
     (Cmds    : Text_Command_Vectors.Vector;
      Glyphs  : in out Glyph_Command_Vectors.Vector;
      Overlay : Boolean) is
   begin
      for Given of Cmds loop
         declare
            Text    : constant Text_Command := Aligned (Given);
            Content : constant String := To_String (Text.Text);
            Cell_X  : Float := Float (Text.X);
            Cell_Y  : constant Float := Float (Text.Y);
            Limit_X : constant Float := Float (Sat_Add (Text.X, Text.Width));
            Base_X  : Float := Float (Text.X);
            Index   : Integer := Content'First;
         begin
            if Text.Width = 0 then
               null;
            elsif Guikit.Bidi.Needs_Layout (Content) then
               Append_Laid_Out (Glyphs, Overlay, Text, Content);
            else
               while Index <= Content'Last loop
                  declare
                     Unit_Start        : constant Integer := Index;
                     Decoded_Codepoint : Natural;
                     Unit_Width        : Natural;
                  begin
                     Guikit.Utf8.Decode_Next_Codepoint (Content, Index, Decoded_Codepoint);
                     Unit_Width := Guikit.Utf8.Display_Units (Content (Unit_Start .. Index - 1));
                     if Unit_Width > 0
                       and then Cell_X + Float (Sat_Mul (Unit_Width, R.Cell_Width)) > Limit_X
                     then
                        exit;
                     end if;

                     Emit_Codepoint
                       (Glyphs, Overlay, Text, Decoded_Codepoint, Unit_Width,
                        Origin_X  => (if Unit_Width = 0 then Base_X else Cell_X),
                        Cell_Y    => Cell_Y,
                        Hug_Right => False);

                     if Unit_Width > 0 then
                        Base_X := Cell_X;
                        Cell_X := Cell_X + Float (Sat_Mul (Unit_Width, R.Cell_Width));
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Append_Glyphs;

   --  Both layers' glyphs into Result, main layer first.
   procedure Append_Layers is
   begin
      Result.Status := Text_Render_Success;
      Append_Glyphs (Commands, Result.Glyphs, Overlay => False);
      Append_Glyphs (Overlay, Result.Overlay_Glyphs, Overlay => True);
   end Append_Layers;

   --  The atlas was emptied to make room partway through: the glyphs
   --  placed before that point sit at places now reused. Build the
   --  frame again; it fits the emptied atlas unless one frame needs
   --  more than the whole atlas holds.
   procedure Rebuild_After_Emptying is
   begin
      Result := (others => <>);
      Carried.Clear;
      Placed_Generation := Textrender.Atlas_Generation (R.Backend);
      Stale_Glyphs := 0;
      Stale_Overlay := 0;
      Append_Layers;
   end Rebuild_After_Emptying;

   --  It did not fit: the atlas was emptied again while the frame
   --  was being built a second time. The glyphs appended before the
   --  last emptying would draw whatever now occupies their cells, so
   --  they are left out; the rest of the frame is drawn correctly.
   --  No atlas size makes this frame whole, so building it a third
   --  time would only repeat the loss.
   procedure Drop_Stale_Glyphs is
   begin
      if Stale_Glyphs > 0 then
         Result.Glyphs.Delete_First (Stale_Glyphs);
      end if;
      if Stale_Overlay > 0 then
         Result.Overlay_Glyphs.Delete_First (Stale_Overlay);
      end if;
   end Drop_Stale_Glyphs;

   --  The atlas as it is once this text's glyphs are in: packing them may
   --  have made it taller. New glyphs packed make a new atlas version,
   --  which every window uploads once (each remembers the version it has).
   procedure Describe_Atlas is
   begin
      R.Atlas_Width  := Textrender.Atlas_Width (R.Backend);
      R.Atlas_Height := Textrender.Atlas_Height (R.Backend);
      Result.Atlas_Width  := R.Atlas_Width;
      Result.Atlas_Height := R.Atlas_Height;
      Result.Atlas_Bytes  := Sat_Mul (R.Atlas_Width, R.Atlas_Height);

      Result.Atlas_Dirty := Textrender.Atlas_Dirty (R.Backend);
      if Result.Atlas_Dirty then
         R.Atlas_Version := New_Atlas_Version;
         Textrender.Clear_Atlas_Dirty (R.Backend);
      end if;
      Result.Atlas_Version := R.Atlas_Version;
      if Textrender.Atlas_Pixels (R.Backend) /= null then
         Result.Atlas_Pixels := Textrender.Atlas_Pixels (R.Backend).all'Address;
      end if;
   end Describe_Atlas;
begin
   if not R.Is_Loaded then
      return Result;
   end if;

   declare
      Generation : constant Natural := Textrender.Atlas_Generation (R.Backend);
   begin
      Append_Layers;
      if Textrender.Atlas_Generation (R.Backend) /= Generation then
         Rebuild_After_Emptying;
         Drop_Stale_Glyphs;
      end if;
   end;

   Describe_Atlas;
   return Result;
end Build_Glyphs;
