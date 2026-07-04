with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

--  Generic fuzzy search and ranking for a command-palette-style searchable list.
--
--  The caller builds a vector of Items -- each carrying an opaque Id plus the
--  searchable/displayable strings -- and calls Search with the query text.
--  Search returns the matching Items, scored and (for a non-empty query) ordered
--  by relevance; an empty query returns every Item in its original order. The
--  package is domain-free: it knows nothing about commands, localization, or any
--  application model. The caller maps Item.Id back to its own domain object.
package Guikit.Palette is
   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   --  One palette entry. Identifier, Label, Description and Shortcut are the
   --  searchable fields, matched with increasing base scores (an Identifier
   --  match ranks strongest, a Shortcut match weakest). Id is an opaque handle
   --  the caller uses to recover its own object; Enabled is carried through
   --  unchanged; Score is filled in by Search.
   type Item is record
      Id          : Natural := 0;
      Identifier  : UString;
      Label       : UString;
      Description : UString;
      Shortcut    : UString;
      Enabled     : Boolean := False;
      Score       : Natural := 0;
   end record;

   package Item_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Item);

   --  Filter and rank Items against a query.
   --
   --  Each returned Item's Score combines its best per-token field match with a
   --  stable tiebreaker on the Item's original position, so equally good matches
   --  keep their input order. A non-empty query drops Items that no token
   --  matches and orders the rest by ascending Score (best first); an empty or
   --  all-whitespace query keeps every Item in its original order.
   --
   --  @param Query Search text; split into whitespace-separated tokens.
   --  @param Items Candidate entries in their natural (e.g. registry) order.
   --  @return Matching Items, scored, best-first for a non-empty query.
   function Search
     (Query : String;
      Items : Item_Vectors.Vector)
      return Item_Vectors.Vector;

end Guikit.Palette;
