with Ada.Containers.Indefinite_Vectors;

with Textrender;

with Guikit.Draw;

--  Text rendering for guikit apps: load a monospace primary font plus a fallback
--  chain into a shared glyph atlas, then rasterize a frame's text commands into
--  positioned glyph quads the Vulkan backend uploads. This is the toolkit's text
--  layer -- an application supplies the font paths and the text commands and gets
--  back a Guikit.Draw.Text_Render_Result; per-glyph fallback, monospace cell
--  advance, box-fitted scaling and pixel snapping all happen here.
package Guikit.Text is

   package Font_Path_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   --  A loaded text renderer: a primary font, its fallback chain, and the shared
   --  glyph atlas. Limited because it owns a Textrender renderer.
   type Renderer is limited private;

   --  Whether Initialize has loaded a primary font into R.
   function Loaded (R : Renderer) return Boolean;

   --  Load the monospace primary font and append the fallback chain into the
   --  same shared atlas. A missing or unloadable fallback is non-fatal (the
   --  primary already renders and the remaining fallbacks still apply).
   --
   --  @param R Renderer to (re)initialize.
   --  @param Font_Path Monospace primary font path; "" fails.
   --  @param Fallback_Paths Fallback font paths, consulted in order.
   --  @param Pixel_Size Rasterization pixel size.
   --  @param Cell_Width Monospace cell width in pixels.
   --  @param Cell_Height Monospace cell height (the text line height).
   --  @param Atlas_Width Glyph atlas width in pixels.
   --  @param Atlas_Height Glyph atlas height in pixels.
   --  @return The load status.
   function Initialize
     (R              : in out Renderer;
      Font_Path      : String;
      Fallback_Paths : Font_Path_Vectors.Vector;
      Pixel_Size     : Positive := 16;
      Cell_Width     : Positive := 10;
      Cell_Height    : Positive := 20;
      Atlas_Width    : Positive := 1024;
      Atlas_Height   : Positive := 1024)
      return Guikit.Draw.Text_Render_Status;

   --  Rasterize a frame's text into glyph quads and atlas upload data.
   --
   --  Commands become the primary glyph layer and Overlay the overlay layer.
   --  Each command's glyphs advance one monospace cell per display unit, clipped
   --  to the command's box; Scale_To_Box fits and centres a single glyph in its
   --  box; Truncated/Italic follow the command's flags. Missing glyphs fall back
   --  to a '?' and are counted.
   --
   --  @param R A loaded renderer.
   --  @param Commands The primary text commands.
   --  @param Overlay The overlay text commands.
   --  @return Glyph quads plus the shared atlas the backend uploads.
   function Build_Glyphs
     (R        : in out Renderer;
      Commands : Guikit.Draw.Text_Command_Vectors.Vector;
      Overlay  : Guikit.Draw.Text_Command_Vectors.Vector)
      return Guikit.Draw.Text_Render_Result;

private

   type Renderer is limited record
      Backend      : Textrender.Renderer;
      Is_Loaded    : Boolean := False;
      Cell_Width   : Positive := 10;
      Cell_Height  : Positive := 20;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024;
   end record;

end Guikit.Text;
