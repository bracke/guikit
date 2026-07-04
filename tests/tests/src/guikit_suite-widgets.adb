with Ada.Containers;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Draw;
with Guikit.Widgets;

--  Unit tests for the domain-free widget draw procedures. Each test calls one
--  Draw_* procedure directly on fresh Guikit.Draw command vectors and asserts
--  the emitted rectangle and text commands: their count, coordinates, colors,
--  and order, plus the clipping rule that a zero clip or an off-screen
--  coordinate drops the command.
package body Guikit_Suite.Widgets is

   use AUnit.Assertions;
   use Guikit.Draw;
   use Guikit.Widgets;
   use type Ada.Containers.Count_Type;

   package U renames Ada.Strings.Unbounded;

   Big : constant Natural := 1000;
   --  A clip window large enough that nothing clips in most tests.

   type Widgets_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Widgets_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Widgets_Test_Case);

   procedure Test_Focus_Ring (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drop_Shadow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Segmented (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scrollbar (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Menu_Panel (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Menu_Row (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Input_Field (T : in out AUnit.Test_Cases.Test_Case'Class);

   --  Number of rectangle commands in a vector, as a plain Natural.
   function Count (V : Rectangle_Command_Vectors.Vector) return Natural is
     (Natural (V.Length));

   --  Number of text commands in a vector, as a plain Natural.
   function Count (V : Text_Command_Vectors.Vector) return Natural is
     (Natural (V.Length));

   overriding function Name (T : Widgets_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit widget draw commands");
   end Name;

   overriding procedure Register_Tests (T : in out Widgets_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Focus_Ring'Access, "Draw_Focus_Ring emits a double ring, one ring at a corner, none when empty");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drop_Shadow'Access, "Draw_Drop_Shadow emits two offset bands and drops off-screen ones");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Close_Button'Access, "Draw_Close_Button emits a fill, border and optional glyph");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Segmented'Access, "Draw_Segmented emits N cells with the last cell absorbing the remainder");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scrollbar'Access, "Draw_Scrollbar emits track, thumb and grip when tall enough");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Menu_Panel'Access, "Draw_Menu_Panel emits a fill and four border edges");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Menu_Row'Access, "Draw_Menu_Row emits a separator or a highlight-plus-label command row");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tooltip'Access, "Draw_Tooltip emits a box, border and label");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Caret'Access, "Draw_Caret emits one rectangle and drops on a zero or off-screen clip");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Marquee'Access, "Draw_Marquee emits a fill and a border");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Input_Field'Access, "Draw_Input_Field emits a fill and a border, nothing when empty");
   end Register_Tests;

   procedure Test_Focus_Ring (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
   begin
      --  A box clear of the top-left edge draws an inner and an outer border.
      Draw_Focus_Ring (Rects, Big, Big, 10, 10, 20, 15, Selection_Color);
      Assert (Count (Rects) = 8, "a focus ring away from the edge is a double border (8 rects)");
      Assert (Rects (1).X = 10 and then Rects (1).Y = 10, "the inner ring's top edge starts at the box origin");
      Assert (Rects (1).Width = 20 and then Rects (1).Height = 1, "the inner top edge is one pixel tall");
      Assert (Rects (1).Color = Selection_Color, "the ring uses the requested color");

      --  A zero-size ring draws nothing.
      Rects.Clear;
      Draw_Focus_Ring (Rects, Big, Big, 10, 10, 0, 15, Selection_Color);
      Assert (Count (Rects) = 0, "a zero-width ring draws nothing");

      --  A ring flush against the top-left edge draws only its inner border.
      Rects.Clear;
      Draw_Focus_Ring (Rects, Big, Big, 0, 0, 20, 15, Selection_Color);
      Assert (Count (Rects) = 4, "a ring at the top-left corner draws only the inner border");
   end Test_Focus_Ring;

   procedure Test_Drop_Shadow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
   begin
      Draw_Drop_Shadow (Rects, Big, Big, 10, 10, 20, 15, Overlay_Color);
      Assert (Count (Rects) = 2, "a drop shadow is a horizontal and a vertical band");
      Assert (Rects (1).X = 13 and then Rects (1).Y = 25, "the bottom band is offset below the box");
      Assert (Rects (1).Width = 20 and then Rects (1).Height = 3, "the bottom band spans the box width");
      Assert (Rects (2).X = 30 and then Rects (2).Y = 13, "the right band is offset beside the box");
      Assert (Rects (2).Width = 3 and then Rects (2).Height = 15, "the right band spans the box height");

      --  Both bands fall outside a tiny clip window and are dropped.
      Rects.Clear;
      Draw_Drop_Shadow (Rects, 20, 20, 10, 10, 20, 15, Overlay_Color);
      Assert (Count (Rects) = 0, "shadow bands off-screen of the clip are dropped");
   end Test_Drop_Shadow;

   procedure Test_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
      Texts : Text_Command_Vectors.Vector;
   begin
      Draw_Close_Button
        (Rects, Texts, Big, Big, 10, 10, 20, 20,
         Hover_Color, Border_Color, 12, 12, 10, 10,
         U.To_Unbounded_String ("x"), Text_Color, Show_Glyph => True);
      Assert (Count (Rects) = 5, "a close button is a fill plus a four-edge border");
      Assert (Count (Texts) = 1, "the visible glyph emits one text command");
      Assert (Rects (1).Color = Hover_Color, "the fill uses the supplied fill color");
      Assert (Texts (1).X = 12 and then Texts (1).Y = 12, "the glyph is placed at its cell origin");
      Assert (Texts (1).Color = Text_Color, "the glyph uses the glyph color");

      --  A hidden glyph still draws the box but no text.
      Rects.Clear;
      Texts.Clear;
      Draw_Close_Button
        (Rects, Texts, Big, Big, 10, 10, 20, 20,
         Hover_Color, Border_Color, 12, 12, 10, 10,
         U.To_Unbounded_String ("x"), Text_Color, Show_Glyph => False);
      Assert (Count (Rects) = 5 and then Count (Texts) = 0, "a hidden glyph draws the box but no text");

      --  An empty glyph string draws no text.
      Rects.Clear;
      Texts.Clear;
      Draw_Close_Button
        (Rects, Texts, Big, Big, 10, 10, 20, 20,
         Hover_Color, Border_Color, 12, 12, 10, 10,
         U.Null_Unbounded_String, Text_Color, Show_Glyph => True);
      Assert (Count (Texts) = 0, "an empty glyph string draws no text");
   end Test_Close_Button;

   procedure Test_Segmented (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
      Texts : Text_Command_Vectors.Vector;
      Three_Labels : constant Segment_Label_Array :=
        [(Text => U.To_Unbounded_String ("A"), Truncated => False),
         (Text => U.To_Unbounded_String ("B"), Truncated => False),
         (Text => U.To_Unbounded_String ("C"), Truncated => False)];
      Two_Labels : constant Segment_Label_Array :=
        [(Text => U.To_Unbounded_String ("A"), Truncated => False),
         (Text => U.To_Unbounded_String ("B"), Truncated => False)];
   begin
      --  Three cells over a width that divides evenly: 3 fills + 3 borders(4) +
      --  3 labels, with cell 2 the active fill.
      Draw_Segmented
        (Rects, Texts, Big, Big, 10, 10, 10, 300, 3, 24,
         Three_Labels, Active_Index => 2,
         Active_Color => Selection_Color, Inactive_Color => Pane_Color,
         Border_Color => Border_Color, Label_Color => Text_Color, Padding => 8);
      Assert (Count (Rects) = 15, "three cells emit three fills and three four-edge borders");
      Assert (Count (Texts) = 3, "each cell emits its label");
      Assert (Rects (1).Width = 100, "each evenly divided cell is Content_Width / Cell_Count wide");
      Assert (Rects (1).Color = Pane_Color, "the first (inactive) cell uses the inactive color");
      Assert (Rects (6).Color = Selection_Color, "the active cell uses the active color");

      --  The last cell absorbs the integer-division remainder.
      Rects.Clear;
      Texts.Clear;
      Draw_Segmented
        (Rects, Texts, Big, Big, 10, 10, 10, 302, 3, 24,
         Three_Labels, Active_Index => 0,
         Active_Color => Selection_Color, Inactive_Color => Pane_Color,
         Border_Color => Border_Color, Label_Color => Text_Color, Padding => 8);
      Assert (Rects (1).Width = 100, "the first remainder-test cell is the base width");
      Assert (Rects (11).Width = 102, "the last cell absorbs the 302 / 3 remainder");

      --  Fewer drawn cells than the grid divisor keeps the uniform width.
      Rects.Clear;
      Texts.Clear;
      Draw_Segmented
        (Rects, Texts, Big, Big, 10, 10, 10, 400, 4, 24,
         Two_Labels, Active_Index => 1,
         Active_Color => Selection_Color, Inactive_Color => Pane_Color,
         Border_Color => Border_Color, Label_Color => Text_Color, Padding => 8);
      Assert (Count (Rects) = 10, "two drawn cells emit ten rectangles");
      Assert (Rects (1).Width = 100 and then Rects (6).Width = 100,
              "cells short of the remainder cell keep the uniform width");
   end Test_Segmented;

   procedure Test_Scrollbar (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
   begin
      --  A tall thumb on a wide track draws track + thumb + border + 3 grips.
      Draw_Scrollbar (Rects, Big, Big, 90, 0, 10, 100, 10, 30,
                      Pane_Color, Selection_Color, Muted_Text_Color);
      Assert (Count (Rects) = 9, "a wide tall scrollbar is track, thumb, border and three grip lines");
      Assert (Rects (1).Color = Pane_Color and then Rects (1).Width = 10, "the track fills the full width");
      Assert (Rects (2).Color = Selection_Color, "the thumb is painted on top of the track");

      --  A short thumb draws no grip lines.
      Rects.Clear;
      Draw_Scrollbar (Rects, Big, Big, 90, 0, 10, 100, 10, 5,
                      Pane_Color, Selection_Color, Muted_Text_Color);
      Assert (Count (Rects) = 6, "a short thumb drops the grip lines");

      --  A too-narrow track draws no grip lines.
      Rects.Clear;
      Draw_Scrollbar (Rects, Big, Big, 90, 0, 2, 100, 10, 30,
                      Pane_Color, Selection_Color, Muted_Text_Color);
      Assert (Count (Rects) = 6, "a two-pixel track has no room for a grip");
   end Test_Scrollbar;

   procedure Test_Menu_Panel (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
   begin
      Draw_Menu_Panel (Rects, Big, Big, 10, 10, 50, 40, Pane_Color, Border_Color);
      Assert (Count (Rects) = 5, "a menu panel is a fill and four border edges");
      Assert (Rects (1).Color = Pane_Color, "the first rectangle is the panel fill");
      Assert (Rects (1).Width = 50 and then Rects (1).Height = 40, "the fill spans the panel");
      Assert (Rects (2).Color = Border_Color and then Rects (2).Height = 1, "the top border is one pixel tall");
   end Test_Menu_Panel;

   procedure Test_Menu_Row (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
      Texts : Text_Command_Vectors.Vector;
   begin
      --  A separator row is a single one-pixel divider and no label.
      Draw_Menu_Row
        (Rects, Texts, Big, Big, 0, 0, 0, 0,
         Is_Separator => True, Separator_X => 4, Separator_Y => 20, Separator_Width => 40,
         Separator_Color => Border_Color, Highlight => False, Highlight_Color => Hover_Color,
         Label_X => 0, Label_Y => 0, Label_Width => 0, Label_Height => 0,
         Label_Text => U.Null_Unbounded_String, Label_Truncated => False, Label_Color => Text_Color);
      Assert (Count (Rects) = 1 and then Count (Texts) = 0, "a separator row is one divider rectangle");
      Assert (Rects (1).X = 4 and then Rects (1).Y = 20 and then Rects (1).Height = 1,
              "the divider sits at its coordinates and is one pixel tall");

      --  A highlighted command row draws the highlight and the label.
      Rects.Clear;
      Texts.Clear;
      Draw_Menu_Row
        (Rects, Texts, Big, Big, 4, 30, 120, 22,
         Is_Separator => False, Separator_X => 0, Separator_Y => 0, Separator_Width => 0,
         Separator_Color => Border_Color, Highlight => True, Highlight_Color => Hover_Color,
         Label_X => 8, Label_Y => 34, Label_Width => 100, Label_Height => 16,
         Label_Text => U.To_Unbounded_String ("Open"), Label_Truncated => False, Label_Color => Text_Color);
      Assert (Count (Rects) = 1 and then Count (Texts) = 1, "a highlighted command row is a highlight plus a label");
      Assert (Rects (1).Color = Hover_Color, "the highlight uses the highlight color");
      Assert (Texts (1).X = 8 and then Texts (1).Y = 34, "the label sits at its box origin");

      --  A command row without a highlight draws only the label.
      Rects.Clear;
      Texts.Clear;
      Draw_Menu_Row
        (Rects, Texts, Big, Big, 4, 30, 120, 22,
         Is_Separator => False, Separator_X => 0, Separator_Y => 0, Separator_Width => 0,
         Separator_Color => Border_Color, Highlight => False, Highlight_Color => Hover_Color,
         Label_X => 8, Label_Y => 34, Label_Width => 100, Label_Height => 16,
         Label_Text => U.To_Unbounded_String ("Open"), Label_Truncated => False, Label_Color => Text_Color);
      Assert (Count (Rects) = 0 and then Count (Texts) = 1, "an unhighlighted command row is only its label");
   end Test_Menu_Row;

   procedure Test_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
      Texts : Text_Command_Vectors.Vector;
   begin
      Draw_Tooltip
        (Rects, Texts, Big, Big, 20, 20, 80, 24,
         Pane_Color, Border_Color, 24, 24, 72, 16,
         U.To_Unbounded_String ("Hint"), Label_Truncated => False, Label_Color => Text_Color);
      Assert (Count (Rects) = 5, "a tooltip is a fill and a four-edge border");
      Assert (Count (Texts) = 1, "a tooltip draws its label");
      Assert (Rects (1).Color = Pane_Color, "the first rectangle is the tooltip fill");
      Assert (Texts (1).X = 24 and then Texts (1).Color = Text_Color, "the label sits at its box origin");
   end Test_Tooltip;

   procedure Test_Caret (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
   begin
      Draw_Caret (Rects, Big, Big, 50, 10, 2, 16, Text_Color);
      Assert (Count (Rects) = 1, "a caret is a single rectangle");
      Assert (Rects (1).X = 50 and then Rects (1).Width = 2 and then Rects (1).Height = 16,
              "the caret sits at its coordinates with the requested size");

      --  A zero clip window drops the caret.
      Rects.Clear;
      Draw_Caret (Rects, 0, 0, 50, 10, 2, 16, Text_Color);
      Assert (Count (Rects) = 0, "a zero clip window drops the caret");

      --  An off-screen caret is dropped.
      Rects.Clear;
      Draw_Caret (Rects, 40, 40, 50, 10, 2, 16, Text_Color);
      Assert (Count (Rects) = 0, "a caret past the clip width is dropped");

      --  A zero-width caret draws nothing.
      Rects.Clear;
      Draw_Caret (Rects, Big, Big, 50, 10, 0, 16, Text_Color);
      Assert (Count (Rects) = 0, "a zero-width caret draws nothing");
   end Test_Caret;

   procedure Test_Marquee (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
   begin
      Draw_Marquee (Rects, Big, Big, 30, 30, 60, 40, Marquee_Color, Selection_Color);
      Assert (Count (Rects) = 5, "a marquee is a translucent fill and a four-edge border");
      Assert (Rects (1).Color = Marquee_Color, "the first rectangle is the marquee fill");
      Assert (Rects (1).Width = 60 and then Rects (1).Height = 40, "the fill spans the marquee");

      Rects.Clear;
      Draw_Marquee (Rects, Big, Big, 30, 30, 0, 40, Marquee_Color, Selection_Color);
      Assert (Count (Rects) = 0, "a zero-width marquee draws nothing");
   end Test_Marquee;

   procedure Test_Input_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rects : Rectangle_Command_Vectors.Vector;
   begin
      Draw_Input_Field (Rects, Big, Big, 10, 10, 120, 28, Input_Color, Border_Color);
      Assert (Count (Rects) = 5, "an input field is a fill and a four-edge border");
      Assert (Rects (1).Color = Input_Color, "the first rectangle is the field fill");
      Assert (Rects (1).Width = 120 and then Rects (1).Height = 28, "the fill spans the field");

      Rects.Clear;
      Draw_Input_Field (Rects, Big, Big, 10, 10, 0, 28, Input_Color, Border_Color);
      Assert (Count (Rects) = 0, "a zero-width input field draws nothing");
   end Test_Input_Field;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Widgets_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Guikit_Suite.Widgets;
