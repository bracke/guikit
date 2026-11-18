with Guikit.Bidi.Data;
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

   --  The bracket entry for Codepoint, or 0 when it is no paired bracket.
   function Bracket_Index (Codepoint : Natural) return Natural is
      Low  : Positive := Brackets'First;
      High : Natural := Brackets'Last;
   begin
      while Low <= High loop
         declare
            Middle : constant Positive := Low + (High - Low) / 2;
         begin
            if Codepoint < Brackets (Middle).Code then
               High := Middle - 1;
            elsif Codepoint > Brackets (Middle).Code then
               Low := Middle + 1;
            else
               return Middle;
            end if;
         end;
      end loop;
      return 0;
   end Bracket_Index;

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

   ---------------------------------------------------------------------------
   --  The algorithm
   ---------------------------------------------------------------------------

   subtype Isolate_Initiator is Bidi_Class range LRI .. FSI;
   subtype Neutral_Or_Isolate is Bidi_Class
     with Static_Predicate => Neutral_Or_Isolate in B | S | WS | ON | LRI | RLI | FSI | PDI;

   Max_Depth : constant := 125;

   function Is_Odd (Level : Natural) return Boolean is (Level mod 2 = 1);

   function Direction_Of (Level : Natural) return Bidi_Class is (if Is_Odd (Level) then R else L);

   --  The direction a resolved type counts as for N0 to N2: EN and AN are R.
   --  ON for anything that is not strong.
   function Strong_Of (Kind : Bidi_Class) return Bidi_Class is
     (case Kind is
         when L => L,
         when R | AL | EN | AN => R,
         when others => ON);

   procedure Resolve_Levels
     (Text            : Codepoint_Array;
      Direction       : Paragraph_Direction;
      Levels          : out Level_Array;
      Paragraph_Level : out Natural)
   is
      N : constant Natural := Text'Length;

      type Class_Array is array (1 .. N) of Bidi_Class;
      type Natural_Array is array (1 .. N) of Natural;
      type Flag_Array is array (1 .. N) of Boolean;

      Original     : Class_Array;
      Types        : Class_Array;
      Lev          : Natural_Array := [others => 0];
      Gone         : Flag_Array := [others => False];
      Matching_PDI : Natural_Array := [others => 0];
      Initiator_Of : Natural_Array := [others => 0];

      --  The first strong direction in From .. To, skipping isolates (P2):
      --  L, R, or ON when there is none.
      function First_Strong (From, To : Natural) return Bidi_Class is
         I : Natural := From;
      begin
         while I <= To loop
            case Original (I) is
               when L =>
                  return L;
               when R | AL =>
                  return R;
               when Isolate_Initiator =>
                  if Matching_PDI (I) = 0 then
                     return ON;
                  end if;
                  I := Matching_PDI (I);
               when others =>
                  null;
            end case;
            I := I + 1;
         end loop;
         return ON;
      end First_Strong;

      Para : Natural;
   begin
      for I in 1 .. N loop
         Original (I) := Class_Of (Text (Text'First + I - 1));
      end loop;
      Types := Original;

      --  BD9: the PDI matching each isolate initiator.
      for I in 1 .. N loop
         if Original (I) in Isolate_Initiator then
            declare
               Depth : Natural := 1;
            begin
               for J in I + 1 .. N loop
                  if Original (J) in Isolate_Initiator then
                     Depth := Depth + 1;
                  elsif Original (J) = PDI then
                     Depth := Depth - 1;
                     if Depth = 0 then
                        Matching_PDI (I) := J;
                        Initiator_Of (J) := I;
                        exit;
                     end if;
                  elsif Original (J) = B then
                     exit;
                  end if;
               end loop;
            end;
         end if;
      end loop;

      --  P2, P3.
      Para :=
        (case Direction is
            when Left_To_Right => 0,
            when Right_To_Left => 1,
            when Auto => (if First_Strong (1, N) = R then 1 else 0));
      Paragraph_Level := Para;

      --  X1 to X8: explicit levels and directions.
      declare
         type Override_Status is (Neutral, Force_L, Force_R);
         type Status_Entry is record
            Level    : Natural;
            Override : Override_Status;
            Isolate  : Boolean;
         end record;
         Stack : array (1 .. Max_Depth + 2) of Status_Entry;
         Depth : Positive := 1;
         Overflow_Isolates   : Natural := 0;
         Overflow_Embeddings : Natural := 0;
         Valid_Isolates      : Natural := 0;

         function Next_Odd (Level : Natural) return Natural is
           (if Is_Odd (Level) then Level + 2 else Level + 1);
         function Next_Even (Level : Natural) return Natural is
           (if Is_Odd (Level) then Level + 1 else Level + 2);

         procedure Take_Top (I : Positive) is
         begin
            Lev (I) := Stack (Depth).Level;
            case Stack (Depth).Override is
               when Force_L => Types (I) := L;
               when Force_R => Types (I) := R;
               when Neutral => null;
            end case;
         end Take_Top;
      begin
         Stack (1) := (Level => Para, Override => Neutral, Isolate => False);
         for I in 1 .. N loop
            case Original (I) is
               when RLE | LRE | RLO | LRO =>
                  declare
                     New_Level : constant Natural :=
                       (if Original (I) in RLE | RLO
                        then Next_Odd (Stack (Depth).Level)
                        else Next_Even (Stack (Depth).Level));
                  begin
                     Lev (I) := Stack (Depth).Level;
                     Gone (I) := True;
                     if New_Level <= Max_Depth and then Overflow_Isolates = 0 and then Overflow_Embeddings = 0 then
                        Depth := Depth + 1;
                        Stack (Depth) :=
                          (Level    => New_Level,
                           Override =>
                             (case Original (I) is
                                 when RLO => Force_R,
                                 when LRO => Force_L,
                                 when others => Neutral),
                           Isolate  => False);
                     elsif Overflow_Isolates = 0 then
                        Overflow_Embeddings := Overflow_Embeddings + 1;
                     end if;
                  end;

               when Isolate_Initiator =>
                  Take_Top (I);
                  declare
                     To_Right : constant Boolean :=
                       Original (I) = RLI
                       or else (Original (I) = FSI
                                and then First_Strong
                                  (I + 1, (if Matching_PDI (I) = 0 then N else Matching_PDI (I) - 1)) = R);
                     New_Level : constant Natural :=
                       (if To_Right then Next_Odd (Stack (Depth).Level) else Next_Even (Stack (Depth).Level));
                  begin
                     if New_Level <= Max_Depth and then Overflow_Isolates = 0 and then Overflow_Embeddings = 0 then
                        Valid_Isolates := Valid_Isolates + 1;
                        Depth := Depth + 1;
                        Stack (Depth) := (Level => New_Level, Override => Neutral, Isolate => True);
                     else
                        Overflow_Isolates := Overflow_Isolates + 1;
                     end if;
                  end;

               when PDI =>
                  if Overflow_Isolates > 0 then
                     Overflow_Isolates := Overflow_Isolates - 1;
                  elsif Valid_Isolates > 0 then
                     Overflow_Embeddings := 0;
                     while not Stack (Depth).Isolate loop
                        Depth := Depth - 1;
                     end loop;
                     Depth := Depth - 1;
                     Valid_Isolates := Valid_Isolates - 1;
                  end if;
                  Take_Top (I);

               when PDF =>
                  if Overflow_Isolates > 0 then
                     null;
                  elsif Overflow_Embeddings > 0 then
                     Overflow_Embeddings := Overflow_Embeddings - 1;
                  elsif not Stack (Depth).Isolate and then Depth >= 2 then
                     Depth := Depth - 1;
                  end if;
                  Lev (I) := Stack (Depth).Level;
                  Gone (I) := True;

               when B =>
                  Lev (I) := Para;

               when BN =>
                  Lev (I) := Stack (Depth).Level;
                  Gone (I) := True;

               when others =>
                  Take_Top (I);
            end case;
         end loop;
      end;

      --  X10: level runs, chained into isolating run sequences. Each
      --  sequence's sos and eos come from the explicit levels, before any
      --  sequence's implicit levels (I1, I2) are resolved.
      declare
         Explicit   : constant Natural_Array := Lev;
         Kept       : Natural_Array;
         Kept_Count : Natural := 0;
         Position   : Natural_Array := [others => 0];  --  of each kept character in Kept

         Run_Start  : Natural_Array;
         Run_End    : Natural_Array;
         Run_Count  : Natural := 0;
         Run_Of     : Natural_Array := [others => 0];  --  by Kept position
      begin
         for I in 1 .. N loop
            if not Gone (I) then
               Kept_Count := Kept_Count + 1;
               Kept (Kept_Count) := I;
               Position (I) := Kept_Count;
            end if;
         end loop;

         for K in 1 .. Kept_Count loop
            if K = 1 or else Lev (Kept (K)) /= Lev (Kept (K - 1)) then
               Run_Count := Run_Count + 1;
               Run_Start (Run_Count) := K;
            end if;
            Run_End (Run_Count) := K;
            Run_Of (K) := Run_Count;
         end loop;

         for Run in 1 .. Run_Count loop
            declare
               First_Char : constant Positive := Kept (Run_Start (Run));

               --  This run continues a sequence when it opens with the PDI
               --  that closes the isolate ending some earlier run.
               Continues : constant Boolean :=
                 Original (First_Char) = PDI
                 and then Initiator_Of (First_Char) /= 0
                 and then not Gone (Initiator_Of (First_Char))
                 and then Run_End (Run_Of (Position (Initiator_Of (First_Char))))
                   = Position (Initiator_Of (First_Char));
            begin
               if not Continues then
                  declare
                     Seq   : Natural_Array;
                     M     : Natural := 0;
                     Current : Natural := Run;
                  begin
                     loop
                        for K in Run_Start (Current) .. Run_End (Current) loop
                           M := M + 1;
                           Seq (M) := Kept (K);
                        end loop;
                        declare
                           Last_Char : constant Positive := Seq (M);
                        begin
                           exit when Original (Last_Char) not in Isolate_Initiator
                             or else Matching_PDI (Last_Char) = 0;
                           declare
                              Closing : constant Positive := Matching_PDI (Last_Char);
                           begin
                              exit when Run_Start (Run_Of (Position (Closing))) /= Position (Closing);
                              Current := Run_Of (Position (Closing));
                           end;
                        end;
                     end loop;

                     --  Resolve the sequence Seq (1 .. M).
                     declare
                        Level : constant Natural := Explicit (Seq (1));
                        Embedding : constant Bidi_Class := Direction_Of (Level);

                        Before : constant Natural :=
                          (if Position (Seq (1)) > 1 then Explicit (Kept (Position (Seq (1)) - 1)) else Para);
                        After  : constant Natural :=
                          (if Original (Seq (M)) in Isolate_Initiator then Para
                           elsif Position (Seq (M)) < Kept_Count then Explicit (Kept (Position (Seq (M)) + 1))
                           else Para);
                        Sos : constant Bidi_Class := Direction_Of (Natural'Max (Level, Before));
                        Eos : constant Bidi_Class := Direction_Of (Natural'Max (Level, After));

                        function T (K : Positive) return Bidi_Class is (Types (Seq (K)));
                     begin
                        --  W1.
                        for K in 1 .. M loop
                           if T (K) = NSM then
                              Types (Seq (K)) :=
                                (if K = 1 then Sos
                                 elsif T (K - 1) in Isolate_Initiator | PDI then ON
                                 else T (K - 1));
                           end if;
                        end loop;

                        --  W2, W3.
                        declare
                           Last_Strong : Bidi_Class := Sos;
                        begin
                           for K in 1 .. M loop
                              case T (K) is
                                 when L | R | AL =>
                                    Last_Strong := T (K);
                                 when EN =>
                                    if Last_Strong = AL then
                                       Types (Seq (K)) := AN;
                                    end if;
                                 when others =>
                                    null;
                              end case;
                           end loop;
                           for K in 1 .. M loop
                              if T (K) = AL then
                                 Types (Seq (K)) := R;
                              end if;
                           end loop;
                        end;

                        --  W4.
                        for K in 2 .. M - 1 loop
                           if T (K) = ES and then T (K - 1) = EN and then T (K + 1) = EN then
                              Types (Seq (K)) := EN;
                           elsif T (K) = CS and then T (K - 1) = EN and then T (K + 1) = EN then
                              Types (Seq (K)) := EN;
                           elsif T (K) = CS and then T (K - 1) = AN and then T (K + 1) = AN then
                              Types (Seq (K)) := AN;
                           end if;
                        end loop;

                        --  W5.
                        declare
                           K : Positive := 1;
                        begin
                           while K <= M loop
                              if T (K) = ET then
                                 declare
                                    Last : Positive := K;
                                 begin
                                    while Last < M and then T (Last + 1) = ET loop
                                       Last := Last + 1;
                                    end loop;
                                    if (K > 1 and then T (K - 1) = EN) or else (Last < M and then T (Last + 1) = EN)
                                    then
                                       for J in K .. Last loop
                                          Types (Seq (J)) := EN;
                                       end loop;
                                    end if;
                                    K := Last + 1;
                                 end;
                              else
                                 K := K + 1;
                              end if;
                           end loop;
                        end;

                        --  W6.
                        for K in 1 .. M loop
                           if T (K) in ES | ET | CS then
                              Types (Seq (K)) := ON;
                           end if;
                        end loop;

                        --  W7.
                        declare
                           Last_Strong : Bidi_Class := Sos;
                        begin
                           for K in 1 .. M loop
                              case T (K) is
                                 when L | R =>
                                    Last_Strong := T (K);
                                 when EN =>
                                    if Last_Strong = L then
                                       Types (Seq (K)) := L;
                                    end if;
                                 when others =>
                                    null;
                              end case;
                           end loop;
                        end;

                        --  N0: paired brackets (BD16).
                        declare
                           Max_Openers : constant := 63;
                           type Opener is record
                              Pair_Code : Natural;
                              At_K      : Positive;
                           end record;
                           Openers : array (1 .. Max_Openers) of Opener;
                           Open_Count : Natural := 0;
                           Pair_Open  : Natural_Array;
                           Pair_Close : Natural_Array;
                           Pairs      : Natural := 0;

                           --  U+2329 and U+232A are canonically U+3008 and U+3009.
                           function Canonical (Code : Natural) return Natural is
                             (case Code is
                                 when 16#2329# => 16#3008#,
                                 when 16#232A# => 16#3009#,
                                 when others => Code);
                        begin
                           Find_Pairs :
                           for K in 1 .. M loop
                              if T (K) = ON then
                                 declare
                                    Code  : constant Natural := Text (Text'First + Seq (K) - 1);
                                    Entry_At : constant Natural := Bracket_Index (Code);
                                 begin
                                    if Entry_At /= 0 then
                                       if Brackets (Entry_At).Kind = Opening then
                                          exit Find_Pairs when Open_Count = Max_Openers;
                                          Open_Count := Open_Count + 1;
                                          Openers (Open_Count) :=
                                            (Pair_Code => Canonical (Brackets (Entry_At).Pair), At_K => K);
                                       else
                                          for Depth in reverse 1 .. Open_Count loop
                                             if Openers (Depth).Pair_Code = Canonical (Code) then
                                                Pairs := Pairs + 1;
                                                Pair_Open (Pairs) := Openers (Depth).At_K;
                                                Pair_Close (Pairs) := K;
                                                Open_Count := Depth - 1;
                                                exit;
                                             end if;
                                          end loop;
                                       end if;
                                    end if;
                                 end;
                              end if;
                           end loop Find_Pairs;

                           --  In order of their opening brackets.
                           for I in 2 .. Pairs loop
                              declare
                                 O : constant Natural := Pair_Open (I);
                                 C : constant Natural := Pair_Close (I);
                                 J : Natural := I - 1;
                              begin
                                 while J >= 1 and then Pair_Open (J) > O loop
                                    Pair_Open (J + 1) := Pair_Open (J);
                                    Pair_Close (J + 1) := Pair_Close (J);
                                    J := J - 1;
                                 end loop;
                                 Pair_Open (J + 1) := O;
                                 Pair_Close (J + 1) := C;
                              end;
                           end loop;

                           for P in 1 .. Pairs loop
                              declare
                                 O : constant Positive := Pair_Open (P);
                                 C : constant Positive := Pair_Close (P);
                                 Found_Embedding : Boolean := False;
                                 Found_Opposite  : Boolean := False;
                                 Resolved        : Bidi_Class := ON;

                                 procedure Set (K : Positive) is
                                 begin
                                    Types (Seq (K)) := Resolved;
                                    for J in K + 1 .. M loop
                                       exit when Original (Seq (J)) /= NSM;
                                       Types (Seq (J)) := Resolved;
                                    end loop;
                                 end Set;
                              begin
                                 for K in O + 1 .. C - 1 loop
                                    if Strong_Of (T (K)) = Embedding then
                                       Found_Embedding := True;
                                       exit;
                                    elsif Strong_Of (T (K)) /= ON then
                                       Found_Opposite := True;
                                    end if;
                                 end loop;

                                 if Found_Embedding then
                                    Resolved := Embedding;
                                 elsif Found_Opposite then
                                    declare
                                       Context : Bidi_Class := Sos;
                                    begin
                                       for K in reverse 1 .. O - 1 loop
                                          if Strong_Of (T (K)) /= ON then
                                             Context := Strong_Of (T (K));
                                             exit;
                                          end if;
                                       end loop;
                                       Resolved := (if Context /= Embedding then Context else Embedding);
                                    end;
                                 end if;

                                 if Resolved /= ON then
                                    Set (O);
                                    Set (C);
                                 end if;
                              end;
                           end loop;
                        end;

                        --  N1, N2.
                        declare
                           K : Positive := 1;
                        begin
                           while K <= M loop
                              if T (K) in Neutral_Or_Isolate then
                                 declare
                                    Last : Positive := K;
                                    Leading, Trailing : Bidi_Class;
                                 begin
                                    while Last < M and then T (Last + 1) in Neutral_Or_Isolate loop
                                       Last := Last + 1;
                                    end loop;
                                    Leading := (if K = 1 then Sos else Strong_Of (T (K - 1)));
                                    Trailing := (if Last = M then Eos else Strong_Of (T (Last + 1)));
                                    for J in K .. Last loop
                                       Types (Seq (J)) := (if Leading = Trailing then Leading else Embedding);
                                    end loop;
                                    K := Last + 1;
                                 end;
                              else
                                 K := K + 1;
                              end if;
                           end loop;
                        end;

                        --  I1, I2.
                        for K in 1 .. M loop
                           if Is_Odd (Lev (Seq (K))) then
                              if T (K) in L | EN | AN then
                                 Lev (Seq (K)) := Lev (Seq (K)) + 1;
                              end if;
                           else
                              if T (K) = R then
                                 Lev (Seq (K)) := Lev (Seq (K)) + 1;
                              elsif T (K) in AN | EN then
                                 Lev (Seq (K)) := Lev (Seq (K)) + 2;
                              end if;
                           end if;
                        end loop;
                     end;
                  end;
               end if;
            end;
         end loop;
      end;

      --  L1: separators, and whitespace before them or at the end of the line,
      --  return to the paragraph level.
      declare
         Trailing : Boolean := True;
      begin
         for I in reverse 1 .. N loop
            if Original (I) in S | B then
               Lev (I) := Para;
               Trailing := True;
            elsif Original (I) in WS | Isolate_Initiator | PDI or else Gone (I) then
               if Trailing then
                  Lev (I) := Para;
               end if;
            else
               Trailing := False;
            end if;
         end loop;
      end;

      for I in 1 .. N loop
         Levels (Levels'First + I - 1) := (if Gone (I) then Removed else Lev (I));
      end loop;
   end Resolve_Levels;

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

   ZWJ  : constant := 16#200D#;
   Lam  : constant := 16#0644#;

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
         Swallow : array (1 .. Count) of Boolean := [others => False];
         Ligated : array (1 .. Count) of Boolean := [others => False];
         Levels  : Level_Array (1 .. Count);
         Para    : Natural;
         Result  : Line;

         function Drawable (Codepoint : Natural) return Boolean is
           (Codepoint /= 0 and then (Has_Glyph = null or else Has_Glyph (Codepoint)));
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
         Shaped := Points;

         --  Arabic joining: each letter takes the form its neighbours, skipping
         --  transparent marks, call for.
         for I in 1 .. Count loop
            declare
               Kind : constant Joining_Type := Join_Of (Points (I));
            begin
               if Kind in Dual | Right | Left then
                  declare
                     Previous : Natural := 0;
                     Next     : Natural := 0;
                  begin
                     for J in reverse 1 .. I - 1 loop
                        if Join_Of (Points (J)) /= Transparent then
                           Previous := J;
                           exit;
                        end if;
                     end loop;
                     for J in I + 1 .. Count loop
                        if Join_Of (Points (J)) /= Transparent then
                           Next := J;
                           exit;
                        end if;
                     end loop;

                     declare
                        Joins_Before : constant Boolean :=
                          Kind in Dual | Right
                          and then Previous /= 0
                          and then Join_Of (Points (Previous)) in Dual | Left | Causing;
                        Joins_After  : constant Boolean :=
                          Kind in Dual | Left
                          and then Next /= 0
                          and then Join_Of (Points (Next)) in Dual | Right | Causing;
                        Alef_Entry : constant Natural :=
                          (if Points (I) = Lam and then Joins_After and then Next = I + 1
                           then Form_Index (Lam_Alef, Points (Next))
                           else 0);
                        Letter : constant Natural := Form_Index (Shapes, Points (I));
                     begin
                        if Alef_Entry /= 0
                          and then Drawable
                            (if Joins_Before then Lam_Alef (Alef_Entry).Final else Lam_Alef (Alef_Entry).Isolated)
                        then
                           Shaped (I) :=
                             (if Joins_Before then Lam_Alef (Alef_Entry).Final else Lam_Alef (Alef_Entry).Isolated);
                           Ligated (I) := True;
                           Swallow (Next) := True;
                        elsif Letter /= 0 then
                           declare
                              Form_Code : constant Natural :=
                                (if Joins_Before and then Joins_After then Shapes (Letter).Medial
                                 elsif Joins_Before then Shapes (Letter).Final
                                 elsif Joins_After then Shapes (Letter).Initial
                                 else Shapes (Letter).Isolated);
                           begin
                              if Drawable (Form_Code) then
                                 Shaped (I) := Form_Code;
                              end if;
                           end;
                        end if;
                     end;
                  end;
               end if;
            end;
         end loop;

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
                  Starts_Cluster : constant Boolean :=
                    Clusters = 0
                    or else (Units > 0 and then not Swallow (I) and then Points (I - 1) /= ZWJ);
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
         Laid : constant Line := Lay_Out (Content);
         Cut  : constant Natural := Cut_Columns (Laid, Columns);
         X    : Natural := 0;

         function Drawn (Column : Natural) return Natural is (if Column > Cut then Column - Cut else 0);
      begin
         for Item of Laid.Clusters loop
            if Cursor >= Content'Length then
               if Item.First + Item.Length = Content'Length then
                  return Drawn (if Item.Right_To_Left then X else X + Item.Units);
               end if;
            elsif Cursor >= Item.First and then Cursor < Item.First + Item.Length then
               return Drawn (if Item.Right_To_Left then X + Item.Units else X);
            end if;
            X := X + Item.Units;
         end loop;
         return Drawn (if Laid.Right_To_Left then 0 else X);
      end;
   end Caret_Column;

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
         Laid : constant Line := Lay_Out (Content);
         Half : constant Natural := Half_Column + 2 * Cut_Columns (Laid, Columns);
         X    : Natural := 0;
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

end Guikit.Bidi;
