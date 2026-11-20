separate (Guikit.Vulkan)
function Create_Render_Targets
  (Renderer : in out Vulkan_Renderer;
   Format   : Vk.Format_T)
   return Boolean
is
   Samples : constant Vk.Sample_Count_Flag_Bits_T := Choose_Color_Sample_Count (Renderer);
   MSAA_On : constant Boolean := Samples /= Vk.SAMPLE_COUNT_1_BIT;
   --  Attachment 0 is the colour target the pipeline draws into. Without MSAA
   --  it is the swapchain image itself (stored and presented). With MSAA it is
   --  a multisampled image whose contents are resolved into the swapchain
   --  image (attachment 1) at the end of the subpass.
   Color_Attachment : constant Vk.Attachment_Description_T :=
     (flags            => 0,
      format           => Format,
      samples          => Samples,
      load_Op          => Vk.ATTACHMENT_LOAD_OP_CLEAR,
      store_Op         =>
        (if MSAA_On then Vk.ATTACHMENT_STORE_OP_DONT_CARE else Vk.ATTACHMENT_STORE_OP_STORE),
      stencil_Load_Op  => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
      stencil_Store_Op => Vk.ATTACHMENT_STORE_OP_DONT_CARE,
      initial_Layout   => Vk.IMAGE_LAYOUT_UNDEFINED,
      final_Layout     =>
        (if MSAA_On then Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL else Image_Layout_Present_Src_KHR));
   Resolve_Attachment : constant Vk.Attachment_Description_T :=
     (flags            => 0,
      format           => Format,
      samples          => Vk.SAMPLE_COUNT_1_BIT,
      load_Op          => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
      store_Op         => Vk.ATTACHMENT_STORE_OP_STORE,
      stencil_Load_Op  => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
      stencil_Store_Op => Vk.ATTACHMENT_STORE_OP_DONT_CARE,
      initial_Layout   => Vk.IMAGE_LAYOUT_UNDEFINED,
      final_Layout     => Image_Layout_Present_Src_KHR);
   Attachments : aliased array (0 .. 1) of Vk.Attachment_Description_T :=
     [Color_Attachment, Resolve_Attachment];
   Color_Reference : aliased Vk.Attachment_Reference_T :=
     (attachment => 0,
      layout     => Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
   Resolve_Reference : aliased Vk.Attachment_Reference_T :=
     (attachment => 1,
      layout     => Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
   Subpass : aliased Vk.Subpass_Description_T :=
     (flags                       => 0,
      pipeline_Bind_Point         => Vk.PIPELINE_BIND_POINT_GRAPHICS,
      input_Attachment_Count      => 0,
      p_Input_Attachments         => System.Null_Address,
      color_Attachment_Count      => 1,
      p_Color_Attachments         => Color_Reference'Address,
      p_Resolve_Attachments       =>
        (if MSAA_On then Resolve_Reference'Address else System.Null_Address),
      p_Depth_Stencil_Attachment  => System.Null_Address,
      preserve_Attachment_Count   => 0,
      p_Preserve_Attachments      => System.Null_Address);
   Render_Pass_Info : aliased Vk.Render_Pass_Create_Info_T :=
     (s_Type           => Vk.STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      p_Next           => System.Null_Address,
      flags            => 0,
      attachment_Count => (if MSAA_On then 2 else 1),
      p_Attachments    => Attachments (Attachments'First)'Address,
      subpass_Count    => 1,
      p_Subpasses      => Subpass'Address,
      dependency_Count => 0,
      p_Dependencies   => System.Null_Address);
   Render_Pass_Handle : aliased Vk.Render_Pass_T := System.Null_Address;
   Result             : Vk.Result_T;
begin
   Renderer.Color_Sample_Count := Samples;

   if MSAA_On and then not Create_Color_MSAA_Target (Renderer, Format, Samples) then
      return False;
   end if;

   Result :=
     Vk.Create_Render_Pass
       (device        => Renderer.Device,
        p_Create_Info => Render_Pass_Info'Address,
        p_Allocator   => System.Null_Address,
        p_Render_Pass => Render_Pass_Handle'Address);

   if Result /= Vk.SUCCESS or else Render_Pass_Handle = System.Null_Address then
      return False;
   end if;

   Renderer.Render_Pass := Render_Pass_Handle;

   for Index in 1 .. Natural (Renderer.Swapchain_Image_Count) loop
      declare
         View_Info : aliased Vk.Image_View_Create_Info_T :=
           (s_Type            => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            p_Next            => System.Null_Address,
            flags             => 0,
            image             => Renderer.Swapchain_Images (Index),
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
         View_Handle : aliased Vk.Image_View_T := System.Null_Address;
         FB_Views : aliased array (0 .. 1) of Vk.Image_View_T := [others => System.Null_Address];
         Framebuffer_Info : aliased Vk.Framebuffer_Create_Info_T;
         Framebuffer_Handle : aliased Vk.Framebuffer_T := System.Null_Address;
      begin
         Result :=
           Vk.Create_Image_View
             (device        => Renderer.Device,
              p_Create_Info => View_Info'Address,
              p_Allocator   => System.Null_Address,
              p_View        => View_Handle'Address);

         if Result /= Vk.SUCCESS or else View_Handle = System.Null_Address then
            return False;
         end if;

         Renderer.Image_Views (Index) := View_Handle;
         --  Attachment order must match the render pass: [0] colour target,
         --  [1] resolve. With MSAA the colour target is the shared multisampled
         --  image and the swapchain image is the resolve; without MSAA the
         --  swapchain image is the sole colour attachment.
         if MSAA_On then
            FB_Views (0) := Renderer.Color_MSAA_View;
            FB_Views (1) := View_Handle;
         else
            FB_Views (0) := View_Handle;
         end if;
         Framebuffer_Info :=
           (s_Type           => Vk.STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            p_Next           => System.Null_Address,
            flags            => 0,
            render_Pass      => Renderer.Render_Pass,
            attachment_Count => (if MSAA_On then 2 else 1),
            p_Attachments    => FB_Views (FB_Views'First)'Address,
            width            => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
            height           => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value),
            layers           => 1);
         Result :=
           Vk.Create_Framebuffer
             (device        => Renderer.Device,
              p_Create_Info => Framebuffer_Info'Address,
              p_Allocator   => System.Null_Address,
              p_Framebuffer => Framebuffer_Handle'Address);

         if Result /= Vk.SUCCESS or else Framebuffer_Handle = System.Null_Address then
            return False;
         end if;

         Renderer.Framebuffers (Index) := Framebuffer_Handle;
      end;
   end loop;

   Renderer.Render_Target_Count := Renderer.Swapchain_Image_Count;
   Renderer.Render_Targets_Live := Renderer.Render_Target_Count = Renderer.Swapchain_Image_Count;
   return Renderer.Render_Targets_Live;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Create_Render_Targets;
