with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Containers; use type Ada.Containers.Count_Type;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Guikit.Draw;
with Guikit.List_Panel;
with Guikit.Tree_Panel;

package body Guikit_Suite.Tree_Panel is

   package U renames Ada.Strings.Unbounded;
   use type Guikit.Draw.Render_Color;

   type Tree_Panel_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name
     (T : Tree_Panel_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests
     (T : in out Tree_Panel_Test_Case);

   procedure Test_Draw_Indent_Guides
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   function Count_Guides
     (Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector) return Natural
   is
      Count : Natural := 0;
   begin
      for R of Rects loop
         if R.Width = 1
           and then R.Color = Guikit.Draw.Muted_Text_Color
           and then R.Height = 20
         then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Count_Guides;

   function Count_Texts
     (Texts : Guikit.Draw.Text_Command_Vectors.Vector) return Natural
   is
   begin
      return Natural (Texts.Length);
   end Count_Texts;

   function Name (T : Tree_Panel_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit tree panel draw commands");
   end Name;

   procedure Register_Tests (T : in out Tree_Panel_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Draw_Indent_Guides'Access,
         "Draw_Frame emits indentation guides for nested tree rows");
   end Register_Tests;

   procedure Test_Draw_Indent_Guides
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Texts : Guikit.Draw.Text_Command_Vectors.Vector;
      Nodes : Guikit.Tree_Panel.Tree_Panel_Row_Vectors.Vector;
      Accessibility : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Config : constant Guikit.Tree_Panel.Tree_Panel_Configuration :=
        (Title               => U.Null_Unbounded_String,
         Empty_State         => U.Null_Unbounded_String,
         Line_Height         => 20,
         Text_Padding        => 12,
         Show_Alternate_Rows => False,
         Indent_In_Columns   => 2,
         Show_Indent_Guides  => True,
         Guide_Color         => Guikit.Draw.Muted_Text_Color);
   begin
      Nodes.Append
        (Guikit.Tree_Panel.Tree_Panel_Row'
           (Row =>
              (Label            => To_Unbounded_String ("src"),
               Detail           => U.Null_Unbounded_String,
               Shortcut         => U.Null_Unbounded_String,
               Selected         => False,
               Enabled          => True,
               Label_Color      => Guikit.Draw.Text_Color,
               Has_Background   => False,
               Background_Color => Guikit.Draw.Pane_Color,
               Accent_Color     => Guikit.Draw.Border_Color,
               Shortcut_Color   => Guikit.Draw.Muted_Text_Color),
            Depth => 2));

      Guikit.Tree_Panel.Draw_Frame
        (Rectangles    => Rects,
         Text          => Texts,
         Accessibility => Accessibility,
         Clip_Width    => 400,
         Clip_Height   => 80,
         Region_X      => 0,
         Region_Y      => 0,
         Region_Width  => 200,
         Region_Height => 40,
         Config        => Config,
         Rows          => Nodes,
         Draw_Chrome   => False);

      Assert (Count_Guides (Rects) = 2,
              "nested row must emit one indentation guide per depth level");
      Assert (Count_Texts (Texts) > 0,
              "tree panel must still emit row text");
   end Test_Draw_Indent_Guides;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (new Tree_Panel_Test_Case);
      return Result;
   end Suite;

end Guikit_Suite.Tree_Panel;
