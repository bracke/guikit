separate (Guikit.Vulkan)
package body Atlas_Uploads is

   --  The descriptor binding each atlas is sampled through.
   Binding : constant array (Atlas_Kind) of Interfaces.Unsigned_32 := [Text_Atlas => 0, Icon_Atlas => 1];

   --  Point descriptor binding Target at the view and sampler of atlas
   --  Source's texture.
   procedure Write_Binding (Renderer : Vulkan_Renderer; Target : Atlas_Kind; Source : Atlas_Kind) is
      Image_Info : aliased Vk.Descriptor_Image_Info_T :=
        (sampler      => Renderer.Atlases (Source).Sampler,
         image_View   => Renderer.Atlases (Source).View,
         image_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
      Write : aliased Vk.Write_Descriptor_Set_T :=
        (s_Type                => Vk.STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
         p_Next                => System.Null_Address,
         dst_Set               => Renderer.Descriptor_Set,
         dst_Binding           => Binding (Target),
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
   end Write_Binding;

   --  Point the icon binding at the text atlas's live view while the icon
   --  atlas has no current binding of its own, so both bindings name a live
   --  view; nothing when the text binding is not current.
   procedure Fall_Back_Icon_Binding (Renderer : in out Vulkan_Renderer) is
      Text : Atlas_Texture renames Renderer.Atlases (Text_Atlas);
      Icon : Atlas_Texture renames Renderer.Atlases (Icon_Atlas);
   begin
      if Renderer.Descriptor_Live
        and then Text.Texture_Live
        and then Text.Binding = Binding_Current
        and then Icon.Binding /= Binding_Current
      then
         Write_Binding (Renderer, Target => Icon_Atlas, Source => Text_Atlas);
         Icon.Binding := Binding_Fallback;
      end if;
   end Fall_Back_Icon_Binding;

   --  Point the atlas's descriptor binding at its texture; binding the text
   --  atlas also refreshes an icon binding that falls back to it.
   procedure Bind_Descriptor (Renderer : in out Vulkan_Renderer; Kind : Atlas_Kind) is
   begin
      Write_Binding (Renderer, Target => Kind, Source => Kind);
      Renderer.Atlases (Kind).Binding := Binding_Current;
      if Kind = Text_Atlas then
         Fall_Back_Icon_Binding (Renderer);
      end if;
   end Bind_Descriptor;

   procedure Release_Texture (Renderer : in out Vulkan_Renderer; Kind : Atlas_Kind) is
      Texture : Atlas_Texture renames Renderer.Atlases (Kind);
   begin
      Destroy_Image_View (Renderer.Device, Texture.View);
      Destroy_Sampler (Renderer.Device, Texture.Sampler);
      Destroy_Image (Renderer.Device, Texture.Image);
      Free_Memory (Renderer.Device, Texture.Memory);
      Texture.Texture_Live := False;
      Texture.Initialized := False;
      Texture.Upload_Pending := False;
      if Texture.Binding = Binding_Current then
         Texture.Binding := Binding_Stale;
      end if;
      case Kind is
         when Text_Atlas =>
            if Renderer.Atlases (Icon_Atlas).Binding = Binding_Fallback then
               Renderer.Atlases (Icon_Atlas).Binding := Binding_Stale;
            end if;
         when Icon_Atlas =>
            Fall_Back_Icon_Binding (Renderer);
      end case;
   end Release_Texture;

   procedure Release_Staging (Renderer : in out Vulkan_Renderer; Kind : Atlas_Kind) is
      Texture : Atlas_Texture renames Renderer.Atlases (Kind);
   begin
      Destroy_Buffer (Renderer.Device, Texture.Staging_Buffer);
      Free_Memory (Renderer.Device, Texture.Staging_Memory);
      Texture.Staging_Live := False;
      Texture.Staging_Capacity := 0;
   end Release_Staging;

   --  The Vulkan format an atlas texture is made in: the icon atlas's
   --  RGBA pixels in sRGB, a coverage byte per pixel otherwise.
   function Vulkan_Format_Of (Format : Atlas_Texture_Format) return Vk.Format_T is
     (if Format = Atlas_Texture_RGBA8 then Format_R8G8B8A8_Srgb else Vk.FORMAT_R8_UNORM);

   --  Make a Width by Height image in Format, and device memory bound to
   --  it. False, with neither left behind, when either cannot be made.
   function Create_Image
     (Renderer : Vulkan_Renderer;
      Width    : Positive;
      Height   : Positive;
      Format   : Vk.Format_T;
      Image    : out Vk.Image_T;
      Memory   : out Vk.Device_Memory_T)
      return Boolean
   is
      Image_Info : aliased Vk.Image_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         image_Type               => Vk.IMAGE_TYPE_2D,
         format                   => Format,
         extent                   =>
           (width  => Interfaces.Unsigned_32 (Width),
            height => Interfaces.Unsigned_32 (Height),
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
      Image_Handle  : aliased Vk.Image_T := System.Null_Address;
      Requirements  : aliased Vk.Memory_Requirements_T;
      Memory_Type   : Interfaces.Unsigned_32 := 0;
      Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
      Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
      Result        : Vk.Result_T;
   begin
      Image := System.Null_Address;
      Memory := System.Null_Address;
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
         Destroy_Image (Renderer.Device, Image_Handle);
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
      if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address
        or else Vk.Bind_Image_Memory (Renderer.Device, Image_Handle, Memory_Handle, 0) /= Vk.SUCCESS
      then
         Free_Memory (Renderer.Device, Memory_Handle);
         Destroy_Image (Renderer.Device, Image_Handle);
         return False;
      end if;

      Image := Image_Handle;
      Memory := Memory_Handle;
      return True;
   end Create_Image;

   --  Make a view of Image in Format. The glyph atlas's one byte per pixel
   --  is read in every channel; the icon atlas's channels are read as they
   --  are. Null when it cannot be made.
   function Create_View
     (Renderer : Vulkan_Renderer;
      Kind     : Atlas_Kind;
      Image    : Vk.Image_T;
      Format   : Vk.Format_T)
      return Vk.Image_View_T
   is
      Channel     : constant array (1 .. 4) of Vk.Component_Swizzle_T :=
        (if Kind = Text_Atlas
         then [others => Vk.COMPONENT_SWIZZLE_R]
         else [Vk.COMPONENT_SWIZZLE_R, Vk.COMPONENT_SWIZZLE_G, Vk.COMPONENT_SWIZZLE_B, Vk.COMPONENT_SWIZZLE_A]);
      View_Info   : aliased Vk.Image_View_Create_Info_T :=
        (s_Type            => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
         p_Next            => System.Null_Address,
         flags             => 0,
         image             => Image,
         view_Type         => Vk.IMAGE_VIEW_TYPE_2D,
         format            => Format,
         components        => (r => Channel (1), g => Channel (2), b => Channel (3), a => Channel (4)),
         subresource_Range =>
           (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
            base_Mip_Level   => 0,
            level_Count      => 1,
            base_Array_Layer => 0,
            layer_Count      => 1));
      View_Handle : aliased Vk.Image_View_T := System.Null_Address;
   begin
      if Vk.Create_Image_View
           (device        => Renderer.Device,
            p_Create_Info => View_Info'Address,
            p_Allocator   => System.Null_Address,
            p_View        => View_Handle'Address) /= Vk.SUCCESS
      then
         return System.Null_Address;
      end if;
      return View_Handle;
   end Create_View;

   --  Make the nearest-neighbour, edge-clamped sampler the atlases are read
   --  through. Null when it cannot be made.
   function Create_Sampler (Renderer : Vulkan_Renderer) return Vk.Sampler_T is
      Sampler_Info   : aliased Vk.Sampler_Create_Info_T :=
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
   begin
      if Vk.Create_Sampler
           (device        => Renderer.Device,
            p_Create_Info => Sampler_Info'Address,
            p_Allocator   => System.Null_Address,
            p_Sampler     => Sampler_Handle'Address) /= Vk.SUCCESS
      then
         return System.Null_Address;
      end if;
      return Sampler_Handle;
   end Create_Sampler;

   --  Make the atlas's image, its memory, view and sampler Width by Height
   --  in Format. False, with nothing left behind, when any of them cannot be
   --  made.
   function Create_Texture
     (Renderer : in out Vulkan_Renderer;
      Kind     : Atlas_Kind;
      Width    : Positive;
      Height   : Positive;
      Format   : Atlas_Texture_Format)
      return Boolean
   is
      Vulkan_Format  : constant Vk.Format_T := Vulkan_Format_Of (Format);
      Image_Handle   : Vk.Image_T;
      Memory_Handle  : Vk.Device_Memory_T;
      View_Handle    : Vk.Image_View_T := System.Null_Address;
      Sampler_Handle : Vk.Sampler_T := System.Null_Address;
   begin
      if not Create_Image (Renderer, Width, Height, Vulkan_Format, Image_Handle, Memory_Handle) then
         return False;
      end if;
      View_Handle := Create_View (Renderer, Kind, Image_Handle, Vulkan_Format);
      if View_Handle /= System.Null_Address then
         Sampler_Handle := Create_Sampler (Renderer);
      end if;
      if Sampler_Handle = System.Null_Address then
         --  Undo what was made.
         Destroy_Image_View (Renderer.Device, View_Handle);
         Free_Memory (Renderer.Device, Memory_Handle);
         Destroy_Image (Renderer.Device, Image_Handle);
         return False;
      end if;

      declare
         Texture : Atlas_Texture renames Renderer.Atlases (Kind);
      begin
         Texture.Image := Image_Handle;
         Texture.Memory := Memory_Handle;
         Texture.View := View_Handle;
         Texture.Sampler := Sampler_Handle;
         Texture.Width := Width;
         Texture.Height := Height;
         Texture.Format := Format;
         Texture.Texture_Live := True;
      end;
      return True;
   end Create_Texture;

   --  Make a host-visible staging buffer Bytes long for the atlas, which
   --  has none. False, with none, when it cannot be made.
   function Create_Staging
     (Renderer : in out Vulkan_Renderer;
      Kind     : Atlas_Kind;
      Bytes    : Positive)
      return Boolean
   is
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
      Result        : Vk.Result_T;

      --  Undo what was made so far.
      procedure Discard is
      begin
         Free_Memory (Renderer.Device, Memory_Handle);
         Destroy_Buffer (Renderer.Device, Buffer_Handle);
      end Discard;
   begin
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
         Discard;
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
      if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address
        or else Vk.Bind_Buffer_Memory (Renderer.Device, Buffer_Handle, Memory_Handle, 0) /= Vk.SUCCESS
      then
         Discard;
         return False;
      end if;

      declare
         Texture : Atlas_Texture renames Renderer.Atlases (Kind);
      begin
         Texture.Staging_Buffer := Buffer_Handle;
         Texture.Staging_Memory := Memory_Handle;
         Texture.Staging_Capacity := Bytes;
         Texture.Staging_Live := True;
      end;
      return True;
   end Create_Staging;

   --  Map the atlas's staging memory and let Fill write Bytes bytes of
   --  pixels into it. False when it cannot be mapped.
   function Copy_To_Staging
     (Renderer : Vulkan_Renderer;
      Kind     : Atlas_Kind;
      Bytes    : Positive;
      Fill     : not null access procedure (Target : Byte_Array_Conversions.Object_Pointer))
      return Boolean
   is
      Memory      : constant Vk.Device_Memory_T := Renderer.Atlases (Kind).Staging_Memory;
      Mapped_Data : aliased System.Address := System.Null_Address;
      Result      : Vk.Result_T;
   begin
      Result :=
        Vk.Map_Memory
          (device  => Renderer.Device,
           memory  => Memory,
           offset  => 0,
           size    => Interfaces.Unsigned_64 (Bytes),
           flags   => 0,
           pp_Data => Mapped_Data'Address);
      if Result /= Vk.SUCCESS or else Mapped_Data = System.Null_Address then
         return False;
      end if;

      Fill (Byte_Array_Conversions.To_Pointer (Mapped_Data));
      Vk.Unmap_Memory (Renderer.Device, Memory);
      return True;
   end Copy_To_Staging;

   function Upload
     (Renderer : in out Vulkan_Renderer;
      Kind     : Atlas_Kind;
      Width    : Positive;
      Height   : Positive;
      Format   : Atlas_Texture_Format;
      Bytes    : Positive;
      Fill     : not null access procedure (Target : Byte_Array_Conversions.Object_Pointer))
      return Boolean
   is
      Texture : Atlas_Texture renames Renderer.Atlases (Kind);
   begin
      if not Texture.Texture_Live
        or else Texture.Width /= Width
        or else Texture.Height /= Height
        or else Texture.Format /= Format
      then
         Release_Texture (Renderer, Kind);
         if not Create_Texture (Renderer, Kind, Width, Height, Format) then
            return False;
         end if;
      end if;

      if not Texture.Staging_Live or else Texture.Staging_Capacity < Bytes then
         Release_Staging (Renderer, Kind);
         if not Create_Staging (Renderer, Kind, Bytes) then
            Release_Texture (Renderer, Kind);
            return False;
         end if;
      end if;

      if not Copy_To_Staging (Renderer, Kind, Bytes, Fill) then
         Release_Texture (Renderer, Kind);
         return False;
      end if;
      Bind_Descriptor (Renderer, Kind);
      Texture.Upload_Pending := True;
      return True;
   end Upload;

end Atlas_Uploads;
