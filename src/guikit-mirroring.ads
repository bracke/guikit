with Guikit.Draw;

--  Mirroring a frame for a right-to-left layout: every command's box is
--  reflected across the vertical centre line of a frame Width pixels wide,
--  so what stood on the left stands on the right. Text keeps its reading
--  order inside its box and is aligned to the box's other edge (Align_End
--  toggled), so it still begins at the side its box begins; text fitted to
--  its box (Scale_To_Box) stays centred. Icons move but keep their
--  pictures; shapes drawn from rectangles and triangles are reflected with
--  them, so a vector arrow points the other way.
--
--  An application draws its frame left to right and mirrors it once before
--  presenting, then reflects the pointer's X the same way (Mirror_X) before
--  hit testing, so layouts, drawing and hit tests never meet a mirrored
--  coordinate. A caret drawn over text is the one thing whose place depends
--  on the text inside a box: Reflect_Column places it, and
--  Guikit.Text_Fields applies that for every field.
--
--  A box that sticks out past the frame is reflected by its visible part:
--  the part past the frame's edge, which nothing shows, is dropped.
package Guikit.Mirroring is

   use Guikit.Draw;

   --  Record whether the application mirrors its frames for a right-to-left
   --  layout. An application-wide registration, like
   --  Guikit.Draw.Set_Icon_Asset_Source: False until set. It is atomic, so
   --  any task may read it while another sets it; an application sets it
   --  before its first frame and again only when its layout direction
   --  changes, and each frame drawn after a change follows the new one.
   --
   --  @param On Whether frames are mirrored.
   procedure Set_Mirrored_Layout (On : Boolean);

   --  @return Whether frames are mirrored (Set_Mirrored_Layout).
   function Mirrored_Layout return Boolean;

   --  The column, counted from a mirrored box's unmirrored start, at which
   --  text Column cells into the drawn text stands. Text in a mirrored box
   --  keeps its reading order and stands against the box's other edge, so
   --  its cells are counted back from the end of the Shown cells drawn.
   --
   --  @param Column Display column into the drawn text.
   --  @param Shown How many display cells the text is drawn in.
   --  @return The column as the unmirrored frame counts it.
   function Reflect_Column (Column, Shown : Natural) return Natural is
     (Shown - Natural'Min (Column, Shown));

   --  The inverse of Reflect_Column for a click: the half cell into the
   --  drawn text of a click Half_Column half cells from a mirrored box's
   --  unmirrored start. A click past the drawn text is before its first
   --  half cell.
   --
   --  @param Half_Column Click position in half cells, as the unmirrored
   --  frame counts it.
   --  @param Shown How many display cells the text is drawn in.
   --  @return The click position in half cells into the drawn text.
   function Reflect_Half_Column (Half_Column, Shown : Natural) return Natural is
     (if Half_Column >= 2 * Shown then 0 else 2 * Shown - Half_Column - 1)
     with Pre => Shown <= Natural'Last / 2;

   --  @param Items Rectangles to reflect.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Rectangle_Command_Vectors.Vector; Width : Natural);

   --  @param Items Triangles to reflect.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Triangle_Command_Vectors.Vector; Width : Natural);

   --  @param Items Text boxes to reflect; Align_End is toggled, and a box
   --  marked as a symbol (Mirror_Glyph) holding one mirrorable character
   --  ('>') takes its mirror image ('<'). Other text, one character or more,
   --  keeps its characters.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Text_Command_Vectors.Vector; Width : Natural);

   --  @param Items Tooltips to reflect.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Tooltip_Command_Vectors.Vector; Width : Natural);

   --  @param Items Icons to move; their pictures are not flipped, nor cut:
   --  an icon sticking out past the frame's right edge starts at its left.
   --  An icon wholly past the right edge, which the unmirrored frame does
   --  not show, is not shown mirrored either: it is left at X 0 with no size
   --  (Size, Draw_Width and Draw_Height 0), which the backend draws as
   --  nothing.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Icon_Command_Vectors.Vector; Width : Natural);

   --  @param Items Accessibility nodes to reflect, so a screen reader is
   --  told where each one is shown.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Accessibility_Node_Vectors.Vector; Width : Natural);

   --  @param Layout Metrics whose pane origins are reflected.
   procedure Mirror (Layout : in out Layout_Metrics);

   --  The X a pointer at X stands on in the unmirrored frame: the pixel
   --  column reflected across a frame Width pixels wide.
   --
   --  @param X Pointer column in the mirrored (shown) frame.
   --  @param Width Frame width in pixels.
   --  @return The column in the frame as drawn before mirroring.
   function Mirror_X (X : Natural; Width : Natural) return Natural is
     (if X >= Width then 0 else Width - 1 - X);

end Guikit.Mirroring;
