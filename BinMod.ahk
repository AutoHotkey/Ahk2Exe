
;@Ahk2Exe-SetVersion     2023.06.05     ; Edition: (y.m.d)
;@Ahk2Exe-SetCopyright   TAC109
;@Ahk2Exe-SetProductName BinMod
;@Ahk2Exe-SetDescription Binary file editor - see Ahk2Exe's PostExec directive
;@Ahk2Exe-SetMainIcon                   ; Override any icon saved as default
/*
 BinMod is a simple, fast binary file editor written by TAC109, designed to be
 called from Ahk2Exe's 'PostExec' compiler directive. Use Ahk2Exe included with
 AutoHotkey v1.1.35+, or check for later Ahk2Exe versions at
 https://www.autohotkey.com/boards/viewtopic.php?f=6&t=65095.


-------------------------  Installation Instructions  --------------------------
                           ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
 Users of Ahk2Exe v1.1.34.03c+ can simply use 'Help' -> 'Check for Updates'.
 Otherwise, compile BinMod.ahk using a recent version 1.1 32-bit Unicode base
 file. Place the resulting BinMod.exe file in the compiler directory that
 contains Ahk2Exe.exe (usually "C:\Program Files\AutoHotkey\Compiler\").


------------------------------  Usage Examples  --------------------------------
                                ¯¯¯¯¯¯¯¯¯¯¯¯¯¯
 With the examples below, the user can make alterations to the compiled program
 to disguise that it is an AutoHotkey compiled script, & also improve security.

0. To use any of the examples 1 - 4 below, add the following 3 lines ONCE ONLY
    to your script immediately prior to the lines used from those examples:

    ;@Ahk2Exe-Obey U_Bin,= "%A_BasePath~^.+\.%" = "bin" ? "Cont" : "Nop" ; .bin?
    ;@Ahk2Exe-Obey U_au, = "%A_IsUnicode%" ? 2 : 1 ; Base file ANSI or Unicode?
    ;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%"

1. To replace '>AUTOHOTKEY SCRIPT<' with ' DATA' (for example) in the .exe made
    from a *.bin base file, add the following line to your script:
    
    ;@Ahk2Exe-%U_Bin%  "%U_au%2.>AUTOHOTKEY SCRIPT<. DATA              "

   Note: In the example above, the replacement field must be upper-case and
    space-filled to give a total of 19 characters in order for the compiled
    program to work correctly. This field should start with a space to avoid
    RCData collating problems with any 'FileInstall' commands in the script.

   Or, if 'DATA' is replaced by the word RANDOM a random number will replace
    this word, and will continue to the end of the 19 character field, e.g.
    
    ;@Ahk2Exe-%U_Bin%  "%U_au%2.>AUTOHOTKEY SCRIPT<. RANDOM"

   Users of ScriptGuard1 (see bit.ly/ScriptGuard) should add a 1 to the line:

    ;@Ahk2Exe-%U_Bin%  "1%U_au%2.>AUTOHOTKEY SCRIPT<. RANDOM"
                        ^
2. To change the 'AutoHotkeyGUI' class to 'My_Class' (for example) add the line:

    ;@Ahk2Exe-Cont  "%U_au%.AutoHotkeyGUI.My_Class"

   If My_Class is replaced by RANDOM a random number will be generated & used.

3. To set the current date and time as the compile time in the generated .exe,
    add one of the following lines (works only until 19 Jan 2038 - MS bug):

    ;@Ahk2Exe-Cont  /SetDateTime     ; Set current local date and time, or
    ;@Ahk2Exe-Cont  /SetUTC          ; Set current UTC date and time

4. To encrypt the embedded script in the .exe with a random key and also provide
    enhanced ScriptGuard security, add one of the the following lines:

    ;@Ahk2Exe-Cont  /ScriptGuard2    ; See 'Parameters in Detail', #4 below
    ;@Ahk2Exe-Cont  /ScriptGuard2pss ; ('Permit /script switch')

5. To prevent the use of "UPX -d" to de-compress a UPX-compressed .exe add the
    following line to your script: (The 'example 0' lines are not needed here.)

    ;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%" "11.UPX." "1.UPX!.", 2


----------------------------  Parameters in Detail  ----------------------------
                              ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
 Parameters are as follows (the first is mandatory, the rest are optional):

   1. Path and file name of file to be modified.

   2. One or more parameters specifying changes to be made, with fields thus:

     a) "1" - match once with 1 byte/character binary file portion.
        "2" - match once with 2 byte/character binary file portion.
        These can be mixed and/or repeated to match more than once.

     b) Simple case-sensitive string for matching.

     c) Simple string to replace matched string.
        If shorter than b, it will be padded with 0x00's.
        If longer than b, an error message will be shown.
        If the replacement string contains the letters RANDOM a random number
        will replace this word, and will continue to the end of the b field.

     Use the same separator between fields a, b, and c (e.g. "." or "`,").

     Parameter 2 can be repeated if required.
     Parameters containing spaces must be enclosed in double quotes.

   3. /SetDateTime or /SetUTC - This parameter sets the compile time to the
      current date and time (local or UTC) in the generated .exe.
      
   4. /ScriptGuard2 or /ScriptGuard2pss - This parameter causes the embedded
      script to be encrypted with a random key, and also adds extra security to
      the generated .exe. The /ScriptGuard2pss version also permits the /script
      switch to be used when running the compiled program, but prevents the
      embedded script from being decrypted when this switch is used.
      See 'https://bit.ly/ScriptGuard' for more details.

*/
; ================================  Program  ===================================
#NoEnv                               ; For performance & future compatibility
#Warn                                ; For catching common errors
#MaxMem 4095                         ; Handle large files
SetBatchLines -1                     ; Run at full speed
#NoTrayIcon
global B:=["UChar","UShort",,"UInt",,,,"UInt64"], Bin, L, Sz, U1
Mes:=">AUTOHOTKEY SCRIPT<", A1:=Bit:=PEz:=Sa:=SG2:=0
SGc := "/ScriptGuard2", SM := "Could not perform " SGc " procedure! ("
((A_PtrSize = 8) || !A_IsUnicode) ? ErrMes("Wrong type of AutoHotkey used!`n`n"
  . "Please compile with a v1.1 32-bit Unicode base file.") : 0
#Include *i A_LineFile\..\..\BinDbg\BinDbg.ahk ; Debugging only
(%false% < 1) ? ErrMes("No parameters supplied!") : 0
FileName := %true%, io("Open", FileName)    ; 1st parameter is file name

Loop % %false%                              ; Number of parameters
{ IfEqual A_Index, 1, continue              ; Skip filename
  Par := %A_Index%                          ; Get parameter
  if par in /SetDateTime,/SetUTC            ; Set current date & time into .exe
  { Date := par="/SetUTC" ? A_NowUTC : A_Now, GetA1()
    Date -= 1970, s                         ; Works until 19 Jan 2038! MS to fix
    NumPut(Date,Bin,A1+8,B.4), io("Alter",[4,A1+8])
  }
  else if Par in %SGc%,%SGc%pss             ; Remember /ScriptGuard2[pss]
    SG2 := [Par, Par = SGc ? 1 : 2], SM := StrReplace(SM, SGc, Par)
  else                                      ; Process text replacements
  { while [1,1][Sep:=SubStr(Par,A_Index,1)] ; Get separator after '1's and '2's
      continue
    Pfld := StrSplit(Par, Sep)              ; Split parameter into fields
    if (Wk := (Pfld.3~="RANDOM"))
      Pfld.3 := SubStr(Pfld.3,1,Wk-1) Rnd(StrLen(Pfld.2)+1-Wk)
    if (Pfld.MaxIndex() != 3 || Pfld.1 = "" || StrLen(Pfld.3) > StrLen(Pfld.2))
      ErrMes("Invalid parameter!`n`n#" A_Index "; """ Par """")
    if (Pfld.2 = Mes && StrLen(Pfld.3) != 19)
      ErrMes("Replacement field not 19 characters long.`n`n""" Par """",0)
    if (Pfld.2 = Mes)
      Mes := Pfld.3
    Slen := StrLen(Pfld.2)                  ; Setup search & replace variables
    VarSetCapacity(Srch1, Slen,   0), StrPut(Pfld.2, &Srch1, "UTF-8")
    VarSetCapacity(Srch2, Slen*2, 0), StrPut(Pfld.2, &Srch2, "UTF-16")
    VarSetCapacity(Rplc1, Slen,   0), StrPut(Pfld.3, &Rplc1, "UTF-8")
    VarSetCapacity(Rplc2, Slen*2, 0), StrPut(Pfld.3, &Rplc2, "UTF-16")
    Loop % StrLen(Pfld.1)                   ; For each type of search
    { Type := SubStr(Pfld.1, A_Index, 1)    ; Scan for search item
      If (Off := InBuf(&Bin, Sz, &Srch%Type%, Slen*Type )) < 0
        ErrMes("String not found!`n`n#" A_Index "=" Type "; """ Pfld.2 """")
      Loop % Slen*Type                      ; Alter buffer & file
        NumPut(NumGet(Rplc%Type%, A_Index-1, B.1), Bin, Off+A_Index-1, B.1)
      io("Alter",[Slen*Type, Off])
} } }
if (SG2)                                    ; Process /ScriptGuard2
{ io(), Buf:= "", VarSetCapacity(BinM,4096,254)
  if !(Mod:=DllCall("BeginUpdateResource", "Str", FileName, "UInt", 0, "Ptr"))
    ErrMes(SM "B1)`n`n'BeginUpdateResource'")
  if !DllCall("UpdateResource", "Ptr",Mod, "Ptr",10, "Str",(BinN:= "  " Rnd(17))
         , "ushort", 0x409, "Ptr", &BinM, "UInt", 4096, "UInt")
    ErrMes(SM "B2)`n`n'UpdateResource'")
  if !DllCall("EndUpdateResource", "Ptr", Mod, "UInt", 0)
    ErrMes(SM "B3)`n`n'EndUpdateResource'")

  hMod       :=DllCall("LoadLibraryEx","Str",FileName,"Ptr",0, "Ptr",2, "Ptr")
  for k, v in ["#1", Mes, "#1"], rc:=pt:=pt1:=pt2:=pt3:=0
  { if (rc   :=DllCall("FindResource", "Ptr",hMod, v ~= "^#\d$" ? "Ptr" : "Str"
        , v ~= "^#\d$" ? SubStr(v,2) : v, "Ptr",k=1 ? 3 : 10,"Ptr"))
      (Sa:=k>1?DllCall("SizeofResource","Ptr",hMod, "Ptr",rc, "UInt") : 0)
    , (pt    :=DllCall("LoadResource",  "Ptr",hMod, "Ptr",rc, "Ptr")), k1:=k
    , (pt%k% :=DllCall("LockResource",  "Ptr",pt,   "Ptr"))
  }            DllCall("FreeLibrary",   "Ptr",hMod)
  (Sa) ? 0 : ErrMes(SM "B4-" A_LastError ")`n`nScript not found.")

  io("Open", FileName), par:=SG2.1, GetA1(), VarSetCapacity(L,0x50,0)
  if NumPut(Bit,L,B.1) && NumPut(A1+0x28,L,0x4,B.4) && (k1=2)
    Wk1:=GetA2(Mes,19,2), Wk:=GetA2(Mes,19,2,0), (!Wk)?Wk:=GetA2(Mes,19):0
    ,(!Wk) ? ErrMes(SM "B5)") : (NumPut(Wk1.2,L,0x8,B.4),NumPut(Wk.2,L,0xc,B.4))
  Wk:=np(SubStr(BinM,1,30),30,0x14,,,1), Rnd(2048,65535,,Bin,Wk,2)

  Wk:=GetA2("~AUTOHOTKEY SCRIPT~",19), (Wk) ? StrPut(BinN,&Bin+Wk.1,19,"UTF-8")
    : ErrMes(SM "B8)`n`nLatest ScriptGuard1() must be included in the script.")
  NumPut(A2r.2,L,0x24,B.4), NumPut(A2r.1,L,0x28,B.4), NumPut(A2r.3,L,0x2c,B.4)
  Wk1 := A2r.3, StrPut("0               ",&Bin+np("7F",2,0x3c,,0), 16, "UTF-8")
  StrPut(Format("{:#-18X}",Wk1), &Bin+np("x7F",3,,,0)-1, 18, "UTF-8")
  NumPut(4096,L,0x1c,B.4), NumPut(37,L,0x10,B.4), Rnd(,3000,,L,0x20,4)

  Wk:=np("; <COMPILER: v",14,0x40), Rnd(99,127,32,Bin,Wk+1,,"`n")
  ((Wk1 := GetA2("; <COMPILER: v",14,,1)) && ng(Wk1.1-1,1) != 34)
    ? ErrMes(SM "B7)`n`nMore than 1 compiled script found.") : 0
  NumPut(Sa,L,0x48,B.4), Rnd(2,65535,7,L,0x30,2), NumPut(SG2.2,L,0x1,B.1)
  NumPut(NumGet(L,0x44,B.4)-pt2-pt3+pt1-NumGet(L,0x28,B.4),L,0x34,B.4)
  ;MsgBox % LOut(L)
  if (Wk:=InBuf(&Bin,0,&L,0)) || ErrorLevel
    ErrMes(SM "B9)`n`nCorrupt machine code!`nResult=" Wk "   Error=" ErrorLevel)
  io(,[[4096,NumGet(L,0x18,B.4)], [Sa,NumGet(L,0x44,B.4)], [4,A1+0x28], [4,U1]])
} else io()                                              
ExitApp 0                                   ; Finish


; ==============================  Subroutines  =================================

ErrMes(Mes, Err:=1)                         ; Show error/warning message
{ MsgBox % Err ? 16 : 49,, % (Err ? "Error: " : "Warning: ") Mes
      . (Err ? "" : "`n`nPress 'OK' to continue, or 'Cancel' to abandon.")
  IfMsgBox Cancel, ExitApp 1                ; Exit if cancel from warning msg
  IfEqual Err, 1,  ExitApp 1                ; Exit if error
}

GetA1()                                     ; Need .exe here
{ global
  if ng(,2)!=0x5A4D || (A1:=ng(0x3C,2)) > StrLen(Bin)-4 || ng(A1)!=0x4550
  || !(Bit:={0x014C:1,0x8664:2}[ng(A1+4,2)]) ; 1=32-bit, 2=64-bit
    ErrMes("File is not a valid .EXE for '" Par "'!`n`n""" FileName """")
  PEz := ng(A1+0x14,2) + 0x18
}

GetA2(ByRef Mes, Slen, Type:=1, Stop:=1, Binary:=0, A2:=0)
{ static Offset:=-1
  global
  VarSetCapacity(Srch1,Slen)  ,StrPut(Mes,&Srch1,"UTF-8"),Offset:=Stop?-1:Offset
  VarSetCapacity(Srch2,Slen*2),StrPut(Mes,&Srch2,"UTF-16")
  IfEqual Binary, 1, Loop % Slen*Type
    NumPut(NumGet(Mes, A_Index-1, B.1), Srch1, A_Index-1, B.1)
  If (Offset := InBuf(&Bin, Sz, &Srch%Type%, Slen*Type, Offset+1 )) >= 0
  { Loop % ng( A1+6, 2)
    { if (A2 := A1+PEz+(A_Index-1)*0x28) && (ng(A2+0x10)+ng(A2+0x14) > Offset)
      { (ng(A2,8) = 0x637273722e) ? NumPut(0xE0000040, Bin, U1:=A2+0x24, B.4) :0
        return [Offset, Offset-ng(A2+0x14)+ng(A2+0xc), ng(A2+0xc), ng(A2+0x8)]
} } } }

ng(OffSt:=0, Size:=4)
{ return NumGet(Bin, Offst, B[Size])
}

np(ByRef Mes, Slen, Offst:=0, Type:=1, Stop:=1, Binary:=0, Wk:=0)
{ global
  Wk := GetA2(Mes, Slen, Type, Stop, Binary), A2r := [Wk.3+Wk.1-Wk.2, Wk.3,Wk.4]
  (Wk)?(Offst?(NumPut(Wk.2,&L,Offst,B.4),NumPut(Wk.1,&L,Offst+4,B.4)):0)
  :ErrMes(SM "B6)`n`n" SubStr(Mes,1,Slen))
  return Wk.1
}

Rnd(cnt:=1, Max:=9, Min:=0, ByRef Add:=0, Off:="", S:=1,Ech:="",Ran:="",Res:="")
{ Loop % cnt
  { Random Ran, Min, Max
    (Off="") ? Res .= Ran : NumPut(Ran, Add, Off+(A_Index-1)*S, B[S])
  } until Ech && NumGet(Add, Off+((A_Index-1)*S)+S, B[S]) = Asc(Ech)
  return Res
}

io(Type:="Close", Data:="")
{ static Upd := [], Nme := "", k, v
  if (Type = "Open")
  { oFl:=FileOpen(Data,"R","UTF-8-RAW"), Nme := Data
   (oFl) ? 0 : ErrMes("File cannot be opened! (B2)`n`n""" Data """")
    oFl.RawRead(Bin,Sz:=oFl.Length), oFl.Close()
  } else if (Type = "Alter")
    Upd.Push(Data)
  else if (Type = "Close")
  { for k, v in Data ? Data : Upd, oFl:=FileOpen(Nme,"RW","UTF-8-RAW")
      oFl.Seek(v.2), oFl.RawWrite(&Bin+v.2,v.1)
    oFl.Close(), Upd := []
} }




; The searching technique used was inspired by this post by gwarble:
;  https://www.autohotkey.com/boards/viewtopic.php?f=76&t=13155#p67713

InBuf(hayP, hayS, neeP, neeS, sOff:=0)      ; Search buffer; returns offset
{ Static Buf ;Includes InBuf by wOxxOm www.autohotkey.com/forum/topic25925.html
  If (!VarSetCapacity(Buf))                 ; Mcode
  { h :=  "530CEC83E5895583145D8BFC57560000BE840F00FB8B104D8B6D7E0041D929C12918"
. "45C701087D8B607E4BACC0310C758B744B32744B41744C754B10744B203F75AEF293AD934E2C"
. "EBF8751F3947393375AEF2AD66931FEBF775FF662475AEF293AD8A10EBF7751F3927381775AE"
. "F22675AEF204EBF87508452BF8894F0D0014C2C95B5E5F4EF3EBD0F7C031DA89FC7589AD4383"
. "F45D8902EBC1DF87F8558903E2F2CA87FB87D18775FF4739DA75AEC783CA89FB89F7F44D8BFC"
. "758B0375A7F30474C98574C985F84D8BDEDF89D375A6F3045A8B0C558BA4EB087D03447A8B30"
. "FE02E9C1484A8B2905E3C1D889C31F03D831078BC3484A8BEF7549AB3F30067403E1838BDB31"
. "FA7549474A8B0875032872D8894902E9C13401ADC32905E3C1385A89F37549C345C70774013A"
. "8062830000013710187A8BD689FC200304428B207A032BF989188B08450889144A03184A0300"
. "000050008100000050B9087D00000024E8A4F38B10750327C683E9B0A4F351034E55EB83C329"
. "58AA89145A2B205A2BFFFEF5E9C0311F04EB90C3565EFF525153000001370DE8036A55575689"
. "64EA83000000146A2B206A2BD5728BC3525A03EB011A7400FE83080C7A8B104A8BEE74A6F34F"
. "47EF01E9F674FF6E380A240CFF000000E4EE0124728BDB318902E9C1344A8B0040346A81344A"
. "E3C1D8894900003BC301ADC3290500FB831075344A850F085A3B0B75490CEB000000AC850F38"
. "5A3BDE7501428A0000009E0030A164240428738B10588B000001F38002588A44DFFFDFBB305A"
. "0000F88366AD66FF752FF88366247400533DD821ADF2D821AD147500430A75004900523D5400"
. "503DD821AD8B240CFF527400EF01407A8B305A8902E9C1484A8B8BC32905E3C1D849ABC301D8"
. "3107E183484A8BEF7549473F30067403EF013C7A8BFA7508B9EB01245A8B8804C3C10000003A"
. "3C30040F24D87549AA0704027C595A5E5F5D58EDC3017E00F8835B0000015204EB906A555756"
. "5251534800000012E8030320428B64EA832948D5894814428BC3525A03EBC5207400FE830872"
. "8B104A8BEE0148FF48EF01480C7A74A6F3CFFF48C7E9F474FF6E380A240CFF000000F4014824"
. "728BDB3102E9C1344A8BEE40346A81344A89D889C9FF00000001ADC32905E3C1831075344A3B"
. "C3085A3B0B7500FBEB000000BA850F5A3BDD75C9FF0D000000AB850F386524042801428A0000"
. "0060A14867738B4820588B4801F38002588A78DFFFDFBB305A0000F88366AD66FF752FF88366"
. "247400533DD821ADF2D821AD147500430A75004900523D5400503DD821AD8B240CFF5B740001"
. "48407A8B305A02E9C1484A8BEFC32905E3C1D889ABC301D831078B484A8BEE75C9FF3F300974"
. "03E183F775C9FFC7FF488BEF01483C7A8B10B9EB0148245A04C3C1480000003C30040F24D888"
. "FFAA0704027C3A5E5F5D58EB75C97E00F8835B595AC301"
    VarSetCapacity(Buf, StrLen(h)//2+6)
    Loop % (StrLen(h)+12)//14
      NumPut("0x" SubStr(h,(A_Index-1)*14+1,14), Buf, (A_Index-1)*7, "Int64")
  }
  Return DllCall(&Buf, "Ptr",hayP,"Ptr",neeP,"Ptr",hayS,"Ptr",neeS,"Ptr",sOff)
}
; ==============================  End of file  =================================
