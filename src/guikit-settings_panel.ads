with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Draw;

--  A stateful, scrollable settings/preferences form built on top of the pure
--  guikit widget tier. The caller supplies a list of typed field descriptors
--  (each: a label, a kind, a current value, and -- where it makes sense -- the
--  set of allowed values); the component renders the matching widget per field
--  (toggle, segmented choice, number stepper, text field, button row), owns the
--  focus/scroll/hit-testing, and reports a single change back to the caller when
--  the user edits a field or presses a button. The caller decides what a change
--  means (validate it, apply it to its own model, persist it) and re-supplies
--  the fields.
--
--  This is a higher, *stateful* tier than Guikit.Widgets -- the widgets stay
--  pure; this bundles them for the common "edit a set of typed settings" case,
--  the sibling of Guikit.Command_Palette.
package Guikit.Settings_Panel is

   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   package UString_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => UString,
      "="          => Ada.Strings.Unbounded."=");

   --  The kind of a form row, which selects the widget and interaction.
   type Field_Kind is
     (Section,   --  a non-interactive section header (Label only)
      Toggle,    --  a boolean; Value is "true" / "false"
      Choice,    --  pick one of Option_Values; Value is the chosen token
      Number,    --  an integer clamped to [Min .. Max]; Value is the number text
      Text,      --  a free-text value; the caller edits the whole string
      Buttons);  --  a row of buttons; Option_Values are ids, Option_Labels labels

   --  One row of the form. Key is opaque to the panel and echoed back on a
   --  change so the caller can map it to its own setting. For Choice and Buttons,
   --  Option_Values holds the tokens/ids and Option_Labels their display labels
   --  (parallel vectors). Number uses Min/Max. Help is shown under the row while
   --  it is focused.
   type Field is record
      Key           : UString;
      Label         : UString;
      Kind          : Field_Kind := Section;
      Value         : UString;
      Option_Values : UString_Vectors.Vector;
      Option_Labels : UString_Vectors.Vector;
      Min           : Integer := 0;
      Max           : Integer := 0;
      Enabled       : Boolean := True;
      Help          : UString;
   end record;

   package Field_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Field);

   type Configuration is record
      Line_Height     : Positive := 20;
      Title           : UString;             --  panel heading
      Status          : UString;             --  a status/validation line at the foot
      Status_Is_Error : Boolean := False;    --  colour the status line as an error
   end record;

   type Panel is private;

   --  Replace the presentation configuration.
   procedure Set_Configuration (P : in out Panel; Config : Configuration);

   --  Replace the field list (keeping the focused row and scroll where possible).
   procedure Set_Fields (P : in out Panel; Fields : Field_Vectors.Vector);

   --  Clear the focus, scroll and any pending change (e.g. when opening).
   procedure Reset (P : in out Panel);

   --  The Section fields act as tabs: the panel shows a segmented switcher of the
   --  section labels and renders only the active section's fields (plus any
   --  fields that precede the first Section, which stay always visible).

   --  How many Section fields there are (the number of tabs).
   function Section_Count (P : Panel) return Natural;

   --  The one-based ordinal of the currently shown section.
   function Active_Section (P : Panel) return Natural;

   --  Show the Ordinal-th section (clamped to 1 .. Section_Count), moving focus
   --  to its first focusable field and resetting the scroll.
   procedure Set_Active_Section (P : in out Panel; Ordinal : Natural);

   --  Move keyboard focus by Delta_Rows over the focusable (non-Section) fields,
   --  clamped. Produces no change.
   procedure Move_Focus (P : in out Panel; Delta_Rows : Integer);

   --  Advance/retreat the focused Toggle or Choice to the next/previous value,
   --  or step a focused Number. Emits Value_Changed.
   procedure Cycle_Choice (P : in out Panel; Forward : Boolean);
   procedure Step_Number (P : in out Panel; Up : Boolean);

   --  Replace the whole value of the focused Text field (the caller does the text
   --  editing). Emits Value_Changed. A no-op unless a Text field is focused.
   procedure Set_Focused_Value (P : in out Panel; Text : String);

   --  Scroll the content by whole rows (positive scrolls down).
   procedure Scroll (P : in out Panel; Lines : Integer);

   --  Hit-test a window coordinate using the most recent render: focus a row,
   --  flip a toggle, pick a choice cell, step a number, or press a button. Emits
   --  the corresponding change.
   --
   --  @return True when a hit landed on the panel (focus and/or a change).
   function Click (P : in out Panel; X : Integer; Y : Integer) return Boolean;

   --  The kind / key / value of the focused field (Section and "" when none).
   function Focused_Kind (P : Panel) return Field_Kind;
   function Focused_Key (P : Panel) return String;
   function Focused_Value (P : Panel) return String;

   --  The change produced by the most recent input, if any. A change kind of
   --  Value_Changed carries the field Key and its new Value; Button_Pressed
   --  carries the buttons-row Key and the pressed button's id in Value. Reading a
   --  change clears it.
   type Change_Kind is (No_Change, Value_Changed, Button_Pressed);
   type Change is record
      Kind  : Change_Kind := No_Change;
      Key   : UString;
      Value : UString;
   end record;

   function Take_Change (P : in out Panel) return Change;

   --  Render the panel within a region and remember the row layout for Click.
   --
   --  Emits the panel (drop shadow, background, border, title, close button), a
   --  widget per field (toggle / segmented choice / number stepper / text field /
   --  button row), section headers, the focused field's help and the status line,
   --  and the scrollbar, plus one accessibility node per element. The caller
   --  submits Rectangles/Text and owns the accessibility nodes.
   --
   --  @param P Panel to render (updates its cached row layout + scroll clamp).
   --  @param Region_X Left edge of the panel region in pixels.
   --  @param Region_Y Top edge of the panel region in pixels.
   --  @param Region_Width Panel region width in pixels.
   --  @param Region_Height Panel region height in pixels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Focused Whether the panel has keyboard focus.
   --  @param Hover_X Cursor X in pixels (negative when off-window).
   --  @param Hover_Y Cursor Y in pixels.
   --  @param Rectangles Out: rectangle commands.
   --  @param Text Out: text commands.
   --  @param Accessibility Out: accessibility nodes.
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
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector);

private

   --  What a cached hit rectangle does when clicked.
   type Hit_Kind is
     (Hit_Focus,        --  focus this field (Field_Index)
      Hit_Toggle,       --  flip the toggle (Field_Index)
      Hit_Choice,       --  pick option Option of a Choice (Field_Index)
      Hit_Step_Down,    --  decrement a Number (Field_Index)
      Hit_Step_Up,      --  increment a Number (Field_Index)
      Hit_Button,       --  press button Option of a Buttons row (Field_Index)
      Hit_Tab);         --  switch to section Option (the section-switcher cells)

   type Hit_Rect is record
      Kind        : Hit_Kind := Hit_Focus;
      Field_Index : Natural  := 0;   --  1-based index into Fields (0 for Hit_Close)
      Option      : Natural  := 0;   --  choice cell / button index (1-based)
      X, Y, W, H  : Natural  := 0;
   end record;

   package Hit_Rect_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Hit_Rect);

   type Panel is record
      Config        : Configuration;
      Fields        : Field_Vectors.Vector;
      Focused       : Natural := 0;   --  1-based index into Fields, 0 = none
      Active        : Natural := 1;   --  1-based active section (tab) ordinal
      Offset        : Natural := 0;   --  scroll offset in rows
      Content_Rows  : Natural := 0;   --  total rows from the last render
      Visible_Rows  : Natural := 0;   --  visible rows from the last render
      Hits          : Hit_Rect_Vectors.Vector;   --  from the last Build_Frame
      Pending       : Change;
   end record;

end Guikit.Settings_Panel;
