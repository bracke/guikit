separate (Guikit.Vulkan)
function Create_Descriptor_Resources
  (Renderer : in out Vulkan_Renderer)
   return Boolean
is
   Binding : aliased Descriptor_Set_Layout_Binding_Array (1 .. 2) :=
     [1 =>
        (binding              => 0,
         descriptor_Type      => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
         descriptor_Count     => 1,
         stage_Flags          => Vk.SHADER_STAGE_FRAGMENT_BIT,
         p_Immutable_Samplers => System.Null_Address),
      2 =>
        (binding              => 1,
         descriptor_Type      => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
         descriptor_Count     => 1,
         stage_Flags          => Vk.SHADER_STAGE_FRAGMENT_BIT,
         p_Immutable_Samplers => System.Null_Address)];
   Layout_Info : aliased Vk.Descriptor_Set_Layout_Create_Info_T :=
     (s_Type        => Vk.STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
      p_Next        => System.Null_Address,
      flags         => 0,
      binding_Count => Interfaces.Unsigned_32 (Binding'Length),
      p_Bindings    => Binding'Address);
   Pool_Size : aliased Descriptor_Pool_Size_Array (1 .. 1) :=
     [1 =>
        (type_F           => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
         descriptor_Count => Interfaces.Unsigned_32 (Binding'Length))];
   Pool_Info : aliased Vk.Descriptor_Pool_Create_Info_T :=
     (s_Type          => Vk.STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
      p_Next          => System.Null_Address,
      flags           => 0,
      max_Sets        => 1,
      pool_Size_Count => 1,
      p_Pool_Sizes    => Pool_Size'Address);
   Layout_Handle : aliased Vk.Descriptor_Set_Layout_T := System.Null_Address;
   Pool_Handle   : aliased Vk.Descriptor_Pool_T := System.Null_Address;
   Set_Layouts   : aliased Descriptor_Set_Layout_Array_C (1 .. 1);
   Allocate_Info : aliased Vk.Descriptor_Set_Allocate_Info_T;
   Sets          : aliased Descriptor_Set_Array_C (1 .. 1);
   Result        : Vk.Result_T;
begin
   Result :=
     Vk.Create_Descriptor_Set_Layout
       (device        => Renderer.Device,
        p_Create_Info => Layout_Info'Address,
        p_Allocator   => System.Null_Address,
        p_Set_Layout  => Layout_Handle'Address);

   if Result /= Vk.SUCCESS or else Layout_Handle = System.Null_Address then
      return False;
   end if;

   Result :=
     Vk.Create_Descriptor_Pool
       (device            => Renderer.Device,
        p_Create_Info     => Pool_Info'Address,
        p_Allocator       => System.Null_Address,
        p_Descriptor_Pool => Pool_Handle'Address);

   if Result /= Vk.SUCCESS or else Pool_Handle = System.Null_Address then
      Vk.Destroy_Descriptor_Set_Layout (Renderer.Device, Layout_Handle, System.Null_Address);
      return False;
   end if;

   Set_Layouts := [1 => Layout_Handle];
   Allocate_Info :=
     (s_Type                => Vk.STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
      p_Next                => System.Null_Address,
      descriptor_Pool       => Pool_Handle,
      descriptor_Set_Count  => 1,
      p_Set_Layouts         => Set_Layouts'Address);
   Result :=
     Vk.Allocate_Descriptor_Sets
       (device              => Renderer.Device,
        p_Allocate_Info     => Allocate_Info'Address,
        p_Descriptor_Sets   => Sets'Address);

   if Result /= Vk.SUCCESS or else Sets (1) = System.Null_Address then
      Vk.Destroy_Descriptor_Pool (Renderer.Device, Pool_Handle, System.Null_Address);
      Vk.Destroy_Descriptor_Set_Layout (Renderer.Device, Layout_Handle, System.Null_Address);
      return False;
   end if;

   Renderer.Descriptor_Set_Layout := Layout_Handle;
   Renderer.Descriptor_Pool := Pool_Handle;
   Renderer.Descriptor_Set := Sets (1);
   Renderer.Descriptor_Live := True;
   Renderer.Texture_Binding_Count := Binding'Length;
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Create_Descriptor_Resources;
