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
--  on the text inside a box: see Guikit.Bidi.Set_Mirrored_Layout.
package Guikit.Mirroring is

   use Guikit.Draw;

   --  @param Items Rectangles to reflect.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Rectangle_Command_Vectors.Vector; Width : Natural);

   --  @param Items Triangles to reflect.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Triangle_Command_Vectors.Vector; Width : Natural);

   --  @param Items Text boxes to reflect; Align_End is toggled, and a box
   --  holding one mirrorable character ('>') takes its mirror image ('<').
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Text_Command_Vectors.Vector; Width : Natural);

   --  @param Items Tooltips to reflect.
   --  @param Width Frame width in pixels.
   procedure Mirror (Items : in out Tooltip_Command_Vectors.Vector; Width : Natural);

   --  @param Items Icons to move; their pictures are not flipped.
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
