separate (Guikit.Vulkan)
function Create_Color_MSAA_Target
  (Renderer : in out Vulkan_Renderer;
   Format   : Vk.Format_T;
   Samples  : Vk.Sample_Count_Flag_Bits_T)
   return Boolean
is
   Image_Info : aliased Vk.Image_Create_Info_T :=
     (s_Type                   => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
      p_Next                   => System.Null_Address,
      flags                    => 0,
      image_Type               => Vk.IMAGE_TYPE_2D,
      format                   => Format,
      extent                   =>
        (width  => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
         height => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value),
         depth  => 1),
      mip_Levels               => 1,
      array_Layers             => 1,
      samples                  => Samples,
      tiling                   => Vk.IMAGE_TILING_OPTIMAL,
      usage                    => Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
      sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
      queue_Family_Index_Count => 0,
      p_Queue_Family_Indices   => System.Null_Address,
      initial_Layout           => Vk.IMAGE_LAYOUT_UNDEFINED);
   Image_Handle  : aliased Vk.Image_T := System.Null_Address;
   Requirements  : aliased Vk.Memory_Requirements_T;
   Memory_Type   : Interfaces.Unsigned_32 := 0;
   Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
   Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
   View_Info     : aliased Vk.Image_View_Create_Info_T;
   View_Handle   : aliased Vk.Image_View_T := System.Null_Address;
   Result        : Vk.Result_T;
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
      format            => Format,
      components        =>
        (r => Vk.COMPONENT_SWIZZLE_IDENTITY,
         g => Vk.COMPONENT_SWIZZLE_IDENTITY,
         b => Vk.COMPONENT_SWIZZLE_IDENTITY,
         a => Vk.COMPONENT_SWIZZLE_IDENTITY),
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

   Renderer.Color_MSAA_Image := Image_Handle;
   Renderer.Color_MSAA_Memory := Memory_Handle;
   Renderer.Color_MSAA_View := View_Handle;
   Renderer.Color_MSAA_Live := True;
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Create_Color_MSAA_Target;
