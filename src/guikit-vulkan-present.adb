separate (Guikit.Vulkan)
function Present
  (Renderer : in out Vulkan_Renderer;
   Batch    : Submission_Batch)
   return Vulkan_Status
is
   Image_Index : aliased Interfaces.Unsigned_32 := 0;
   Swapchains  : aliased Swapchain_Array (1 .. 1) := [1 => Renderer.Swapchain];
   Indices     : aliased Image_Index_Array (1 .. 1);
   --  The render-finished semaphore is the acquired image's own, set once
   --  the acquire has said which image that is.
   Present_Waits : aliased Semaphore_Array (1 .. 1) := [1 => System.Null_Address];
   Submit_Waits  : aliased Semaphore_Array (1 .. 1) := [1 => Renderer.Image_Available];
   Submit_Signals : aliased Semaphore_Array (1 .. 1) := [1 => System.Null_Address];
   Wait_Stages : aliased Interfaces.Unsigned_32 := Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
   Fence_Array : aliased Fence_Array_C (1 .. 1) := [1 => Renderer.In_Flight];
   Submit_Commands : aliased Command_Buffer_Array_C (1 .. 1);
   Submit_Info : aliased Vk.Submit_Info_T :=
     (s_Type                 => Vk.STRUCTURE_TYPE_SUBMIT_INFO,
      p_Next                 => System.Null_Address,
      wait_Semaphore_Count   => 1,
      p_Wait_Semaphores      => Submit_Waits'Address,
      p_Wait_Dst_Stage_Mask  => Wait_Stages'Address,
      command_Buffer_Count   => 1,
      p_Command_Buffers      => Submit_Commands'Address,
      signal_Semaphore_Count => 1,
      p_Signal_Semaphores    => Submit_Signals'Address);
   Present_Info : aliased Vk.Present_Info_KHR_T :=
     (s_Type               => Structure_Type_Present_Info_KHR,
      p_Next               => System.Null_Address,
      wait_Semaphore_Count => 1,
      p_Wait_Semaphores    => Present_Waits'Address,
      swapchain_Count      => 1,
      p_Swapchains         => Swapchains'Address,
      p_Image_Indices      => Indices'Address,
      p_Results            => System.Null_Address);
   Present_Result : Vk.Result_T;
   --  An image is acquired and its submit has not been made yet.
   Acquired : Boolean := False;

   --  Record a failed Vulkan call's result and the frame's Status.
   procedure Fail (Status : Vulkan_Status; Result : Vk.Result_T) is
   begin
      Renderer.Last_Vk_Result := Interfaces.Integer_32 (Result);
      Renderer.Last_Status := Status;
   end Fail;

   --  Whether the frame can be drawn now; when not, Last_Status says why
   --  (skipped, or the swapchain is to be made again at the batch's size).
   function Ready_To_Draw return Boolean is
   begin
      if not Renderer.Device_Live or else not Renderer.Surface_Live then
         Renderer.Last_Status := Vulkan_Present_Skipped;
      elsif not Renderer.Swapchain_Configured
        or else not Renderer.Swapchain_Live
        or else not Renderer.Sync_Live
        or else not Renderer.Commands_Live
        or else Renderer.Graphics_Queue = System.Null_Address
      then
         Renderer.Last_Status := Vulkan_Present_Skipped;
      elsif Batch.Width = 0
        or else Batch.Height = 0
        or else Batch.Vertices.Is_Empty
      then
         Renderer.Last_Status := Vulkan_Present_Skipped;
      elsif Batch.Width /= Renderer.Frame_Width_Value
        or else Batch.Height /= Renderer.Frame_Height_Value
      then
         Request_Swapchain_Recreate (Renderer, Batch.Width, Batch.Height);
         Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
      else
         return True;
      end if;
      return False;
   end Ready_To_Draw;

   --  Wait for the last frame's submit, then upload this frame's atlases,
   --  vertices and read-back buffer. False, with Last_Status set, when a
   --  step the frame cannot be drawn without fails. An icon atlas that
   --  cannot be uploaded is not one of them: the frame is drawn without its
   --  icons (Upload_Vertices collapses them), Icon_Atlas_Failed says so, and
   --  the icon binding keeps naming a live view (the icon atlas's previous
   --  texture, or the text atlas's as its fallback, Atlas_Uploads).
   function Upload_Frame return Boolean is
   begin
      Renderer.Last_Vk_Result := -10_010;
      Present_Result :=
        Vk.Wait_For_Fences
          (device      => Renderer.Device,
           fence_Count => 1,
           p_Fences    => Fence_Array'Address,
           wait_All    => 1,
           timeout     => Infinite_Timeout);
      if Present_Result /= Vk.SUCCESS then
         Fail (Vulkan_Submit_Failed, Present_Result);
         return False;
      end if;

      if Renderer.Readback_Enabled then
         Capture_Completed_Readback (Renderer);
      end if;
      Renderer.Last_Vk_Result := -10_020;
      if not Upload_Atlas (Renderer, Batch) then
         Renderer.Last_Status := Vulkan_Atlas_Texture_Create_Failed;
         return False;
      end if;

      --  Upload the icon atlas (binding 1) whenever the batch's icons
      --  changed, not only when text shares the frame.
      Renderer.Icon_Atlas_Failed :=
        Batch.Icon_Atlas_Dirty and then not Upload_Icon_Atlas (Renderer, Batch);

      --  Icons are drawn only from the atlas this frame uploaded or kept:
      --  not after a failed upload (a texture left from an earlier frame
      --  holds other tiles), nor through a binding that falls back to the
      --  text atlas.
      if not Upload_Vertices
        (Renderer,
         Batch,
         Hide_Icons =>
           Renderer.Icon_Atlas_Failed
           or else Renderer.Atlases (Icon_Atlas).Binding /= Binding_Current)
      then
         Renderer.Last_Status := Vulkan_Vertex_Buffer_Create_Failed;
      elsif Renderer.Readback_Enabled
        and then not Ensure_Readback_Buffer
          (Renderer,
           Saturating_Multiply (Saturating_Multiply (Batch.Width, Batch.Height), 4))
      then
         Renderer.Last_Status := Vulkan_Vertex_Buffer_Create_Failed;
      else
         return True;
      end if;
      return False;
   end Upload_Frame;

   --  Acquire an image and record its command buffer. False, with
   --  Last_Status set, when that fails; a failure after the acquire gives
   --  the frame up (Abandon_Acquired_Frame).
   function Acquire_And_Record return Boolean is
   begin
      Renderer.Last_Vk_Result := -10_030;
      Present_Result :=
        Vk.Acquire_Next_Image_KHR
          (device        => Renderer.Device,
           swapchain     => Renderer.Swapchain,
           timeout       => Infinite_Timeout,
           semaphore     => Renderer.Image_Available,
           fence         => System.Null_Address,
           p_Image_Index => Image_Index'Address);
      Acquired := Present_Result = Vk.SUCCESS or else Present_Result = Suboptimal_KHR;

      if Present_Result = Error_Out_Of_Date_KHR then
         Fail (Vulkan_Swapchain_Recreate_Needed, Present_Result);
         Request_Swapchain_Recreate (Renderer, Batch.Width, Batch.Height);
      elsif not Acquired then
         Fail (Vulkan_Present_Failed, Present_Result);
      elsif not Record_Command_Buffers
        (Renderer, Natural (Batch.Vertices.Length), Only_Image => Positive (Image_Index + 1))
      then
         Renderer.Last_Status := Vulkan_Command_Record_Failed;
         Abandon_Acquired_Frame (Renderer, Batch.Width, Batch.Height);
      else
         return True;
      end if;
      return False;
   end Acquire_And_Record;

   --  Submit the acquired image's command buffer. False, with Last_Status
   --  set and the frame given up, when that fails.
   function Submit return Boolean is
   begin
      Renderer.Last_Vk_Result := -10_040;
      Renderer.Current_Image_Index := Image_Index;
      Indices (1) := Image_Index;
      Submit_Commands (1) := Renderer.Command_Buffers (Positive (Image_Index + 1));
      Submit_Signals (1) := Renderer.Render_Finished (Positive (Image_Index + 1));
      Present_Waits (1) := Submit_Signals (1);
      Renderer.Last_Vk_Result := -10_050;
      --  Nothing that can fail lies between this reset and the submit that
      --  signals the fence again.
      Present_Result :=
        Vk.Reset_Fences
          (device      => Renderer.Device,
           fence_Count => 1,
           p_Fences    => Fence_Array'Address);
      if Present_Result = Vk.SUCCESS then
         Renderer.Last_Vk_Result := -10_060;
         Present_Result :=
           Vk.Queue_Submit
             (queue        => Renderer.Graphics_Queue,
              submit_Count => 1,
              p_Submits    => Submit_Info'Address,
              fence        => Renderer.In_Flight);
      end if;
      if Present_Result /= Vk.SUCCESS then
         Fail (Vulkan_Submit_Failed, Present_Result);
         Abandon_Acquired_Frame (Renderer, Batch.Width, Batch.Height);
         return False;
      end if;

      Acquired := False;
      Renderer.Submitted_Frames := Renderer.Submitted_Frames + 1;
      Renderer.Readback_Pending := Renderer.Readback_Enabled;
      Renderer.Readback_Pending_Frame := Renderer.Submitted_Frames;
      return True;
   end Submit;

   --  Hand the submitted image to the presentation engine.
   procedure Present_Image is
   begin
      Renderer.Last_Vk_Result := -10_070;
      Present_Result :=
        Vk.Queue_Present_KHR
          (queue          => Renderer.Graphics_Queue,
           p_Present_Info => Present_Info'Address);

      if Present_Result = Vk.SUCCESS then
         Fail (Vulkan_Presented, Present_Result);
      elsif Present_Result = Suboptimal_KHR or else Present_Result = Error_Out_Of_Date_KHR then
         Fail (Vulkan_Swapchain_Recreate_Needed, Present_Result);
         Request_Swapchain_Recreate (Renderer, Batch.Width, Batch.Height);
      else
         Fail (Vulkan_Present_Failed, Present_Result);
      end if;
   end Present_Image;

   --  Count the frame as presented, skipped or failed.
   procedure Count_Frame is
   begin
      case Renderer.Last_Status is
         when Vulkan_Presented =>
            Renderer.Presented_Frames := Renderer.Presented_Frames + 1;
         when Vulkan_Present_Skipped | Vulkan_Swapchain_Recreate_Needed =>
            Renderer.Skipped_Frames := Renderer.Skipped_Frames + 1;
         when Vulkan_Present_Failed
            | Vulkan_Submit_Failed
            | Vulkan_Command_Record_Failed
            | Vulkan_Vertex_Buffer_Create_Failed
            | Vulkan_Atlas_Texture_Create_Failed =>
            Renderer.Failed_Frames := Renderer.Failed_Frames + 1;
         when others =>
            null;
      end case;
   end Count_Frame;
begin
   Renderer.Last_Vk_Result := -10_000;
   Renderer.Last_Vertex_Count := Natural (Batch.Vertices.Length);
   Renderer.Last_Texture_Count := Batch.Texture_Count;
   Renderer.Last_Used_Mixed_Textures := Batch.Uses_Separate_Text_And_Icon_Textures;

   if Ready_To_Draw and then Upload_Frame and then Acquire_And_Record and then Submit then
      Present_Image;
   end if;

   Count_Frame;
   return Renderer.Last_Status;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      Renderer.Last_Status := Vulkan_Present_Failed;
      if Acquired then
         Abandon_Acquired_Frame (Renderer, Batch.Width, Batch.Height);
      end if;
      Renderer.Failed_Frames := Renderer.Failed_Frames + 1;
      return Renderer.Last_Status;
end Present;
