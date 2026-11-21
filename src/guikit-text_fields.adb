with Guikit.Bidi;
with Guikit.Layout;
with Guikit.Utf8;

package body Guikit.Text_Fields is

   --  How many display cells Text takes when drawn in Columns cells: the
   --  whole characters that fit, as Guikit.Text.Build_Glyphs sizes a box
   --  aligned to its end, so a wide character straddling the end is not
   --  counted.
   function Shown_Units (Text : String; Columns : Natural) return Natural is
     (Guikit.Utf8.Display_Units (Guikit.Utf8.Prefix_By_Units (Text, Columns)));

   --  Where a caret Column cells into drawn text Shown cells wide is drawn,
   --  in pixels from the field's left edge, as Caret_X places it: reflected
   --  in a mirrored frame, and kept inside the field.
   function Caret_Pixel
     (Column      : Natural;
      Shown       : Natural;
      Field_Width : Natural;
      Cell_W      : Positive;
      Caret_Width : Natural;
      Mirrored    : Boolean)
      return Natural
   is
      Room : constant Natural := (if Field_Width > Caret_Width then Field_Width - Caret_Width else 0);
      X    : Natural;
   begin
      if Mirrored then
         --  The rectangle ends where, once mirrored, it starts.
         X := Guikit.Layout.Saturating_Multiply (Guikit.Mirroring.Reflect_Column (Column, Shown), Cell_W);
         X := (if X > Caret_Width then X - Caret_Width else 0);
      else
         X := Guikit.Layout.Saturating_Multiply (Column, Cell_W);
      end if;
      return Natural'Min (X, Room);
   end Caret_Pixel;

   function Caret_X
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null)
      return Natural
   is
      Cell_W  : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Columns : constant Natural := Field_Width / Cell_W;
      --  A mirrored field's text is aligned to its end, in a box as wide as
      --  the whole characters that fit: the text is drawn in that many cells.
      Shown   : constant Natural := (if Mirrored then Shown_Units (Text, Columns) else Columns);
      Column  : constant Natural :=
        Guikit.Bidi.Caret_Column (Text, Natural'Min (Cursor, Text'Length), Shown, Has_Glyph);
   begin
      return Caret_Pixel (Column, Shown, Field_Width, Cell_W, Caret_Width, Mirrored);
   end Caret_X;

   --  View_Of for text that needs bidi layout: scrolled by the caret's
   --  column in the whole laid-out text, drawn with a cut of display cells.
   function Laid_Out_View
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural;
      Mirrored    : Boolean;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean)
      return View
   is
      Cell_W  : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Columns : constant Natural := Field_Width / Cell_W;
      Laid    : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Text, Has_Glyph);
      --  The caret's column in the whole text, nothing cut.
      Column  : constant Natural := Guikit.Bidi.Caret_Column (Text, Cursor, Natural'Last, Has_Glyph);
      --  The cut the text is drawn with unscrolled.
      Natural_Cut : constant Natural := Guikit.Bidi.Cut_Columns (Laid, Columns);
   begin
      if Columns = 0 then
         --  Narrower than one cell: nothing is drawn, so there is nothing to
         --  scroll to, and the caret stands at the field's start.
         return (Skip_Bytes => 0, Caret_X => 0, Cut_Columns => Natural_Cut);
      end if;
      declare
         --  Where the caret may stand, counted from the cut: as for plain
         --  text, a left-to-right paragraph keeps a cell after the caret for
         --  what is typed next, and the field shows columns 0 .. Columns - 1;
         --  a right-to-left one keeps that cell on the caret's left, 1 ..
         --  Columns, so the caret at its start, on the right, is not
         --  scrolled.
         Low  : constant Natural := (if Laid.Right_To_Left then 1 else 0);
         High : constant Natural := (if Laid.Right_To_Left then Columns else Columns - 1);
         Cut  : Natural;
      begin
         if Column in Natural_Cut + Low .. Natural_Cut + High then
            Cut := Natural_Cut;
         elsif Column < Natural_Cut + Low then
            --  The caret is in the cells cut off: bring it to the left edge.
            Cut := (if Column > Low then Column - Low else 0);
         else
            --  Past the field's end: bring it to the right edge.
            Cut := Column - High;
         end if;
         return
           (Skip_Bytes  => 0,
            Caret_X     =>
              Caret_Pixel
                (Column - Cut,
                 (if Mirrored then Guikit.Bidi.Drawn_Columns (Laid, Cut, Columns) else Columns),
                 Field_Width, Cell_W, Caret_Width, Mirrored),
            Cut_Columns => Cut);
      end;
   end Laid_Out_View;

   function View_Of
     (Text        : String;
      Cursor      : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Caret_Width : Natural;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null)
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

   begin
      if Guikit.Bidi.Needs_Layout (Text) then
         return Laid_Out_View (Text, At_Cursor, Field_Width, Line_Height, Caret_Width, Mirrored, Has_Glyph);
      end if;
      declare
         Skip : constant Natural := Skipped;
      begin
         return
           (Skip_Bytes  => Skip,
            Caret_X     =>
              Caret_X
                (Text (Text'First + Skip .. Text'Last), At_Cursor - Skip, Field_Width, Line_Height, Caret_Width,
                 Mirrored, Has_Glyph),
            Cut_Columns => Guikit.Draw.Auto_Cut);
      end;
   end View_Of;

   function Cursor_At
     (Text        : String;
      Skip_Bytes  : Natural;
      Click_X     : Natural;
      Field_Width : Natural;
      Line_Height : Positive;
      Mirrored    : Boolean := Guikit.Mirroring.Mirrored_Layout;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null;
      Cut_Columns : Natural := Guikit.Draw.Auto_Cut)
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
      if Cut_Columns /= Guikit.Draw.Auto_Cut and then Guikit.Bidi.Needs_Layout (Shown) then
         --  Drawn with Cut_Columns cells cut off: count the click from the
         --  start of the whole laid-out text.
         declare
            Laid  : constant Guikit.Bidi.Line := Guikit.Bidi.Lay_Out (Shown, Has_Glyph);
            Cells : constant Natural :=
              (if Mirrored then Guikit.Bidi.Drawn_Columns (Laid, Cut_Columns, Columns) else Columns);
            Drawn : constant Natural :=
              (if Mirrored then Guikit.Mirroring.Reflect_Half_Column (Half, Cells) else Half);
         begin
            return Skip
              + Guikit.Bidi.Cursor_At_Half_Column
                  (Shown,
                   Guikit.Layout.Saturating_Add (Drawn, Guikit.Layout.Saturating_Multiply (Cut_Columns, 2)),
                   Natural'Last,
                   Has_Glyph);
         end;
      end if;
      declare
         --  The cells the text is drawn in, as Caret_X counts them.
         Cells : constant Natural := (if Mirrored then Shown_Units (Shown, Columns) else Columns);
      begin
         return Skip
           + Guikit.Bidi.Cursor_At_Half_Column
               (Shown,
                (if Mirrored then Guikit.Mirroring.Reflect_Half_Column (Half, Cells) else Half),
                Cells,
                Has_Glyph);
      end;
   end Cursor_At;

end Guikit.Text_Fields;
