with Guikit.Errors;
with Ada.Strings;
with Ada.Strings.Fixed;

--  Implementation of the renderer-agnostic draw model helpers.
package body Guikit.Draw is

   use Ada.Strings.Unbounded;

   function Color_For
     (Role  : Render_Color;
      Theme : Theme_Kind := Theme_Dark)
      return Palette_Color
   is
      function RGB
        (R : Float;
         G : Float;
         B : Float;
         A : Float := 1.0)
         return Palette_Color is
      begin
         return (R => R, G => G, B => B, A => A);
      end RGB;

      --  Dark base palette.
      function Dark_Color return Palette_Color is
      begin
         case Role is
            when Canvas_Color          => return RGB (0.08, 0.09, 0.10);
            when Toolbar_Color         => return RGB (0.07, 0.08, 0.09);
            when Bottom_Bar_Color      => return RGB (0.07, 0.08, 0.09);
            when Main_Color            => return RGB (0.10, 0.11, 0.12);
            when Alternate_Row_Color => return RGB (0.12, 0.13, 0.14);
            when Pane_Color            => return RGB (0.16, 0.17, 0.18);
            when Input_Color           => return RGB (0.18, 0.19, 0.20);
            when Input_Error_Color     => return RGB (0.44, 0.12, 0.14);
            when Selection_Color       => return RGB (0.21, 0.38, 0.62);
            when Hover_Color           => return RGB (0.20, 0.22, 0.24);
            when Pressed_Color         => return RGB (0.17, 0.24, 0.34);
            when Border_Color          => return RGB (0.28, 0.29, 0.30);
            when Text_Color            => return RGB (0.86, 0.87, 0.88);
            when Muted_Text_Color      => return RGB (0.58, 0.60, 0.62);
            when Error_Text_Color      => return RGB (0.94, 0.30, 0.27);
            when Disabled_Text_Color   => return RGB (0.40, 0.41, 0.42);
            when Icon_Folder_Color  => return RGB (0.32, 0.50, 0.82);
            when Icon_Document_Color       => return RGB (0.70, 0.72, 0.74);
            when Icon_Program_Color => return RGB (0.38, 0.68, 0.42);
            when Icon_Generic_Color    => return RGB (0.55, 0.55, 0.57);
            when Accent_Gold_Color   => return RGB (0.96, 0.78, 0.28);
            when Accent_Red_Color       => return RGB (0.90, 0.30, 0.28);
            when Accent_Orange_Color    => return RGB (0.94, 0.58, 0.22);
            when Accent_Yellow_Color    => return RGB (0.94, 0.84, 0.30);
            when Accent_Green_Color     => return RGB (0.40, 0.74, 0.42);
            when Accent_Blue_Color      => return RGB (0.34, 0.56, 0.90);
            when Accent_Purple_Color    => return RGB (0.64, 0.44, 0.86);
            when Accent_Gray_Color      => return RGB (0.60, 0.62, 0.66);
            when Marquee_Color         => return RGB (0.21, 0.38, 0.62, 0.25);
            when Modal_Backdrop_Color => return RGB (0.00, 0.00, 0.00, 0.52);
            when Shadow_Color          => return RGB (0.00, 0.00, 0.00, 0.45);
            when Overlay_Color         => return RGB (0.04, 0.05, 0.06);
         end case;
      end Dark_Color;

      --  Light palette: light surfaces, dark text, and selection/hover/border
      --  colors chosen for legible contrast against the light backgrounds.
      function Light_Color return Palette_Color is
      begin
         case Role is
            when Canvas_Color          => return RGB (0.93, 0.94, 0.95);
            when Toolbar_Color         => return RGB (0.88, 0.89, 0.91);
            when Bottom_Bar_Color      => return RGB (0.88, 0.89, 0.91);
            when Main_Color            => return RGB (0.98, 0.98, 0.99);
            when Alternate_Row_Color => return RGB (0.94, 0.95, 0.96);
            when Pane_Color            => return RGB (0.90, 0.91, 0.93);
            when Input_Color           => return RGB (1.00, 1.00, 1.00);
            when Input_Error_Color     => return RGB (0.98, 0.82, 0.82);
            when Selection_Color       => return RGB (0.62, 0.78, 0.98);
            when Hover_Color           => return RGB (0.84, 0.86, 0.89);
            when Pressed_Color         => return RGB (0.72, 0.82, 0.95);
            when Border_Color          => return RGB (0.68, 0.70, 0.73);
            when Text_Color            => return RGB (0.11, 0.12, 0.14);
            when Muted_Text_Color      => return RGB (0.38, 0.40, 0.43);
            when Error_Text_Color      => return RGB (0.72, 0.10, 0.10);
            when Disabled_Text_Color   => return RGB (0.60, 0.62, 0.64);
            when Icon_Folder_Color  => return RGB (0.18, 0.40, 0.74);
            when Icon_Document_Color       => return RGB (0.34, 0.36, 0.40);
            when Icon_Program_Color => return RGB (0.16, 0.52, 0.24);
            when Icon_Generic_Color    => return RGB (0.44, 0.44, 0.48);
            when Accent_Gold_Color   => return RGB (0.82, 0.60, 0.08);
            when Accent_Red_Color       => return RGB (0.82, 0.20, 0.18);
            when Accent_Orange_Color    => return RGB (0.86, 0.48, 0.12);
            when Accent_Yellow_Color    => return RGB (0.82, 0.70, 0.14);
            when Accent_Green_Color     => return RGB (0.24, 0.60, 0.28);
            when Accent_Blue_Color      => return RGB (0.20, 0.44, 0.82);
            when Accent_Purple_Color    => return RGB (0.50, 0.30, 0.76);
            when Accent_Gray_Color      => return RGB (0.46, 0.48, 0.52);
            when Marquee_Color         => return RGB (0.62, 0.78, 0.98, 0.30);
            when Modal_Backdrop_Color => return RGB (0.08, 0.10, 0.14, 0.32);
            when Shadow_Color          => return RGB (0.08, 0.10, 0.14, 0.25);
            when Overlay_Color         => return RGB (0.90, 0.91, 0.93);
         end case;
      end Light_Color;

      --  High contrast keeps a dark canvas but deliberately separates every
      --  interactive surface and raises secondary/disabled text above the
      --  ordinary dark palette. Bright borders make focus and panel geometry
      --  visible without relying on subtle changes in near-black fills.
      function High_Contrast_Color return Palette_Color is
      begin
         case Role is
            when Canvas_Color           => return RGB (0.01, 0.01, 0.02);
            when Toolbar_Color          => return RGB (0.02, 0.02, 0.03);
            when Bottom_Bar_Color       => return RGB (0.02, 0.02, 0.03);
            when Main_Color             => return RGB (0.04, 0.04, 0.05);
            when Alternate_Row_Color => return RGB (0.08, 0.08, 0.10);
            when Pane_Color             => return RGB (0.10, 0.10, 0.12);
            when Input_Color            => return RGB (0.13, 0.13, 0.15);
            when Input_Error_Color      => return RGB (0.46, 0.05, 0.08);
            when Selection_Color        => return RGB (0.08, 0.43, 0.88);
            when Hover_Color            => return RGB (0.18, 0.18, 0.22);
            when Pressed_Color          => return RGB (0.08, 0.30, 0.58);
            when Border_Color           => return RGB (0.72, 0.74, 0.78);
            when Text_Color             => return RGB (1.00, 1.00, 1.00);
            when Muted_Text_Color       => return RGB (0.82, 0.84, 0.87);
            when Error_Text_Color       => return RGB (1.00, 0.34, 0.30);
            when Disabled_Text_Color    => return RGB (0.62, 0.64, 0.67);
            when Icon_Folder_Color   => return RGB (0.32, 0.62, 1.00);
            when Icon_Document_Color        => return RGB (0.88, 0.90, 0.94);
            when Icon_Program_Color  => return RGB (0.36, 0.86, 0.42);
            when Icon_Generic_Color     => return RGB (0.76, 0.78, 0.82);
            when Accent_Gold_Color    => return RGB (1.00, 0.84, 0.20);
            when Accent_Red_Color        => return RGB (1.00, 0.30, 0.28);
            when Accent_Orange_Color     => return RGB (1.00, 0.62, 0.20);
            when Accent_Yellow_Color     => return RGB (1.00, 0.90, 0.22);
            when Accent_Green_Color      => return RGB (0.40, 0.88, 0.44);
            when Accent_Blue_Color       => return RGB (0.34, 0.66, 1.00);
            when Accent_Purple_Color     => return RGB (0.76, 0.50, 1.00);
            when Accent_Gray_Color       => return RGB (0.78, 0.80, 0.84);
            when Marquee_Color          => return RGB (0.08, 0.43, 0.88, 0.38);
            when Modal_Backdrop_Color   => return RGB (0.00, 0.00, 0.00, 0.68);
            when Shadow_Color           => return RGB (0.00, 0.00, 0.00, 0.70);
            when Overlay_Color          => return RGB (0.00, 0.00, 0.00);
         end case;
      end High_Contrast_Color;
   begin
      case Theme is
         when Theme_Dark          => return Dark_Color;
         when Theme_High_Contrast => return High_Contrast_Color;
         when Theme_Light         => return Light_Color;
      end case;
   end Color_For;

   function Icon_Rgb_For
     (Role  : Render_Color;
      Theme : Theme_Kind := Theme_Dark)
      return Icon_Rgb
   is
      Color : constant Palette_Color := Color_For (Role, Theme);

      function Channel (Value : Float) return Interfaces.Unsigned_8 is
        (Interfaces.Unsigned_8 (Float'Rounding (Float'Min (1.0, Float'Max (0.0, Value)) * 255.0)));
   begin
      return (R => Channel (Color.R), G => Channel (Color.G), B => Channel (Color.B));
   end Icon_Rgb_For;

   Asset_Source : Icon_Asset_Source := null;

   procedure Set_Icon_Asset_Source (Source : Icon_Asset_Source) is
   begin
      Asset_Source := Source;
   end Set_Icon_Asset_Source;

   function Icon_Asset_Text
     (Icon_Id    : String;
      Theme_Name : String)
      return String is
     (if Asset_Source = null then "" else Asset_Source (Icon_Id, Theme_Name));

   function Is_Format_Header (Line : String) return Boolean is
      Suffix : constant String := "-" & Icon_Format_Name;
   begin
      return Line = Icon_Format_Name
        or else (Line'Length > Suffix'Length
                 and then Line (Line'Last - Suffix'Length + 1 .. Line'Last) = Suffix);
   end Is_Format_Header;

   function Parse_Icon_Asset
     (Content : String)
      return Icon_Asset
   is
      Result      : Icon_Asset;
      Saw_Header  : Boolean := False;
      Saw_Name    : Boolean := False;
      Saw_Grid    : Boolean := False;
      Parse_Failed : Boolean := False;

      function Starts_With
        (Value  : String;
         Prefix : String)
         return Boolean is
      begin
         return Value'Length >= Prefix'Length
           and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

      function Try_Parse_Natural
        (Text  : String;
         Value : out Natural)
         return Boolean
      is
         Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      begin
         Value := 0;
         if Clean = "" then
            return False;
         end if;

         for Position in Clean'Range loop
            if Clean (Position) not in '0' .. '9'
              or else Value > (Natural'Last - Character'Pos (Clean (Position)) + Character'Pos ('0')) / 10
            then
               return False;
            end if;
            Value := Value * 10 + Character'Pos (Clean (Position)) - Character'Pos ('0');
         end loop;

         return True;
      end Try_Parse_Natural;

      function Try_Parse_Role
        (Text : String;
         Role : out Icon_Asset_Color_Role)
         return Boolean
      is
         Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      begin
         if Clean = "base" then
            Role := Icon_Asset_Base;
            return True;
         elsif Clean = "accent" then
            Role := Icon_Asset_Accent;
            return True;
         elsif Clean = "border" then
            Role := Icon_Asset_Border;
            return True;
         elsif Clean = "muted" then
            Role := Icon_Asset_Muted;
            return True;
         else
            Role := Icon_Asset_Base;
            return False;
         end if;
      end Try_Parse_Role;

      function Field
        (Text  : String;
         Index : Positive)
         return String
      is
         Start : Positive := Text'First;
         Count : Positive := 1;
      begin
         for Position in Text'Range loop
            if Text (Position) = ',' then
               if Count = Index then
                  return Text (Start .. Position - 1);
               end if;
               Count := Count + 1;
               Start := Position + 1;
            end if;
         end loop;

         if Count = Index then
            return Text (Start .. Text'Last);
         else
            return "";
         end if;
      end Field;

      function Fits_Grid (Rect : Icon_Asset_Rect) return Boolean is
      begin
         return Rect.Grid_X < Result.Grid
           and then Rect.Grid_Y < Result.Grid
           and then Rect.Grid_W <= Result.Grid - Rect.Grid_X
           and then Rect.Grid_H <= Result.Grid - Rect.Grid_Y;
      end Fits_Grid;

      procedure Parse_Line
        (Raw_Line : String)
      is
         Line : constant String := Ada.Strings.Fixed.Trim (Raw_Line, Ada.Strings.Both);
      begin
         if Line = "" then
            return;
         elsif not Saw_Header then
            Saw_Header := Is_Format_Header (Line);
         elsif Starts_With (Line, "name=") then
            Result.Name := To_Unbounded_String (Line (Line'First + 5 .. Line'Last));
            Saw_Name := Length (Result.Name) > 0;
         elsif Starts_With (Line, "grid=") then
            declare
               Grid_Value : Natural;
            begin
               if not Try_Parse_Natural (Line (Line'First + 5 .. Line'Last), Grid_Value)
                 or else Grid_Value = 0
               then
                  Parse_Failed := True;
                  return;
               end if;

               Result.Grid := Grid_Value;
               Saw_Grid := True;
            end;
         elsif Starts_With (Line, "rect=") then
            if not Saw_Grid then
               Parse_Failed := True;
               return;
            end if;

            declare
               Data  : constant String := Line (Line'First + 5 .. Line'Last);
               Rect  : Icon_Asset_Rect;
            begin
               if not Try_Parse_Natural (Field (Data, 1), Rect.Grid_X)
                 or else not Try_Parse_Natural (Field (Data, 2), Rect.Grid_Y)
                 or else not Try_Parse_Natural (Field (Data, 3), Rect.Grid_W)
                 or else not Try_Parse_Natural (Field (Data, 4), Rect.Grid_H)
                 or else not Try_Parse_Role (Field (Data, 5), Rect.Role)
               then
                  Parse_Failed := True;
                  return;
               end if;

               if Rect.Grid_W = 0 or else Rect.Grid_H = 0 or else not Fits_Grid (Rect) then
                  Parse_Failed := True;
                  return;
               end if;
               Result.Rectangles.Append (Rect);
            end;
         elsif Starts_With (Line, "tri=") then
            if not Saw_Grid then
               Parse_Failed := True;
               return;
            end if;

            declare
               Data : constant String := Line (Line'First + 4 .. Line'Last);
               Tri  : Icon_Asset_Tri;
            begin
               if not Try_Parse_Natural (Field (Data, 1), Tri.X1)
                 or else not Try_Parse_Natural (Field (Data, 2), Tri.Y1)
                 or else not Try_Parse_Natural (Field (Data, 3), Tri.X2)
                 or else not Try_Parse_Natural (Field (Data, 4), Tri.Y2)
                 or else not Try_Parse_Natural (Field (Data, 5), Tri.X3)
                 or else not Try_Parse_Natural (Field (Data, 6), Tri.Y3)
                 or else not Try_Parse_Role (Field (Data, 7), Tri.Role)
               then
                  Parse_Failed := True;
                  return;
               end if;

               --  Vertices may sit on the grid edge (0 .. Grid), unlike a rect's
               --  top-left origin which must be strictly inside.
               if Tri.X1 > Result.Grid or else Tri.Y1 > Result.Grid
                 or else Tri.X2 > Result.Grid or else Tri.Y2 > Result.Grid
                 or else Tri.X3 > Result.Grid or else Tri.Y3 > Result.Grid
               then
                  Parse_Failed := True;
                  return;
               end if;
               Result.Triangles.Append (Tri);
            end;
         else
            Parse_Failed := True;
            return;
         end if;
      end Parse_Line;

      Line_Start : Positive := Content'First;
   begin
      if Content = "" then
         return Result;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            if Index > Line_Start then
               Parse_Line (Content (Line_Start .. Index - 1));
            else
               Parse_Line ("");
            end if;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Parse_Line (Content (Line_Start .. Content'Last));
      end if;

      Result.Valid :=
        not Parse_Failed
        and then Saw_Header
        and then Saw_Name
        and then Saw_Grid
        and then not Result.Rectangles.Is_Empty;
      return Result;
   exception
      when Error : others =>
         Guikit.Errors.Note (Error, "Guikit.Draw");
         Result.Valid := False;
         Result.Rectangles.Clear;
         return Result;
   end Parse_Icon_Asset;

end Guikit.Draw;
