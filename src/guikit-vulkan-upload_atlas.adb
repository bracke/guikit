separate (Guikit.Vulkan)
function Upload_Atlas
  (Renderer : in out Vulkan_Renderer;
   Batch    : Submission_Batch)
   return Boolean
is
   Use_Batch_Atlas : constant Boolean :=
     Batch.Text_Atlas_Used
     and then
       (Batch.Atlas_Version /= Renderer.Uploaded_Atlas_Version
        or else not Renderer.Atlas_Texture_Live
        or else Renderer.Atlas_Width_Value /= Batch.Atlas_Width
        or else Renderer.Atlas_Height_Value /= Batch.Atlas_Height
        or else Renderer.Atlas_Format_Value /= Atlas_Texture_R8);
   --  Without text, the texture only has to be valid (a 1x1 stand-in):
   --  icons are drawn from their own texture (Upload_Icon_Atlas).
   Upload_Format   : constant Atlas_Texture_Format :=
     (if Use_Batch_Atlas then Atlas_Texture_R8 else Atlas_Texture_None);
   Vulkan_Format   : constant Vk.Format_T :=
     (if Upload_Format = Atlas_Texture_RGBA8 then Format_R8G8B8A8_Srgb else Vk.FORMAT_R8_UNORM);
   Actual_Width : constant Natural :=
     (if Use_Batch_Atlas then Batch.Atlas_Width else 1);
   Actual_Height : constant Natural :=
     (if Use_Batch_Atlas then Batch.Atlas_Height else 1);
   Bytes : constant Natural :=
     (if Use_Batch_Atlas then Batch.Atlas_Bytes else 1);
   Pixel_Address : constant System.Address :=
     (if Use_Batch_Atlas then Batch.Atlas_Pixels else Fallback_Atlas_Pixel'Address);
   Needs_New_Texture : constant Boolean :=
     not Renderer.Atlas_Texture_Live
     or else Renderer.Atlas_Width_Value /= Actual_Width
     or else Renderer.Atlas_Height_Value /= Actual_Height
     or else Renderer.Atlas_Format_Value /= Upload_Format;

   --  Destroy the atlas texture the renderer has, so a new one can take its
   --  place.
   procedure Release_Atlas_Texture is
   begin
      if Renderer.Atlas_View /= System.Null_Address then
         Vk.Destroy_Image_View (Renderer.Device, Renderer.Atlas_View, System.Null_Address);
         Renderer.Atlas_View := System.Null_Address;
      end if;

      if Renderer.Atlas_Sampler /= System.Null_Address then
         Vk.Destroy_Sampler (Renderer.Device, Renderer.Atlas_Sampler, System.Null_Address);
         Renderer.Atlas_Sampler := System.Null_Address;
      end if;

      if Renderer.Atlas_Image /= System.Null_Address then
         Vk.Destroy_Image (Renderer.Device, Renderer.Atlas_Image, System.Null_Address);
         Renderer.Atlas_Image := System.Null_Address;
      end if;

      if Renderer.Atlas_Memory /= System.Null_Address then
         Vk.Free_Memory (Renderer.Device, Renderer.Atlas_Memory, System.Null_Address);
         Renderer.Atlas_Memory := System.Null_Address;
      end if;

      Renderer.Atlas_Texture_Live := False;
      Renderer.Atlas_Initialized := False;
   end Release_Atlas_Texture;

   --  Create the atlas image, its memory, view and sampler at the size and
   --  format this upload needs, and hand them to the renderer. False, with
   --  nothing left behind, when any of them cannot be made.
   function Create_Atlas_Texture return Boolean is
      Image_Info : aliased Vk.Image_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         image_Type               => Vk.IMAGE_TYPE_2D,
         format                   => Vulkan_Format,
         extent                   =>
           (width  => Interfaces.Unsigned_32 (Actual_Width),
            height => Interfaces.Unsigned_32 (Actual_Height),
            depth  => 1),
         mip_Levels               => 1,
         array_Layers             => 1,
         samples                  => Vk.SAMPLE_COUNT_1_BIT,
         tiling                   => Vk.IMAGE_TILING_OPTIMAL,
         usage                    => Vk.IMAGE_USAGE_TRANSFER_DST_BIT or Vk.IMAGE_USAGE_SAMPLED_BIT,
         sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices   => System.Null_Address,
         initial_Layout           => Vk.IMAGE_LAYOUT_UNDEFINED);
      Image_Handle : aliased Vk.Image_T := System.Null_Address;
      Requirements : aliased Vk.Memory_Requirements_T;
      Memory_Type  : Interfaces.Unsigned_32 := 0;
      Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
      Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
      View_Info : aliased Vk.Image_View_Create_Info_T;
      View_Handle : aliased Vk.Image_View_T := System.Null_Address;
      Sampler_Info : aliased Vk.Sampler_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         mag_Filter               => Vk.FILTER_NEAREST,
         min_Filter               => Vk.FILTER_NEAREST,
         mipmap_Mode              => Vk.SAMPLER_MIPMAP_MODE_NEAREST,
         address_Mode_U           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
         address_Mode_V           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
         address_Mode_W           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
         mip_Lod_Bias             => 0.0,
         anisotropy_Enable        => 0,
         max_Anisotropy           => 1.0,
         compare_Enable           => 0,
         compare_Op               => Vk.COMPARE_OP_ALWAYS,
         min_Lod                  => 0.0,
         max_Lod                  => 0.0,
         border_Color             => Vk.BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
         unnormalized_Coordinates => 0);
      Sampler_Handle : aliased Vk.Sampler_T := System.Null_Address;
      Result : Vk.Result_T;
   begin
      Result :=
        Vk.Create_Image
          (device        => Renderer.Device,
           p_Create_Info => Image_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Image       => Image_Handle'Address);

      if Result /= Vk.SUCCESS or else Image_Handle = System.Null_Address then
         return False;
      end if;

      Vk.Get_Image_Memory_Requirements (Renderer.Device, Image_Handle, Requirements'Address);
      if not Any_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
         Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
         return False;
      end if;

      Allocate_Info :=
        (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
         p_Next            => System.Null_Address,
         allocation_Size   => Requirements.size,
         memory_Type_Index => Memory_Type);
      Result :=
        Vk.Allocate_Memory
          (device          => Renderer.Device,
           p_Allocate_Info => Allocate_Info'Address,
           p_Allocator     => System.Null_Address,
           p_Memory        => Memory_Handle'Address);

      if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
         Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
         return False;
      end if;

      if Vk.Bind_Image_Memory (Renderer.Device, Image_Handle, Memory_Handle, 0) /= Vk.SUCCESS then
         Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
         Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
         return False;
      end if;

      View_Info :=
        (s_Type            => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
         p_Next            => System.Null_Address,
         flags             => 0,
         image             => Image_Handle,
         view_Type         => Vk.IMAGE_VIEW_TYPE_2D,
         format            => Vulkan_Format,
         components        =>
           (r => Vk.COMPONENT_SWIZZLE_R,
            g =>
              (if Upload_Format = Atlas_Texture_RGBA8
               then Vk.COMPONENT_SWIZZLE_G
               else Vk.COMPONENT_SWIZZLE_R),
            b =>
              (if Upload_Format = Atlas_Texture_RGBA8
               then Vk.COMPONENT_SWIZZLE_B
               else Vk.COMPONENT_SWIZZLE_R),
            a =>
              (if Upload_Format = Atlas_Texture_RGBA8
               then Vk.COMPONENT_SWIZZLE_A
               else Vk.COMPONENT_SWIZZLE_R)),
         subresource_Range =>
           (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
            base_Mip_Level   => 0,
            level_Count      => 1,
            base_Array_Layer => 0,
            layer_Count      => 1));
      Result :=
        Vk.Create_Image_View
          (device        => Renderer.Device,
           p_Create_Info => View_Info'Address,
           p_Allocator   => System.Null_Address,
           p_View        => View_Handle'Address);

      if Result /= Vk.SUCCESS or else View_Handle = System.Null_Address then
         Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
         Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
         return False;
      end if;

      Result :=
        Vk.Create_Sampler
          (device        => Renderer.Device,
           p_Create_Info => Sampler_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Sampler     => Sampler_Handle'Address);

      if Result /= Vk.SUCCESS or else Sampler_Handle = System.Null_Address then
         Vk.Destroy_Image_View (Renderer.Device, View_Handle, System.Null_Address);
         Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
         Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
         return False;
      end if;

      Renderer.Atlas_Image := Image_Handle;
      Renderer.Atlas_Memory := Memory_Handle;
      Renderer.Atlas_View := View_Handle;
      Renderer.Atlas_Sampler := Sampler_Handle;
      Renderer.Atlas_Width_Value := Actual_Width;
      Renderer.Atlas_Height_Value := Actual_Height;
      Renderer.Atlas_Format_Value := Upload_Format;
      Renderer.Atlas_Texture_Live := True;
      return True;
   end Create_Atlas_Texture;

   --  Destroy the staging buffer the renderer has and make a host-visible
   --  one Bytes long. False when it cannot be made.
   function Replace_Staging_Buffer return Boolean is
      Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         size                     => Interfaces.Unsigned_64 (Bytes),
         usage                    => Vk.BUFFER_USAGE_TRANSFER_SRC_BIT,
         sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices   => System.Null_Address);
      Buffer_Handle : aliased Vk.Buffer_T := System.Null_Address;
      Requirements  : aliased Vk.Memory_Requirements_T;
      Memory_Type   : Interfaces.Unsigned_32 := 0;
      Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
      Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
      Result : Vk.Result_T;
   begin
      if Renderer.Atlas_Staging_Buffer /= System.Null_Address then
         Vk.Destroy_Buffer (Renderer.Device, Renderer.Atlas_Staging_Buffer, System.Null_Address);
         Renderer.Atlas_Staging_Buffer := System.Null_Address;
      end if;

      if Renderer.Atlas_Staging_Memory /= System.Null_Address then
         Vk.Free_Memory (Renderer.Device, Renderer.Atlas_Staging_Memory, System.Null_Address);
         Renderer.Atlas_Staging_Memory := System.Null_Address;
      end if;

      Result :=
        Vk.Create_Buffer
          (device        => Renderer.Device,
           p_Create_Info => Buffer_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Buffer      => Buffer_Handle'Address);

      if Result /= Vk.SUCCESS or else Buffer_Handle = System.Null_Address then
         return False;
      end if;

      Vk.Get_Buffer_Memory_Requirements (Renderer.Device, Buffer_Handle, Requirements'Address);
      if not Host_Visible_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      Allocate_Info :=
        (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
         p_Next            => System.Null_Address,
         allocation_Size   => Requirements.size,
         memory_Type_Index => Memory_Type);
      Result :=
        Vk.Allocate_Memory
          (device          => Renderer.Device,
           p_Allocate_Info => Allocate_Info'Address,
           p_Allocator     => System.Null_Address,
           p_Memory        => Memory_Handle'Address);

      if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      if Vk.Bind_Buffer_Memory (Renderer.Device, Buffer_Handle, Memory_Handle, 0) /= Vk.SUCCESS then
         Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      Renderer.Atlas_Staging_Buffer := Buffer_Handle;
      Renderer.Atlas_Staging_Memory := Memory_Handle;
      Renderer.Atlas_Staging_Capacity := Bytes;
      Renderer.Atlas_Staging_Live := True;
      return True;
   end Replace_Staging_Buffer;

   --  Copy the pixels into the staging buffer. False when it cannot be
   --  mapped.
   function Copy_To_Staging return Boolean is
      Mapped_Data : aliased System.Address := System.Null_Address;
      Result : Vk.Result_T;
   begin
      Result :=
        Vk.Map_Memory
          (device  => Renderer.Device,
           memory  => Renderer.Atlas_Staging_Memory,
           offset  => 0,
           size    => Interfaces.Unsigned_64 (Bytes),
           flags   => 0,
           pp_Data => Mapped_Data'Address);

      if Result /= Vk.SUCCESS or else Mapped_Data = System.Null_Address then
         return False;
      end if;

      declare
         Target : constant Byte_Array_Conversions.Object_Pointer :=
           Byte_Array_Conversions.To_Pointer (Mapped_Data);
      begin
         declare
            Source : constant Byte_Array_Conversions.Object_Pointer :=
              Byte_Array_Conversions.To_Pointer (Pixel_Address);
         begin
            for Index in 1 .. Bytes loop
               Target.all (Index) := Source.all (Index);
            end loop;
         end;
      end;

      Vk.Unmap_Memory (Renderer.Device, Renderer.Atlas_Staging_Memory);
      return True;
   end Copy_To_Staging;

   --  Point the descriptor set's sampler binding at the atlas texture.
   procedure Bind_Atlas_Descriptor is
      Image_Info : aliased Vk.Descriptor_Image_Info_T :=
        (sampler      => Renderer.Atlas_Sampler,
         image_View   => Renderer.Atlas_View,
         image_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
      Write : aliased Vk.Write_Descriptor_Set_T :=
        (s_Type                => Vk.STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
         p_Next                => System.Null_Address,
         dst_Set               => Renderer.Descriptor_Set,
         dst_Binding           => 0,
         dst_Array_Element     => 0,
         descriptor_Count      => 1,
         descriptor_Type       => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
         p_Image_Info          => Image_Info'Address,
         p_Buffer_Info         => System.Null_Address,
         p_Texel_Buffer_View   => System.Null_Address);
   begin
      Vk.Update_Descriptor_Sets
        (device                 => Renderer.Device,
         descriptor_Write_Count => 1,
         p_Descriptor_Writes    => Write'Address,
         descriptor_Copy_Count  => 0,
         p_Descriptor_Copies    => System.Null_Address);
   end Bind_Atlas_Descriptor;
begin
   if not Use_Batch_Atlas and then Renderer.Atlas_Texture_Live then
      return True;
   elsif Pixel_Address = System.Null_Address
     or else Actual_Width = 0
     or else Actual_Height = 0
     or else Bytes = 0
     or else Bytes > Max_Atlas_Bytes
   then
      return False;
   end if;

   if Needs_New_Texture then
      Release_Atlas_Texture;
      if not Create_Atlas_Texture then
         return False;
      end if;
   end if;

   if not Renderer.Atlas_Staging_Live or else Renderer.Atlas_Staging_Capacity < Bytes then
      if not Replace_Staging_Buffer then
         return False;
      end if;
   end if;

   if not Copy_To_Staging then
      return False;
   end if;
   Bind_Atlas_Descriptor;

   Renderer.Atlas_Upload_Pending := True;
   --  The text atlas texture now holds this version, or icons (version 0
   --  is never handed out, so the next text frame uploads again).
   Renderer.Uploaded_Atlas_Version := (if Use_Batch_Atlas then Batch.Atlas_Version else 0);
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Upload_Atlas;
