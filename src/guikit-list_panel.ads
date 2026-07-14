with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Draw;

--  A reusable floating list panel: chrome, title, empty state, and simple
--  label/detail rows. The caller supplies the row data and owns the behavior;
--  this package only paints the common panel/list geometry and accessibility
--  structure.
package Guikit.List_Panel is

   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   type List_Panel_Row is record
      Label            : Guikit.Draw.UString;
      Detail           : Guikit.Draw.UString;
      Shortcut         : Guikit.Draw.UString := Ada.Strings.Unbounded.Null_Unbounded_String;
      Selected         : Boolean := False;
      Enabled          : Boolean := True;
      Label_Color      : Guikit.Draw.Render_Color := Guikit.Draw.Text_Color;
      Has_Background   : Boolean := False;
      Background_Color : Guikit.Draw.Render_Color := Guikit.Draw.Pane_Color;
      Accent_Color     : Guikit.Draw.Render_Color := Guikit.Draw.Border_Color;
      Shortcut_Color   : Guikit.Draw.Render_Color := Guikit.Draw.Muted_Text_Color;
   end record;

   package List_Panel_Row_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => List_Panel_Row);

   type List_Panel_Configuration is record
      Title               : Guikit.Draw.UString;
      Empty_State         : Guikit.Draw.UString;
      Line_Height         : Positive := 20;
      Text_Padding        : Natural := 12;
      Show_Alternate_Rows : Boolean := True;
   end record;

   --  Draw a reusable list panel into the supplied draw vectors.
   --
   --  The caller supplies the rows and decides whether the panel chrome
   --  should be drawn. The widget handles the shared list geometry, optional
   --  title row, optional empty-state row, and accessibility nodes for the
   --  container, title, empty state, and each row.
   procedure Draw_Frame
     (Rectangles    : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : in out Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Config        : List_Panel_Configuration;
      Rows          : List_Panel_Row_Vectors.Vector;
      Draw_Chrome   : Boolean := True);

end Guikit.List_Panel;
