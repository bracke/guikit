with Guikit.Bidi.Data;

package body Guikit.Bidi.Shaping is

   use Guikit.Bidi.Data;

   Lam : constant := 16#0644#;

   function Join_Of (Codepoint : Natural) return Joining_Type is
      Low  : Positive := Joins'First;
      High : Natural := Joins'Last;
   begin
      while Low <= High loop
         declare
            Middle : constant Positive := Low + (High - Low) / 2;
         begin
            if Codepoint < Joins (Middle).First then
               High := Middle - 1;
            elsif Codepoint > Joins (Middle).Last then
               Low := Middle + 1;
            else
               return Joins (Middle).Kind;
            end if;
         end;
      end loop;
      return Non_Joining;
   end Join_Of;

   --  The entry for Codepoint in a form table, or 0.
   function Form_Index (Table : Form_Array; Codepoint : Natural) return Natural is
      Low  : Positive := Table'First;
      High : Natural := Table'Last;
   begin
      while Low <= High loop
         declare
            Middle : constant Positive := Low + (High - Low) / 2;
         begin
            if Codepoint < Table (Middle).Code then
               High := Middle - 1;
            elsif Codepoint > Table (Middle).Code then
               Low := Middle + 1;
            else
               return Middle;
            end if;
         end;
      end loop;
      return 0;
   end Form_Index;

   procedure Shape
     (Points    : Codepoint_Array;
      Drawable  : not null access function (Codepoint : Natural) return Boolean;
      Shaped    : out Codepoint_Array;
      Ligated   : out Flag_Array;
      Swallowed : out Flag_Array)
   is
      --  The nearest letter before or after I that is not transparent, or 0.
      function Previous_Joining (I : Positive) return Natural is
      begin
         for J in reverse Points'First .. I - 1 loop
            if Join_Of (Points (J)) /= Transparent then
               return J;
            end if;
         end loop;
         return 0;
      end Previous_Joining;

      function Next_Joining (I : Positive) return Natural is
      begin
         for J in I + 1 .. Points'Last loop
            if Join_Of (Points (J)) /= Transparent then
               return J;
            end if;
         end loop;
         return 0;
      end Next_Joining;

      --  Shape the joining letter at I of kind Kind.
      procedure Shape_Letter (I : Positive; Kind : Joining_Type) is
         Previous     : constant Natural := Previous_Joining (I);
         Next         : constant Natural := Next_Joining (I);
         Joins_Before : constant Boolean :=
           Kind in Dual | Right
           and then Previous /= 0
           and then Join_Of (Points (Previous)) in Dual | Left | Causing;
         Joins_After  : constant Boolean :=
           Kind in Dual | Left
           and then Next /= 0
           and then Join_Of (Points (Next)) in Dual | Right | Causing;
         Alef_Entry   : constant Natural :=
           (if Points (I) = Lam and then Joins_After and then Next = I + 1
            then Form_Index (Lam_Alef, Points (Next))
            else 0);
         Letter       : constant Natural := Form_Index (Shapes, Points (I));
         Ligature     : constant Natural :=
           (if Alef_Entry = 0 then 0
            elsif Joins_Before then Lam_Alef (Alef_Entry).Final
            else Lam_Alef (Alef_Entry).Isolated);
      begin
         if Ligature /= 0 and then Drawable (Ligature) then
            Shaped (I) := Ligature;
            Ligated (I) := True;
            Swallowed (Next) := True;
         elsif Letter /= 0 then
            declare
               Form_Code : constant Natural :=
                 (if Joins_Before and then Joins_After then Shapes (Letter).Medial
                  elsif Joins_Before then Shapes (Letter).Final
                  elsif Joins_After then Shapes (Letter).Initial
                  else Shapes (Letter).Isolated);
            begin
               if Form_Code /= 0 and then Drawable (Form_Code) then
                  Shaped (I) := Form_Code;
               end if;
            end;
         end if;
      end Shape_Letter;
   begin
      Shaped := Points;
      Ligated := [others => False];
      Swallowed := [others => False];
      for I in Points'Range loop
         declare
            Kind : constant Joining_Type := Join_Of (Points (I));
         begin
            if Kind in Dual | Right | Left then
               Shape_Letter (I, Kind);
            end if;
         end;
      end loop;
   end Shape;

end Guikit.Bidi.Shaping;
