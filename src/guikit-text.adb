with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Interfaces;

with Guikit.Bidi;
with Guikit.Layout;
with Guikit.Shared_Bytes;
with Guikit.Utf8;

package body Guikit.Text is

   use type Ada.Containers.Count_Type;
   use type Textrender.Status_Code;

   --  The last atlas version handed out, across every renderer, so a version
   --  names one atlas content however renderers are reloaded.
   Last_Atlas_Version : Natural := 0;

   function New_Atlas_Version return Natural is
   begin
      Last_Atlas_Version := (if Last_Atlas_Version = Natural'Last then 1 else Last_Atlas_Version + 1);
      return Last_Atlas_Version;
   end New_Atlas_Version;

   function Loaded (R : Renderer) return Boolean is (R.Is_Loaded);

   --  The Arabic presentation forms, and the forms between them (variation
   --  selectors and the like), which are answered for alike.
   subtype Form_Codepoint is Natural range 16#FB50# .. 16#FEFF#;

   function Is_Form (Codepoint : Natural) return Boolean is
     (Codepoint in 16#FB50# .. 16#FDFF# | 16#FE70# .. 16#FEFF#);

   type Form_Coverage is array (Form_Codepoint) of Boolean
     with Pack;

   --  Which presentation forms the fonts last loaded draw (Can_Draw_Form).
   protected Loaded_Forms is

      procedure Set (Coverage : Form_Coverage);

      function Draws (Codepoint : Form_Codepoint) return Boolean;

   private
      Known : Form_Coverage := [others => True];
   end Loaded_Forms;

   protected body Loaded_Forms is

      procedure Set (Coverage : Form_Coverage) is
      begin
         Known := Coverage;
      end Set;

      function Draws (Codepoint : Form_Codepoint) return Boolean is (Known (Codepoint));

   end Loaded_Forms;

   function Can_Draw_Form (Codepoint : Natural) return Boolean is
     (not Is_Form (Codepoint) or else Loaded_Forms.Draws (Codepoint));

   --  Record which presentation forms R's fonts draw, for Can_Draw_Form.
   procedure Record_Forms (R : Renderer) is
      Coverage : Form_Coverage := [others => True];
   begin
      for Codepoint in Form_Codepoint loop
         if Is_Form (Codepoint) then
            Coverage (Codepoint) := Textrender.Can_Draw (R.Backend, Codepoint);
         end if;
      end loop;
      Loaded_Forms.Set (Coverage);
   end Record_Forms;

   function Atlas_Version (R : Renderer) return Natural is (R.Atlas_Version);

   --  How tall the glyph atlas may grow: four times its usual height, which
   --  at its usual 1024 columns is the 4 MiB the Vulkan backend uploads
   --  (Guikit.Draw.Max_Atlas_Bytes). Past that the atlas is emptied
   --  and refilled instead.
   Atlas_Max_Height : constant := 4_096;

   function Initialize
     (R              : in out Renderer;
      Font_Path      : String;
      Fallback_Paths : Font_Path_Vectors.Vector;
      Pixel_Size     : Positive := 16;
      Cell_Width     : Positive := 10;
      Cell_Height    : Positive := 20;
      Atlas_Width    : Positive := 1024;
      Atlas_Height   : Positive := 1024)
      return Guikit.Draw.Text_Render_Status
   is
      Status : Textrender.Status_Code;
   begin
      R.Is_Loaded := False;

      if Font_Path = "" then
         Textrender.Reset (R.Backend);
         return Guikit.Draw.Text_Render_Font_Load_Failed;
      end if;

      Status :=
        Textrender.Load_Font
          (R            => R.Backend,
           Path         => Font_Path,
           Pixel_Size   => Pixel_Size,
           Cell_Width   => Cell_Width,
           Cell_Height  => Cell_Height,
           Atlas_Width  => Atlas_Width,
           Atlas_Height => Atlas_Height);
      if Status /= Textrender.Success then
         return Guikit.Draw.Text_Render_Font_Load_Failed;
      end if;

      --  Best-effort: a missing or unloadable fallback is non-fatal, so the
      --  per-font status is intentionally discarded.
      for Path of Fallback_Paths loop
         declare
            Added : constant Textrender.Status_Code := Textrender.Add_Fallback_Font (R.Backend, Path);
            pragma Unreferenced (Added);
         begin
            null;
         end;
      end loop;

      --  A screen of text in many scripts outgrows any fixed atlas; let it
      --  grow taller rather than drop glyphs, and once it is as tall as it
      --  may be, empty it for the glyphs asked for now. Build_Glyphs starts a
      --  frame over when that happens partway through it.
      Textrender.Set_Atlas_Growth (R.Backend, Max_Height => Atlas_Max_Height);
      Textrender.Set_Atlas_Eviction (R.Backend, Enabled => True);
      --  Colour pictures are copied out of their sheet as each is drawn, so a
      --  full sheet can simply be emptied rather than leave emoji out.
      Textrender.Set_Colour_Sheet_Eviction (R.Backend, Enabled => True);

      Record_Forms (R);
      R.Is_Loaded    := True;
      R.Atlas_Version := New_Atlas_Version;
      R.Cell_Width   := Cell_Width;
      R.Cell_Height  := Cell_Height;
      R.Atlas_Width  := Atlas_Width;
      R.Atlas_Height := Atlas_Height;
      return Guikit.Draw.Text_Render_Success;
   end Initialize;

   procedure Set_Image_Decoder
     (R      : in out Renderer;
      Extent : Textrender.Image_Extent_Reader;
      Decode : Textrender.Image_Decoder) is
   begin
      Textrender.Set_Image_Decoder (R.Backend, Extent, Decode);
   end Set_Image_Decoder;

   package Codepoint_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Natural);

   function Build_Glyphs
     (R        : in out Renderer;
      Commands : Guikit.Draw.Text_Command_Vectors.Vector;
      Overlay  : Guikit.Draw.Text_Command_Vectors.Vector)
      return Guikit.Draw.Text_Render_Result is separate;

end Guikit.Text;
