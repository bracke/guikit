separate (Guikit.Vulkan)
function Ensure_Vertex_Buffer
  (Renderer : in out Vulkan_Renderer;
   Vertex_Count : Natural)
   return Boolean
is
   Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
     (s_Type                   => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
      p_Next                   => System.Null_Address,
      flags                    => 0,
      size                     => Gpu_Vertex_Buffer_Size,
      usage                    => Vk.BUFFER_USAGE_VERTEX_BUFFER_BIT,
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
   if Vertex_Count = 0 then
      return True;
   elsif Vertex_Count > Max_Batch_Vertices then
      return False;
   elsif Renderer.Vertex_Buffer_Live and then Renderer.Vertex_Buffer_Capacity >= Vertex_Count then
      return True;
   end if;

   if Renderer.Vertex_Buffer /= System.Null_Address then
      Vk.Destroy_Buffer
        (device      => Renderer.Device,
         buffer      => Renderer.Vertex_Buffer,
         p_Allocator => System.Null_Address);
      Renderer.Vertex_Buffer := System.Null_Address;
   end if;

   if Renderer.Vertex_Memory /= System.Null_Address then
      Vk.Free_Memory
        (device      => Renderer.Device,
         memory      => Renderer.Vertex_Memory,
         p_Allocator => System.Null_Address);
      Renderer.Vertex_Memory := System.Null_Address;
      Renderer.Uploaded_Vertices_Valid := False;
   end if;

   Renderer.Vertex_Buffer_Live := False;
   Renderer.Vertex_Buffer_Capacity := 0;
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

   if not Host_Visible_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
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

   Result :=
     Vk.Bind_Buffer_Memory
       (device        => Renderer.Device,
        buffer        => Buffer_Handle,
        memory        => Memory_Handle,
        memory_Offset => 0);

   if Result /= Vk.SUCCESS then
      Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
      Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
      return False;
   end if;

   Renderer.Vertex_Buffer := Buffer_Handle;
   Renderer.Vertex_Memory := Memory_Handle;
   Renderer.Uploaded_Vertices_Valid := False;
   Renderer.Vertex_Buffer_Capacity := Max_Batch_Vertices;
   Renderer.Vertex_Buffer_Live := True;
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Ensure_Vertex_Buffer;
