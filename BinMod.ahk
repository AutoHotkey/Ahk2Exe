;
;@Ahk2Exe-SetVersion     2020.08.23     ; Edition: 23 August 2020
;@Ahk2Exe-SetCopyright   TAC109
;@Ahk2Exe-SetCompanyName TAC109
;@Ahk2Exe-SetProductName BinMod
;@Ahk2Exe-SetDescription Binary file editor - see Ahk2Exe's PostExec directive


/*
 BinMod is a simple, fast binary file editor written by TAC109, designed to be
 called from Ahk2Exe's 'PostExec' compiler directive. (Use Ahk2Exe included with
 AutoHotkey v1.1.33+, or for earlier versions get the latest Ahk2Exe beta from
 https://www.autohotkey.com/boards/viewtopic.php?f=6&t=65095).
 
-------------------------  Installation Instructions  --------------------------
                           ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
 Compile BinMod.ahk using the bin file "Unicode 32bit.bin" or "ANSI 32bit.bin".
 Place the resulting BinMod.exe file in the compiler directory that contains
 Ahk2Exe.exe (usually "C:\Program Files\AutoHotkey\Compiler\").

------------------------------  Usage examples  --------------------------------
                                ¯¯¯¯¯¯¯¯¯¯¯¯¯¯
 With the examples below, the user can make alterations to the compiled program
 to disguise that it is an AutoHotkey compiled script, & also improve security.

1. To replace ">AUTOHOTKEY SCRIPT<" with " DATA" (for example) in the .exe,
    add the following three lines to your script:
    
    ;@Ahk2Exe-Obey U_au, = "%A_IsUnicode%" ? 2 : 1 ; .Bin file ANSI or Unicode?
    ;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%"
    ;@Ahk2Exe-Cont  "%U_au%2.>AUTOHOTKEY SCRIPT<. DATA              "

   Note: In the example above, the 3rd line replacement field must be upper-case
    and space-filled to give a total of 19 characters in order for the compiled
    program to work correctly. This field should start with a space to avoid
    RCData collating problems with any 'FileInstall' commands in the script.

   Users of ScriptGuard1 (bit.ly/ScriptGuard) should add a 1 to the 3rd line:

    ;@Ahk2Exe-Cont  "1%U_au%2.>AUTOHOTKEY SCRIPT<. DATA              "

2. To change the "AutoHotkeyGUI" class to "My_String" (for example) add the next
    line to example 1 (or replace the 3rd line above if not needed):

    ;@Ahk2Exe-Cont  "%U_au%.AutoHotkeyGUI.My_String"

   Note: In this example, if the replacement field is shorter than 13
    characters it will be automatically padded with 0x00's (nul's).

3. Additional ScriptGuard security can be gained for 32-bit compiles by adding
    the next line to example 1 (or replace the 3rd line above if not needed):

    ;@Ahk2Exe-Cont  /ScriptGuard2     ; See bit.ly/ScriptGuard for more details.

4. To set the current date and time as the compile time in the generated .exe,
    add one of the following lines to example 1 (or replace the 3rd line above
    if not needed):

    ;@Ahk2Exe-Cont  /SetDateTime     ; Set current local date and time, or
    ;@Ahk2Exe-Cont  /SetUTC          ; Set current UTC date and time

5. To prevent the use of "UPX -d" to de-compress a UPX-compressed .exe
    add the following line to your script:

    ;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%" "11.UPX." "1.UPX!.", 2

   Note: In this example, there are empty replacement fields, so the matched
    strings will be completely replaced with 0x00's (nul's).

----------------------------  Parameters in detail  ----------------------------
                              ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
 Parameters are as follows (the first is mandatory, the rest are optional):

   1. FileName of file to be modified. (The file will stay the same length.)

   2. One or more parameters specifying changes to be made, with fields thus:

     a) "1" - match once with 1 byte/character binary file portion.
        "2" - match once with 2 byte/character binary file portion.
        These can be mixed and/or repeated to match more than once.

     b) Simple case-sensitive string for matching.

     c) Simple string to replace matched string.
        If shorter than b, it will be padded with 0x00's.
        If longer than b, an error message will be shown.

     Use the same separator between fields a, b, and c (e.g. "." or "`,").

     Parameter 2 can be repeated if required.
     Parameters containing spaces must be enclosed in double quotes.

   3. "/SetDateTime" or "/SetUTC" (without the quotes). This parameter can 
      occur once anywhere after the 1st parameter, and sets the compile time
      to the current date and time (local or UTC) in the generated .exe.

   4. "/ScriptGuard2" (without the quotes). This parameter can occur once
      anywhere after the 1st parameter. See bit.ly/ScriptGuard for more details.
      
--------------------------------------------------------------------------------
 The searching technique used was inspired by these posts:
   https://www.autohotkey.com/boards/viewtopic.php?f=76&t=13155 by gwarble,
   AutoHotkeySC.bin String Patcher for AHK_L 32 Unicode by SKAN 16-Nov-2010,
   autohotkey.com/board/topic/80585-how-to-manipulate-binary-data-with-pointers
*/





; ================================  Program  ===================================
#NoEnv                               ; For performance & future compatibility
#Warn                                ; For catching common errors
#MaxMem 4095                         ; Handle large files
SetBatchLines -1                     ; Run at full speed

global hFile := 0, Bin, B := {1:"UChar", 2:"UShort", 4:"UInt", 8:"UInt64"}
Mes:=">AHK WITH ICON<", Adr1:=Adr2:=Adr3:=Bit:=ErNo:=PEz:=0

if (A_PtrSize = 8)
	ErrMes("Cannot run on 64-bit AutoHotkey.exe!`n`nPlease compile as 32-bit.")

if 0 < 2
	ErrMes("Not enough parameters (minimum 2)!")

FileName := %true%                          ; 1st parameter is file name
FileGetSize Sz,  %FileName%
VarSetCapacity(Bin, Sz)
FileRead Bin, *c %FileName%
if ErrorLevel
	ErrMes("File cannot be opened!`n`n""" FileName """")

hFile:=DllCall("_lopen", "AStr",FileName, "Int",0x2) ; Open file for alteration

Loop % %false%                              ; Number of parameters
{ IfEqual A_Index, 1, continue              ; Skip filename
	Par := %A_Index%                          ; Get parameter
	
	if Par in /SetDateTime,/SetUTC,/ScriptGuard2 ; Need .exe for these parameters
		if ng(,2)!=0x5A4D || (Adr1:=ng(0x3C,2)) > StrLen(Bin)-4 || ng(Adr1)!=0x4550
		|| !(Bit:={0x014C:1,0x8664:2}[ng(Adr1+4,2)]) ; 1=32-bit, 2=64-bit
			ErrMes("File is not a valid .EXE for '" Par "'!`n`n""" FileName """")
			
	if par in /SetDateTime,/SetUTC            ; Set current date & time into .exe
	{ Date := par="/SetUTC" ? A_NowUTC : A_Now
		Date -= 1970, s                         ; Works until 19 Jan 2038! MS to fix
		VarSetCapacity(Rplc1,4), NumPut(Date,Rplc1,0,B.4)
		DllCall("_llseek", "UPtr",hFile, "UInt",Adr1+8,  "Int",0)
		DllCall("_lwrite", "UPtr",hFile, "UInt",&Rplc1, "UInt",4)
		continue
	}

	if (Par = "/ScriptGuard2" && !PEz)        ; Process ScriptGuard2 once
	{	Slen:=StrLen(Mes), VarSetCapacity(Srch1,Slen)  , StrPut(Mes,&Srch1,"UTF-8")
		Type:=3          , VarSetCapacity(Srch2,Slen*2), StrPut(Mes,&Srch2,"UTF-16")

		PEz := ng(Adr1+0x14,2) + 0x18           ; PE header fixed size
		if (Bit = 2)
		{ ErrMes("/ScriptGuard2 procedure is not available for 64-bit compiles.",0)
			continue
		}
		while --Type && !Adr3
		{ Loop % ng( Adr1+6, 2)                 ; Loop through sections
			{ Adr2 := Adr1+PEz + (A_Index-1)*0x28 ; Adr section
				if (Off:=InBuf(&Bin+ng(Adr2+0x14),ng(Adr2+8),&Srch%Type%,Slen*Type))>=0
				{ Adr3 := Off + (Slen+1)*Type + ng(Adr2+0xC) + (Bit=1?ng(Adr1+0x34):0)
					break 2
		} } }
		if (Adr3=0 || ng( ng(Adr2+0x14)+Off+(Slen+1)*Type, 8) 
		!= [0x6F6E20646C756F43,0x6C0075006F0043][Type])
			ErrMes("Could not perform /ScriptGuard2 procedure. (B1)",0)
			
		else {
			VarSetCapacity(Srch1,5,0x68), NumPut(Adr3,Srch1,1,"UInt")
			VarSetCapacity(Rplc1,1,0xB8)
			Loop % ng( Adr1+6, 2)                 ; Loop through sections again
			{ Adr2 := Adr1 + PEz + (A_Index-1)*0x28, Off := 0 ; Adr section
				if ng(Adr2+0x24)&0x20               ; Code section?
				{ while (Off > -1)
					{ if (Off:=InBuf(&Bin+ng(Adr2+0x14), ng(Adr2+8),&Srch1,5,++Off)) >= 0
						&& (ErNo:=1) && ng(Adr3:=ng(Adr2+0x14)+Off+5,1) = 0xE8
						&& (ErNo:=2) && ng(Adr3+5,2) = 0xC483
						{ DllCall("_llseek", "UPtr",hFile, "UInt",Adr3,    "Int",0)
							DllCall("_lwrite", "UPtr",hFile, "UInt",&Rplc1, "UInt",1)
							Adr2 := 0
							break 2
			} } } }
			if (Adr2)
				ErrMes("Could not perform /ScriptGuard2 procedure. (B" ErNo+2 ")",0)
		}
		continue
	}                                         ; Process text replacements
	while [1,1][Sep := SubStr(Par,A_Index,1)] ; Get separator after '1's and '2's
		continue
	Pfld := StrSplit(Par, Sep)                ; Split parameter into fields
	if (Pfld.MaxIndex() != 3 || Pfld.1 = "" || StrLen(Pfld.3) > StrLen(Pfld.2))
		ErrMes("Invalid parameter!`n`n""" Par """")

	Slen := StrLen(Pfld.2)                    ; Setup search & replace variables
	VarSetCapacity(Srch1, Slen,   0), StrPut(Pfld.2, &Srch1, "UTF-8")
	VarSetCapacity(Srch2, Slen*2, 0), StrPut(Pfld.2, &Srch2, "UTF-16")
	VarSetCapacity(Rplc1, Slen,   0), StrPut(Pfld.3, &Rplc1, "UTF-8")
	VarSetCapacity(Rplc2, Slen*2, 0), StrPut(Pfld.3, &Rplc2, "UTF-16")

	Loop % StrLen(Pfld.1)                     ; For each type of search
	{ Type := SubStr(Pfld.1, A_Index, 1)      ; Scan for search item
		If (Off := InBuf(&Bin, Sz, &Srch%Type%, Slen*Type )) < 0
			ErrMes("String not found!`n`n""" Pfld.2 """")

		Loop % Slen*Type                        ; Alter buffer & file
			NumPut(NumGet(Rplc%Type%, A_Index-1, B.1), Bin, Off+A_Index-1, B.1)

		DllCall("_llseek", "UPtr",hFile, "UInt",Off, "Int",0)
		DllCall("_lwrite", "UPtr",hFile, "UInt",&Rplc%Type%, "UInt",Slen*Type)
}	}

DllCall("_lclose", "UPtr",hFile)            ; Close file & finish
ExitApp 0

; ==============================  Subroutines  =================================
InBuf(hayP, hayS, neeP, neeS, sOff=0)       ; Search buffer; returns offset
{ Static Buf      ; InBuf() by wOxxOm @ www.autohotkey.com/forum/topic25925.html
	If (!VarSetCapacity(Buf))                 ; MCode
	{ h :=  "5589E583EC0C53515256579C8B5D1483FB000F8EC20000008B4D108B451829C129D9"
. "410F8EB10000008B7D0801C78B750C31C0FCAC4B742A4B742D4B74364B74144B753F93AD93F2"
. "AE0F858B000000391F75F4EB754EADF2AE757F3947FF75F7EB68F2AE7574EB628A26F2AE756C"
. "382775F8EB569366AD93F2AE755E66391F75F7EB474E43AD8975FC89DAC1EB02895DF483E203"
. "8955F887DF87D187FB87CAF2AE75373947FF75F789FB89CA83C7038B75FC8B4DF485C97404F3"
. "A775DE8B4DF885C97404F3A675D389DF4F89F82B45089D5F5E5A595BC9C2140031C0F7D0EBF0"
		VarSetCapacity(Buf, StrLen(h)//2)
		Loop % StrLen(h)//2
				NumPut("0x" SubStr(h,2*A_Index-1,2), Buf, A_Index-1, "Char")
	}
	Return DllCall(&Buf, "UInt",hayP, "UInt",neeP, "UInt",hayS, "Int",neeS
										 , "UInt",sOff)
}

ErrMes(Mes, Err:=1)                         ; Show error/warning message
{ MsgBox % Err ? 16 : 49,, % (Err ? "Error: " : "Warning: ") Mes
			. (Err ? "" : "`n`nPress 'OK' to continue, 'Cancel' to abandon.")
	IfMsgBox Cancel
		Err := 1                                ; Exit if cancel from warning msg
	if (hFile && Err)
		DllCall("_lclose", "UPtr",hFile)        ; Close file if open & error
	if (Err)
		ExitApp 1                               ; Exit if error
}

ng(Offset = 0, Size = 4)                    ; Shorten NumGet
{ return NumGet(Bin, Offset, B[Size])
}
; ===============================  Debugging  ==================================
VarOut(Name, ByRef var, len, f=0)           ; Variable to file; check value with
{	f := FileOpen(A_ScriptDir "\Bin_" Name ".var", "w", "UTF-8-RAW") ;  hex viewer
	f.RawWrite(var, len)
	f.Close()
}
Hex(d)
{ return Format(" {:#X}",d)             ; Format hex for display
}
; ==============================  End of file  =================================
