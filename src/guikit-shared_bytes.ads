with Ada.Containers.Vectors;
with Interfaces;

private with Ada.Finalization;
private with System.Atomic_Counters;

--  Immutable, reference-counted byte buffers for decoded image pixels.
--
--  A thumbnail or icon carried in a draw command, a snapshot or a palette
--  entry was a deep copy at every hop, so each frame rebuild copied every
--  visible image again. A Bytes value is shared on copy instead: copying it
--  only bumps a count, and the bytes are never modified after To_Shared.
package Guikit.Shared_Bytes is

   --  A plain byte vector, for building the bytes before sharing them.
   package Byte_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Interfaces.Unsigned_8,
      "="          => Interfaces."=");

   --  A shared, read-only byte buffer; the default value is empty.
   type Bytes is private;

   --  The empty buffer.
   Empty : constant Bytes;

   --  Share a copy of Value.
   --
   --  @param Value Bytes to share.
   --  @return A buffer holding Value; Empty when Value is empty.
   function To_Shared (Value : Byte_Vectors.Vector) return Bytes;

   --  Copy the bytes out, for an API that needs its own vector.
   --
   --  @param Value Buffer to read.
   --  @return A copy of the bytes.
   function To_Vector (Value : Bytes) return Byte_Vectors.Vector;

   --  @param Value Buffer to measure.
   --  @return Number of bytes held.
   function Length (Value : Bytes) return Natural;

   --  @param Value Buffer to test.
   --  @return True when the buffer holds no bytes.
   function Is_Empty (Value : Bytes) return Boolean is (Length (Value) = 0);

   --  One byte, without copying the buffer.
   --
   --  @param Value Buffer to read.
   --  @param Index One-based position, at most Length (Value).
   --  @return The byte at Index.
   function Element (Value : Bytes; Index : Positive) return Interfaces.Unsigned_8
     with Pre => Index <= Length (Value);

   --  Which buffer Value is: every To_Shared makes a new number, and copies
   --  of a value keep it, so equal serials mean the same bytes without
   --  comparing them (a cache can key on it).
   --
   --  @param Value Buffer to identify.
   --  @return Its serial, or 0 for the empty buffer.
   function Serial (Value : Bytes) return Natural;

   --  Equal when both share one buffer or hold the same bytes.
   --
   --  @param Left First buffer.
   --  @param Right Second buffer.
   --  @return True when the contents are equal.
   overriding function "=" (Left, Right : Bytes) return Boolean;

private

   type Payload is record
      Count  : System.Atomic_Counters.Atomic_Counter;
      Serial : Natural := 0;
      Data   : Byte_Vectors.Vector;
   end record;

   type Payload_Access is access Payload;

   type Bytes is new Ada.Finalization.Controlled with record
      Ref : Payload_Access := null;
   end record;

   overriding procedure Adjust (Object : in out Bytes);
   overriding procedure Finalize (Object : in out Bytes);

   Empty : constant Bytes := (Ada.Finalization.Controlled with Ref => null);

end Guikit.Shared_Bytes;
