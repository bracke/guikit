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
        or else Codepoint in 16#FE00# .. 16#FE0F#
        or else Codepoint in 16#E0100# .. 16#E01EF#;
   end Is_Combining_Codepoint;

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
        or else Codepoint in 16#1F300# .. 16#1FAFF#;
   end Is_Wide_Codepoint;

   function Codepoint_Display_Units
     (Codepoint : Natural)
      return Natural is
   begin
      if Is_Combining_Codepoint (Codepoint) then
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

   function Prefix_By_Units
     (Content   : String;
      Max_Units : Natural)
      return String
   is
      Index     : Integer := Content'First;
      Last      : Integer := Content'First - 1;
      Units     : Natural := 0;
      Codepoint : Natural := 0;
      Width     : Natural := 0;
   begin
      if Max_Units = 0 or else Content'Length = 0 then
         return "";
      end if;

      while Index <= Content'Last loop
         declare
            Start : constant Integer := Index;
         begin
            Decode_Next_Codepoint (Content, Index, Codepoint);
            Width := Codepoint_Display_Units (Codepoint);
            exit when Saturating_Add (Units, Width) > Max_Units;

            Units := Saturating_Add (Units, Width);
            Last := Index - 1;
         exception
            when Constraint_Error =>
               Index := Start + 1;
               exit when Saturating_Add (Units, 1) > Max_Units;
               Units := Saturating_Add (Units, 1);
               Last := Start;
         end;
      end loop;

      if Last < Content'First then
         return "";
      end if;

      return Content (Content'First .. Last);
   end Prefix_By_Units;

   function Display_Units_Before
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Limit     : constant Natural := Natural'Min (Cursor, Content'Length);
      Index     : Integer := Content'First;
      Units     : Natural := 0;
      Codepoint : Natural := 0;
   begin
      if Limit = 0 then
         return 0;
      end if;

      while Index <= Content'Last and then Natural (Index - Content'First) < Limit loop
         Decode_Next_Codepoint (Content, Index, Codepoint);
         Units := Saturating_Add (Units, Codepoint_Display_Units (Codepoint));
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
         --  A bare C1 next-line byte is not a valid UTF-8 start, so treat it as
         --  a one-byte separator before attempting to decode.
         return 1;
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
