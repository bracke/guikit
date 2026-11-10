package body Guikit.Errors is

   --  Set once at startup, read by whichever thread catches something.
   Current : Reporter := null with Atomic;

   procedure Set_Reporter (To : Reporter) is
   begin
      Current := To;
   end Set_Reporter;

   procedure Note (Occurrence : Ada.Exceptions.Exception_Occurrence; Where : String) is
      Report : constant Reporter := Current;
   begin
      if Report /= null then
         Report (Occurrence, Where);
      end if;
   exception
      --  A failing reporter must not turn a handled failure into a new one.
      when others =>
         null;
   end Note;

end Guikit.Errors;
