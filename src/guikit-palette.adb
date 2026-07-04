with Ada.Characters.Handling;
with Ada.Strings.Fixed;

with Guikit.Utf8;

package body Guikit.Palette is
   use Ada.Strings.Unbounded;

   No_Match_Score : constant Natural := Natural'Last;

   function Is_Continuation (Value : Character) return Boolean is
     (Character'Pos (Value) in 16#80# .. 16#BF#);

   --  UTF-8-aware ASCII/Latin case folding: lowercases ASCII and the Latin-1
   --  supplement / Latin Extended-A ranges that have a simple lowercase mapping,
   --  and passes other multi-byte sequences through unchanged so a case-
   --  insensitive substring match works for accented command names.
   function To_Lower (Text : String) return String is
      Result : String (Text'Range);
      Index  : Integer := Text'First;
   begin
      while Index <= Text'Last loop
         if Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C3#
           and then Character'Pos (Text (Index + 1)) in 16#80# .. 16#96#
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Character'Val (Character'Pos (Text (Index + 1)) + 16#20#);
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C3#
           and then Character'Pos (Text (Index + 1)) in 16#98# .. 16#9E#
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Character'Val (Character'Pos (Text (Index + 1)) + 16#20#);
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C5#
           and then Character'Pos (Text (Index + 1)) = 16#B8#
         then
            Result (Index) := Character'Val (16#C3#);
            Result (Index + 1) := Character'Val (16#BF#);
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) in 16#C2# .. 16#DF#
           and then Is_Continuation (Text (Index + 1))
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Text (Index + 1);
            Index := Index + 2;
         elsif Index <= Text'Last - 2
           and then Character'Pos (Text (Index)) in 16#E0# .. 16#EF#
           and then Is_Continuation (Text (Index + 1))
           and then Is_Continuation (Text (Index + 2))
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Text (Index + 1);
            Result (Index + 2) := Text (Index + 2);
            Index := Index + 3;
         elsif Index <= Text'Last - 3
           and then Character'Pos (Text (Index)) in 16#F0# .. 16#F4#
           and then Is_Continuation (Text (Index + 1))
           and then Is_Continuation (Text (Index + 2))
           and then Is_Continuation (Text (Index + 3))
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Text (Index + 1);
            Result (Index + 2) := Text (Index + 2);
            Result (Index + 3) := Text (Index + 3);
            Index := Index + 4;
         else
            Result (Index) := Ada.Characters.Handling.To_Lower (Text (Index));
            Index := Index + 1;
         end if;
      end loop;

      return Result;
   end To_Lower;

   function Contains_Case_Insensitive
     (Haystack : String;
      Needle   : String)
      return Boolean is
   begin
      if Needle = "" then
         return True;
      end if;

      return Ada.Strings.Fixed.Index (To_Lower (Haystack), To_Lower (Needle)) > 0;
   end Contains_Case_Insensitive;

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Natural'Last - Left < Right then
         return Natural'Last;
      end if;

      return Left + Right;
   end Saturating_Add;

   function Saturating_Score
     (Base_Score     : Natural;
      Registry_Index : Natural)
      return Natural
   is
      Scale : constant Natural := 100;
   begin
      if Base_Score > Natural'Last / Scale then
         return Natural'Last;
      end if;

      return Saturating_Add (Base_Score * Scale, Registry_Index);
   end Saturating_Score;

   function Field_Score
     (Field : String;
      Token : String;
      Base  : Natural)
      return Natural
   is
      Lower_Field : constant String := To_Lower (Field);
      Lower_Token : constant String := To_Lower (Token);
   begin
      if Lower_Field = Lower_Token then
         return Base;
      elsif Lower_Field'Length >= Lower_Token'Length
        and then Lower_Field (Lower_Field'First .. Lower_Field'First + Lower_Token'Length - 1) = Lower_Token
      then
         return Base + 10;
      elsif Contains_Case_Insensitive (Field, Token) then
         return Base + 20;
      else
         return No_Match_Score;
      end if;
   end Field_Score;

   function Query_Score
     (Identifier  : String;
      Label       : String;
      Description : String;
      Shortcuts   : String;
      Query       : String)
      return Natural
   is
      Position         : Natural := 0;
      Last             : Natural;
      Separator_Length : Natural;
      Score            : Natural := 0;
   begin
      if Query = "" then
         return 0;
      end if;

      while Position < Query'Length loop
         loop
            Separator_Length := Guikit.Utf8.Whitespace_Separator_Length (Query, Position);
            exit when Separator_Length = 0;
            Position := Natural'Min (Position + Separator_Length, Query'Length);
         end loop;

         exit when Position >= Query'Length;

         Last := Position;
         while Last < Query'Length and then Guikit.Utf8.Whitespace_Separator_Length (Query, Last) = 0 loop
            Last := Last + 1;
         end loop;

         declare
            Token : constant String := Query (Query'First + Position .. Query'First + Last - 1);
            Token_Score : constant Natural :=
              Natural'Min
                 (Field_Score (Identifier, Token, 0),
                 Natural'Min
                   (Field_Score (Label, Token, 100),
                    Natural'Min
                      (Field_Score (Description, Token, 200),
                       Field_Score (Shortcuts, Token, 300))));
         begin
            if Token_Score = No_Match_Score then
               return No_Match_Score;
            end if;
            Score := Saturating_Add (Score, Token_Score);
         end;

         Position := Last;
      end loop;

      return Score;
   end Query_Score;

   function Has_Query_Token (Query : String) return Boolean is
      Position : Natural := 0;
   begin
      while Position < Query'Length loop
         declare
            Separator_Length : constant Natural := Guikit.Utf8.Whitespace_Separator_Length (Query, Position);
         begin
            if Separator_Length = 0 then
               return True;
            end if;
            Position := Natural'Min (Position + Separator_Length, Query'Length);
         end;
      end loop;

      return False;
   end Has_Query_Token;

   function Search
     (Query : String;
      Items : Item_Vectors.Vector)
      return Item_Vectors.Vector
   is
      Results   : Item_Vectors.Vector;
      Has_Token : constant Boolean := Has_Query_Token (Query);
   begin
      for I in Items.First_Index .. Items.Last_Index loop
         declare
            Entry_Item     : Item := Items.Element (I);
            Base_Score     : constant Natural :=
              Query_Score
                (To_String (Entry_Item.Identifier),
                 To_String (Entry_Item.Label),
                 To_String (Entry_Item.Description),
                 To_String (Entry_Item.Shortcut),
                 Query);
            Registry_Index : constant Natural := I - Items.First_Index;
         begin
            if Base_Score /= No_Match_Score then
               Entry_Item.Score := Saturating_Score (Base_Score, Registry_Index);
               Results.Append (Entry_Item);
            end if;
         end;
      end loop;

      if Has_Token then
         declare
            function Less (Left, Right : Item) return Boolean is
              (Left.Score < Right.Score);

            package Sorting is new Item_Vectors.Generic_Sorting ("<" => Less);
         begin
            Sorting.Sort (Results);
         end;
      end if;

      return Results;
   end Search;

end Guikit.Palette;
