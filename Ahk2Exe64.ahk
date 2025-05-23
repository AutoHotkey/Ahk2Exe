; 
; File encoding:  UTF-8 with BOM
;
; Script description:
;	Ahk2Exe64 - AutoHotkey Script Compiler special 64-bit version
;             Allows creation of .exe up to ~2GB size
;             (standard 32-bit version only allows .exe up to ~1GB)
;	By TAC109
;
; Must be compiled with itself (same version)
;
#Requires AutoHotkey 1.1
b := 64
;@Ahk2Exe-Base            %A_AhkPath%\..\AutoHotkeyU64.exe
#Include                  Ahk2Exe.ahk
