with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Draw;

--  A stateless horizontal segmented control: a row of cells that pick one of a
--  small fixed set (e.g. a view-mode switcher). The caller supplies the cells
--  and which one is active; the component lays them out variable-width (each
--  cell proportional to its label's measured pixel width, together filling the
--  region), renders them as a button group (active cell highlighted, hover
--  feedback), emits per-cell hover tooltips and accessibility nodes, and
--  hit-tests a click back to a cell index. Labels are measured internally, so a
--  click always lands on the cell that was drawn. It owns no state -- the active
--  selection lives in the caller's model.
package Guikit.Segmented is

   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   type Segment is record
      Label   : UString;   --  shown in the cell (fitted)
      Tooltip : UString;   --  hover tooltip; none when empty
      Enabled : Boolean := True;
   end record;

   package Segment_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Segment);

   --  The left edge and width of one cell within the control's region, using the
   --  same variable-width layout Build_Frame draws. Cells outside 1 .. length
   --  return width 0.
   --
   --  @param Segments The cells, left to right.
   --  @param Region_X Left edge of the control in pixels.
   --  @param Region_Width Control width in pixels.
   --  @param Line_Height Row height in pixels (drives label measurement).
   --  @param Cell One-based cell index.
   --  @param X Out: the cell's left edge in pixels.
   --  @param Width Out: the cell's width in pixels.
   procedure Cell_Bounds
     (Segments     : Segment_Vectors.Vector;
      Region_X     : Natural;
      Region_Width : Natural;
      Line_Height  : Positive;
      Cell         : Positive;
      X            : out Natural;
      Width        : out Natural);

   --  The one-based cell index at horizontal coordinate X within the control's
   --  region, or 0 when X is outside the region.
   --
   --  @param Segments The cells, left to right.
   --  @param Region_X Left edge of the control in pixels.
   --  @param Region_Width Control width in pixels.
   --  @param Line_Height Row height in pixels (drives label measurement).
   --  @param X Pointer x coordinate in pixels.
   --  @return The one-based cell index, or 0.
   function Cell_At
     (Segments     : Segment_Vectors.Vector;
      Region_X     : Natural;
      Region_Width : Natural;
      Line_Height  : Positive;
      X            : Integer)
      return Natural;

   --  Render the segmented control within a region: Segments'Length equal cells,
   --  the Active cell highlighted, each labelled with a hover tooltip (when set)
   --  and an accessibility node. The caller maps the cell index to its meaning.
   --
   --  @param Segments The cells, left to right.
   --  @param Active One-based active cell, or 0 for none.
   --  @param Region_X Left edge in pixels.
   --  @param Region_Y Top edge in pixels.
   --  @param Region_Width Control width in pixels.
   --  @param Region_Height Control height in pixels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Line_Height Row height in pixels (for label vertical centring).
   --  @param Hover_X Cursor x in pixels (negative when off-window).
   --  @param Hover_Y Cursor y in pixels.
   --  @param Rectangles Out: rectangle commands.
   --  @param Text Out: text commands.
   --  @param Tooltips Out: hover tooltip commands.
   --  @param Accessibility Out: accessibility nodes.
   procedure Build_Frame
     (Segments      : Segment_Vectors.Vector;
      Active        : Natural;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Hover_X       : Integer;
      Hover_Y       : Integer;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Tooltips      : out Guikit.Draw.Tooltip_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

end Guikit.Segmented;
