with Guikit.Bidi;
with Guikit.Layout;
with Guikit.Utf8;

package body Guikit.Text_Fields is

   --  How many display cells Text takes when drawn in Columns cells.
   function Shown_Units (Text : String; Columns : Natural) return Natural is
     (Natural'Min (Guikit.Utf8.Display_Units (Text), Columns));

   function Caret_X
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout)
      return Natural
   is
      Cell_W  : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Columns : constant Natural := Field_Width / Cell_W;
      Column  : constant Natural := Guikit.Bidi.Caret_Column (Text, Natural'Min (Cursor, Text'Length), Columns);
      Room    : constant Natural := (if Field_Width > Caret_Width then Field_Width - Caret_Width else 0);
      X       : Natural;
   begin
      if Mirrored then
         --  The rectangle ends where, once mirrored, it starts.
         X := Guikit.Layout.Saturating_Multiply
           (Guikit.Mirroring.Reflect_Column (Column, Shown_Units (Text, Columns)), Cell_W);
         X := (if X > Caret_Width then X - Caret_Width else 0);
      else
         X := Guikit.Layout.Saturating_Multiply (Column, Cell_W);
      end if;
      return Natural'Min (X, Room);
   end Caret_X;

   function View_Of
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout)
      return View
   is
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

      Skip : constant Natural := Skipped;
   begin
      return
        (Skip_Bytes => Skip,
         Caret_X    =>
           Caret_X
             (Text (Text'First + Skip .. Text'Last), At_Cursor - Skip, Field_Width, Line_Height, Caret_Width,
              Mirrored));
   end View_Of;

   function Cursor_At
     (Text        : String;
      Skip_Bytes  : Natural;
      Click_X     : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout)
      return Natural
   is
      Cell_W  : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Columns : constant Natural := Field_Width / Cell_W;
      Skip    : constant Natural := Natural'Min (Skip_Bytes, Text'Length);
      Shown   : constant String := Text (Text'First + Skip .. Text'Last);
      --  The click in half cells: which half of a character it lands on
      --  decides the side of it the caret goes.
      Half    : constant Natural := Guikit.Layout.Saturating_Multiply (Click_X, 2) / Cell_W;
   begin
      return Skip
        + Guikit.Bidi.Cursor_At_Half_Column
            (Shown,
             (if Mirrored then Guikit.Mirroring.Reflect_Half_Column (Half, Shown_Units (Shown, Columns)) else Half),
             Columns);
   end Cursor_At;

end Guikit.Text_Fields;
