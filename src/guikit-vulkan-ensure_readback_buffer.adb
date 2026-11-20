separate (Guikit.Vulkan)
function Ensure_Readback_Buffer
  (Renderer : in out Vulkan_Renderer;
   Byte_Count : Natural)
   return Boolean
is
   Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
     (s_Type                   => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
      p_Next                   => System.Null_Address,
      flags                    => 0,
      size                     => Interfaces.Unsigned_64 (Byte_Count),
      usage                    => Vk.BUFFER_USAGE_TRANSFER_DST_BIT,
      sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
      queue_Family_Index_Count => 0,
      p_Queue_Family_Indices   => System.Null_Address);
   Buffer_Handle : aliased Vk.Buffer_T := System.Null_Address;
   Requirements  : aliased Vk.Memory_Requirements_T;
   Memory_Type   : Interfaces.Unsigned_32 := 0;
   Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
   Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
   Result        : Vk.Result_T;
begin
   if Byte_Count = 0 or else Byte_Count > Max_Readback_Bytes then
      return False;
   elsif Renderer.Readback_Buffer /= System.Null_Address
     and then Renderer.Readback_Memory /= System.Null_Address
     and then Renderer.Readback_Capacity >= Byte_Count
   then
      Renderer.Readback_Bytes := Byte_Count;
      return True;
   end if;

   if Renderer.Readback_Buffer /= System.Null_Address then
      Vk.Destroy_Buffer (Renderer.Device, Renderer.Readback_Buffer, System.Null_Address);
      Renderer.Readback_Buffer := System.Null_Address;
   end if;
   if Renderer.Readback_Memory /= System.Null_Address then
      Vk.Free_Memory (Renderer.Device, Renderer.Readback_Memory, System.Null_Address);
      Renderer.Readback_Memory := System.Null_Address;
   end if;

   Renderer.Readback_Capacity := 0;
   Renderer.Readback_Bytes := 0;
   Renderer.Readback_Pending := False;
   Renderer.Readback_Ready := False;
   Result :=
     Vk.Create_Buffer
       (device        => Renderer.Device,
        p_Create_Info => Buffer_Info'Address,
        p_Allocator   => System.Null_Address,
        p_Buffer      => Buffer_Handle'Address);

   if Result /= Vk.SUCCESS or else Buffer_Handle = System.Null_Address then
      return False;
   end if;

   Vk.Get_Buffer_Memory_Requirements
     (device                => Renderer.Device,
      buffer                => Buffer_Handle,
      p_Memory_Requirements => Requirements'Address);

   if not Host_Visible_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type, Prefer_Cached => True)
   then
      Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
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
      Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
      return False;
   end if;

   Result := Vk.Bind_Buffer_Memory (Renderer.Device, Buffer_Handle, Memory_Handle, 0);
   if Result /= Vk.SUCCESS then
      Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
      Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
      return False;
   end if;

   Renderer.Readback_Buffer := Buffer_Handle;
   Renderer.Readback_Memory := Memory_Handle;
   Renderer.Readback_Capacity := Byte_Count;
   Renderer.Readback_Bytes := Byte_Count;
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Ensure_Readback_Buffer;
