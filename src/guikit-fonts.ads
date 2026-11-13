with Guikit.Text;

--  Font discovery for guikit apps: the monospace primary and the per-glyph
--  fallback chain an application hands Guikit.Text.Initialize. One list of
--  known font locations (Linux paths, and file names looked for in the host's
--  font folders on Windows and macOS), one loadability test (the font must
--  load and draw ordinary text, or be a colour emoji font with the glyphs it
--  exists for), and one coverage score for picking the broadest font a folder
--  scan turns up when no known one is present.
--
--  Where the host keeps its fonts is the caller's to say: an application with
--  a platform layer passes its own folders (on Windows the Fonts known folder
--  need not be C:\Windows\Fonts); Default_Font_Directories is the portable
--  guess from the environment for one without.
package Guikit.Fonts is

   subtype Path_List is Guikit.Text.Font_Path_Vectors.Vector;

   --  The host's font folders as the environment tells them, the system's
   --  first and then the current user's, each only if it exists: on Windows
   --  %WINDIR%\Fonts and %LOCALAPPDATA%\Microsoft\Windows\Fonts; on macOS
   --  /System/Library/Fonts, /Library/Fonts and ~/Library/Fonts; elsewhere
   --  /usr/share/fonts, /usr/local/share/fonts, $XDG_DATA_HOME/fonts (else
   --  ~/.local/share/fonts) and ~/.fonts.
   --
   --  @return The existing font folders, each once.
   function Default_Font_Directories return Path_List;

   --  Whether Path is a font the text renderer can use: an ordinary file
   --  that loads and draws an ASCII sample and '?', or a colour emoji font
   --  (bitmap or layered) that has the colour glyphs it exists for. Faces the
   --  renderer is known to mis-draw are refused.
   --
   --  @param Path Font file path.
   --  @return True when the renderer can use it.
   function Is_Loadable_Font (Path : String) return Boolean;

   --  The available font best suited for broad text, as the monospace primary
   --  of a frame laid out in fixed cells: Override when it loads, else the
   --  first known monospace location that loads, else the loadable font with
   --  the broadest script coverage found scanning Font_Directories. The answer
   --  is remembered for the same Override and folders.
   --
   --  @param Font_Directories The host's font folders, system first.
   --  @param Override An explicit font path (from the application's own
   --    setting or environment variable), or "" for none.
   --  @return Font path, or "" when no usable font is present.
   function Default_Font_Path
     (Font_Directories : Path_List := Default_Font_Directories;
      Override         : String := "")
      return String;

   --  The ordered per-glyph fallback chain to load after Primary: monospace
   --  symbols, broad proportional symbols, CJK, broad international faces,
   --  and the colour emoji fonts last (an emoji font maps arrows, stars and
   --  check marks too, and ahead of the text fonts would capture them). Only
   --  fonts that load are returned, each once, never Primary.
   --
   --  @param Primary The primary font path (left out of the chain).
   --  @param Font_Directories The host's font folders, system first.
   --  @param Colour_Bitmaps Whether the caller installs an image decoder
   --    (Guikit.Text.Set_Image_Decoder): bitmap emoji fonts hold PNGs and are
   --    only listed when they can be decoded; layered (COLR) ones always are.
   --  @return Ordered, de-duplicated fallback font paths.
   function Fallback_Font_Paths
     (Primary          : String;
      Font_Directories : Path_List := Default_Font_Directories;
      Colour_Bitmaps   : Boolean := False)
      return Path_List;

end Guikit.Fonts;
