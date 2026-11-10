with Ada.Exceptions;

--  Where guikit tells its application of an exception it carries on past (a
--  Vulkan step that fails into a False result, a drop it could not hand
--  over): the application installs its own reporter -- its diagnostics log
--  -- and guikit stays free of any logging of its own. Without one, Note does
--  nothing, as before.
package Guikit.Errors is

   --  What an application does with an exception guikit noted.
   type Reporter is access procedure (Occurrence : Ada.Exceptions.Exception_Occurrence; Where : String);

   --  Send what Note is given to To from now on; null stops it.
   --
   --  @param To The application's reporter.
   procedure Set_Reporter (To : Reporter);

   --  Tell the reporter, if there is one, of an exception guikit caught and
   --  carries on past. Never raises.
   --
   --  @param Occurrence What was caught.
   --  @param Where The guikit unit that caught it.
   procedure Note (Occurrence : Ada.Exceptions.Exception_Occurrence; Where : String);

end Guikit.Errors;
