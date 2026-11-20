with Guikit.Errors;
with Ada.Containers.Hashed_Maps;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings.Hash;
with Ada.Unchecked_Deallocation;

with Interfaces.C;
with Glfw.Windows.Hints;
with Glfw.Windows.Vulkan;
with System.Address_To_Access_Conversions;

package body Guikit.Vulkan is
   use Ada.Strings.Unbounded;
   use type Interfaces.C.C_float;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;
   use type System.Address;
   use type Guikit.Draw.Text_Render_Status;
   use type Guikit.Draw.Icon_Command_Vectors.Vector;
   use type Guikit.Draw.Icon_Class;
   use type Vk.Result_T;
   use type Vk.Format_T;
   use type Vk.Color_Space_KHR_T;

   Structure_Type_Swapchain_Create_Info_KHR : constant Vk.Structure_Type_T :=
     Vk.Structure_Type_T (1_000_001_000);
   Structure_Type_Present_Info_KHR : constant Vk.Structure_Type_T :=
     Vk.Structure_Type_T (1_000_001_001);
   Suboptimal_KHR : constant Vk.Result_T := Vk.Result_T (1_000_001_003);
   Error_Out_Of_Date_KHR : constant Vk.Result_T := Vk.Result_T (-1_000_001_004);
   Image_Layout_Present_Src_KHR : constant Vk.Image_Layout_T := Vk.Image_Layout_T (1_000_001_002);
   Max_Surface_Formats : constant Positive := 32;
   Max_Batch_Vertices : constant Positive := 65_536;
   Max_Atlas_Bytes : constant Positive := Guikit.Draw.Max_Atlas_Bytes;
   Max_Readback_Bytes : constant Positive := 33_554_432;
   Icon_Atlas_Tile_Size : constant Positive := 64;
   Icon_Atlas_Channels : constant Positive := 4;
   Max_Icon_Atlas_Tiles : constant Positive :=
     Max_Atlas_Bytes / (Icon_Atlas_Tile_Size * Icon_Atlas_Tile_Size * Icon_Atlas_Channels);
   --  A large (e.g. Quick Look) image icon gets a tile up to this many pixels per
   --  side instead of the 64-pixel icon tile, so it renders crisply. Bounded so
   --  the icon atlas stays within Max_Atlas_Bytes.
   Max_Overlay_Tile : constant Positive := 512;
   Max_Atlas_Dimension : constant Positive := 16_384;

   --  Placement of one icon's tile within the icon atlas. When every tile is the
   --  64-pixel icon size the tiles form the historical single-row strip; a large
   --  image tile switches the layout to a compact shelf pack.
   type Icon_Tile_Rect is record
      X : Natural := 0;
      Y : Natural := 0;
      W : Natural := 0;
      H : Natural := 0;
   end record;
   package Icon_Tile_Rect_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Icon_Tile_Rect);

   package Natural_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Natural);

   function Hash_Unbounded (Key : Ada.Strings.Unbounded.Unbounded_String)
     return Ada.Containers.Hash_Type
   is (Ada.Strings.Hash (Ada.Strings.Unbounded.To_String (Key)));

   --  Which tile an icon draws from, keyed by what decides its pixels.
   package Tile_Slot_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Ada.Strings.Unbounded.Unbounded_String,
      Element_Type    => Positive,
      Hash            => Hash_Unbounded,
      Equivalent_Keys => Ada.Strings.Unbounded."=");
   Infinite_Timeout : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64'Last;
   Format_R8G8B8A8_Unorm : constant Vk.Format_T := Vk.Format_T (37);
   Format_R8G8B8A8_Srgb  : constant Vk.Format_T := Vk.Format_T (43);

   --  Raw GLFW bindings for window hints and the event pump.
   GLFW_Client_API : constant Interfaces.C.int := 16#0002_2001#;
   GLFW_No_API     : constant Interfaces.C.int := 0;

   procedure Set_Raw_Window_Hint (Target : Interfaces.C.int; Hint : Interfaces.C.int)
     with Import, Convention => C, External_Name => "glfwWindowHint";

   procedure Raw_Poll_Events
     with Import, Convention => C, External_Name => "glfwPollEvents";

   procedure Raw_Wait_Events_Timeout (Timeout : Interfaces.C.double)
     with Import, Convention => C, External_Name => "glfwWaitEventsTimeout";

   procedure Configure_Window_Hints
     (Resizable : Boolean := True;
      Visible   : Boolean := False) is
   begin
      Glfw.Windows.Hints.Reset_To_Defaults;
      Set_Raw_Window_Hint (GLFW_Client_API, GLFW_No_API);
      Glfw.Windows.Hints.Set_Resizable (Resizable);
      Glfw.Windows.Hints.Set_Visible (Visible);
   end Configure_Window_Hints;

   procedure Poll_Events is
   begin
      Raw_Poll_Events;
   end Poll_Events;

   procedure Wait_For_Events (Timeout : Duration) is
   begin
      Raw_Wait_Events_Timeout (Interfaces.C.double (Timeout));
   end Wait_For_Events;

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural is
   begin
      if Factor = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Natural'Last;
      else
         return Value * Factor;
      end if;
   end Saturating_Multiply;

   function Scaled_Down
     (Value       : Natural;
      Numerator   : Positive;
      Denominator : Positive)
      return Natural is
   begin
      return
        Saturating_Add
          (Saturating_Multiply (Value / Denominator, Numerator),
           Saturating_Multiply (Value mod Denominator, Numerator) / Denominator);
   end Scaled_Down;

   function Bounded_Product_Divide
     (Value       : Natural;
      Factor      : Natural;
      Denominator : Positive)
      return Natural is
   begin
      if Factor = 0 or else Value = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Scaled_Down (Value, Factor, Denominator);
      else
         return (Value * Factor) / Denominator;
      end if;
   end Bounded_Product_Divide;

   --  Whether the backend draws an icon from its atlas, rather than the
   --  consumer having drawn it already (Guikit.Draw.Icon_Class).
   function Is_Atlas_Icon
     (Icon : Guikit.Draw.Icon_Command)
      return Boolean is
     (Icon.Class = Guikit.Draw.Atlas_Icon);

   type Gpu_Vertex is record
      X : Interfaces.C.C_float := 0.0;
      Y : Interfaces.C.C_float := 0.0;
      U : Interfaces.C.C_float := 0.0;
      V : Interfaces.C.C_float := 0.0;
      R : Interfaces.C.C_float := 0.0;
      G : Interfaces.C.C_float := 0.0;
      B : Interfaces.C.C_float := 0.0;
      A : Interfaces.C.C_float := 1.0;
      Textured : Interfaces.C.C_float := 0.0;
      Texture : Interfaces.C.C_float := 0.0;
   end record
     with Convention => C;

   type Gpu_Vertex_Buffer_Array is array (Positive range 1 .. Max_Batch_Vertices) of aliased Gpu_Vertex
     with Convention => C;

   package Gpu_Vertex_Buffer_Conversions is new System.Address_To_Access_Conversions (Gpu_Vertex_Buffer_Array);

   type Byte_Array is array (Positive range 1 .. Max_Atlas_Bytes) of aliased Interfaces.Unsigned_8
     with Convention => C;

   package Byte_Array_Conversions is new System.Address_To_Access_Conversions (Byte_Array);

   type Readback_Byte_Array is array (Positive range 1 .. Max_Readback_Bytes) of aliased Interfaces.Unsigned_8
     with Convention => C;

   package Readback_Byte_Array_Conversions is new System.Address_To_Access_Conversions (Readback_Byte_Array);

   Fallback_Atlas_Pixel : aliased Interfaces.Unsigned_8 := 255;

   --  Destroy Handle on Device with Destroy, unless it is null, and leave it
   --  null: one of these for each kind of handle a renderer tears down.
   generic
      with procedure Destroy (Device : Vk.Device_T; Handle : System.Address; Allocator : System.Address);
   procedure Destroy_Handle (Device : Vk.Device_T; Handle : in out System.Address);

   procedure Destroy_Handle (Device : Vk.Device_T; Handle : in out System.Address) is
   begin
      if Handle /= System.Null_Address then
         Destroy (Device, Handle, System.Null_Address);
         Handle := System.Null_Address;
      end if;
   end Destroy_Handle;

   procedure Destroy_Buffer is new Destroy_Handle (Vk.Destroy_Buffer);
   procedure Free_Memory is new Destroy_Handle (Vk.Free_Memory);
   procedure Destroy_Image is new Destroy_Handle (Vk.Destroy_Image);
   procedure Destroy_Image_View is new Destroy_Handle (Vk.Destroy_Image_View);
   procedure Destroy_Sampler is new Destroy_Handle (Vk.Destroy_Sampler);
   procedure Destroy_Pipeline is new Destroy_Handle (Vk.Destroy_Pipeline);
   procedure Destroy_Pipeline_Layout is new Destroy_Handle (Vk.Destroy_Pipeline_Layout);
   procedure Destroy_Descriptor_Set_Layout is new Destroy_Handle (Vk.Destroy_Descriptor_Set_Layout);
   procedure Destroy_Framebuffer is new Destroy_Handle (Vk.Destroy_Framebuffer);
   procedure Destroy_Render_Pass is new Destroy_Handle (Vk.Destroy_Render_Pass);
   procedure Destroy_Command_Pool is new Destroy_Handle (Vk.Destroy_Command_Pool);

   Gpu_Vertex_Size : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (Gpu_Vertex'Size / 8);
   Gpu_Vertex_Buffer_Size : constant Interfaces.Unsigned_64 :=
     Interfaces.Unsigned_64 (Max_Batch_Vertices) * Gpu_Vertex_Size;

   type Shader_Code_Array is array (Positive range <>) of aliased Interfaces.Unsigned_32
     with Convention => C;

   Vertex_Shader_Code : aliased constant Shader_Code_Array :=
     [119734787, 65536, 524299, 43, 0, 131089, 1, 393227, 1, 1280527431,
      1685353262, 808793134, 0, 196622, 0, 1, 983055, 0, 4, 1852399981, 0, 13,
      18, 28, 29, 31, 33, 36, 38, 40, 41, 196611, 2, 450, 262149, 4,
      1852399981, 0, 393221, 11, 1348430951, 1700164197, 2019914866, 0,
      393222, 11, 0, 1348430951, 1953067887, 7237481, 458758, 11, 1,
      1348430951, 1953393007, 1702521171, 0, 458758, 11, 2, 1130327143,
      1148217708, 1635021673, 6644590, 458758, 11, 3, 1130327143, 1147956341,
      1635021673, 6644590, 196613, 13, 0, 262149, 18, 1885302377, 29551,
      262149, 28, 1601467759, 30325, 262149, 29, 1969188457, 118, 327685, 31,
      1601467759, 1869377379, 114, 327685, 33, 1667198569, 1919904879, 0,
      393221, 36, 1601467759, 1954047348, 1684370037, 0, 327685, 38,
      1952411241, 1970567269, 6579570, 458757, 40, 1601467759, 1954047348,
      1600483957, 1920298867, 25955, 458757, 41, 1952411241, 1970567269,
      1935631730, 1668445551, 101, 196679, 11, 2, 327752, 11, 0, 11, 0,
      327752, 11, 1, 11, 1, 327752, 11, 2, 11, 3, 327752, 11, 3, 11, 4,
      262215, 18, 30, 0, 262215, 28, 30, 0, 262215, 29, 30, 1, 262215, 31, 30,
      1, 262215, 33, 30, 2, 262215, 36, 30, 2, 262215, 38, 30, 3, 262215, 40,
      30, 3, 262215, 41, 30, 4, 131091, 2, 196641, 3, 2, 196630, 6, 32,
      262167, 7, 6, 4, 262165, 8, 32, 0, 262187, 8, 9, 1, 262172, 10, 6, 9,
      393246, 11, 7, 6, 10, 10, 262176, 12, 3, 11, 262203, 12, 13, 3, 262165,
      14, 32, 1, 262187, 14, 15, 0, 262167, 16, 6, 2, 262176, 17, 1, 16,
      262203, 17, 18, 1, 262187, 6, 20, 0, 262187, 6, 21, 1065353216, 262176,
      25, 3, 7, 262176, 27, 3, 16, 262203, 27, 28, 3, 262203, 17, 29, 1,
      262203, 25, 31, 3, 262176, 32, 1, 7, 262203, 32, 33, 1, 262176, 35, 3,
      6, 262203, 35, 36, 3, 262176, 37, 1, 6, 262203, 37, 38, 1, 262203, 35,
      40, 3, 262203, 37, 41, 1, 327734, 2, 4, 0, 3, 131320, 5, 262205, 16, 19,
      18, 327761, 6, 22, 19, 0, 327761, 6, 23, 19, 1, 458832, 7, 24, 22, 23,
      20, 21, 327745, 25, 26, 13, 15, 196670, 26, 24, 262205, 16, 30, 29,
      196670, 28, 30, 262205, 7, 34, 33, 196670, 31, 34, 262205, 6, 39, 38,
      196670, 36, 39, 262205, 6, 42, 41, 196670, 40, 42, 65789, 65592];

   Fragment_Shader_Code : aliased constant Shader_Code_Array :=
     [119734787, 65536, 524299, 74, 0, 131089, 1, 393227, 1, 1280527431,
      1685353262, 808793134, 0, 196622, 0, 1, 655375, 4, 4, 1852399981, 0, 11,
      14, 21, 35, 72, 196624, 4, 7, 196611, 2, 450, 262149, 4, 1852399981, 0,
      262149, 9, 1869377379, 114, 327685, 11, 1667198569, 1919904879, 0,
      327685, 14, 1952411241, 1970567269, 6579570, 458757, 21, 1952411241,
      1970567269, 1935631730, 1668445551, 101, 393221, 27, 1886216563,
      1667196268, 1919904879, 0, 327685, 31, 1852793705, 1819566431, 29537,
      262149, 35, 1969188457, 118, 262149, 54, 1752198241, 97, 327685, 55,
      1954047348, 1819566431, 29537, 327685, 72, 1601467759, 1869377379, 114,
      262215, 11, 30, 1, 262215, 14, 30, 2, 262215, 21, 30, 3, 262215, 31, 33,
      1, 262215, 31, 34, 0, 262215, 35, 30, 0, 262215, 55, 33, 0, 262215, 55,
      34, 0, 262215, 72, 30, 0, 131091, 2, 196641, 3, 2, 196630, 6, 32,
      262167, 7, 6, 4, 262176, 8, 7, 7, 262176, 10, 1, 7, 262203, 10, 11, 1,
      262176, 13, 1, 6, 262203, 13, 14, 1, 262187, 6, 16, 1056964608, 131092,
      17, 262203, 13, 21, 1, 262187, 6, 23, 1069547520, 589849, 28, 6, 1, 0,
      0, 0, 1, 0, 196635, 29, 28, 262176, 30, 0, 29, 262203, 30, 31, 0,
      262167, 33, 6, 2, 262176, 34, 1, 33, 262203, 34, 35, 1, 262167, 38, 6,
      3, 262165, 41, 32, 0, 262187, 41, 42, 3, 262176, 43, 7, 6, 262203, 30,
      55, 0, 262187, 41, 59, 0, 262176, 71, 3, 7, 262203, 71, 72, 3, 327734,
      2, 4, 0, 3, 131320, 5, 262203, 8, 9, 7, 262203, 8, 27, 7, 262203, 43,
      54, 7, 262205, 7, 12, 11, 196670, 9, 12, 262205, 6, 15, 14, 327866, 17,
      18, 15, 16, 196855, 20, 0, 262394, 18, 19, 20, 131320, 19, 262205, 6,
      22, 21, 327866, 17, 24, 22, 23, 196855, 26, 0, 262394, 24, 25, 53,
      131320, 25, 262205, 29, 32, 31, 262205, 33, 36, 35, 327767, 7, 37, 32,
      36, 196670, 27, 37, 262205, 7, 39, 27, 524367, 38, 40, 39, 39, 0, 1, 2,
      327745, 43, 44, 27, 42, 262205, 6, 45, 44, 327745, 13, 46, 11, 42,
      262205, 6, 47, 46, 327813, 6, 48, 45, 47, 327761, 6, 49, 40, 0, 327761,
      6, 50, 40, 1, 327761, 6, 51, 40, 2, 458832, 7, 52, 49, 50, 51, 48,
      196670, 9, 52, 131321, 26, 131320, 53, 262205, 29, 56, 55, 262205, 33,
      57, 35, 327767, 7, 58, 56, 57, 327761, 6, 60, 58, 0, 327745, 13, 61, 11,
      42, 262205, 6, 62, 61, 327813, 6, 63, 60, 62, 196670, 54, 63, 262205, 7,
      64, 11, 524367, 38, 65, 64, 64, 0, 1, 2, 262205, 6, 66, 54, 327761, 6,
      67, 65, 0, 327761, 6, 68, 65, 1, 327761, 6, 69, 65, 2, 458832, 7, 70,
      67, 68, 69, 66, 196670, 9, 70, 131321, 26, 131320, 26, 131321, 20,
      131320, 20, 262205, 7, 73, 9, 196670, 72, 73, 65789, 65592];

   type Surface_Format_Array is array (Positive range <>) of aliased Vk.Surface_Format_KHR_T
     with Convention => C;

   type Swapchain_Array is array (Positive range <>) of aliased Vk.Swapchain_KHR_T
     with Convention => C;

   type Image_Index_Array is array (Positive range <>) of aliased Interfaces.Unsigned_32
     with Convention => C;

   type Semaphore_Array is array (Positive range <>) of aliased Vk.Semaphore_T
     with Convention => C;

   type Queue_Family_Array is array (Positive range <>) of aliased Vk.Queue_Family_Properties_T
     with Convention => C;

   type Address_Array is array (Positive range <>) of aliased System.Address
     with Convention => C;

   type Image_Array is array (Positive range <>) of aliased Vk.Image_T
     with Convention => C;

   type Command_Buffer_Array_C is array (Positive range <>) of aliased Vk.Command_Buffer_T
     with Convention => C;

   type Fence_Array_C is array (Positive range <>) of aliased Vk.Fence_T
     with Convention => C;

   type Buffer_Array_C is array (Positive range <>) of aliased Vk.Buffer_T
     with Convention => C;

   type Buffer_Offset_Array_C is array (Positive range <>) of aliased Interfaces.Unsigned_64
     with Convention => C;

   type Shader_Stage_Array is array (Positive range <>) of aliased Vk.Pipeline_Shader_Stage_Create_Info_T
     with Convention => C;

   type Vertex_Binding_Array is array (Positive range <>) of aliased Vk.Vertex_Input_Binding_Description_T
     with Convention => C;

   type Vertex_Attribute_Array is array (Positive range <>) of aliased Vk.Vertex_Input_Attribute_Description_T
     with Convention => C;

   type Descriptor_Set_Array_C is array (Positive range <>) of aliased Vk.Descriptor_Set_T
     with Convention => C;

   type Descriptor_Set_Layout_Array_C is array (Positive range <>) of aliased Vk.Descriptor_Set_Layout_T
     with Convention => C;

   type Descriptor_Set_Layout_Binding_Array is array
     (Positive range <>) of aliased Vk.Descriptor_Set_Layout_Binding_T
     with Convention => C;

   type Descriptor_Pool_Size_Array is array (Positive range <>) of aliased Vk.Descriptor_Pool_Size_T
     with Convention => C;

   function Clamp
     (Value : Interfaces.Unsigned_32;
      Low   : Interfaces.Unsigned_32;
      High  : Interfaces.Unsigned_32)
      return Interfaces.Unsigned_32;

   function Choose_Graphics_Queue_Family
     (Physical : Vk.Physical_Device_T)
      return Interfaces.Unsigned_32;

   --  Destroy everything built on the device for the current swapchain,
   --  after waiting for the device to go idle so nothing still in use by the
   --  GPU is freed. Keep_Swapchain leaves the swapchain handle itself alive
   --  so that Create_Swapchain_Resources can hand it on as oldSwapchain.
   procedure Destroy_Swapchain_Resources
     (Renderer       : in out Vulkan_Renderer;
      Keep_Swapchain : Boolean := False);

   function Create_Render_Targets
     (Renderer : in out Vulkan_Renderer;
      Format   : Vk.Format_T)
      return Boolean;

   function Create_Graphics_Pipeline
     (Renderer : in out Vulkan_Renderer)
      return Boolean;

   function Create_Descriptor_Resources
     (Renderer : in out Vulkan_Renderer)
      return Boolean;

   function Create_Command_Resources
     (Renderer : in out Vulkan_Renderer)
      return Boolean;

   function Ensure_Vertex_Buffer
     (Renderer : in out Vulkan_Renderer;
      Vertex_Count : Natural)
      return Boolean;

   --  Copy Batch's vertices into the vertex buffer. With Hide_Icons, each
   --  vertex sampling the icon atlas is collapsed onto one point, so its
   --  triangles cover nothing and the rest of the frame is drawn without
   --  them (an icon atlas that could not be uploaded).
   function Upload_Vertices
     (Renderer   : in out Vulkan_Renderer;
      Batch      : Submission_Batch;
      Hide_Icons : Boolean)
      return Boolean;

   function Upload_Atlas
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean;

   function Upload_Icon_Atlas
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean;

   function Ensure_Readback_Buffer
     (Renderer : in out Vulkan_Renderer;
      Byte_Count : Natural)
      return Boolean;

   procedure Capture_Completed_Readback
     (Renderer : in out Vulkan_Renderer);

   procedure Free_Retained_Frame is new Ada.Unchecked_Deallocation
     (Object => Guikit.Frame_Analysis.Byte_Array,
      Name   => Retained_Frame_Access);

   --  Release the retained read-back framebuffer copy, if any.
   procedure Release_Readback_Copy
     (Renderer : in out Vulkan_Renderer);

   function Record_Command_Buffers
     (Renderer     : in out Vulkan_Renderer;
      Vertex_Count : Natural;
      Only_Image   : Natural := 0)
      return Boolean;

   function Create_Swapchain_Resources
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Vulkan_Status;

   function Color_To_Vertex
     (Color : Guikit.Draw.Render_Color;
      Theme : Guikit.Draw.Theme_Kind := Guikit.Draw.Theme_Dark)
      return Gpu_Vertex;

   function Host_Visible_Memory_Type
     (Renderer         : Vulkan_Renderer;
      Memory_Type_Bits : Interfaces.Unsigned_32;
      Memory_Type      : out Interfaces.Unsigned_32;
      Prefer_Cached    : Boolean := False)
      return Boolean;

   function Any_Memory_Type
     (Renderer         : Vulkan_Renderer;
      Memory_Type_Bits : Interfaces.Unsigned_32;
      Memory_Type      : out Interfaces.Unsigned_32)
      return Boolean;

   --  The steps uploading pixels into either atlas texture (Atlas_Kind)
   --  takes: the glyph atlas (Upload_Atlas) and the icon atlas
   --  (Upload_Icon_Atlas) share them.
   package Atlas_Uploads is

      --  Destroy the atlas's image, memory, view and sampler: it has no
      --  texture until the next upload makes one. A binding that named the
      --  destroyed view is marked stale, except that the icon binding is
      --  pointed at the text atlas's live view (Binding_Fallback) when the
      --  text binding is current, so the set stays bindable; releasing the
      --  text atlas also marks an icon binding that fell back to it stale.
      procedure Release_Texture (Renderer : in out Vulkan_Renderer; Kind : Atlas_Kind);

      --  Destroy the atlas's staging buffer and its memory: the next upload
      --  makes another.
      procedure Release_Staging (Renderer : in out Vulkan_Renderer; Kind : Atlas_Kind);

      --  Copy Bytes bytes of pixels into the atlas through its staging
      --  buffer and point its descriptor binding at it: the texture is made
      --  again when it is not Width by Height in Format, the staging buffer
      --  when it is smaller than Bytes. Fill writes the pixels into the
      --  mapped staging memory. The command buffers copy them into the
      --  image (Upload_Pending). Binding the text atlas also points the
      --  icon binding at the text atlas's view whenever the icon atlas has
      --  no current binding of its own (Binding_Fallback), so the fragment
      --  shader's icon sampler never names an unwritten or destroyed view.
      --  False when a step fails: the texture is then left released, never
      --  half made, and its binding handled as Release_Texture says.
      function Upload
        (Renderer : in out Vulkan_Renderer;
         Kind     : Atlas_Kind;
         Width    : Positive;
         Height   : Positive;
         Format   : Atlas_Texture_Format;
         Bytes    : Positive;
         Fill     : not null access procedure (Target : Byte_Array_Conversions.Object_Pointer))
         return Boolean
        with Pre => Bytes <= Max_Atlas_Bytes;

   end Atlas_Uploads;

   package body Atlas_Uploads is separate;

   function Clamp
     (Value : Interfaces.Unsigned_32;
      Low   : Interfaces.Unsigned_32;
      High  : Interfaces.Unsigned_32)
      return Interfaces.Unsigned_32 is
   begin
      if Value < Low then
         return Low;
      elsif High /= 0 and then Value > High then
         return High;
      else
         return Value;
      end if;
   end Clamp;

   function Choose_Graphics_Queue_Family
     (Physical : Vk.Physical_Device_T)
      return Interfaces.Unsigned_32
   is
      Count : aliased Interfaces.Unsigned_32 := 0;
      Properties : Queue_Family_Array (1 .. 32);
   begin
      Vk.Get_Physical_Device_Queue_Family_Properties
        (physical_Device               => Physical,
         p_Queue_Family_Property_Count => Count'Address,
         p_Queue_Family_Properties     => System.Null_Address);

      if Count = 0 then
         return 0;
      end if;

      if Count > Properties'Length then
         Count := Properties'Length;
      end if;

      Vk.Get_Physical_Device_Queue_Family_Properties
        (physical_Device               => Physical,
         p_Queue_Family_Property_Count => Count'Address,
         p_Queue_Family_Properties     => Properties (Properties'First)'Address);

      for Index in 1 .. Natural (Count) loop
         if (Properties (Index).queue_Flags and Vk.QUEUE_GRAPHICS_BIT) /= 0
           and then Properties (Index).queue_Count > 0
         then
            return Interfaces.Unsigned_32 (Index - 1);
         end if;
      end loop;

      return 0;
   end Choose_Graphics_Queue_Family;

   function Color_To_Vertex
     (Color : Guikit.Draw.Render_Color;
      Theme : Guikit.Draw.Theme_Kind := Guikit.Draw.Theme_Dark)
      return Gpu_Vertex
   is
      function Pow (Base : Float; Exponent : Float) return Float is
        (Ada.Numerics.Elementary_Functions.Exp
           (Exponent * Ada.Numerics.Elementary_Functions.Log (Base)));

      function To_Linear (S : Interfaces.C.C_float) return Interfaces.C.C_float is
         F : constant Float := Float (S);
      begin
         if F <= 0.04045 then
            return Interfaces.C.C_float (F / 12.92);
         else
            return Interfaces.C.C_float (Pow ((F + 0.055) / 1.055, 2.4));
         end if;
      end To_Linear;

      --  Palette color roles resolve to sRGB channels in Guikit.Draw.Color_For;
      --  the sRGB-to-linear conversion stays here in the Vulkan backend.
      Palette : constant Guikit.Draw.Palette_Color :=
        Guikit.Draw.Color_For (Color, Theme);
   begin
      return
        (X        => 0.0,
         Y        => 0.0,
         U        => 0.0,
         V        => 0.0,
         R        => To_Linear (Interfaces.C.C_float (Palette.R)),
         G        => To_Linear (Interfaces.C.C_float (Palette.G)),
         B        => To_Linear (Interfaces.C.C_float (Palette.B)),
         A        => Interfaces.C.C_float (Palette.A),
         Textured => 0.0,
         Texture  => 0.0);
   end Color_To_Vertex;

   --  Prefer_Cached asks first for memory the CPU reads through its cache.
   --  Memory that is only host-visible is uncached on a real GPU, where
   --  reading a frame back from it byte by byte takes over a second.
   function Host_Visible_Memory_Type
     (Renderer         : Vulkan_Renderer;
      Memory_Type_Bits : Interfaces.Unsigned_32;
      Memory_Type      : out Interfaces.Unsigned_32;
      Prefer_Cached    : Boolean := False)
      return Boolean
   is
      Properties : aliased Vk.Physical_Device_Memory_Properties_T;
      Required   : constant Interfaces.Unsigned_32 :=
        Vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT or Vk.MEMORY_PROPERTY_HOST_COHERENT_BIT;
      Cached     : constant Interfaces.Unsigned_32 := Required or Vk.MEMORY_PROPERTY_HOST_CACHED_BIT;
      type Flag_List is array (Positive range <>) of Interfaces.Unsigned_32;
      Wanted_Flags : constant Flag_List := (if Prefer_Cached then [Cached, Required] else [1 => Required]);
   begin
      Vk.Get_Physical_Device_Memory_Properties
        (physical_Device     => Renderer.Physical_Device,
         p_Memory_Properties => Properties'Address);

      for Wanted of Wanted_Flags loop
         for Index in 0 .. Natural (Properties.memory_Type_Count) - 1 loop
            if (Memory_Type_Bits and Interfaces.Shift_Left (Interfaces.Unsigned_32'(1), Index)) /= 0
              and then (Properties.memory_Types (Index).property_Flags and Wanted) = Wanted
            then
               Memory_Type := Interfaces.Unsigned_32 (Index);
               return True;
            end if;
         end loop;
      end loop;

      Memory_Type := 0;
      return False;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, "Guikit.Vulkan");
         return False;
   end Host_Visible_Memory_Type;

   function Any_Memory_Type
     (Renderer         : Vulkan_Renderer;
      Memory_Type_Bits : Interfaces.Unsigned_32;
      Memory_Type      : out Interfaces.Unsigned_32)
      return Boolean
   is
      Properties : aliased Vk.Physical_Device_Memory_Properties_T;
   begin
      Vk.Get_Physical_Device_Memory_Properties
        (physical_Device     => Renderer.Physical_Device,
         p_Memory_Properties => Properties'Address);

      for Index in 0 .. Natural (Properties.memory_Type_Count) - 1 loop
         if (Memory_Type_Bits and Interfaces.Shift_Left (Interfaces.Unsigned_32'(1), Index)) /= 0 then
            Memory_Type := Interfaces.Unsigned_32 (Index);
            return True;
         end if;
      end loop;

      return False;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, "Guikit.Vulkan");
         return False;
   end Any_Memory_Type;

   --  Pick the multisample count for the colour target: the highest of 8x/4x/2x
   --  the device supports for framebuffer colour attachments, else 1x (no
   --  anti-aliasing). Any query failure falls back safely to 1x.
   function Choose_Color_Sample_Count
     (Renderer : Vulkan_Renderer)
      return Vk.Sample_Count_Flag_Bits_T
   is
      Properties : aliased Vk.Physical_Device_Properties_T;
      Counts     : Vk.Sample_Count_Flags_T;
   begin
      Vk.Get_Physical_Device_Properties (Renderer.Physical_Device, Properties'Address);
      Counts := Properties.limits.framebuffer_Color_Sample_Counts;
      if (Counts and Vk.SAMPLE_COUNT_8_BIT) /= 0 then
         return Vk.SAMPLE_COUNT_8_BIT;
      elsif (Counts and Vk.SAMPLE_COUNT_4_BIT) /= 0 then
         return Vk.SAMPLE_COUNT_4_BIT;
      elsif (Counts and Vk.SAMPLE_COUNT_2_BIT) /= 0 then
         return Vk.SAMPLE_COUNT_2_BIT;
      else
         return Vk.SAMPLE_COUNT_1_BIT;
      end if;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, "Guikit.Vulkan");
         return Vk.SAMPLE_COUNT_1_BIT;
   end Choose_Color_Sample_Count;

   --  Create the multisampled colour image the frame renders into before it is
   --  resolved to the (single-sample) swapchain image. Stores the image/memory/
   --  view on the renderer; returns False (and cleans up) on any failure.
   function Create_Color_MSAA_Target
     (Renderer : in out Vulkan_Renderer;
      Format   : Vk.Format_T;
      Samples  : Vk.Sample_Count_Flag_Bits_T)
      return Boolean
   is separate;

   --  Block until the device has finished all queued work. The result is not
   --  acted on: a lost device has no work left either, and every caller goes
   --  on to destroy or rebuild what it was about to.
   procedure Wait_Device_Idle
     (Renderer : Vulkan_Renderer) is
   begin
      if Renderer.Device_Live then
         declare
            Ignored_Result : constant Vk.Result_T := Vk.Device_Wait_Idle (Renderer.Device);
            pragma Unreferenced (Ignored_Result);
         begin
            null;
         end;
      end if;
   end Wait_Device_Idle;

   --  Destroy the frame synchronisation objects. The caller makes sure the
   --  device no longer uses them (Wait_Device_Idle).
   procedure Destroy_Sync_Objects
     (Renderer : in out Vulkan_Renderer) is
   begin
      if Renderer.Device_Live then
         if Renderer.In_Flight /= System.Null_Address then
            Vk.Destroy_Fence
              (device      => Renderer.Device,
               fence       => Renderer.In_Flight,
               p_Allocator => System.Null_Address);
         end if;

         for Index in Renderer.Render_Finished'Range loop
            if Renderer.Render_Finished (Index) /= System.Null_Address then
               Vk.Destroy_Semaphore
                 (device      => Renderer.Device,
                  semaphore   => Renderer.Render_Finished (Index),
                  p_Allocator => System.Null_Address);
            end if;
         end loop;

         if Renderer.Image_Available /= System.Null_Address then
            Vk.Destroy_Semaphore
              (device      => Renderer.Device,
               semaphore   => Renderer.Image_Available,
               p_Allocator => System.Null_Address);
         end if;
      end if;

      Renderer.In_Flight := System.Null_Address;
      Renderer.Render_Finished := [others => System.Null_Address];
      Renderer.Image_Available := System.Null_Address;
      Renderer.Sync_Live := False;
   end Destroy_Sync_Objects;

   --  Create fresh frame synchronisation objects for the current swapchain:
   --  one image-available semaphore, one render-finished semaphore per
   --  swapchain image and the in-flight fence, created signalled so the first
   --  frame's wait returns at once. Any objects already there are destroyed
   --  first. On failure nothing is left behind and Sync_Live stays False.
   function Create_Sync_Objects
     (Renderer : in out Vulkan_Renderer)
      return Boolean
   is separate;

   procedure Destroy_Swapchain_Resources
     (Renderer       : in out Vulkan_Renderer;
      Keep_Swapchain : Boolean := False)
   is separate;

   procedure Set_Readback_Enabled
     (Renderer : in out Vulkan_Renderer;
      Enabled  : Boolean) is
   begin
      Renderer.Readback_Enabled := Enabled;
      if not Enabled then
         Renderer.Readback_Pending := False;
         Renderer.Readback_Ready := False;
         Renderer.Readback_Bytes := 0;
         Renderer.Last_Readback_Hash := 0;
      end if;
   end Set_Readback_Enabled;

   function Readback_Enabled (Renderer : Vulkan_Renderer) return Boolean is
   begin
      return Renderer.Readback_Enabled;
   end Readback_Enabled;

   function Create_Render_Targets
     (Renderer : in out Vulkan_Renderer;
      Format   : Vk.Format_T)
      return Boolean
   is separate;

   function Create_Graphics_Pipeline
     (Renderer : in out Vulkan_Renderer)
      return Boolean is separate;

   function Create_Descriptor_Resources
     (Renderer : in out Vulkan_Renderer)
      return Boolean
   is separate;

   function Create_Command_Resources
     (Renderer : in out Vulkan_Renderer)
      return Boolean
   is separate;

   function Ensure_Vertex_Buffer
     (Renderer : in out Vulkan_Renderer;
      Vertex_Count : Natural)
      return Boolean
   is separate;

   function Upload_Vertices
     (Renderer   : in out Vulkan_Renderer;
      Batch      : Submission_Batch;
      Hide_Icons : Boolean)
      return Boolean
   is separate;

   function Ensure_Readback_Buffer
     (Renderer : in out Vulkan_Renderer;
      Byte_Count : Natural)
      return Boolean
   is separate;

   procedure Capture_Completed_Readback
     (Renderer : in out Vulkan_Renderer)
   is separate;

   procedure Release_Readback_Copy
     (Renderer : in out Vulkan_Renderer) is
   begin
      Free_Retained_Frame (Renderer.Readback_Copy);
      Renderer.Readback_Copy := null;
      Renderer.Readback_Copy_Length := 0;
      Renderer.Readback_Copy_Width := 0;
      Renderer.Readback_Copy_Height := 0;
   end Release_Readback_Copy;

   function Readback_Region_Ink_Fraction
     (Renderer : Vulkan_Renderer;
      X        : Natural;
      Y        : Natural;
      W        : Natural;
      H        : Natural)
      return Float is
   begin
      if Renderer.Readback_Copy = null
        or else not Renderer.Readback_Ready
        or else Renderer.Readback_Copy_Width = 0
        or else Renderer.Readback_Copy_Height = 0
      then
         return 0.0;
      end if;

      return Frame_Analysis.Region_Ink_Fraction
        (Data   => Renderer.Readback_Copy.all,
         Width  => Renderer.Readback_Copy_Width,
         Height => Renderer.Readback_Copy_Height,
         Format => Frame_Analysis.Pixel_Format_RGBA8,
         X      => X,
         Y      => Y,
         W      => W,
         H      => H);
   end Readback_Region_Ink_Fraction;

   function Readback_Region_Has_Ink
     (Renderer     : Vulkan_Renderer;
      X            : Natural;
      Y            : Natural;
      W            : Natural;
      H            : Natural;
      Min_Fraction : Float :=
        Guikit.Frame_Analysis.Default_Region_Ink_Fraction)
      return Boolean is
   begin
      return Readback_Region_Ink_Fraction (Renderer, X, Y, W, H) >= Min_Fraction;
   end Readback_Region_Has_Ink;

   function Upload_Atlas
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean is separate;

   function Upload_Icon_Atlas
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean
   is separate;

   function Icon_Upload_Texture_Format
     (Batch : Submission_Batch)
      return Atlas_Texture_Format is
   begin
      if not Batch.Icon_Atlas_Dirty then
         return Atlas_Texture_None;
      elsif Batch.Icon_Atlas_Channels = 4 then
         return Atlas_Texture_RGBA8;
      else
         return Atlas_Texture_R8;
      end if;
   end Icon_Upload_Texture_Format;

   --  Only_Image names the one buffer a frame will submit; 0 records them all.
   function Record_Command_Buffers
     (Renderer     : in out Vulkan_Renderer;
      Vertex_Count : Natural;
      Only_Image   : Natural := 0)
      return Boolean is separate;

   function Create_Swapchain_Resources
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Vulkan_Status is separate;

   --  Drivers layered over another API (MoltenVK on macOS) implement only a
   --  portability subset of Vulkan. The loader hides them unless the instance
   --  asks for them with this extension and flag, and a device that offers the
   --  subset extension must have it enabled.
   Portability_Enumeration : constant String := "VK_KHR_portability_enumeration";
   Portability_Subset      : constant String := "VK_KHR_portability_subset";
   Create_Enumerate_Portability : constant Vk.Instance_Create_Flags_T := 16#0000_0001#;

   type Extension_Property_Array is array (Positive range <>) of aliased Vk.Extension_Properties_T
     with Convention => C;

   function Has_Extension (Properties : Extension_Property_Array; Name : String) return Boolean is
   begin
      for Item of Properties loop
         if Interfaces.C.To_Ada (Interfaces.C.char_array (Item.extension_Name)) = Name then
            return True;
         end if;
      end loop;
      return False;
   end Has_Extension;

   --  Whether the instance (Physical = null) or the device offers Name.
   function Offers_Extension (Physical : Vk.Physical_Device_T; Name : String) return Boolean is
      Count  : aliased Interfaces.Unsigned_32 := 0;
      Result : Vk.Result_T;
   begin
      Result :=
        (if Physical = System.Null_Address
         then Vk.Enumerate_Instance_Extension_Properties (System.Null_Address, Count'Address, System.Null_Address)
         else Vk.Enumerate_Device_Extension_Properties
                (Physical, System.Null_Address, Count'Address, System.Null_Address));
      if Result /= Vk.SUCCESS or else Count = 0 then
         return False;
      end if;
      declare
         Properties : aliased Extension_Property_Array (1 .. Natural (Count));
      begin
         Result :=
           (if Physical = System.Null_Address
            then Vk.Enumerate_Instance_Extension_Properties
                   (System.Null_Address, Count'Address, Properties'Address)
            else Vk.Enumerate_Device_Extension_Properties
                   (Physical, System.Null_Address, Count'Address, Properties'Address));
         return (Result = Vk.SUCCESS or else Result = Vk.INCOMPLETE)
           and then Has_Extension (Properties (1 .. Natural'Min (Natural (Count), Properties'Length)), Name);
      end;
   end Offers_Extension;

   function Initialize
     (Renderer : in out Vulkan_Renderer)
      return Vulkan_Status
   is separate;

   procedure Shutdown
     (Renderer : in out Vulkan_Renderer) is separate;

   function Ready
     (Renderer : Vulkan_Renderer)
      return Boolean is
   begin
      return Renderer.Device_Live;
   end Ready;

   function Status
     (Renderer : Vulkan_Renderer)
      return Vulkan_Status is
   begin
      return Renderer.Last_Status;
   end Status;

   function Physical_Device_Count
     (Renderer : Vulkan_Renderer)
      return Interfaces.Unsigned_32 is
   begin
      return Renderer.Last_Physical_Devices;
   end Physical_Device_Count;

   function Create_Surface
     (Renderer : in out Vulkan_Renderer;
      Window   : not null access Glfw.Windows.Window)
      return Vulkan_Status
   is separate;

   function Surface_Ready
     (Renderer : Vulkan_Renderer)
      return Boolean is
   begin
      return Renderer.Surface_Live;
   end Surface_Ready;

   function Configure_Swapchain
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Vulkan_Status is
   begin
      if Width = 0 or else Height = 0 then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := True;
         Renderer.Frame_Width_Value := Width;
         Renderer.Frame_Height_Value := Height;
         Renderer.Pending_Width_Value := Width;
         Renderer.Pending_Height_Value := Height;
         Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
      elsif not Renderer.Device_Live or else not Renderer.Surface_Live then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := True;
         Renderer.Frame_Width_Value := 0;
         Renderer.Frame_Height_Value := 0;
         Renderer.Pending_Width_Value := Width;
         Renderer.Pending_Height_Value := Height;
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
      else
         Renderer.Last_Status := Create_Swapchain_Resources (Renderer, Width, Height);
      end if;

      return Renderer.Last_Status;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, "Guikit.Vulkan");
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := True;
         Renderer.Frame_Width_Value := 0;
         Renderer.Frame_Height_Value := 0;
         Renderer.Pending_Width_Value := Width;
         Renderer.Pending_Height_Value := Height;
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
         return Renderer.Last_Status;
   end Configure_Swapchain;

   procedure Request_Swapchain_Recreate
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural) is
   begin
      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Pending := True;
      Renderer.Pending_Width_Value := Width;
      Renderer.Pending_Height_Value := Height;
      Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
   end Request_Swapchain_Recreate;

   function Swapchain_Ready
     (Renderer : Vulkan_Renderer)
      return Boolean is
   begin
      return Renderer.Swapchain_Configured;
   end Swapchain_Ready;

   function Frame_Width
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Frame_Width_Value;
   end Frame_Width;

   function Frame_Height
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Frame_Height_Value;
   end Frame_Height;

   function Pending_Frame_Width
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Pending_Width_Value;
   end Pending_Frame_Width;

   function Pending_Frame_Height
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Pending_Height_Value;
   end Pending_Frame_Height;

   function Diagnostics
     (Renderer : Vulkan_Renderer)
      return Renderer_Diagnostics is separate;

   --  The icon atlases Build_Submission built last, which an identical one
   --  reuses: one per window showing different icons, so two windows do not
   --  rebuild each other's atlas every frame. Frames are built on one task.
   type Cached_Icon_Atlas is record
      Signature : Unbounded_String;
      Pixels    : Guikit.Shared_Bytes.Bytes;
      Used      : Natural := 0;
   end record;

   Icon_Atlas_Cache : array (1 .. 4) of Cached_Icon_Atlas;
   Icon_Atlas_Clock : Natural := 0;

   function Build_Submission
     (Rectangles         : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Triangles          : Guikit.Draw.Triangle_Command_Vectors.Vector;
      Icons              : Guikit.Draw.Icon_Command_Vectors.Vector;
      Overlay_Rectangles : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Layout             : Guikit.Draw.Layout_Metrics;
      Theme              : Guikit.Draw.Theme_Kind;
      Text               : Guikit.Draw.Text_Render_Result)
      return Submission_Batch is separate;

   --  A frame was abandoned after its image was acquired: the acquire left
   --  Image_Available signalled with nothing to wait on it, the fence may have
   --  been reset with no submit to signal it again, and the acquired image is
   --  never presented. Rebuild the synchronisation objects at once, so the
   --  next Present neither reuses a signalled semaphore nor waits forever on
   --  an unsignalled fence, and ask for the swapchain to be rebuilt as well,
   --  which is the only way to hand the stranded image back (an application
   --  may hold only a few images acquired at a time). The frame's failure
   --  status is kept.
   procedure Abandon_Acquired_Frame
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
   is
      Failed_Status : constant Vulkan_Status := Renderer.Last_Status;
   begin
      Wait_Device_Idle (Renderer);
      declare
         --  When this fails Sync_Live is False, so Present skips until the
         --  swapchain rebuild requested below creates them again.
         Rebuilt : constant Boolean := Create_Sync_Objects (Renderer);
         pragma Unreferenced (Rebuilt);
      begin
         null;
      end;
      Request_Swapchain_Recreate (Renderer, Width, Height);
      Renderer.Last_Status := Failed_Status;
   end Abandon_Acquired_Frame;

   --  Frame synchronisation. One frame is in flight at a time:
   --
   --  * In_Flight (fence) is signalled by each frame's submit. Present waits
   --    on it first, so when a frame starts the previous submit -- and with it
   --    every command buffer, vertex and atlas upload it used -- is finished.
   --    It is reset only immediately before a Queue_Submit that will happen,
   --    so it never stays unsignalled with no submit pending.
   --  * Image_Available (one semaphore) is signalled by the acquire and
   --    waited on by the same frame's submit. Because of the fence wait, by
   --    the next acquire that wait has executed and the semaphore is unsignalled
   --    again, so one is enough.
   --  * Render_Finished (one semaphore per swapchain image) is signalled by
   --    the submit and waited on by the present. The fence does not cover the
   --    present, so a single semaphore could be re-signalled by the next
   --    submit while the previous present still waits on it. Indexed by the
   --    image instead, it is reused only when that image is acquired again,
   --    and the presentation engine hands an image back only after its
   --    present -- and so its semaphore wait -- has executed.
   --
   --  Any failure between a successful acquire and a successful submit
   --  breaks these invariants; Abandon_Acquired_Frame restores them.
   --  Destroying or rebuilding any of this waits for the device to go idle
   --  (Destroy_Swapchain_Resources).
   function Present
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Vulkan_Status is separate;

   procedure Ensure_Ready
     (Renderer : in out Vulkan_Renderer;
      Window   : not null access Glfw.Windows.Window;
      Width    : Natural;
      Height   : Natural)
   is
   begin
      if not Renderer.Init_Attempted then
         declare
            Status : constant Vulkan_Status := Initialize (Renderer);
            pragma Unreferenced (Status);
         begin
            Renderer.Init_Attempted := True;
         end;
      end if;

      if Renderer.Init_Attempted
        and then not Renderer.Surface_Attempted
        and then Ready (Renderer)
      then
         declare
            Status : constant Vulkan_Status := Create_Surface (Renderer, Window);
            pragma Unreferenced (Status);
         begin
            Renderer.Surface_Attempted := True;
         end;
      end if;

      if Renderer.Surface_Attempted
        and then Surface_Ready (Renderer)
        and then
          (not Swapchain_Ready (Renderer)
           or else Renderer.Frame_Width_Value /= Width
           or else Renderer.Frame_Height_Value /= Height)
      then
         Request_Swapchain_Recreate (Renderer, Width, Height);
         declare
            Status : constant Vulkan_Status := Configure_Swapchain (Renderer, Width, Height);
            pragma Unreferenced (Status);
         begin
            null;
         end;
      end if;
   end Ensure_Ready;

   function Present_Frame
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch;
      Width    : Natural;
      Height   : Natural)
      return Vulkan_Status
   is
      Status : Vulkan_Status := Present (Renderer, Batch);
   begin
      if Status = Vulkan_Swapchain_Recreate_Needed then
         Status := Configure_Swapchain (Renderer, Width, Height);
         if Status = Vulkan_Swapchain_Ready then
            Status := Present (Renderer, Batch);
         end if;
      end if;
      --  A frame not presented may not have committed its uploads: send the
      --  atlases again next time rather than trust they arrived.
      if Status /= Vulkan_Presented then
         Renderer.Uploaded_Atlas_Version := 0;
         Renderer.Uploaded_Icon_Signature := Null_Unbounded_String;
      end if;
      return Status;
   end Present_Frame;

end Guikit.Vulkan;
