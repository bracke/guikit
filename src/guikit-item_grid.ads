with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

--  A reusable item grid: the file-listing surface shared by a file manager and
--  similar list/grid views. This is the geometry and hit-testing foundation;
--  rendering and rename-field editing are layered on in later revisions.
--
--  The grid owns no selection or rename state -- the consumer passes the current
--  state in and the grid reports which item a pointer lands on. Layout is a plain
--  table of per-item rectangles (Item_Layout) that both the renderer and the
--  hit-tests read, so a click always resolves to the item that was drawn.
package Guikit.Item_Grid is

   --  How the grid arranges items: a compact single-line icon+label row
   --  (Icons_Small), a large centred icon over a wrapped label (Icons_Large),
   --  or a multi-column table (Details).
   type View_Kind is (Icons_Small, Icons_Large, Details);

   --  The size of one item cell in a given view: the cell box, the icon box
   --  inside it, and whether this is a "large" (icon-above-label) cell.
   type Cell_Metrics is record
      Width     : Natural := 0;
      Height    : Natural := 0;
      Icon_Size : Natural := 0;
      Large     : Boolean := False;
   end record;

   --  The cell metrics for one view. In Details the cell spans the full main
   --  width; the icon views use fixed multiples of the line height.
   --
   --  @param View The grid view.
   --  @param Main_Width Available content width in pixels (used by Details).
   --  @param Line_Height Text line height in pixels.
   --  @return The cell metrics.
   function Cell_Metrics_For
     (View        : View_Kind;
      Main_Width  : Natural;
      Line_Height : Positive)
      return Cell_Metrics;

   --  Per-item geometry for one visible row/cell: the cell rectangle, the icon
   --  box, the primary text box, and -- in a details view -- each column's x and
   --  width. Visible_Index is the one-based index into the consumer's visible
   --  item list, or 0 for a non-selectable row such as a group header.
   type Item_Layout is record
      Visible_Index     : Natural := 0;
      X                 : Natural := 0;
      Y                 : Natural := 0;
      Width             : Natural := 0;
      Height            : Natural := 0;
      Icon_X            : Natural := 0;
      Icon_Y            : Natural := 0;
      Icon_Size         : Natural := 0;
      Text_X            : Natural := 0;
      Text_Y            : Natural := 0;
      Text_Width        : Natural := 0;
      Name_X            : Natural := 0;
      Name_Width        : Natural := 0;
      Modified_X        : Natural := 0;
      Modified_Width    : Natural := 0;
      Size_X            : Natural := 0;
      Size_Width        : Natural := 0;
      Filetype_X        : Natural := 0;
      Filetype_Width    : Natural := 0;
      Created_X         : Natural := 0;
      Created_Width     : Natural := 0;
      Permissions_X     : Natural := 0;
      Permissions_Width : Natural := 0;
   end record;

   package Item_Layout_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Item_Layout);

   --  A neutral per-item input to layout: its one-based visible index (0 for a
   --  non-selectable group-header row), whether it is a group header, and its
   --  label (measured for large-icon text centring).
   type Layout_Item is record
      Visible_Index : Natural := 0;
      Group_Header  : Boolean := False;
      Label         : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Layout_Item_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Layout_Item);

   --  The details-view columns in their fixed logical order.
   type Detail_Column is
     (Name_Column, Modified_Column, Size_Column, Filetype_Column, Created_Column, Permissions_Column);

   type Column_Bounds is record
      X     : Natural := 0;
      Width : Natural := 0;
   end record;

   type Detail_Column_Bounds is array (Detail_Column) of Column_Bounds;

   --  Lay every item into its cell (icon views) or row (Details) rectangle,
   --  offset by the scroll. The caller supplies the content rectangle, the
   --  scroll offset in pixels, and -- for Details -- the precomputed column
   --  bounds; the grid does the pure per-item geometry. Off-screen items get a
   --  zero-height rectangle so callers skip them.
   --
   --  @param Items The visible items in order (including group-header rows).
   --  @param View The grid view.
   --  @param Content_X Content area left edge in pixels.
   --  @param Content_Y Content area top edge in pixels.
   --  @param Content_W Content area width in pixels.
   --  @param Content_H Content area height in pixels.
   --  @param Columns Details column bounds (ignored for the icon views).
   --  @param Scroll_Pixels Vertical scroll offset in pixels.
   --  @param Line_Height Text line height in pixels.
   --  @return The per-item layout table.
   function Calculate_Layout
     (Items         : Layout_Item_Vectors.Vector;
      View          : View_Kind;
      Content_X     : Natural;
      Content_Y     : Natural;
      Content_W     : Natural;
      Content_H     : Natural;
      Columns       : Detail_Column_Bounds;
      Scroll_Pixels : Natural;
      Line_Height   : Positive := 20)
      return Item_Layout_Vectors.Vector;

   --  One-based visible indices, used to carry hit-test results (e.g. the items
   --  a marquee rectangle covers) back to the consumer's selection logic.
   package Visible_Index_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Positive);

   --  The visible index of the item whose cell rectangle contains (X, Y), or 0
   --  when the point is over no item (empty space or a group header).
   --
   --  @param Items Per-item layout table.
   --  @param X Pointer x coordinate in pixels.
   --  @param Y Pointer y coordinate in pixels.
   --  @return The one-based visible index, or 0.
   function Item_At
     (Items : Item_Layout_Vectors.Vector;
      X     : Natural;
      Y     : Natural)
      return Natural;

   --  Normalise a marquee drag from its press point (Start) and current pointer
   --  into a canonical rectangle, so drags in any direction give the same rect.
   --
   --  @param Start_X Press-point x in pixels.
   --  @param Start_Y Press-point y in pixels.
   --  @param Current_X Current pointer x in pixels.
   --  @param Current_Y Current pointer y in pixels.
   --  @param X Out: rectangle left edge.
   --  @param Y Out: rectangle top edge.
   --  @param Width Out: rectangle width.
   --  @param Height Out: rectangle height.
   procedure Marquee_Rect
     (Start_X   : Natural;
      Start_Y   : Natural;
      Current_X : Natural;
      Current_Y : Natural;
      X         : out Natural;
      Y         : out Natural;
      Width     : out Natural;
      Height    : out Natural);

   --  The visible indices of every item whose cell overlaps the rectangle. A
   --  zero-area rectangle (a plain click, no drag) overlaps nothing, so it never
   --  selects via this path.
   --
   --  @param Items Per-item layout table.
   --  @param X Rectangle left edge in pixels.
   --  @param Y Rectangle top edge in pixels.
   --  @param Width Rectangle width in pixels.
   --  @param Height Rectangle height in pixels.
   --  @return The covered visible indices, in layout order.
   function Items_In_Rect
     (Items  : Item_Layout_Vectors.Vector;
      X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural)
      return Visible_Index_Vectors.Vector;

end Guikit.Item_Grid;
