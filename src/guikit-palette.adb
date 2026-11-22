with Ada.Characters.Handling;
with Ada.Strings.Fixed;

with Guikit.Utf8;

package body Guikit.Palette is
   use Ada.Strings.Unbounded;

   No_Match_Score : constant Natural := Natural'Last;

   function Is_Continuation (Value : Character) return Boolean is
     (Character'Pos (Value) in 16#80# .. 16#BF#);

   --  UTF-8-aware ASCII/Latin-1 case folding: lowercases ASCII, the Latin-1
   --  supplement's capitals and Y with diaeresis, and passes other multi-byte
   --  sequences through unchanged. The default when the caller supplies no
   --  Fold_Function to Search.
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

   --  How well a folded Token matches a folded Field, on top of Base: exact,
   --  then prefix, then anywhere in it.
   function Field_Score
     (Field : String;
      Token : String;
      Base  : Natural)
      return Natural is
   begin
      if Field = Token then
         return Base;
      elsif Field'Length >= Token'Length
        and then Field (Field'First .. Field'First + Token'Length - 1) = Token
      then
         return Base + 10;
      elsif Ada.Strings.Fixed.Index (Field, Token) > 0 then
         return Base + 20;
      else
         return No_Match_Score;
      end if;
   end Field_Score;

   --  The zero-based offset just past the UTF-8 sequence at Position: a whole
   --  well-formed sequence, else the one stray byte.
   function Next_Sequence
     (Text     : String;
      Position : Natural)
      return Natural
   is
      Index     : Integer := Text'First + Position;
      Codepoint : Natural;
   begin
      Guikit.Utf8.Decode_Next_Codepoint (Text, Index, Codepoint);
      pragma Unreferenced (Codepoint);
      return Natural (Index - Text'First);
   end Next_Sequence;

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

         --  Step whole UTF-8 sequences, so the token never ends inside a
         --  letter whose continuation byte happens to equal a separator byte.
         Last := Position;
         while Last < Query'Length and then Guikit.Utf8.Whitespace_Separator_Length (Query, Last) = 0 loop
            Last := Next_Sequence (Query, Last);
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
      Items : Item_Vectors.Vector;
      Fold  : Fold_Function := null)
      return Item_Vectors.Vector
   is
      --  Every field and the query folded once, by the caller's folding or
      --  the toolkit's.
      function Folded (Text : String) return String is
        (if Fold = null then To_Lower (Text) else Fold (Text));

      Folded_Query : constant String := Folded (Query);
      --  A match and where it stood among Items: the order is the pair, the
      --  match first and the position only between equal matches. Packed into
      --  one number (match * 100 + position) the position overtook the match
      --  once there were a thousand items, and an exact match far down the
      --  list ranked below a mere substring match near the top.
      type Ranked is record
         Value    : Item;
         Position : Natural := 0;
      end record;

      package Ranked_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Positive,
         Element_Type => Ranked);

      Matches   : Ranked_Vectors.Vector;
      Results   : Item_Vectors.Vector;
      Has_Token : constant Boolean := Has_Query_Token (Query);
   begin
      for I in Items.First_Index .. Items.Last_Index loop
         declare
            Entry_Item : Item := Items.Element (I);
            Base_Score : constant Natural :=
              Query_Score
                (Folded (To_String (Entry_Item.Identifier)),
                 Folded (To_String (Entry_Item.Label)),
                 Folded (To_String (Entry_Item.Description)),
                 Folded (To_String (Entry_Item.Shortcut)),
                 Folded_Query);
         begin
            if Base_Score /= No_Match_Score then
               Entry_Item.Score := Base_Score;
               Matches.Append (Ranked'(Value => Entry_Item, Position => I - Items.First_Index));
            end if;
         end;
      end loop;

      if Has_Token then
         declare
            function Less (Left, Right : Ranked) return Boolean is
              (Left.Value.Score < Right.Value.Score
               or else (Left.Value.Score = Right.Value.Score and then Left.Position < Right.Position));

            package Sorting is new Ranked_Vectors.Generic_Sorting ("<" => Less);
         begin
            Sorting.Sort (Matches);
         end;
      end if;

      for Match of Matches loop
         Results.Append (Match.Value);
      end loop;
      return Results;
   end Search;

end Guikit.Palette;
