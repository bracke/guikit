with Ada.Unchecked_Deallocation;

package body Guikit.Shared_Bytes is

   procedure Free is new Ada.Unchecked_Deallocation (Payload, Payload_Access);

   --  Hands out serials; buffers are made from more than one task.
   protected Serials is
      procedure Next (Value : out Natural);
   private
      Last : Natural := 0;
   end Serials;

   protected body Serials is
      procedure Next (Value : out Natural) is
      begin
         Last := (if Last = Natural'Last then 1 else Last + 1);
         Value := Last;
      end Next;
   end Serials;

   function To_Shared (Value : Byte_Vectors.Vector) return Bytes is
   begin
      if Value.Is_Empty then
         return Empty;
      end if;
      declare
         Number : Natural;
      begin
         Serials.Next (Number);
         --  A new Atomic_Counter starts at one: this value is the only holder.
         return (Ada.Finalization.Controlled with Ref => new Payload'(Count => <>, Serial => Number, Data => Value));
      end;
   end To_Shared;

   function To_Vector (Value : Bytes) return Byte_Vectors.Vector is
   begin
      if Value.Ref = null then
         return Byte_Vectors.Empty_Vector;
      end if;
      return Value.Ref.Data;
   end To_Vector;

   function Length (Value : Bytes) return Natural is
     (if Value.Ref = null then 0 else Natural (Value.Ref.Data.Length));

   function Serial (Value : Bytes) return Natural is
     (if Value.Ref = null then 0 else Value.Ref.Serial);

   function Element (Value : Bytes; Index : Positive) return Interfaces.Unsigned_8 is
     (Value.Ref.Data.Element (Index));

   overriding function "=" (Left, Right : Bytes) return Boolean is
      use type Byte_Vectors.Vector;
   begin
      if Left.Ref = Right.Ref then
         return True;
      elsif Left.Ref = null or else Right.Ref = null then
         return Length (Left) = 0 and then Length (Right) = 0;
      end if;
      return Left.Ref.Data = Right.Ref.Data;
   end "=";

   overriding procedure Adjust (Object : in out Bytes) is
   begin
      if Object.Ref /= null then
         System.Atomic_Counters.Increment (Object.Ref.Count);
      end if;
   end Adjust;

   overriding procedure Finalize (Object : in out Bytes) is
      Ref : Payload_Access := Object.Ref;
   begin
      --  Finalize may run more than once on one object; clear first.
      Object.Ref := null;
      if Ref /= null and then System.Atomic_Counters.Decrement (Ref.Count) then
         Free (Ref);
      end if;
   end Finalize;

end Guikit.Shared_Bytes;
