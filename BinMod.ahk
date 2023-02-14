;@Ahk2Exe-SetVersion     2023.02.14     ; Edition: y.m.d
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
    enhanced ScriptGuard security, add the next line:

    ;@Ahk2Exe-Cont  /ScriptGuard2    ; See bit.ly/ScriptGuard for more details

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
      
   4. /ScriptGuard2 - This parameter causes the embedded script to be encrypted
      with a random key, and also adds extra security to the generated .exe. See
      bit.ly/ScriptGuard for more details.
--------------------------------------------------------------------------------
 The searching technique used was inspired by this post:
   https://www.autohotkey.com/boards/viewtopic.php?f=76&t=13155 by gwarble.
*/
; ================================  Program  ===================================
#NoEnv                               ; For performance & future compatibility
#Warn                                ; For catching common errors
#MaxMem 4095                         ; Handle large files
SetBatchLines -1                     ; Run at full speed
#NoTrayIcon
global hFile:=0, Bin, L, B:=["UChar","UShort",,"UInt",,,,"UInt64"], dbg:=0
Mes:=">AUTOHOTKEY SCRIPT<", Sa:=PEz:=A1:=Bit:=SG2:=0
SM := "Could not perform /ScriptGuard2 procedure! ("
((A_PtrSize = 8) || !A_IsUnicode) ? ErrMes("Wrong type of AutoHotkey used!`n`n"
  . "Please compile with a v1.1 32-bit Unicode base file.") : 0
#Include *i D:\Dropbox\AutoHotKey\BinDbg.ahk ; Debugging only
(%false% < 1) ? ErrMes("No parameters supplied!") : 0
FileName := %true%                          ; 1st parameter is file name
FileGetSize Sz,  %FileName%
VarSetCapacity(Bin, Sz)
FileRead Bin, *c %FileName%
(ErrorLevel) ? ErrMes("File cannot be opened! (B1)`n`n""" FileName """") : 0
hFile:=DllCall("_lopen", "AStr",FileName, "Int",0x2) ; Open file for alteration
Loop % %false%                              ; Number of parameters
{ IfEqual A_Index, 1, continue              ; Skip filename
  Par := %A_Index%                          ; Get parameter
  if par in /SetDateTime,/SetUTC            ; Set current date & time into .exe
  { Date := par="/SetUTC" ? A_NowUTC : A_Now, GetA1()
    Date -= 1970, s                         ; Works until 19 Jan 2038! MS to fix
    VarSetCapacity(Rplc1,4), NumPut(Date,Rplc1,0,B.4)
    DllCall("_llseek", "UPtr",hFile, "UInt",A1+8,   "Int",0)
    DllCall("_lwrite", "UPtr",hFile, "UInt",&Rplc1, "UInt",4)
  }
  else if (Par = "/ScriptGuard2")           ; Remember ScriptGuard2 for later
    SG2 := 1
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
      DllCall("_llseek", "UPtr",hFile, "UInt",Off, "Int",0)
      DllCall("_lwrite", "UPtr",hFile, "UInt",&Rplc%Type%, "UInt",Slen*Type)
} } }
if (SG2)                                    ; Process /ScriptGuard2
{ DllCall("_lclose", "UPtr",hFile), hFile := 0, VarSetCapacity(BinM,4096,254)
  IfEqual dbg, 1, ToolTip Update Resource
  if !(Mod:=DllCall("BeginUpdateResource", "Str", FileName, "UInt", 0, "Ptr"))
    ErrMes(SM "B1)`n`n'BeginUpdateResource'")
  if !DllCall("UpdateResource", "Ptr",Mod, "Ptr",10, "Str",(BinN:= "  " Rnd(17))
         , "ushort", 0x409, "Ptr", &BinM, "UInt", 4096, "UInt")
    ErrMes(SM "B2)`n`n'UpdateResource'")
  Loop
  { if !DllCall("EndUpdateResource", "Ptr", Mod, "UInt", 0)
      ErrMes(SM "B3)`n`nThis error may be caused by your anti-virus checker.",0)
    else break
  }
  IfEqual dbg, 1, ToolTip
  FileGetSize Sz,  %FileName%
  VarSetCapacity(Bin, Sz)
  FileRead Bin, *c %FileName%
  (ErrorLevel) ? ErrMes("File cannot be opened! (B2)`n`n""" FileName """") : 0
  hMod      :=DllCall("LoadLibraryEx","Str",FileName,"Ptr",0, "Ptr",2, "Ptr")
  for k, v in ["#1", Mes, "#1"], rc:=pt:=pt1:=pt2:=pt3:=0
  { if (rc  :=DllCall("FindResource", "Ptr",hMod, v ~= "^#\d$" ? "Ptr" : "Str"
        , v ~= "^#\d$" ? SubStr(v,2) : v, "Ptr",k=1 ? 3 : 10,"Ptr"))
      (Sa   :=DllCall("SizeofResource","Ptr",hMod, "Ptr",rc, "UInt")) && k1:=k
    , (pt   :=DllCall("LoadResource",  "Ptr",hMod, "Ptr",rc, "Ptr"))
    , (pt%k%:=DllCall("LockResource",  "Ptr",pt,   "Ptr"))
  }           DllCall("FreeLibrary",   "Ptr",hMod)
  (Sa = 0) ? ErrMes(SM "B4-" A_LastError ")`n`nScript not found.") : 0
  par := "/ScriptGuard2", GetA1(), VarSetCapacity(L,0x50,0)
  if NumPut(Bit,L,B.4) && NumPut(A1+0x28,L,4,B.4) && (k1=2)
    Wk1:=GetA2(Mes,19,2), Wk:=GetA2(Mes,19,2,0), (!Wk)?Wk:=GetA2(Mes,19):0
    ,(!Wk) ? ErrMes(SM "B5)") : (NumPut(Wk1.2,L,0x8,B.4),NumPut(Wk.2,L,0xc,B.4))
  Wk:=np(SubStr(BinM,1,30),30,0x14,,,1), Rnd(2048,65535,,Bin,Wk,2)
  Wk:=GetA2("~AUTOHOTKEY SCRIPT~",19), (Wk) ? StrPut(BinN,&Bin+Wk.1,19,"UTF-8")
    : ErrMes(SM "B8)`n`nLatest ScriptGuard1() must be included in the script.")
  NumPut(A2r.2,L,0x24,B.4), NumPut(A2r.1,L,0x28,B.4), NumPut(A2r.3,L,0x2c,B.4)
  Wk1 := A2r.3, StrPut("0               ",&Bin+np("7F",2,0x3c,,0), 16, "UTF-8")
  StrPut(Format("{:#-18X}",Wk1), &Bin+np("x7F",3,,,0)-1, 18, "UTF-8")
  NumPut(4096,L,0x1c,B.4), NumPut(37,L,0x10,B.4) , Rnd(,3000,,L,0x20,4)
  Wk:=np("; <COMPILER: v",14,0x40), Rnd(99,127,32,Bin,Wk+1,,"`n")
  ((Wk1 := GetA2("; <COMPILER: v",14,,1)) && ng(Wk1.1-1,1) != 34)
    ? ErrMes(SM "B7)`n`nMore than 1 compiled script found.") : 0
  NumPut(Sa,L,0x48,B.4), Rnd(2,65535,7,L,0x30,2)
  NumPut(NumGet(L,0x44,B.4)-pt2-pt3+pt1-NumGet(L,0x28,B.4),L,0x34,B.4)
  IfEqual dbg, 1, ToolTip Update Machine Code

  if (Wk:=InBuf(&Bin,0,&L,0)) || ErrorLevel
    ErrMes(SM "B9)`n`nCorrupt machine code!`nResult=" Wk "   Error=" ErrorLevel)
  hFile:=DllCall("_lopen", "AStr",FileName, "Int",0x2)
  DllCall("_llseek", "UPtr",hFile, "UInt",0,     "Int",0)
  DllCall("_lwrite", "UPtr",hFile, "UInt",&Bin, "UInt",Sz)
  IfEqual dbg, 1, ToolTip

}
DllCall("_lclose", "UPtr",hFile)            ; Close file & finish
ExitApp 0

; ==============================  Subroutines  =================================
ErrMes(Mes, Err:=1)                         ; Show error/warning message
{ IfEqual dbg, 1, ToolTip
  MsgBox % Err ? 16 : 49,, % (Err ? "Error: " : "Warning: ") Mes
      . (Err ? "" : "`n`nPress 'OK' to continue, or 'Cancel' to abandon.")
  IfMsgBox Cancel
    Err := 1                                ; Exit if cancel from warning msg
  if (hFile && Err)
    DllCall("_lclose", "UPtr",hFile)        ; Close file if open & error
  if (Err)
    ExitApp 1                               ; Exit if error
}

GetA1()                                     ; Need .exe here
{ global
  if ng(,2)!=0x5A4D || (A1:=ng(0x3C,2)) > StrLen(Bin)-4 || ng(A1)!=0x4550
  || !(Bit:={0x014C:1,0x8664:2}[ng(A1+4,2)]) ; 1=32-bit, 2=64-bit
    ErrMes("File is not a valid .EXE for '" Par "'!`n`n""" FileName """")
  PEz := ng(A1+0x14,2) + 0x18
}

GetA2(ByRef Mes, Slen, Type=1, Stop=1, Binary=0, A2=0)
{ static Offset:=-1
  global
  VarSetCapacity(Srch1,Slen)  ,StrPut(Mes,&Srch1,"UTF-8"),Offset:=Stop?-1:Offset
  VarSetCapacity(Srch2,Slen*2),StrPut(Mes,&Srch2,"UTF-16")
  IfEqual Binary, 1, Loop % Slen*Type
    NumPut(NumGet(Mes, A_Index-1, B.1), Srch1, A_Index-1, B.1)
  If (Offset := InBuf(&Bin, Sz, &Srch%Type%, Slen*Type, Offset+1 )) >= 0
  { Loop % ng( A1+6, 2)
    { if (A2 := A1+PEz+(A_Index-1)*0x28) && (ng(A2+0x10)+ng(A2+0x14) > Offset)
      { (ng(A2,8) = 0x637273722e) ? NumPut(0xE0000040, Bin, A2+0x24, B.4) : 0
        return [Offset, Offset-ng(A2+0x14)+ng(A2+0xc), ng(A2+0xc), ng(A2+0x8)]
} } } }

ng(OffSt = 0, Size = 4)
{ return NumGet(Bin, Offst, B[Size])
}

np(ByRef Mes, Slen, Offst=0, Type=1, Stop=1, Binary=0, Wk=0)
{ global
  Wk := GetA2(Mes, Slen, Type, Stop, Binary), A2r := [Wk.3+Wk.1-Wk.2, Wk.3,Wk.4]
  (Wk)?(Offst?(NumPut(Wk.2,&L,Offst,B.4),NumPut(Wk.1,&L,Offst+4,B.4)):0)
  :ErrMes(SM "B6)`n`n" SubStr(Mes,1,Slen))
  return Wk.1
}

Rnd(cnt=1, Max=9, Min=0, ByRef Add=0, Off="", S=1, Ech="", Ran="", Res="")
{ Loop % cnt
  { Random Ran, Min, Max
    (Off="") ? Res .= Ran : NumPut(Ran, Add, Off+(A_Index-1)*S, B[S])
  } until Ech && NumGet(Add, Off+((A_Index-1)*S)+S, B[S]) = Asc(Ech)
  return Res
}



InBuf(hayP, hayS, neeP, neeS, sOff=0)       ; Search buffer; returns offset
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
. "83D68900000136108B207A03187A8B188B08450304424A03184A2BF9890050008108891450B9"
. "087D03000024E8A4F30000000327C683000000F351034E8B1075C32958AAE9B0A42B205A2B55"
. "EB83E9C0311F89145AC3565EFFFFFEF90000013604EB90036A5756525153EA8300000011E814"
. "420320428B63EB1A89C329D38908728BC3525A0332031A7400FE83030C7A8B104A8B0A74A6F3"
. "4F473AE1E9F674FF6E3831240CFF0000008B320324728BDB4A8902E9C1344A000040346A8134"
. "05E3C1D88949004A3BC301ADC3297500FB83107534A9850F085A3B0B75490CEB0000009B850F"
. "385A3BDE64240CFF000000588B00000030A102588A44738B10BB305A0001F38066AD66FFDFFF"
. "DF8366247400F883D821ADF2752FF81475004300533D4900523DD821AD3DD821AD0A7500FF52"
. "74005400507A8B305A8B240CC1484A8B3A034005E3C1D88902E901D831078BC3294A8BEF7549"
. "ABC330067403E183487A8BFA7549473F03245A8B3A033CC100000008B91A040F24D88804C307"
. "04027C3A3C305E5F58ED7549AA7400F8835B595A015004EB90C3015756525153000000000015"
. "E8036A20428B63EA834848D3894814420303EB1A8948C3298308728BC3525A320348207400FE"
. "480C7A8B104A8BFF48C7FF483A036E380A74A6F3CF0000F1E9F474FF8BDB31240CFF004A8B32"
. "03482472344A8902E9C13400000040346A8105E3C1D889C9FF4A3BC301ADC3297500FB831075"
. "34B7850F085A3B0BC9FF0DEB000000850F385A3BDD75240CFF000000A8000060A14867658B48"
. "20588B4800F38002588A7873FFDFBB305A0001F88366AD66FFDF2FF88366247400533DD821AD"
. "F27521AD147500430075004900523DD800503DD821AD0A240CFF5B74005448407A8B305A8BE9"
. "C1484A8B3A032905E3C1D88902C301D831078BC34A8BEE75C9FFAB30097403E1834875C9FFC7"
. "FF483F3A03483C7A8BF7B91A0348245A8BC3C1480000001030040F24D88804AA0704027C3A3C"
. "5E5F58EB75C9FF7400F8835B595AC301"
    VarSetCapacity(Buf, StrLen(h)//2+6)
    Loop % (StrLen(h)+12)//14
      NumPut("0x" SubStr(h,(A_Index-1)*14+1,14), Buf, (A_Index-1)*7, "Int64")
  }
  Return DllCall(&Buf, "Ptr",hayP,"Ptr",neeP,"Ptr",hayS,"Ptr",neeS,"Ptr",sOff)
}
; ==============================  End of file  =================================
