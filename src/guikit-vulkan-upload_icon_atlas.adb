separate (Guikit.Vulkan)
function Upload_Icon_Atlas
  (Renderer : in out Vulkan_Renderer;
   Batch    : Submission_Batch)
   return Boolean
is
   Texture : Atlas_Texture renames Renderer.Atlases (Icon_Atlas);
   Upload_Format : constant Atlas_Texture_Format := Icon_Upload_Texture_Format (Batch);
   Bytes : constant Natural := Batch.Icon_Atlas_Bytes;
   Needs_New_Texture : constant Boolean :=
     not Texture.Texture_Live
     or else Texture.Width /= Batch.Icon_Atlas_Width
     or else Texture.Height /= Batch.Icon_Atlas_Height
     or else Texture.Format /= Upload_Format;

   --  The batch's icon atlas pixels into the staging memory.
   procedure Fill (Target : Byte_Array_Conversions.Object_Pointer) is
   begin
      for Index in 1 .. Bytes loop
         Target.all (Index) := Batch.Icon_Atlas_Pixels.Element (Index);
      end loop;
   end Fill;
begin
   if Texture.Texture_Live
     and then (not Batch.Icon_Atlas_Dirty
               or else (Length (Batch.Icon_Atlas_Signature) > 0
                        and then Batch.Icon_Atlas_Signature = Renderer.Uploaded_Icon_Signature
                        and then not Needs_New_Texture))
   then
      return True;
   elsif not Batch.Icon_Atlas_Dirty
     or else Upload_Format = Atlas_Texture_None
     or else Batch.Icon_Atlas_Width = 0
     or else Batch.Icon_Atlas_Height = 0
     or else Bytes = 0
     or else Bytes > Max_Atlas_Bytes
     or else Guikit.Shared_Bytes.Length (Batch.Icon_Atlas_Pixels) /= Bytes
   then
      return False;
   end if;

   if not Atlas_Uploads.Upload
     (Renderer, Icon_Atlas, Batch.Icon_Atlas_Width, Batch.Icon_Atlas_Height, Upload_Format, Bytes, Fill'Access)
   then
      return False;
   end if;

   Renderer.Uploaded_Icon_Signature := Batch.Icon_Atlas_Signature;
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Upload_Icon_Atlas;
