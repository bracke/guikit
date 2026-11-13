package body Guikit.Utf8.Editing is

   function Is_Continuation (Value : Character) return Boolean is
     (Character'Pos (Value) in 16#80# .. 16#BF#);

   --  How far Decode_Next_Codepoint steps: a whole well-formed sequence,
   --  else one byte, by the same rules.
   function Unit_Length
     (Content : String;
      Index   : Integer)
      return Positive
   is
      Next      : Integer := Index;
      Codepoint : Natural;
   begin
      Decode_Next_Codepoint (Content, Next, Codepoint);
      pragma Unreferenced (Codepoint);
      return Next - Index;
   end Unit_Length;

   function Codepoint_At_Offset
     (Content : String;
      Offset  : Natural)
      return Natural
   is
      Index     : Integer := Content'First + Offset;
      Codepoint : Natural := 0;
   begin
      if Offset >= Content'Length then
         return 16#110000#;
      end if;

      Decode_Next_Codepoint
        (Content,
         Index,
         Codepoint,
         Replacement_Codepoint => 16#FFFD#);
      return Codepoint;
   end Codepoint_At_Offset;

   function Continuation_At
     (Content  : String;
      Position : Natural)
      return Boolean
   is
      Index : constant Natural := Content'First + Position;
      Lead  : Natural := Position;
   begin
      if Position = 0
        or else Position >= Content'Length
        or else not Is_Continuation (Content (Index))
      then
         return False;
      end if;

      while Lead > 0 and then Is_Continuation (Content (Content'First + Lead)) loop
         Lead := Lead - 1;
      end loop;

      declare
         Lead_Index : constant Integer := Content'First + Integer (Lead);
         Length     : constant Positive := Unit_Length (Content, Lead_Index);
      begin
         --  Unit_Length performs the complete UTF-8 validity check, including
         --  overlong, surrogate, out-of-range and truncated sequences.  Merely
         --  counting continuation bytes here would incorrectly merge the bytes
         --  of those malformed sequences into one cursor/deletion unit.
         return Length > 1 and then Position - Lead < Natural (Length);
      end;
   end Continuation_At;

   function Next_Unit_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
   begin
      if Position >= Content'Length then
         return Content'Length;
      end if;

      Position := Position + 1;
      while Position < Content'Length and then Continuation_At (Content, Position) loop
         Position := Position + 1;
      end loop;

      return Position;
   end Next_Unit_Boundary;

   function Previous_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Codepoint : Natural := 0;
   begin
      if Position = 0 then
         return 0;
      end if;

      loop
         Position := Position - 1;
         while Position > 0 and then Continuation_At (Content, Position) loop
            Position := Position - 1;
         end loop;

         Codepoint := Codepoint_At_Offset (Content, Position);
         exit when not Is_Combining_Codepoint (Codepoint) or else Position = 0;
      end loop;

      return Position;
   end Previous_Boundary;

   function Next_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Codepoint : Natural := 0;
   begin
      Position := Next_Unit_Boundary (Content, Position);
      while Position < Content'Length loop
         Codepoint := Codepoint_At_Offset (Content, Position);
         exit when not Is_Combining_Codepoint (Codepoint);
         Position := Next_Unit_Boundary (Content, Position);
      end loop;

      return Position;
   end Next_Boundary;

   function Boundary_At_Or_Before
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Codepoint : Natural := 0;
   begin
      while Position > 0
        and then Position < Content'Length
        and then Continuation_At (Content, Position)
      loop
         Position := Position - 1;
      end loop;

      if Position > 0 and then Position < Content'Length then
         Codepoint := Codepoint_At_Offset (Content, Position);
         if Is_Combining_Codepoint (Codepoint) then
            return Previous_Boundary (Content, Position);
         end if;
      end if;

      return Position;
   end Boundary_At_Or_Before;

   function Is_Word_Punctuation (Codepoint : Natural) return Boolean is
   begin
      return Codepoint = Character'Pos ('/')
        or else Codepoint = Character'Pos ('\')
        or else Codepoint = Character'Pos ('.')
        or else Codepoint = Character'Pos ('-')
        or else Codepoint = Character'Pos ('_');
   end Is_Word_Punctuation;

   function Word_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural
   is
   begin
      if Position >= Content'Length then
         return 0;
      end if;

      declare
         Length : constant Natural :=
           Whitespace_Separator_Length (Content, Position);
         Index  : constant Integer := Content'First + Integer (Position);
      begin
         if Length > 0 then
            return Length;
         elsif Is_Word_Punctuation (Character'Pos (Content (Index))) then
            return 1;
         end if;
      end;

      return 0;
   end Word_Separator_Length;

   function Previous_Word_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural
   is
      Max_Length : constant Natural := Natural'Min (4, Position);
   begin
      for Length in reverse 1 .. Max_Length loop
         if Word_Separator_Length (Content, Position - Length) = Length then
            return Length;
         end if;
      end loop;

      return 0;
   end Previous_Word_Separator_Length;

   function Previous_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Separator_Length : Natural;
   begin
      loop
         Separator_Length := Previous_Word_Separator_Length (Content, Position);
         exit when Separator_Length = 0;
         Position := Position - Separator_Length;
      end loop;

      while Position > 0 and then Previous_Word_Separator_Length (Content, Position) = 0 loop
         Position := Previous_Boundary (Content, Position);
      end loop;

      return Position;
   end Previous_Word_Boundary;

   function Next_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Separator_Length : Natural;
   begin
      loop
         Separator_Length := Word_Separator_Length (Content, Position);
         exit when Separator_Length = 0;
         Position := Natural'Min (Position + Separator_Length, Content'Length);
      end loop;

      while Position < Content'Length and then Word_Separator_Length (Content, Position) = 0 loop
         Position := Next_Boundary (Content, Position);
      end loop;

      return Position;
   end Next_Word_Boundary;

   function Remove_Range
     (Content : String;
      First   : Natural;
      Last    : Natural)
      return String
   is
      Start_Index : constant Natural := Natural'Min (First, Content'Length);
      End_Index   : constant Natural := Natural'Min (Last, Content'Length);
   begin
      if Content = "" or else Start_Index >= End_Index then
         return Content;
      end if;

      return
        (if Start_Index > 0
         then Content (Content'First .. Content'First + Start_Index - 1)
         else "")
        & (if End_Index < Content'Length
           then Content (Content'First + End_Index .. Content'Last)
           else "");
   end Remove_Range;

   procedure Delete_At
     (Text       : String;
      Cursor     : Natural;
      Backward   : Boolean;
      By_Word    : Boolean;
      New_Text   : out Ada.Strings.Unbounded.Unbounded_String;
      New_Cursor : out Natural)
   is
      Boundary : Natural;
   begin
      New_Text := Ada.Strings.Unbounded.To_Unbounded_String (Text);
      New_Cursor := Cursor;
      if Backward then
         if Cursor = 0 then
            return;
         end if;
         Boundary :=
           (if By_Word then Previous_Word_Boundary (Text, Cursor) else Previous_Boundary (Text, Cursor));
         New_Text := Ada.Strings.Unbounded.To_Unbounded_String (Remove_Range (Text, Boundary, Cursor));
         New_Cursor := Boundary;
      else
         if Cursor >= Text'Length then
            return;
         end if;
         Boundary := (if By_Word then Next_Word_Boundary (Text, Cursor) else Next_Boundary (Text, Cursor));
         New_Text := Ada.Strings.Unbounded.To_Unbounded_String (Remove_Range (Text, Cursor, Boundary));
      end if;
   end Delete_At;

end Guikit.Utf8.Editing;
