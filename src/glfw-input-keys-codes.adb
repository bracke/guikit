package body Glfw.Input.Keys.Codes is

   function To_Key_Code (Pressed : Key) return Guikit.Input.Key_Code is
   begin
      case Pressed is
         when Key_1 =>
            return Guikit.Input.Key_1;
         when Key_2 =>
            return Guikit.Input.Key_2;
         when Key_3 =>
            return Guikit.Input.Key_3;
         when Key_4 =>
            return Guikit.Input.Key_4;
         when A =>
            return Guikit.Input.Key_A;
         when B =>
            return Guikit.Input.Key_B;
         when C =>
            return Guikit.Input.Key_C;
         when D =>
            return Guikit.Input.Key_D;
         when F =>
            return Guikit.Input.Key_F;
         when I =>
            return Guikit.Input.Key_I;
         when L =>
            return Guikit.Input.Key_L;
         when N =>
            return Guikit.Input.Key_N;
         when P =>
            return Guikit.Input.Key_P;
         when R =>
            return Guikit.Input.Key_R;
         when S =>
            return Guikit.Input.Key_S;
         when V =>
            return Guikit.Input.Key_V;
         when X =>
            return Guikit.Input.Key_X;
         when Z =>
            return Guikit.Input.Key_Z;
         when Comma =>
            return Guikit.Input.Key_Comma;
         when Backspace =>
            return Guikit.Input.Key_Backspace;
         when Delete =>
            return Guikit.Input.Key_Delete;
         when F2 =>
            return Guikit.Input.Key_F2;
         when F5 =>
            return Guikit.Input.Key_F5;
         when Escape =>
            return Guikit.Input.Key_Escape;
         when Enter | Numpad_Enter =>
            return Guikit.Input.Key_Return;
         when Left =>
            return Guikit.Input.Key_Left;
         when Right =>
            return Guikit.Input.Key_Right;
         when Up =>
            return Guikit.Input.Key_Up;
         when Down =>
            return Guikit.Input.Key_Down;
         when Home =>
            return Guikit.Input.Key_Home;
         when Key_End =>
            return Guikit.Input.Key_End;
         when Page_Up =>
            return Guikit.Input.Key_Page_Up;
         when Page_Down =>
            return Guikit.Input.Key_Page_Down;
         when Equal | Right_Bracket | Numpad_Add =>
            return Guikit.Input.Key_Equal;
         when Minus | Slash | Numpad_Substract =>
            return Guikit.Input.Key_Minus;
         when Key_0 =>
            return Guikit.Input.Key_0;
         when Space =>
            return Guikit.Input.Key_Space;
         when Key_5 =>
            return Guikit.Input.Key_5;
         when Key_6 =>
            return Guikit.Input.Key_6;
         when Key_7 =>
            return Guikit.Input.Key_7;
         when Key_8 =>
            return Guikit.Input.Key_8;
         when Key_9 =>
            return Guikit.Input.Key_9;
         when E =>
            return Guikit.Input.Key_E;
         when G =>
            return Guikit.Input.Key_G;
         when H =>
            return Guikit.Input.Key_H;
         when J =>
            return Guikit.Input.Key_J;
         when K =>
            return Guikit.Input.Key_K;
         when M =>
            return Guikit.Input.Key_M;
         when O =>
            return Guikit.Input.Key_O;
         when Q =>
            return Guikit.Input.Key_Q;
         when T =>
            return Guikit.Input.Key_T;
         when U =>
            return Guikit.Input.Key_U;
         when W =>
            return Guikit.Input.Key_W;
         when Y =>
            return Guikit.Input.Key_Y;
         when F1 =>
            return Guikit.Input.Key_F1;
         when F3 =>
            return Guikit.Input.Key_F3;
         when F4 =>
            return Guikit.Input.Key_F4;
         when F6 =>
            return Guikit.Input.Key_F6;
         when F7 =>
            return Guikit.Input.Key_F7;
         when F8 =>
            return Guikit.Input.Key_F8;
         when F9 =>
            return Guikit.Input.Key_F9;
         when F10 =>
            return Guikit.Input.Key_F10;
         when F11 =>
            return Guikit.Input.Key_F11;
         when F12 =>
            return Guikit.Input.Key_F12;
         when Tab =>
            return Guikit.Input.Key_Tab;
         when Insert =>
            return Guikit.Input.Key_Insert;
         when Menu =>
            return Guikit.Input.Key_Menu;
         when others =>
            return Guikit.Input.Key_Unknown;
      end case;
   end To_Key_Code;

   function To_Modifiers (Mods : Modifiers) return Guikit.Input.Modifier_Set is
      Held : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Held (Guikit.Input.Shift_Key) := Mods.Shift;
      Held (Guikit.Input.Control_Key) := Mods.Control;
      Held (Guikit.Input.Alt_Key) := Mods.Alt;
      Held (Guikit.Input.Meta_Key) := Mods.Super;
      return Held;
   end To_Modifiers;

end Glfw.Input.Keys.Codes;
