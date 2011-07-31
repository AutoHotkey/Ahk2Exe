;
; File encoding:  UTF-8
; Platform:  Windows XP/Vista/7
; Author:    A.N.Other <myemail@nowhere.com>
;
; Script description:
;	Template script
;

#NoEnv
#SingleInstance Off
#Include Compiler.ahk
SendMode Input

;DEBUG := true

if A_IsUnicode
	FileEncoding, UTF-8

gosub LoadSettings

if 0 != 0
	goto CLIMain

if DEBUG
{
	AhkFile = %A_ScriptDir%\hello.ahk
	ExeFile = %A_ScriptDir%\hello2.exe
	IcoFile = %A_ScriptDir%\ahkswitch.ico
}else
	IcoFile = %LastIcon%

Menu, FileMenu, Add, &Convert`tCtrl+C, Convert
Menu, FileMenu, Add
Menu, FileMenu, Add, E&xit`tAlt+F4, GuiClose
Menu, HelpMenu, Add, &About`tF1, About
Menu, MenuBar, Add, &File, :FileMenu
Menu, MenuBar, Add, &Help, :HelpMenu
Gui, Menu, MenuBar

Gui, Add, Pic, x40 y5 +0x801000 vlogo, AutoHotkey_logo.png
Gui, Add, Text, x287 y34,
(
©2004-2009 Chris Mallet
©2008-2011 Steve Gray (Lexikos)
©2011 fincs
http://www.autohotkey.com
)
Gui, Add, Text, x11 y117 w570 h2 +0x1007
Gui, Add, GroupBox, x11 y124 w570 h86, Required Parameters
Gui, Add, Text, x17 y151, &Source (script file)
Gui, Add, Edit, x137 y146 w315 h23 +Disabled vAhkFile, %AhkFile%
Gui, Add, Button, x459 y146 w53 h23 gBrowseAhk, &Browse
Gui, Add, Text, x17 y180, &Destination (.exe file)
Gui, Add, Edit, x137 y176 w315 h23 +Disabled vExeFile, %Exefile%
Gui, Add, Button, x459 y176 w53 h23 gBrowseExe, B&rowse
Gui, Add, GroupBox, x11 y219 w570 h57, Optional Parameters
Gui, Add, Text, x18 y245, Custom Icon (.ico file)
Gui, Add, Edit, x138 y241 w315 h23 +Disabled vIcoFile, %IcoFile%
Gui, Add, Button, x461 y241 w53 h23 gBrowseIco, Br&owse
Gui, Add, Button, x519 y241 w53 h23 gDefaultIco, D&efault
Gui, Add, Button, x258 y280 w75 h28 +Default gConvert, > &Convert <
Gui, Add, Statusbar,, Ready
Gui, Show, w594 h334, Ahk2Exe for AHK_L %A_AhkVersion% -- Script to EXE Converter
return

GuiClose:
ExitApp

CLIMain:
p := []
Loop, %0%
{
	if %A_Index% = /NoDecompile
		Util_Error("Error: /NoDecompile is not supported.")
	else p._Insert(%A_Index%)
}

if Mod(p._MaxIndex(), 2)
	goto BadParams

Loop, % p._MaxIndex() // 2
{
	p1 := p[2*(A_Index-1)+1]
	p2 := p[2*(A_Index-1)+2]
	
	if p1 not in /in,/out,/icon,/pass,/bin
		goto BadParams
	
	if p1 = /pass
		Util_Error("Error: Password protection is not supported.")
	
	if p2 =
		goto BadParams
	
	StringTrimLeft, p1, p1, 1
	gosub _Process%p1%
}

if !AhkFile
	goto BadParams

if !IcoFile
	IcoFile := LastIcon

CLIMode := true
gosub ConvertCLI
ExitApp

BadParams:
Util_Info("Command Line Parameters:`n`n" A_ScriptName " /in infile.ahk [/out outfile.exe] [/icon iconfile.ico] [/bin AutoHotkeySC.bin]")
ExitApp

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
BinFile := p2
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
ConvertCLI:
AhkCompile(AhkFile, ExeFile, IcoFile, BinFile)
if !CLIMode
{
	Util_Info("Conversion complete.")
	gosub SaveSettings
}else
	FileAppend, Successfully compiled: %ExeFile%`n, *
return

LoadSettings:
RegRead, LastScriptDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastScriptDir
RegRead, LastExeDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir
RegRead, LastIconDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastIconDir
RegRead, LastIcon, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon
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
return

About:
MsgBox, 64, About Ahk2Exe,
(
Ahk2Exe - Script to EXE Converter

Original version:
  Copyright ©1999-2003 Jonathan Bennett & AutoIt Team
  Copyright ©2004-2009 Chris Mallet
  Copyright ©2008-2011 Steve Gray (Lexikos)

Script rewrite:
  Copyright ©2011 fincs
)
return

Util_Status(s)
{
	SB_SetText(s)
}

Util_Error(txt, doexit=1)
{
	global CLIMode, ExeFile
	Util_HideHourglass()
	MsgBox, 16, Ahk2Exe Error, % txt
	
	if CLIMode
		FileAppend, Failed to compile: %ExeFile%`n, *
	
	Util_Status("Ready")
	
	if doexit
		Exit
}

Util_Info(txt)
{
	MsgBox, 64, Ahk2Exe, % txt
}

Util_DisplayHourglass()
{
	DllCall("SetCursor", "ptr", DllCall("LoadCursor", "ptr", 0, "ptr", 32514, "ptr"))
}

Util_HideHourglass()
{
	DllCall("SetCursor", "ptr", DllCall("LoadCursor", "ptr", 0, "ptr", 32512, "ptr"))
}
