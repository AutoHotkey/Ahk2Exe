; 
; File encoding:  UTF-8 with BOM
;
; Script description:
;	Ahk2Exe - AutoHotkey Script Compiler
;	Written by fincs - Interface based on the original Ahk2Exe
;
; @Ahk2Exe-Bin             Unicode 32*            ; Commented out
;@Ahk2Exe-SetName         Ahk2Exe
;@Ahk2Exe-SetDescription  AutoHotkey Script Compiler
;@Ahk2Exe-SetCopyright    Copyright (c) since 2004
;@Ahk2Exe-SetCompanyName  AutoHotkey
;@Ahk2Exe-SetOrigFilename Ahk2Exe.ahk
;@Ahk2Exe-SetMainIcon     Ahk2Exe.ico

SendMode Input
SetBatchLines -1
#NoEnv
#NoTrayIcon
#SingleInstance Off

#Include %A_ScriptDir%
#Include Compiler.ahk

OnExit("Util_HideHourglass")             ; Reset cursor on exit

CompressCode := {-1:2, 0:-1, 1:-1, 2:-1} ; Valid compress codes (-1 => 2)

global UseAhkPath := "", AhkWorkingDir := A_WorkingDir, StopCDExe, StopCDIco
	, StopCDBin, SBDMes := "Script Bin directive"
	, ExeFiles := [], BinFiles := [], BinNames

ExeDefaultMes := "(default is script source, or any relevant script directive)"

; Set default codepage from any installed AHK
ScriptFileCP := A_FileEncoding
RegRead wk, HKCR\\AutoHotkeyScript\Shell\Open\Command
if (wk != "" && RegExMatch(wk, "i)/(CP\d+)", o))
	ScriptFileCP := o1

gosub BuildBinFileList
gosub LoadSettings
gosub ParseCmdLine
if !CustomBinFile
	gosub CheckAutoHotkeySC

if UseMPRESS =
	UseMPRESS := LastUseMPRESS
if IcoFile =
	IcoFile := LastIcon

if CLIMode
{
	gosub ConvertCLI
	ExitApp, 0 ; Success
}

BinFileId := FindBinFile(LastBinFile)

#include *i __debug.ahk

Menu, FileMenu, Add, S&ave Script Settings As…`tCtrl+S, SaveAsMenu
if (!AhkFile)
	Menu, FileMenu, Disable, S&ave Script Settings As…`tCtrl+S
Menu, FileMenu, Add, &Convert, Convert
Menu, FileMenu, Add
Menu, FileMenu, Add, E&xit`tAlt+F4, GuiClose
Menu, HelpMenu, Add, &Help`tF1, Help
Menu, HelpMenu, Add
Menu, HelpMenu, Add, &About, About
Menu, MenuBar,  Add, &File, :FileMenu
Menu, MenuBar,  Add, &Help, :HelpMenu
Gui, Menu, MenuBar

Gui, +LastFound +Resize +MinSize594x444
GuiHwnd := WinExist("")
Gui, Add, Link, x287 y15,
(
©2004-2009 Chris Mallet
©2008-2011 Steve Gray (Lexikos)
©2011-2016 fincs
©2019-%A_Year% TAC109
<a href="https://www.autohotkey.com">https://www.autohotkey.com</a>
Note: Compiling does not guarantee source code protection.
)
Gui, Add, Text,     x11 y110 w570 h2 +0x1007 vTopLine
Gui, Add, GroupBox, x11 yp15 w570 h95 cBlue vGroupA, Main Parameters
Gui, Add, Text,     x17 yp30, &Source (script file)
Gui, Add, Edit,   xp130 yp-4 w305 h23 +Disabled vAhkFile, %AhkFile%
Gui, Add, Button, xp322 yp w53 h23 gBrowseAhk vBtnAhkFile, &Browse
Gui, Add, Text,     x17 yp34, &Destination (.exe file)
Gui, Add, Edit,   xp130 yp-4 w305 h23 +Disabled vExeFile1
		, % Exefile ? ExeFile : ExeDefaultMes
Gui, Add, Button, xp322 yp w53 h23 gBrowseExe vBtnExeFile, B&rowse
Gui, Add, Button,  xp58 yp w53 h23 gDefaultExe vBtnExeDefault, D&efault
Gui, Add, GroupBox, x11 yp50 w570 h120 cBlue vGroupB, Options
Gui, Add, Text,     x17 yp30, Custom &Icon (.ico file)
Gui, Add, Edit,   xp130 yp-4 w305 h23 +Disabled vIcoFile, %IcoFile%
Gui, Add, Button, xp322 yp w53 h23 gBrowseIco vBtnIcoFile, Br&owse
Gui, Add, Button,  xp58 yp w53 h23 gDefaultIco vBtnIcoDefault, Def&ault
Gui, Add, Text,     x17 yp34, Base File (.bin)
Gui, Add, DDL,    xp130 yp-2 w305 h23 R10 AltSubmit gBinChanged vBinFileId Choose%BinFileId%, %BinNames%
Gui, Add, Text,     x17 yp32, Compress exe with
Gui, Add, DDL, % "xp130 yp-2 w75 AltSubmit gCompress vUseMPress Choose" UseMPRESS+1, (none)|MPRESS|UPX
Gui, Add, Text,     x17 yp50, Save 'Options' as default
Gui, Add, Button, xp243 yp-4 w75 h23 gSaveAsDefault vBtnSave, S&ave
Gui, Add, Text,     x17 yp34, Convert script to executable
Gui, Add, Button, xp243 yp-4 w75 h23 Default gConvert vBtnConvert, > &Convert <
Gui, Add, StatusBar,, Ready
;@Ahk2Exe-IgnoreBegin
Gui, Add, Pic, x29 y16 w240 h78, %A_ScriptDir%\logo.png
;@Ahk2Exe-IgnoreEnd
/*@Ahk2Exe-Keep
gosub AddPicture
*/
Gui, Show, w594 h383, % "Ahk2Exe for AutoHotkey v" A_AhkVersion " -- Script to EXE Converter"
GuiControl, Focus, vBtnConvert
gosub compress
return

GuiClose:
Gui, Submit
UseMPRESS--
gosub SaveSettings
ExitApp

compress:
gui, Submit, NoHide
if (UseMPRESS !=1
 && !FileExist(wk := A_ScriptDir "\" . {2:"MPRESS.exe",3:"UPX.exe"}[UseMPRESS]))
	Util_Status("Warning: """ wk """ not found.")
else Util_Status("Ready")
return

GuiDropFiles:
if A_EventInfo > 4
	Util_Error("You cannot drop more than one file of each type into this window!", 0x51)
loop, parse, A_GuiEvent, `n
{
	SplitPath, A_LoopField,,, dropExt
	if SubStr(dropExt,1,2) = "ah"          ; Allow for v2, e.g. ah2, ahk2, etc
	{	GuiControl,, AhkFile, %A_LoopField%
		Menu, FileMenu, Enable, S&ave Script Settings As…`tCtrl+S
	} else GuiControl,, %dropExt%File, %A_LoopField%
	if (dropExt = "bin")
		CustomBinFile:=1, BinFile := A_LoopField
		, Util_Status("""" BinFile """ will be used until 'Base File' changed.")
	StopCD%dropExt% := 1                     ; Override any compiler directive
}
return

BinChanged:
gui, Submit, NoHide
if CustomBinFile
	Util_Status("Selected 'Base File' will be used.")
else Util_Status("Ready")
CustomBinFile := ""
return

GuiSize:
if (A_EventInfo = 1) ; The window has been minimized.
	return

; Top border / Separator
GuiControl, Move, TopLine,       % "w" A_GuiWidth-24

; GroupBox - Required Parameter
GuiControl, Move, AhkFile,       % "w" A_GuiWidth-289
GuiControl, Move, BtnAhkFile,    % "x" A_GuiWidth-135
GuiControl, MoveDraw, GroupA,    % "w" A_GuiWidth-24

; GroupBox - Optional Parameters
GuiControl, Move, ExeFile1,      % "w" A_GuiWidth-289
GuiControl, Move, BtnExeFile,    % "x" A_GuiWidth-135
GuiControl, Move, BtnExeDefault, % "x" A_GuiWidth-77
GuiControl, Move, IcoFile,       % "w" A_GuiWidth-289
GuiControl, Move, BtnIcoFile,    % "x" A_GuiWidth-135
GuiControl, Move, BtnIcoDefault, % "x" A_GuiWidth-77
GuiControl, Move, BinFileId,     % "w" A_GuiWidth-289
GuiControl, MoveDraw, GroupB,    % "w" A_GuiWidth-24

;GuiControl, Move, BtnSave   , % "x" (A_GuiWidth-75)/2
;GuiControl, Move, BtnConvert, % "x" (A_GuiWidth-75)/2
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

hGdip := DllCall("LoadLibrary", "str", "gdiplus", "Ptr")
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
		Unable to copy the appropriate binary file as AutoHotkeySC.bin because the current user does not have write/create privileges in the %A_ScriptDir% folder.
		
		You should run this program once as administrator to complete setup.
		
		Abandon this run?
		)
		IfMsgBox, No
			return
		ExitApp, 0x2 ; Compilation cancelled
	}
	FileDelete, %A_ScriptDir%\___.tmp
	
	IfNotExist, %A_ScriptDir%\..\AutoHotkey.exe
	{
		BinFile = %A_ScriptDir%\Unicode 32-bit.bin

		if !FileExist(BinFile)                  ; Ahk2Exe in non-standard folder?
		{	FileCopy  %A_AhkPath%\..\Compiler\Unicode 32-bit.bin
			       ,  %A_ScriptDir%\AutoHotkeySC.bin
			BinFile = %A_ScriptDir%\AutoHotkeySC.bin
			FileCopy  %A_AhkPath%\..\Compiler\*bit.bin, %A_ScriptDir%\, 1
		}
	} else {
		BinType := AHKType(A_ScriptDir "\..\AutoHotkey.exe")
		if (BinType.PtrSize = 8)
			BinFile = %A_ScriptDir%\Unicode 64-bit.bin
		else if (BinType.IsUnicode)
			BinFile = %A_ScriptDir%\Unicode 32-bit.bin
		else 
			BinFile = %A_ScriptDir%\ANSI 32-bit.bin
	}

	IfNotExist, %BinFile%
	{
		MsgBox, 52, Ahk2Exe Error,
		(LTrim
		Unable to copy the appropriate binary file as AutoHotkeySC.bin because said file does not exist:
		%BinFile%
		
		Abandon this run?
		)
		IfMsgBox, No
			return
		ExitApp, 0x2 ; Compilation cancelled
	}
	
	FileCopy, %BinFile%, %A_ScriptDir%\AutoHotkeySC.bin
}
BinType := AHKType(A_ScriptDir "\AutoHotkeySC.bin")
wk := BinType.PtrSize=8?"Unicode 64":BinType.IsUnicode?"Unicode 32":"ANSI 32"
BinNames := SubStr(BinNames,1,8) " - " wk "-bit" SubStr(BinNames,9)
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
	p.Insert(%A_Index%)

; Set defaults - may be overridden.
CLIMode := true  
SilentMode := false
ForceReload := false
Verbose := false

while p.MaxIndex()
{
	p1 := p.RemoveAt(1)
	
	if SubStr(p1,1,1) != "/" || !(p1fn := Func("CmdArg_" SubStr(p1,2)))
		BadParams("Unrecognised parameter:`n" p1)
	
	if p1fn.MaxParams  ; Currently assumes 0 or 1 params.
	{
		p2 := p.RemoveAt(1)
		if p2 =
			BadParams("Blank or missing parameter for " p1 ".")
	}
	
	%p1fn%(p2)
}

if (AhkFile = "" && CLIMode)
	BadParams("No input file specified.")

if (SilentMode && !CLIMode){
	BadParams("/silent requires CLI mode.")
}

if BinFile =
	BinFile := A_ScriptDir "\" LastBinFile
return

BadParams(Message, ErrorCode=0x3)
{
	params = 
	(LTrim
	Command Line Parameters:
	Ahk2Exe.exe
	`t[/silent]
	`t[/gui]
	`t /in infile.ahk
	`t[/out outfile.exe]
	`t[/icon iconfile.ico]
	`t[/bin AutoHotkeySC.bin]
	`t[/compress 0 (none), 1 (MPRESS), or 2 (UPX)]
	`t[/cp codepage]
	`t[/ahk path\name]
	`t[/ForceReload]
	`t[/verbose]
	)
	Util_Error(Message, ErrorCode,, params)
}

CmdArg_Gui() {
	global
	CLIMode := false
	Error_ForceExit := false
}

CmdArg_In(p2) {
	global AhkFile := p2
	SetCDBin()
}

CmdArg_Out(p2) {
	global ExeFile := p2, StopCDExe := 1
}

CmdArg_Icon(p2) {
	global IcoFile := p2, StopCDIco := 1
}

CmdArg_Bin(p2) {
	global
	CustomBinFile := StopCDBin := true, BinFile := p2
}

CmdArg_MPRESS(p2) {
	CmdArg_Compress(p2)
}
CmdArg_Compress(p2) {
	global
	if !CompressCode[p2]                ; Invalid codes?
		BadParams(p1 " parameter invalid:`n" p2)
	if CompressCode[p2] > 0             ; Convert any old codes
		p2 := CompressCode[p2]
	UseMPRESS := p2
}

CmdArg_Ahk(p2) {
	global
	if !FileExist(p2)
		Util_Error("Error: Specified resource does not exist.", 0x36
		, "Command line parameter /ahk`n""" p2 """")
	UseAhkPath := Util_GetFullPath(p2)
}

CmdArg_CP(p2) { ; for example: '/cp 1252' or '/cp UTF-8'
	global
	if p2 is number
		ScriptFileCP := "CP" p2
	else
		ScriptFileCP := p2
}

CmdArg_Silent(){
	global SilentMode:= true
}

CmdArg_ForceReload(){
	global ForceReload:= true
}

CmdArg_Verbose(){
	global Verbose:= true
}

CmdArg_Pass() {
	BadParams("Password protection is not supported.", 0x24)
}

CmdArg_NoDecompile() {
	BadParams("/NoDecompile is not supported.", 0x23)
}

BrowseAhk:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastScriptDir%, Open, AutoHotkey files (*.ahk)
if ErrorLevel
	return
SplitPath ov,, LastScriptDir
GuiControl,, AhkFile, %ov%
menu, FileMenu, Enable, S&ave Script Settings As…`tCtrl+S
return

BrowseExe:
Gui, +OwnDialogs
FileSelectFile, ov, S16, %LastExeDir%, Save As, Executable files (*.exe)
if ErrorLevel
	return
if !RegExMatch(ov, "\.[^\\/]+$") ; append a default file extension if none
	ov .= ".exe"
SplitPath ov,, LastExeDir
ExeFile := ov, StopCDExe := 1, SetCDBin()
GuiControl,, ExeFile1, %ov%
return

BrowseIco:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastIconDir%, Open, Icon files (*.ico)
if ErrorLevel
	return
SplitPath ov,, LastIconDir
GuiControl,, IcoFile, %ov%
StopCDIco := 1
return

DefaultExe:
ExeFile := "", StopCDExe := 0
GuiControl,, ExeFile1, %ExeDefaultMes%
return

DefaultIco:
StopCDIco := 0
GuiControl,, IcoFile
return

SaveAsMenu:
Gui, +OwnDialogs
Gui, Submit, NoHide
BinFile := A_ScriptDir "\" BinFiles[BinFileId]
SaveAs := ""
FileSelectFile, SaveAs, S,% RegExReplace(AhkFile,"\.[^.]+$") "_Compile"
 , Save Script Settings As, *.ahk            ;^ Removes extension
If (SaveAs = "") or ErrorLevel
	Return
If !RegExMatch(SaveAs,"\.ahk$")
	SaveAs .= ".ahk"
Gui, +OwnDialogs
MsgBox 35,, Append to`n"%SaveAs%"?`n`n(Selecting 'No' overwrites any existing file)
IfMsgBox Cancel, return
IfMsgBox, No,    FileDelete %SaveAs%
FileAppend % "RunWait """ A_ScriptDir "\Ahk2Exe.exe""`n /in """ AhkFile """"
. (ExeFile ? "`n /out """ ExeFile """" : "")
. (IcoFile ? "`n /icon """ IcoFile """": "") 
. "`n /bin """ BinFile """`n /compress " UseMpress-1 "`n`n", %SaveAs%
Util_Status("Saved script settings")
Return

SetCDBin()
{	Loop Read %AhkFile%
	{	if RegExMatch(A_LoopReadLine,"i)^\s*\S{1,2}@Ahk2Exe-Bin (.*$)")
		{ if (BinFiles.1 != SBDMes)
			{	BinFiles.InsertAt(1,SBDMes), BinNames := SBDMes "|" BinNames
				return 1
	}	}	}
	if (BinFiles.1 = SBDMes)
		BinFiles.RemoveAt(1), BinNames := SubStr(BinNames,InStr(BinNames,"|")+1)
}	

Convert:
Gui, +OwnDialogs
Gui, Submit, NoHide
UseMPRESS--
if !CustomBinFile
	BinFile := A_ScriptDir "\" BinFiles[BinFileId]

ConvertCLI:
AhkFile := Util_GetFullPath(AhkFile)
if AhkFile =
	Util_Error("Error: Source file not specified.", 0x33)
SplitPath, AhkFile, ScriptName, ScriptDir
DerefIncludeVars.A_ScriptFullPath := AhkFile
DerefIncludeVars.A_ScriptName := ScriptName
DerefIncludeVars.A_ScriptDir := ScriptDir
SetWorkingDir %A_ScriptDir%

global DirDone := []                   ; Process Bin directives
DirBinsWk := [], DirBins := [], DirExe := [], DirCP := [], Cont := 0
Loop Read, %AhkFile%                   ;v Handle 1-2 unknown comment characters
{	if (Cont=1 && RegExMatch(A_LoopReadLine,"i)^\s*\S{1,2}@Ahk2Exe-Cont (.*$)",o))
		DirBinsWk[DirBinsWk.MaxIndex()] .= RegExReplace(o1,"\s+;.*$")
		, DirDone[A_Index] := 1
	else if (Cont!=2)
	&& RegExMatch(A_LoopReadLine,"i)^\s*\S{1,2}@Ahk2Exe-Bin (.*$)",o)
		DirBinsWk.Push(RegExReplace(o1, "\s+;.*$")), Cont := 1, DirDone[A_Index]:= 1
	else if SubStr(LTrim(A_LoopReadLine),1,2) = "/*"
		Cont := 2
	else if Cont != 2
		Cont := 0
	if (Cont = 2) && A_LoopReadLine~="^\s*\*/|\*/\s*$"  ;End block comment
		Cont := 0
}
for k, v1 in StopCDBin ? [] : DirBinsWk
{	Util_Status("Processing directive: " v1)
	StringReplace, v, v1, ```,, `n, All
	Loop Parse, v, `,, %A_Space%%A_Tab%
	{	if A_LoopField =
			continue
		StringReplace, o1, A_LoopField, `n, `,, All
		StringReplace, o,o1, ``n, `n, All
		StringReplace, o, o, ``r, `r, All
		StringReplace, o, o, ``t, `t, All
		StringReplace, o, o,````, ``, All
		o := DerefIncludePath(o, DerefIncludeVars, 1)
		if A_Index = 1
		{	o .= RegExReplace(o, "\.[^\\]*$") = o ? ".bin" : "" ; Add extension?
			if !(FileExist(o) && RegExReplace(o,"^.+\.") = "bin")
			 Util_Error("Error: The selected AutoHotkeySC binary does not exist. (A1)"
			 , 0x34, """" o1 """")
			Loop Files, % o
				DirBins.Push(A_LoopFileLongPath), DirExe.Push(ExeFile), Cont := A_Index
		} else if A_Index = 2
		{	SplitPath ExeFile    ,, edir,,ename
			SplitPath A_LoopField,, idir,,iname
			Loop % Cont
				DirExe[DirExe.MaxIndex()-A_Index+1] 
				:= (idir ? idir : edir) "\" (iname ? iname : ename) ".exe"
		}	else if A_Index = 3
		{	wk := A_LoopField~="^\d+$" ? "CP" A_LoopField : A_LoopField
			Loop % Cont
				DirCP[DirExe.MaxIndex()-A_Index+1] := wk
		}	else Util_Error("Error: Wrongly formatted directive. (A1)", 0x64, v1)
}	}
if Util_ObjNotEmpty(DirBins)
	for k in DirBins
		 ExeFile:= AhkCompile(AhkFile, DirExe[k], IcoFile, DirBins[k],UseMpress
		                                       , DirCP[k] ? DirCP[k] : ScriptFileCP)
else ExeFile:= AhkCompile(AhkFile, ExeFile,   IcoFile, BinFile,   UseMpress, ScriptFileCP)

Util_Info("Conversion complete.")
if CLIMode
	FileAppend, Successfully compiled: %ExeFile%`n, *
return

LoadSettings:
RegRead, LastScriptDir, HKCU, Software\AutoHotkey\Ahk2Exe, LastScriptDir
RegRead, LastExeDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir
RegRead, LastIconDir,   HKCU, Software\AutoHotkey\Ahk2Exe, LastIconDir
RegRead, LastIcon,      HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon
RegRead, LastBinFile,   HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile
RegRead, LastUseMPRESS, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS
if !FileExist(LastIcon)
	LastIcon := ""
if (LastBinFile = "") || !FileExist(A_ScriptDir "\" LastBinFile)
	LastBinFile = AutoHotkeySC.bin
if !CompressCode[LastUseMPRESS]                ; Invalid codes := 0
	LastUseMPRESS := false
if CompressCode[LastUseMPRESS] > 0             ; Convert any old codes
	LastUseMPRESS := CompressCode[LastUseMPRESS]
return

SaveAsDefault:
Gui, Submit, NoHide
if IcoFile
	SplitPath, IcoFile,, IcoFileDir
else
	IcoFileDir := ""
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIconDir,   %IcoFileDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon,      %IcoFile%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS,% UseMPRESS-1
if !CustomBinFile
	RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile, % BinFiles[BinFileId]
Util_Status("Options saved as default")
return

SaveSettings:
SplitPath, AhkFile,, AhkFileDir
if ExeFile
	SplitPath, ExeFile,, ExeFileDir
else
	ExeFileDir := LastExeDir
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastScriptDir, %AhkFileDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir,    %ExeFileDir%
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

Script maintenance:
  2019-%A_Year% TAC109

Special thanks:
  joedf, benallred, aviaryan
)
return

Util_Status(s)
{
	global Verbose
	if Verbose{
		if s not in ,Ready
			FileAppend, Ahk2Exe Status: %s%`n, *
	} 
	SB_SetText(s)
}

Util_Error(txt, exitcode, extra := "", extra1 := "")
{
	global CLIMode, Error_ForceExit, ExeFileTmp, SilentMode
	
	if extra
		txt .= "`n`nSpecifically:`n" extra
	
	if extra1
		txt .= "`n`n" extra1
	
	Util_HideHourglass()
	if CLIMode && SilentMode {
		FileAppend, % "Ahk2Exe " (exitcode? "Error" : "Warning") ": " txt "`n", **
	} else {
		if exitcode
			MsgBox, 16, Ahk2Exe Error, % txt
		else {
			MsgBox, 49, Ahk2Exe Warning, % txt
		. (extra||extra1 ? "" : "`n`nPress 'OK' to continue, or 'Cancel' to abandon.")
			IfMsgBox Cancel
				exitcode := 2
		}
	}
	if (exitcode && ExeFileTmp && FileExist(ExeFileTmp))
	{	FileDelete, %ExeFileTmp%
		ExeFileTmp =
	}

	if CLIMode && exitcode
		FileAppend, Failed to compile: %ExeFile%`n, **
	Util_Status("Ready")
	
	if exitcode
		if Error_ForceExit || SilentMode
			ExitApp, %exitcode%
		else
			Exit, %exitcode% 
	Util_DisplayHourglass()
}

Util_Info(txt)
{	
	global SilentMode
	if SilentMode
		FileAppend, Ahk2Exe Info: %txt%`n, *
	else
		MsgBox, 64, Ahk2Exe, % txt
}

Util_DisplayHourglass()    ; Change IDC_ARROW (32512) to IDC_APPSTARTING (32650)
{	DllCall("SetSystemCursor", "Ptr",DllCall("LoadCursor", "Ptr",0, "Ptr",32512)
	,"Ptr",32650)
}

Util_HideHourglass()                           ; Reset arrow cursor to standard
{	DllCall("SystemParametersInfo", "Ptr",0x57, "Ptr",0, "Ptr",0, "Ptr",0)
}

Util_ObjNotEmpty(obj)
{	for _,__ in obj
		return true
}
