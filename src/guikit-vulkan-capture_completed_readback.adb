separate (Guikit.Vulkan)
procedure Capture_Completed_Readback
  (Renderer : in out Vulkan_Renderer)
is
   Mapped_Data : aliased System.Address := System.Null_Address;
   Result      : Vk.Result_T;
   Hash        : Interfaces.Unsigned_32 := 2_166_136_261;

   procedure Mix
     (Value : Interfaces.Unsigned_8) is
   begin
      Hash := (Hash xor Interfaces.Unsigned_32 (Value)) * 16_777_619;
   end Mix;
begin
   if not Renderer.Readback_Pending
     or else Renderer.Readback_Memory = System.Null_Address
     or else Renderer.Readback_Bytes = 0
     or else Renderer.Readback_Bytes > Max_Readback_Bytes
   then
      return;
   end if;

   Result :=
     Vk.Map_Memory
       (device  => Renderer.Device,
        memory  => Renderer.Readback_Memory,
        offset  => 0,
        size    => Interfaces.Unsigned_64 (Renderer.Readback_Bytes),
        flags   => 0,
        pp_Data => Mapped_Data'Address);

   if Result /= Vk.SUCCESS or else Mapped_Data = System.Null_Address then
      Renderer.Readback_Pending := False;
      Renderer.Readback_Ready := False;
      return;
   end if;

   declare
      Bytes : constant Readback_Byte_Array_Conversions.Object_Pointer :=
        Readback_Byte_Array_Conversions.To_Pointer (Mapped_Data);
      Frame : Frame_Analysis.Byte_Array (1 .. Renderer.Readback_Bytes)
        with Import, Address => Mapped_Data;
   begin
      for Index in 1 .. Renderer.Readback_Bytes loop
         Mix (Bytes.all (Index));
      end loop;

      --  Analyze the read-back pixels in place for a structural verdict.
      Renderer.Last_Frame_Metrics :=
        Frame_Analysis.Analyze
          (Data   => Frame,
           Width  => Renderer.Frame_Width_Value,
           Height => Renderer.Frame_Height_Value,
           Format => Frame_Analysis.Pixel_Format_RGBA8);
      Renderer.Last_Frame_Passed :=
        Frame_Analysis.Passed (Renderer.Last_Frame_Metrics);

      --  Retain a heap copy of the pixels so layout-derived region checks
      --  can index the same framebuffer after this mapped memory is
      --  unmapped below.
      if Renderer.Readback_Copy = null
        or else Renderer.Readback_Copy_Length /= Renderer.Readback_Bytes
      then
         Free_Retained_Frame (Renderer.Readback_Copy);
         Renderer.Readback_Copy :=
           new Frame_Analysis.Byte_Array (1 .. Renderer.Readback_Bytes);
         Renderer.Readback_Copy_Length := Renderer.Readback_Bytes;
      end if;
      Renderer.Readback_Copy.all := Frame;
      Renderer.Readback_Copy_Width := Renderer.Frame_Width_Value;
      Renderer.Readback_Copy_Height := Renderer.Frame_Height_Value;
   end;

   Vk.Unmap_Memory (Renderer.Device, Renderer.Readback_Memory);
   Renderer.Last_Readback_Hash := Hash;
   Renderer.Last_Readback_Frame := Renderer.Readback_Pending_Frame;
   Renderer.Readback_Ready := True;
   Renderer.Readback_Pending := False;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      if Mapped_Data /= System.Null_Address then
         Vk.Unmap_Memory (Renderer.Device, Renderer.Readback_Memory);
      end if;
      Renderer.Readback_Pending := False;
      Renderer.Readback_Ready := False;
end Capture_Completed_Readback;
