separate (Guikit.Vulkan.Build_Submission)
procedure Build_Icon_Atlas is
   Tile_Size  : constant Positive := Icon_Atlas_Tile_Size;
   Icon_Count : Natural := 0;

   --  Icons that would rasterize to the same pixels share one tile, which
   --  is what keeps a listing cheap: a hundred rows showing the same folder
   --  icon cost one tile between them rather than a hundred, and the cap on
   --  tiles stops being a cap on how many files may be on screen.
   --
   --  Identity is whatever Rasterize_Asset reads: the id picks the asset,
   --  the theme its variant, the base colour its fill. An icon carrying its
   --  own picture is never shared -- a thumbnail belongs to one file, so
   --  comparing pixel buffers would cost more than the tile it might save.
   Slot_Rep : Natural_Vectors.Vector;
   Slot_Of  : Tile_Slot_Maps.Map;

   --  The base colour in decimal, for the tile identity.
   function Base_Color_Key (Base : Guikit.Draw.Icon_Rgb) return String is
     (Natural'Image (Natural (Base.R)) & Natural'Image (Natural (Base.G)) & Natural'Image (Natural (Base.B)));

   function Tile_Key (Icon : Guikit.Draw.Icon_Command) return Unbounded_String is
     (if Icon.Shared_Tile_Id /= Null_Unbounded_String then Icon.Shared_Tile_Id
      elsif Icon.Thumbnail_Pixels.Is_Empty
      then Icon.Icon_Id & ASCII.NUL & Icon.Theme_Name & ASCII.NUL & Base_Color_Key (Icon.Base_Color)
      else Null_Unbounded_String);

   --  The tile size for one icon: the 64-pixel icon tile, or up to
   --  Max_Overlay_Tile (clamped to Cap) when it carries a large image.
   --  A picture gets a tile its own size; only an icon drawn from a vector
   --  asset gets the standard one.
   --
   --  For an asset the tile is the resolution it is rasterized at, so 64 is
   --  a choice about sharpness. For a picture it is a destination to copy
   --  into, and any size but its own means resampling it: a 20-pixel emoji
   --  in a 64-pixel tile was scaled up on the way in and back down on the
   --  way out, and nearest sampling at those ratios dropped one row in five
   --  and doubled another.
   function Natural_Tile (Icon : Guikit.Draw.Icon_Command) return Boolean is
     (not Icon.Thumbnail_Pixels.Is_Empty
      and then Icon.Thumbnail_Width > 0
      and then Icon.Thumbnail_Height > 0);

   function Tile_W_For (Icon : Guikit.Draw.Icon_Command; Cap : Positive) return Positive is
     (if Icon.Thumbnail_Width > Tile_Size
      then Natural'Min (Icon.Thumbnail_Width, Natural'Min (Max_Overlay_Tile, Cap))
      elsif Natural_Tile (Icon)
      then Icon.Thumbnail_Width
      else Tile_Size);
   function Tile_H_For (Icon : Guikit.Draw.Icon_Command; Cap : Positive) return Positive is
     (if Icon.Thumbnail_Height > Tile_Size
      then Natural'Min (Icon.Thumbnail_Height, Natural'Min (Max_Overlay_Tile, Cap))
      elsif Natural_Tile (Icon)
      then Icon.Thumbnail_Height
      else Tile_Size);

   --  Compute the tile layout for a given overlay cap. When no tile exceeds
   --  the icon size the tiles form the historical single-row strip (byte
   --  identical to before); otherwise they are shelf-packed into a 512-wide
   --  region so a large image fits alongside the icons within Max_Atlas_Bytes.
   procedure Layout_Tiles
     (Cap      : Positive;
      Atlas_W  : out Natural;
      Atlas_H  : out Natural;
      Fits     : out Boolean)
   is
      Has_Large : Boolean := False;
      Shelf_W   : constant Positive := Natural'Max (Tile_Size * 8, Max_Overlay_Tile);

      --  The shelf width comes from constants, so a width that broke the
      --  dimension limit would be a mistake in them rather than a layout
      --  that failed to fit. Caught here, where it cannot rot, instead of
      --  by a run-time test that today can only ever answer True.
      pragma Compile_Time_Error
        (Icon_Atlas_Tile_Size * 8 > Max_Atlas_Dimension
           or else Max_Overlay_Tile > Max_Atlas_Dimension,
         "the icon shelf is wider than a texture may be");
      Cursor_X  : Natural := 0;
      Cursor_Y  : Natural := 0;
      Shelf_H   : Natural := 0;
   begin
      Icon_Tile_Layout.Clear;

      --  One pass per tile, not per icon: the placed icons and the shared
      --  repeats were both settled when the slots were assigned.
      for Rep of Slot_Rep loop
         declare
            Icon : Guikit.Draw.Icon_Command renames All_Icons (Rep);
         begin
            if Tile_W_For (Icon, Cap) /= Tile_Size
              or else Tile_H_For (Icon, Cap) /= Tile_Size
            then
               Has_Large := True;
            end if;
         end;
      end loop;

      if not Has_Large then
         Atlas_W := Icon_Count * Tile_Size;
         Atlas_H := Tile_Size;
         declare
            X : Natural := 0;
         begin
            for Ignored in 1 .. Icon_Count loop
               Icon_Tile_Layout.Append
                 (Icon_Tile_Rect'(X => X, Y => 0, W => Tile_Size, H => Tile_Size));
               X := X + Tile_Size;
            end loop;
         end;
         Fits := True;
         return;
      end if;

      for Rep of Slot_Rep loop
         declare
            Icon : Guikit.Draw.Icon_Command renames All_Icons (Rep);
            TW   : constant Positive := Tile_W_For (Icon, Cap);
            TH   : constant Positive := Tile_H_For (Icon, Cap);
         begin
            if Cursor_X + TW > Shelf_W then
               Cursor_Y := Cursor_Y + Shelf_H;
               Cursor_X := 0;
               Shelf_H := 0;
            end if;
            Icon_Tile_Layout.Append
              (Icon_Tile_Rect'(X => Cursor_X, Y => Cursor_Y, W => TW, H => TH));
            Cursor_X := Cursor_X + TW;
            Shelf_H := Natural'Max (Shelf_H, TH);
         end;
      end loop;

      Atlas_W := Shelf_W;
      Atlas_H := Cursor_Y + Shelf_H;
      --  Only the height and the byte total vary here: the width is the
      --  shelf's, fixed above.
      Fits :=
        Atlas_H <= Max_Atlas_Dimension
        and then Atlas_W * Atlas_H * Icon_Atlas_Channels <= Max_Atlas_Bytes;
   end Layout_Tiles;

   --  The atlas being built, shared once it is complete.
   Pixels : Guikit.Shared_Bytes.Byte_Vectors.Vector;

   procedure Put_Pixel
     (X : Natural;
      Y : Natural;
      R : Interfaces.Unsigned_8;
      G : Interfaces.Unsigned_8;
      B : Interfaces.Unsigned_8;
      A : Interfaces.Unsigned_8)
   is
      Offset : constant Positive :=
        Positive (((Y * Result.Icon_Atlas_Width) + X) * Result.Icon_Atlas_Channels + 1);
   begin
      Pixels.Replace_Element (Offset, R);
      Pixels.Replace_Element (Offset + 1, G);
      Pixels.Replace_Element (Offset + 2, B);
      Pixels.Replace_Element (Offset + 3, A);
   end Put_Pixel;

   procedure Role_Color
     (Base : Guikit.Draw.Icon_Rgb;
      Role : Guikit.Draw.Icon_Asset_Color_Role;
      R    : out Interfaces.Unsigned_8;
      G    : out Interfaces.Unsigned_8;
      B    : out Interfaces.Unsigned_8;
      A    : out Interfaces.Unsigned_8)
   is
   begin
      case Role is
         when Guikit.Draw.Icon_Asset_Base =>
            --  The command's own: the consumer knows what the icon is.
            R := Base.R;
            G := Base.G;
            B := Base.B;
         when Guikit.Draw.Icon_Asset_Accent =>
            R := 57;
            G := 127;
            B := 218;
         when Guikit.Draw.Icon_Asset_Border =>
            R := 30;
            G := 35;
            B := 42;
         when Guikit.Draw.Icon_Asset_Muted =>
            R := 112;
            G := 120;
            B := 130;
      end case;
      A := 255;
   end Role_Color;

   procedure Rasterize_Asset
     (Tile_Index : Natural;
      Icon       : Guikit.Draw.Icon_Command)
   is
      Asset_Text : constant String :=
        Guikit.Draw.Icon_Asset_Text (To_String (Icon.Icon_Id), To_String (Icon.Theme_Name));
      Asset      : Guikit.Draw.Icon_Asset := Guikit.Draw.Parse_Icon_Asset (Asset_Text);
      Tile       : constant Icon_Tile_Rect := Icon_Tile_Layout.Element (Tile_Index + 1);

      procedure Fill_Rect
        (Rect : Guikit.Draw.Icon_Asset_Rect)
      is
         X0 : constant Natural :=
           Saturating_Add
             (Tile.X,
              Bounded_Product_Divide (Value => Rect.Grid_X, Factor => Tile.W, Denominator => Asset.Grid));
         Y0 : constant Natural :=
           Saturating_Add
             (Tile.Y,
              Bounded_Product_Divide (Value => Rect.Grid_Y, Factor => Tile.H, Denominator => Asset.Grid));
         X1 : constant Natural :=
           Natural'Min
             (Saturating_Add (Tile.X, Tile.W),
              Saturating_Add
                (Tile.X,
                 Bounded_Product_Divide
                   (Value       => Rect.Grid_X + Rect.Grid_W,
                    Factor      => Tile.W,
                    Denominator => Asset.Grid)));
         Y1 : constant Natural :=
           Natural'Min
             (Saturating_Add (Tile.Y, Tile.H),
              Saturating_Add
                (Tile.Y,
                 Bounded_Product_Divide
                   (Value => Rect.Grid_Y + Rect.Grid_H, Factor => Tile.H, Denominator => Asset.Grid)));
         R  : Interfaces.Unsigned_8;
         G  : Interfaces.Unsigned_8;
         B  : Interfaces.Unsigned_8;
         A  : Interfaces.Unsigned_8;
      begin
         if X1 <= X0 or else Y1 <= Y0 then
            return;
         end if;

         Role_Color (Icon.Base_Color, Rect.Role, R, G, B, A);
         for Y in Y0 .. Y1 - 1 loop
            for X in X0 .. X1 - 1 loop
               Put_Pixel (X, Y, R, G, B, A);
            end loop;
         end loop;
      end Fill_Rect;

      function Rasterize_Thumbnail return Boolean is
         Source_Width  : constant Natural := Icon.Thumbnail_Width;
         Source_Height : constant Natural := Icon.Thumbnail_Height;
         --  One copy out of the shared buffer, then plain indexing.
         Pixels        : constant Guikit.Draw.Byte_Vectors.Vector := Icon.Thumbnail_Pixels.To_Vector;
      begin
         if Source_Width = 0
           or else Source_Height = 0
           or else Icon.Thumbnail_Pixels.Length /= Source_Width * Source_Height * 4
         then
            return False;
         end if;

         for Y in 0 .. Tile.H - 1 loop
            for X in 0 .. Tile.W - 1 loop
               declare
                  Source_X : constant Natural := (X * Source_Width) / Tile.W;
                  Source_Y : constant Natural := (Y * Source_Height) / Tile.H;
                  Offset   : constant Positive :=
                    Positive (((Source_Y * Source_Width) + Source_X) * 4 + 1);
               begin
                  Put_Pixel
                    (Tile.X + X,
                     Tile.Y + Y,
                     Pixels.Element (Offset),
                     Pixels.Element (Offset + 1),
                     Pixels.Element (Offset + 2),
                     Pixels.Element (Offset + 3));
               end;
            end loop;
         end loop;

         return True;
      end Rasterize_Thumbnail;
   begin
      if Rasterize_Thumbnail then
         return;
      end if;

      if not Asset.Valid then
         Asset :=
           Guikit.Draw.Parse_Icon_Asset
             (Guikit.Draw.Icon_Asset_Text ("unknown", To_String (Icon.Theme_Name)));
      end if;

      if Asset.Valid then
         for Rect of Asset.Rectangles loop
            Fill_Rect (Rect);
         end loop;
      end if;
   end Rasterize_Asset;

   --  Give every atlas icon its tile: a new one, or the tile an icon with
   --  the same identity already has (Slot_Rep, Slot_Of, Icon_Tile_Of).
   procedure Assign_Tiles is
      Index : Natural := 0;
   begin
      for Icon of All_Icons loop
         Index := Index + 1;

         if Is_Atlas_Icon (Icon) then
            declare
               Key  : constant Unbounded_String := Tile_Key (Icon);
               Slot : Positive;
            begin
               if Key /= Null_Unbounded_String and then Slot_Of.Contains (Key) then
                  Slot := Slot_Of.Element (Key);
               else
                  Slot_Rep.Append (Index);
                  Slot := Positive (Slot_Rep.Length);

                  if Key /= Null_Unbounded_String then
                     Slot_Of.Insert (Key, Slot);
                  end if;
               end if;

               Icon_Tile_Of.Append (Slot);
            end;
         end if;
      end loop;
   end Assign_Tiles;

   --  Shrink the large-image cap until the atlas fits the byte budget; at
   --  the icon size every tile is 64 and the strip layout always fits. The
   --  atlas's size goes into Result.
   procedure Size_Atlas is
      Atlas_W : Natural := 0;
      Atlas_H : Natural := 0;
      Fits    : Boolean := False;
      Cap     : Positive := Max_Overlay_Tile;
   begin
      loop
         Layout_Tiles (Cap, Atlas_W, Atlas_H, Fits);
         exit when Fits or else Cap <= Tile_Size;
         Cap := Natural'Max (Tile_Size, (Cap * 3) / 4);
      end loop;

      Result.Icon_Atlas_Width := Atlas_W;
      Result.Icon_Atlas_Height := Atlas_H;
      Result.Icon_Atlas_Channels := Icon_Atlas_Channels;
      Result.Icon_Atlas_Bytes :=
        Result.Icon_Atlas_Width * Result.Icon_Atlas_Height * Result.Icon_Atlas_Channels;
      Result.Icon_Atlas_Dirty := True;
   end Size_Atlas;

   --  The atlas this frame needs, by what each tile shows and where: a
   --  vector icon by its identity, a picture by its shared buffer's
   --  serial.
   function Atlas_Signature return Unbounded_String is
      Signature : Unbounded_String :=
        To_Unbounded_String (Natural'Image (Result.Icon_Atlas_Width) & Natural'Image (Result.Icon_Atlas_Height));
      Tile_Number : Natural := 0;
   begin
      for Rep of Slot_Rep loop
         Tile_Number := Tile_Number + 1;
         declare
            Icon : Guikit.Draw.Icon_Command renames All_Icons.Constant_Reference (Rep).Element.all;
            Key  : constant Unbounded_String := Tile_Key (Icon);
            Tile : constant Icon_Tile_Rect := Icon_Tile_Layout.Element (Tile_Number);
         begin
            Append (Signature, ASCII.LF);
            if Length (Key) > 0 then
               Append (Signature, Key);
               --  The asset text too: its source can change under one id.
               if Icon.Thumbnail_Pixels.Is_Empty then
                  Append
                    (Signature,
                     Ada.Containers.Hash_Type'Image
                       (Ada.Strings.Hash
                          (Guikit.Draw.Icon_Asset_Text
                             (To_String (Icon.Icon_Id), To_String (Icon.Theme_Name)))));
               else
                  Append (Signature, "#" & Natural'Image (Icon.Thumbnail_Pixels.Serial));
               end if;
            else
               Append (Signature, "#" & Natural'Image (Icon.Thumbnail_Pixels.Serial)
                       & Natural'Image (Icon.Thumbnail_Width) & Natural'Image (Icon.Thumbnail_Height));
            end if;
            Append (Signature, Natural'Image (Tile.X) & Natural'Image (Tile.Y)
                    & Natural'Image (Tile.W) & Natural'Image (Tile.H));
         end;
      end loop;
      return Signature;
   end Atlas_Signature;

   --  Whether Icon_Atlas_Cache holds the atlas Result's signature names:
   --  then Result takes its pixels and the entry counts as just used.
   function Reused_Cached_Atlas return Boolean is
   begin
      for Cached of Icon_Atlas_Cache loop
         if Cached.Signature = Result.Icon_Atlas_Signature then
            Result.Icon_Atlas_Pixels := Cached.Pixels;
            Cached.Used := Icon_Atlas_Clock;
            return True;
         end if;
      end loop;
      return False;
   end Reused_Cached_Atlas;

   --  Once per tile: a shared tile is rasterized from the first icon that
   --  asked for it, and every other icon with the same identity reads it.
   procedure Rasterize_Tiles is
      Tile_Index : Natural := 0;
   begin
      Pixels := Guikit.Shared_Bytes.Byte_Vectors.To_Vector (0, Ada.Containers.Count_Type (Result.Icon_Atlas_Bytes));
      for Rep of Slot_Rep loop
         Rasterize_Asset (Tile_Index, All_Icons (Rep));
         Tile_Index := Tile_Index + 1;
      end loop;
      Result.Icon_Atlas_Pixels := Guikit.Shared_Bytes.To_Shared (Pixels);
   end Rasterize_Tiles;

   --  Keep Result's atlas in Icon_Atlas_Cache, in place of the entry used
   --  longest ago.
   procedure Remember_Atlas is
      Oldest : Positive := Icon_Atlas_Cache'First;
   begin
      for Index in Icon_Atlas_Cache'Range loop
         if Icon_Atlas_Cache (Index).Used < Icon_Atlas_Cache (Oldest).Used then
            Oldest := Index;
         end if;
      end loop;
      Icon_Atlas_Cache (Oldest) :=
        (Signature => Result.Icon_Atlas_Signature, Pixels => Result.Icon_Atlas_Pixels, Used => Icon_Atlas_Clock);
   end Remember_Atlas;
begin
   Assign_Tiles;

   --  The budget is tiles, so it is the shared count that has to fit.
   Icon_Count := Natural (Slot_Rep.Length);

   if Icon_Count = 0
     or else Icon_Count > Max_Icon_Atlas_Tiles
   then
      return;
   end if;

   Size_Atlas;

   --  The same atlas as the last one built is not rebuilt (no parsing, no
   --  copying pictures in), and a renderer that has it uploads nothing.
   Result.Icon_Atlas_Signature := Atlas_Signature;
   Icon_Atlas_Clock := Icon_Atlas_Clock + 1;
   if Reused_Cached_Atlas then
      return;
   end if;

   Rasterize_Tiles;
   Remember_Atlas;
end Build_Icon_Atlas;
