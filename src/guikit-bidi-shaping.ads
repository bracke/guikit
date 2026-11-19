--  Arabic joining (ArabicShaping.txt): each letter takes the presentation
--  form its neighbours call for, and lam followed by alef becomes one
--  ligature, as far as the font can draw those forms.
private package Guikit.Bidi.Shaping is

   type Flag_Array is array (Positive range <>) of Boolean;

   --  Shape the letters of one paragraph.
   --
   --  @param Points The paragraph's code points, in stored order.
   --  @param Drawable Whether the font can draw a code point; a form it
   --  cannot draw is left as the plain letter.
   --  @param Shaped Each code point as drawn: its presentation form, or the
   --  code point itself.
   --  @param Ligated Whether the code point is a lam drawn as a lam-alef
   --  ligature.
   --  @param Swallowed Whether the code point is the alef such a ligature
   --  draws, which has no glyph of its own.
   procedure Shape
     (Points    : Codepoint_Array;
      Drawable  : not null access function (Codepoint : Natural) return Boolean;
      Shaped    : out Codepoint_Array;
      Ligated   : out Flag_Array;
      Swallowed : out Flag_Array)
     with Pre =>
       Shaped'First = Points'First and then Shaped'Length = Points'Length
       and then Ligated'First = Points'First and then Ligated'Length = Points'Length
       and then Swallowed'First = Points'First and then Swallowed'Length = Points'Length;

end Guikit.Bidi.Shaping;
