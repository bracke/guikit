with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Guikit.Layout;
with Guikit.List_Panel;

package body Guikit.Tree_Panel is

   use Guikit.Draw;

   procedure Draw_Frame
     (Rectangles   : in out Rectangle_Command_Vectors.Vector;
      Text         : in out Text_Command_Vectors.Vector;
      Accessibility : in out Accessibility_Node_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      Region_X     : Natural;
      Region_Y     : Natural;
      Region_Width : Natural;
      Region_Height : Natural;
      Config       : Tree_Panel_Configuration;
      Rows         : Tree_Panel_Row_Vectors.Vector;
      Draw_Chrome  : Boolean := True)
   is
      Panel_Config : constant Guikit.List_Panel.List_Panel_Configuration :=
        (Title               => Config.Title,
         Empty_State         => Config.Empty_State,
         Line_Height         => Config.Line_Height,
         Text_Padding        => Config.Text_Padding,
         Show_Alternate_Rows => Config.Show_Alternate_Rows);
      List_Rows : Guikit.List_Panel.List_Panel_Row_Vectors.Vector;
      Line_Height : constant Positive := Config.Line_Height;
      Cell_W      : constant Positive :=
        Positive'Max (1, Guikit.Layout.Saturating_Multiply (Line_Height, 12) / 20);
      Has_Title : constant Boolean := Length (Config.Title) > 0;
      Title_Rows : constant Natural := (if Has_Title then 1 else 0);
      Max_Rows : constant Natural :=
        (if Region_Height / Line_Height > Title_Rows
         then Region_Height / Line_Height - Title_Rows
         else 0);
      Rows_To_Render : constant Natural := Natural'Min (Natural (Rows.Length), Max_Rows);
      Row_Base_Y : constant Natural := Region_Y + (Title_Rows * Line_Height);
   begin
      if Region_Width = 0 or else Region_Height = 0 then
         return;
      end if;

      for Row of Rows loop
         List_Rows.Append (Row.Row);
      end loop;

      Guikit.List_Panel.Draw_Frame
        (Rectangles    => Rectangles,
         Text          => Text,
         Accessibility => Accessibility,
         Clip_Width    => Clip_Width,
         Clip_Height   => Clip_Height,
         Region_X      => Region_X,
         Region_Y      => Region_Y,
         Region_Width  => Region_Width,
         Region_Height => Region_Height,
         Config        => Panel_Config,
         Rows          => List_Rows,
         Draw_Chrome   => Draw_Chrome);

      if not Config.Show_Indent_Guides or else Rows_To_Render = 0 then
         return;
      end if;

      for I in 1 .. Rows_To_Render loop
         declare
            Row : constant Tree_Panel_Row := Rows (I);
            Row_Y : constant Natural := Row_Base_Y + ((I - 1) * Line_Height);
         begin
            if Row.Depth > 0 then
               for D in 1 .. Row.Depth loop
                  declare
                     Guide_X : constant Natural :=
                       Region_X
                       + Natural ((D - 1) * Config.Indent_In_Columns * Cell_W)
                       + (Cell_W / 2);
                  begin
                     Rectangles.Append
                       (Rectangle_Command'
                          (X      => Guide_X,
                           Y      => Row_Y,
                           Width  => 1,
                           Height => Line_Height,
                           Color  => Config.Guide_Color));
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Draw_Frame;

end Guikit.Tree_Panel;
