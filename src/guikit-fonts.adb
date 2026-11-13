with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Textrender.Fonts;

with Guikit.Errors;

package body Guikit.Fonts is

   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Textrender.Fonts.Glyph_Lookup_Result;
   use type Textrender.Fonts.Load_Result;

   Unit_Name : constant String := "Guikit.Fonts";

   Max_Discovered_Fonts     : constant Natural := 256;
   Max_Search_Depth         : constant Natural := 4;
   Max_Scanned_Font_Entries : constant Natural := 100_000;

   --  Where a known font lives: a whole path, or a file name looked for in
   --  each of the host's font folders (Windows' Fonts folder is wherever
   --  Windows is, and a font installed for one user lives in their profile).
   type Location_Kind is (Absolute, In_Font_Folders);

   --  Text_Fallback is the font's rank in the text part of the fallback chain
   --  (0: not in it). Primary says whether it may be the monospace primary.
   type Known_Font is record
      Path          : Unbounded_String;
      Where         : Location_Kind;
      Primary       : Boolean;
      Text_Fallback : Natural;
   end record;

   function At_Path (Path : String; Primary : Boolean; Text_Fallback : Natural := 0) return Known_Font is
     ((Path          => To_Unbounded_String (Path),
       Where         => Absolute,
       Primary       => Primary,
       Text_Fallback => Text_Fallback));

   function Named (Name : String; Primary : Boolean; Text_Fallback : Natural := 0) return Known_Font is
     ((Path          => To_Unbounded_String (Name),
       Where         => In_Font_Folders,
       Primary       => Primary,
       Text_Fallback => Text_Fallback));

   --  Every known font, once. In primary order: the first that loads is the
   --  primary, so the monospace faces lead and the broad proportional ones
   --  only stand in on a system without any of them. The text fallbacks, by
   --  rank: DejaVu Sans Mono for monospace symbols (stars, arrows, box
   --  drawing), DejaVu Sans for broad proportional symbol coverage, VL Gothic
   --  for CJK ideographs and kana (a TrueType glyf face the renderer can
   --  rasterize; the CFF/.ttc Noto CJK fonts are not), Noto Sans for broad
   --  international Latin, and the Windows/macOS system faces for hosts without
   --  those. A missing font is simply skipped.
   Known_Fonts : constant array (Positive range <>) of Known_Font :=
     [At_Path ("/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf", Primary => True),
      At_Path ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", Primary => True, Text_Fallback => 1),
      At_Path ("/usr/share/fonts/truetype/noto/NotoMono-Regular.ttf", Primary => True),
      At_Path ("/usr/share/fonts/noto/NotoSansMono-Regular.ttf", Primary => True),
      At_Path ("/usr/share/fonts/TTF/DejaVuSansMono.ttf", Primary => True, Text_Fallback => 2),
      At_Path ("/usr/share/fonts/truetype/vlgothic/VL-Gothic-Regular.ttf", Primary => True, Text_Fallback => 5),
      At_Path ("/usr/share/fonts/truetype/vlgothic/VL-PGothic-Regular.ttf", Primary => True, Text_Fallback => 6),
      At_Path ("/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf", Primary => True, Text_Fallback => 7),
      At_Path ("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf", Primary => True),
      At_Path ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", Primary => True, Text_Fallback => 3),
      At_Path ("/usr/share/fonts/TTF/DejaVuSans.ttf", Primary => True, Text_Fallback => 4),
      At_Path ("/usr/share/fonts/truetype/freefont/FreeSans.ttf", Primary => True),
      At_Path ("/usr/share/fonts/truetype/fonts-japanese-gothic.ttf", Primary => True),
      At_Path ("/System/Library/Fonts/Supplemental/Arial.ttf", Primary => False, Text_Fallback => 10),
      Named ("consola.ttf", Primary => True),
      Named ("Monaco.ttf", Primary => True),
      Named ("malgun.ttf", Primary => True),
      Named ("seguiemj.ttf", Primary => True),
      Named ("segoeui.ttf", Primary => True, Text_Fallback => 8),
      Named ("arial.ttf", Primary => True, Text_Fallback => 9)];

   Last_Text_Fallback : constant Natural := 10;

   Cached_Default_Key   : Unbounded_String;
   Cached_Default_Path  : Unbounded_String;
   Cached_Default_Ready : Boolean := False;

   --  ASCII-only lowering: the suffixes and names compared are ASCII, and
   --  bytes of a multi-byte UTF-8 name pass through untouched.
   function To_Lower (Text : String) return String is
      Result : String := Text;
   begin
      for Char of Result loop
         if Char in 'A' .. 'Z' then
            Char := Ada.Characters.Handling.To_Lower (Char);
         end if;
      end loop;
      return Result;
   end To_Lower;

   function Has_Suffix
     (Text   : String;
      Suffix : String)
      return Boolean is
     (Text'Length >= Suffix'Length
      and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix);

   --  Folder and Name joined with the folder's own separator.
   function Join (Folder : String; Name : String) return String is
   begin
      if Folder = "" then
         return Name;
      elsif Folder (Folder'Last) in '/' | '\' then
         return Folder & Name;
      elsif Ada.Strings.Fixed.Index (Folder, "\") > 0 and then Ada.Strings.Fixed.Index (Folder, "/") = 0 then
         return Folder & '\' & Name;
      end if;
      return Folder & '/' & Name;
   end Join;

   --  The part of Path after its last separator.
   function Simple_Name (Path : String) return String is
   begin
      for Index in reverse Path'Range loop
         if Path (Index) in '/' | '\' then
            return Path (Index + 1 .. Path'Last);
         end if;
      end loop;
      return Path;
   end Simple_Name;

   function Is_Ordinary_File (Path : String) return Boolean is
   begin
      return Path /= ""
        and then Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File;
   exception
      when Swallowed : others =>
         Guikit.Errors.Note (Swallowed, Unit_Name);
         return False;
   end Is_Ordinary_File;

   function Is_Directory (Path : String) return Boolean is
   begin
      return Path /= ""
        and then Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Directory;
   exception
      when Swallowed : others =>
         Guikit.Errors.Note (Swallowed, Unit_Name);
         return False;
   end Is_Directory;

   function Is_Font_File (Path : String) return Boolean is
      Lower : constant String := To_Lower (Path);
   begin
      return Has_Suffix (Lower, ".ttf") or else Has_Suffix (Lower, ".otf");
   end Is_Font_File;

   function Is_Known_Unsupported_Renderer_Font (Path : String) return Boolean is
      --  Match the file's simple name, not the whole path, so a font merely
      --  living in a directory whose name contains one of these substrings
      --  (e.g. ".../liberation/SomeOtherFont.ttf", or an explicit override
      --  under such a directory) is not wrongly blocked.
      Lower : constant String := To_Lower (Simple_Name (Path));
   begin
      --  Noto Color Emoji was on this list because the renderer could not read
      --  it: it carries no outlines at all, and loading a font without them
      --  failed outright. It can be read now -- the pictures inside it are
      --  decoded and drawn as colour glyphs -- so the exclusion has become the
      --  only thing keeping emoji off the screen.
      return Ada.Strings.Fixed.Index (Lower, "droidsansfallbackfull.ttf") > 0
        or else Ada.Strings.Fixed.Index (Lower, "liberation") > 0
        or else Ada.Strings.Fixed.Index (Lower, "unifont.ttf") > 0;
   end Is_Known_Unsupported_Renderer_Font;

   procedure Append_Unique
     (Paths : in out Path_List;
      Path  : String) is
   begin
      if Path = "" then
         return;
      end if;
      for Existing of Paths loop
         if Existing = Path then
            return;
         end if;
      end loop;
      Paths.Append (Path);
   end Append_Unique;

   --  Every place Font may be: its path, or its file name in each folder.
   function Locations (Font : Known_Font; Font_Directories : Path_List) return Path_List is
      Result : Path_List;
   begin
      case Font.Where is
         when Absolute =>
            Result.Append (To_String (Font.Path));
         when In_Font_Folders =>
            for Folder of Font_Directories loop
               Result.Append (Join (Folder, To_String (Font.Path)));
            end loop;
      end case;
      return Result;
   end Locations;

   function Default_Font_Directories return Path_List is
      Result : Path_List;

      function Variable (Name : String) return String is
        (if Ada.Environment_Variables.Exists (Name) then Ada.Environment_Variables.Value (Name) else "");

      Home      : constant String := Variable ("HOME");
      Data_Home : constant String := Variable ("XDG_DATA_HOME");
      Windows   : constant String :=
        (if Variable ("WINDIR") /= "" then Variable ("WINDIR") else Variable ("SystemRoot"));
      Local     : constant String := Variable ("LOCALAPPDATA");

      procedure Place (Folder : String) is
      begin
         if Is_Directory (Folder) then
            Append_Unique (Result, Folder);
         end if;
      end Place;
   begin
      if Windows /= "" then
         Place (Join (Windows, "Fonts"));
      end if;
      if Local /= "" then
         Place (Join (Local, "Microsoft\Windows\Fonts"));
      end if;
      Place ("/System/Library/Fonts");
      Place ("/Library/Fonts");
      if Home /= "" then
         Place (Home & "/Library/Fonts");
      end if;
      Place ("/usr/share/fonts");
      Place ("/usr/local/share/fonts");
      if Data_Home /= "" and then Data_Home (Data_Home'First) = '/' then
         Place (Data_Home & "/fonts");
      elsif Home /= "" then
         Place (Home & "/.local/share/fonts");
      end if;
      if Home /= "" then
         Place (Home & "/.fonts");
      end if;
      return Result;
   exception
      when Swallowed : others =>
         Guikit.Errors.Note (Swallowed, Unit_Name);
         return Result;
   end Default_Font_Directories;

   procedure Scan_Font_Directory
     (Paths   : in out Path_List;
      Root    : String;
      Depth   : Natural;
      Scanned : in out Natural)
   is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      Names  : Path_List;
   begin
      if Natural (Paths.Length) >= Max_Discovered_Fonts
        or else Scanned >= Max_Scanned_Font_Entries
        or else Depth > Max_Search_Depth
        or else not Is_Directory (Root)
      then
         return;
      end if;

      --  Listed first and visited after, so the search is closed before any
      --  recursion opens another.
      Ada.Directories.Start_Search
        (Search, Root, "",
         [Ada.Directories.Directory | Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name /= "." and then Name /= ".." then
               Names.Append (Name);
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);

      for Name of Names loop
         exit when Natural (Paths.Length) >= Max_Discovered_Fonts or else Scanned >= Max_Scanned_Font_Entries;
         Scanned := Scanned + 1;
         declare
            Full : constant String := Join (Root, Name);
         begin
            if Is_Directory (Full) then
               --  A linked folder is not followed: it can loop back on itself.
               --  (On Windows this reports no links; the depth bound still
               --  ends any loop.)
               if not GNAT.OS_Lib.Is_Symbolic_Link (Full) then
                  Scan_Font_Directory (Paths, Full, Depth + 1, Scanned);
               end if;
            elsif Is_Font_File (Full) and then not Is_Known_Unsupported_Renderer_Font (Full) then
               Append_Unique (Paths, Full);
            end if;
         end;
      end loop;
   exception
      when Failure : others =>
         Guikit.Errors.Note (Failure, Unit_Name);
   end Scan_Font_Directory;

   --  The known primary candidates, then every font the folder scan finds, in
   --  name order.
   function Candidate_Fonts (Font_Directories : Path_List) return Path_List is
      Paths      : Path_List;
      Discovered : Path_List;
      Scanned    : Natural := 0;
      package Sorting is new Guikit.Text.Font_Path_Vectors.Generic_Sorting;
   begin
      for Font of Known_Fonts loop
         if Font.Primary then
            for Path of Locations (Font, Font_Directories) loop
               if Is_Font_File (Path) and then not Is_Known_Unsupported_Renderer_Font (Path) then
                  Append_Unique (Paths, Path);
               end if;
            end loop;
         end if;
      end loop;

      for Root of Font_Directories loop
         Scan_Font_Directory (Discovered, Root, 0, Scanned);
         exit when Scanned >= Max_Scanned_Font_Entries;
      end loop;

      Sorting.Sort (Discovered);
      for Path of Discovered loop
         Append_Unique (Paths, Path);
      end loop;

      return Paths;
   end Candidate_Fonts;

   function Is_Loadable_Font (Path : String) return Boolean is
      Font : Textrender.Fonts.Font;

      function Has_Drawable_Glyph
        (Codepoint : Textrender.Fonts.Codepoint)
         return Boolean
      is
         Glyph : Textrender.Fonts.Glyph_Info;
      begin
         return Textrender.Fonts.Lookup_Glyph (Font, Codepoint, Glyph) = Textrender.Fonts.Glyph_Found
           and then not Glyph.Is_Empty;
      end Has_Drawable_Glyph;

      function Has_Drawable_ASCII_Sample return Boolean is
         Sample : constant String := "files/tmp-09.txt";
      begin
         for Char of Sample loop
            if not Has_Drawable_Glyph (Textrender.Fonts.Codepoint (Character'Pos (Char))) then
               return False;
            end if;
         end loop;

         return True;
      end Has_Drawable_ASCII_Sample;
   begin
      if not Is_Ordinary_File (Path) then
         return False;
      elsif Is_Known_Unsupported_Renderer_Font (Path) then
         return False;
      end if;

      if Textrender.Fonts.Load (Font, Path) /= Textrender.Fonts.Loaded then
         Textrender.Fonts.Reset (Font);
         return False;
      end if;

      --  A colour font is judged on different evidence. The ASCII sample below
      --  asks whether outlines can be drawn for ordinary text, and a colour
      --  emoji font cannot: a bitmap font has no outlines at all, and a layered
      --  one has plenty but none for 'f' or '0'. Either way every lookup in that
      --  sample fails however sound the font is, so what counts instead is
      --  whether it has the colour glyphs it exists for.
      if Textrender.Fonts.Is_Bitmap_Only (Font)
        or else Textrender.Fonts.Has_Colour_Layers (Font)
      then
         declare
            Usable : constant Boolean :=
              Textrender.Fonts.Has_Colour_Bitmaps (Font)
              or else Textrender.Fonts.Has_Colour_Layers (Font);
         begin
            Textrender.Fonts.Reset (Font);
            return Usable;
         end;
      end if;

      if not Has_Drawable_ASCII_Sample
        or else not Has_Drawable_Glyph (Textrender.Fonts.Codepoint (Character'Pos ('?')))
      then
         Textrender.Fonts.Reset (Font);
         return False;
      end if;
      Textrender.Fonts.Reset (Font);
      return True;
   exception
      when Swallowed : others =>
         Guikit.Errors.Note (Swallowed, Unit_Name);
         Textrender.Fonts.Reset (Font);
         return False;
   end Is_Loadable_Font;

   --  How many of a sample of scripts' letters (Latin accents, Cyrillic,
   --  Greek, Hebrew, Arabic, Devanagari, kana, Hangul, Han) the font draws;
   --  -1 when it cannot be used at all.
   function Glyph_Coverage_Score (Path : String) return Integer is
      type Codepoint_Array is array (Positive range <>) of Textrender.Fonts.Codepoint;

      Probe_Codepoints : constant Codepoint_Array :=
        [16#00E5#,
         16#00E6#,
         16#00E9#,
         16#00F8#,
         16#00FC#,
         16#0142#,
         16#00F1#,
         16#0416#,
         16#0439#,
         16#03A9#,
         16#05D0#,
         16#0627#,
         16#0905#,
         16#3042#,
         16#AC00#,
         16#6587#,
         16#4EF6#];
      Score : Integer := 0;
      Font  : Textrender.Fonts.Font;
      Glyph : Textrender.Fonts.Glyph_Info;
   begin
      if not Is_Loadable_Font (Path) then
         return -1;
      end if;

      if Textrender.Fonts.Load (Font, Path) /= Textrender.Fonts.Loaded then
         Textrender.Fonts.Reset (Font);
         return -1;
      end if;

      for Codepoint of Probe_Codepoints loop
         if Textrender.Fonts.Lookup_Glyph (Font, Codepoint, Glyph) = Textrender.Fonts.Glyph_Found
           and then not Glyph.Is_Empty
         then
            Score := Score + 1;
         end if;
      end loop;
      Textrender.Fonts.Reset (Font);
      return Score;
   exception
      when Swallowed : others =>
         Guikit.Errors.Note (Swallowed, Unit_Name);
         Textrender.Fonts.Reset (Font);
         return -1;
   end Glyph_Coverage_Score;

   function Default_Font_Path
     (Font_Directories : Path_List := Default_Font_Directories;
      Override         : String := "")
      return String
   is
      --  What the answer depends on: the override and the folders.
      Key        : Unbounded_String := To_Unbounded_String (Override);
      Best_Path  : Unbounded_String;
      Best_Score : Integer := -1;

      procedure Remember (Path : String) is
      begin
         Cached_Default_Key := Key;
         Cached_Default_Path := To_Unbounded_String (Path);
         Cached_Default_Ready := True;
      end Remember;
   begin
      for Folder of Font_Directories loop
         Append (Key, ASCII.NUL & Folder);
      end loop;
      if Cached_Default_Ready and then Cached_Default_Key = Key then
         return To_String (Cached_Default_Path);
      end if;

      if Is_Loadable_Font (Override) then
         Remember (Override);
         return Override;
      end if;

      for Font of Known_Fonts loop
         if Font.Primary then
            for Path of Locations (Font, Font_Directories) loop
               if Is_Font_File (Path)
                 and then not Is_Known_Unsupported_Renderer_Font (Path)
                 and then Is_Loadable_Font (Path)
               then
                  Remember (Path);
                  return Path;
               end if;
            end loop;
         end if;
      end loop;

      for Path of Candidate_Fonts (Font_Directories) loop
         declare
            Score : constant Integer := Glyph_Coverage_Score (Path);
         begin
            if Score > Best_Score then
               Best_Path := To_Unbounded_String (Path);
               Best_Score := Score;
            end if;
         end;
      end loop;

      if Best_Score >= 0 then
         Remember (To_String (Best_Path));
         return To_String (Best_Path);
      end if;

      Remember ("");
      return "";
   exception
      when Swallowed : others =>
         Guikit.Errors.Note (Swallowed, Unit_Name);
         return "";
   end Default_Font_Path;

   function Fallback_Font_Paths
     (Primary          : String;
      Font_Directories : Path_List := Default_Font_Directories;
      Colour_Bitmaps   : Boolean := False)
      return Path_List
   is
      Result : Path_List;

      procedure Consider (Path : String) is
      begin
         if Path = "" or else Path = Primary then
            return;
         end if;
         for Existing of Result loop
            if Existing = Path then
               return;
            end if;
         end loop;
         if Is_Loadable_Font (Path) then
            Result.Append (Path);
         end if;
      end Consider;

      --  Name in every one of the host's font folders: the system's, then the
      --  one a font installed without administrator rights lands in.
      procedure Consider_In_Font_Directories (Name : String) is
      begin
         for Folder of Font_Directories loop
            Consider (Join (Folder, Name));
         end loop;
      end Consider_In_Font_Directories;
   begin
      for Rank in 1 .. Last_Text_Fallback loop
         for Font of Known_Fonts loop
            if Font.Text_Fallback = Rank then
               for Path of Locations (Font, Font_Directories) loop
                  Consider (Path);
               end loop;
            end if;
         end loop;
      end loop;

      --  Colour emoji, and last on purpose. The chain is resolved by asking
      --  each font whether it maps a codepoint and taking the first that says
      --  yes, and these fonts map far more than emoji -- arrows, stars, the
      --  check mark. Ahead of the text fonts it would capture characters they
      --  draw perfectly well. Noto Color Emoji is also looked for by name in
      --  the host's font folders: Windows and macOS ship none, so it is
      --  wherever its user installed it. These hold PNGs, so they are only
      --  worth listing to an application that decodes them.
      if Colour_Bitmaps then
         Consider ("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf");
         Consider_In_Font_Directories ("NotoColorEmoji.ttf");
         Consider ("/System/Library/Fonts/Apple Color Emoji.ttc");
      end if;

      --  The layered kind, which costs a reader nothing: a COLR/CPAL emoji is
      --  outlines and a palette, both of which Textrender reads on its own.
      --  For an application without an image decoder these are the only
      --  emoji fonts it can draw.
      Consider_In_Font_Directories ("seguiemj.ttf");
      Consider ("/usr/share/fonts/truetype/twemoji/TwemojiMozilla.ttf");
      Consider ("/usr/share/fonts/TTF/TwemojiMozilla.ttf");
      Consider_In_Font_Directories ("TwemojiMozilla.ttf");

      return Result;
   exception
      when Swallowed : others =>
         Guikit.Errors.Note (Swallowed, Unit_Name);
         return Guikit.Text.Font_Path_Vectors.Empty_Vector;
   end Fallback_Font_Paths;

end Guikit.Fonts;
