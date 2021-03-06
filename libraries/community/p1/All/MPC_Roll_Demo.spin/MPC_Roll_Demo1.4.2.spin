{{ MPC_Roll_Demo.spin - Motor Position Controller V1.4.2

        TOBI - The Tool Bot Roll Test 1
        http://letsmakerobots.com/node/7025
        TheGrue: gruesnest@gmail.com

        V1.4.2 - Added 1/2 second wait period for FullDuplexSerialPlus to initialize

Schematics:

                MPC_Pin   1KΩ
     Propeller  ────────── DATA  ──────────────────────────────  NC
                             5V ─ 5V    (Position controller 1)─────── (Position controller 2)
                                ┌─ GND   ──────────────────────────────  NC
                                
                                    Each position controller has an "Out to HB-25" 
                                    Conecct this to each HB-25


       Motor and HB-25 wiring

    ┌───────┐ M1                                            Robot Base Layout
    │       ├──── Blue ───┌───┐                                  Front
    │ HB-25 │ M2           │   │ Motor                         ┌─────────┐
    │       ├──── Yellow ─└───┘                               │    ‣    │
    └───────┘                                                  │ Caster  │
                                                         Left  │         │ Right
                                                               │         │
                                                         ID 1  │       │ ID 2
                                                               └─────────┘
                                                                   Rear

Notes: This setup runs Caster first with the Right Position Controller reversed in the Code.
To run with the wheels first you need to reverse the wires on the HB-25's AND reverse the Left
Position Controller in the code [or leave the code and switch the ID jumpers on the controllers]

}}

OBJ

  DrvMtr : "FullDuplexSerialPlus"                       ' Included with Propeller Tool

CON
  _clkmode      = xtal1 + pll16x                        ' Set Propeller to run 
  _xinfreq      = 5_000_000                             ' at 80 Mhz

           
  QPOS                          = $08                   ' Query Position
  QSPD                          = $10                   ' Query Speed
  CHFA                          = $18                   ' Check for Arrival
  TRVL                          = $20                   ' Travel Number of Positions
  CLRP                          = $28                   ' Clear Position
  SREV                          = $30                   ' Set Orientation as Reversed
  STXD                          = $38                   ' Set TX Delay
  SMAX                          = $40                   ' Set Speed Maximum
  SSRR                          = $48                   ' Set Speed Ramp Rate
   
  AllWheels     = 0
  RightWheel    = 2
  LeftWheel     = 1

  MPC_Pin       = 0                                     ' Motor Position Controller pin
  Button_Pin    = 8

PUB main

   dira[MPC_Pin]~~
  
  DrvMtr.Start(MPC_Pin,MPC_Pin,0,19200)                 ' Establish comunications to MPC
  waitcnt(clkfreq / 2 + cnt)                            ' 1/2 second to allow FDSP to init
  SetAsReversed(LeftWheel)                              ' This might need to be changed depending upon what direction is "Forward"

  waitcnt(clkfreq * 5 + cnt)                            ' Wait 5 seconds before moving
  
  GoForward (0,300)                                     ' Move forward
  repeat                                                ' Keep cog awake

PRI GoForward (Wheel, Dist)
   DrvMtr.TX(TRVL + Wheel)
   DrvMtr.TX(Dist.BYTE[1])
   DrvMtr.TX(Dist.BYTE[0])

PRI SetAsReversed (Wheel) 
  DrvMtr.TX(SREV + Wheel)
  