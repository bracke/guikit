with Guikit.Bidi.Data;

package body Guikit.Bidi.Levels is

   use Guikit.Bidi.Data;

   subtype Isolate_Initiator is Bidi_Class range LRI .. FSI;
   subtype Neutral_Or_Isolate is Bidi_Class
     with Static_Predicate => Neutral_Or_Isolate in B | S | WS | ON | LRI | RLI | FSI | PDI;

   Max_Depth : constant := 125;

   type Class_Array is array (Positive range <>) of Bidi_Class;
   type Natural_Array is array (Positive range <>) of Natural;
   type Flag_Array is array (Positive range <>) of Boolean;

   --  A paragraph being resolved, its characters numbered from 1.
   type Paragraph (N : Natural) is record
      Text         : Codepoint_Array (1 .. N);
      --  Each character's Bidi_Class.
      Original     : Class_Array (1 .. N);
      --  Each character's type as the rules have resolved it so far.
      Types        : Class_Array (1 .. N);
      Lev          : Natural_Array (1 .. N) := [others => 0];
      --  Removed by rule X9.
      Gone         : Flag_Array (1 .. N) := [others => False];
      --  The PDI closing an isolate initiator, and the initiator a PDI
      --  closes; 0 when there is none.
      Matching_PDI : Natural_Array (1 .. N) := [others => 0];
      Initiator_Of : Natural_Array (1 .. N) := [others => 0];
      --  The paragraph embedding level.
      Para         : Natural := 0;
   end record;

   --  An isolating run sequence (BD13): its characters in order, its start
   --  and end of sequence types, and its embedding direction.
   type Run_Sequence (M : Natural) is record
      Chars     : Natural_Array (1 .. M);
      Sos, Eos  : Bidi_Class;
      Embedding : Bidi_Class;
   end record;

   function Direction_Of (Level : Natural) return Bidi_Class is (if Is_Odd (Level) then R else L);

   --  The direction a resolved type counts as for N0 to N2: EN and AN are R.
   --  ON for anything that is not strong.
   function Strong_Of (Kind : Bidi_Class) return Bidi_Class is
     (case Kind is
         when L => L,
         when R | AL | EN | AN => R,
         when others => ON);

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

   --  The first strong direction in From .. To, skipping isolates (P2):
   --  L, R, or ON when there is none.
   function First_Strong (P : Paragraph; From, To : Natural) return Bidi_Class is
      I : Natural := From;
   begin
      while I <= To loop
         case P.Original (I) is
            when L =>
               return L;
            when R | AL =>
               return R;
            when Isolate_Initiator =>
               if P.Matching_PDI (I) = 0 then
                  return ON;
               end if;
               I := P.Matching_PDI (I);
            when others =>
               null;
         end case;
         I := I + 1;
      end loop;
      return ON;
   end First_Strong;

   --  BD9: the PDI matching each isolate initiator.
   procedure Match_Isolates (P : in out Paragraph) is
   begin
      for I in 1 .. P.N loop
         if P.Original (I) in Isolate_Initiator then
            declare
               Depth : Natural := 1;
            begin
               for J in I + 1 .. P.N loop
                  if P.Original (J) in Isolate_Initiator then
                     Depth := Depth + 1;
                  elsif P.Original (J) = PDI then
                     Depth := Depth - 1;
                     if Depth = 0 then
                        P.Matching_PDI (I) := J;
                        P.Initiator_Of (J) := I;
                        exit;
                     end if;
                  elsif P.Original (J) = B then
                     exit;
                  end if;
               end loop;
            end;
         end if;
      end loop;
   end Match_Isolates;

   --  X1 to X9: explicit levels and directions; X9's removals are marked Gone.
   procedure Resolve_Explicit (P : in out Paragraph) is
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

      --  Whether a new level can be pushed (X2 to X5c).
      function Room_For (Level : Natural) return Boolean is
        (Level <= Max_Depth and then Overflow_Isolates = 0 and then Overflow_Embeddings = 0);

      procedure Take_Top (I : Positive) is
      begin
         P.Lev (I) := Stack (Depth).Level;
         case Stack (Depth).Override is
            when Force_L => P.Types (I) := L;
            when Force_R => P.Types (I) := R;
            when Neutral => null;
         end case;
      end Take_Top;

      --  X2 to X5: an embedding or override initiator.
      procedure Open_Embedding (I : Positive) is
         New_Level : constant Natural :=
           (if P.Original (I) in RLE | RLO then Next_Odd (Stack (Depth).Level) else Next_Even (Stack (Depth).Level));
      begin
         P.Lev (I) := Stack (Depth).Level;
         P.Gone (I) := True;
         if Room_For (New_Level) then
            Depth := Depth + 1;
            Stack (Depth) :=
              (Level    => New_Level,
               Override =>
                 (case P.Original (I) is
                     when RLO => Force_R,
                     when LRO => Force_L,
                     when others => Neutral),
               Isolate  => False);
         elsif Overflow_Isolates = 0 then
            Overflow_Embeddings := Overflow_Embeddings + 1;
         end if;
      end Open_Embedding;

      --  X5a to X5c: an isolate initiator.
      procedure Open_Isolate (I : Positive) is
         To_Right  : constant Boolean :=
           P.Original (I) = RLI
           or else (P.Original (I) = FSI
                    and then First_Strong
                      (P, I + 1, (if P.Matching_PDI (I) = 0 then P.N else P.Matching_PDI (I) - 1)) = R);
         New_Level : Natural;
      begin
         Take_Top (I);
         New_Level := (if To_Right then Next_Odd (Stack (Depth).Level) else Next_Even (Stack (Depth).Level));
         if Room_For (New_Level) then
            Valid_Isolates := Valid_Isolates + 1;
            Depth := Depth + 1;
            Stack (Depth) := (Level => New_Level, Override => Neutral, Isolate => True);
         else
            Overflow_Isolates := Overflow_Isolates + 1;
         end if;
      end Open_Isolate;

      --  X6a: a PDI.
      procedure Close_Isolate (I : Positive) is
      begin
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
      end Close_Isolate;

      --  X7: a PDF.
      procedure Close_Embedding (I : Positive) is
      begin
         if Overflow_Isolates > 0 then
            null;
         elsif Overflow_Embeddings > 0 then
            Overflow_Embeddings := Overflow_Embeddings - 1;
         elsif not Stack (Depth).Isolate and then Depth >= 2 then
            Depth := Depth - 1;
         end if;
         P.Lev (I) := Stack (Depth).Level;
         P.Gone (I) := True;
      end Close_Embedding;
   begin
      Stack (1) := (Level => P.Para, Override => Neutral, Isolate => False);
      for I in 1 .. P.N loop
         case P.Original (I) is
            when RLE | LRE | RLO | LRO =>
               Open_Embedding (I);
            when Isolate_Initiator =>
               Open_Isolate (I);
            when PDI =>
               Close_Isolate (I);
            when PDF =>
               Close_Embedding (I);
            when B =>
               P.Lev (I) := P.Para;
            when BN =>
               P.Lev (I) := Stack (Depth).Level;
               P.Gone (I) := True;
            when others =>
               Take_Top (I);
         end case;
      end loop;
   end Resolve_Explicit;

   --  W1 to W7: the weak types of one sequence.
   procedure Resolve_Weak (P : in out Paragraph; Seq : Run_Sequence) is
      M : constant Natural := Seq.M;

      function T (K : Positive) return Bidi_Class is (P.Types (Seq.Chars (K)));

      procedure Set (K : Positive; Kind : Bidi_Class) is
      begin
         P.Types (Seq.Chars (K)) := Kind;
      end Set;

      Last_Strong : Bidi_Class;
      --  W5's scan: where the next run of European terminators may start.
      Run_Start   : Positive;
   begin
      --  W1.
      for K in 1 .. M loop
         if T (K) = NSM then
            Set (K, (if K = 1 then Seq.Sos elsif T (K - 1) in Isolate_Initiator | PDI then ON else T (K - 1)));
         end if;
      end loop;

      --  W2, W3.
      Last_Strong := Seq.Sos;
      for K in 1 .. M loop
         case T (K) is
            when L | R | AL =>
               Last_Strong := T (K);
            when EN =>
               if Last_Strong = AL then
                  Set (K, AN);
               end if;
            when others =>
               null;
         end case;
      end loop;
      for K in 1 .. M loop
         if T (K) = AL then
            Set (K, R);
         end if;
      end loop;

      --  W4.
      for K in 2 .. M - 1 loop
         if T (K) in ES | CS and then T (K - 1) = EN and then T (K + 1) = EN then
            Set (K, EN);
         elsif T (K) = CS and then T (K - 1) = AN and then T (K + 1) = AN then
            Set (K, AN);
         end if;
      end loop;

      --  W5.
      Run_Start := 1;
      while Run_Start <= M loop
         if T (Run_Start) = ET then
            declare
               Last : Positive := Run_Start;
            begin
               while Last < M and then T (Last + 1) = ET loop
                  Last := Last + 1;
               end loop;
               if (Run_Start > 1 and then T (Run_Start - 1) = EN) or else (Last < M and then T (Last + 1) = EN) then
                  for J in Run_Start .. Last loop
                     Set (J, EN);
                  end loop;
               end if;
               Run_Start := Last + 1;
            end;
         else
            Run_Start := Run_Start + 1;
         end if;
      end loop;

      --  W6.
      for K in 1 .. M loop
         if T (K) in ES | ET | CS then
            Set (K, ON);
         end if;
      end loop;

      --  W7.
      Last_Strong := Seq.Sos;
      for K in 1 .. M loop
         case T (K) is
            when L | R =>
               Last_Strong := T (K);
            when EN =>
               if Last_Strong = L then
                  Set (K, L);
               end if;
            when others =>
               null;
         end case;
      end loop;
   end Resolve_Weak;

   --  N0: the paired brackets of one sequence (BD16).
   procedure Resolve_Brackets (P : in out Paragraph; Seq : Run_Sequence) is
      M : constant Natural := Seq.M;

      function T (K : Positive) return Bidi_Class is (P.Types (Seq.Chars (K)));

      --  U+2329 and U+232A are canonically U+3008 and U+3009.
      function Canonical (Code : Natural) return Natural is
        (case Code is
            when 16#2329# => 16#3008#,
            when 16#232A# => 16#3009#,
            when others => Code);

      Max_Openers : constant := 63;
      type Opener is record
         Pair_Code : Natural;
         At_K      : Positive;
      end record;
      Openers    : array (1 .. Max_Openers) of Opener;
      Open_Count : Natural := 0;
      Pair_Open  : Natural_Array (1 .. M);
      Pair_Close : Natural_Array (1 .. M);
      Pairs      : Natural := 0;

      --  Record the pair a closing bracket at K completes, if any.
      procedure Close (K : Positive; Code : Natural) is
      begin
         for Depth in reverse 1 .. Open_Count loop
            if Openers (Depth).Pair_Code = Canonical (Code) then
               Pairs := Pairs + 1;
               Pair_Open (Pairs) := Openers (Depth).At_K;
               Pair_Close (Pairs) := K;
               Open_Count := Depth - 1;
               return;
            end if;
         end loop;
      end Close;

      --  Put the pairs in order of their opening brackets.
      procedure Sort_Pairs is
      begin
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
      end Sort_Pairs;

      --  The direction the pair O .. C resolves to, or ON when it stays.
      function Pair_Direction (O, C : Positive) return Bidi_Class is
         Found_Opposite : Boolean := False;
      begin
         for K in O + 1 .. C - 1 loop
            if Strong_Of (T (K)) = Seq.Embedding then
               return Seq.Embedding;
            elsif Strong_Of (T (K)) /= ON then
               Found_Opposite := True;
            end if;
         end loop;
         if not Found_Opposite then
            return ON;
         end if;
         --  Only the opposite direction inside: the pair takes the direction
         --  of the strong context before it.
         for K in reverse 1 .. O - 1 loop
            if Strong_Of (T (K)) /= ON then
               return Strong_Of (T (K));
            end if;
         end loop;
         return Seq.Sos;
      end Pair_Direction;

      --  Give the bracket at K, and the marks after it, the type Kind.
      procedure Set (K : Positive; Kind : Bidi_Class) is
      begin
         P.Types (Seq.Chars (K)) := Kind;
         for J in K + 1 .. M loop
            exit when P.Original (Seq.Chars (J)) /= NSM;
            P.Types (Seq.Chars (J)) := Kind;
         end loop;
      end Set;
   begin
      Find_Pairs :
      for K in 1 .. M loop
         if T (K) = ON then
            declare
               Code     : constant Natural := P.Text (Seq.Chars (K));
               Entry_At : constant Natural := Bracket_Index (Code);
            begin
               if Entry_At /= 0 then
                  if Brackets (Entry_At).Kind = Opening then
                     exit Find_Pairs when Open_Count = Max_Openers;
                     Open_Count := Open_Count + 1;
                     Openers (Open_Count) := (Pair_Code => Canonical (Brackets (Entry_At).Pair), At_K => K);
                  else
                     Close (K, Code);
                  end if;
               end if;
            end;
         end if;
      end loop Find_Pairs;

      Sort_Pairs;

      for Pair in 1 .. Pairs loop
         declare
            Resolved : constant Bidi_Class := Pair_Direction (Pair_Open (Pair), Pair_Close (Pair));
         begin
            if Resolved /= ON then
               Set (Pair_Open (Pair), Resolved);
               Set (Pair_Close (Pair), Resolved);
            end if;
         end;
      end loop;
   end Resolve_Brackets;

   --  N1, N2: the neutrals of one sequence.
   procedure Resolve_Neutrals (P : in out Paragraph; Seq : Run_Sequence) is
      M : constant Natural := Seq.M;

      function T (K : Positive) return Bidi_Class is (P.Types (Seq.Chars (K)));

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
               Leading := (if K = 1 then Seq.Sos else Strong_Of (T (K - 1)));
               Trailing := (if Last = M then Seq.Eos else Strong_Of (T (Last + 1)));
               for J in K .. Last loop
                  P.Types (Seq.Chars (J)) := (if Leading = Trailing then Leading else Seq.Embedding);
               end loop;
               K := Last + 1;
            end;
         else
            K := K + 1;
         end if;
      end loop;
   end Resolve_Neutrals;

   --  I1, I2: the implicit levels of one sequence.
   procedure Resolve_Implicit (P : in out Paragraph; Seq : Run_Sequence) is
   begin
      for Char of Seq.Chars loop
         if Is_Odd (P.Lev (Char)) then
            if P.Types (Char) in L | EN | AN then
               P.Lev (Char) := P.Lev (Char) + 1;
            end if;
         elsif P.Types (Char) = R then
            P.Lev (Char) := P.Lev (Char) + 1;
         elsif P.Types (Char) in AN | EN then
            P.Lev (Char) := P.Lev (Char) + 2;
         end if;
      end loop;
   end Resolve_Implicit;

   --  X10: the level runs, chained into isolating run sequences, each
   --  resolved in turn. Each sequence's sos and eos come from the explicit
   --  levels, before any sequence's implicit levels are resolved.
   procedure Resolve_Sequences (P : in out Paragraph) is
      N          : constant Natural := P.N;
      Explicit   : constant Natural_Array := P.Lev;
      --  The characters X9 keeps, and each one's place among them.
      Kept       : Natural_Array (1 .. N);
      Kept_Count : Natural := 0;
      Position   : Natural_Array (1 .. N) := [others => 0];
      --  Level runs, as ranges of Kept, and the run of each kept place.
      Run_Start  : Natural_Array (1 .. N);
      Run_End    : Natural_Array (1 .. N);
      Run_Count  : Natural := 0;
      Run_Of     : Natural_Array (1 .. N) := [others => 0];

      --  A run continues a sequence when it opens with the PDI that closes
      --  the isolate ending some earlier run.
      function Continues (Run : Positive) return Boolean is
         First_Char : constant Positive := Kept (Run_Start (Run));
         Initiator  : constant Natural := P.Initiator_Of (First_Char);
      begin
         return P.Original (First_Char) = PDI
           and then Initiator /= 0
           and then Run_End (Run_Of (Position (Initiator))) = Position (Initiator);
      end Continues;

      --  The sequence starting with run First_Run: Chars (1 .. Count).
      procedure Chain (First_Run : Positive; Chars : out Natural_Array; Count : out Natural) is
         Current : Positive := First_Run;
      begin
         Count := 0;
         loop
            for K in Run_Start (Current) .. Run_End (Current) loop
               Count := Count + 1;
               Chars (Count) := Kept (K);
            end loop;
            declare
               Last_Char : constant Positive := Chars (Count);
               Closing   : constant Natural := P.Matching_PDI (Last_Char);
            begin
               exit when P.Original (Last_Char) not in Isolate_Initiator
                 or else Closing = 0
                 or else Run_Start (Run_Of (Position (Closing))) /= Position (Closing);
               Current := Run_Of (Position (Closing));
            end;
         end loop;
      end Chain;

      --  The sequence of Chars with its sos, eos and embedding direction.
      function Sequence_Of (Chars : Natural_Array) return Run_Sequence is
         First  : constant Positive := Chars (Chars'First);
         Last   : constant Positive := Chars (Chars'Last);
         Level  : constant Natural := Explicit (First);
         Before : constant Natural := (if Position (First) > 1 then Explicit (Kept (Position (First) - 1)) else P.Para);
         After  : constant Natural :=
           (if P.Original (Last) in Isolate_Initiator then P.Para
            elsif Position (Last) < Kept_Count then Explicit (Kept (Position (Last) + 1))
            else P.Para);
      begin
         return
           (M         => Chars'Length,
            Chars     => Chars,
            Sos       => Direction_Of (Natural'Max (Level, Before)),
            Eos       => Direction_Of (Natural'Max (Level, After)),
            Embedding => Direction_Of (Level));
      end Sequence_Of;
   begin
      for I in 1 .. N loop
         if not P.Gone (I) then
            Kept_Count := Kept_Count + 1;
            Kept (Kept_Count) := I;
            Position (I) := Kept_Count;
         end if;
      end loop;

      for K in 1 .. Kept_Count loop
         if K = 1 or else P.Lev (Kept (K)) /= P.Lev (Kept (K - 1)) then
            Run_Count := Run_Count + 1;
            Run_Start (Run_Count) := K;
         end if;
         Run_End (Run_Count) := K;
         Run_Of (K) := Run_Count;
      end loop;

      for Run in 1 .. Run_Count loop
         if not Continues (Run) then
            declare
               Chars : Natural_Array (1 .. N);
               Count : Natural;
            begin
               Chain (Run, Chars, Count);
               declare
                  Sequence : constant Run_Sequence := Sequence_Of (Chars (1 .. Count));
               begin
                  Resolve_Weak (P, Sequence);
                  Resolve_Brackets (P, Sequence);
                  Resolve_Neutrals (P, Sequence);
                  Resolve_Implicit (P, Sequence);
               end;
            end;
         end if;
      end loop;
   end Resolve_Sequences;

   --  L1: separators, and whitespace before them or at the end of the line,
   --  return to the paragraph level.
   procedure Reset_Whitespace (P : in out Paragraph) is
      Trailing : Boolean := True;
   begin
      for I in reverse 1 .. P.N loop
         if P.Original (I) in S | B then
            P.Lev (I) := P.Para;
            Trailing := True;
         elsif P.Original (I) in WS | Isolate_Initiator | PDI or else P.Gone (I) then
            if Trailing then
               P.Lev (I) := P.Para;
            end if;
         else
            Trailing := False;
         end if;
      end loop;
   end Reset_Whitespace;

   procedure Resolve
     (Text            : Codepoint_Array;
      Direction       : Paragraph_Direction;
      Levels          : out Level_Array;
      Paragraph_Level : out Natural)
   is
      P : Paragraph (Text'Length);
   begin
      for I in 1 .. P.N loop
         P.Text (I) := Text (Text'First + I - 1);
         P.Original (I) := Class_Of (P.Text (I));
      end loop;
      P.Types := P.Original;

      Match_Isolates (P);

      --  P2, P3.
      P.Para :=
        (case Direction is
            when Left_To_Right => 0,
            when Right_To_Left => 1,
            when Auto => (if First_Strong (P, 1, P.N) = R then 1 else 0));
      Paragraph_Level := P.Para;

      Resolve_Explicit (P);
      Resolve_Sequences (P);
      Reset_Whitespace (P);

      for I in 1 .. P.N loop
         Levels (Levels'First + I - 1) := (if P.Gone (I) then Removed else P.Lev (I));
      end loop;
   end Resolve;

end Guikit.Bidi.Levels;
