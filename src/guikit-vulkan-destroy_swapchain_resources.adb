separate (Guikit.Vulkan)
procedure Destroy_Swapchain_Resources
  (Renderer       : in out Vulkan_Renderer;
   Keep_Swapchain : Boolean := False)
is
   --  The command buffers and their pool, and the vertex buffer.
   procedure Destroy_Commands_And_Vertices is
   begin
      if Renderer.Command_Buffer_Count > 0 and then Renderer.Command_Pool /= System.Null_Address then
         Vk.Free_Command_Buffers
           (device               => Renderer.Device,
            command_Pool         => Renderer.Command_Pool,
            command_Buffer_Count => Renderer.Command_Buffer_Count,
            p_Command_Buffers    => Renderer.Command_Buffers (Renderer.Command_Buffers'First)'Address);
      end if;
      Destroy_Command_Pool (Renderer.Device, Renderer.Command_Pool);

      Destroy_Buffer (Renderer.Device, Renderer.Vertex_Buffer);
      if Renderer.Vertex_Memory /= System.Null_Address then
         Free_Memory (Renderer.Device, Renderer.Vertex_Memory);
         Renderer.Uploaded_Vertices_Valid := False;
      end if;
   end Destroy_Commands_And_Vertices;

   --  Both atlases' staging buffers and textures, and the read-back buffer.
   procedure Destroy_Textures_And_Readback is
   begin
      for Kind in Atlas_Kind loop
         Atlas_Uploads.Release_Staging (Renderer, Kind);
         Atlas_Uploads.Release_Texture (Renderer, Kind);
      end loop;
      Destroy_Buffer (Renderer.Device, Renderer.Readback_Buffer);
      Free_Memory (Renderer.Device, Renderer.Readback_Memory);
   end Destroy_Textures_And_Readback;

   --  The pipeline, its layout and the descriptors it binds.
   procedure Destroy_Pipeline_And_Descriptors is
   begin
      Destroy_Pipeline (Renderer.Device, Renderer.Graphics_Pipeline);
      Destroy_Pipeline_Layout (Renderer.Device, Renderer.Pipeline_Layout);
      if Renderer.Descriptor_Pool /= System.Null_Address then
         Vk.Destroy_Descriptor_Pool
           (device          => Renderer.Device,
            descriptor_Pool => Renderer.Descriptor_Pool,
            p_Allocator     => System.Null_Address);
         Renderer.Descriptor_Pool := System.Null_Address;
         Renderer.Descriptor_Set := System.Null_Address;
      end if;
      Destroy_Descriptor_Set_Layout (Renderer.Device, Renderer.Descriptor_Set_Layout);
   end Destroy_Pipeline_And_Descriptors;

   --  The framebuffers, render pass, multisampled colour target and the
   --  swapchain images' views.
   procedure Destroy_Render_Targets is
   begin
      for Framebuffer of Renderer.Framebuffers loop
         Destroy_Framebuffer (Renderer.Device, Framebuffer);
      end loop;
      Destroy_Render_Pass (Renderer.Device, Renderer.Render_Pass);

      Destroy_Image_View (Renderer.Device, Renderer.Color_MSAA_View);
      Destroy_Image (Renderer.Device, Renderer.Color_MSAA_Image);
      Free_Memory (Renderer.Device, Renderer.Color_MSAA_Memory);
      Renderer.Color_MSAA_Live := False;

      for View of Renderer.Image_Views loop
         Destroy_Image_View (Renderer.Device, View);
      end loop;
   end Destroy_Render_Targets;

   --  Without a device there is nothing to destroy them on: forget the
   --  handles.
   procedure Forget_Handles is
   begin
      Renderer.Image_Available := System.Null_Address;
      Renderer.Render_Finished := [others => System.Null_Address];
      Renderer.In_Flight := System.Null_Address;
      Renderer.Swapchain := System.Null_Address;
      Renderer.Render_Pass := System.Null_Address;
      Renderer.Image_Views := [others => System.Null_Address];
      Renderer.Framebuffers := [others => System.Null_Address];
      Renderer.Command_Pool := System.Null_Address;
      Renderer.Pipeline_Layout := System.Null_Address;
      Renderer.Graphics_Pipeline := System.Null_Address;
      Renderer.Descriptor_Set_Layout := System.Null_Address;
      Renderer.Descriptor_Pool := System.Null_Address;
      Renderer.Descriptor_Set := System.Null_Address;
      Renderer.Vertex_Buffer := System.Null_Address;
      Renderer.Vertex_Memory := System.Null_Address;
      Renderer.Uploaded_Vertices_Valid := False;
      Renderer.Readback_Buffer := System.Null_Address;
      Renderer.Readback_Memory := System.Null_Address;
      Renderer.Sync_Live := False;
      Renderer.Swapchain_Live := False;
   end Forget_Handles;

   --  What the renderer records about the resources, now that none are
   --  left.
   procedure Reset_State is
   begin
      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Image_Count := 0;
      Renderer.Render_Target_Count := 0;
      Renderer.Command_Buffer_Count := 0;
      Renderer.Render_Targets_Live := False;
      Renderer.Descriptor_Live := False;
      Renderer.Texture_Binding_Count := 0;
      Renderer.Pipeline_Live := False;
      Renderer.Vertex_Buffer_Live := False;
      --  Each atlas's handles are destroyed or forgotten; its size,
      --  format and binding go with the descriptor set.
      Renderer.Atlases := [others => <>];
      Renderer.Commands_Live := False;
      Renderer.Swapchain_Images := [others => System.Null_Address];
      Renderer.Command_Buffers := [others => System.Null_Address];
      Renderer.Current_Image_Index := 0;
      Renderer.Vertex_Buffer_Capacity := 0;
      Renderer.Readback_Capacity := 0;
      Renderer.Readback_Bytes := 0;
      Renderer.Readback_Pending := False;
      Renderer.Readback_Ready := False;
      Renderer.Last_Readback_Hash := 0;
   end Reset_State;
begin
   if Renderer.Device_Live then
      --  Command buffers, pipelines, atlases and the swapchain images may
      --  all still be referenced by a submitted frame or a pending present.
      Wait_Device_Idle (Renderer);

      Destroy_Commands_And_Vertices;
      Destroy_Textures_And_Readback;
      Destroy_Pipeline_And_Descriptors;
      Destroy_Render_Targets;
      Destroy_Sync_Objects (Renderer);

      if Renderer.Swapchain_Live and then not Keep_Swapchain then
         Vk.Destroy_Swapchain_KHR
           (device      => Renderer.Device,
            swapchain   => Renderer.Swapchain,
            p_Allocator => System.Null_Address);
         Renderer.Swapchain := System.Null_Address;
         Renderer.Swapchain_Live := False;
      end if;
   else
      Forget_Handles;
   end if;

   Reset_State;
end Destroy_Swapchain_Resources;
