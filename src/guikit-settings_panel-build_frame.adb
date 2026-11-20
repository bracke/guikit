separate (Guikit.Settings_Panel)
procedure Build_Frame
  (P             : in out Panel;
   Region_X      : Natural;
   Region_Y      : Natural;
   Region_Width  : Natural;
   Region_Height : Natural;
   Clip_Width    : Natural;
   Clip_Height   : Natural;
   Focused       : Boolean;
   Hover_X       : Integer;
   Hover_Y       : Integer;
   Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
   Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
   Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector;
   Has_Glyph     : access function (Codepoint : Natural) return Boolean := null)
is
   LH        : constant Positive := P.Config.Line_Height;
   --  The panel's spacing grows with its text (a 2x display, a larger font).
   Pad       : constant Natural  := Guikit.Layout.Scaled (Guikit.Layout.Settings_Pane_Padding, LH);
   Row_Gap   : constant Natural  := Guikit.Layout.Scaled (Guikit.Layout.Settings_Row_Gap, LH);
   Row_H     : constant Natural  := LH + Row_Gap;
   --  The rest of the chrome, at the reference line height, scaled alike:
   --  the scrollbar, a text field's (and a stepper value's) inset, a
   --  button's label padding on each side and the gap between buttons, and
   --  the title and close button's inset from the panel's top edge.
   Bar_W     : constant Natural  := Guikit.Layout.Scaled (Bar_W_Base, LH);
   Field_Inset : constant Natural := Guikit.Layout.Scaled (4, LH);
   Button_Pad  : constant Natural := Guikit.Layout.Scaled (6, LH);
   Button_Gap  : constant Natural := Guikit.Layout.Scaled (4, LH);
   Edge_Inset  : constant Natural := Guikit.Layout.Panel_Edge_Inset (LH);
   --  Shared height for interactive controls: fill the row band (leaving a
   --  small margin) so fields and buttons are comfortably tall, not a short
   --  fraction of the line height.
   Ctrl_H    : constant Natural  := Row_H - Guikit.Layout.Scaled (4, LH);
   Cell_W    : constant Natural  := Guikit.Layout.Caret_Advance_Width (LH);
   N         : constant Natural  := Natural (P.Fields.Length);
   Tab_Count : constant Natural  := Section_Count (P);
   Content_X : constant Natural  := Region_X + Pad;
   --  Equal padding on both sides. The scrollbar (Bar_W, narrower than Pad) sits
   --  within the right padding at the panel edge, so the content still clears it
   --  without reserving extra width on the right.
   Content_W : constant Natural  :=
     (if Region_Width > 2 * Pad then Region_Width - 2 * Pad else 0);

   --  How many sections row Row (0-based) of Rows holds: the sections split
   --  as evenly as they go, any extra one going to the earlier rows.
   function Row_Size (Row, Rows : Natural) return Natural is
     (Tab_Count / Rows + (if Row < Tab_Count mod Rows then 1 else 0));

   --  The unstretched width a field's control needs. The value column is
   --  sized to the widest control across every section, so it stays put when
   --  switching sections.
   function Control_Width (F : Field) return Natural is separate;

   --  Where this frame places its parts, worked out once before any is drawn.
   type Frame_Geometry is record
      --  The section tabs: how many rows they take, their height and top.
      Tab_Rows   : Natural := 0;
      Switch_H   : Natural := 0;
      Switch_Y   : Natural := 0;
      --  The title's top and width, clear of the close button.
      Title_Y    : Natural := 0;
      Title_W    : Natural := 0;
      --  The field rows' top and bottom, and the height between them.
      Rows_Top   : Natural := 0;
      Rows_Bot   : Natural := 0;
      Avail_H    : Natural := 0;
      --  The footer: whether it shows the status line (else the focused
      --  field's help), its lines wrapped to the content width, its height.
      Has_Status : Boolean := False;
      Foot_Lines : UString_Vectors.Vector;
      Foot_H     : Natural := 0;
      --  The label column's width and the value column's left edge and width.
      Label_W    : Natural := 0;
      Ctrl_X     : Natural := 0;
      Ctrl_W     : Natural := 0;
      --  The focused row's highlight and its accent bar.
      Hl_X       : Natural := 0;
      Hl_W       : Natural := 0;
      Accent_X   : Natural := 0;
      Accent_W   : Natural := 0;
      --  The gap between the preamble (the action buttons) and the section.
      Group_Gap  : Natural := 0;
   end record;

   function Compute_Geometry return Frame_Geometry is separate;

   G : constant Frame_Geometry := Compute_Geometry;
   --  Field indices rendered as rows now (preamble + active section), compact.
   Visible   : Index_Array (1 .. Natural'Max (1, N)) := (others => 0);
   Vis_N     : Natural := 0;
   --  Number of leading visible rows belonging to the preamble (Section 0),
   --  which precede all of the active section's rows.
   Preamble_Rows : Natural := 0;

   procedure Add_Rect (X, Y, W, H : Natural; Color : Guikit.Draw.Render_Color) is
   begin
      if W > 0 and then H > 0 then
         Rectangles.Append
           (Guikit.Draw.Rectangle_Command'(X => X, Y => Y, Width => W, Height => H, Color => Color));
      end if;
   end Add_Rect;

   procedure Add_Text
     (X, Y, W     : Natural;
      S           : UString;
      Color       : Guikit.Draw.Render_Color;
      Cut_Columns : Natural := Guikit.Draw.Auto_Cut) is
   begin
      if W > 0 and then Length (S) > 0 then
         Text.Append
           (Guikit.Draw.Text_Command'
              (X => X, Y => Y, Width => W, Height => LH, Text => S, Color => Color, Cut_Columns => Cut_Columns,
               others => <>));
      end if;
   end Add_Text;

   procedure Add_Hit (Kind : Hit_Kind; Field_Index, Option, X, Y, W, H : Natural) is
   begin
      P.Hits.Append
        (Hit_Rect'(Kind => Kind, Field_Index => Field_Index, Option => Option,
                   X => X, Y => Y, W => W, H => H));
   end Add_Hit;

   --  The frame's parts, each its own subunit, drawn in this order (later parts
   --  sit above earlier ones): the panel chrome, the section tabs, the field
   --  rows, the footer, the scrollbar, the close button and the tab tooltip.
   procedure Draw_Chrome is separate;
   procedure Draw_Tabs is separate;
   procedure Draw_Control (I : Positive; F : Field; Row_Y : Natural) is separate;
   procedure Draw_Rows is separate;
   procedure Draw_Footer is separate;
   procedure Draw_Scrollbar is separate;
   procedure Draw_Close_Button is separate;
   procedure Draw_Switch_Tooltip is separate;

   procedure Update_Rows is separate;
begin
   --  Out vectors are passed by reference: drop what the caller's held.
   Rectangles.Clear;
   Text.Clear;
   Accessibility.Clear;
   P.Hits.Clear;
   Update_Rows;

   Draw_Chrome;
   Draw_Tabs;
   Draw_Rows;
   Draw_Footer;
   Draw_Scrollbar;
   Draw_Close_Button;
   Draw_Switch_Tooltip;
end Build_Frame;
