package body Guikit.Utf8 is

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Is_Continuation (Value : Character) return Boolean is
      Code : constant Natural := Character'Pos (Value);
   begin
      return Code in 16#80# .. 16#BF#;
   end Is_Continuation;

   function Byte_At
     (Content : String;
      Index   : Integer)
      return Natural is
   begin
      return Character'Pos (Content (Index));
   end Byte_At;

   function Is_Required_Zero_Width_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Codepoint in 16#0300# .. 16#036F#
        or else Codepoint in 16#1AB0# .. 16#1AFF#
        or else Codepoint in 16#1DC0# .. 16#1DFF#
        or else Codepoint in 16#20D0# .. 16#20FF#
        or else Codepoint in 16#FE20# .. 16#FE2F#;
   end Is_Required_Zero_Width_Codepoint;

   function Is_Combining_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Is_Required_Zero_Width_Codepoint (Codepoint)
        --  Variation selectors (VS1-16, VS17-256).
        or else Codepoint in 16#FE00# .. 16#FE0F#
        or else Codepoint in 16#E0100# .. 16#E01EF#
        --  Common nonspacing marks of the scripts beyond Latin: Cyrillic
        --  titlo and friends, Hebrew points, Arabic harakat, Devanagari
        --  signs, Thai vowel and tone marks, and the combining kana
        --  voicing marks.
        or else Codepoint in 16#0483# .. 16#0489#
        or else Codepoint in 16#0591# .. 16#05BD#
        or else Codepoint = 16#05BF#
        or else Codepoint in 16#05C1# .. 16#05C2#
        or else Codepoint in 16#05C4# .. 16#05C5#
        or else Codepoint = 16#05C7#
        or else Codepoint in 16#0610# .. 16#061A#
        or else Codepoint in 16#064B# .. 16#065F#
        or else Codepoint = 16#0670#
        or else Codepoint in 16#06D6# .. 16#06DC#
        or else Codepoint in 16#06DF# .. 16#06E4#
        or else Codepoint in 16#06E7# .. 16#06E8#
        or else Codepoint in 16#06EA# .. 16#06ED#
        or else Codepoint in 16#0900# .. 16#0902#
        or else Codepoint = 16#093A#
        or else Codepoint = 16#093C#
        or else Codepoint in 16#0941# .. 16#0948#
        or else Codepoint = 16#094D#
        or else Codepoint in 16#0951# .. 16#0957#
        or else Codepoint in 16#0962# .. 16#0963#
        or else Codepoint = 16#0E31#
        or else Codepoint in 16#0E34# .. 16#0E3A#
        or else Codepoint in 16#0E47# .. 16#0E4E#
        or else Codepoint in 16#3099# .. 16#309A#;
   end Is_Combining_Codepoint;

   --  Zero-width joiner: binds the codepoints either side of it into one
   --  sequence (an emoji ZWJ sequence such as a family or a profession).
   Zero_Width_Joiner : constant := 16#200D#;

   --  Invisible format characters that take no cell: the zero-width space,
   --  non-joiner and joiner, the directional marks, embeddings and
   --  isolates, the word joiner and invisible operators, the byte-order
   --  mark, and the emoji tag characters (subdivision flags).
   function Is_Zero_Width_Format_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Codepoint in 16#200B# .. 16#200F#
        or else Codepoint in 16#202A# .. 16#202E#
        or else Codepoint in 16#2060# .. 16#2064#
        or else Codepoint in 16#2066# .. 16#2069#
        or else Codepoint = 16#FEFF#
        or else Codepoint = 16#E0001#
        or else Codepoint in 16#E0020# .. 16#E007F#;
   end Is_Zero_Width_Format_Codepoint;

   function Is_Wide_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Codepoint in 16#1100# .. 16#115F#
        or else Codepoint = 16#2329#
        or else Codepoint = 16#232A#
        or else Codepoint in 16#2E80# .. 16#A4CF#
        or else Codepoint in 16#AC00# .. 16#D7A3#
        or else Codepoint in 16#F900# .. 16#FAFF#
        or else Codepoint in 16#FE10# .. 16#FE19#
        or else Codepoint in 16#FE30# .. 16#FE6F#
        or else Codepoint in 16#FF00# .. 16#FF60#
        or else Codepoint in 16#FFE0# .. 16#FFE6#
        or else Codepoint in 16#1F300# .. 16#1FAFF#
        --  CJK Unified Ideographs Extension B onwards (plane 2) and
        --  Extension G onwards (plane 3).
        or else Codepoint in 16#20000# .. 16#2FFFD#
        or else Codepoint in 16#30000# .. 16#3FFFD#;
   end Is_Wide_Codepoint;

   function Codepoint_Display_Units
     (Codepoint : Natural)
      return Natural is
   begin
      if Is_Combining_Codepoint (Codepoint) or else Is_Zero_Width_Format_Codepoint (Codepoint) then
         return 0;
      elsif Is_Wide_Codepoint (Codepoint) then
         return 2;
      else
         return 1;
      end if;
   end Codepoint_Display_Units;

   procedure Decode_Next_Codepoint
     (Content               : String;
      Index                 : in out Integer;
      Codepoint             : out Natural;
      Replacement_Codepoint : Natural := 16#FFFD#)
   is
      B1 : constant Natural := Byte_At (Content, Index);
      B2 : Natural := 0;
      B3 : Natural := 0;
      B4 : Natural := 0;
   begin
      if B1 <= 16#7F# then
         Codepoint := B1;
         Index := Index + 1;
      elsif B1 in 16#C2# .. 16#DF#
        and then Index <= Content'Last - 1
        and then Is_Continuation (Content (Index + 1))
      then
         B2 := Byte_At (Content, Index + 1);
         Codepoint := ((B1 mod 32) * 64) + (B2 mod 64);
         Index := Index + 2;
      elsif B1 in 16#E0# .. 16#EF#
        and then Index <= Content'Last - 2
        and then Is_Continuation (Content (Index + 1))
        and then Is_Continuation (Content (Index + 2))
      then
         B2 := Byte_At (Content, Index + 1);
         B3 := Byte_At (Content, Index + 2);
         if (B1 = 16#E0# and then B2 < 16#A0#)
           or else (B1 = 16#ED# and then B2 > 16#9F#)
         then
            Codepoint := Replacement_Codepoint;
            Index := Index + 1;
         else
            Codepoint := ((B1 mod 16) * 4096) + ((B2 mod 64) * 64) + (B3 mod 64);
            Index := Index + 3;
         end if;
      elsif B1 in 16#F0# .. 16#F4#
        and then Index <= Content'Last - 3
        and then Is_Continuation (Content (Index + 1))
        and then Is_Continuation (Content (Index + 2))
        and then Is_Continuation (Content (Index + 3))
      then
         B2 := Byte_At (Content, Index + 1);
         B3 := Byte_At (Content, Index + 2);
         B4 := Byte_At (Content, Index + 3);
         if (B1 = 16#F0# and then B2 < 16#90#)
           or else (B1 = 16#F4# and then B2 > 16#8F#)
         then
            Codepoint := Replacement_Codepoint;
            Index := Index + 1;
         else
            Codepoint :=
              ((B1 mod 8) * 262_144)
              + ((B2 mod 64) * 4096)
              + ((B3 mod 64) * 64)
              + (B4 mod 64);
            Index := Index + 4;
         end if;
      else
         Codepoint := Replacement_Codepoint;
         Index := Index + 1;
      end if;
   end Decode_Next_Codepoint;

   function Display_Units
     (Content : String)
      return Natural
   is
      Index     : Integer := Content'First;
      Units     : Natural := 0;
      Codepoint : Natural := 0;
   begin
      while Index <= Content'Last loop
         Decode_Next_Codepoint (Content, Index, Codepoint);
         Units := Saturating_Add (Units, Codepoint_Display_Units (Codepoint));
      end loop;

      return Units;
   end Display_Units;

   --  Advance Index past one display cluster: the codepoint at Index, every
   --  zero-width codepoint after it (combining marks, variation selectors,
   --  invisible format characters), and -- across each zero-width joiner --
   --  the codepoint the joiner binds together with its own trailing marks.
   --  Width is the cells the whole cluster takes: the sum of its codepoints'
   --  widths, which is what the text renderer advances over when it draws
   --  the cluster codepoint by codepoint. Truncation and caret placement
   --  step over whole clusters so neither ever lands inside an emoji ZWJ
   --  sequence or between a base and its combining mark.
   procedure Next_Cluster
     (Content : String;
      Index   : in out Integer;
      Width   : out Natural)
   is
      Codepoint : Natural := 0;
      Joined    : Boolean;
      Peek      : Integer;
   begin
      Decode_Next_Codepoint (Content, Index, Codepoint);
      Width := Codepoint_Display_Units (Codepoint);
      Joined := Codepoint = Zero_Width_Joiner;
      while Index <= Content'Last loop
         Peek := Index;
         Decode_Next_Codepoint (Content, Peek, Codepoint);
         exit when not Joined and then Codepoint_Display_Units (Codepoint) > 0;
         Width := Saturating_Add (Width, Codepoint_Display_Units (Codepoint));
         Joined := Codepoint = Zero_Width_Joiner;
         Index := Peek;
      end loop;
   end Next_Cluster;

   function Prefix_By_Units
     (Content   : String;
      Max_Units : Natural)
      return String
   is
      Index : Integer := Content'First;
      Last  : Integer := Content'First - 1;
      Units : Natural := 0;
      Width : Natural := 0;
   begin
      if Max_Units = 0 or else Content'Length = 0 then
         return "";
      end if;

      while Index <= Content'Last loop
         Next_Cluster (Content, Index, Width);
         exit when Saturating_Add (Units, Width) > Max_Units;
         Units := Saturating_Add (Units, Width);
         Last := Index - 1;
      end loop;

      if Last < Content'First then
         return "";
      end if;

      return Content (Content'First .. Last);
   end Prefix_By_Units;

   function Fit_With_Ellipsis
     (Content   : String;
      Max_Units : Natural)
      return String
   is
      --  U+2026 HORIZONTAL ELLIPSIS, the truncation affordance.
      Ellipsis : constant String := Encode (16#2026#);
   begin
      if Max_Units = 0 then
         return "";
      elsif Display_Units (Content) <= Max_Units then
         return Content;
      elsif Max_Units < 2 then
         return Prefix_By_Units (Content, Max_Units);
      end if;

      declare
         Prefix  : constant String := Prefix_By_Units (Content, Max_Units - 1);
         Trimmed : constant String :=
           (if Prefix'Length > 0
              and then (Prefix (Prefix'Last) = '.' or else Prefix (Prefix'Last) = ' ')
            then Prefix (Prefix'First .. Prefix'Last - 1)
            else Prefix);
      begin
         if Trimmed = "" then
            return Prefix_By_Units (Content, Max_Units);
         end if;
         return Trimmed & Ellipsis;
      end;
   end Fit_With_Ellipsis;

   function Display_Units_Before
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Limit : constant Natural := Natural'Min (Cursor, Content'Length);
      Index : Integer := Content'First;
      Units : Natural := 0;
      Width : Natural := 0;
   begin
      if Limit = 0 then
         return 0;
      end if;

      --  Whole clusters: a cursor inside one measures to its end, so a caret
      --  never sits inside an emoji ZWJ sequence.
      while Index <= Content'Last and then Natural (Index - Content'First) < Limit loop
         Next_Cluster (Content, Index, Width);
         Units := Saturating_Add (Units, Width);
      end loop;

      return Units;
   end Display_Units_Before;

   function Is_Whitespace_Separator_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Codepoint = Character'Pos (' ')
        or else Codepoint = 9
        or else Codepoint = 10
        or else Codepoint = 11
        or else Codepoint = 12
        or else Codepoint = 13
        or else Codepoint = 16#85#
        or else Codepoint = 16#00A0#
        or else Codepoint = 16#1680#
        or else Codepoint in 16#2000# .. 16#200A#
        or else Codepoint = 16#2028#
        or else Codepoint = 16#2029#
        or else Codepoint = 16#202F#
        or else Codepoint = 16#205F#
        or else Codepoint = 16#3000#;
   end Is_Whitespace_Separator_Codepoint;

   --  Whether the byte at Index is a continuation byte of a well-formed
   --  sequence that starts before it (the 85 of "Å", C3 85), rather than a
   --  stray byte of its own.
   function Inside_Sequence
     (Content : String;
      Index   : Integer)
      return Boolean
   is
      Lead      : Integer := Index - 1;
      Next      : Integer;
      Ignored   : Natural;
   begin
      --  A sequence is at most four bytes, so its lead is at most three back.
      while Lead >= Content'First and then Index - Lead <= 3 loop
         if not Is_Continuation (Content (Lead)) then
            Next := Lead;
            Decode_Next_Codepoint (Content, Next, Ignored);
            return Next > Index;
         end if;
         Lead := Lead - 1;
      end loop;
      return False;
   end Inside_Sequence;

   function Whitespace_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural
   is
      Index     : constant Natural := Content'First + Position;
      Next      : Integer := Index;
      Codepoint : Natural := 0;
   begin
      if Position >= Content'Length then
         return 0;
      elsif Byte_At (Content, Index) = 16#85# then
         --  A stray C1 next-line byte (legacy Latin-1 text) is not a valid
         --  UTF-8 start, so it is a one-byte separator of its own. The same
         --  byte as the tail of a well-formed sequence -- the second byte of
         --  "Å" (C3 85), "х" (D1 85), "ą" (C4 85), or of many CJK characters
         --  -- is part of that letter, not whitespace.
         return (if Inside_Sequence (Content, Index) then 0 else 1);
      end if;

      Decode_Next_Codepoint
        (Content,
         Next,
         Codepoint,
         Replacement_Codepoint => 16#110000#);
      if Is_Whitespace_Separator_Codepoint (Codepoint) then
         return Natural (Next - Index);
      end if;

      return 0;
   end Whitespace_Separator_Length;

   function Byte_Offset_For_Display_Column
     (Content : String;
      Column  : Natural)
      return Natural
   is
      Index     : Integer := Content'First;
      Units     : Natural := 0;
      Codepoint : Natural := 0;
      Width     : Natural := 0;
      Offset    : Natural := 0;

      function After_Trailing_Zero_Width (Start : Integer) return Natural is
         Scan            : Integer := Start;
         Scanned_Point   : Natural := 0;
         Scanned_Width   : Natural := 0;
      begin
         while Scan <= Content'Last loop
            declare
               Unit_Start : constant Integer := Scan;
            begin
               Decode_Next_Codepoint (Content, Scan, Scanned_Point);
               Scanned_Width := Codepoint_Display_Units (Scanned_Point);
               exit when Scanned_Width > 0;
               Offset := Natural (Scan - Content'First);
            exception
               when Constraint_Error =>
                  return Natural (Unit_Start - Content'First);
            end;
         end loop;

         return Offset;
      end After_Trailing_Zero_Width;
   begin
      if Content'Length = 0 or else Column = 0 then
         return 0;
      end if;

      while Index <= Content'Last loop
         Offset := Natural (Index - Content'First);
         if Units >= Column then
            return After_Trailing_Zero_Width (Index);
         end if;

         Decode_Next_Codepoint (Content, Index, Codepoint);
         Width := Codepoint_Display_Units (Codepoint);
         if Width > 0 and then Saturating_Add (Units, Width) > Column then
            return Offset;
         end if;

         Units := Saturating_Add (Units, Width);
      end loop;

      return Content'Length;
   end Byte_Offset_For_Display_Column;

   function Is_Valid
     (Content : String)
      return Boolean
   is
      Invalid_Codepoint : constant Natural := 16#110000#;
      Index             : Integer := Content'First;
      Codepoint         : Natural := 0;
   begin
      while Index <= Content'Last loop
         Decode_Next_Codepoint
           (Content,
            Index,
            Codepoint,
            Replacement_Codepoint => Invalid_Codepoint);
         if Codepoint = Invalid_Codepoint then
            return False;
         end if;
      end loop;

      return True;
   end Is_Valid;

   function Encode (Codepoint : Natural) return String is
      function Byte (Value : Natural) return Character is (Character'Val (Value));
   begin
      if (Codepoint >= 16#D800# and then Codepoint <= 16#DFFF#)
        or else Codepoint > 16#10FFFF#
      then
         return "";
      elsif Codepoint <= 16#7F# then
         return String'(1 => Byte (Codepoint));
      elsif Codepoint <= 16#7FF# then
         return Byte (16#C0# + Codepoint / 16#40#)
           & Byte (16#80# + Codepoint mod 16#40#);
      elsif Codepoint <= 16#FFFF# then
         return Byte (16#E0# + Codepoint / 16#1000#)
           & Byte (16#80# + (Codepoint / 16#40#) mod 16#40#)
           & Byte (16#80# + Codepoint mod 16#40#);
      else
         return Byte (16#F0# + Codepoint / 16#40000#)
           & Byte (16#80# + (Codepoint / 16#1000#) mod 16#40#)
           & Byte (16#80# + (Codepoint / 16#40#) mod 16#40#)
           & Byte (16#80# + Codepoint mod 16#40#);
      end if;
   end Encode;

end Guikit.Utf8;
