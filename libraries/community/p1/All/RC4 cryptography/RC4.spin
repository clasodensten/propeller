{{

                **************************************************
                          RC4 V1.0       Alleged RC4 
                **************************************************
                   coded by Jason Wood jtw.programmer@gmail.com        
                ************************************************** 

                  ┌──────────────────────────────────────────┐
                  │ Copyright (c) 2008 Jason T Wood          │               
                  │     See end of file for terms of use.    │               
                  └──────────────────────────────────────────┘
                         
}}
VAR

  byte RC4_Return[255]
  byte HE[255]
  byte RB[255]
  byte HP[255]

pub Cryptography (Expression, Password) : stringptr | X, Y, Z, Temp, PS, ES
{{

  Accepts an Expression that is either encrypted or plain text as well as
  a password to either encrypt or decrypt the Expression. Obviously if the
  Expression is plain text it will get encrypted an if it's already been
  encrypted then it will get decrypted. You can not send a password > 255
  bytes or the function will fail but you can increase the Expression's
  size if you feel the need.

  Often if you try and print the encrypted output to a terminal it will not
  print correctly. This is do to the crazy characters that get returned
  in the encrypted state. 
  
CON

  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000

OBJ
                         
  BS2 : "BS2_Functions"
  RC4 : "RC4"

PUB go | RC4_Value[255] 

  BS2.start (31, 30, 4800, 1)           ' Initialize BS2 Object, Rx and Tx pins for DEBUG
  BS2.Debug_Str ( String(13) )
    
  RC4_Value := RC4.Cryptography(string("Expression"), string("Password"))
  BS2.Debug_Str ( String("Encoded: ") )  
  BS2.Debug_Str ( RC4_Value )
  BS2.Debug_Str ( string(13) )  

  RC4_Value := RC4.Cryptography(RC4_Value, string("Password"))
  BS2.Debug_Str ( String("Decoded: ") )
  BS2.Debug_Str ( RC4_Value )
  BS2.Debug_Str ( string(13) )

}}

  ES := strsize(Expression)
  PS := strsize(Password)

  if ES == 0 OR PS == 0
    return string("Error: Expression and Password must have a lenght > 0", 13)

  if PS > 255
    return string("Error: Password can not exceed 255 characters", 13)
  
  repeat X from 0 to 255
    RB[X] := X

  X := 0
  repeat ES
    HE[X++] := RC4_Return[X] := byte[Expression++]
    
  X := 0
  repeat PS
    HP[X++] := byte[Password++]
        
  X := 0
  Y := 0
  Z := 0
  
  repeat X from 0 to 255
    Y := (Y + RB[X] + HP[X - (PS * (X / PS))]) 
    Y -= 256 * (Y / 256)
    Temp := RB[X]
    RB[X] := RB[Y]
    RB[Y] := Temp      

  X := 0
  Y := 0
  Z := 0
  
  repeat X from 0 to ES - 1
    Y := (Y + 1)
    Y -= 256 * (Y / 256)
    
    Z := (Z + RB[Y])
    Z -= 256 * (Z / 256)
    
    Temp := RB[Y]
    RB[Y] := RB[Z]
    RB[Z] := Temp

    Temp := (RB[Y] + RB[Z])
    Temp -= 256 * (Temp / 256)
    Temp := RB[Temp]
    
    RC4_Return[X] := RC4_Return[X] ^ Temp

  RC4_Return[ES] := 0

  stringptr := @RC4_Return


{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}