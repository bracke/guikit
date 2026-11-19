with Guikit.Bidi.Carets;
with Guikit.Bidi.Data;
with Guikit.Bidi.Levels;
with Guikit.Bidi.Shaping;
with Guikit.Utf8;

package body Guikit.Bidi is

   use Guikit.Bidi.Data;

   ---------------------------------------------------------------------------
   --  Property lookups
   ---------------------------------------------------------------------------

   function Class_Of (Codepoint : Natural) return Bidi_Class is
      Low  : Positive := Classes'First;
      High : Natural := Classes'Last;
   begin
      while Low <= High loop
         declare
            Middle : constant Positive := Low + (High - Low) / 2;
         begin
            if Codepoint < Classes (Middle).First then
               High := Middle - 1;
            elsif Codepoint > Classes (Middle).Last then
               Low := Middle + 1;
            else
               return Classes (Middle).Class;
            end if;
         end;
      end loop;
      return L;
   end Class_Of;

   function Mirror_Of (Codepoint : Natural) return Natural is
      Low  : Positive := Mirrors'First;
      High : Natural := Mirrors'Last;
   begin
      while Low <= High loop
         declare
            Middle : constant Positive := Low + (High - Low) / 2;
         begin
            if Codepoint < Mirrors (Middle).From then
               High := Middle - 1;
            elsif Codepoint > Mirrors (Middle).From then
               Low := Middle + 1;
            else
               return Mirrors (Middle).To;
            end if;
         end;
      end loop;
      return Codepoint;
   end Mirror_Of;

   ---------------------------------------------------------------------------
   --  The algorithm
   ---------------------------------------------------------------------------

   procedure Resolve_Levels
     (Text            : Codepoint_Array;
      Direction       : Paragraph_Direction;
      Levels          : out Level_Array;
      Paragraph_Level : out Natural)
     renames Guikit.Bidi.Levels.Resolve;

   function Visual_Order (Levels : Level_Array) return Index_Array is
      Count : Natural := 0;
   begin
      for Level of Levels loop
         if Level /= Removed then
            Count := Count + 1;
         end if;
      end loop;

      declare
         Order   : Index_Array (1 .. Count);
         Of_Line : Level_Array (1 .. Count);
         Next    : Natural := 0;
         Highest : Natural := 0;
         Lowest_Odd : Natural := Natural'Last;
      begin
         for I in Levels'Range loop
            if Levels (I) /= Removed then
               Next := Next + 1;
               Order (Next) := I;
               Of_Line (Next) := Levels (I);
               Highest := Natural'Max (Highest, Levels (I));
               if Is_Odd (Levels (I)) then
                  Lowest_Odd := Natural'Min (Lowest_Odd, Levels (I));
               end if;
            end if;
         end loop;

         if Lowest_Odd /= Natural'Last then
            for Level in reverse Lowest_Odd .. Highest loop
               declare
                  K : Positive := 1;
               begin
                  while K <= Count loop
                     if Of_Line (K) >= Level then
                        declare
                           Last : Positive := K;
                        begin
                           while Last < Count and then Of_Line (Last + 1) >= Level loop
                              Last := Last + 1;
                           end loop;
                           for J in 0 .. (Last - K + 1) / 2 - 1 loop
                              declare
                                 Index_Swap : constant Positive := Order (K + J);
                                 Level_Swap : constant Natural := Of_Line (K + J);
                              begin
                                 Order (K + J) := Order (Last - J);
                                 Of_Line (K + J) := Of_Line (Last - J);
                                 Order (Last - J) := Index_Swap;
                                 Of_Line (Last - J) := Level_Swap;
                              end;
                           end loop;
                           K := Last + 1;
                        end;
                     else
                        K := K + 1;
                     end if;
                  end loop;
               end;
            end loop;
         end if;
         return Order;
      end;
   end Visual_Order;

   ---------------------------------------------------------------------------
   --  Layout
   ---------------------------------------------------------------------------

   function Needs_Layout (Content : String) return Boolean is
      Index     : Integer := Content'First;
      Codepoint : Natural;
   begin
      while Index <= Content'Last loop
         if Character'Pos (Content (Index)) < 16#80# then
            Index := Index + 1;
         else
            Guikit.Utf8.Decode_Next_Codepoint (Content, Index, Codepoint);
            if Class_Of (Codepoint) in R | AL | AN | RLE | RLO | RLI | FSI then
               return True;
            end if;
         end if;
      end loop;
      return False;
   end Needs_Layout;

   --  Which presentation forms the text is drawn with (Can_Draw_Form).
   protected Drawable_Forms is

      procedure Set (Coverage : Form_Coverage);

      function Draws (Codepoint : Form_Codepoint) return Boolean;

      --  The whole coverage recorded now, read at once.
      function Current return Form_Coverage;

   private
      Known : Form_Coverage := [others => True];
   end Drawable_Forms;

   protected body Drawable_Forms is

      procedure Set (Coverage : Form_Coverage) is
      begin
         Known := Coverage;
      end Set;

      function Draws (Codepoint : Form_Codepoint) return Boolean is (Known (Codepoint));

      function Current return Form_Coverage is (Known);

   end Drawable_Forms;

   procedure Set_Drawable_Forms (Coverage : Form_Coverage) is
   begin
      Drawable_Forms.Set (Coverage);
   end Set_Drawable_Forms;

   function Can_Draw_Form (Codepoint : Natural) return Boolean is
     (not Is_Presentation_Form (Codepoint) or else Drawable_Forms.Draws (Codepoint));

   function Lay_Out
     (Content   : String;
      Has_Glyph : access function (Codepoint : Natural) return Boolean := null)
      return Line
   is
      Count : Natural := 0;
   begin
      declare
         Index     : Integer := Content'First;
         Codepoint : Natural;
      begin
         while Index <= Content'Last loop
            Guikit.Utf8.Decode_Next_Codepoint (Content, Index, Codepoint);
            Count := Count + 1;
         end loop;
      end;

      declare
         Points  : Codepoint_Array (1 .. Count);
         Starts  : array (1 .. Count + 1) of Natural;
         Shaped  : Codepoint_Array (1 .. Count);
         --  The alef of a lam-alef ligature, drawn by the lam's glyph.
         Swallow : Guikit.Bidi.Shaping.Flag_Array (1 .. Count);
         Ligated : Guikit.Bidi.Shaping.Flag_Array (1 .. Count);
         Levels  : Level_Array (1 .. Count);
         Para    : Natural;
         Result  : Line;
         --  The recorded coverage, read once so a font reload partway
         --  through cannot lay one line out with two fonts' answers.
         Forms   : constant Form_Coverage :=
           (if Has_Glyph = null then Drawable_Forms.Current else [others => True]);

         function Drawable (Codepoint : Natural) return Boolean is
           (if Has_Glyph /= null then Has_Glyph (Codepoint)
            else not Is_Presentation_Form (Codepoint) or else Forms (Codepoint));
      begin
         declare
            Index : Integer := Content'First;
         begin
            for I in 1 .. Count loop
               Starts (I) := Natural (Index - Content'First);
               Guikit.Utf8.Decode_Next_Codepoint (Content, Index, Points (I));
            end loop;
            Starts (Count + 1) := Content'Length;
         end;
         Guikit.Bidi.Shaping.Shape (Points, Drawable'Access, Shaped, Ligated, Swallow);

         Resolve_Levels (Points, Auto, Levels, Para);
         Result.Right_To_Left := Is_Odd (Para);

         --  Clusters in stored order, each with its level.
         declare
            Stored       : Cluster_Vectors.Vector;
            Stored_Level : Level_Array (1 .. Count);
            Clusters     : Natural := 0;
         begin
            for I in 1 .. Count loop
               declare
                  Units : constant Natural := Guikit.Utf8.Codepoint_Display_Units (Points (I));
                  --  A character after a ZWJ still takes its own cells: the
                  --  font draws no joined sequence, so the emoji of a family
                  --  stand side by side, as they do in text needing no
                  --  layout, rather than on top of each other.
                  Starts_Cluster : constant Boolean :=
                    Clusters = 0 or else (Units > 0 and then not Swallow (I));
                  Level : constant Natural := (if Levels (I) = Removed then Para else Levels (I));
               begin
                  if Starts_Cluster then
                     Clusters := Clusters + 1;
                     Stored.Append
                       (Cluster'(First         => Starts (I),
                                 Length        => 0,
                                 Units         => 0,
                                 Right_To_Left => Is_Odd (Level),
                                 Glyph_First   => Natural (Result.Glyphs.Length) + 1,
                                 Glyph_Count   => 0,
                                 Ligature      => Ligated (I)));
                     Stored_Level (Clusters) := Level;
                  end if;

                  declare
                     Current : Cluster := Stored (Clusters);
                  begin
                     Current.Length := Starts (I + 1) - Current.First;
                     Current.Units := Current.Units + Units;
                     if not Swallow (I) then
                        Result.Glyphs.Append
                          (if Starts_Cluster and then Is_Odd (Level) and then not Ligated (I)
                           then Mirror_Of (Shaped (I))
                           else Shaped (I));
                        Current.Glyph_Count := Current.Glyph_Count + 1;
                     end if;
                     Stored (Clusters) := Current;
                  end;
               end;
            end loop;

            declare
               Order : constant Index_Array := Visual_Order (Stored_Level (1 .. Clusters));
            begin
               for Index of Order loop
                  Result.Clusters.Append (Stored (Index));
               end loop;
            end;
         end;
         return Result;
      end;
   end Lay_Out;

   ---------------------------------------------------------------------------
   --  Carets
   ---------------------------------------------------------------------------

   function Cut_Columns (Laid : Line; Columns : Natural) return Natural renames Guikit.Bidi.Carets.Cut_Columns;

   function Caret_Column
     (Content   : String;
      Cursor    : Natural;
      Columns   : Natural := Natural'Last;
      Has_Glyph : access function (Codepoint : Natural) return Boolean := null)
      return Natural
     renames Guikit.Bidi.Carets.Caret_Column;

   function Cursor_At_Half_Column
     (Content     : String;
      Half_Column : Natural;
      Columns     : Natural := Natural'Last;
      Has_Glyph   : access function (Codepoint : Natural) return Boolean := null)
      return Natural
     renames Guikit.Bidi.Carets.Cursor_At_Half_Column;

   function Caret_Step
     (Content   : String;
      Cursor    : Natural;
      Rightward : Boolean;
      By_Word   : Boolean := False;
      Has_Glyph : access function (Codepoint : Natural) return Boolean := null)
      return Natural
     renames Guikit.Bidi.Carets.Caret_Step;

end Guikit.Bidi;
