separate (Guikit.Vulkan)
function Initialize
  (Renderer : in out Vulkan_Renderer)
   return Vulkan_Status
is
   Extension_Count : Interfaces.Unsigned_32 := 0;
   Extension_Names : constant System.Address :=
     Glfw.Windows.Vulkan.Required_Instance_Extensions (Extension_Count);

   Instance_Handle : aliased Vk.Instance_T := System.Null_Address;
   Instance_Result : Vk.Result_T;

   Device_Count : aliased Interfaces.Unsigned_32 := 1;
   Physical     : aliased Vk.Physical_Device_T := System.Null_Address;
   Device_Result : Vk.Result_T;
begin
   Shutdown (Renderer);

   if Extension_Count = 0 or else Extension_Names = System.Null_Address then
      Renderer.Last_Status := Vulkan_Surface_Unsupported;
      return Renderer.Last_Status;
   end if;

   declare
      Required : constant Address_Array (1 .. Natural (Extension_Count))
        with Import, Address => Extension_Names;
      Portable : constant Boolean := Offers_Extension (System.Null_Address, Portability_Enumeration);
      Portability_Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Portability_Enumeration);
      Names : aliased Address_Array (1 .. Required'Length + 1) :=
        [for I in 1 .. Required'Length + 1 =>
           (if I <= Required'Length then Required (I)
            else Portability_Name (Portability_Name'First)'Address)];
      Instance_Info : aliased Vk.Instance_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => (if Portable then Create_Enumerate_Portability else 0),
         p_Application_Info       => System.Null_Address,
         enabled_Layer_Count      => 0,
         pp_Enabled_Layer_Names   => System.Null_Address,
         enabled_Extension_Count  => Extension_Count + (if Portable then 1 else 0),
         pp_Enabled_Extension_Names => Names'Address);
   begin
      Instance_Result :=
        Vk.Create_Instance
          (p_Create_Info => Instance_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Instance    => Instance_Handle'Address);
   end;

   if Instance_Result /= Vk.SUCCESS or else Instance_Handle = System.Null_Address then
      Renderer.Last_Status := Vulkan_Instance_Create_Failed;
      return Renderer.Last_Status;
   end if;

   Renderer.Instance := Instance_Handle;
   Renderer.Instance_Live := True;

   Device_Result :=
     Vk.Enumerate_Physical_Devices
       (instance         => Renderer.Instance,
        p_Physical_Device_Count => Device_Count'Address,
        p_Physical_Devices      => Physical'Address);
   Renderer.Last_Physical_Devices := Device_Count;

   if (Device_Result /= Vk.SUCCESS and then Device_Result /= Vk.INCOMPLETE)
     or else Device_Count = 0
     or else Physical = System.Null_Address
   then
      Vk.Destroy_Instance (instance => Renderer.Instance, p_Allocator => System.Null_Address);
      Renderer.Instance := System.Null_Address;
      Renderer.Instance_Live := False;
      Renderer.Last_Status := Vulkan_Device_Create_Failed;
      return Renderer.Last_Status;
   end if;

   declare
      Swapchain_Extension : aliased Interfaces.C.char_array :=
        Interfaces.C.To_C ("VK_KHR_swapchain");
      Subset_Extension    : aliased Interfaces.C.char_array := Interfaces.C.To_C (Portability_Subset);
      Subset              : constant Boolean := Offers_Extension (Physical, Portability_Subset);
      Extension_Names     : aliased Address_Array (1 .. 2) :=
        [Swapchain_Extension (Swapchain_Extension'First)'Address,
         Subset_Extension (Subset_Extension'First)'Address];
      Queue_Family        : constant Interfaces.Unsigned_32 :=
        Choose_Graphics_Queue_Family (Physical);
      Priority          : aliased Interfaces.C.C_float := 1.0;
      Queue_Create_Info : aliased Vk.Device_Queue_Create_Info_T :=
        (s_Type              => Vk.STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
         p_Next              => System.Null_Address,
         flags               => 0,
         queue_Family_Index  => Queue_Family,
         queue_Count         => 1,
         p_Queue_Priorities  => Priority'Address);
      Device_Info       : aliased Vk.Device_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_DEVICE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         queue_Create_Info_Count  => 1,
         p_Queue_Create_Infos     => Queue_Create_Info'Address,
         enabled_Layer_Count      => 0,
         pp_Enabled_Layer_Names   => System.Null_Address,
         enabled_Extension_Count  => (if Subset then 2 else 1),
         pp_Enabled_Extension_Names => Extension_Names'Address,
         p_Enabled_Features       => System.Null_Address);
      Device_Handle     : aliased Vk.Device_T := System.Null_Address;
      Queue_Handle      : aliased Vk.Queue_T := System.Null_Address;
   begin
      Device_Result :=
        Vk.Create_Device
          (physical_Device => Physical,
           p_Create_Info   => Device_Info'Address,
           p_Allocator     => System.Null_Address,
           p_Device        => Device_Handle'Address);

      if Device_Result /= Vk.SUCCESS or else Device_Handle = System.Null_Address then
         Vk.Destroy_Instance (instance => Renderer.Instance, p_Allocator => System.Null_Address);
         Renderer.Instance := System.Null_Address;
         Renderer.Physical_Device := System.Null_Address;
         Renderer.Instance_Live := False;
         Renderer.Last_Status := Vulkan_Device_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Renderer.Physical_Device := Physical;
      Renderer.Device := Device_Handle;
      Renderer.Queue_Family_Index := Queue_Family;
      Vk.Get_Device_Queue
        (device             => Renderer.Device,
         queue_Family_Index => Renderer.Queue_Family_Index,
         queue_Index        => 0,
         p_Queue            => Queue_Handle'Address);
      Renderer.Graphics_Queue := Queue_Handle;
   end;

   Renderer.Device_Live := True;
   Renderer.Last_Status := Vulkan_Ready;
   return Renderer.Last_Status;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      if Renderer.Device_Live then
         Vk.Destroy_Device (device => Renderer.Device, p_Allocator => System.Null_Address);
         Renderer.Device := System.Null_Address;
         Renderer.Graphics_Queue := System.Null_Address;
         Renderer.Device_Live := False;
      end if;

      if Renderer.Instance_Live then
         Vk.Destroy_Instance (instance => Renderer.Instance, p_Allocator => System.Null_Address);
         Renderer.Instance := System.Null_Address;
         Renderer.Instance_Live := False;
      end if;

      Renderer.Last_Status := Vulkan_Instance_Create_Failed;
      return Renderer.Last_Status;
end Initialize;
