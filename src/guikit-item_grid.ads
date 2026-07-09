with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Draw;

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

   --  Which background an item cell shows. In the caller's priority order a cell
   --  is at most one of these; No_Background leaves the cell bare.
   type Background_Kind is (No_Background, Alternate, Hovered, Selected, Drop_Target);

   --  Paint one item cell's background into Rectangles: the fill and border plus
   --  a left accent stripe for the selected and drop-target states, the plain
   --  fill+border for hover, or the striped alternate-row fill. Everything is
   --  clipped to the drawable rectangle.
   --
   --  @param Rectangles Rectangle command vector to append to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Cell The cell geometry (X/Y/Width/Height are used).
   --  @param Kind Which background to paint.
   --  @param Selection_Color Selected fill / drop-target accent colour.
   --  @param Hover_Color Hover and drop-target fill colour.
   --  @param Border_Color Selected left-stripe colour.
   --  @param Alternate_Color Striped alternate-row fill colour.
   procedure Draw_Item_Background
     (Rectangles      : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      Cell            : Item_Layout;
      Kind            : Background_Kind;
      Selection_Color : Guikit.Draw.Render_Color;
      Hover_Color     : Guikit.Draw.Render_Color;
      Border_Color    : Guikit.Draw.Render_Color;
      Alternate_Color : Guikit.Draw.Render_Color);

   --  Emit a text command fitted to a box: measured against the box width in
   --  display columns and, when Fit, truncated on a codepoint boundary with a
   --  trailing ellipsis. The box is clipped to the drawable rectangle; an empty
   --  result emits nothing.
   --
   --  @param Text_Commands Text command vector to append to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Text box left edge in pixels.
   --  @param Y Text box top edge in pixels.
   --  @param Width Text box width in pixels.
   --  @param Height Text box height in pixels.
   --  @param Text The text to draw.
   --  @param Color Text colour.
   --  @param Line_Height Text line height in pixels (drives column width).
   --  @param Fit Whether to truncate to the box width with an ellipsis.
   --  @param Italic Whether to render italic.
   procedure Draw_Fitted_Text
     (Text_Commands : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      X             : Natural;
      Y             : Natural;
      Width         : Natural;
      Height        : Natural;
      Text          : Ada.Strings.Unbounded.Unbounded_String;
      Color         : Guikit.Draw.Render_Color;
      Line_Height   : Positive;
      Fit           : Boolean := True;
      Italic        : Boolean := False);

   --  Draw a grouping band-header row: a subdued fill, a muted fitted caption at
   --  the cell's text box, a one-pixel bottom separator, and a non-selectable
   --  accessibility node.
   --
   --  @param Rectangles Rectangle command vector.
   --  @param Text_Commands Text command vector.
   --  @param Accessibility Accessibility node vector.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Cell The group-header row geometry.
   --  @param Label The band caption.
   --  @param Line_Height Text line height in pixels.
   --  @param Background_Color Subdued row fill colour.
   --  @param Label_Color Muted caption colour.
   --  @param Border_Color Bottom separator colour.
   procedure Draw_Group_Header
     (Rectangles       : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text_Commands    : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility    : in out Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Clip_Width       : Natural;
      Clip_Height      : Natural;
      Cell             : Item_Layout;
      Label            : Ada.Strings.Unbounded.Unbounded_String;
      Line_Height      : Positive;
      Background_Color : Guikit.Draw.Render_Color;
      Label_Color      : Guikit.Draw.Render_Color;
      Border_Color     : Guikit.Draw.Render_Color);

   --  Draw a details-view data row: a one-pixel bottom separator and the five
   --  optional columns, each fitted to its padded column box and dimmed+italic
   --  when Dim, with a hover tooltip on the time columns when their tooltip text
   --  is non-empty. A column of zero width is skipped. The caller supplies the
   --  already-formatted column strings.
   --
   --  @param Rectangles Rectangle command vector.
   --  @param Text_Commands Text command vector.
   --  @param Tooltips Tooltip command vector.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Cell The row geometry (column x/width fields are used).
   --  @param Line_Height Text line height in pixels.
   --  @param Modified Formatted modified-time column value.
   --  @param Size Formatted size column value.
   --  @param Filetype Formatted filetype column value.
   --  @param Created Formatted created-time column value.
   --  @param Permissions Formatted permissions column value.
   --  @param Modified_Tooltip Hover tooltip for the modified column, or empty.
   --  @param Created_Tooltip Hover tooltip for the created column, or empty.
   --  @param Dim Whether the row is dimmed (e.g. a cut item): italic + Dim_Color.
   --  @param Value_Color Normal column text colour.
   --  @param Dim_Color Dimmed column text colour.
   --  @param Border_Color Bottom separator colour.
   procedure Draw_Details_Row
     (Rectangles       : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text_Commands    : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Tooltips         : in out Guikit.Draw.Tooltip_Command_Vectors.Vector;
      Clip_Width       : Natural;
      Clip_Height      : Natural;
      Cell             : Item_Layout;
      Line_Height      : Positive;
      Modified         : Ada.Strings.Unbounded.Unbounded_String;
      Size             : Ada.Strings.Unbounded.Unbounded_String;
      Filetype         : Ada.Strings.Unbounded.Unbounded_String;
      Created          : Ada.Strings.Unbounded.Unbounded_String;
      Permissions      : Ada.Strings.Unbounded.Unbounded_String;
      Modified_Tooltip : Ada.Strings.Unbounded.Unbounded_String;
      Created_Tooltip  : Ada.Strings.Unbounded.Unbounded_String;
      Dim              : Boolean;
      Value_Color      : Guikit.Draw.Render_Color;
      Dim_Color        : Guikit.Draw.Render_Color;
      Border_Color     : Guikit.Draw.Render_Color);

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
