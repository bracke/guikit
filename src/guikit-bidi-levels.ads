--  The embedding levels of one paragraph (UAX #9 rules P2 to I2 and L1),
--  resolved phase by phase: the explicit levels over the whole paragraph,
--  then the weak types, paired brackets, neutrals and implicit levels over
--  each isolating run sequence, and last the trailing whitespace.
private package Guikit.Bidi.Levels is

   --  The work of Guikit.Bidi.Resolve_Levels.
   --
   --  @param Text The paragraph's code points, in stored order.
   --  @param Direction Auto takes the first strong character's (rules P2, P3).
   --  @param Levels Each character's level, or Removed.
   --  @param Paragraph_Level 0 for a left-to-right paragraph, 1 for right-to-left.
   procedure Resolve
     (Text            : Codepoint_Array;
      Direction       : Paragraph_Direction;
      Levels          : out Level_Array;
      Paragraph_Level : out Natural)
     with Pre => Levels'First = Text'First and then Levels'Length = Text'Length;

end Guikit.Bidi.Levels;
