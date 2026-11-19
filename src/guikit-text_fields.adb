with Guikit.Bidi;
with Guikit.Layout;
with Guikit.Utf8;

package body Guikit.Text_Fields is

   function View_Of
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural)
      return View
   is
      Cell_W       : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      At_Cursor    : constant Natural := Natural'Min (Cursor, Text'Length);
      Caret_Column : constant Natural := Guikit.Utf8.Display_Units_Before (Text, At_Cursor);
      Wanted       : constant Natural := Guikit.Layout.Input_Scroll_Columns (Caret_Column, Field_Width, Line_Height);

      --  The scrolled-off prefix: at least Wanted columns, widened a column
      --  at a time until a cluster straddling the cut goes with it.
      function Skipped return Natural is
      begin
         if Wanted = 0 then
            return 0;
         end if;
         for Columns in Wanted .. Caret_Column loop
            declare
               Prefix : constant String := Guikit.Utf8.Prefix_By_Units (Text, Columns);
            begin
               if Guikit.Utf8.Display_Units (Prefix) >= Wanted then
                  return Natural'Min (Prefix'Length, At_Cursor);
               end if;
            end;
         end loop;
         return At_Cursor;
      end Skipped;

      Skip   : constant Natural := Skipped;
      Shown  : constant String := Text (Text'First + Skip .. Text'Last);
      Column : constant Natural :=
        Guikit.Bidi.Caret_Column (Shown, At_Cursor - Skip, Columns => Field_Width / Cell_W);
      Room   : constant Natural := (if Field_Width > Caret_Width then Field_Width - Caret_Width else 0);
   begin
      return
        (Skip_Bytes => Skip,
         Caret_X    => Natural'Min (Guikit.Layout.Saturating_Multiply (Column, Cell_W), Room));
   end View_Of;

end Guikit.Text_Fields;
