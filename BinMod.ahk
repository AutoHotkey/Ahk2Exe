/*
 BinMod; a simple, fast binary file editor by TAC109.
 Designed be called from Ahk2Exe's 'PostExec' compiler directive.

-------------------------  Installation Instructions  --------------------------

 Compile BinMod.ahk using the bin file "Unicode 32bit.bin" or "ANSI 32bit.bin".
 Place the resulting BinMod.exe file in the compiler directory that contains
  Ahk2Exe.exe (e.g. "C:\Program Files\AutoHotkey\Compiler\").

------------------------------  Usage examples  --------------------------------

1. To replace ">AUTOHOTKEY SCRIPT<" with "DATA" (for example) in the .exe:
    ;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%"
    ;@Ahk2Exe-Cont  "22.>AUTOHOTKEY SCRIPT<.DATA               "

   Note: In the example above, the replacement field must be space-filled to 
    give a total of 19 characters in order for the compiled program to work.

2. To change the "AutoHotkeyGUI" class to "My_String" (for example) add the next
    line to the previous example (or replace the 2nd line above if not needed):
    ;@Ahk2Exe-Cont  "2.AutoHotkeyGUI.My_String"

   Note: In this example, if the replacement field is shorter than 13
    characters it will be automatically padded with 0x00's (nul's).

3. To prevent the use of "UPX -d" to de-compress a UPX-compressed .exe:
    ;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%"
    ;@Ahk2Exe-Cont  "11.UPX." "1.UPX!.", 2

   Note: In this example, there are empty replacement fields, so the matched
    strings will be completely replaced with 0x00's (nul's).

--------------------------------------------------------------------------------

 Parameter details:

   1. FileName of file to be modified. (The file will stay the same length.)

   2. One or more parameters specifying changes to be made, with fields thus:

     a) "1" - match once with 1 byte/character binary file portion.
        "2" - match once with 2 byte/character binary file portion.
        These can be mixed and/or repeated to match more than once.

     b) Simple case-sensitive string for matching.

     c) Simple string to replace matched string.
        If shorter than b, it will be padded with 0x00's.
        If longer than b, an error message will be shown.

     Use the same separator between a, b, and c (e.g. "." or "`,").

   Parameter 2 can be repeated if required.
   Parameters containing spaces must be enclosed in double quotes.

--------------------------------------------------------------------------------

 Technique inspired by these posts:
   https://www.autohotkey.com/boards/viewtopic.php?f=76&t=13155 by gwarble,
   AutoHotkeySC.bin String Patcher for AHK_L 32 Unicode by SKAN 16-Nov-2010,
   autohotkey.com/board/topic/80585-how-to-manipulate-binary-data-with-pointers
*/
; ================================  Program  ===================================
#NoEnv                               ; For performance & future compatibility
#Warn                                ; For catching common errors
#MaxMem 4095                         ; Handle large files
SetBatchLines -1                     ; Run at full speed

if A_PtrSize = 8
{ MsgBox 16,,Cannot run on 64-bit AutoHotkey.exe!`n`nPlease compile as 32-bit.
	ExitApp 1
}
if 0 < 2
{ MsgBox 16,, Not enough parameters (minimum 2)!
	ExitApp 1
}
FileName := %true%                          ; 1st parameter
FileGetSize Sz,  %FileName%
VarSetCapacity(Bin, Sz)
FileRead Bin, *c %FileName%
if ErrorLevel
{ MsgBox 16,, File cannot be opened!`n`n"%FileName%"
	ExitApp 1
}
hFile := DllCall("_lopen", AStr,%true%, Int,0x2) ; Open file for modification
Loop % %false%                              ; Number of parameters
{ IfEqual A_Index, 1, continue              ; Skip filename
	Par := %A_Index%                          ; Get parameter
	while [1,1][Sep := SubStr(Par,A_Index,1)] ; Get separator after '1's and '2's
		continue
	Pfld := StrSplit(Par, Sep)                ; Split parameter into fields
	if (Pfld.MaxIndex() !=3 || Pfld.1 = "" || StrLen(Pfld.3) > StrLen(Pfld.2))
	{ DllCall("_lclose", UInt,hFile)
		MsgBox 16,, Invalid parameter!`n`n#%A_Index%; "%Par%"
		ExitApp 1
	}
	Slen := StrLen(Pfld.2)                    ; Setup search & replace variables
	VarSetCapacity(Srch1, Slen,   0), StrPut(Pfld.2, &Srch1, "UTF-8")
	VarSetCapacity(Srch2, Slen*2, 0), StrPut(Pfld.2, &Srch2, "UTF-16")
	VarSetCapacity(Rplc1, Slen,   0), StrPut(Pfld.3, &Rplc1, "UTF-8")
	VarSetCapacity(Rplc2, Slen*2, 0), StrPut(Pfld.3, &Rplc2, "UTF-16")
	Loop % StrLen(Pfld.1)                     ; For each type of search
	{ Type := SubStr(Pfld.1, A_Index, 1)      ; Scan for search item
		If (Off := InBuf(&Bin, Sz, &Srch%Type%, Slen*Type )) < 0
		{	DllCall("_lclose", UInt,hFile)
			MsgBox 16,, % "String not found!`n`n" Type "; """ Pfld.2 """"
			ExitApp 1
		}
		Loop % Slen*Type                        ; Alter buffer & file
			NumPut(NumGet(Rplc%Type%,A_Index-1,"UChar"), Bin, Off+A_Index-1, "UChar")
		DllCall("_llseek", UInt,hFile, UInt,Off, Int,0)
		DllCall("_lwrite", UInt,hFile, UInt,&Rplc%Type%, UInt,Slen*Type)
}	}

DllCall("_lclose", UInt,hFile)              ; Close file & finish
ExitApp 0

; ==============================  Subroutines  =================================
InBuf(hayP,hayS, neeP,neeS, sOff=0)         ; Search buffer mcode; gives offset
{ Static InBuf ; Original version  @ www.autohotkey.com/forum/topic25925.html
  If (!VarSetCapacity(InBuf)) ; Slightly altered version of InBuf() by wOxxOm
	{ FiH := "530CEC83E58955|5D8B9C57565251|C28E0F00FB8314|8B104D8B000000|"
		FiH .= "41D929C1291845|8B000000B18E0F|0C758BC701087D|2A744BACFCC031|"
		FiH .= "4B36744B2D744B|AD933F754B1474|008B850FAEF293|EBF4751F390000|"
		FiH .= "7F75AEF2AD4E75|68EBF775FF4739|8A62EB7475AEF2|27386C75AEF226|"
		FiH .= "AD669356EBF875|39665E75AEF293|434E47EBF7751F|C1DA89FC7589AD|"
		FiH .= "E283F45D8902EB|87DF87F8558903|AEF2CA87FB87D1|F775FF47393775|"
		FiH .= "03C783CA89FB89|85F44D8BFC758B|DE75A7F30474C9|0474C985F84D8B|"
		FiH .= "4FDF89D375A6F3|5F9D08452BF889|14C2C95B595A5E|F0EBD0F7C03100"
		VarSetCapacity(InBuf, 224, 0)
		Loop, Parse, FiH, |
			NumPut( "0x" A_LoopField, InBuf,(7*(A_Index-1)), "Int64" )
	}
	Return DllCall(&InBuf, UInt,hayP, UInt,neeP, UInt,hayS, UInt,neeS, UInt,sOff)
}

; ===============================  Debugging  ==================================
VarOut(Name, ByRef var, len, f=0)           ; Variable to file; check value with
{	f := FileOpen(A_ScriptDir "\Bin_" Name ".var", "w", "UTF-8-RAW") ;  hex viewer
	f.RawWrite(var, len)
	f.Close()
}

; ==============================  End of file  =================================
