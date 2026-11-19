separate (Guikit.Vulkan)
function Record_Command_Buffers
  (Renderer     : in out Vulkan_Renderer;
   Vertex_Count : Natural;
   Only_Image   : Natural := 0)
   return Boolean
is
   First : constant Positive := (if Only_Image = 0 then 1 else Only_Image);
   Last  : constant Natural :=
     (if Only_Image = 0 then Natural (Renderer.Command_Buffer_Count) else Only_Image);

   --  Record copying a texture's staging buffer into its image, with the
   --  layout transitions around the copy: Initialized tells whether the
   --  image already holds an earlier upload the shaders read.
   procedure Record_Texture_Upload
     (Buffer      : Vk.Command_Buffer_T;
      Image       : Vk.Image_T;
      Staging     : Vk.Buffer_T;
      Initialized : Boolean;
      Width       : Natural;
      Height      : Natural)
   is
      To_Transfer : aliased Vk.Image_Memory_Barrier_T :=
        (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
         p_Next                 => System.Null_Address,
         src_Access_Mask        =>
           (if Initialized then Vk.ACCESS_SHADER_READ_BIT else 0),
         dst_Access_Mask        => Vk.ACCESS_TRANSFER_WRITE_BIT,
         old_Layout             =>
           (if Initialized
            then Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
            else Vk.IMAGE_LAYOUT_UNDEFINED),
         new_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
         src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
         dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
         image                  => Image,
         subresource_Range      =>
           (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
            base_Mip_Level   => 0,
            level_Count      => 1,
            base_Array_Layer => 0,
            layer_Count      => 1));
      Copy_Region : aliased Vk.Buffer_Image_Copy_T :=
        (buffer_Offset       => 0,
         buffer_Row_Length   => 0,
         buffer_Image_Height => 0,
         image_Subresource   =>
           (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
            mip_Level        => 0,
            base_Array_Layer => 0,
            layer_Count      => 1),
         image_Offset        => (x => 0, y => 0, z => 0),
         image_Extent        =>
           (width  => Interfaces.Unsigned_32 (Width),
            height => Interfaces.Unsigned_32 (Height),
            depth  => 1));
      To_Shader : aliased Vk.Image_Memory_Barrier_T :=
        (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
         p_Next                 => System.Null_Address,
         src_Access_Mask        => Vk.ACCESS_TRANSFER_WRITE_BIT,
         dst_Access_Mask        => Vk.ACCESS_SHADER_READ_BIT,
         old_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
         new_Layout             => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
         src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
         dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
         image                  => Image,
         subresource_Range      =>
           (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
            base_Mip_Level   => 0,
            level_Count      => 1,
            base_Array_Layer => 0,
            layer_Count      => 1));
   begin
      Vk.Cmd_Pipeline_Barrier
        (command_Buffer              => Buffer,
         src_Stage_Mask              =>
           (if Initialized
            then Vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT
            else Vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT),
         dst_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
         dependency_Flags            => 0,
         memory_Barrier_Count        => 0,
         p_Memory_Barriers           => System.Null_Address,
         buffer_Memory_Barrier_Count => 0,
         p_Buffer_Memory_Barriers    => System.Null_Address,
         image_Memory_Barrier_Count  => 1,
         p_Image_Memory_Barriers     => To_Transfer'Address);
      Vk.Cmd_Copy_Buffer_To_Image
        (command_Buffer   => Buffer,
         src_Buffer       => Staging,
         dst_Image        => Image,
         dst_Image_Layout => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
         region_Count     => 1,
         p_Regions        => Copy_Region'Address);
      Vk.Cmd_Pipeline_Barrier
        (command_Buffer              => Buffer,
         src_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
         dst_Stage_Mask              => Vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
         dependency_Flags            => 0,
         memory_Barrier_Count        => 0,
         p_Memory_Barriers           => System.Null_Address,
         buffer_Memory_Barrier_Count => 0,
         p_Buffer_Memory_Barriers    => System.Null_Address,
         image_Memory_Barrier_Count  => 1,
         p_Image_Memory_Barriers     => To_Shader'Address);
   end Record_Texture_Upload;

   --  Record the draw of the vertex buffer's first Vertex_Count vertices,
   --  with the atlas descriptor set bound when there is one.
   procedure Record_Draw (Buffer : Vk.Command_Buffer_T) is
      Vertex_Buffers : aliased Buffer_Array_C (1 .. 1) := [1 => Renderer.Vertex_Buffer];
      Vertex_Offsets : aliased Buffer_Offset_Array_C (1 .. 1) := [1 => 0];
   begin
      Vk.Cmd_Bind_Pipeline
        (command_Buffer      => Buffer,
         pipeline_Bind_Point => Vk.PIPELINE_BIND_POINT_GRAPHICS,
         pipeline            => Renderer.Graphics_Pipeline);
      if Renderer.Descriptor_Live and then Renderer.Atlases (Text_Atlas).Texture_Live then
         declare
            Sets : aliased Descriptor_Set_Array_C (1 .. 1) := [1 => Renderer.Descriptor_Set];
         begin
            Vk.Cmd_Bind_Descriptor_Sets
              (command_Buffer        => Buffer,
               pipeline_Bind_Point   => Vk.PIPELINE_BIND_POINT_GRAPHICS,
               layout                => Renderer.Pipeline_Layout,
               first_Set             => 0,
               descriptor_Set_Count  => 1,
               p_Descriptor_Sets     => Sets'Address,
               dynamic_Offset_Count  => 0,
               p_Dynamic_Offsets     => System.Null_Address);
         end;
      end if;
      Vk.Cmd_Bind_Vertex_Buffers
        (command_Buffer => Buffer,
         first_Binding  => 0,
         binding_Count  => 1,
         p_Buffers      => Vertex_Buffers'Address,
         p_Offsets      => Vertex_Offsets'Address);
      Vk.Cmd_Draw
        (command_Buffer => Buffer,
         vertex_Count   => Interfaces.Unsigned_32 (Vertex_Count),
         instance_Count => 1,
         first_Vertex   => 0,
         first_Instance => 0);
   end Record_Draw;

   --  Record copying swapchain image Index into the readback buffer, and
   --  handing it back for presenting.
   procedure Record_Readback (Buffer : Vk.Command_Buffer_T; Index : Positive) is
      To_Transfer : aliased Vk.Image_Memory_Barrier_T :=
        (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
         p_Next                 => System.Null_Address,
         src_Access_Mask        => Vk.ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
         dst_Access_Mask        => Vk.ACCESS_TRANSFER_READ_BIT,
         old_Layout             => Image_Layout_Present_Src_KHR,
         new_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
         src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
         dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
         image                  => Renderer.Swapchain_Images (Index),
         subresource_Range      =>
           (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
            base_Mip_Level   => 0,
            level_Count      => 1,
            base_Array_Layer => 0,
            layer_Count      => 1));
      Copy_Region : aliased Vk.Buffer_Image_Copy_T :=
        (buffer_Offset       => 0,
         buffer_Row_Length   => 0,
         buffer_Image_Height => 0,
         image_Subresource   =>
           (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
            mip_Level        => 0,
            base_Array_Layer => 0,
            layer_Count      => 1),
         image_Offset        => (x => 0, y => 0, z => 0),
         image_Extent        =>
           (width  => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
            height => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value),
            depth  => 1));
      To_Present : aliased Vk.Image_Memory_Barrier_T :=
        (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
         p_Next                 => System.Null_Address,
         src_Access_Mask        => Vk.ACCESS_TRANSFER_READ_BIT,
         dst_Access_Mask        => 0,
         old_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
         new_Layout             => Image_Layout_Present_Src_KHR,
         src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
         dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
         image                  => Renderer.Swapchain_Images (Index),
         subresource_Range      =>
           (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
            base_Mip_Level   => 0,
            level_Count      => 1,
            base_Array_Layer => 0,
            layer_Count      => 1));
   begin
      Vk.Cmd_Pipeline_Barrier
        (command_Buffer              => Buffer,
         src_Stage_Mask              => Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
         dst_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
         dependency_Flags            => 0,
         memory_Barrier_Count        => 0,
         p_Memory_Barriers           => System.Null_Address,
         buffer_Memory_Barrier_Count => 0,
         p_Buffer_Memory_Barriers    => System.Null_Address,
         image_Memory_Barrier_Count  => 1,
         p_Image_Memory_Barriers     => To_Transfer'Address);
      Vk.Cmd_Copy_Image_To_Buffer
        (command_Buffer   => Buffer,
         src_Image        => Renderer.Swapchain_Images (Index),
         src_Image_Layout => Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
         dst_Buffer       => Renderer.Readback_Buffer,
         region_Count     => 1,
         p_Regions        => Copy_Region'Address);
      Vk.Cmd_Pipeline_Barrier
        (command_Buffer              => Buffer,
         src_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
         dst_Stage_Mask              => Vk.PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
         dependency_Flags            => 0,
         memory_Barrier_Count        => 0,
         p_Memory_Barriers           => System.Null_Address,
         buffer_Memory_Barrier_Count => 0,
         p_Buffer_Memory_Barriers    => System.Null_Address,
         image_Memory_Barrier_Count  => 1,
         p_Image_Memory_Barriers     => To_Present'Address);
   end Record_Readback;

   --  Record command buffer Index: the pending atlas uploads, the render
   --  pass with its draw, and the readback copy when one is wanted. False
   --  when the buffer cannot be begun or ended.
   function Record_Buffer (Index : Positive) return Boolean is
      Buffer : constant Vk.Command_Buffer_T := Renderer.Command_Buffers (Index);
      Clear : aliased Vk.Clear_Value_T :=
        (Kind  => 0,
         color =>
           (Kind    => 0,
            float32 => [0.08, 0.09, 0.10, 1.0]));
      Begin_Info : aliased Vk.Command_Buffer_Begin_Info_T :=
        (s_Type             => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
         p_Next             => System.Null_Address,
         flags              => 0,
         p_Inheritance_Info => System.Null_Address);
      Render_Info : aliased Vk.Render_Pass_Begin_Info_T :=
        (s_Type            => Vk.STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
         p_Next            => System.Null_Address,
         render_Pass       => Renderer.Render_Pass,
         framebuffer       => Renderer.Framebuffers (Index),
         render_Area       =>
           (offset => (x => 0, y => 0),
            extent =>
              (width  => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
               height => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value))),
         clear_Value_Count => 1,
         p_Clear_Values    => Clear'Address);
      Result : Vk.Result_T;
   begin
      Result :=
        Vk.Begin_Command_Buffer
          (command_Buffer => Buffer,
           p_Begin_Info   => Begin_Info'Address);

      if Result /= Vk.SUCCESS then
         return False;
      end if;

      if Renderer.Atlases (Text_Atlas).Upload_Pending
        and then Renderer.Atlases (Text_Atlas).Texture_Live
        and then Renderer.Atlases (Text_Atlas).Staging_Live
      then
         Record_Texture_Upload
           (Buffer      => Buffer,
            Image       => Renderer.Atlases (Text_Atlas).Image,
            Staging     => Renderer.Atlases (Text_Atlas).Staging_Buffer,
            Initialized => Renderer.Atlases (Text_Atlas).Initialized,
            Width       => Renderer.Atlases (Text_Atlas).Width,
            Height      => Renderer.Atlases (Text_Atlas).Height);
      end if;

      if Renderer.Atlases (Icon_Atlas).Upload_Pending
        and then Renderer.Atlases (Icon_Atlas).Texture_Live
        and then Renderer.Atlases (Icon_Atlas).Staging_Live
      then
         Record_Texture_Upload
           (Buffer      => Buffer,
            Image       => Renderer.Atlases (Icon_Atlas).Image,
            Staging     => Renderer.Atlases (Icon_Atlas).Staging_Buffer,
            Initialized => Renderer.Atlases (Icon_Atlas).Initialized,
            Width       => Renderer.Atlases (Icon_Atlas).Width,
            Height      => Renderer.Atlases (Icon_Atlas).Height);
      end if;

      Vk.Cmd_Begin_Render_Pass
        (command_Buffer      => Buffer,
         p_Render_Pass_Begin => Render_Info'Address,
         contents            => Vk.SUBPASS_CONTENTS_INLINE);

      if Vertex_Count > 0 and then Renderer.Pipeline_Live and then Renderer.Vertex_Buffer_Live then
         Record_Draw (Buffer);
      end if;

      Vk.Cmd_End_Render_Pass (Buffer);

      if Renderer.Readback_Enabled
        and then Renderer.Readback_Buffer /= System.Null_Address
        and then Renderer.Readback_Bytes > 0
        and then Renderer.Readback_Bytes <= Max_Readback_Bytes
      then
         Record_Readback (Buffer, Index);
      end if;

      Result := Vk.End_Command_Buffer (Buffer);
      return Result = Vk.SUCCESS;
   end Record_Buffer;
begin
   if Vk.Reset_Command_Pool (Renderer.Device, Renderer.Command_Pool, 0) /= Vk.SUCCESS then
      return False;
   end if;

   for Index in First .. Last loop
      if not Record_Buffer (Index) then
         return False;
      end if;
   end loop;

   if Renderer.Atlases (Text_Atlas).Upload_Pending then
      Renderer.Atlases (Text_Atlas).Initialized := True;
      Renderer.Atlases (Text_Atlas).Upload_Pending := False;
   end if;
   if Renderer.Atlases (Icon_Atlas).Upload_Pending then
      Renderer.Atlases (Icon_Atlas).Initialized := True;
      Renderer.Atlases (Icon_Atlas).Upload_Pending := False;
   end if;

   Renderer.Commands_Live := Renderer.Command_Buffer_Count = Renderer.Render_Target_Count;
   return Renderer.Commands_Live;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Record_Command_Buffers;
