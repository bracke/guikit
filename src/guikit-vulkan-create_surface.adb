separate (Guikit.Vulkan)
function Create_Surface
  (Renderer : in out Vulkan_Renderer;
   Window   : not null access Glfw.Windows.Window)
   return Vulkan_Status
is
   Surface : Vk.Surface_KHR_T := System.Null_Address;
   Result  : Vk.Result_T;
begin
   if Renderer.Surface_Live then
      Renderer.Last_Status := Vulkan_Surface_Ready;
      return Renderer.Last_Status;
   end if;

   if not Renderer.Instance_Live then
      Renderer.Last_Status := Vulkan_Instance_Create_Failed;
      return Renderer.Last_Status;
   end if;

   if not Glfw.Windows.Vulkan.Supported then
      Renderer.Last_Status := Vulkan_Surface_Unsupported;
      return Renderer.Last_Status;
   end if;

   Result :=
     Glfw.Windows.Vulkan.Create_Surface
       (Window   => Window,
        Instance => Renderer.Instance,
        Surface  => Surface);

   if Result = Vk.SUCCESS and then Surface /= System.Null_Address then
      Renderer.Surface := Surface;
      Renderer.Surface_Live := True;
      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Pending := False;
      Renderer.Frame_Width_Value := 0;
      Renderer.Frame_Height_Value := 0;
      Renderer.Pending_Width_Value := 0;
      Renderer.Pending_Height_Value := 0;
      Renderer.Last_Status := Vulkan_Surface_Ready;
   else
      Renderer.Surface := System.Null_Address;
      Renderer.Surface_Live := False;
      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Pending := False;
      Renderer.Frame_Width_Value := 0;
      Renderer.Frame_Height_Value := 0;
      Renderer.Pending_Width_Value := 0;
      Renderer.Pending_Height_Value := 0;
      Renderer.Last_Status := Vulkan_Surface_Create_Failed;
   end if;

   return Renderer.Last_Status;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      Renderer.Surface := System.Null_Address;
      Renderer.Surface_Live := False;
      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Pending := False;
      Renderer.Frame_Width_Value := 0;
      Renderer.Frame_Height_Value := 0;
      Renderer.Pending_Width_Value := 0;
      Renderer.Pending_Height_Value := 0;
      Renderer.Last_Status := Vulkan_Surface_Create_Failed;
      return Renderer.Last_Status;
end Create_Surface;
