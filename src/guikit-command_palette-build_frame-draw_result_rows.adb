separate (Guikit.Command_Palette.Build_Frame)
procedure Draw_Result_Rows is
   Enabled : Guikit.Layout.Palette_Enabled_Vectors.Vector;
begin
   for C of P.Ranked loop
      Enabled.Append (C.Enabled);
   end loop;
   declare
      Row_List : constant Guikit.Layout.Palette_Result_Row_Vectors.Vector :=
        Guikit.Layout.Calculate_Palette_Result_Rows (Layout, Enabled, P.Selected, P.Offset);
   begin
      for Row of Row_List loop
         Draw_Result_Row (Row);
      end loop;
   end;
end Draw_Result_Rows;
