with Ada.Containers.Vectors;
with System.Address_To_Access_Conversions;

package body Glfw.Windows.Drop.Paths is

   use type System.Address;
   use type Interfaces.C.Strings.chars_ptr;
   use type Interfaces.C.int;

   type Watched is record
      Raw   : System.Address := System.Null_Address;
      Into  : access Receiver'Class;
      Limit : Positive := 1;
   end record;

   package Watched_Vectors is new Ada.Containers.Vectors (Positive, Watched);

   --  Read and written on the thread that creates windows and polls events.
   Windows : Watched_Vectors.Vector;

   type C_Path_Array is array (Positive range 1 .. Positive'Last) of Interfaces.C.Strings.chars_ptr
     with Convention => C;
   package C_Path_Array_Pointers is new System.Address_To_Access_Conversions (C_Path_Array);

   procedure Dropped_On
     (Window : System.Address;
      Count  : Interfaces.C.int;
      Paths  : System.Address)
     with Convention => C;

   function Collect
     (Count : Natural;
      Item  : not null access function (Index : Positive) return Interfaces.C.Strings.chars_ptr;
      Limit : Positive)
      return Path_Vectors.Vector
   is
      Got : Path_Vectors.Vector;
   begin
      for Index in 1 .. Count loop
         exit when Natural (Got.Length) = Limit;
         declare
            Path : constant Interfaces.C.Strings.chars_ptr := Item (Index);
         begin
            if Path /= Interfaces.C.Strings.Null_Ptr then
               Got.Append (Interfaces.C.Strings.Value (Path));
            end if;
         end;
      end loop;
      return Got;
   end Collect;

   procedure Dropped_On
     (Window : System.Address;
      Count  : Interfaces.C.int;
      Paths  : System.Address)
   is
      Target : access Receiver'Class := null;
   begin
      if Paths = System.Null_Address or else Count <= 0 then
         return;
      end if;
      for Item of Windows loop
         if Item.Raw = Window then
            Target := Item.Into;
            declare
               Raw : constant C_Path_Array_Pointers.Object_Pointer := C_Path_Array_Pointers.To_Pointer (Paths);

               function Entry_At (Index : Positive) return Interfaces.C.Strings.chars_ptr is (Raw.all (Index));
            begin
               --  Read GLFW's array in place, straight into the (heap) result:
               --  no copy of it is made, so a drop of thousands of paths -- a
               --  Limit in the tens of thousands -- puts nothing on the stack
               --  of this callback, which on Windows has only about 1 MiB.
               Item.Into.Receive (Collect (Natural (Count), Entry_At'Access, Item.Limit));
            end;
            return;
         end if;
      end loop;
   exception
      --  Called from GLFW's C frames: nothing may unwind through them, not
      --  even from the receiver's own Failed.
      when Error : others =>
         if Target /= null then
            begin
               Target.Failed (Error);
            exception
               --  The receiver's own report failed: there is nobody left to tell.
               when others =>
                  null;
            end;
         end if;
   end Dropped_On;

   procedure Watch
     (Window : not null access Glfw.Windows.Window;
      Into   : not null access Receiver'Class;
      Limit  : Positive) is
   begin
      Forget (Window);
      Windows.Append (Watched'(Raw => Window.Handle, Into => Into, Limit => Limit));
      Set_Drop_Callback (Window, Dropped_On'Access);
   end Watch;

   procedure Forget (Window : not null access Glfw.Windows.Window) is
   begin
      for Index in reverse Windows.First_Index .. Windows.Last_Index loop
         if Windows (Index).Raw = Window.Handle then
            Windows.Delete (Index);
         end if;
      end loop;
   end Forget;

end Glfw.Windows.Drop.Paths;
