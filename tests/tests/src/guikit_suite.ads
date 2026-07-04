with AUnit.Test_Suites;

package Guikit_Suite is

   --  Return the complete guikit AUnit suite.
   --
   --  @return Test suite containing the guikit unit tests.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Guikit_Suite;
