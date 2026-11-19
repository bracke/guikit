separate (Guikit.Text.Build_Glyphs)
procedure Append_Laid_Out
  (Glyphs  : in out Glyph_Command_Vectors.Vector;
   Overlay : Boolean;
   Text    : Text_Command;
   Content : String)
is
   Laid    : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Content, Font_Has'Access);
   Cell_X  : Float := Float (Text.X);
   Cell_Y  : constant Float := Float (Text.Y);
   Limit_X : constant Float := Float (Sat_Add (Text.X, Text.Width));
   Total   : Natural := 0;
   Skip    : Natural := 0;
begin
   for Item of Laid.Clusters loop
      Total := Sat_Add (Total, Item.Units);
   end loop;
   if Laid.Right_To_Left and then Total > Text.Width / R.Cell_Width then
      Skip := Total - Text.Width / R.Cell_Width;
   end if;

   for Item of Laid.Clusters loop
      if Skip > 0 and then Item.Units > 0 then
         --  Cut off: a wide cluster the cut runs through leaves its
         --  remaining cells blank.
         if Item.Units > Skip then
            Cell_X := Cell_X + Float (Sat_Mul (Item.Units - Skip, R.Cell_Width));
         end if;
         Skip := Skip - Natural'Min (Skip, Item.Units);
      elsif Skip = 0 or else Item.Units > 0 then
         exit when Item.Units > 0
           and then Cell_X + Float (Sat_Mul (Item.Units, R.Cell_Width)) > Limit_X;
         for G in Item.Glyph_First .. Item.Glyph_First + Item.Glyph_Count - 1 loop
            declare
               Base : constant Boolean := G = Item.Glyph_First and then Item.Units > 0;
            begin
               Emit_Codepoint
                 (Glyphs,
                  Overlay,
                  Text,
                  Laid.Glyphs (G),
                  Unit_Width => (if Base then Item.Units else 0),
                  --  A lam-alef ligature is one glyph over two
                  --  letters' cells: centred across them.
                  Origin_X   =>
                    (if Base and then Item.Ligature
                     then Cell_X + Float (Sat_Mul (Item.Units - 1, R.Cell_Width)) / 2.0
                     else Cell_X),
                  Cell_Y     => Cell_Y,
                  Hug_Right  => Item.Right_To_Left);
            end;
         end loop;
         Cell_X := Cell_X + Float (Sat_Mul (Item.Units, R.Cell_Width));
      end if;
   end loop;
end Append_Laid_Out;
