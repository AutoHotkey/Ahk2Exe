﻿;
; File encoding:  UTF-8
;
; Script description:
;	Ahk2Exe - AutoHotkey Script Compiler
;	Written by fincs - Interface based on the original Ahk2Exe
;

;@Ahk2Exe-SetName         Ahk2Exe
;@Ahk2Exe-SetDescription  AutoHotkey Script Compiler
;@Ahk2Exe-SetCopyright    Copyright (c) since 2004
;@Ahk2Exe-SetCompanyName  AutoHotkey
;@Ahk2Exe-SetOrigFilename Ahk2Exe.ahk
;@Ahk2Exe-SetMainIcon     Ahk2Exe.ico

#NoEnv
#NoTrayIcon
#SingleInstance Off
#Include %A_ScriptDir%
#Include Compiler.ahk
SendMode Input

OnExit("Util_HideHourglass")            ; Reset cursor on exit

global DEBUG := !A_IsCompiled

gosub BuildBinFileList
gosub LoadSettings
gosub ParseCmdLine
if !UsesCustomBin
	gosub CheckAutoHotkeySC

if CLIMode
{
	gosub ConvertCLI
	ExitApp, 0 ; Success
}

IcoFile = %LastIcon%
BinFileId := FindBinFile(LastBinFile)
ScriptFileCP := A_FileEncoding

CompressDescr := {-1:" UPX  (if prese&nt)", 0:" (&none)", 1:" MPRESS  (if prese&nt)"}

#include *i __debug.ahk

Menu, FileMenu, Add, &Convert, Convert
Menu, FileMenu, Add
Menu, FileMenu, Add, E&xit`tAlt+F4, GuiClose
Menu, HelpMenu, Add, &Help, Help
Menu, HelpMenu, Add
Menu, HelpMenu, Add, &About, About
Menu, MenuBar,  Add, &File, :FileMenu
Menu, MenuBar,  Add, &Help, :HelpMenu
Gui, Menu, MenuBar

Gui, +LastFound
GuiHwnd := WinExist("")
Gui, Add, Link, x287 y20,
(
©2004-2009 Chris Mallet
©2008-2011 Steve Gray (Lexikos)
©2011-2016 fincs
<a href="https://www.autohotkey.com">https://www.autohotkey.com</a>
Note: Compiling does not guarantee source code protection.
)
Gui, Add, Text, x11 y117 w570 h2 +0x1007
Gui, Add, GroupBox, x11 y124 w570 h55 cBlue, Required Parameter
Gui, Add, Text, x17 y151, &Source (script file)
Gui, Add, Edit, x137 y146 w315 h23 +Disabled vAhkFile, %AhkFile%
Gui, Add, Button, x459 y146 w53 h23 gBrowseAhk, &Browse
Gui, Add, GroupBox, x11 y182 w570 h140 cBlue, Optional Parameters
Gui, Add, Text, x17 y208, &Destination (.exe file)
Gui, Add, Edit, x137 y204 w315 h23 +Disabled vExeFile, %Exefile%
Gui, Add, Button, x459 y204 w53 h23 gBrowseExe, B&rowse
Gui, Add, Text, x17 y240, Custom &Icon (.ico file)
Gui, Add, Edit, x137 y236 w315 h23 +Disabled vIcoFile, %IcoFile%
Gui, Add, Button, x461 y236 w53 h23 gBrowseIco, Br&owse
Gui, Add, Button, x519 y236 w53 h23 gDefaultIco, D&efault
Gui, Add, Text, x17 y270, Base File (.bin)
Gui, Add, DDL, x137 y270 w315 h23 R10 AltSubmit vBinFileId Choose%BinFileId%, %BinNames%
Gui, Add, Text, x17 y296, Compress exe with
Gui, Add, CheckBox, x138 y294 w315 h20 Check3 vUseMpress gcompress Checked%LastUseMPRESS%, % CompressDescr[LastUseMPRESS]
Gui, Add, Button, x258 y329 w75 h28 Default gConvert, > &Convert <
Gui, Add, StatusBar,, Ready
;@Ahk2Exe-IgnoreBegin
Gui, Add, Pic, x29 y16 w240 h78, %A_ScriptDir%\logo.png
;@Ahk2Exe-IgnoreEnd
/*@Ahk2Exe-Keep
gosub AddPicture
*/
GuiControl, Focus, Button1
Gui, Show, w594 h383, Ahk2Exe for AutoHotkey v%A_AhkVersion% -- Script to EXE Converter
return

GuiClose:
Gui, Submit
gosub SaveSettings
ExitApp

compress:
gui, Submit, NoHide
GuiControl Text, UseMpress, % CompressDescr[UseMPRESS]

GuiDropFiles:
if A_EventInfo > 3
	Util_Error("You cannot drop more than one file of each type into this window!", 0x51)
loop, parse, A_GuiEvent, `n
{
	SplitPath, A_LoopField,,, dropExt
	if SubStr(dropExt,1,2) = "ah"          ; Allow for v2, e.g. ah2, ahk2, etc
		GuiControl,, AhkFile, %A_LoopField%
	else GuiControl,, %dropExt%File, %A_LoopField%
}
return

/*@Ahk2Exe-Keep

AddPicture:
; Code based on http://www.autohotkey.com/forum/viewtopic.php?p=147052
Gui, Add, Text, x29 y16 w240 h78 +0xE hwndhPicCtrl

;@Ahk2Exe-AddResource logo.png
hRSrc := DllCall("FindResource", "ptr", 0, "str", "LOGO.PNG", "ptr", 10, "ptr")
sData := DllCall("SizeofResource", "ptr", 0, "ptr", hRSrc, "uint")
hRes  := DllCall("LoadResource", "ptr", 0, "ptr", hRSrc, "ptr")
pData := DllCall("LockResource", "ptr", hRes, "ptr")
hGlob := DllCall("GlobalAlloc", "uint", 2, "uint", sData, "ptr") ; 2=GMEM_MOVEABLE
pGlob := DllCall("GlobalLock", "ptr", hGlob, "ptr")
DllCall("msvcrt\memcpy", "ptr", pGlob, "ptr", pData, "uint", sData, "CDecl")
DllCall("GlobalUnlock", "ptr", hGlob)
DllCall("ole32\CreateStreamOnHGlobal", "ptr", hGlob, "int", 1, "ptr*", pStream)

hGdip := DllCall("LoadLibrary", "str", "gdiplus")
VarSetCapacity(si, 16, 0), NumPut(1, si, "UChar")
DllCall("gdiplus\GdiplusStartup", "ptr*", gdipToken, "ptr", &si, "ptr", 0)
DllCall("gdiplus\GdipCreateBitmapFromStream", "ptr", pStream, "ptr*", pBitmap)
DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", pBitmap, "ptr*", hBitmap, "uint", 0)
SendMessage, 0x172, 0, hBitmap,, ahk_id %hPicCtrl% ; 0x172=STM_SETIMAGE, 0=IMAGE_BITMAP
GuiControl, Move, %hPicCtrl%, w240 h78

DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
DllCall("gdiplus\GdiplusShutdown", "ptr", gdipToken)
DllCall("FreeLibrary", "ptr", hGdip)
ObjRelease(pStream)
return

*/

BuildBinFileList:
BinFiles := ["AutoHotkeySC.bin"]
BinNames = (Default)
Loop, %A_ScriptDir%\*.bin
{
	SplitPath, A_LoopFileFullPath,,,, n
	if n = AutoHotkeySC
		continue
	FileGetVersion, v, %A_LoopFileFullPath%
	BinFiles.Insert(n ".bin")
	BinNames .= "|v" v " " n
}
return

CheckAutoHotkeySC:
IfNotExist, %A_ScriptDir%\AutoHotkeySC.bin
{
	; Check if we can actually write to the compiler dir
	try FileAppend, test, %A_ScriptDir%\___.tmp
	catch
	{
		MsgBox, 52, Ahk2Exe Error,
		(LTrim
		Unable to copy the appropriate binary file as AutoHotkeySC.bin because the current user does not have write/create privileges in the %A_ScriptDir% folder (perhaps you should run this program as administrator?)
		
		Do you still want to continue?
		)
		IfMsgBox, Yes
			return
		ExitApp, 0x2 ; Compilation cancelled
	}
	FileDelete, %A_ScriptDir%\___.tmp
	
	IfNotExist, %A_ScriptDir%\..\AutoHotkey.exe
	{
		binFile = %A_ScriptDir%\Unicode 32-bit.bin

		if !FileExist(BinFile)                  ; Ahk2Exe in non-standard folder?
		{	FileCopy  %A_AhkPath%\..\Compiler\Unicode 32-bit.bin
			       ,  %A_ScriptDir%\AutoHotkeySC.bin
			BinFile = %A_ScriptDir%\AutoHotkeySC.bin
			FileCopy  %A_AhkPath%\..\Compiler\*bit.bin, %A_ScriptDir%\, 1

	}	} else
	{
		try FileDelete, %A_Temp%\___temp.ahk
		FileAppend, ExitApp `% (A_IsUnicode=1) << 8 | (A_PtrSize=8) << 9, %A_Temp%\___temp.ahk
		RunWait, "%A_ScriptDir%\..\AutoHotkey.exe" "%A_Temp%\___temp.ahk"
		rc := ErrorLevel
		FileDelete,  %A_Temp%\___temp.ahk
		if rc = 0
			binFile = %A_ScriptDir%\ANSI 32-bit.bin
		else if rc = 0x100
			binFile = %A_ScriptDir%\Unicode 32-bit.bin
		else if rc = 0x300
			binFile = %A_ScriptDir%\Unicode 64-bit.bin
		; else: shouldn't happen
	}
	
	IfNotExist, %binFile%
	{
		MsgBox, 52, Ahk2Exe Error,
		(LTrim
		Unable to copy the appropriate binary file as AutoHotkeySC.bin because said file does not exist:
		%binFile%
		
		Do you still want to continue?
		)
		IfMsgBox, Yes
			return
		ExitApp, 0x2 ; Compilation cancelled
	}
	
	FileCopy, %binFile%, %A_ScriptDir%\AutoHotkeySC.bin
}
return

FindBinFile(name)
{
	global BinFiles
	for k,v in BinFiles
		if (v = name)
			return k
	return 1
}

ParseCmdLine:
if 0 = 0
	return

Error_ForceExit := true

p := []
Loop, %0%
{
	if %A_Index% = /NoDecompile
		Util_Error("Error: /NoDecompile is not supported.", 0x23)
	else p.Insert(%A_Index%)
}

if Mod(p.MaxIndex(), 2)
	goto BadParams

Loop, % p.MaxIndex() // 2
{
	p1 := p[2*(A_Index-1)+1]
	p2 := p[2*(A_Index-1)+2]
	
	if p1 not in /in,/out,/icon,/pass,/bin,/mpress,/cp
		goto BadParams
	
	if p1 = /bin
		UsesCustomBin := true
	
	if p1 = /pass
		Util_Error("Error: Password protection is not supported.", 0x24)
	
	if p2 =
		goto BadParams
	
	StringTrimLeft, p1, p1, 1
	gosub _Process%p1%
}

if !AhkFile
	goto BadParams

if !IcoFile
	IcoFile := LastIcon

if !BinFile
	BinFile := A_ScriptDir "\" LastBinFile

if UseMPRESS =
	UseMPRESS := LastUseMPRESS

CLIMode := true
return

BadParams:
Util_Info("Command Line Parameters:`n`n" A_ScriptName " /in infile.ahk [/out outfile.exe] [/icon iconfile.ico] [/bin AutoHotkeySC.bin] [/mpress 1 (true) or 0 (false)] [/cp codepage]")
ExitApp, 0x3

_ProcessIn:
AhkFile := p2
return

_ProcessOut:
ExeFile := p2
return

_ProcessIcon:
IcoFile := p2
return

_ProcessBin:
CustomBinFile := true
BinFile := p2
return

_ProcessMPRESS:
UseMPRESS := p2
return

_ProcessCP: ; for example: '/cp 1252' or '/cp UTF-8'
if p2 is number
	ScriptFileCP := "CP" p2
else
	ScriptFileCP := p2
return

BrowseAhk:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastScriptDir%, Open, AutoHotkey files (*.ahk)
if ErrorLevel
	return
GuiControl,, AhkFile, %ov%
return

BrowseExe:
Gui, +OwnDialogs
FileSelectFile, ov, S16, %LastExeDir%, Save As, Executable files (*.exe)
if ErrorLevel
	return
if !RegExMatch(ov, "\.[^\\/]+$") ;~ append a default file extension is none specified
	ov .= ".exe"
GuiControl,, ExeFile, %ov%
return

BrowseIco:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastIconDir%, Open, Icon files (*.ico)
if ErrorLevel
	return
GuiControl,, IcoFile, %ov%
return

DefaultIco:
GuiControl,, IcoFile
return

Convert:
Gui, +OwnDialogs
Gui, Submit, NoHide
BinFile := A_ScriptDir "\" BinFiles[BinFileId]
ConvertCLI:
AhkCompile(AhkFile, ExeFile, IcoFile, BinFile, UseMpress, ScriptFileCP)
if !CLIMode
	Util_Info("Conversion complete.")
else
	FileAppend, Successfully compiled: %ExeFile%`n, *
return

LoadSettings:
RegRead, LastScriptDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastScriptDir
RegRead, LastExeDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir
RegRead, LastIconDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastIconDir
RegRead, LastIcon, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon
RegRead, LastBinFile, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile
RegRead, LastUseMPRESS, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS
if !FileExist(LastIcon)
	LastIcon := ""
if (LastBinFile = "") || !FileExist(LastBinFile)
	LastBinFile = AutoHotkeySC.bin
return

SaveSettings:
SplitPath, AhkFile,, AhkFileDir
if ExeFile
	SplitPath, ExeFile,, ExeFileDir
else
	ExeFileDir := LastExeDir
if IcoFile
	SplitPath, IcoFile,, IcoFileDir
else
	IcoFileDir := ""
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastScriptDir, %AhkFileDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir, %ExeFileDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIconDir, %IcoFileDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon, %IcoFile%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS, %UseMPRESS%
if !CustomBinFile
	RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile, % BinFiles[BinFileId]
return

Help:
helpfile = %A_ScriptDir%\..\AutoHotkey.chm
IfNotExist, %helpfile%
	Util_Error("Error: cannot find AutoHotkey help file!", 0x52)

VarSetCapacity(ak, ak_size := 8+5*A_PtrSize+4, 0) ; HH_AKLINK struct
NumPut(ak_size, ak, 0, "UInt")
name = Ahk2Exe
NumPut(&name, ak, 8)
DllCall("hhctrl.ocx\HtmlHelp", "ptr", GuiHwnd, "str", helpfile, "uint", 0x000D, "ptr", &ak) ; 0x000D: HH_KEYWORD_LOOKUP
return

About:
Gui, +OwnDialogs
MsgBox, 64, About Ahk2Exe,
(
Ahk2Exe - Script to EXE Converter

Original version:
  Copyright ©1999-2003 Jonathan Bennett & AutoIt Team
  Copyright ©2004-2009 Chris Mallet
  Copyright ©2008-2011 Steve Gray (Lexikos)

Script rewrite:
  Copyright ©2011-2016 fincs
)
return

Util_Status(s)
{
	SB_SetText(s)
}

Util_Error(txt, exitcode, extra := "")
{
	global CLIMode, Error_ForceExit, ExeFileTmp
	
	if (exitcode && ExeFileTmp && FileExist(ExeFileTmp))
	{
		FileDelete, %ExeFileTmp%
		ExeFileTmp =
	}
	
	if extra
		txt .= "`n`nSpecifically: " extra
	
	Util_HideHourglass()
	if exitcode
		MsgBox, 16, Ahk2Exe Error, % txt
	else
		MsgBox, 48, Ahk2Exe Warning, % txt

	
	if CLIMode && exitcode
	{
		FileAppend, Failed to compile: %ExeFile%`n, *
		Util_Status("Ready")
	}
	
	if exitcode
		if !Error_ForceExit
			Exit, exitcode
		else
			ExitApp, exitcode
}

Util_Info(txt)
{
	MsgBox, 64, Ahk2Exe, % txt
}

Util_DisplayHourglass()
{                          ; Change IDC_ARROW (32512) to IDC_APPSTARTING (32650)
  DllCall("SetSystemCursor",Ptr,DllCall("LoadCursor",Ptr,0,Ptr,32512),Ptr,32650)
}

Util_HideHourglass()
{                                              ; Reset arrow cursor to standard
  DllCall("SystemParametersInfo", Ptr,0x57, Ptr,0, Ptr,0, Ptr,0)
}
