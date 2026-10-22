with Ada.Directories;
with Ada.Strings.Unbounded;
with Interfaces;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Guikit.Draw;
with Guikit.Text;

--  Glyph atlas tests for Guikit.Text.Build_Glyphs: a frame whose glyphs no
--  longer fit an atlas grown as far as it may comes out as if built on an
--  empty atlas, not with glyphs pointing at places reused partway through.
package body Guikit_Suite.Text is

   use AUnit.Assertions;
   use Guikit.Draw;

   type Text_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Text_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Text_Test_Case);

   procedure Test_Full_Atlas_Rebuilds_Frame (T : in out AUnit.Test_Cases.Test_Case'Class);

   --  A monospace face each host has, as textrender's own tests look for.
   Font_Candidates : constant array (Positive range <>) of access constant String :=
     [new String'("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
      new String'("/usr/share/fonts/TTF/DejaVuSansMono.ttf"),
      new String'("/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf"),
      new String'("/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf"),
      new String'("/System/Library/Fonts/Menlo.ttc"),
      new String'("/System/Library/Fonts/Monaco.ttf"),
      new String'("C:\Windows\Fonts\consola.ttf"),
      new String'("C:\Windows\Fonts\cour.ttf")];

   function Font_Path return String is
   begin
      for Candidate of Font_Candidates loop
         if Ada.Directories.Exists (Candidate.all) then
            return Candidate.all;
         end if;
      end loop;
      return "";
   end Font_Path;

   function Line (Text : String) return Text_Command_Vectors.Vector is
      Result : Text_Command_Vectors.Vector;
   begin
      Result.Append
        (Text_Command'
           (X      => 0,
            Y      => 0,
            Width  => 100_000,
            Height => 200,
            Text   => Ada.Strings.Unbounded.To_Unbounded_String (Text),
            others => <>));
      return Result;
   end Line;

   --  Glyphs this large fill a 128-column atlas, one per shelf, long before
   --  it reaches the height it may grow to, so a few dozen letters need it
   --  emptied.
   function Start (R : in out Guikit.Text.Renderer) return Boolean is
     (Guikit.Text.Initialize
        (R, Font_Path, Guikit.Text.Font_Path_Vectors.Empty_Vector,
         Pixel_Size => 160, Cell_Width => 100, Cell_Height => 200,
         Atlas_Width => 128, Atlas_Height => 64) = Text_Render_Success);

   procedure Test_Full_Atlas_Rebuilds_Frame (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Lower : constant String := "abcdefghijklmnopqrstuvwxyz";
      Upper : constant String := "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
      Empty : Text_Command_Vectors.Vector;
      Used, Fresh : Guikit.Text.Renderer;
      First, Second, Alone : Text_Render_Result;
   begin
      if Font_Path = "" then
         return;
      end if;
      Assert (Start (Used) and then Start (Fresh), "the renderers load the font");

      --  The first frame fills most of the atlas. The second starts with
      --  letters the first packed, then needs more room than is left, so the
      --  atlas is emptied after those first letters were placed.
      First := Guikit.Text.Build_Glyphs (Used, Line (Lower (1 .. 8)), Empty);
      Second := Guikit.Text.Build_Glyphs (Used, Line (Lower (1 .. 3) & Upper (1 .. 14)), Empty);
      Alone := Guikit.Text.Build_Glyphs (Fresh, Line (Lower (1 .. 3) & Upper (1 .. 14)), Empty);
      Assert (First.Status = Text_Render_Success and then Second.Status = Text_Render_Success,
              "both frames build");
      Assert (Natural (Second.Glyphs.Length) = 17 and then Natural (Alone.Glyphs.Length) = 17,
              "every letter has a glyph");

      --  Built again after the emptying, the frame lies in the atlas exactly
      --  as it does when it is the first frame an atlas sees.
      --  Built again after the emptying, every glyph's rectangle holds that
      --  glyph's picture -- the same pixels a fresh atlas holds for it --
      --  and no two of them share room.
      declare
         use type Interfaces.Unsigned_8;
         type Bytes is array (Natural range <>) of Interfaces.Unsigned_8;
         Here : Bytes (0 .. Second.Atlas_Width * Second.Atlas_Height - 1)
           with Import, Address => Second.Atlas_Pixels;
         There : Bytes (0 .. Alone.Atlas_Width * Alone.Atlas_Height - 1)
           with Import, Address => Alone.Atlas_Pixels;
      begin
         for Index in Second.Glyphs.First_Index .. Second.Glyphs.Last_Index loop
            declare
               Got  : constant Glyph_Command := Second.Glyphs (Index);
               Want : constant Glyph_Command := Alone.Glyphs (Index);
               Same : Boolean := Got.Atlas_W = Want.Atlas_W and then Got.Atlas_H = Want.Atlas_H;
            begin
               Assert (Got.Atlas_X + Got.Atlas_W <= Second.Atlas_Width
                       and then Got.Atlas_Y + Got.Atlas_H <= Second.Atlas_Height,
                       "glyph" & Index'Image & " lies inside the atlas");
               for Row in 0 .. Got.Atlas_H - 1 loop
                  exit when not Same;
                  for Column in 0 .. Got.Atlas_W - 1 loop
                     if Here ((Got.Atlas_Y + Row) * Second.Atlas_Width + Got.Atlas_X + Column)
                       /= There ((Want.Atlas_Y + Row) * Alone.Atlas_Width + Want.Atlas_X + Column)
                     then
                        Same := False;
                        exit;
                     end if;
                  end loop;
               end loop;
               Assert (Same, "glyph" & Index'Image & " is drawn from its own picture");
               for Other in Index + 1 .. Second.Glyphs.Last_Index loop
                  declare
                     O : constant Glyph_Command := Second.Glyphs (Other);
                  begin
                     Assert (O.Atlas_X >= Got.Atlas_X + Got.Atlas_W
                             or else Got.Atlas_X >= O.Atlas_X + O.Atlas_W
                             or else O.Atlas_Y >= Got.Atlas_Y + Got.Atlas_H
                             or else Got.Atlas_Y >= O.Atlas_Y + O.Atlas_H,
                             "glyphs" & Index'Image & " and" & Other'Image & " do not share room");
                  end;
               end loop;
            end;
         end loop;
      end;
   end Test_Full_Atlas_Rebuilds_Frame;

   overriding function Name (T : Text_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("guikit text glyph atlas");
   end Name;

   overriding procedure Register_Tests (T : in out Text_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Full_Atlas_Rebuilds_Frame'Access,
         "a frame that fills the atlas partway through is built again on the emptied atlas");
   end Register_Tests;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Text_Test_Case));
      return Result;
   end Suite;

end Guikit_Suite.Text;
