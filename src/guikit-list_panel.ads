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
   --
   --  @param Rectangles Rectangle draw commands to append to.
   --  @param Text Text draw commands to append to.
   --  @param Accessibility Accessibility nodes to append to.
   --  @param Clip_Width Width of the clip area in pixels.
   --  @param Clip_Height Height of the clip area in pixels.
   --  @param Region_X Left edge of the panel region.
   --  @param Region_Y Top edge of the panel region.
   --  @param Region_Width Width of the panel region.
   --  @param Region_Height Height of the panel region.
   --  @param Config Title, empty state, line height and row options.
   --  @param Rows Rows to draw, in order.
   --  @param Draw_Chrome Whether to draw the panel chrome.
   --  @param Row_Height Height of each row. 0 (or less than Config.Line_Height) keeps one
   --    Line_Height per row; a larger value gives taller rows with the label vertically
   --    centred (the padded root/drive selector). A defaulted parameter rather than a
   --    Config field, so callers' full List_Panel_Configuration aggregates still compile.
   --  @param Leading_Icon_Width Width of a reserved column left of the label for a
   --    caller-drawn icon; 0 for none. The widget draws nothing there and only shifts
   --    the label right by it.
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
      Draw_Chrome   : Boolean := True;
      Row_Height         : Natural := 0;
      Leading_Icon_Width : Natural := 0);

end Guikit.List_Panel;
