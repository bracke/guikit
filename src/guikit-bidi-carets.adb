with Guikit.Utf8;
with Guikit.Utf8.Editing;

package body Guikit.Bidi.Carets is

   function Cut_Columns (Laid : Line; Columns : Natural) return Natural is
      Total : Natural := 0;
   begin
      if not Laid.Right_To_Left then
         return 0;
      end if;
      for Item of Laid.Clusters loop
         Total := Total + Item.Units;
      end loop;
      return (if Total > Columns then Total - Columns else 0);
   end Cut_Columns;

   --  The column, before any cut, of a caret Cursor bytes into the text
   --  Laid was laid out from, Length bytes long.
   function Column_In (Laid : Line; Length, Cursor : Natural) return Natural is
      X : Natural := 0;
   begin
      for Item of Laid.Clusters loop
         if Cursor >= Length then
            if Item.First + Item.Length = Length then
               return (if Item.Right_To_Left then X else X + Item.Units);
            end if;
         elsif Cursor >= Item.First and then Cursor < Item.First + Item.Length then
            return (if Item.Right_To_Left then X + Item.Units else X);
         end if;
         X := X + Item.Units;
      end loop;
      return (if Laid.Right_To_Left then 0 else X);
   end Column_In;

   function Caret_Column
     (Content : String;
      Cursor  : Natural;
      Columns : Natural := Natural'Last)
      return Natural
   is
   begin
      if not Needs_Layout (Content) then
         return Guikit.Utf8.Display_Units_Before (Content, Cursor);
      end if;

      declare
         Laid   : constant Line := Lay_Out (Content);
         Cut    : constant Natural := Cut_Columns (Laid, Columns);
         Column : constant Natural := Column_In (Laid, Content'Length, Cursor);
      begin
         return (if Column > Cut then Column - Cut else 0);
      end;
   end Caret_Column;

   function Caret_Step
     (Content   : String;
      Cursor    : Natural;
      Rightward : Boolean;
      By_Word   : Boolean := False)
      return Natural
   is
      use Guikit.Utf8.Editing;
   begin
      if not Needs_Layout (Content) then
         if By_Word then
            return (if Rightward then Next_Word_Boundary (Content, Cursor)
                    else Previous_Word_Boundary (Content, Cursor));
         elsif Rightward then
            return (if Cursor < Content'Length then Next_Boundary (Content, Cursor) else Cursor);
         else
            return (if Cursor > 0 then Previous_Boundary (Content, Cursor) else Cursor);
         end if;
      end if;

      declare
         Laid : constant Line := Lay_Out (Content);
         Here : constant Natural := Natural'Min (Cursor, Content'Length);
      begin
         if By_Word then
            --  Words step in reading order, which in a right-to-left
            --  paragraph runs leftward.
            return
              (if Rightward = Laid.Right_To_Left then Previous_Word_Boundary (Content, Here)
               else Next_Word_Boundary (Content, Here));
         end if;

         declare
            Mine        : constant Natural := Column_In (Laid, Content'Length, Here);
            Best        : Natural := Here;
            Best_Column : Natural := Mine;
            Found       : Boolean := False;

            --  Stop ordering: by column, then by byte offset.
            function Before (Column_A, A, Column_B, B : Natural) return Boolean is
              (Column_A < Column_B or else (Column_A = Column_B and then A < B));

            procedure Consider (Stop, Column : Natural) is
            begin
               if Stop = Here then
                  return;
               elsif Rightward then
                  if Before (Mine, Here, Column, Stop)
                    and then (not Found or else Before (Column, Stop, Best_Column, Best))
                  then
                     Best := Stop;
                     Best_Column := Column;
                     Found := True;
                  end if;
               elsif Before (Column, Stop, Mine, Here)
                 and then (not Found or else Before (Best_Column, Best, Column, Stop))
               then
                  Best := Stop;
                  Best_Column := Column;
                  Found := True;
               end if;
            end Consider;

            X : Natural := 0;
         begin
            --  The stops are where the clusters start, at the cluster's
            --  leading edge in its direction, and the end of the text, at
            --  the trailing edge of the cluster that ends it: one pass over
            --  the clusters gives every stop its column.
            for Item of Laid.Clusters loop
               Consider (Item.First, (if Item.Right_To_Left then X + Item.Units else X));
               if Item.First + Item.Length = Content'Length then
                  Consider (Content'Length, (if Item.Right_To_Left then X else X + Item.Units));
               end if;
               X := X + Item.Units;
            end loop;
            return Best;
         end;
      end;
   end Caret_Step;

   function Cursor_At_Half_Column
     (Content     : String;
      Half_Column : Natural;
      Columns     : Natural := Natural'Last)
      return Natural
   is
   begin
      if not Needs_Layout (Content) then
         return Guikit.Utf8.Byte_Offset_For_Display_Column (Content, (Half_Column + 1) / 2);
      end if;

      declare
         Laid       : constant Line := Lay_Out (Content);
         Half       : constant Natural := Half_Column + 2 * Cut_Columns (Laid, Columns);
         X          : Natural := 0;
         Last_Drawn : Natural := 0;
      begin
         for Position in 1 .. Natural (Laid.Clusters.Length) loop
            declare
               Item : constant Cluster := Laid.Clusters (Position);
            begin
               if Item.Units > 0 then
                  Last_Drawn := Position;
                  if Half < 2 * (X + Item.Units) then
                     declare
                        Left_Half : constant Boolean := Half < 2 * X + Item.Units;
                     begin
                        return
                          (if Left_Half = Item.Right_To_Left then Item.First + Item.Length else Item.First);
                     end;
                  end if;
                  X := X + Item.Units;
               end if;
            end;
         end loop;

         if Last_Drawn = 0 then
            return 0;
         end if;
         declare
            Item : constant Cluster := Laid.Clusters (Last_Drawn);
         begin
            return (if Item.Right_To_Left then Item.First else Item.First + Item.Length);
         end;
      end;
   end Cursor_At_Half_Column;

end Guikit.Bidi.Carets;
