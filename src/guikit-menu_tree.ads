with Ada.Containers.Vectors;

with Guikit.Draw;

--  Reusable file-manager style tree/menu overlay: box chrome, a title band,
--  hierarchical rows (background, an optional expand affordance, and a
--  depth-indented label), and an optional footer button bar. Distinct from
--  Guikit.Tree_Panel, which models the editor's flat-label + guide-line style.
--
--  The caller owns behaviour: it supplies each row's rectangle (authoritative
--  for hit-testing), its depth-derived triangle position, and its per-frame
--  hover/pressed/selected state, plus the footer button geometry and labels.
--  This package only paints; it does not register accessibility nodes and does
--  not draw the panel close button (both stay caller-side).
package Guikit.Menu_Tree is

   --  One visible tree row. X/Y/Width/Height is the row rectangle the caller
   --  computed (and hit-tests against); Triangle_X/Triangle_Width locate the
   --  expand affordance; the label is drawn one Line_Height to the right of the
   --  triangle, vertically centred, and fitted to the remaining width.
   type Menu_Tree_Row is record
      Label          : Guikit.Draw.UString;
      X              : Natural := 0;
      Y              : Natural := 0;
      Width          : Natural := 0;
      Height         : Natural := 0;
      Triangle_X     : Natural := 0;
      Triangle_Width : Natural := 0;
      Has_Children   : Boolean := False;
      Expanded       : Boolean := False;
      Selected       : Boolean := False;
      Hovered        : Boolean := False;
      Pressed        : Boolean := False;
   end record;

   package Menu_Tree_Row_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Menu_Tree_Row);

   --  One footer button (e.g. Choose / Cancel). Geometry and hover/pressed are
   --  caller-computed; the widget draws the themed button and its label.
   type Menu_Tree_Button is record
      Label   : Guikit.Draw.UString;
      X       : Natural := 0;
      Y       : Natural := 0;
      Width   : Natural := 0;
      Height  : Natural := 0;
      Hovered : Boolean := False;
      Pressed : Boolean := False;
   end record;

   package Menu_Tree_Button_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Menu_Tree_Button);

   type Menu_Tree_Configuration is record
      Line_Height     : Positive := 20;
      --  Horizontal inset for the title text and the row label's right margin.
      Text_Padding    : Natural := 0;
      --  Height of the title band (0 draws no title band).
      Title_Height    : Natural := 0;
      --  Expand-affordance glyphs, caller-supplied so the domain owns the text.
      Expanded_Glyph  : Guikit.Draw.UString;
      Collapsed_Glyph : Guikit.Draw.UString;
   end record;

   --  Draw the tree panel into the supplied draw vectors.
   --
   --  When Draw_Chrome is True the box (right drop-shadow, fill, border) and the
   --  title band are drawn; pass False to reuse a cached body and only repaint
   --  the rows/buttons. Rows and buttons are always drawn.
   procedure Draw_Frame
     (Rectangles    : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Title         : Guikit.Draw.UString;
      Config        : Menu_Tree_Configuration;
      Rows          : Menu_Tree_Row_Vectors.Vector;
      Buttons       : Menu_Tree_Button_Vectors.Vector;
      Draw_Chrome   : Boolean := True);

end Guikit.Menu_Tree;
