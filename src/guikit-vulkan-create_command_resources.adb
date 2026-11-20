separate (Guikit.Vulkan)
function Create_Command_Resources
  (Renderer : in out Vulkan_Renderer)
   return Boolean
is
   Pool_Info : aliased Vk.Command_Pool_Create_Info_T :=
     (s_Type             => Vk.STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      p_Next             => System.Null_Address,
      flags              => 0,
      queue_Family_Index => Renderer.Queue_Family_Index);
   Pool_Handle : aliased Vk.Command_Pool_T := System.Null_Address;
   Buffers     : aliased Command_Buffer_Array_C (1 .. Max_Swapchain_Images);
   Allocate_Info : aliased Vk.Command_Buffer_Allocate_Info_T;
   Result      : Vk.Result_T;
begin
   Result :=
     Vk.Create_Command_Pool
       (device         => Renderer.Device,
        p_Create_Info  => Pool_Info'Address,
        p_Allocator    => System.Null_Address,
        p_Command_Pool => Pool_Handle'Address);

   if Result /= Vk.SUCCESS or else Pool_Handle = System.Null_Address then
      return False;
   end if;

   Renderer.Command_Pool := Pool_Handle;
   Allocate_Info :=
     (s_Type               => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      p_Next               => System.Null_Address,
      command_Pool         => Renderer.Command_Pool,
      level                => Vk.COMMAND_BUFFER_LEVEL_PRIMARY,
      command_Buffer_Count => Renderer.Render_Target_Count);
   Result :=
     Vk.Allocate_Command_Buffers
       (device            => Renderer.Device,
        p_Allocate_Info   => Allocate_Info'Address,
        p_Command_Buffers => Buffers (Buffers'First)'Address);

   if Result /= Vk.SUCCESS then
      return False;
   end if;

   for Index in 1 .. Natural (Renderer.Render_Target_Count) loop
      Renderer.Command_Buffers (Index) := Buffers (Index);
   end loop;

   Renderer.Command_Buffer_Count := Renderer.Render_Target_Count;
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Create_Command_Resources;
