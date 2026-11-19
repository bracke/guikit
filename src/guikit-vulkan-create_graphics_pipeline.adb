separate (Guikit.Vulkan)
function Create_Graphics_Pipeline
  (Renderer : in out Vulkan_Renderer)
   return Boolean
is
   --  The fixed-function state the pipeline is made with. The create infos
   --  point at one another, so they live here, for the whole call, and the
   --  Describe_ steps fill them in.
   Binding          : aliased Vertex_Binding_Array (1 .. 1);
   Attributes       : aliased Vertex_Attribute_Array (1 .. 5);
   Vertex_Input     : aliased Vk.Pipeline_Vertex_Input_State_Create_Info_T;
   Input_Assembly   : aliased Vk.Pipeline_Input_Assembly_State_Create_Info_T;
   Viewport         : aliased Vk.Viewport_T;
   Scissor          : aliased Vk.Rect2_D_T;
   Viewport_State   : aliased Vk.Pipeline_Viewport_State_Create_Info_T;
   Rasterization    : aliased Vk.Pipeline_Rasterization_State_Create_Info_T;
   Multisample      : aliased Vk.Pipeline_Multisample_State_Create_Info_T;
   Blend_Attachment : aliased Vk.Pipeline_Color_Blend_Attachment_State_T;
   Color_Blend      : aliased Vk.Pipeline_Color_Blend_State_Create_Info_T;
   Main_Name        : aliased Interfaces.C.char_array := Interfaces.C.To_C ("main");
   Stages           : aliased Shader_Stage_Array (1 .. 2);

   Vertex_Module   : aliased Vk.Shader_Module_T := System.Null_Address;
   Fragment_Module : aliased Vk.Shader_Module_T := System.Null_Address;
   Layout_Handle   : aliased Vk.Pipeline_Layout_T := System.Null_Address;
   Pipeline_Handle : aliased Vk.Pipeline_T := System.Null_Address;

   --  A shader module made from Code, or null when it cannot be made.
   function Shader_Module (Code : Shader_Code_Array) return Vk.Shader_Module_T is
      Info   : aliased Vk.Shader_Module_Create_Info_T :=
        (s_Type    => Vk.STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
         p_Next    => System.Null_Address,
         flags     => 0,
         code_Size => Interfaces.C.size_t (Code'Size / 8),
         p_Code    => Code (Code'First)'Address);
      Handle : aliased Vk.Shader_Module_T := System.Null_Address;
   begin
      if Vk.Create_Shader_Module
           (device          => Renderer.Device,
            p_Create_Info   => Info'Address,
            p_Allocator     => System.Null_Address,
            p_Shader_Module => Handle'Address) /= Vk.SUCCESS
      then
         return System.Null_Address;
      end if;
      return Handle;
   end Shader_Module;

   --  The pipeline layout: the one descriptor set the atlases are bound in.
   --  Null when it cannot be made.
   function Pipeline_Layout return Vk.Pipeline_Layout_T is
      Set_Layouts : aliased Descriptor_Set_Layout_Array_C (1 .. 1) := [1 => Renderer.Descriptor_Set_Layout];
      Info        : aliased Vk.Pipeline_Layout_Create_Info_T :=
        (s_Type                    => Vk.STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
         p_Next                    => System.Null_Address,
         flags                     => 0,
         set_Layout_Count          => 1,
         p_Set_Layouts             => Set_Layouts'Address,
         push_Constant_Range_Count => 0,
         p_Push_Constant_Ranges    => System.Null_Address);
      Handle      : aliased Vk.Pipeline_Layout_T := System.Null_Address;
   begin
      if Vk.Create_Pipeline_Layout
           (device            => Renderer.Device,
            p_Create_Info     => Info'Address,
            p_Allocator       => System.Null_Address,
            p_Pipeline_Layout => Handle'Address) /= Vk.SUCCESS
      then
         return System.Null_Address;
      end if;
      return Handle;
   end Pipeline_Layout;

   --  One binding of Gpu_Vertex records: position, texture coordinates,
   --  colour, and two floats choosing the texture.
   procedure Describe_Vertex_Input is
      Float_Bytes : constant Interfaces.Unsigned_32 := Interfaces.Unsigned_32 (Interfaces.C.C_float'Size / 8);
   begin
      Binding :=
        [1 =>
           (binding    => 0,
            stride     => Interfaces.Unsigned_32 (Gpu_Vertex_Size),
            input_Rate => Vk.VERTEX_INPUT_RATE_VERTEX)];
      Attributes :=
        [1 => (location => 0, binding => 0, format => Vk.FORMAT_R32G32_SFLOAT, offset => 0),
         2 => (location => 1, binding => 0, format => Vk.FORMAT_R32G32_SFLOAT, offset => 2 * Float_Bytes),
         3 => (location => 2, binding => 0, format => Vk.FORMAT_R32G32B32A32_SFLOAT, offset => 4 * Float_Bytes),
         4 => (location => 3, binding => 0, format => Vk.FORMAT_R32_SFLOAT, offset => 8 * Float_Bytes),
         5 => (location => 4, binding => 0, format => Vk.FORMAT_R32_SFLOAT, offset => 9 * Float_Bytes)];
      Vertex_Input :=
        (s_Type                             => Vk.STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
         p_Next                             => System.Null_Address,
         flags                              => 0,
         vertex_Binding_Description_Count   => 1,
         p_Vertex_Binding_Descriptions      => Binding'Address,
         vertex_Attribute_Description_Count => 5,
         p_Vertex_Attribute_Descriptions    => Attributes'Address);
      Input_Assembly :=
        (s_Type                   => Vk.STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         topology                 => Vk.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
         primitive_Restart_Enable => 0);
   end Describe_Vertex_Input;

   --  The whole frame, Y pointing down as the frame's pixels do.
   procedure Describe_Viewport is
      Framebuffer_Width  : constant Interfaces.C.C_float := Interfaces.C.C_float (Renderer.Frame_Width_Value);
      Framebuffer_Height : constant Interfaces.C.C_float := Interfaces.C.C_float (Renderer.Frame_Height_Value);
   begin
      Viewport :=
        (x         => 0.0,
         y         => Framebuffer_Height,
         width     => Framebuffer_Width,
         height    => -Framebuffer_Height,
         min_Depth => 0.0,
         max_Depth => 1.0);
      Scissor :=
        (offset => (x => 0, y => 0),
         extent =>
           (width  => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
            height => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value)));
      Viewport_State :=
        (s_Type         => Vk.STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
         p_Next         => System.Null_Address,
         flags          => 0,
         viewport_Count => 1,
         p_Viewports    => Viewport'Address,
         scissor_Count  => 1,
         p_Scissors     => Scissor'Address);
   end Describe_Viewport;

   --  Filled triangles, both faces, multisampled as the colour target is.
   procedure Describe_Rasterization is
   begin
      Rasterization :=
        (s_Type                     => Vk.STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
         p_Next                     => System.Null_Address,
         flags                      => 0,
         depth_Clamp_Enable         => 0,
         rasterizer_Discard_Enable  => 0,
         polygon_Mode               => Vk.POLYGON_MODE_FILL,
         cull_Mode                  => Vk.CULL_MODE_NONE,
         front_Face                 => Vk.FRONT_FACE_COUNTER_CLOCKWISE,
         depth_Bias_Enable          => 0,
         depth_Bias_Constant_Factor => 0.0,
         depth_Bias_Clamp           => 0.0,
         depth_Bias_Slope_Factor    => 0.0,
         line_Width                 => 1.0);
      Multisample :=
        (s_Type                   => Vk.STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         rasterization_Samples    => Renderer.Color_Sample_Count,
         sample_Shading_Enable    => 0,
         min_Sample_Shading       => 1.0,
         p_Sample_Mask            => System.Null_Address,
         alpha_To_Coverage_Enable => 0,
         alpha_To_One_Enable      => 0);
   end Describe_Rasterization;

   --  Straight-alpha blending over what is drawn before.
   procedure Describe_Blending is
   begin
      Blend_Attachment :=
        (blend_Enable           => 1,
         src_Color_Blend_Factor => Vk.BLEND_FACTOR_SRC_ALPHA,
         dst_Color_Blend_Factor => Vk.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
         color_Blend_Op         => Vk.BLEND_OP_ADD,
         src_Alpha_Blend_Factor => Vk.BLEND_FACTOR_ONE,
         dst_Alpha_Blend_Factor => Vk.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
         alpha_Blend_Op         => Vk.BLEND_OP_ADD,
         color_Write_Mask       =>
           Vk.COLOR_COMPONENT_R_BIT or Vk.COLOR_COMPONENT_G_BIT or
           Vk.COLOR_COMPONENT_B_BIT or Vk.COLOR_COMPONENT_A_BIT);
      Color_Blend :=
        (s_Type           => Vk.STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
         p_Next           => System.Null_Address,
         flags            => 0,
         logic_Op_Enable  => 0,
         logic_Op         => Vk.LOGIC_OP_COPY,
         attachment_Count => 1,
         p_Attachments    => Blend_Attachment'Address,
         blend_Constants  => [0.0, 0.0, 0.0, 0.0]);
   end Describe_Blending;

   --  The two shader stages, both entered at main.
   procedure Describe_Stages is
   begin
      Stages :=
        [1 =>
           (s_Type                => Vk.STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            p_Next                => System.Null_Address,
            flags                 => 0,
            stage                 => Vk.SHADER_STAGE_VERTEX_BIT,
            module                => Vertex_Module,
            p_Name                => Main_Name (Main_Name'First)'Address,
            p_Specialization_Info => System.Null_Address),
         2 =>
           (s_Type                => Vk.STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            p_Next                => System.Null_Address,
            flags                 => 0,
            stage                 => Vk.SHADER_STAGE_FRAGMENT_BIT,
            module                => Fragment_Module,
            p_Name                => Main_Name (Main_Name'First)'Address,
            p_Specialization_Info => System.Null_Address)];
   end Describe_Stages;

   --  Make the pipeline from the state described; False when it cannot be
   --  made.
   function Make_Pipeline return Boolean is
      Pipeline_Info : aliased Vk.Graphics_Pipeline_Create_Info_T :=
        (s_Type                 => Vk.STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
         p_Next                 => System.Null_Address,
         flags                  => 0,
         stage_Count            => 2,
         p_Stages               => Stages'Address,
         p_Vertex_Input_State   => Vertex_Input'Address,
         p_Input_Assembly_State => Input_Assembly'Address,
         p_Tessellation_State   => System.Null_Address,
         p_Viewport_State       => Viewport_State'Address,
         p_Rasterization_State  => Rasterization'Address,
         p_Multisample_State    => Multisample'Address,
         p_Depth_Stencil_State  => System.Null_Address,
         p_Color_Blend_State    => Color_Blend'Address,
         p_Dynamic_State        => System.Null_Address,
         layout                 => Layout_Handle,
         render_Pass            => Renderer.Render_Pass,
         subpass                => 0,
         base_Pipeline_Handle   => System.Null_Address,
         base_Pipeline_Index    => Interfaces.Integer_32'(-1));
   begin
      return
        Vk.Create_Graphics_Pipelines
          (device            => Renderer.Device,
           pipeline_Cache    => System.Null_Address,
           create_Info_Count => 1,
           p_Create_Infos    => Pipeline_Info'Address,
           p_Allocator       => System.Null_Address,
           p_Pipelines       => Pipeline_Handle'Address) = Vk.SUCCESS
        and then Pipeline_Handle /= System.Null_Address;
   end Make_Pipeline;

   --  The shader modules are only needed while the pipeline is made.
   procedure Destroy_Shader_Modules is
   begin
      if Fragment_Module /= System.Null_Address then
         Vk.Destroy_Shader_Module (Renderer.Device, Fragment_Module, System.Null_Address);
      end if;
      if Vertex_Module /= System.Null_Address then
         Vk.Destroy_Shader_Module (Renderer.Device, Vertex_Module, System.Null_Address);
      end if;
   end Destroy_Shader_Modules;

   Made : Boolean := False;
begin
   Vertex_Module := Shader_Module (Vertex_Shader_Code);
   Fragment_Module :=
     (if Vertex_Module = System.Null_Address then System.Null_Address else Shader_Module (Fragment_Shader_Code));
   if Fragment_Module /= System.Null_Address then
      Layout_Handle := Pipeline_Layout;
   end if;

   if Layout_Handle /= System.Null_Address then
      Describe_Vertex_Input;
      Describe_Viewport;
      Describe_Rasterization;
      Describe_Blending;
      Describe_Stages;
      Made := Make_Pipeline;
      if not Made then
         Destroy_Pipeline_Layout (Renderer.Device, Layout_Handle);
      end if;
   end if;
   Destroy_Shader_Modules;

   if Made then
      Renderer.Pipeline_Layout := Layout_Handle;
      Renderer.Graphics_Pipeline := Pipeline_Handle;
      Renderer.Pipeline_Live := True;
   end if;
   return Made;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      return False;
end Create_Graphics_Pipeline;
