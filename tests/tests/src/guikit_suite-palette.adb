with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Ada.Strings.Unbounded;

with Guikit.Palette;

--  Search/ranking tests for Guikit.Palette.Search: an empty query keeps every
--  item in order, a query drops non-matching items, matches are ranked
--  best-first (exact over prefix over substring, stronger field over weaker),
--  and equally scored items keep their input order.
package body Guikit_Suite.Palette is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use type Guikit.Palette.Item_Vectors.Vector;

   type Palette_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Palette_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Palette_Test_Case);

   procedure Test_Empty_Query_Keeps_All (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drops_Non_Matching (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Ranks_By_Relevance (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Stable_Tiebreaker (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Whitespace_Tokenizing (T : in out AUnit.Test_Cases.Test_Case'Class);

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
        (T, Test_Whitespace_Tokenizing'Access, "a query splits on ASCII and Unicode whitespace into tokens");
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

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (new Palette_Test_Case);
      return Result;
   end Suite;

end Guikit_Suite.Palette;
