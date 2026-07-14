with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Draw;
with Guikit.List_Panel;

--  Reusable tree-aware list panel: shared list geometry plus optional
--  indentation-guide rendering for hierarchical rows.
package Guikit.Tree_Panel is

   type Tree_Panel_Row is record
      Row   : Guikit.List_Panel.List_Panel_Row;
      Depth : Natural := 0;
   end record;

   package Tree_Panel_Row_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Tree_Panel_Row);

   type Tree_Panel_Configuration is record
      Title               : Guikit.Draw.UString;
      Empty_State         : Guikit.Draw.UString;
      Line_Height         : Positive := 20;
      Text_Padding        : Natural := 12;
      Show_Alternate_Rows : Boolean := True;
      Indent_In_Columns   : Natural := 2;
      Show_Indent_Guides  : Boolean := False;
      Guide_Color         : Guikit.Draw.Render_Color := Guikit.Draw.Border_Color;
   end record;

   --  Draw a reusable tree panel into the supplied draw vectors.
   --
   --  The caller supplies the rows and controls whether the shared list chrome
   --  is drawn. This package paints the shared list geometry via
   --  Guikit.List_Panel and, when enabled, overlays indentation guides for the
   --  visible tree depth.
   procedure Draw_Frame
     (Rectangles   : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text         : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : in out Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      Region_X     : Natural;
      Region_Y     : Natural;
      Region_Width : Natural;
      Region_Height : Natural;
      Config       : Tree_Panel_Configuration;
      Rows         : Tree_Panel_Row_Vectors.Vector;
      Draw_Chrome  : Boolean := True);

end Guikit.Tree_Panel;
