' =========================================================================
'Unipolar stepper ULN2803 testing program.
'By Larry McGrew, Mar. 2010                
'See end of file for terms of use.
  
{{This program runs a unipolar stepper in three modes. ramps up and down, goes forward
 and reverse and powers down at the end. It would have to be modified in order for another
 object to pass parameters to it. I may submit a demo but I would welcome feedback to see if
 one is needed. You will see Jon Williams influence because I studied and adapted his work. My thanks
 to Jon!}}


'P7   <────│    I used io pins 4-7
'P6   <────│
'P5   <────│
'P4   <────│
   


CON

  _CLKMODE      = XTAL1 + PLL16X
  _XINFREQ      = 5_000_000
                                     

VAR

  long  idx, stpIdx, stpDelay
                                     
                                
PUB main

  dira[7..4]~~                           'make pins outputs
   FullStep                              'High torque
   Wave                                  'Low torque
   HalfStep                              'Higher precision
  
PUB FullStep                              'High torque 
      stpDelay := 65                     'initial speed
   {{I want this to ramp so I start with a beginning stpDelay of 65 then increment by 3
   until I reach the limit of 250 steps per/sec}}
                                                   
   repeat 500                            'Distance
      stpDelay := 250                    'No ramp      
      stepFwd      
      waitcnt(clkfreq/stpDelay + cnt)    'speed   250 steps per second

   pause(500)
   stpDelay := 65
                            
       repeat 500                        
          stpDelay := stpDelay + 3 <#250     'Ramp        
          stepRev      
          waitcnt(clkfreq/stpDelay + cnt)    
       repeat until stpDelay < 40            'repeat until ...stopped the looping! 
          stpDelay := stpDelay - 4          
          waitcnt(clkfreq/stpDelay + cnt)
          stepRev
          
       pause(500)   
          
PUB Wave                                  'Low torque
      stpDelay := 65
        
   repeat 500                                     
      stpDelay :=320                      
      stepFwdWave      
      waitcnt(clkfreq/stpDelay + cnt)
           
   pause(500)
        stpDelay := 65
    
   repeat 500                                     
      stpDelay := stpDelay + 3 <#320                     
      stepRevWave      
      waitcnt(clkfreq/stpDelay + cnt)
   repeat until stpDelay < 40  
     stpDelay := stpDelay - 4
     stepRevWave
     waitcnt(clkfreq/stpDelay + cnt)
     
   pause(500) 

PUB HalfStep                              'Higher precision
      stpDelay := 65
      
   repeat 500                                     
      stpDelay :=320                     
      HalfStepFwd      
      waitcnt(clkfreq/stpDelay + cnt)
      
   pause(500)
   stpDelay := 65
    
               
   repeat 500                                     
      stpDelay := stpDelay + 3 <#320                       
      HalfStepRev      
      waitcnt(clkfreq/stpDelay + cnt)
   repeat until stpDelay < 40  
     stpDelay := stpDelay - 4     
     waitcnt(clkfreq/stpDelay + cnt)
     HalfStepRev
     
   dira[7..4]~           


PRI stepFwd

  stpIdx := ++stpIdx // 4                    ' point to next step
  outa[7..4] := Steps[stpIdx]                ' update outputs
  

PRI stepRev

  stpIdx := (stpIdx + 3) // 4                ' point to previous step
  outa[7..4] := Steps[stpIdx]                ' update outputs
  

PRI stepFwdWave

  stpIdx := ++stpIdx // 4                              
  outa[7..4] := StepsW[stpIdx]                         
  

PRI stepRevWave

  stpIdx := (stpIdx + 3) // 4                         
  outa[7..4] := StepsW[stpIdx]                        
  

PRI HalfStepFwd

  stpIdx := ++stpIdx // 8                               
  outa[7..4] := StepsH[stpIdx]                         
  

PRI HalfStepRev

  stpIdx := (stpIdx + 7) // 8                           
  outa[7..4] := StepsH[stpIdx]                         
    

PRI pause(ms) | c

  c := cnt                                   ' sync with system counter
  repeat until (ms-- == 0)                   ' repeat while time left
    waitcnt(c += clkfreq / 1000)             ' wait 1 ms
   

DAT

  Steps       byte  %0011, %0110, %1100, %1001                               ' full step
  StepsW      byte  %0001, %0010, %0100, %1000                               ' Wave
  StepsH      byte  %0001, %0011, %0010, %0110, %0100, %1100, %1000, %1001   ' Half step


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
  