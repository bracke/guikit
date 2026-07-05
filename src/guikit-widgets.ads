with Guikit.Draw;

--  Domain-free drawing of simple, self-contained widgets.
--
--  Each procedure draws pixels for one visual widget by appending draw
--  commands to caller-supplied Guikit.Draw command vectors. Everything a
--  widget needs -- geometry (in pixels), clip bounds, and semantic colors --
--  is passed explicitly, so this package has no dependency on any file-manager
--  domain package (model, settings, localization, rendering, ...). Callers own
--  all policy: they compute geometry, resolve theme colors, decide visibility,
--  and register hit regions or accessibility nodes. The widget only emits the
--  rectangles and text.
--
--  Coordinates and sizes are window pixels. Clip_Width and Clip_Height give
--  the drawable window bounds; each emitted rectangle or text run is clipped to
--  them and dropped when it would be empty, matching the renderer's primitives.
package Guikit.Widgets is

   --  Draw a focus ring: a one-pixel border around the given box, plus a
   --  second border one pixel outside it when the box is not flush against the
   --  top-left window edge. Emits into a base-layer rectangle vector.
   --
   --  @param Rectangles Rectangle command vector to append the ring to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Ring left edge in pixels.
   --  @param Y Ring top edge in pixels.
   --  @param Width Ring width in pixels; nothing is drawn when zero.
   --  @param Height Ring height in pixels; nothing is drawn when zero.
   --  @param Color Ring color.
   procedure Draw_Focus_Ring
     (Rectangles  : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Guikit.Draw.Render_Color);

   --  Draw a drop shadow along the bottom and right edges of a box: a
   --  horizontal band below it and a vertical band to its right, both offset by
   --  three pixels.
   --
   --  @param Rectangles Rectangle command vector to append the shadow to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Box left edge in pixels.
   --  @param Y Box top edge in pixels.
   --  @param Width Box width in pixels; nothing is drawn when zero.
   --  @param Height Box height in pixels; nothing is drawn when zero.
   --  @param Color Shadow color.
   procedure Draw_Drop_Shadow
     (Rectangles  : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Guikit.Draw.Render_Color);

   --  Draw a panel close button: a filled, bordered square with the close
   --  glyph centered inside it. The rectangles and the glyph are appended to
   --  the supplied vectors (pass the base or the overlay vectors to target the
   --  desired layer). The caller resolves the fill color from hover/press
   --  state, computes the glyph geometry and its visibility, and registers the
   --  accessibility node.
   --
   --  @param Rectangles Rectangle command vector for the box (fill + border).
   --  @param Text Text command vector for the glyph.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Button_X Button left edge in pixels.
   --  @param Button_Y Button top edge in pixels.
   --  @param Button_Width Button width in pixels.
   --  @param Button_Height Button height in pixels.
   --  @param Fill_Color Button background color.
   --  @param Border_Color Button border color.
   --  @param Glyph_X Glyph cell left edge in pixels.
   --  @param Glyph_Y Glyph cell top edge in pixels.
   --  @param Glyph_Width Glyph cell width in pixels.
   --  @param Glyph_Height Glyph cell height in pixels.
   --  @param Glyph Close glyph text.
   --  @param Glyph_Color Glyph color.
   --  @param Show_Glyph When False, the glyph is not drawn (the box still is).
   procedure Draw_Close_Button
     (Rectangles    : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Button_X      : Natural;
      Button_Y      : Natural;
      Button_Width  : Natural;
      Button_Height : Natural;
      Fill_Color    : Guikit.Draw.Render_Color;
      Border_Color  : Guikit.Draw.Render_Color;
      Glyph_X       : Natural;
      Glyph_Y       : Natural;
      Glyph_Width   : Natural;
      Glyph_Height  : Natural;
      Glyph         : Guikit.Draw.UString;
      Glyph_Color   : Guikit.Draw.Render_Color;
      Show_Glyph    : Boolean);

   --  One cell's label for a segmented selector: the display text (already
   --  localized and fitted to the cell width by the caller) and whether that
   --  fitting truncated it. An empty Text draws no label for that cell -- the
   --  fill and border still draw -- letting the caller suppress a label that is
   --  fully clipped or covered by an overlay while keeping the cell box.
   type Segment_Label is record
      Text      : Guikit.Draw.UString;
      Truncated : Boolean := False;
   end record;

   --  One-based row of segment labels; its length is the number of cells drawn.
   type Segment_Label_Array is array (Positive range <>) of Segment_Label;

   --  Draw a horizontal segmented cycling selector: a row of cells, each a
   --  filled, bordered box with a left-aligned label inset by Padding. Cell
   --  widths come from Content_Width / Cell_Count; the cell whose zero-based
   --  offset equals Cell_Count - 1 absorbs the integer-division remainder so a
   --  full row of cells spans exactly Content_Width. Cell_Count is the grid
   --  divisor, which may exceed Labels'Length: a caller that draws fewer cells
   --  than the divisor (so no drawn cell is the remainder cell) leaves the
   --  cells at the uniform Content_Width / Cell_Count width. The cell whose
   --  one-based index equals Active_Index is filled with Active_Color; the rest
   --  with Inactive_Color (Active_Index = 0 draws none active). Cells of zero
   --  width are skipped. The caller resolves the labels, the active index, and
   --  the colors, and registers any hit regions; the widget only emits pixels.
   --
   --  @param Rectangles Rectangle command vector for the fills and borders.
   --  @param Text Text command vector for the labels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Row left edge in pixels.
   --  @param Box_Y Top edge of each cell's fill and border in pixels.
   --  @param Label_Y Top edge of each cell's label in pixels.
   --  @param Content_Width Total row width in pixels; cell width is this over
   --    Cell_Count and nothing is drawn when zero.
   --  @param Cell_Count Grid divisor for the cell width and remainder cell.
   --  @param Height Height of each cell and its label in pixels.
   --  @param Labels One label per drawn cell, at offsets 0 .. Labels'Length - 1.
   --  @param Active_Index One-based index of the active cell, or 0 for none.
   --  @param Active_Color Fill color of the active cell.
   --  @param Inactive_Color Fill color of the inactive cells.
   --  @param Border_Color Cell border color.
   --  @param Label_Color Label text color.
   --  @param Padding Left inset of each label from its cell edge in pixels.
   procedure Draw_Segmented
     (Rectangles     : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text           : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width     : Natural;
      Clip_Height    : Natural;
      X              : Natural;
      Box_Y          : Natural;
      Label_Y        : Natural;
      Content_Width  : Natural;
      Cell_Count     : Natural;
      Height         : Natural;
      Labels         : Segment_Label_Array;
      Active_Index   : Natural;
      Active_Color   : Guikit.Draw.Render_Color;
      Inactive_Color : Guikit.Draw.Render_Color;
      Border_Color   : Guikit.Draw.Render_Color;
      Label_Color    : Guikit.Draw.Render_Color;
      Padding        : Natural);

   --  Draw a vertical scrollbar: a full-height track rectangle with a thumb
   --  rectangle painted on top of it, the thumb outlined by a one-pixel border
   --  and -- when it is at least seven pixels tall and the track is wide enough
   --  for a grip -- three horizontal grip lines centered on the thumb. The
   --  caller computes the track and thumb geometry from the scroll offset and
   --  content height, resolves the theme colors, decides visibility, and
   --  registers any drag hit region; the widget only emits the rectangles.
   --
   --  @param Rectangles Rectangle command vector to append the scrollbar to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Track_X Left edge of the track and thumb in pixels.
   --  @param Track_Y Track top edge in pixels.
   --  @param Track_Width Width of both the track and the thumb in pixels.
   --  @param Track_Height Track height in pixels.
   --  @param Thumb_Y Thumb top edge in pixels.
   --  @param Thumb_Height Thumb height in pixels.
   --  @param Track_Color Track fill color; also used for the thumb's border.
   --  @param Thumb_Color Thumb fill color.
   --  @param Grip_Color Color of the three grip lines.
   procedure Draw_Scrollbar
     (Rectangles   : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      Track_X      : Natural;
      Track_Y      : Natural;
      Track_Width  : Natural;
      Track_Height : Natural;
      Thumb_Y      : Natural;
      Thumb_Height : Natural;
      Track_Color  : Guikit.Draw.Render_Color;
      Thumb_Color  : Guikit.Draw.Render_Color;
      Grip_Color   : Guikit.Draw.Render_Color);

   --  Draw a floating menu panel's chrome: a filled body rectangle with a
   --  one-pixel border, emitted as the fill followed by the top, bottom, left
   --  and right border edges in that order. The bottom edge is skipped when
   --  Height is zero and the right edge when Width is zero, so a degenerate
   --  panel still paints its fill and the top/left edges. A drop shadow, if
   --  any, is a separate Draw_Drop_Shadow call in the caller. The caller
   --  computes the geometry, resolves the theme colors and registers the
   --  panel's accessibility node; the widget only emits the rectangles.
   --
   --  @param Rectangles Rectangle command vector for the fill and border.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Panel left edge in pixels.
   --  @param Y Panel top edge in pixels.
   --  @param Width Panel width in pixels.
   --  @param Height Panel height in pixels.
   --  @param Fill_Color Panel background color.
   --  @param Border_Color Panel border color.
   procedure Draw_Menu_Panel
     (Rectangles   : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      X            : Natural;
      Y            : Natural;
      Width        : Natural;
      Height       : Natural;
      Fill_Color   : Guikit.Draw.Render_Color;
      Border_Color : Guikit.Draw.Render_Color);

   --  Draw an editable input field's box chrome: a filled background rectangle
   --  with a one-pixel border, emitted as the fill followed by the top, left,
   --  bottom and right border edges in that order. Nothing is drawn when Width
   --  or Height is zero. This differs from Draw_Menu_Panel: the border edges are
   --  emitted top/left/bottom/right (not top/bottom/left/right) and a degenerate
   --  box paints nothing, matching the renderer's inline field boxes. The
   --  field's text, placeholder, caret, focus ring, and any adornments (favorite
   --  star, filter scope chip) are separate caller draws; the widget only emits
   --  the background fill and the border.
   --
   --  @param Rectangles Rectangle command vector for the fill and border.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Field left edge in pixels.
   --  @param Y Field top edge in pixels.
   --  @param Width Field width in pixels; nothing is drawn when zero.
   --  @param Height Field height in pixels; nothing is drawn when zero.
   --  @param Fill_Color Field background color.
   --  @param Border_Color Field border color.
   procedure Draw_Input_Field
     (Rectangles   : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      X            : Natural;
      Y            : Natural;
      Width        : Natural;
      Height       : Natural;
      Fill_Color   : Guikit.Draw.Render_Color;
      Border_Color : Guikit.Draw.Render_Color);

   --  Draw one row of a floating menu panel: either a command row or a group
   --  separator, selected by Is_Separator.
   --
   --  For a command row (Is_Separator = False): when Highlight is set, a
   --  full-row highlight rectangle at (Row_X, Row_Y, Row_Width, Row_Height) is
   --  painted first, then the label. Label_Text is the already localized and
   --  fitted label (empty draws no label, e.g. when it clips to nothing);
   --  Label_Truncated flags whether the caller's fitting shortened it. The
   --  label box (Label_X, Label_Y, Label_Width, Label_Height) is clipped to the
   --  window and the label dropped when it would be empty.
   --
   --  For a separator row (Is_Separator = True): a single one-pixel-tall
   --  divider rectangle at (Separator_X, Separator_Y, Separator_Width) is drawn
   --  and every command-row parameter is ignored.
   --
   --  The caller owns all policy: which command a row holds, its enabled/hover
   --  state, the highlight color choice, label localization and fitting, the
   --  row geometry, and the per-row hit and accessibility registration; the
   --  widget only emits the rectangle and text.
   --
   --  @param Rectangles Rectangle command vector for the highlight or divider.
   --  @param Text Text command vector for the label.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Row_X Command-row highlight left edge in pixels.
   --  @param Row_Y Command-row highlight top edge in pixels.
   --  @param Row_Width Command-row highlight width in pixels.
   --  @param Row_Height Command-row highlight height in pixels.
   --  @param Is_Separator When True, draw the divider instead of a command row.
   --  @param Separator_X Divider left edge in pixels.
   --  @param Separator_Y Divider top edge in pixels.
   --  @param Separator_Width Divider width in pixels.
   --  @param Separator_Color Divider color.
   --  @param Highlight When True, paint the row highlight rectangle.
   --  @param Highlight_Color Row highlight color.
   --  @param Label_X Label box left edge in pixels.
   --  @param Label_Y Label box top edge in pixels.
   --  @param Label_Width Label box width in pixels.
   --  @param Label_Height Label box height in pixels.
   --  @param Label_Text Fitted label text; empty draws no label.
   --  @param Label_Truncated Whether the caller's fitting truncated the label.
   --  @param Label_Color Label text color.
   procedure Draw_Menu_Row
     (Rectangles      : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text            : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      Row_X           : Natural;
      Row_Y           : Natural;
      Row_Width       : Natural;
      Row_Height      : Natural;
      Is_Separator    : Boolean;
      Separator_X     : Natural;
      Separator_Y     : Natural;
      Separator_Width : Natural;
      Separator_Color : Guikit.Draw.Render_Color;
      Highlight       : Boolean;
      Highlight_Color : Guikit.Draw.Render_Color;
      Label_X         : Natural;
      Label_Y         : Natural;
      Label_Width     : Natural;
      Label_Height    : Natural;
      Label_Text      : Guikit.Draw.UString;
      Label_Truncated : Boolean;
      Label_Color     : Guikit.Draw.Render_Color);

   --  Draw one command-palette (searchable-list) result row: the row background,
   --  a left selection accent bar when Selected, and up to three pre-fitted text
   --  runs -- the label, an optional right-aligned shortcut sharing the label's
   --  line (its top and height are Label_Y and Label_Height), and an optional
   --  description on a second line at the label's left edge (Label_X). Each text
   --  run is dropped when its box clips to nothing or its text is empty. The
   --  caller owns the geometry, the state-to-colour choice, the label fitting,
   --  and the hit / accessibility registration; the widget only emits the
   --  rectangles and text.
   --
   --  @param Rectangles Rectangle command vector for the background and accent.
   --  @param Text Text command vector for the label, shortcut and description.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Row_X Row left edge in pixels.
   --  @param Row_Y Row top edge in pixels.
   --  @param Row_Width Row width in pixels.
   --  @param Row_Height Row height in pixels.
   --  @param Background_Color Row background fill colour.
   --  @param Selected When True, paint the left selection accent bar.
   --  @param Accent_Color Selection accent bar colour.
   --  @param Label_X Label box left edge (also the description's left edge).
   --  @param Label_Y Label box top edge (also the shortcut's top edge).
   --  @param Label_Width Label box width in pixels.
   --  @param Label_Height Label box height (also the shortcut's height).
   --  @param Label_Text Fitted label text; empty draws no label.
   --  @param Label_Truncated Whether the caller's fitting shortened the label.
   --  @param Label_Color Label text colour.
   --  @param Shortcut_X Shortcut box left edge in pixels.
   --  @param Shortcut_Width Shortcut box width; zero draws no shortcut.
   --  @param Shortcut_Text Fitted shortcut text.
   --  @param Shortcut_Truncated Whether the caller's fitting shortened it.
   --  @param Shortcut_Color Shortcut text colour.
   --  @param Description_Y Description box top edge in pixels.
   --  @param Description_Width Description box width; zero draws no description.
   --  @param Description_Height Description box height in pixels.
   --  @param Description_Text Fitted description text.
   --  @param Description_Truncated Whether the caller's fitting shortened it.
   --  @param Description_Color Description text colour.
   procedure Draw_Palette_Row
     (Rectangles            : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text                  : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width            : Natural;
      Clip_Height           : Natural;
      Row_X                 : Natural;
      Row_Y                 : Natural;
      Row_Width             : Natural;
      Row_Height            : Natural;
      Background_Color      : Guikit.Draw.Render_Color;
      Selected              : Boolean;
      Accent_Color          : Guikit.Draw.Render_Color;
      Label_X               : Natural;
      Label_Y               : Natural;
      Label_Width           : Natural;
      Label_Height          : Natural;
      Label_Text            : Guikit.Draw.UString;
      Label_Truncated       : Boolean;
      Label_Color           : Guikit.Draw.Render_Color;
      Shortcut_X            : Natural;
      Shortcut_Width        : Natural;
      Shortcut_Text         : Guikit.Draw.UString;
      Shortcut_Truncated    : Boolean;
      Shortcut_Color        : Guikit.Draw.Render_Color;
      Description_Y         : Natural;
      Description_Width     : Natural;
      Description_Height    : Natural;
      Description_Text      : Guikit.Draw.UString;
      Description_Truncated : Boolean;
      Description_Color     : Guikit.Draw.Render_Color);

   --  Draw a boolean toggle switch: a filled track (On_Color when set, else
   --  Off_Color) with a one-pixel border and a square knob pushed to the right
   --  when On and to the left when Off. The caller owns the geometry, the
   --  colours, and the hit / accessibility registration; the widget only emits
   --  the rectangles.
   --
   --  @param Rectangles Rectangle command vector for the track, border and knob.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Track left edge in pixels.
   --  @param Y Track top edge in pixels.
   --  @param Width Track width in pixels.
   --  @param Height Track height in pixels.
   --  @param Is_On Whether the toggle is set.
   --  @param On_Color Track fill when Is_On.
   --  @param Off_Color Track fill when not Is_On.
   --  @param Border_Color Track border colour.
   --  @param Knob_Color Knob fill colour.
   procedure Draw_Toggle
     (Rectangles   : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      X            : Natural;
      Y            : Natural;
      Width        : Natural;
      Height       : Natural;
      Is_On        : Boolean;
      On_Color     : Guikit.Draw.Render_Color;
      Off_Color    : Guikit.Draw.Render_Color;
      Border_Color : Guikit.Draw.Render_Color;
      Knob_Color   : Guikit.Draw.Render_Color);

   --  Draw a number stepper: a value box flanked by a decrement and an increment
   --  button. Each is a filled box with a one-pixel border and a padded, single-
   --  line label -- the current value, and the decrement/increment glyphs. All
   --  three boxes share Box_Y/Box_Height and all three labels share Text_Y/
   --  Text_Height (the label may sit lower than the box top). Labels are assumed
   --  to fit their boxes; the caller owns the geometry, colours and the hit /
   --  accessibility registration; the widget only emits the rectangles and text.
   --
   --  @param Rectangles Rectangle command vector for the three boxes.
   --  @param Text Text command vector for the value and glyph labels.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Box_Y Top edge of all three boxes in pixels.
   --  @param Box_Height Height of all three boxes in pixels.
   --  @param Text_Y Top edge of the labels in pixels.
   --  @param Text_Height Height of the label boxes in pixels.
   --  @param Padding Horizontal inset of each label within its box.
   --  @param Value_X Value box left edge in pixels.
   --  @param Value_Width Value box width in pixels.
   --  @param Value_Text Current value label.
   --  @param Down_X Decrement button left edge in pixels.
   --  @param Up_X Increment button left edge in pixels.
   --  @param Button_Width Width of each stepper button in pixels.
   --  @param Decrement_Label Decrement glyph (e.g. "-").
   --  @param Increment_Label Increment glyph (e.g. "+").
   --  @param Fill_Color Box background colour.
   --  @param Border_Color Box border colour.
   --  @param Text_Color Label text colour.
   procedure Draw_Number_Stepper
     (Rectangles      : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text            : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      Box_Y           : Natural;
      Box_Height      : Natural;
      Text_Y          : Natural;
      Text_Height     : Natural;
      Padding         : Natural;
      Value_X         : Natural;
      Value_Width     : Natural;
      Value_Text      : Guikit.Draw.UString;
      Down_X          : Natural;
      Up_X            : Natural;
      Button_Width    : Natural;
      Decrement_Label : Guikit.Draw.UString;
      Increment_Label : Guikit.Draw.UString;
      Fill_Color      : Guikit.Draw.Render_Color;
      Border_Color    : Guikit.Draw.Render_Color;
      Text_Color      : Guikit.Draw.Render_Color);

   --  Draw a labelled button: a filled box with a one-pixel border and a single
   --  pre-fitted label, horizontally inset by Padding and vertically centred
   --  (the label box is Label_Height tall). The caller resolves the fill colour
   --  for the button's state (idle/hover/press), fits and localises the label,
   --  and owns the hit / accessibility registration; the widget only emits the
   --  box and label. Nothing is drawn for the label when it clips to nothing or
   --  is empty.
   --
   --  @param Rectangles Rectangle command vector for the fill and border.
   --  @param Text Text command vector for the label.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Button left edge in pixels.
   --  @param Y Button top edge in pixels.
   --  @param Width Button width in pixels.
   --  @param Height Button height in pixels.
   --  @param Fill_Color Button background colour for its current state.
   --  @param Border_Color Button border colour.
   --  @param Padding Horizontal inset of the label within the button.
   --  @param Label_Text Fitted, localised label; empty draws no label.
   --  @param Label_Truncated Whether the caller's fitting shortened the label.
   --  @param Label_Height Height of the (vertically centred) label box.
   --  @param Label_Color Label text colour.
   procedure Draw_Button
     (Rectangles      : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text            : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      X               : Natural;
      Y               : Natural;
      Width           : Natural;
      Height          : Natural;
      Fill_Color      : Guikit.Draw.Render_Color;
      Border_Color    : Guikit.Draw.Render_Color;
      Padding         : Natural;
      Label_Text      : Guikit.Draw.UString;
      Label_Truncated : Boolean;
      Label_Height    : Natural;
      Label_Color     : Guikit.Draw.Render_Color);

   --  Draw a floating hover tooltip: a filled box with a one-pixel border and a
   --  single padded text label. The rectangles are emitted as the fill followed
   --  by the top, left, bottom and right border edges in that order, then the
   --  label. Label_Text is the already localized and fitted label (empty draws
   --  no label, e.g. when it clips to nothing); Label_Truncated flags whether
   --  the caller's fitting shortened it. The label box (Label_X, Label_Y,
   --  Label_Width, Label_Height) is clipped to the window and the label dropped
   --  when it would be empty. A drop shadow, if any, is a separate
   --  Draw_Drop_Shadow call in the caller. The caller owns all policy: hover
   --  detection, the tooltip text and which element it is for, the box geometry
   --  and placement, the colors, the label localization and fitting, and any
   --  hit-region or accessibility bookkeeping; the widget only emits the box and
   --  label.
   --
   --  @param Rectangles Rectangle command vector for the fill and border.
   --  @param Text Text command vector for the label.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param Box_X Tooltip box left edge in pixels.
   --  @param Box_Y Tooltip box top edge in pixels.
   --  @param Box_Width Tooltip box width in pixels.
   --  @param Box_Height Tooltip box height in pixels.
   --  @param Fill_Color Tooltip background color.
   --  @param Border_Color Tooltip border color.
   --  @param Label_X Label box left edge in pixels.
   --  @param Label_Y Label box top edge in pixels.
   --  @param Label_Width Label box width in pixels.
   --  @param Label_Height Label box height in pixels.
   --  @param Label_Text Fitted label text; empty draws no label.
   --  @param Label_Truncated Whether the caller's fitting truncated the label.
   --  @param Label_Color Label text color.
   procedure Draw_Tooltip
     (Rectangles      : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text            : in out Guikit.Draw.Text_Command_Vectors.Vector;
      Clip_Width      : Natural;
      Clip_Height     : Natural;
      Box_X           : Natural;
      Box_Y           : Natural;
      Box_Width       : Natural;
      Box_Height      : Natural;
      Fill_Color      : Guikit.Draw.Render_Color;
      Border_Color    : Guikit.Draw.Render_Color;
      Label_X         : Natural;
      Label_Y         : Natural;
      Label_Width     : Natural;
      Label_Height    : Natural;
      Label_Text      : Guikit.Draw.UString;
      Label_Truncated : Boolean;
      Label_Color     : Guikit.Draw.Render_Color);

   --  Draw a text insertion caret: a single filled vertical rectangle, clipped
   --  to the window and dropped when it would be empty. The caller owns all
   --  policy -- it computes the caret's x from the cursor position and the
   --  glyph advance, its height and vertical centering from the font, decides
   --  which input field is active, and whether the caret is currently visible
   --  (blink phase); the widget only emits the one rectangle.
   --
   --  @param Rectangles Rectangle command vector to append the caret to.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Caret left edge in pixels.
   --  @param Y Caret top edge in pixels.
   --  @param Width Caret width in pixels; nothing is drawn when zero.
   --  @param Height Caret height in pixels; nothing is drawn when zero.
   --  @param Color Caret color.
   procedure Draw_Caret
     (Rectangles  : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width  : Natural;
      Clip_Height : Natural;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Color       : Guikit.Draw.Render_Color);

   --  Draw a rubber-band (marquee) selection rectangle: a translucent fill
   --  followed by a one-pixel border around the same box, in that order. The
   --  caller owns all policy -- it computes the drag-region geometry from the
   --  drag anchor and the pointer, resolves the fill and border colors, and
   --  decides when a drag is in progress; the widget only emits the fill and
   --  border rectangles.
   --
   --  @param Rectangles Rectangle command vector for the fill and border.
   --  @param Clip_Width Drawable window width in pixels.
   --  @param Clip_Height Drawable window height in pixels.
   --  @param X Marquee left edge in pixels.
   --  @param Y Marquee top edge in pixels.
   --  @param Width Marquee width in pixels; nothing is drawn when zero.
   --  @param Height Marquee height in pixels; nothing is drawn when zero.
   --  @param Fill_Color Translucent fill color.
   --  @param Border_Color Border color.
   procedure Draw_Marquee
     (Rectangles   : in out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Clip_Width   : Natural;
      Clip_Height  : Natural;
      X            : Natural;
      Y            : Natural;
      Width        : Natural;
      Height       : Natural;
      Fill_Color   : Guikit.Draw.Render_Color;
      Border_Color : Guikit.Draw.Render_Color);

end Guikit.Widgets;
