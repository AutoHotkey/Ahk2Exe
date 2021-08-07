; 
; File encoding:  UTF-8 with BOM
;
; Script description:
;	Ahk2Exe - AutoHotkey Script Compiler
;	Written by fincs - Interface based on the original Ahk2Exe
;	Updated by TAC109 since 2019
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
#include *i __debug.ahk

OnExit("Util_HideHourglass")             ; Reset cursor on exit

CompressCode := {-1:2, 0:-1, 1:-1, 2:-1} ; Valid compress codes (-1 => 2)

global UseAhkPath := "", AhkWorkingDir := A_WorkingDir, StopCDExe, StopCDIco
	, StopCDBin, SBDMes := "(Use script's 'Base' directives)", CLIMode
	, ExeFiles := [], BinFiles := [], BinNames, FileNameG

ExeDfltMes := "(Default is script file, or any relevant compiler directive)"

; Set default codepage from any installed AHK
ScriptFileCP := A_FileEncoding
RegRead wk, HKCR\\AutoHotkeyScript\Shell\Open\Command
if (wk != "" && RegExMatch(wk, "i)/(CP\d+)", o))
	ScriptFileCP := o1

gosub LoadSettings
gosub ParseCmdLine
gosub BuildBinFileList

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

Menu, FileMenu, Add, R&eset all fields`tF5, Restart
Menu, FileMenu, Add, S&ave script settings As…`tCtrl+S, SaveAsMenu
if (!AhkFile)
	Menu, FileMenu, Disable, S&ave script Settings As…`tCtrl+S
Menu, FileMenu, Add, &Convert, Convert
Menu, FileMenu, Add
Menu, FileMenu, Add, E&xit`tAlt+F4, GuiClose
Menu, HelpMenu, Add, &Help`tF1, Help
Menu, HelpMenu, Add
Menu, HelpMenu, Add, &About, About
Menu, MenuBar,  Add, &File, :FileMenu
Menu, MenuBar,  Add, &Help, :HelpMenu
Gui, Menu, MenuBar

Gui, +LastFound +Resize +MinSize594x415
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
		, % Exefile ? ExeFile : ExeDfltMes
Gui, Add, Button, xp322 yp w53 h23 gBrowseExe vBtnExeFile, B&rowse
Gui, Add, Button,  xp58 yp w53 h23 gDefaultExe vBtnExeDefault, D&efault
Gui, Add, GroupBox, x11 yp50 w570 h120 cBlue vGroupB, Options
Gui, Add, Text,     x17 yp30, Custom &Icon (.ico file)
Gui, Add, Edit,   xp130 yp-4 w305 h23 +Disabled vIcoFile, %IcoFile%
Gui, Add, Button, xp322 yp w53 h23 gBrowseIco vBtnIcoFile, Br&owse
Gui, Add, Button,  xp58 yp w53 h23 gDefaultIco vBtnIcoDefault, Def&ault
Gui, Add, Text,     x17 yp34, Base File (.bin, .exe)
Gui, Add, DDL,    xp130 yp-2 w305 h23 R10 AltSubmit vBinFileId Choose%BinFileId%, %BinNames%
Gui, Add, Button, xp322 yp w53 h23 gBrowseBin vBtnBinFile, Bro&wse
Gui, Add, Text,     x17 yp32, Compress exe with
Gui, Add, DDL, % "xp130 yp-2 w75 AltSubmit gCompress vUseMPress Choose" UseMPRESS+1, (none)|MPRESS|UPX
Gui, Add, Text,     x17 yp50, Convert to executable
Gui, Add, Button, xp130 yp-4 w75 h23 Default gConvert vBtnConvert, > &Convert <
Gui, Add, Text,   xp160 yp4 vSave, Save 'Options' as default
Gui, Add, Button,  x456 yp-4 w53 h23 gSaveAsDefault vBtnSave, S&ave
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
loop, parse, A_GuiEvent, `n
{	SplitPath, A_LoopField,,, DropExt
	if SubStr(DropExt,1,2) = "ah"          ; Allow for v2, e.g. ah2, ahk2, etc
	{	GuiControl,, AhkFile, %A_LoopField%
		Menu, FileMenu, Enable, S&ave script settings As…`tCtrl+S
		Util_Status("""" A_LoopField """ added as 'Source'"), SetCDBin(A_LoopField)
	} 
	else if (DropExt = "ico")
	{	GuiControl,, IcoFile, %A_LoopField%
		Util_Status("""" A_LoopField """ added as 'Custom Icon'"), StopCDIco := 1
	} 
	else if DropExt in bin,exe
	{	Count := FindBinsExes(A_LoopField, "\|", "")
		if (DropExt = "exe" && Count = 0)
		{	GuiControl,, ExeFile1, %A_LoopField%
			Util_Status("""" A_LoopField """ added as 'Destination'"), StopCDExe := 1
			continue
		}
		if (Count > 1)
		{	GuiControl,,       BinFileId, |%BinNames% 
			GuiControl Choose, BinFileId, % BinFiles.MaxIndex()
			Util_Status("""" A_LoopField """ temporarily added to 'Base file' list.")
	}	}	
	else Util_Status("""" A_LoopField """ invalid - ignored!")
}
return

GuiSize:
if (A_EventInfo = 1) ; The window has been minimized.
	return

; Top border / Separator
GuiControl, Move,     TopLine,       % "w" A_GuiWidth-24

; GroupBox - Main Parameters
GuiControl, Move,     AhkFile,       % "w" A_GuiWidth-289
GuiControl, Move,     BtnAhkFile,    % "x" A_GuiWidth-135
GuiControl, Move,     ExeFile1,      % "w" A_GuiWidth-289
GuiControl, Move,     BtnExeFile,    % "x" A_GuiWidth-135
GuiControl, Move,     BtnExeDefault, % "x" A_GuiWidth-77
GuiControl, MoveDraw, GroupA,        % "w" A_GuiWidth-24

; GroupBox - Options
GuiControl, Move,     IcoFile,       % "w" A_GuiWidth-289
GuiControl, Move,     BtnIcoFile,    % "x" A_GuiWidth-135
GuiControl, Move,     BtnIcoDefault, % "x" A_GuiWidth-77
GuiControl, Move,     BtnBinFile,    % "x" A_GuiWidth-135
GuiControl, Move,     BinFileId,     % "w" A_GuiWidth-289
GuiControl, Move,     Save,          % "x" A_GuiWidth-280
GuiControl, MoveDraw, BtnSave,       % "x" A_GuiWidth-135
GuiControl, MoveDraw, GroupB,        % "w" A_GuiWidth-24

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
FindBinsExes(A_ScriptDir "\AutoHotkeySC.bin","\|","","—") ; Any default is first
FindBinsExes(A_ScriptDir "\*",, "")                      ; Rest of \Compiler
if SubStr(A_LineFile,1,1) = "*"                          ; if I am worthy,
	FindBinsExes(A_ScriptDir "\Ahk2Exe.exe", "\|", "","\") ;   add me to the lists
FindBinsExes(A_ScriptDir "\..\*",, "", "|")              ; Parent dir files only
Loop Files,% A_ScriptDir "\..\*", D                      ; Parent dir dirs
	if !(A_LoopFileName~="i)^AutoHotkey_H") && A_LoopFileName~="i)^AutoHotkey|^v"
		FindBinsExes(A_LoopFileLongPath "\*",,, "/")
ToolTip
BinNames := LTrim(BinNames, "|")
return

FindBinsExes(File, Exclude="AutoHotkeySC.bin|Ahk2Exe.exe", Mode="R", Phase="")
{	if (Phase && !CLIMode)
		ToolTip Ahk2Exe:`n%Phase% Working %Phase%
	Count := 0
	Loop Files, %File%, %Mode%
	{	if !(A_LoopFileExt~="i)^(exe|bin)$") || A_LoopFileLongPath~="i)" Exclude "$"
			continue
		Type := AHKType(A_LoopFileLongPath,0) ; Get basic file stats
		if (Type.era = "Modern")
		&&  (A_LoopFileExt = "exe" && InStr(Type.Description,"AutoHotkey")
			&& A_LoopFileName != "AutoHotkey.exe" || A_LoopFileExt = "bin")
		{	Type := AHKType(A_LoopFileLongPath) ; Get Unicode data and other stats
			if (A_LoopFileExt = "exe")
			{	if !(ExeFiles[Type.Version Type.Summary]) ; Keep only first of a version
					ExeFiles[Type.Version Type.Summary] := A_LoopFileLongPath
				wk := StrSplit(Type.Version,[".","-"]), Count++
				if !(wk.1 = 1 &&  wk.3 >= 34 
				||   wk.1 = 2 && (wk.3 = wk.3+0 || wk.3 >= "a135"))
					continue
			}
			BinFiles.Push(A_LoopFileLongPath), Count+=2
			BinNames .= "|v" Type.Version " " Type.Summary " " 
			. (A_LoopFileName = "AutoHotkeySC.bin" ? "(Default)" : A_LoopFileName)
	}	}                        ; Count+=1 if file (could be) added to ExeFiles{}
	return Count               ; Count+=2 if file added to BinFiles[]
}

FindBinFile(name)
{	global BinFiles
	for k,v in BinFiles
		if (v = name)
			return k
	return 1
}

ParseCmdLine:
if !A_Args.MaxIndex()
	return
Error_ForceExit := true
CLIMode := true           ; Set default - may be overridden.
p := A_Args.Clone()       ; Don't deplete A_Args here as needed in 'Restart:'

while p.MaxIndex()
{
	p1 := p.RemoveAt(1)
	
	if SubStr(p1,1,1) != "/" || !(p1fn := Func("CmdArg_" SubStr(p1,2)))
		BadParams("Error: Unrecognised parameter:`n" p1)
	
	if p1fn.MaxParams  ; Currently assumes 0 or 1 params.
	{
		p2 := p.RemoveAt(1)
		if p2 =
			BadParams("Error: Blank or missing parameter for " p1 ".")
	}
	
	%p1fn%(p2)
}

if (AhkFile = "" && CLIMode)
	BadParams("Error: No input file specified.")

if BinFile =
	BinFile := LastBinFile
return

BadParams(Message, ErrorCode=0x3)
{ global Error_ForceExit := true
	Util_Error(Message, ErrorCode,, "Command Line Parameters:`n`n" A_ScriptName "`n`t  /in infile.ahk`n`t [/out outfile.exe]`n`t [/icon iconfile.ico]`n`t [/base AutoHotkeySC.bin]`n`t [/compress 0 (none), 1 (MPRESS), or 2 (UPX)]`n`t [/cp codepage]`n`t [/ahk path\name]`n`t [/gui]")
}

CmdArg_Gui() {
	global
	CLIMode := false
	Error_ForceExit := false
}

CmdArg_In(p2) {
	global AhkFile := p2
	SetCDBin(AhkFile)
}

CmdArg_Out(p2) {
	global StopCDExe := 1, ExeFile := p2
}

CmdArg_Icon(p2) {
	global StopCDIco := 1, IcoFile := p2
}

CmdArg_Base(p2) {
	global StopCDBin := 1, BinFile := p2, LastBinFile := p2
	FindBinsExes(p2, "\|", "")
}

CmdArg_Bin(p2) {
	CmdArg_Base(p2)
}

CmdArg_MPRESS(p2) {
	CmdArg_Compress(p2)
}
CmdArg_Compress(p2) {
	global
	if !CompressCode[p2]                ; Invalid codes?
		BadParams("Error: " p1 " parameter invalid:`n" p2)
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

CmdArg_Pass() {
	BadParams("Error: Password protection is not supported.", 0x24)
}

CmdArg_NoDecompile() {
	BadParams("Error: /NoDecompile is not supported.", 0x23)
}

BrowseAhk:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastAhkDir%, Open Script, AutoHotkey files (*.ahk)
if ErrorLevel
	return
SplitPath ov,, LastAhkDir
GuiControl,, AhkFile, %ov%
SetCDBin(ov)
menu, FileMenu, Enable, S&ave script settings As…`tCtrl+S
return

BrowseExe:
Gui, +OwnDialogs
FileSelectFile ov,S16,%LastExeDir%, Save Executable As, Executable files (*.exe)
if ErrorLevel
	return
if !RegExMatch(ov, "\.[^\\/]+$") ; append a default file extension if none
	ov .= ".exe"
SplitPath ov,, LastExeDir
ExeFile := ov, StopCDExe := 1 
GuiControl,, ExeFile1, %ov%
return

BrowseIco:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastIcoDir%, Open Custom Icon, Icon files (*.ico)
if ErrorLevel
	return
SplitPath ov,, LastIcoDir
GuiControl,, IcoFile, %ov%
StopCDIco := 1
return

BrowseBin:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastBinDir%, Open Base File, Base files (*.bin;*.exe)
if ErrorLevel
	return
SplitPath ov,, LastBinDir
if FindBinsExes(ov, "\|", "") > 1
{	GuiControl,,       BinFileId, |%BinNames% 
	GuiControl Choose, BinFileId, % BinFiles.MaxIndex()
	Util_Status("""" ov """ temporarily added to 'Base file' list.")
} else Util_Status("""" ov """ invalid!")
return

DefaultExe:
ExeFile := "", StopCDExe := 0
GuiControl,, ExeFile1, %ExeDfltMes%
return

DefaultIco:
StopCDIco := 0
GuiControl,, IcoFile
return

Restart:
For k, v in A_Args          ; Add quotes to parameters & escape any trailing \
  wk := StrReplace(v,"""","\"""), Par .= """" wk (SubStr(wk,0)="\"?"\":"") """ "
if A_IsCompiled
	Run "%A_ScriptFullPath%" /Restart %Par%
else 
	Run "%A_AhkPath%" /Restart "%A_ScriptFullPath%" %Par%
ExitApp

SaveAsMenu:
Gui, +OwnDialogs
Gui, Submit, NoHide
BinFile := BinFiles[BinFileId]
SaveAs := ""
FileSelectFile, SaveAs, S,% RegExReplace(AhkFile,"\.[^.]+$") "_Compile"
 , Save script settings As, *.ahk            ;^ Removes extension
If (SaveAs = "") or ErrorLevel
	Return
If !RegExMatch(SaveAs,"\.ahk$")
	SaveAs .= ".ahk"
if FileExist(SaveAs)
{	Gui, +OwnDialogs
	MsgBox 35,, Append to`n"%SaveAs%"?`n`n(Selecting 'No' overwrites any existing file)
	IfMsgBox Cancel, return
	IfMsgBox, No,    FileDelete %SaveAs%
}
FileAppend % "RunWait """ A_ScriptDir "\Ahk2Exe.exe""`n /in """ AhkFile """"
. (ExeFile ? "`n /out """ ExeFile """" : "")
. (IcoFile ? "`n /icon """ IcoFile """": "") 
. "`n /base """ BinFile """`n /compress " UseMpress-1 "`n`n", %SaveAs%
Util_Status("Saved script settings")
Return

SetCDBin(FileName)
{	static LastId := 1
	SetTimer MonitorFile, Off
	FileNameG := FileName, IsBase := Comment := 0
	Loop Read, %FileName%
	{	if RegExMatch(A_LoopReadLine,"i)^\s*\S{1,2}@Ahk2Exe-(?:Bin|Base) (.*$)")
		&& Comment = 0
		{	IsBase := 1
			if (BinFiles.1 != SBDMes)
			{	BinFiles.InsertAt(1,SBDMes), BinNames := SBDMes "|" BinNames
				GuiControlGet LastId,, BinFileId
				GuiControl,,           BinFileId, |%BinNames% 
				GuiControl Choose,     BinFileId, 1
				Util_Status("""" SBDMes """ added to 'Base File' list.")
			}
			break
	}	else if SubStr(LTrim(A_LoopReadLine),1,2) = "/*"      ; Start block comment
			Comment := 1
		if (Comment = 1) && A_LoopReadLine~="^\s*\*/|\*/\s*$" ; End block comment
			Comment := 0
	}
	if (!IsBase && BinFiles.1 = SBDMes)
	{	BinFiles.RemoveAt(1), BinNames := SubStr(BinNames,InStr(BinNames,"|")+1)
		GuiControl,,       BinFileId, |%BinNames% 
		GuiControl Choose, BinFileId,  %LastId%
		Util_Status("""" SBDMes """ removed from 'Base File' list.")
	}                             ; As can't change parameter of BoundFunc Object,
	SetTimer MonitorFile, 400, -1 ;   we are using a global for FileName parameter
}

MonitorFile()
{	static LastTime := LastSize := 0
	FileGetTime ThisTime, %FileNameG%
	FileGetSize ThisSize, %FileNameG%
	if (LastTime != ThisTime || LastSize != ThisSize)
		  LastTime := ThisTime,   LastSize := ThisSize, SetCDBin(FileNameG)
}

Convert:
Gui, +OwnDialogs
Gui, Submit, NoHide
UseMPRESS--
BinFile := BinFiles[BinFileId]
if (BinFile = SBDMes)
	StopCDBin := 0
else StopCDBin := 1

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
	&& RegExMatch(A_LoopReadLine,"i)^\s*\S{1,2}@Ahk2Exe-(?:Bin|Base) (.*$)",o)
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
			if !FileExist(o)
			 Util_Error("Error: The selected Base file does not exist. (A1)"
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
		 AhkCompile(AhkFile, DirExe[k], IcoFile, DirBins[k],UseMpress
		                                       , DirCP[k] ? DirCP[k] : ScriptFileCP)
else AhkCompile(AhkFile, ExeFile,   IcoFile, BinFile,   UseMpress, ScriptFileCP)

if !CLIMode
	Util_Info("Conversion complete.")
else
	FileAppend, Successfully compiled: %ExeFile%`n, *
return

LoadSettings:
RegRead, LastAhkDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastAhkDir
RegRead, LastExeDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir
RegRead, LastBinDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastBinDir
RegRead, LastIcoDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastIcoDir
RegRead, LastIcon,      HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon
RegRead, LastBinFile,   HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile
RegRead, LastUseMPRESS, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS
if !FileExist(LastIcon)
	LastIcon := ""
if (LastBinFile = "") || !FileExist(LastBinFile)
	LastBinFile := BinFiles.1
if !CompressCode[LastUseMPRESS]                ; Invalid codes := 0
	LastUseMPRESS := false
if CompressCode[LastUseMPRESS] > 0             ; Convert any old codes
	LastUseMPRESS := CompressCode[LastUseMPRESS]
return

SaveAsDefault:
Gui, Submit, NoHide
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcoDir,    %LastIcoDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon,      %IcoFile%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS,% UseMPRESS-1
if !(BinFile = SBDMes)
	RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile, % BinFiles[BinFileId]
Util_Status("Options saved as default")
return

SaveSettings:
RegWrite REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastAhkDir, %LastAhkDir%
RegWrite REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir, %LastExeDir%
RegWrite REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinDir, %LastBinDir%
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
{	SB_SetText(s)
}

Util_Error(txt, exitcode, extra := "", extra1 := "")
{
	global CLIMode, Error_ForceExit, ExeFileTmp
	
	if extra
		txt .= "`n`nSpecifically:`n" extra
	
	if extra1
		txt .= "`n`n" extra1
	
	Util_HideHourglass()
	if exitcode
		MsgBox, 16, Ahk2Exe Error, % txt
	else {
		MsgBox, 49, Ahk2Exe Warning, % txt
	. (extra||extra1 ? "" : "`n`nPress 'OK' to continue, or 'Cancel' to abandon.")
		IfMsgBox Cancel
			exitcode := 2
	}
	if (exitcode && ExeFileTmp && FileExist(ExeFileTmp))
	{	FileDelete, %ExeFileTmp%
		ExeFileTmp =
	}

	if CLIMode && exitcode
		FileAppend, Failed to compile: %ExeFile%`n, *
	Util_Status("Ready")
	
	if exitcode
		if !Error_ForceExit
			Exit, exitcode
		else ExitApp, exitcode
	Util_DisplayHourglass()
}

Util_Info(txt)
{	MsgBox, 64, Ahk2Exe, % txt
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
