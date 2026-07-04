with Guikit_Suite.Widgets;
with Guikit_Suite.Layout;
with Guikit_Suite.Utf8;
with Guikit_Suite.Input;
with Guikit_Suite.Frame_Analysis;
with Guikit_Suite.Palette;

package body Guikit_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (Guikit_Suite.Widgets.Suite);
      Result.Add_Test (Guikit_Suite.Layout.Suite);
      Result.Add_Test (Guikit_Suite.Utf8.Suite);
      Result.Add_Test (Guikit_Suite.Input.Suite);
      Result.Add_Test (Guikit_Suite.Frame_Analysis.Suite);
      Result.Add_Test (Guikit_Suite.Palette.Suite);
      return Result;
   end Suite;

end Guikit_Suite;
