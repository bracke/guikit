separate (Guikit.Vulkan)
function Create_Swapchain_Resources
  (Renderer : in out Vulkan_Renderer;
   Width    : Natural;
   Height   : Natural)
   return Vulkan_Status
is
   Capabilities  : aliased Vk.Surface_Capabilities_KHR_T;
   Chosen_Format : Vk.Surface_Format_KHR_T :=
     (format => Vk.FORMAT_B8G8R8A8_SRGB, color_Space => Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR);
   --  The swapchain being replaced, if any. It is handed to the driver as
   --  oldSwapchain, which retires it (it can no longer acquire) and lets
   --  the driver reuse its resources, and is destroyed once the new one has
   --  been created -- or as soon as it is clear none will be.
   Old_Swapchain : Vk.Swapchain_KHR_T := System.Null_Address;

   procedure Retire_Old_Swapchain is
   begin
      if Old_Swapchain /= System.Null_Address then
         Vk.Destroy_Swapchain_KHR
           (device      => Renderer.Device,
            swapchain   => Old_Swapchain,
            p_Allocator => System.Null_Address);
         Old_Swapchain := System.Null_Address;
      end if;
   end Retire_Old_Swapchain;

   --  Record Status as the outcome and return it.
   function Outcome (Status : Vulkan_Status) return Vulkan_Status is
   begin
      Renderer.Last_Status := Status;
      return Status;
   end Outcome;

   --  The surface's support, capabilities, and an sRGB format for it
   --  (Capabilities, Chosen_Format); Vulkan_Swapchain_Ready when they are
   --  in hand, else the failure.
   function Query_Surface return Vulkan_Status is
      Surface_Supported : aliased Interfaces.Unsigned_32 := 0;
      Format_Count      : aliased Interfaces.Unsigned_32 := 0;
      Formats           : Surface_Format_Array (1 .. Max_Surface_Formats);
   begin
      if Vk.Get_Physical_Device_Surface_Support_KHR
           (physical_Device    => Renderer.Physical_Device,
            queue_Family_Index => Renderer.Queue_Family_Index,
            surface            => Renderer.Surface,
            p_Supported        => Surface_Supported'Address) /= Vk.SUCCESS
        or else Surface_Supported = 0
      then
         return Vulkan_Surface_Unsupported;
      end if;

      if Vk.Get_Physical_Device_Surface_Capabilities_KHR
           (physical_Device        => Renderer.Physical_Device,
            surface                => Renderer.Surface,
            p_Surface_Capabilities => Capabilities'Address) /= Vk.SUCCESS
      then
         return Vulkan_Swapchain_Create_Failed;
      end if;

      if Vk.Get_Physical_Device_Surface_Formats_KHR
           (physical_Device        => Renderer.Physical_Device,
            surface                => Renderer.Surface,
            p_Surface_Format_Count => Format_Count'Address,
            p_Surface_Formats      => System.Null_Address) /= Vk.SUCCESS
        or else Format_Count = 0
      then
         return Vulkan_Swapchain_Create_Failed;
      end if;

      if Format_Count > Formats'Length then
         Format_Count := Formats'Length;
      end if;

      if Vk.Get_Physical_Device_Surface_Formats_KHR
           (physical_Device        => Renderer.Physical_Device,
            surface                => Renderer.Surface,
            p_Surface_Format_Count => Format_Count'Address,
            p_Surface_Formats      => Formats (Formats'First)'Address) /= Vk.SUCCESS
      then
         return Vulkan_Swapchain_Create_Failed;
      end if;

      --  An sRGB swapchain is not a preference here, it is a requirement.
      --  Color_To_Vertex converts every colour from sRGB to linear on the way to
      --  the GPU, on the understanding that the swapchain encodes back to sRGB
      --  when it stores. That is what makes the blending gamma-correct. Handed a
      --  UNORM target instead, the same linear values are displayed as if they
      --  were already sRGB and the whole interface comes out too dark -- a wrong
      --  picture rather than an error, which is the kind of failure worth
      --  refusing outright.
      --
      --  Either sRGB byte order will do; the surface reports which it prefers.
      for Index in 1 .. Natural (Format_Count) loop
         if (Formats (Index).format = Vk.FORMAT_B8G8R8A8_SRGB
               or else Formats (Index).format = Format_R8G8B8A8_Srgb)
           and then Formats (Index).color_Space = Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR
         then
            Chosen_Format := Formats (Index);
            return Vulkan_Swapchain_Ready;
         end if;
      end loop;
      return Vulkan_Swapchain_Create_Failed;
   end Query_Surface;

   --  Create the swapchain for the surface as queried, retiring the old one
   --  either way: a failed create still retires oldSwapchain. False when it
   --  cannot be made.
   function Make_Swapchain return Boolean is
      Image_Count      : Interfaces.Unsigned_32 := Capabilities.min_Image_Count + 1;
      Extent           : Vk.Extent2_D_T := Capabilities.current_Extent;
      Swapchain_Info   : aliased Vk.Swapchain_Create_Info_KHR_T;
      Swapchain_Handle : aliased Vk.Swapchain_KHR_T := System.Null_Address;
      Swapchain_Result : Vk.Result_T;
   begin
      if Capabilities.max_Image_Count /= 0 and then Image_Count > Capabilities.max_Image_Count then
         Image_Count := Capabilities.max_Image_Count;
      end if;

      if Capabilities.current_Extent.width = Interfaces.Unsigned_32'Last then
         Extent :=
           (width  =>
              Clamp
                (Interfaces.Unsigned_32 (Width),
                 Capabilities.min_Image_Extent.width,
                 Capabilities.max_Image_Extent.width),
            height =>
              Clamp
                (Interfaces.Unsigned_32 (Height),
                 Capabilities.min_Image_Extent.height,
                 Capabilities.max_Image_Extent.height));
      end if;

      Swapchain_Info :=
        (s_Type                   => Structure_Type_Swapchain_Create_Info_KHR,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         surface                  => Renderer.Surface,
         min_Image_Count          => Image_Count,
         image_Format             => Chosen_Format.format,
         image_Color_Space        => Chosen_Format.color_Space,
         image_Extent             => Extent,
         image_Array_Layers       => 1,
         image_Usage              => Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT or Vk.IMAGE_USAGE_TRANSFER_SRC_BIT,
         image_Sharing_Mode       => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices   => System.Null_Address,
         pre_Transform            => Capabilities.current_Transform,
         composite_Alpha          => Vk.COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
         present_Mode             => Vk.PRESENT_MODE_FIFO_KHR,
         clipped                  => 1,
         old_Swapchain            => Old_Swapchain);

      Swapchain_Result :=
        Vk.Create_Swapchain_KHR
          (device        => Renderer.Device,
           p_Create_Info => Swapchain_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Swapchain   => Swapchain_Handle'Address);
      Retire_Old_Swapchain;

      if Swapchain_Result /= Vk.SUCCESS or else Swapchain_Handle = System.Null_Address then
         return False;
      end if;

      Renderer.Swapchain := Swapchain_Handle;
      Renderer.Swapchain_Live := True;
      Renderer.Frame_Width_Value := Natural (Extent.width);
      Renderer.Frame_Height_Value := Natural (Extent.height);
      return True;
   end Make_Swapchain;

   --  The new swapchain's images, into Renderer.Swapchain_Images;
   --  Vulkan_Swapchain_Ready when they are in hand, else the failure.
   function Fetch_Images return Vulkan_Status is
      Images : Image_Array (1 .. Max_Swapchain_Images);
   begin
      Renderer.Swapchain_Image_Count := 0;
      if Vk.Get_Swapchain_Images_KHR
           (device                  => Renderer.Device,
            swapchain               => Renderer.Swapchain,
            p_Swapchain_Image_Count => Renderer.Swapchain_Image_Count'Address,
            p_Swapchain_Images      => System.Null_Address) /= Vk.SUCCESS
        or else Renderer.Swapchain_Image_Count = 0
      then
         return Vulkan_Swapchain_Image_Query_Failed;
      elsif Renderer.Swapchain_Image_Count > Interfaces.Unsigned_32 (Max_Swapchain_Images) then
         return Vulkan_Swapchain_Image_Query_Failed;
      elsif Vk.Get_Swapchain_Images_KHR
              (device                  => Renderer.Device,
               swapchain               => Renderer.Swapchain,
               p_Swapchain_Image_Count => Renderer.Swapchain_Image_Count'Address,
               p_Swapchain_Images      => Images (Images'First)'Address) /= Vk.SUCCESS
      then
         return Vulkan_Swapchain_Image_Query_Failed;
      end if;

      for Index in 1 .. Natural (Renderer.Swapchain_Image_Count) loop
         Renderer.Swapchain_Images (Index) := Images (Index);
      end loop;
      return Vulkan_Swapchain_Ready;
   end Fetch_Images;

   --  Everything drawn into the swapchain's images: render targets, command
   --  pool, descriptors, pipeline, command buffers and sync objects;
   --  Vulkan_Swapchain_Ready when they are all made, else the first failure.
   function Build_On_Swapchain return Vulkan_Status is
   begin
      if not Create_Render_Targets (Renderer, Chosen_Format.format) then
         return Vulkan_Render_Target_Create_Failed;
      elsif not Create_Command_Resources (Renderer) then
         return Vulkan_Command_Create_Failed;
      elsif not Create_Descriptor_Resources (Renderer) then
         return Vulkan_Descriptor_Create_Failed;
      elsif not Create_Graphics_Pipeline (Renderer) then
         return Vulkan_Pipeline_Create_Failed;
      elsif not Record_Command_Buffers (Renderer, 0) then
         return Vulkan_Command_Record_Failed;
      elsif not Create_Sync_Objects (Renderer) then
         return Vulkan_Sync_Create_Failed;
      end if;
      return Vulkan_Swapchain_Ready;
   end Build_On_Swapchain;

   Status : Vulkan_Status;
begin
   --  Everything but the swapchain handle goes now, after the device has
   --  gone idle; the handle survives only until the new swapchain exists.
   Destroy_Swapchain_Resources (Renderer, Keep_Swapchain => True);
   if Renderer.Swapchain_Live then
      Old_Swapchain := Renderer.Swapchain;
      Renderer.Swapchain := System.Null_Address;
      Renderer.Swapchain_Live := False;
   end if;

   Status := Query_Surface;
   if Status /= Vulkan_Swapchain_Ready then
      Retire_Old_Swapchain;
      return Outcome (Status);
   elsif not Make_Swapchain then
      return Outcome (Vulkan_Swapchain_Create_Failed);
   end if;

   Status := Fetch_Images;
   if Status = Vulkan_Swapchain_Ready then
      Status := Build_On_Swapchain;
   end if;
   if Status /= Vulkan_Swapchain_Ready then
      Destroy_Swapchain_Resources (Renderer);
      return Outcome (Status);
   end if;

   Renderer.Swapchain_Configured := True;
   Renderer.Swapchain_Pending := False;
   Renderer.Pending_Width_Value := 0;
   Renderer.Pending_Height_Value := 0;
   return Outcome (Vulkan_Swapchain_Ready);
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      Retire_Old_Swapchain;
      Destroy_Swapchain_Resources (Renderer);
      return Outcome (Vulkan_Swapchain_Create_Failed);
end Create_Swapchain_Resources;
