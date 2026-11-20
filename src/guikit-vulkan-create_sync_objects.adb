separate (Guikit.Vulkan)
function Create_Sync_Objects
  (Renderer : in out Vulkan_Renderer)
   return Boolean
is
   Semaphore_Info : aliased constant Vk.Semaphore_Create_Info_T :=
     (s_Type => Vk.STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
      p_Next => System.Null_Address,
      flags  => 0);
   Fence_Info : aliased constant Vk.Fence_Create_Info_T :=
     (s_Type => Vk.STRUCTURE_TYPE_FENCE_CREATE_INFO,
      p_Next => System.Null_Address,
      flags  => Vk.FENCE_CREATE_SIGNALED_BIT);
   Semaphore_Handle : aliased Vk.Semaphore_T := System.Null_Address;
   Fence_Handle     : aliased Vk.Fence_T := System.Null_Address;
   Result           : Vk.Result_T;
begin
   Destroy_Sync_Objects (Renderer);

   if not Renderer.Device_Live
     or else Renderer.Swapchain_Image_Count = 0
     or else Renderer.Swapchain_Image_Count > Interfaces.Unsigned_32 (Max_Swapchain_Images)
   then
      return False;
   end if;

   Result :=
     Vk.Create_Semaphore
       (device        => Renderer.Device,
        p_Create_Info => Semaphore_Info'Address,
        p_Allocator   => System.Null_Address,
        p_Semaphore   => Semaphore_Handle'Address);

   if Result /= Vk.SUCCESS or else Semaphore_Handle = System.Null_Address then
      Destroy_Sync_Objects (Renderer);
      return False;
   end if;
   Renderer.Image_Available := Semaphore_Handle;

   for Index in 1 .. Natural (Renderer.Swapchain_Image_Count) loop
      Semaphore_Handle := System.Null_Address;
      Result :=
        Vk.Create_Semaphore
          (device        => Renderer.Device,
           p_Create_Info => Semaphore_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Semaphore   => Semaphore_Handle'Address);

      if Result /= Vk.SUCCESS or else Semaphore_Handle = System.Null_Address then
         Destroy_Sync_Objects (Renderer);
         return False;
      end if;
      Renderer.Render_Finished (Index) := Semaphore_Handle;
   end loop;

   Result :=
     Vk.Create_Fence
       (device        => Renderer.Device,
        p_Create_Info => Fence_Info'Address,
        p_Allocator   => System.Null_Address,
        p_Fence       => Fence_Handle'Address);

   if Result /= Vk.SUCCESS or else Fence_Handle = System.Null_Address then
      Destroy_Sync_Objects (Renderer);
      return False;
   end if;
   Renderer.In_Flight := Fence_Handle;
   Renderer.Sync_Live := True;
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      Destroy_Sync_Objects (Renderer);
      return False;
end Create_Sync_Objects;
