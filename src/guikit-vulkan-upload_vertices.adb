separate (Guikit.Vulkan)
function Upload_Vertices
  (Renderer   : in out Vulkan_Renderer;
   Batch      : Submission_Batch;
   Hide_Icons : Boolean)
   return Boolean
is
   use type Guikit.Draw.Theme_Kind;
   use type Vertex_Vectors.Vector;
   Count       : constant Natural := Natural (Batch.Vertices.Length);
   Mapped_Data : aliased System.Address := System.Null_Address;
   Result      : Vk.Result_T;
begin
   if not Ensure_Vertex_Buffer (Renderer, Count) then
      return False;
   elsif Count = 0 then
      return True;
   elsif Renderer.Uploaded_Vertices_Valid
     and then Renderer.Uploaded_Theme = Batch.Palette_Theme
     and then Renderer.Uploaded_Icons_Hidden = Hide_Icons
     and then Renderer.Uploaded_Vertices = Batch.Vertices
   then
      --  The memory holds this frame's vertices already: a present that
      --  changed nothing drawn, which comparing costs a fraction of what
      --  writing them to the device does.
      return True;
   end if;
   Renderer.Uploaded_Vertices_Valid := False;

   Result :=
     Vk.Map_Memory
       (device  => Renderer.Device,
        memory  => Renderer.Vertex_Memory,
        offset  => 0,
        size    => Interfaces.Unsigned_64 (Count) * Gpu_Vertex_Size,
        flags   => 0,
        pp_Data => Mapped_Data'Address);

   if Result /= Vk.SUCCESS or else Mapped_Data = System.Null_Address then
      return False;
   end if;

   declare
      Mapped : constant Gpu_Vertex_Buffer_Conversions.Object_Pointer :=
        Gpu_Vertex_Buffer_Conversions.To_Pointer (Mapped_Data);
      Index  : Positive := 1;
   begin
      for Source of Batch.Vertices loop
         declare
            Packed : Gpu_Vertex := Color_To_Vertex (Source.Color, Batch.Palette_Theme);
         begin
            Packed.X := Interfaces.C.C_float (Source.X);
            Packed.Y := Interfaces.C.C_float (Source.Y);
            Packed.U := Interfaces.C.C_float (Source.U);
            Packed.V := Interfaces.C.C_float (Source.V);
            Packed.Textured := (if Source.Textured then 1.0 else 0.0);
            Packed.Texture := Interfaces.C.C_float (Texture_Source'Pos (Source.Texture));
            if Hide_Icons and then Source.Texture = Texture_Icon_Atlas then
               Packed.X := 0.0;
               Packed.Y := 0.0;
            end if;
            Mapped.all (Index) := Packed;
            Index := Index + 1;
         end;
      end loop;
   end;

   Vk.Unmap_Memory
     (device => Renderer.Device,
      memory => Renderer.Vertex_Memory);
   Renderer.Uploaded_Vertices := Batch.Vertices;
   Renderer.Uploaded_Theme := Batch.Palette_Theme;
   Renderer.Uploaded_Icons_Hidden := Hide_Icons;
   Renderer.Uploaded_Vertices_Valid := True;
   return True;
exception
   when Error : others =>
      Guikit.Errors.Note (Error, "Guikit.Vulkan");
      if Mapped_Data /= System.Null_Address then
         Vk.Unmap_Memory
           (device => Renderer.Device,
            memory => Renderer.Vertex_Memory);
      end if;

      return False;
end Upload_Vertices;
