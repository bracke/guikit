separate (Guikit.Vulkan)
procedure Shutdown
  (Renderer : in out Vulkan_Renderer) is
begin
   Destroy_Swapchain_Resources (Renderer);
   Release_Readback_Copy (Renderer);

   if Renderer.Surface_Live then
      Vk.Destroy_Surface_KHR
        (instance    => Renderer.Instance,
         surface     => Renderer.Surface,
         p_Allocator => System.Null_Address);
      Renderer.Surface := System.Null_Address;
      Renderer.Surface_Live := False;
   end if;

   Renderer.Swapchain_Configured := False;
   Renderer.Swapchain_Pending := False;
   Renderer.Frame_Width_Value := 0;
   Renderer.Frame_Height_Value := 0;
   Renderer.Queue_Family_Index := 0;
   Renderer.Pending_Width_Value := 0;
   Renderer.Pending_Height_Value := 0;
   Renderer.Presented_Frames := 0;
   Renderer.Skipped_Frames := 0;
   Renderer.Failed_Frames := 0;
   Renderer.Last_Vertex_Count := 0;

   if Renderer.Device_Live then
      Vk.Destroy_Device (device => Renderer.Device, p_Allocator => System.Null_Address);
      Renderer.Device := System.Null_Address;
      Renderer.Graphics_Queue := System.Null_Address;
      Renderer.Device_Live := False;
   end if;

   if Renderer.Instance_Live then
      Vk.Destroy_Instance (instance => Renderer.Instance, p_Allocator => System.Null_Address);
      Renderer.Instance := System.Null_Address;
      Renderer.Physical_Device := System.Null_Address;
      Renderer.Instance_Live := False;
   end if;

   if Renderer.Last_Status = Vulkan_Ready then
      Renderer.Last_Status := Vulkan_Not_Initialized;
   end if;

   Renderer.Init_Attempted := False;
   Renderer.Surface_Attempted := False;
end Shutdown;
