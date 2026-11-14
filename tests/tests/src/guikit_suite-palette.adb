with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Ada.Strings.Unbounded;
with Interfaces;

with Guikit.Draw;
with Guikit.Palette;
with Guikit.Utf8;

--  Search/ranking tests for Guikit.Palette.Search: an empty query keeps every
--  item in order, a query drops non-matching items, matches are ranked
--  best-first (exact over prefix over substring, stronger field over weaker),
--  and equally scored items keep their input order.
package body Guikit_Suite.Palette is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use Guikit.Draw;
   use type Guikit.Draw.Palette_Color;
   use type Guikit.Palette.Item_Vectors.Vector;

   type Palette_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Palette_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Palette_Test_Case);

   procedure Test_Empty_Query_Keeps_All (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drops_Non_Matching (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ranks_By_Relevance (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stable_Tiebreaker (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Match_Outranks_Position (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Whitespace_Tokenizing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Continuation_Byte_Not_Separator (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_High_Contrast_Colors (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Modal_Backdrop_Colors (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Icon_Rgb_For (T : in out AUnit.Test_Cases.Test_Case'Class);

   function Item
     (Id          : Natural;
      Identifier  : String;
      Label       : String;
      Description : String := "";
      Shortcut    : String := "")
      return Guikit.Palette.Item is
     (Id          => Id,
      Identifier  => To_Unbounded_String (Identifier),
      Label       => To_Unbounded_String (Label),
      Description => To_Unbounded_String (Description),
      Shortcut    => To_Unbounded_String (Shortcut),
      Enabled     => True,
      Score       => 0);

   function Sample return Guikit.Palette.Item_Vectors.Vector is
      Items : Guikit.Palette.Item_Vectors.Vector;
   begin
      Items.Append (Item (10, "open", "Open", "Open a file"));
      Items.Append (Item (20, "close", "Close", "Close the window"));
      Items.Append (Item (30, "save", "Save", "Save changes"));
      return Items;
   end Sample;

   overriding function Name (T : Palette_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit palette search and ranking");
   end Name;

   overriding procedure Register_Tests (T : in out Palette_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Query_Keeps_All'Access, "an empty query keeps every item in its input order");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drops_Non_Matching'Access, "a query drops items no token matches");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ranks_By_Relevance'Access, "matches rank best-first (prefix over substring)");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Stable_Tiebreaker'Access, "equally scored items keep their input order");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Match_Outranks_Position'Access,
         "a better match far down a long list outranks a weaker one at its top");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Whitespace_Tokenizing'Access, "a query splits on ASCII and Unicode whitespace into tokens");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Continuation_Byte_Not_Separator'Access,
         "a letter whose UTF-8 tail is the next-line byte (A-ring, Cyrillic ha) is not split");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_High_Contrast_Colors'Access, "high contrast strengthens text and panel boundaries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Modal_Backdrop_Colors'Access, "modal backdrops dim without becoming opaque");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Icon_Rgb_For'Access, "an icon colour is its palette role's colour, each channel rounded to 8 bits");
   end Register_Tests;

   procedure Test_Empty_Query_Keeps_All (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Results : constant Guikit.Palette.Item_Vectors.Vector :=
        Guikit.Palette.Search ("", Sample);
   begin
      Assert (Natural (Results.Length) = 3, "an empty query returns every item");
      Assert (Results.Element (1).Id = 10, "the first item keeps its input position");
      Assert (Results.Element (2).Id = 20, "the second item keeps its input position");
      Assert (Results.Element (3).Id = 30, "the third item keeps its input position");
   end Test_Empty_Query_Keeps_All;

   procedure Test_Drops_Non_Matching (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Hit  : constant Guikit.Palette.Item_Vectors.Vector :=
        Guikit.Palette.Search ("OPEN", Sample);
      Miss : constant Guikit.Palette.Item_Vectors.Vector :=
        Guikit.Palette.Search ("zzz", Sample);
   begin
      Assert (Natural (Hit.Length) = 1, "only the matching item survives");
      Assert (Hit.Element (1).Id = 10, "case-insensitive query matches the Open command");
      Assert (Natural (Miss.Length) = 0, "a query that matches nothing returns no items");
   end Test_Drops_Non_Matching;

   procedure Test_Ranks_By_Relevance (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  "s": "save" is a prefix of the save item's identifier (strong), while
      --  the close item only contains "s" (weaker), so save ranks first.
      Results : constant Guikit.Palette.Item_Vectors.Vector :=
        Guikit.Palette.Search ("s", Sample);
   begin
      Assert (Natural (Results.Length) = 2, "both items containing 's' match");
      Assert (Results.Element (1).Id = 30, "the prefix match (save) ranks first");
      Assert (Results.Element (2).Id = 20, "the substring match (close) ranks second");
      Assert (Results.Element (1).Score < Results.Element (2).Score, "a better match scores lower");
   end Test_Ranks_By_Relevance;

   procedure Test_Stable_Tiebreaker (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Items : Guikit.Palette.Item_Vectors.Vector;
   begin
      --  Both labels match "test" as a prefix equally; the tiebreaker is input
      --  order, so the first-appended item ranks first.
      Items.Append (Item (1, "one", "Test One"));
      Items.Append (Item (2, "two", "Test Two"));
      declare
         Results : constant Guikit.Palette.Item_Vectors.Vector :=
           Guikit.Palette.Search ("test", Items);
      begin
         Assert (Natural (Results.Length) = 2, "both equal matches survive");
         Assert (Results.Element (1).Id = 1, "the earlier item wins the tie");
         Assert (Results.Element (2).Id = 2, "the later item follows");
      end;
   end Test_Stable_Tiebreaker;

   procedure Test_Match_Outranks_Position (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Count : constant := 2_500;
      Items : Guikit.Palette.Item_Vectors.Vector;
   begin
      --  The first item only contains "go"; the exact match is item 2_400.
      --  Ranked by match * 100 + position, as it once was, 2_400 positions
      --  outweighed the 20 between an exact and a substring match.
      Items.Append (Item (1, "cargo", "Cargo"));
      for Index in 2 .. Count loop
         Items.Append
           (Item (Index, (if Index = 2_400 then "go" else "filler"), "Filler" & Natural'Image (Index)));
      end loop;
      declare
         Results : constant Guikit.Palette.Item_Vectors.Vector := Guikit.Palette.Search ("go", Items);
      begin
         Assert (Natural (Results.Length) = 2, "only the two items with ""go"" match");
         Assert (Results.Element (1).Id = 2_400, "the exact match ranks first, however far down it was");
         Assert (Results.Element (2).Id = 1, "and the substring match second");
         Assert (Results.Element (1).Score < Results.Element (2).Score, "the better match scores lower");
      end;
   end Test_Match_Outranks_Position;

   procedure Test_Whitespace_Tokenizing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      NEL : constant Character := Character'Val (16#85#);  --  C1 next-line control byte
      --  "open" matches the Open command's identifier, "file" its description;
      --  a next-line byte between them must split the query so both tokens are
      --  required (and both match). The concatenation matches no field.
      Split  : constant Guikit.Palette.Item_Vectors.Vector :=
        Guikit.Palette.Search ("open" & NEL & "file", Sample);
      Joined : constant Guikit.Palette.Item_Vectors.Vector :=
        Guikit.Palette.Search ("openfile", Sample);
   begin
      Assert (Natural (Split.Length) = 1, "a C1 next-line byte separates the query into two tokens");
      Assert (Split.Element (1).Id = 10, "both tokens match the Open command's fields");
      Assert (Natural (Joined.Length) = 0, "the un-separated concatenation matches no field");
   end Test_Whitespace_Tokenizing;

   procedure Test_Continuation_Byte_Not_Separator (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function B (Code : Natural) return Character is (Character'Val (Code));
      --  "Åbn" and "åbn": Å is C3 85, whose second byte is the C1 next-line
      --  byte; å is C3 A5.
      Upper_Abn : constant String := B (16#C3#) & B (16#85#) & "bn";
      Lower_Abn : constant String := B (16#C3#) & B (16#A5#) & "bn";
      --  "Подход": its х is D1 85.
      Approach  : constant String :=
        B (16#D0#) & B (16#9F#) & B (16#D0#) & B (16#BE#) & B (16#D0#) & B (16#B4#)
        & B (16#D1#) & B (16#85#) & B (16#D0#) & B (16#BE#) & B (16#D0#) & B (16#B4#);
      Items     : Guikit.Palette.Item_Vectors.Vector;

      function Finds (Query : String; Id : Natural) return Boolean is
         Results : constant Guikit.Palette.Item_Vectors.Vector := Guikit.Palette.Search (Query, Items);
      begin
         return Natural (Results.Length) = 1 and then Results.Element (1).Id = Id;
      end Finds;
   begin
      Items.Append (Item (1, "open", Upper_Abn));
      Items.Append (Item (2, "approach", Approach));
      Assert (Finds (Upper_Abn, 1), "the query A-ring-bn finds the A-ring-bn command");
      Assert (Finds (Lower_Abn, 1), "the lower-case query a-ring-bn finds the A-ring-bn command");
      Assert (Finds (Approach, 2), "a Cyrillic query containing ha (D1 85) finds its command");
      Assert
        (Guikit.Utf8.Whitespace_Separator_Length (Upper_Abn, 1) = 0,
         "the tail byte of A-ring is not a separator on its own");
      Assert
        (Guikit.Utf8.Whitespace_Separator_Length ("a" & B (16#85#) & "b", 1) = 1,
         "a stray next-line byte after ASCII still separates");
   end Test_Continuation_Byte_Not_Separator;

   procedure Test_High_Contrast_Colors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dark_Text       : constant Palette_Color := Color_For (Text_Color, Theme_Dark);
      Contrast_Text   : constant Palette_Color := Color_For (Text_Color, Theme_High_Contrast);
      Dark_Muted      : constant Palette_Color := Color_For (Muted_Text_Color, Theme_Dark);
      Contrast_Muted  : constant Palette_Color := Color_For (Muted_Text_Color, Theme_High_Contrast);
      Dark_Border     : constant Palette_Color := Color_For (Border_Color, Theme_Dark);
      Contrast_Border : constant Palette_Color := Color_For (Border_Color, Theme_High_Contrast);
   begin
      Assert (Contrast_Text /= Dark_Text and then Contrast_Text.R > Dark_Text.R,
              "high-contrast primary text is brighter than dark text");
      Assert (Contrast_Muted.R > Dark_Muted.R,
              "high-contrast secondary text remains readily legible");
      Assert (Contrast_Border.R > Dark_Border.R,
              "high-contrast borders separate adjacent surfaces");
   end Test_High_Contrast_Colors;

   procedure Test_Modal_Backdrop_Colors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for Theme in Theme_Kind loop
         declare
            Backdrop : constant Palette_Color := Color_For (Modal_Backdrop_Color, Theme);
            Shadow   : constant Palette_Color := Color_For (Shadow_Color, Theme);
            Surface  : constant Palette_Color := Color_For (Overlay_Color, Theme);
         begin
            Assert
              (Backdrop.A > 0.0 and then Backdrop.A < 1.0,
               "a modal backdrop dims the underlying view without hiding it");
            Assert
              (Shadow.A > 0.0 and then Shadow.A < 1.0,
               "a drop shadow remains translucent");
            Assert
              (Surface.A = 1.0,
               "an interactive overlay surface is opaque over underlying text");
         end;
      end loop;
      Assert
        (Color_For (Modal_Backdrop_Color, Theme_High_Contrast).A
           > Color_For (Modal_Backdrop_Color, Theme_Light).A,
         "high contrast uses the strongest modal separation");
   end Test_Modal_Backdrop_Colors;

   procedure Test_Icon_Rgb_For (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Roles : constant array (Positive range <>) of Render_Color :=
        [Canvas_Color, Main_Color, Icon_Folder_Color, Accent_Gold_Color, Accent_Blue_Color];

      --  A channel the way the spec states it: the nearest of 0 .. 255.
      function Matches (Byte : Interfaces.Unsigned_8; Channel : Float) return Boolean is
        (abs (Float (Byte) - Channel * 255.0) <= 0.5);
   begin
      --  Worked by hand from the palette: dark folder blue (0.32, 0.50, 0.82)
      --  is 81.6, 127.5 and 209.1 of 255 -- a half rounds up -- and light
      --  folder blue (0.18, 0.40, 0.74) is 45.9, 102.0 and 188.7.
      Assert (Icon_Rgb_For (Icon_Folder_Color, Theme_Dark) = (R => 82, G => 128, B => 209),
              "the dark folder blue in 8 bits");
      Assert (Icon_Rgb_For (Icon_Folder_Color, Theme_Light) = (R => 46, G => 102, B => 189),
              "the light folder blue in 8 bits");
      Assert (Icon_Rgb_For (Canvas_Color, Theme_Light) = (R => 237, G => 240, B => 242),
              "the light canvas in 8 bits");
      Assert (Icon_Rgb_For (Icon_Folder_Color, Theme_Dark) /= Icon_Rgb_For (Icon_Folder_Color, Theme_Light),
              "a theme change gives a folder a different base colour");

      for Theme in Theme_Dark .. Theme_Light loop
         for Role of Roles loop
            declare
               Color : constant Palette_Color := Color_For (Role, Theme);
               Bytes : constant Icon_Rgb := Icon_Rgb_For (Role, Theme);
            begin
               Assert (Matches (Bytes.R, Color.R) and then Matches (Bytes.G, Color.G)
                         and then Matches (Bytes.B, Color.B),
                       Render_Color'Image (Role) & " under " & Theme_Kind'Image (Theme)
                       & " is Color_For's colour rounded to the nearest byte");
            end;
         end loop;
      end loop;
   end Test_Icon_Rgb_For;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Palette_Test_Case));
      return Result;
   end Suite;

end Guikit_Suite.Palette;
