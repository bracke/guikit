separate (Guikit.Vulkan)
function Diagnostics
  (Renderer : Vulkan_Renderer)
   return Renderer_Diagnostics is
begin
   return
     (Device_Ready          => Renderer.Device_Live,
      Surface_Ready         => Renderer.Surface_Live,
      Swapchain_Ready       => Renderer.Swapchain_Configured,
      Swapchain_Recreate    => Renderer.Swapchain_Pending,
      Render_Targets_Ready  => Renderer.Render_Targets_Live,
      Commands_Ready        => Renderer.Commands_Live,
      Sync_Ready            => Renderer.Sync_Live,
      Pipeline_Ready        => Renderer.Pipeline_Live,
      Descriptor_Ready      => Renderer.Descriptor_Live,
      Texture_Binding_Count => Renderer.Texture_Binding_Count,
      Mixed_Texture_Bindings_Ready =>
        Renderer.Descriptor_Live
        and then Renderer.Atlases (Text_Atlas).Binding = Binding_Current
        and then Renderer.Atlases (Icon_Atlas).Binding = Binding_Current,
      Vertex_Buffer_Ready   => Renderer.Vertex_Buffer_Live,
      Atlas_Texture_Ready   => Renderer.Atlases (Text_Atlas).Texture_Live,
      Icon_Atlas_Texture_Ready => Renderer.Atlases (Icon_Atlas).Texture_Live,
      Icon_Atlas_Upload_Failed => Renderer.Icon_Atlas_Failed,
      Presented_Frames      => Renderer.Presented_Frames,
      Skipped_Frames        => Renderer.Skipped_Frames,
      Failed_Frames         => Renderer.Failed_Frames,
      Last_Vertex_Count     => Renderer.Last_Vertex_Count,
      Last_Texture_Count    => Renderer.Last_Texture_Count,
      Last_Used_Mixed_Textures => Renderer.Last_Used_Mixed_Textures,
      Framebuffer_Readback_Enabled => Renderer.Readback_Enabled,
      Framebuffer_Readback_Ready => Renderer.Readback_Ready,
      Last_Framebuffer_Hash => Renderer.Last_Readback_Hash,
      Last_Framebuffer_Bytes => Renderer.Readback_Bytes,
      Submitted_Frames      => Renderer.Submitted_Frames,
      Last_Framebuffer_Frame => Renderer.Last_Readback_Frame,
      Framebuffer_Analysis  => Renderer.Last_Frame_Metrics,
      Framebuffer_Passed    => Renderer.Last_Frame_Passed,
      Frame_Width           => Renderer.Frame_Width_Value,
      Frame_Height          => Renderer.Frame_Height_Value,
      Pending_Frame_Width   => Renderer.Pending_Width_Value,
      Pending_Frame_Height  => Renderer.Pending_Height_Value,
      Last_Status           => Renderer.Last_Status,
      Last_Vk_Result        => Renderer.Last_Vk_Result,
      Physical_Device_Count => Renderer.Last_Physical_Devices);
end Diagnostics;
