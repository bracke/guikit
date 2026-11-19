with Guikit.Layout;
with Guikit.Text_Fields;
with Guikit.Palette;
with Guikit.Utf8;
with Guikit.Utf8.Editing;
with Guikit.Widgets;

package body Guikit.Command_Palette is

   use Ada.Strings.Unbounded;
   use type Guikit.Draw.Render_Color;

   --  The width of a row's icon column at Guikit.Layout.Reference_Line_Height;
   --  it grows with the text like the rest of the chrome.
   Icon_Slot_Base : constant Natural := 36;
   --  Match the grid/list scrollbar width so panels look consistent (at the
   --  reference line height, scaled with the text).
   Bar_Width_Base : constant Natural := 12;
   --  Re-rank the commands for the current query unless the cached results
   --  already belong to this query and command list. Each Guikit.Palette
   --  item's Id is the one-based index into Commands, so results map straight
   --  back. An empty query keeps input order. A new ranking also drops the
   --  rows the last Build_Frame laid out: they map screen positions to the
   --  old ranking's indexes, so a click before the next frame must not pick
   --  from them.
   procedure Refresh_Results (P : in out Palette) is
      Items : Guikit.Palette.Item_Vectors.Vector;
   begin
      if P.Ranked_Revision = P.Revision and then P.Ranked_Query = P.Query then
         return;
      end if;
      for I in P.Commands.First_Index .. P.Commands.Last_Index loop
         declare
            C : constant Command := P.Commands.Element (I);
         begin
            Items.Append
              (Guikit.Palette.Item'
                 (Id          => I,
                  Identifier  => C.Identifier,
                  Label       => C.Label,
                  Description => C.Description,
                  Shortcut    => C.Shortcut,
                  Enabled     => C.Enabled,
                  Score       => 0));
         end;
      end loop;
      P.Ranked.Clear;
      for Item of Guikit.Palette.Search (To_String (P.Query), Items) loop
         P.Ranked.Append (P.Commands.Element (Item.Id));
      end loop;
      P.Ranked_Query    := P.Query;
      P.Ranked_Revision := P.Revision;
      P.Rows.Clear;
   end Refresh_Results;

   --  The number of commands matching the current query: the cached ranking,
   --  which every query or command-list edit keeps current.
   function Ranked_Count (P : Palette) return Natural is (Natural (P.Ranked.Length));

   --  After the query changes: re-rank, and reset the selection to the first
   --  result (or none).
   procedure Reset_Selection (P : in out Palette) is
   begin
      Refresh_Results (P);
      P.Selected := (if Ranked_Count (P) = 0 then 0 else 1);
      P.Offset   := 0;
   end Reset_Selection;

   --  Fit Text into Max_Cells display cells with the toolkit's one truncation
   --  rule; Truncated reports whether it was shortened.
   function Fit_To_Cells
     (Text      : String;
      Max_Cells : Natural;
      Truncated : out Boolean)
      return String is
   begin
      Truncated := Guikit.Utf8.Display_Units (Text) > Max_Cells;
      return Guikit.Utf8.Fit_With_Ellipsis (Text, Max_Cells);
   end Fit_To_Cells;

   procedure Set_Configuration (P : in out Palette; Config : Configuration) is
   begin
      P.Config := Config;
   end Set_Configuration;

   procedure Set_Commands (P : in out Palette; Commands : Command_Vectors.Vector) is
      Count : Natural;
   begin
      P.Commands := Commands;
      P.Revision := P.Revision + 1;
      Refresh_Results (P);
      Count := Ranked_Count (P);
      if Count = 0 then
         P.Selected := 0;
      elsif P.Selected = 0 or else P.Selected > Count then
         P.Selected := 1;
      end if;
   end Set_Commands;

   procedure Insert (P : in out Palette; Text : String) is
   begin
      Append (P.Query, Text);
      Reset_Selection (P);
   end Insert;

   procedure Backspace (P : in out Palette) is
      S          : constant String := To_String (P.Query);
      New_Cursor : Natural;
   begin
      if S'Length = 0 then
         return;
      end if;
      --  The shared text-field rule: a whole character, with any combining
      --  marks after it, at the caret (which is the query's end).
      Guikit.Utf8.Editing.Delete_At
        (Text       => S,
         Cursor     => S'Length,
         Backward   => True,
         By_Word    => False,
         New_Text   => P.Query,
         New_Cursor => New_Cursor);
      pragma Unreferenced (New_Cursor);
      Reset_Selection (P);
   end Backspace;

   procedure Set_Query (P : in out Palette; Query : String) is
   begin
      P.Query := To_Unbounded_String (Query);
      Reset_Selection (P);
   end Set_Query;

   procedure Reset (P : in out Palette) is
   begin
      P.Query    := Null_Unbounded_String;
      Refresh_Results (P);
      P.Selected := 0;
      P.Offset   := 0;
      P.Rows.Clear;
   end Reset;

   procedure Move_Selection (P : in out Palette; Delta_Rows : Integer) is
      Count : constant Natural := Ranked_Count (P);
      Next  : Integer;
   begin
      if Count = 0 then
         P.Selected := 0;
         return;
      end if;
      if P.Config.Wrap_Selection then
         --  Wrap around the 1 .. Count range.
         Next := (if P.Selected = 0 then 1 else P.Selected) + Delta_Rows;
         while Next < 1 loop
            Next := Next + Count;
         end loop;
         while Next > Count loop
            Next := Next - Count;
         end loop;
      else
         Next := Integer'Max (1, Integer'Min (Integer (P.Selected) + Delta_Rows, Count));
      end if;
      P.Selected := Natural (Next);
   end Move_Selection;

   procedure Select_First (P : in out Palette) is
   begin
      P.Selected := (if Ranked_Count (P) = 0 then 0 else 1);
   end Select_First;

   procedure Select_Last (P : in out Palette) is
   begin
      P.Selected := Ranked_Count (P);
   end Select_Last;

   procedure Page (P : in out Palette; Down : Boolean) is
      Step : constant Integer := Integer'Max (1, P.Visible_Rows);
   begin
      Move_Selection (P, (if Down then Step else -Step));
   end Page;

   function Click (P : in out Palette; X : Integer; Y : Integer) return Boolean is
   begin
      for Row of P.Rows loop
         --  Rows always belong to the current ranking (a re-rank clears them),
         --  but a row that names no current result is never a hit.
         if Row.Result_Index <= Ranked_Count (P)
           and then X >= Row.X and then X < Row.X + Row.W
           and then Y >= Row.Y and then Y < Row.Y + Row.H
         then
            P.Selected := Row.Result_Index;
            return True;
         end if;
      end loop;
      return False;
   end Click;

   function Query (P : Palette) return String is (To_String (P.Query));

   function Selected_Index (P : Palette) return Natural is (P.Selected);

   function Result_Count (P : Palette) return Natural is (Ranked_Count (P));

   function Selected_Id (P : Palette) return Natural is
   begin
      if P.Selected in 1 .. Ranked_Count (P) then
         return P.Ranked.Element (P.Selected).Id;
      end if;
      return 0;
   end Selected_Id;

   function Results (P : Palette) return Command_Vectors.Vector is (P.Ranked);

   procedure Build_Frame
     (P             : in out Palette;
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
      Icons         : out Guikit.Draw.Icon_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Has_Glyph     : access function (Codepoint : Natural) return Boolean := null) is separate;

end Guikit.Command_Palette;
