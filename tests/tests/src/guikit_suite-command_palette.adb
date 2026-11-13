with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Command_Palette;
with Guikit.Draw;
with Guikit.Layout;
with Guikit.Utf8;

--  Exercises the command-palette state machine (filtering, selection, id
--  mapping) and a headless Build_Frame that emits draw commands without a GPU.
package body Guikit_Suite.Command_Palette is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   package CP renames Guikit.Command_Palette;

   type Palette_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Palette_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Palette_Test_Case);

   procedure Test_Filter_And_Select (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Build_Frame (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Line_Height_Scaling (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Cached_Results (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Query_Scrolls (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Label_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Click_After_Query_Change (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Backspace_Whole_Character (T : in out AUnit.Test_Cases.Test_Case'Class);

   function Sample return CP.Command_Vectors.Vector is
      Result : CP.Command_Vectors.Vector;

      procedure Add (Id : Natural; Label : String) is
      begin
         Result.Append
           (CP.Command'
              (Id         => Id,
               Identifier => To_Unbounded_String (Label),
               Label      => To_Unbounded_String (Label),
               Enabled    => True,
               others     => <>));
      end Add;
   begin
      Add (10, "Firefox");
      Add (20, "Files");
      Add (30, "Calculator");
      return Result;
   end Sample;

   overriding function Name (T : Palette_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit command palette component");
   end Name;

   overriding procedure Register_Tests (T : in out Palette_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filter_And_Select'Access, "filtering narrows results, selection clamps, id maps back");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Build_Frame'Access, "Build_Frame emits draw commands and lays out clickable rows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Line_Height_Scaling'Access,
         "the palette's padding, title band, search box and row height scale with the line height");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cached_Results'Access,
         "cached results match a fresh search after every query and command-list edit");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Query_Scrolls'Access,
         "a long query scrolls so its end and the caret stay inside the search field, clear of the close button");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Label_Truncation'Access,
         "a row label too long for its row is truncated by the toolkit's one ellipsis rule");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Click_After_Query_Change'Access,
         "a click between a query change and the next frame selects nothing stale");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Backspace_Whole_Character'Access,
         "Backspace deletes a whole character with its combining marks");
   end Register_Tests;

   procedure Test_Filter_And_Select (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P : CP.Palette;
   begin
      CP.Set_Commands (P, Sample);
      Assert (CP.Result_Count (P) = 3, "all commands show for an empty query");
      Assert (CP.Selected_Index (P) = 1, "the first command is selected by default");
      Assert (CP.Selected_Id (P) = 10, "the selected id maps back to the first command");

      CP.Move_Selection (P, 1);
      Assert (CP.Selected_Id (P) = 20, "moving down selects the second command");
      CP.Move_Selection (P, 10);
      Assert (CP.Selected_Index (P) = 3, "moving past the end clamps to the last result");

      CP.Insert (P, "fire");
      Assert (CP.Result_Count (P) = 1, "a specific query narrows the results");
      Assert (CP.Selected_Index (P) = 1, "a new query resets the selection to the top");
      Assert (CP.Selected_Id (P) = 10, "the narrowed selection maps to Firefox");

      CP.Backspace (P);
      CP.Backspace (P);
      Assert (CP.Query (P) = "fi", "backspace edits the query");
      Assert (CP.Result_Count (P) = 2, "a shorter query matches more commands");

      CP.Set_Query (P, "zzz");
      Assert (CP.Result_Count (P) = 0, "a non-matching query yields no results");
      Assert (CP.Selected_Index (P) = 0, "no results clears the selection");
   end Test_Filter_And_Select;

   procedure Test_Build_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P     : CP.Palette;
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Icons : Guikit.Draw.Icon_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
   begin
      CP.Set_Commands (P, Sample);
      CP.Build_Frame
        (P, 0, 0, 400, 300, 400, 300, True, -1, -1, Rects, Text, Icons, Nodes);
      Assert (not Rects.Is_Empty, "Build_Frame emits rectangles (panel, rows)");
      Assert (not Text.Is_Empty, "Build_Frame emits text (row labels)");
      Assert (not Nodes.Is_Empty, "Build_Frame emits accessibility nodes");
      --  A click on the first result row selects it.
      declare
         Hit : constant Boolean := CP.Click (P, 200, 60);
      begin
         Assert (Hit or else CP.Selected_Index (P) >= 1, "a click hits a laid-out row");
      end;
   end Test_Build_Frame;

   procedure Test_Line_Height_Scaling (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Accessibility_Role;

      Width  : constant := 800;
      Height : constant := 600;

      --  Lay out and render the palette at Line_Height and check it against the
      --  expected chrome at that height: the panel padding (8 at 20 px), the
      --  result-row padding (4) and the search box's input-field padding (8).
      procedure Check (LH : Positive; Pad, Row_Pad, Field_Pad : Natural) is
         Where     : constant String := " at line height" & LH'Image;
         Layout    : constant Guikit.Layout.Palette_Layout :=
           Guikit.Layout.Calculate_Palette_Layout (0, 0, Width, Height, LH);
         Search_H  : constant Natural := LH + 2 * Field_Pad;
         Row_H     : constant Natural := 2 * LH + 2 * Row_Pad;
         Title_H   : constant Natural := LH + Pad;
         Results_Y : constant Natural := Pad + Title_H + Search_H + Pad;
         P         : CP.Palette;
         Rects     : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text      : Guikit.Draw.Text_Command_Vectors.Vector;
         Icons     : Guikit.Draw.Icon_Command_Vectors.Vector;
         Nodes     : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Seen_Heading, Seen_Search, Seen_Row, Seen_Label : Boolean := False;
      begin
         --  The pure layout, without a title band.
         Assert (Layout.Search_X = Pad and then Layout.Search_Y = Pad,
                 "the search box is inset by the palette padding" & Where);
         Assert (Layout.Search_Width = Width - 2 * Pad, "the search box spans the panel less two paddings" & Where);
         Assert (Layout.Search_Height = Search_H, "the search box is a line plus two field paddings" & Where);
         Assert (Layout.Results_X = Pad, "the results are inset by the palette padding" & Where);
         Assert (Layout.Results_Y = Pad + Search_H + Pad, "the results sit one padding below the search box" & Where);
         Assert (Layout.Results_Height = Height - 2 * Pad - Search_H - Pad,
                 "the results fill the rest of the padded panel" & Where);
         Assert (Layout.Row_Height = Row_H, "a result row is two lines plus two row paddings" & Where);

         --  The component, with a title band (one line plus a padding).
         CP.Set_Configuration
           (P, CP.Configuration'(Line_Height => LH, Title => To_Unbounded_String ("Commands"), others => <>));
         CP.Set_Commands (P, Sample);
         CP.Build_Frame (P, 0, 0, Width, Height, Width, Height, False, -1, -1, Rects, Text, Icons, Nodes);
         for Node of Nodes loop
            if Node.Role = Guikit.Draw.Role_Heading then
               Seen_Heading := True;
               Assert (Node.X = Pad, "the title is inset by the palette padding" & Where);
            elsif Node.Role = Guikit.Draw.Role_Text_Input then
               Seen_Search := True;
               Assert (Node.X = Pad and then Node.Y = Pad + Title_H,
                       "the search box sits below the padded title band" & Where);
               Assert (Node.Height = Search_H, "the rendered search box has the scaled height" & Where);
            elsif Node.Role = Guikit.Draw.Role_List_Item and then Node.Name = "Firefox" then
               Seen_Row := True;
               Assert (Node.X = Pad and then Node.Y = Results_Y,
                       "the first row starts one padding below the search box" & Where);
               Assert (Node.Height = Row_H, "the rendered row has the scaled height" & Where);
            end if;
         end loop;
         for Command of Text loop
            if Command.Text = "Firefox" then
               Seen_Label := True;
               Assert (Command.X = 2 * Pad, "a row label is inset by the padding inside the padded row" & Where);
               Assert (Command.Y = Results_Y + Row_Pad, "a row label sits one row padding into its row" & Where);
            end if;
         end loop;
         Assert (Seen_Heading and then Seen_Search and then Seen_Row and then Seen_Label,
                 "the title, search box, first row and its label are all rendered" & Where);
      end Check;

      --  The rest of the chrome: the icon column (36 px at 20 px), the
      --  scrollbar (12 px), the floating panel's top accent band (3 px) and
      --  its drop shadow (3 px in from the corner).
      procedure Check_Chrome (LH : Positive; Pad, Icon_Slot, Bar, Accent, Shadow : Natural) is
         use type Guikit.Draw.Render_Color;

         Where    : constant String := " at line height" & LH'Image;
         Many     : CP.Command_Vectors.Vector;
         P        : CP.Palette;
         Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text     : Guikit.Draw.Text_Command_Vectors.Vector;
         Icons    : Guikit.Draw.Icon_Command_Vectors.Vector;
         Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Seen_Label, Seen_Bar, Seen_Accent, Seen_Shadow : Boolean := False;
      begin
         for I in 1 .. 60 loop
            Many.Append
              (CP.Command'
                 (Id => I, Label => To_Unbounded_String ("Entry" & I'Image), Enabled => True, others => <>));
         end loop;
         CP.Set_Configuration
           (P, CP.Configuration'(Line_Height => LH, Show_Icons => True, Overlay => True, others => <>));
         CP.Set_Commands (P, Many);
         --  Clipped wider than the panel, so its shadow (outside it) is kept.
         CP.Build_Frame (P, 0, 0, Width, Height, Width + 100, Height + 100, False, -1, -1, Rects, Text, Icons, Nodes);
         for Command of Text loop
            if Command.Text = "Entry 1" then
               Seen_Label := True;
               Assert (Command.X = 3 * Pad + Icon_Slot,
                       "a row label clears the padded icon column" & Where);
            end if;
         end loop;
         for R of Rects loop
            if R.X = Width - Bar and then R.Width = Bar and then R.Color = Guikit.Draw.Border_Color then
               Seen_Bar := True;
            elsif R.X = 0 and then R.Y = 0 and then R.Width = Width and then R.Height = Accent
              and then R.Color = Guikit.Draw.Selection_Color
            then
               Seen_Accent := True;
            elsif R.Color = Guikit.Draw.Shadow_Color and then R.X = Shadow and then R.Y = Height then
               Seen_Shadow := True;
            end if;
         end loop;
         Assert (Seen_Label, "the first row's label is drawn" & Where);
         Assert (Seen_Bar, "the scrollbar track is the scaled width, at the panel's right edge" & Where);
         Assert (Seen_Accent, "the panel's top accent band is the scaled height" & Where);
         Assert (Seen_Shadow, "the drop shadow starts the scaled offset in from the corner" & Where);
      end Check_Chrome;

      Base   : constant Guikit.Layout.Palette_Layout :=
        Guikit.Layout.Calculate_Palette_Layout (0, 0, Width, Height, 20);
      Double : constant Guikit.Layout.Palette_Layout :=
        Guikit.Layout.Calculate_Palette_Layout (0, 0, Width, Height, 40);
   begin
      Check (20, Pad => 8, Row_Pad => 4, Field_Pad => 8);
      Check (30, Pad => 12, Row_Pad => 6, Field_Pad => 12);
      Check (40, Pad => 16, Row_Pad => 8, Field_Pad => 16);
      Check_Chrome (20, Pad => 8, Icon_Slot => 36, Bar => 12, Accent => 3, Shadow => 3);
      Check_Chrome (40, Pad => 16, Icon_Slot => 72, Bar => 24, Accent => 6, Shadow => 6);

      --  Everything the line height drives is exactly doubled at twice the line height.
      Assert (Double.Search_X = 2 * Base.Search_X, "the palette padding doubles at 2x");
      Assert (Double.Search_Height = 2 * Base.Search_Height, "the search box height doubles at 2x");
      Assert (Double.Results_Y = 2 * Base.Results_Y, "the results top doubles at 2x");
      Assert (Double.Row_Height = 2 * Base.Row_Height, "the row height doubles at 2x");
   end Test_Line_Height_Scaling;

   procedure Test_Cached_Results (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P : CP.Palette;

      function Others_List return CP.Command_Vectors.Vector is
         Labels : constant array (Positive range 1 .. 4) of Unbounded_String :=
           [To_Unbounded_String ("Find in files"), To_Unbounded_String ("File info"),
            To_Unbounded_String ("Fill colour"), To_Unbounded_String ("Quit")];
         Result : CP.Command_Vectors.Vector;
      begin
         for Label of Labels loop
            Result.Append
              (CP.Command'(Id => Natural (Result.Length) + 100, Identifier => Label, Label => Label,
                           Enabled => True, others => <>));
         end loop;
         return Result;
      end Others_List;

      --  The palette's results against a fresh palette given the same command
      --  list and query, which searches from scratch.
      procedure Check (Commands : CP.Command_Vectors.Vector; Step : String) is
         Fresh : CP.Palette;
      begin
         CP.Set_Commands (Fresh, Commands);
         CP.Set_Query (Fresh, CP.Query (P));
         declare
            Got  : constant CP.Command_Vectors.Vector := CP.Results (P);
            Want : constant CP.Command_Vectors.Vector := CP.Results (Fresh);
         begin
            Assert (Natural (Got.Length) = Natural (Want.Length)
                      and then CP.Result_Count (P) = CP.Result_Count (Fresh),
                    Step & ": as many results as a fresh search");
            for I in Want.First_Index .. Want.Last_Index loop
               Assert (Got.Element (I).Id = Want.Element (I).Id, Step & ": the same ranking as a fresh search");
            end loop;
            Assert (CP.Selected_Id (P) =
                      (if CP.Selected_Index (P) in 1 .. Natural (Want.Length)
                       then Want.Element (CP.Selected_Index (P)).Id else 0),
                    Step & ": the selection maps into the current results");
         end;
      end Check;
   begin
      CP.Set_Commands (P, Sample);
      Check (Sample, "after Set_Commands");
      CP.Insert (P, "f");
      Check (Sample, "after typing f");
      CP.Insert (P, "i");
      Check (Sample, "after typing fi");
      CP.Set_Commands (P, Others_List);
      Check (Others_List, "after replacing the commands under a query");
      CP.Backspace (P);
      Check (Others_List, "after a backspace");
      CP.Set_Query (P, "qu");
      Check (Others_List, "after Set_Query");
      CP.Set_Query (P, "qu");
      Check (Others_List, "after setting the same query again");
      CP.Reset (P);
      Check (Others_List, "after Reset");
      CP.Set_Commands (P, Sample);
      Check (Sample, "after replacing the commands with an empty query");
   end Test_Cached_Results;

   procedure Test_Query_Scrolls (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Render_Color;

      LH      : constant := 20;
      Width   : constant := 400;
      Height  : constant := 300;
      Cell_W  : constant Natural := Guikit.Layout.Caret_Advance_Width (LH);
      Caret_W : constant Natural := Natural'Max (1, Cell_W / 6);
      Layout  : constant Guikit.Layout.Palette_Layout :=
        Guikit.Layout.Calculate_Palette_Layout (0, 0, Width, Height, LH);
      Pad     : constant Natural := Guikit.Layout.Scaled (Guikit.Layout.Palette_Padding, LH);
      --  The overlay's close button: a line-height square inset max (4, LH / 4).
      Close_X : constant Natural := Width - Natural'Max (Guikit.Layout.Scaled (4, LH), LH / 4) - LH;

      --  Render Query and check the drawn query text and caret.
      procedure Check (Query : String; Scrolled : Boolean) is
         P       : CP.Palette;
         Rects   : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text    : Guikit.Draw.Text_Command_Vectors.Vector;
         Icons   : Guikit.Draw.Icon_Command_Vectors.Vector;
         Nodes   : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Shown   : Unbounded_String;
         Field_X : constant Natural := Layout.Search_X + Pad;
         Field_W : Natural := 0;
         Carets  : Natural := 0;
      begin
         CP.Set_Configuration (P, CP.Configuration'(Line_Height => LH, Overlay => True, others => <>));
         CP.Set_Commands (P, Sample);
         CP.Set_Query (P, Query);
         CP.Build_Frame (P, 0, 0, Width, Height, Width, Height, True, -1, -1, Rects, Text, Icons, Nodes);
         for Command of Text loop
            if Command.X = Field_X and then Command.Color = Guikit.Draw.Text_Color and then Command.Y < Layout.Results_Y
            then
               Shown := Command.Text;
               Field_W := Command.Width;
            end if;
         end loop;
         declare
            S : constant String := To_String (Shown);
         begin
            Assert (S'Length > 0, Natural'Image (Query'Length) & "-byte query: the query text is drawn");
            Assert (Field_X + Field_W <= Close_X, "the query field ends before the close button");
            Assert (Guikit.Utf8.Display_Units (S) * Cell_W <= Field_W, "the shown query fits the field");
            Assert (S = Query (Query'Last - S'Length + 1 .. Query'Last), "the shown query is the query's end");
            Assert ((S'Length < Query'Length) = Scrolled,
                    (if Scrolled then "a long query scrolls its start off" else "a short query shows whole"));
            for R of Rects loop
               if R.Color = Guikit.Draw.Text_Color and then R.Width = Caret_W and then R.Height = LH then
                  Carets := Carets + 1;
                  Assert (R.X = Field_X + Guikit.Utf8.Display_Units (S) * Cell_W,
                          "the caret follows the end of the shown query");
                  Assert (R.X + R.Width <= Field_X + Field_W, "the caret stays inside the field");
               end if;
            end loop;
            Assert (Carets = 1, "one caret is drawn");
         end;
      end Check;

      Digits_Run : constant String := "0123456789";

      --  Man, woman, girl, boy joined by zero-width joiners: one cluster
      --  several columns wide.
      Joiner : constant String := Guikit.Utf8.Encode (16#200D#);
      Family : constant String :=
        Guikit.Utf8.Encode (16#1F468#) & Joiner & Guikit.Utf8.Encode (16#1F469#) & Joiner
        & Guikit.Utf8.Encode (16#1F467#) & Joiner & Guikit.Utf8.Encode (16#1F466#);
      --  The query field's width in columns, as Build_Frame lays it out: the
      --  search box ends before the overlay's close button.
      Inset    : constant Natural := Natural'Max (Guikit.Layout.Scaled (4, LH), LH / 4);
      Search_W : constant Natural := (Layout.X + Layout.Width - LH - 2 * Inset) - Layout.Search_X;
      Capacity : constant Natural := (Search_W - 2 * Pad) / Cell_W;
      --  The family, then enough digits that the caret is two columns past the
      --  field: two columns must scroll off, and the cluster is wider than
      --  that, so the whole family goes.
      Tail_Length : constant Natural := Capacity + 1 - Guikit.Utf8.Display_Units (Family);
      Tail        : constant String (1 .. Tail_Length) := [others => '7'];
   begin
      Check ("abc", Scrolled => False);
      Check (Digits_Run & Digits_Run & Digits_Run & Digits_Run & Digits_Run & Digits_Run & Digits_Run & Digits_Run,
             Scrolled => True);
      Assert (Guikit.Utf8.Display_Units (Family) > 2, "the family cluster is wider than the scrolled columns");
      Check (Family & Tail, Scrolled => True);
   end Test_Query_Scrolls;

   procedure Test_Label_Truncation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Label    : constant String := "Open. Recent. Files. And. More. Things. Here. And. Even. More. Of. Them.";
      Cell_W   : constant Natural := Guikit.Layout.Caret_Advance_Width (20);
      Commands : CP.Command_Vectors.Vector;
      P        : CP.Palette;
      Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text     : Guikit.Draw.Text_Command_Vectors.Vector;
      Icons    : Guikit.Draw.Icon_Command_Vectors.Vector;
      Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Seen     : Boolean := False;
   begin
      Commands.Append
        (CP.Command'(Id => 1, Identifier => To_Unbounded_String (Label), Label => To_Unbounded_String (Label),
                     Enabled => True, others => <>));
      CP.Set_Commands (P, Commands);
      CP.Build_Frame (P, 0, 0, 240, 200, 240, 200, False, -1, -1, Rects, Text, Icons, Nodes);
      for Command of Text loop
         if Command.Truncated then
            Seen := True;
            Assert (To_String (Command.Text) = Guikit.Utf8.Fit_With_Ellipsis (Label, Command.Width / Cell_W),
                    "the label is fitted by Guikit.Utf8.Fit_With_Ellipsis");
         end if;
      end loop;
      Assert (Seen, "the too-long label is drawn truncated");
   end Test_Label_Truncation;

   procedure Test_Click_After_Query_Change (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Accessibility_Role;
      P     : CP.Palette;
      Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text  : Guikit.Draw.Text_Command_Vectors.Vector;
      Icons : Guikit.Draw.Icon_Command_Vectors.Vector;
      Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Rows  : Guikit.Draw.Accessibility_Node_Vectors.Vector;

      function Centre_X (Row : Positive) return Integer is (Rows (Row).X + Rows (Row).Width / 2);
      function Centre_Y (Row : Positive) return Integer is (Rows (Row).Y + Rows (Row).Height / 2);
   begin
      CP.Set_Commands (P, Sample);
      CP.Build_Frame (P, 0, 0, 400, 300, 400, 300, True, -1, -1, Rects, Text, Icons, Nodes);
      for Node of Nodes loop
         if Node.Role = Guikit.Draw.Role_List_Item then
            Rows.Append (Node);
         end if;
      end loop;
      Assert (Natural (Rows.Length) = 3, "every command is laid out as a row");

      --  Narrow to one result without a new frame: the third row's place now
      --  names no result, and the first row's names one ranked differently.
      CP.Insert (P, "fire");
      Assert (CP.Result_Count (P) = 1, "the query narrows to one result");
      Assert (not CP.Click (P, Centre_X (3), Centre_Y (3)),
              "a click where a stale row was laid out is not a hit");
      Assert (CP.Selected_Index (P) = 1, "the stale click leaves the selection in the results");
      Assert (not CP.Click (P, Centre_X (1), Centre_Y (1)),
              "no row is hit until the next frame lays the new results out");

      CP.Set_Commands (P, Sample);
      CP.Build_Frame (P, 0, 0, 400, 300, 400, 300, True, -1, -1, Rects, Text, Icons, Nodes);
      Assert (CP.Click (P, Centre_X (1), Centre_Y (1)), "after a frame the new first row is hit");
      Assert (CP.Selected_Id (P) = 10, "and selects the one result");
      CP.Set_Commands (P, Sample);
      Assert (not CP.Click (P, Centre_X (1), Centre_Y (1)), "a new command list drops the laid-out rows too");
   end Test_Click_After_Query_Change;

   procedure Test_Backspace_Whole_Character (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      P : CP.Palette;
      --  "e" with a combining acute accent, after an "a-ring".
      Accented : constant String := Guikit.Utf8.Encode (16#E5#) & "e" & Guikit.Utf8.Encode (16#301#);
   begin
      CP.Set_Commands (P, Sample);
      CP.Set_Query (P, Accented);
      CP.Backspace (P);
      Assert (CP.Query (P) = Guikit.Utf8.Encode (16#E5#), "the base letter goes with its combining mark");
      CP.Backspace (P);
      Assert (CP.Query (P) = "", "a two-byte letter goes whole");
      CP.Backspace (P);
      Assert (CP.Query (P) = "", "Backspace on an empty query does nothing");
   end Test_Backspace_Whole_Character;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Palette_Test_Case));
      return Result;
   end Suite;

end Guikit_Suite.Command_Palette;
