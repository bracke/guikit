with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Draw;

--  A stateful, searchable command-palette component built on top of the pure
--  guikit widget/layout/search tiers. The caller supplies a list of commands and
--  feeds it input events (typing, navigation, clicks); the component owns the
--  query, selection and scroll state, filters + ranks with Guikit.Palette, keeps
--  the selection visible, and renders itself (panel, search box, result rows,
--  optional icons/shortcuts, scrollbar) into draw-command vectors. It returns the
--  chosen command's opaque Id; the caller decides what that means and acts on it.
--
--  This is a higher, *stateful* tier than Guikit.Widgets — the widgets stay pure;
--  this bundles them for the common "filter a list, pick one" case.
package Guikit.Command_Palette is

   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   --  Optional per-command icon, as a row-major RGBA bitmap (Width = 0 means the
   --  command has no icon). Fed through the guikit icon-atlas bitmap path.
   type Command_Icon is record
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Guikit.Draw.Byte_Vectors.Vector;
   end record;

   No_Icon : constant Command_Icon := (Width => 0, Height => 0, Pixels => <>);

   --  One selectable command. Id is opaque to the component and returned on
   --  selection. Identifier/Label/Description/Shortcut are searched (per the
   --  Guikit.Palette field weighting); Label/Description/Shortcut are also shown.
   type Command is record
      Id          : Natural := 0;
      Identifier  : UString;
      Label       : UString;
      Description : UString;
      Shortcut    : UString;
      Enabled     : Boolean := True;
      Icon        : Command_Icon := No_Icon;
   end record;

   package Command_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Command);

   --  Presentation and behaviour options that span the consumers: the launcher
   --  (icons, full window, clamp navigation) and a files-style overlay (shortcuts,
   --  drop shadow, wrap-around navigation).
   type Configuration is record
      Line_Height    : Positive := 20;
      Show_Icons     : Boolean  := False;  --  draw a left icon gutter
      Show_Shortcuts : Boolean  := False;  --  draw a right-aligned shortcut column
      Overlay        : Boolean  := False;  --  drop shadow + close button (floating)
      Wrap_Selection : Boolean  := False;  --  navigation wraps at the ends
      Placeholder    : UString;            --  shown in the search box when empty
      Empty_State    : UString;            --  shown when no command matches
   end record;

   type Palette is private;

   --  Replace the presentation/behaviour configuration.
   procedure Set_Configuration (P : in out Palette; Config : Configuration);

   --  Replace the command list and re-clamp the selection to the new results.
   procedure Set_Commands (P : in out Palette; Commands : Command_Vectors.Vector);

   --  Append typed text to the query (resets the selection to the first result).
   procedure Insert (P : in out Palette; Text : String);

   --  Delete the last query character (UTF-8 aware) and reset the selection.
   procedure Backspace (P : in out Palette);

   --  Replace the whole query (e.g. from a controller's own text editing) and
   --  reset the selection.
   procedure Set_Query (P : in out Palette; Query : String);

   --  Reset the query, selection and scroll (e.g. when closing the palette).
   procedure Reset (P : in out Palette);

   --  Move the highlighted result by Delta_Rows, clamped (or wrapped when
   --  Wrap_Selection is set) to the result range.
   procedure Move_Selection (P : in out Palette; Delta_Rows : Integer);

   --  Highlight the first / last result (or clear when there are none).
   procedure Select_First (P : in out Palette);
   procedure Select_Last (P : in out Palette);

   --  Move by a page (the last-rendered visible row count), clamped.
   procedure Page (P : in out Palette; Down : Boolean);

   --  Select the result at a window coordinate, using the most recent layout.
   --
   --  @return True when a result row was hit (and is now selected).
   function Click (P : in out Palette; X : Integer; Y : Integer) return Boolean;

   --  The current query text.
   function Query (P : Palette) return String;

   --  One-based index of the highlighted result (0 when none).
   function Selected_Index (P : Palette) return Natural;

   --  Number of results matching the current query.
   function Result_Count (P : Palette) return Natural;

   --  The Id of the highlighted command, or 0 when nothing is selected.
   function Selected_Id (P : Palette) return Natural;

   --  The current query's matching commands, ranked best-first (for a caller
   --  that maintains its own snapshot/tests of the result set).
   function Results (P : Palette) return Command_Vectors.Vector;

   --  Render the palette within a region and remember the row layout for Click.
   --
   --  Emits the panel (with drop shadow + close button when Overlay), the search
   --  box + query/placeholder + caret, the result rows (with optional icons and
   --  shortcuts), the empty-state message and the scrollbar, plus one
   --  accessibility node per element. The caller submits Rectangles/Text/Icons
   --  and owns the accessibility nodes.
   --
   --  @param P Palette to render (updates its cached row layout + scroll offset).
   --  @param Region_X Left edge of the palette region in pixels.
   --  @param Region_Y Top edge of the palette region in pixels.
   --  @param Region_Width Palette region width in pixels.
   --  @param Region_Height Palette region height in pixels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Focused Whether the search box has keyboard focus (caret/ring).
   --  @param Hover_X Cursor X in pixels (negative when off-window).
   --  @param Hover_Y Cursor Y in pixels.
   --  @param Rectangles Out: rectangle commands.
   --  @param Text Out: text commands.
   --  @param Icons Out: icon commands.
   --  @param Accessibility Out: accessibility nodes for the palette elements.
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
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

private

   --  Cached geometry of one rendered result row, for click hit-testing.
   type Row_Rect is record
      Result_Index : Positive := 1;
      X, Y, W, H   : Natural := 0;
   end record;

   package Row_Rect_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Row_Rect);

   type Palette is record
      Config       : Configuration;
      Commands     : Command_Vectors.Vector;
      Query        : UString;
      Selected     : Natural := 0;   --  1-based into the results, 0 = none
      Offset       : Natural := 0;
      Rows         : Row_Rect_Vectors.Vector;  --  from the last Build_Frame
      Visible_Rows : Natural := 0;             --  from the last Build_Frame
   end record;

end Guikit.Command_Palette;
