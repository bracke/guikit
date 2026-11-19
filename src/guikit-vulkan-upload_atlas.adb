separate (Guikit.Vulkan)
function Upload_Atlas
  (Renderer : in out Vulkan_Renderer;
   Batch    : Submission_Batch)
   return Boolean
is
   Texture : Atlas_Texture renames Renderer.Atlases (Text_Atlas);
   Use_Batch_Atlas : constant Boolean :=
     Batch.Text_Atlas_Used
     and then
       (Batch.Atlas_Version /= Renderer.Uploaded_Atlas_Version
        or else not Texture.Texture_Live
        or else Texture.Width /= Batch.Atlas_Width
        or else Texture.Height /= Batch.Atlas_Height
        or else Texture.Format /= Atlas_Texture_R8);
   --  Without text, the texture only has to be valid (a 1x1 stand-in):
   --  icons are drawn from their own texture (Upload_Icon_Atlas).
   Upload_Format : constant Atlas_Texture_Format :=
     (if Use_Batch_Atlas then Atlas_Texture_R8 else Atlas_Texture_None);
   Actual_Width  : constant Natural := (if Use_Batch_Atlas then Batch.Atlas_Width else 1);
   Actual_Height : constant Natural := (if Use_Batch_Atlas then Batch.Atlas_Height else 1);
   Bytes         : constant Natural := (if Use_Batch_Atlas then Batch.Atlas_Bytes else 1);
   Pixel_Address : constant System.Address :=
     (if Use_Batch_Atlas then Batch.Atlas_Pixels else Fallback_Atlas_Pixel'Address);

   --  The atlas pixels, one coverage byte each, into the staging memory.
   procedure Fill (Target : Byte_Array_Conversions.Object_Pointer) is
      Source : constant Byte_Array_Conversions.Object_Pointer := Byte_Array_Conversions.To_Pointer (Pixel_Address);
   begin
      for Index in 1 .. Bytes loop
         Target.all (Index) := Source.all (Index);
      end loop;
   end Fill;
begin
   if not Use_Batch_Atlas and then Texture.Texture_Live then
      return True;
   elsif Pixel_Address = System.Null_Address
     or else Actual_Width = 0
     or else Actual_Height = 0
     or else Bytes = 0
     or else Bytes > Max_Atlas_Bytes
   then
      return False;
   end if;

   if not Atlas_Uploads.Upload (Renderer, Text_Atlas, Actual_Width, Actual_Height, Upload_Format, Bytes, Fill'Access)
   then
      return False;
   end if;

   --  The text atlas texture now holds this version, or icons (version 0
   --  is never handed out, so the next text frame uploads again).
   Renderer.Uploaded_Atlas_Version := (if Use_Batch_Atlas then Batch.Atlas_Version else 0);
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Upload_Atlas;
