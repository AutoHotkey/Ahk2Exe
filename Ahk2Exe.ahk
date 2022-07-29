; 
; File encoding:  UTF-8 with BOM
;
; Script description:
;	Ahk2Exe - AutoHotkey Script Compiler
;	Written by fincs - Interface based on the original Ahk2Exe
;	Updated by TAC109 since 2019
;
; Must be compiled with itself (same version)
;
; @Ahk2Exe-Base           AutoHotkeyU32.exe           ; Commented out; advisory
;@Ahk2Exe-SetName         Ahk2Exe
;@Ahk2Exe-SetDescription  AutoHotkey Script Compiler
;@Ahk2Exe-SetCopyright    Copyright (c) since 2004
;@Ahk2Exe-SetOrigFilename Ahk2Exe.ahk
;@Ahk2Exe-SetMainIcon     Ahk2Exe.ico

;v Quoted literal at end must be empty on GitHub. Needs Ahk2Exe v1.1.34.03c+
Ver := A_IsCompiled ? AHKType(A_ScriptFullPath,0).Version : A_AhkVersion ""
;@Ahk2Exe-Obey U_V, = "%A_PriorLine~U)^(.+")(.*)".*$~$2%" ? "SetVersion" : "Nop"
;@Ahk2Exe-%U_V%        %A_AhkVersion%%A_PriorLine~U)^(.+")(.*)".*$~$2%

SendMode Input
SetBatchLines -1
#NoEnv
#NoTrayIcon
#SingleInstance Off

#Include %A_ScriptDir%
#Include Compiler.ahk
#include *i __debug.ahk

OnExit("Util_HideHourglass")             ; Reset cursor on exit
OnExit("UpdDirRem")                      ; Remove any temp directory

CompressCode := {-1:2, 0:-1, 1:-1, 2:-1} ; Valid compress codes (-1 => 2)

global UseAhkPath := "", AhkWorkingDir := A_WorkingDir, StopCDExe, StopCDIco
	, StopCDBin, SBDMes := "(Use script's 'Base' directives)", CLIMode, DirDoneG
	, ExeFiles := [], BinFiles := [], BinNames, FileNameG, LastIdG := 1

ExeDfltMes := "(Default is script file, or any relevant compiler directive)"

; Set default codepage from any installed AHK
ScriptFileCP := A_FileEncoding
RegRead wk, HKCR\\AutoHotkeyScript\Shell\Open\Command
if (wk != "" && RegExMatch(wk, "i)/(CP\d+)", o))
	ScriptFileCP := o1

gosub LoadSettings
gosub ParseCmdLine
gosub BuildBinFileList

UseMPRESS := UseMPRESS = "" ? LastUseMPRESS : UseMPRESS
IcoFile   := IcoFile   = "" ? LastIcon      : IcoFile

if CLIMode
{	ConvertCLI()
	ExitApp, 0 ; Success
}
if (BinFiles.1 = SBDMes && !StopCDBin)
	BinFileId := 1, LastIdG := FindBinFile(LastBinFile) - 1
else BinFileId := FindBinFile(LastBinFile)

AllowMes0 := "A&llow Gui Shrinkage`tAlt+L"
AllowMes1 := "Disa&llow Gui Shrinkage`tAlt+L"
SaveMes   := "S&ave Script Settings As…`tCtrl+S"

Help1 := Func("Help").Bind(0,"Ahk2Exe", "Scripts.htm#ahk2exe") ; Help topics
Help2 := Func("Help").Bind(0,"Compression", "Scripts.htm#mpress")
Help3 := Func("Help").Bind(0,"Compression", "Scripts.htm#mpress")
Help4 := Func("Help").Bind(0,"PostExec directive (Ahk2Exe)"
	,"misc/Ahk2ExeDirectives.htm#PostExec")

Menu, FileMenu, Add, %AllowMes0%, Shrink
Menu, FileMenu, Add, R&eset all Fields`tF5, Restart
Menu, FileMenu, Add, %SaveMes%, SaveAsMenu
if (!AhkFile)
	Menu, FileMenu, Disable, %SaveMes%
Menu, FileMenu, Add, &Convert`tAlt+C, Convert
Menu, FileMenu, Add
Menu, FileMenu, Add, E&xit`tAlt+F4, GuiClose
Menu, HelpMenu, Add, &Help`tF1, % Help1
Menu, HelpMenu, Add, Check for Updates...`tAlt+K, Update
Menu, HelpMenu, Add
Menu, HelpMenu, Add, &About, About
Menu, MenuBar,  Add, &File, :FileMenu
Menu, MenuBar,  Add, &Help, :HelpMenu
;Gui, Font, s9, simsun                        ; To test overlapping GUI fields
;Gui, Font, , Segoe UI Variable               ; English default
Gui, Menu, MenuBar

GuiX := 580, GuiY := 355

Gui, +LastFound +Resize +MinSize%GuiX%x%GuiY% ; +MaxSizex%GuiY%
GuiHwnd := WinExist("")                       ;^ Fails on older Windows versions
Gui, Add, Link, x275 y5 vHeading2,
(
©2004-2009 Chris Mallet
©2008-2011 Steve Gray (Lexikos)
©2011-2016 fincs
©2019-%A_Year% TAC109
<a href="https://www.autohotkey.com">https://www.autohotkey.com</a>
Note: Compiling does not guarantee source code protection.
)
Gui, Add, Text,     x11 y90 w556 h2 +0x1007 vTopLine
Gui, Add, GroupBox, x11 yp10 w556 h80 cGreen vGroupA, Main Parameters
Gui, Add, Text,     x17 yp20, &Source (script file)
Gui, Add, Edit,   xp140 yp-4 w291 h23 ReadOnly vAhkFile, %AhkFile%
Gui, Add, Button, xp296 yp w53 h23 gBrowseAhk vBtnAhkFile, &Browse
Gui, Add, Text,     x17 yp34, &Destination (.exe file)
Gui, Add, Edit,   xp140 yp-4 w291 h23 ReadOnly vExeFile1
		, % Exefile ? ExeFile : ExeDfltMes
Gui, Add, Button, xp296 yp w53 h23 gBrowseExe vBtnExeFile, B&rowse
Gui, Add, Button,  xp58 yp w53 h23 gDefaultExe vBtnExeDefault, D&efault
Gui, Add, GroupBox, x11 yp45 w556 h105 cGreen vGroupB, Options
Gui, Add, Text,     x17 yp20, Custom &Icon (.ico file)
Gui, Add, Edit,   xp140 yp-4 w291 h23 ReadOnly vIcoFile, %IcoFile%
Gui, Add, Button, xp296 yp w53 h23 gBrowseIco vBtnIcoFile, Br&owse
Gui, Add, Button,  xp58 yp w53 h23 gDefaultIco vBtnIcoDefault, Def&ault
Gui, Add, Text,     x17 yp34, Base File (.bin, .exe)
Gui, Add, DDL,    xp140 yp-2 w291 h23 R10 AltSubmit gBinChanged vBinFileId Choose%BinFileId%, %BinNames%
Gui, Add, Button, xp296 yp w53 h23 gBrowseBin vBtnBinFile, Bro&wse
Gui, Add, Text,     x17 yp32, Compress exe with
Gui, Add, DDL, % "xp140 yp-2 w75 AltSubmit gCompress vUseMPress Choose" UseMPRESS+1, (none)|MPRESS|UPX
Gui, Add, Text,   xp150 yp2 vEmbRes, Embedded Resource ID
gui, Add, ComboBox,x444 yp-2 w112 vResourceID, %LastResource%
Gui, Add, Text,     x17 yp40, Convert to executable
Gui, Font, bold
Gui, Add, Button, xp140 yp-4 w75 h23 Default gConvert vBtnConvert, &Convert
Gui, Font, norm 
Gui, Add, Text,   xp150 yp4 vSave, Save 'Options' as default
Gui, Add, Button,  x444 yp-4 w53 h23 gSaveAsDefault vBtnSave, S&ave
Gui, Add, StatusBar,, Ready
;@Ahk2Exe-IgnoreBegin
Gui, Add, Pic, x20 y6 w240 h78 vHeading1, %A_ScriptDir%\logo.png
;@Ahk2Exe-IgnoreEnd
/*@Ahk2Exe-Keep
gosub AddPicture
*/
Gui, Show, %LastWidth%, Ahk2Exe for AutoHotkey v%Ver% -- Script to EXE Converter
GuiControl, Focus, vBtnConvert
gosub compress
gosub BinChanged
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
Util_Status("Warning: """ wk """ not found. See 'Help' -> 'Check for Updates'.")
else Util_Status("Ready")
return

BinChanged:
Gui Submit, NoHide
GuiControl % SubStr(BinFiles[BinFileId],-3)=".bin"?"Disable":"Enable",EmbRes
GuiControl % SubStr(BinFiles[BinFileId],-3)=".bin"?"Disable":"Enable",ResourceID
return

GuiDropFiles:
loop, parse, A_GuiEvent, `n
{	SplitPath, A_LoopField,,, DropExt
	if SubStr(DropExt,1,2) = "ah"          ; Allow for v2, e.g. ah2, ahk2, etc
	{	GuiControl,, AhkFile, %A_LoopField%
		Menu, FileMenu, Enable, %SaveMes%
		Util_Status("""" A_LoopField """ added as 'Source'"), SetCDBin(A_LoopField)
	} 
	else if (DropExt = "ico")
	{	GuiControl,, IcoFile, %A_LoopField%
		Util_Status("""" A_LoopField """ added as 'Custom Icon'"), StopCDIco := 1
	} 
	else if DropExt in bin,exe
	{	MouseGetPos,,,,Control ; .exe is 'Dest.' if dropped onto 'Main Parameters'
		if (DropExt = "exe" && Control ~= "^(Edit[12]|Static[23]|Button[1-4])$")
		{	GuiControl,, ExeFile1, %A_LoopField%
			ExeFile := A_LoopField, StopCDExe := 1
			Util_Status("""" A_LoopField """ added as 'Destination'")
		}	else AddBin(A_LoopField)		
	}
	else Util_Status("""" A_LoopField """ invalid - ignored!")
}
return

Shrink:
Gui % (Flip := !Flip, Flip1 := !Flip) ? "-MinSize" : "+MinSize" GuiX "x" GuiY
Menu FileMenu, Rename, % AllowMes%Flip1%, % AllowMes%Flip%
Gui Show, w%GuiX% h%GuiY%
return

Restart:
For k, v in A_Args          ; Add quotes to parameters & escape any trailing \
  wk := StrReplace(v,"""","\"""), Par .= """" wk (SubStr(wk,0)="\"?"\":"") """ "
if A_IsCompiled
	Run "%A_ScriptFullPath%" /Restart %Par%
else 
	Run "%A_AhkPath%" /Restart "%A_ScriptFullPath%" %Par%
ExitApp

GuiSize:
if (A_EventInfo = 1) ; The window has been minimized.
	return

; Headings
GuiControl, Move,     Heading1,      % "x" A_GuiWidth-560 -(A_GuiWidth-GuiX)/2
GuiControl, MoveDraw, Heading2,      % "x" A_GuiWidth-305 -(A_GuiWidth-GuiX)/2

; Top border / Separator
GuiControl, Move,     TopLine,       % "w" A_GuiWidth-24

; GroupBox - Main Parameters
GuiControl, Move,     AhkFile,       % "w" A_GuiWidth-299
GuiControl, Move,     BtnAhkFile,    % "x" A_GuiWidth-135
GuiControl, Move,     ExeFile1,      % "w" A_GuiWidth-299
GuiControl, Move,     BtnExeFile,    % "x" A_GuiWidth-135
GuiControl, Move,     BtnExeDefault, % "x" A_GuiWidth-77
GuiControl, MoveDraw, GroupA,        % "w" A_GuiWidth-24

; GroupBox - Options
GuiControl, Move,     IcoFile,       % "w" A_GuiWidth-299
GuiControl, Move,     BtnIcoFile,    % "x" A_GuiWidth-135
GuiControl, Move,     BtnIcoDefault, % "x" A_GuiWidth-77
GuiControl, Move,     BtnBinFile,    % "x" A_GuiWidth-135
GuiControl, Move,     BinFileId,     % "w" A_GuiWidth-299
GuiControl, Move,     EmbRes,        % "x" A_GuiWidth-290
GuiControl, MoveDraw, ResourceID,    % "x" A_GuiWidth-135
GuiControl, MoveDraw, GroupB,        % "w" A_GuiWidth-24

; Footer
GuiControl, MoveDraw, Save,          % "x" A_GuiWidth-290
GuiControl, MoveDraw, BtnSave,       % "x" A_GuiWidth-135
LastWidth := "W" A_GuiWidth
return

/*@Ahk2Exe-Keep
AddPicture:
; Code based on http://www.autohotkey.com/forum/viewtopic.php?p=147052
Gui, Add, Text, x20 y6 w240 h78 +0xE hwndhPicCtrl vHeading1

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

FindBinFile(name)
{	for k,v in BinFiles
		if (v = name)
			return k
	return 1
}

BuildBinFileList:
FindBinsExes(A_ScriptDir "\AutoHotkeySC.bin","\|","","-") ; Any default is first
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

FindBinsExes(File, Excl="AutoHotkeySC.bin|Ahk2Exe.exe", Mode="R",Phase="",Dup=0)
{	if (Phase && !CLIMode)
		ToolTip Ahk2Exe:`n%Phase% Working %Phase%
	Count := 0
	Loop Files, %File%, %Mode%
	{	if !(A_LoopFileName~="i)\.bin$|^AutoHotkey.+\.exe$|^Ahk2Exe.exe$")
		|| A_LoopFileName~="i)^(" Excl ")$|_UIA.exe$"
			continue
		Type := AHKType(A_LoopFileLongPath)   ; Get Unicode data and stats
		if (Type.era = "Modern") && (A_LoopFileExt = "bin"
		|| (A_LoopFileExt = "exe" && InStr(Type.Description,"AutoHotkey")))
		{	if (A_LoopFileExt = "exe")
			{	if !(ExeFiles[Type.Version Type.Summary]) ; Keep only first of a version
					ExeFiles[Type.Version Type.Summary] := A_LoopFileLongPath
				wk := StrSplit(Type.Version,[".","-"]), Count++
				if !(wk.1 = 1 &&  wk.3 >= 34 
				||   wk.1 = 2 && (wk.3 = wk.3+0 || wk.3 >= "a135"))
					continue
			} Count+=2
			if (!Dup        ; Skip duplicate Base files by default
			&& BinNames ~= "\|v" Type.Version " " Type.Summary " " A_LoopFileName)
				continue 
			BinFiles.Push(A_LoopFileLongPath)
			BinNames .= "|v" Type.Version " " Type.Summary " " 
			. (A_LoopFileName = "AutoHotkeySC.bin" ? "(Default) bin" : A_LoopFileName)
	}	}                        ; Count+=1 if file (could be) added to ExeFiles{}
	return Count               ; Count+=2 if file (could be) added to BinFiles[]
}

AddBin(File)
{	if FindBinsExes(File, "\|", "",, 1) < 2
	{	Util_Error("Warning: Base file appears to be invalid.",0 ,"""" File """"
		, "Press 'OK' to accept anyway, or 'Cancel' to ignore.", 0)
		Type := AHKType(File), BinFiles.Push(File), BinNames .= "|v"
		. Type.Version " " Type.Summary " " RegExReplace(File, "^.+\\")
	}
	GuiControl,,       BinFileId, |%BinNames% 
	GuiControl Choose, BinFileId, % BinFiles.MaxIndex()
	Util_Status("""" File """ added to 'Base file' list.")
}		

ParseCmdLine:
if !A_Args.MaxIndex()
	return
Error_ForceExit := true

; Set defaults - may be overridden.
CLIMode := true
SilentMode := 0	; 0=off, 1=on, 2=verbose
p := A_Args.Clone()       ; Don't deplete A_Args here as needed in 'Restart:'

while p.MaxIndex()
{
	p1 := p.RemoveAt(1)
	
	if SubStr(p1,1,1) != "/" || !(p1fn := Func("CmdArg_" SubStr(p1,2)))
		BadParams("Error: Unrecognised parameter:`n" p1)
	
	if p1fn.MaxParams  ; Currently assumes 0 or 1 params.
	{
		p2 := p.RemoveAt(1)
		if (p2 = "" || SubStr(p2,1,1) = "/")
			BadParams("Error: Blank or missing parameter for " p1 ".")
	}
	
	%p1fn%(p2)
}

if (AhkFile = "" && CLIMode)
	BadParams("Error: No input file specified.")

if (SilentMode && !CLIMode){
	BadParams("Error: /silent requires CLI mode.")
}

if BinFile =
	BinFile := LastBinFile
return

BadParams(Message, ErrorCode := 0x3, Specifically := "")
{ global Error_ForceExit := true
	Util_Error(Message, ErrorCode,Specifically, "Command Line Parameters:`n`n" A_ScriptName "`n`t [/in infile.ahk]`n`t [/out outfile.exe]`n`t [/icon iconfile.ico]`n`t [/base AutoHotkeySC.bin]`n`t [/resourceid #1]`n`t [/compress 0 (none), 1 (MPRESS), or 2 (UPX)]`n`t [/cp codepage]`n`t [/silent [verbose]]`n`t [/gui]")
}

CmdArg_Gui() {
	global CLIMode := false, Error_ForceExit := false
}

CmdArg_In(p2) {
	global AhkFile := p2
	if !FileExist(p2)
		BadParams("Error: Source file does not exist.",0x32,"""" p2 """")
	SetCDBin(AhkFile)
}

CmdArg_Out(p2) {
	global StopCDExe := 1, ExeFile := p2
}

CmdArg_Icon(p2) {
	global StopCDIco := 1, IcoFile := p2
	if !FileExist(p2)
		BadParams("Error: Icon file does not exist.",0x35,"""" p2 """")
}

CmdArg_Base(p2) {
	global StopCDBin := 1, BinFile := p2, LastBinFile := Util_GetFullPath(p2), p1
	if !FileExist(p2)
		BadParams("Error: Base file does not exist.",0x34,"""" p2 """")
	AddBin(p2)
}

CmdArg_Bin(p2) {
	CmdArg_Base(p2)
}

CmdArg_ResourceID(p2) {
	global ResourceID := p2, LastResource := StrReplace(LastResource,"||","|")
	LastResource:=p2 "||" Trim(StrReplace("|" LastResource "|","|"p2 "|","|"),"|")
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

CmdArg_Silent(){
	global 
	if (p[1] = "verbose")
	{	SilentMode := 2
		p.RemoveAt(1)
	} else	SilentMode := 1
}

CmdArg_Pass() {
	BadParams("Error: Password protection is not supported.", 0x24)
}

CmdArg_NoDecompile() {
	BadParams("Error: /NoDecompile is not supported.", 0x23)
}

BrowseAhk:
Gui, +OwnDialogs
FileSelectFile, ov, 1, %LastAhkDir%, Open Script, AutoHotkey files (*.ah*)
if ErrorLevel
	return
SplitPath ov,, LastAhkDir
GuiControl,, AhkFile, %ov%
SetCDBin(ov)
menu, FileMenu, Enable, %SaveMes%
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
AddBin(ov)
return

DefaultExe:
ExeFile := "", StopCDExe := 0, Util_Status("")
GuiControl,, ExeFile1, %ExeDfltMes%
return

DefaultIco:
StopCDIco := 0, Util_Status("")
GuiControl,, IcoFile
return

SaveAsMenu:
Gui, +OwnDialogs
Gui, Submit, NoHide
BinFile := BinFiles[BinFileId], SaveAs := "", Util_Status("")
FileSelectFile, SaveAs, S,% RegExReplace(AhkFile,"\.[^.]+$") "_Compile"
 , Save script settings As, *.ahk            ;^ Removes extension
If (SaveAs = "") or ErrorLevel
	Return
SaveAs .= SaveAs ~= "\.ahk$" ? "" : ".ahk"
if FileExist(SaveAs)
{	MsgBox 35,, Append to`n"%SaveAs%"?`n`n(Selecting 'No' overwrites file)
	IfMsgBox Cancel, return
	IfMsgBox No,     FileDelete %SaveAs%
}
if (SubStr(AHKType(BinFile,0).Version,1,1) = 2) ; If v2 Base file, write v2 code
	FileAppend % "RunWait """ A_ScriptFullPath """`n . ' /in ' """ AhkFile """"
	. (ExeFile ? "`n . ' /out ' """ ExeFile """" : "")
	. (IcoFile ? "`n . ' /icon ' """ IcoFile """": "") (ResourceID 
	~="i)^\(default\)$|^\(reset list\)$" ? "" : "`n "
	. ". ' /ResourceID ' """ ResourceID """")
	. "`n . ' /base ' """ BinFile """`n "
	. ". ' /compress " UseMpress-1 "'`n`n", %SaveAs%
else FileAppend % "RunWait """ A_ScriptFullPath """`n /in """ AhkFile """"
	. (ExeFile ? "`n /out """ ExeFile """" : "")
	. (IcoFile ? "`n /icon """ IcoFile """": "") (ResourceID 
	~="i)^\(default\)$|^\(reset list\)$" ? "":"`n /ResourceID """ ResourceID """")
	. "`n /base """ BinFile """`n /compress " UseMpress-1 "`n`n", %SaveAs%
Util_Status(ErrorLevel?"Save script settings failed!":"Saved script settings")
Return

SetCDBin(FileName)
{	SetTimer MonitorFile, Off
	FileNameG := FileName, IsBase := Comment := 0
	Loop Read, %FileName%
	{	if RegExMatch(A_LoopReadLine,"i)^\s*\S{1,2}@Ahk2Exe-(?:Bin|Base) (.*$)")
		&& Comment = 0
		{	IsBase := 1
			if (BinFiles.1 != SBDMes)
			{	BinFiles.InsertAt(1,SBDMes), BinNames := RTrim(SBDMes "|" BinNames, "|")
				GuiControlGet LastIdG,, BinFileId
				GuiControl,,            BinFileId, |%BinNames% 
				GuiControl Choose,      BinFileId, 1
				Util_Status("""" SBDMes """ added to 'Base File' list.")
			}
			break
	}	else if SubStr(LTrim(A_LoopReadLine),1,2) = "/*"      ; Start block comment
			Comment := 1
		if (Comment = 1) && A_LoopReadLine~="^\s*\*/|\*/\s*$" ; End block comment
			Comment := 0
	}
	if (!IsBase && BinFiles.1 = SBDMes)
	{	BinFiles.RemoveAt(1), BinNames := SubStr(BinNames,InStr(BinNames "|","|")+1)
		GuiControl,,       BinFileId, |%BinNames% 
		GuiControl Choose, BinFileId,  %LastIdG%
		Util_Status("""" SBDMes """ removed from 'Base File' list.")
	}                             ; As can't change parameter of BoundFunc Object,
	SetTimer MonitorFile, 400, -1 ;   we are using a global for FileName parameter
	gosub BinChanged
}

MonitorFile()
{	static LastTime := 0, LastSize := 0
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
ConvertCLI()
return

ConvertCLI()
{	local TempWD, ExeFileL
	AhkFile := Util_GetFullPath(AhkFile)
	if AhkFile =
		Util_Error("Error: Source file not specified.", 0x33)
	SplitPath, AhkFile, ScriptName, ScriptDir
	DerefIncludeVars.A_ScriptFullPath := AhkFile
	DerefIncludeVars.A_ScriptName := ScriptName
	DerefIncludeVars.A_ScriptDir := ScriptDir
	TempWD := new CTempWD(A_ScriptDir)
	
	DirDoneG := []                       ; Process Bin directives
	DirBinsWk := [], DirBins := [], DirExe := [], DirCP := [], Cont := 0
	Loop Read, %AhkFile%                 ;v Handle 1-2 unknown comment characters
	{	if (Cont=1&&RegExMatch(A_LoopReadLine,"i)^\s*\S{1,2}@Ahk2Exe-Cont (.*$)",o))
			DirBinsWk[DirBinsWk.MaxIndex()] .= RegExReplace(o1,"\s+;.*$")
			, DirDoneG[A_Index] := 1
		else if (Cont!=2)
		&& RegExMatch(A_LoopReadLine,"i)^\s*\S{1,2}@Ahk2Exe-(?:Bin|Base) (.*$)",o)
			DirBinsWk.Push(RegExReplace(o1,"\s+;.*$")), Cont := 1,DirDoneG[A_Index]:=1
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
					DirBins.Push(A_LoopFileLongPath), DirExe.Push(ExeFile), Cont:=A_Index
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
	if !Util_ObjNotEmpty(DirBins)
		DirExe.1 := ExeFile, DirBins.1 := BinFile
		
	for k in DirBins
		ExeFileL .= """" AhkCompile(AhkFile, DirExe[k], ResourceID, IcoFile
		, DirBins[k], UseMpress, DirCP[k] ? DirCP[k] : ScriptFileCP) """,`n"
	
	if !CLIMode
		Util_Info("Successfully compiled as:`n" RTrim(ExeFileL,",`n"))
	else
		FileAppend,% "Successfully compiled as:`n" RTrim(ExeFileL,",`n") "`n", *
}

LoadSettings:
RegRead, LastAhkDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastAhkDir
RegRead, LastExeDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir
RegRead, LastBinDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastBinDir
RegRead, LastIcoDir,    HKCU, Software\AutoHotkey\Ahk2Exe, LastIcoDir
RegRead, LastIcon,      HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon
RegRead, LastBinFile,   HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile
RegRead, LastResource,  HKCU, Software\AutoHotkey\Ahk2Exe, LastResource
RegRead, LastUseMPRESS, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS
RegRead, LastWidth,     HKCU, Software\AutoHotkey\Ahk2Exe, LastWidth
if !FileExist(LastIcon)
	LastIcon := ""
if (LastBinFile = "") || !FileExist(LastBinFile)
	LastBinFile := BinFiles.1
if (LastResource = "")
	LastResource := "(default)||#1|#2|(reset list)"
if !CompressCode[LastUseMPRESS]                ; Invalid codes := 0
	LastUseMPRESS := false
if CompressCode[LastUseMPRESS] > 0             ; Convert any old codes
	LastUseMPRESS := CompressCode[LastUseMPRESS]
return

SaveAsDefault:
Gui, Submit, NoHide
if (ResourceID = "(reset list)")
	LastResource := "(default)||#1|#2|(reset list)"
else
	wk := ResourceID, LastResource := StrReplace(LastResource,"||","|")
,	LastResource:=wk "||" Trim(StrReplace("|" LastResource "|","|"wk "|","|"),"|")
GuiControl,,ResourceID, |%LastResource%

RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcoDir,    %LastIcoDir%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcon,      %IcoFile%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS,% UseMPRESS-1
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastResource,%LastResource%
RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastWidth,   %LastWidth%
if !(BinFile = SBDMes)
	RegWrite, REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinFile, % BinFiles[BinFileId]
Util_Status("Options saved as default")
return

SaveSettings:
RegRead, wk, HKCU, Software\AutoHotkey\Ahk2Exe, LastUseMPRESS ; Test if present
if !ErrorLevel      ; Only RegWrite if 'save' has occurred sometime in the past
{	RegWrite REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastAhkDir, %LastAhkDir%
	RegWrite REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastExeDir, %LastExeDir%
	RegWrite REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastBinDir, %LastBinDir%
	RegWrite REG_SZ, HKCU, Software\AutoHotkey\Ahk2Exe, LastIcoDir, %LastIcoDir%
}
return

Help(a, b, c, d := 0, e := 0, f := 0, g := 0)
{	static Name, Online
	global BinFileId
	if !a
	{	Name := b, Online := c
		Menu mHelp, Add, Local help,  Help
		Menu mHelp, Add, Online help, Help
		Menu mHelp, Show
	}	else               ;v Try to use latest help version according to version of
	{	v := SubStr(AHKType(BinFiles[BinFileId],0).Version,1,1) ; Base file selected
		if b=1                                              ; 'Local help'
		{	HelpFile := A_ScriptDir "\..\AutoHotkey.chm", HelpTime := 0
			if FileExist( HelpFile) && v=1
				FileGetTime HelpTime, %HelpFile%
			Loop Files, %A_ScriptDir%\..\v%v%*, D
			{	if FileExist(A_LoopFileLongPath "\AutoHotkey.chm") 
				{	FileGetTime wk, %A_LoopFileLongPath%\AutoHotkey.chm
					if (wk > HelpTime)
						HelpTime := wk, HelpFile := A_LoopFileLongPath "\AutoHotkey.chm"
			}	}
			IfNotExist %helpfile%
				Util_Error("Error: cannot find AutoHotkey help file!", 0x52, HelpFile)
			VarSetCapacity(ak, ak_size := 8+5*A_PtrSize+4, 0) ; HH_AKLINK struct
			NumPut(ak_size, ak, 0, "UInt")
			NumPut(&Name, ak, 8)
			DllCall("hhctrl.ocx\HtmlHelp", "ptr", GuiHwnd, "str", HelpFile, "uint"
			, 0x000D, "ptr", &ak) ; 0x000D: HH_KEYWORD_LOOKUP
	}	else if v=1                                         ; 'Online help'
		Run "https://autohotkey.com/docs/%Online%"
	else Run "https://lexikos.github.io/v2/docs/%Online%"
}	}

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

Util_Status(s)       ;v Keep early status for GUI
{ global SilentMode, StaR .= StaR = 0 || s ~= "^Ready|^Warn" ? "" : s "  "
	, StaW := s~="^Warn" ? 1 : StaW
	if SilentMode = 2 ; verbose
		if s not in ,Ready
			FileAppend, Ahk2Exe Status: %s%`n, *
	StaR := s ~= "^Ready|^Warn" || !StaW ? StaR : 0 
	SB_SetText(s = "Ready" && StaR ? StaR : s), StaR := s = "Ready" ? 0 : StaR
}

Util_Error(txt, exitcode, extra := "", extra1 := "", HourGlass := 1)
{
	global CLIMode, Error_ForceExit, ExeFileTmp, SilentMode, AhkFile
	
	if extra
		txt .= "`n`nSpecifically:`n" extra
	
	if extra1
		txt .= "`n`n" extra1
	
	Util_HideHourglass()
	if SilentMode
	{	txt := "Ahk2Exe " txt "`n"
		try FileAppend, %txt%, **
		catch
			FileAppend, %txt%, *
	}	else
	{	if exitcode
			MsgBox, 16, Ahk2Exe Error, % txt
		else
		{	MsgBox, 49, Ahk2Exe Warning, % txt (extra||extra1 ? ""
			 : "`n`nPress 'OK' to continue, or 'Cancel' to abandon.")
			IfMsgBox Cancel
				exitcode := 2
	}	}
	if (exitcode && ExeFileTmp && FileExist(ExeFileTmp))
	{	FileDelete, %ExeFileTmp%
		ExeFileTmp =
	}

	if (CLIMode && exitcode)
	{	try FileAppend, Failed to compile: %AhkFile%`n, **
		catch
			FileAppend, Failed to compile: %AhkFile%`n, *
	}
	Util_Status("Ready")
	
	if exitcode
		if (Error_ForceExit || SilentMode)
			ExitApp, exitcode
		else Exit, exitcode
	If HourGlass
		Util_DisplayHourglass()
}

Update:
Reqs:=[(wk:="AutoHotkey/Ahk2Exe") ",,,Ahk2Exe.exe"
,"https://www.autohotkey.com/mpress/mpress.219.zip,,,Mpress.exe"
,"UPX/UPX," (A_Is64bitOS?"64.zip":"32.zip") ",,Upx.exe", wk ",,2,BinMod.ahk"]
A2D := A_ScriptDir "\", Priv := ""
if !A_IsCompiled                               ; Compile Ahk2Exe to test updates
	RunWait "%A_AhkPath%" "%A_ScriptFullPath%"
		/in "%A_ScriptFullPath%" /base "%A_AhkPath%\..\AutoHotkeyU32.exe"
UpdDirRem(), UpdDir := Util_TempFile(,"Update", "Update")
FileCreateDir %UpdDir%
Gui Upd:Destroy
;Gui Upd:Font, s9, simsun                      ; To test overlapping GUI fields
;Gui Upd:Font, , Segoe UI Variable             ; English default
Gui Upd:+Owner1
Gui Upd:Font, bold
Gui Upd:Add, Text, Center w300, Status of Updates
Gui Upd:Font, norm
Gui Upd:Show, w330 h160, % "  Checking ..."
for k, v in Reqs
{	Reqa := StrSplit(v,","), Text%k%T := ""
	Url := Reqa.4="mpress.exe" ? Reqa.1 : GitHubDwnldUrl(Reqa.1,Reqa.2,Reqa.3)
	if url
	{	URLDownloadToFile %Url%, %UpdDir%\File.zip
		FileCopyDir %UpdDir%\File.zip, %UpdDir%\%k%
		IfNotExist % UpdDir "\" k (wk := "\" Reqa.4)
			Loop Files, %UpdDir%\%k%\*, D
				FileCopy % A_LoopFilePath "\" Reqa.4, %UpdDir%, 1
		else FileCopy  % UpdDir "\" k "\" Reqa.4, %UpdDir%, 1
		if (Reqa.4 ~= "i).ahk$")                   ; Script needs compiling?
			RunWait "%A2D%Ahk2Exe.exe" /in "%UpdDir%%wk%" /base "%A2D%Ahk2Exe.exe"
	}
	VnO := AHKType(RegExReplace(A2D Reqa.4,"i)ahk$","exe"),0).Version
	Text%k%V := VnO := RegExReplace(VnO,"\(.+$") ; Get old version
	VnN := AHKType(RegExReplace(UpdDir "\" Reqa.4,"i)ahk$","exe"),0).Version
	VnN := RegExReplace(VnN, "\(.+$")            ; Get new version
	if VnN
		Text := VnO ? VnN<=VnO ? "  Up-to-date" : "  Update to" : "  Install"
	else Text := "  Offline   "
	Gui Upd:Add, Button,   x17 yp25 h15 vHlp%k%, ?
	GuiControl Upd:+g,   Hlp%k%, % Help%k% 
	Gui Upd:Add, Text,     xp20, % RegExReplace(Reqa.4, "\..+$")
	Gui Upd:Add, Text,     xp50, % VnO
	Gui Upd:Add, Checkbox, xp65 vText%k% Check3 gUpdChk, % Text
	Gui Upd:Add, Text,     xp95, % VnN=VnO ? "" : VnN
	Gui Upd:Show,, % "  Checking " SubStr(" ...", 2-mod(k,2))
}
Gui Upd:Add, Button, % "x120 yp30 w80 h15 vUpd " (Text1||Text2||Text3||Text4
	 ? "" : "Disabled"), % " Update?"
Gui Upd:Show,, Ahk2Exe Updater
FileAppend `n, %A2D%Test.txt
IfNotExist %A2D%Test.txt
	SetTimer UpdTimer, 50
FileDelete %A2D%Test.txt
return

UpdChk:
if !(%A_GuiControl%T)
	GuiControlGet %A_GuiControl%T, Upd:,%A_GuiControl%, Text
GuiControlGet wk, Upd:, %A_GuiControl%
if (wk = 1) && %A_GuiControl%T = "  Up-to-date"
	GuiControl Upd:, %A_GuiControl%, % "  Update"
if (wk = 1) && %A_GuiControl%T = "  Offline   "
	GuiControl Upd:, %A_GuiControl%, % wk := %A_GuiControl%V ? -1 : 0
if (wk = -1)
	if(%A_GuiControl%T = "  Install")
		GuiControl Upd:, %A_GuiControl%, 0
	else GuiControl Upd:, %A_GuiControl%, % "  Delete!"
else if (wk = 0)
	GuiControl Upd:, %A_GuiControl%, % %A_GuiControl%T
Gui Submit, NoHide
GuiControl % Text1||Text2||Text3||Text4 ? "Upd:Enable" : "Upd:Disable", upd
return

UpdGuiClose:
UpdGuiEscape:
Gui Upd:Destroy
UpdDirRem()
return

UpdDirRem()
{	global
	If InStr(FileExist(UpdDir), "D")
		FileRemoveDir %UpdDir%, 1
}

UpdTimer:
IfWinNotExist Ahk2Exe Updater
	return
SetTimer,, Off
Priv := "*RunAs"
SendMessage 0x160c,, 1, Button9, Ahk2Exe Updater  ; BCM_SETSHIELD := 0x160c
return

UpdButtonUpdate?:
Gui Submit, NoHide
FileDelete %UpdDir%\Script*.ahk
DOS = "%A2D%Ahk2Exe.exe" /Script "%UpdDir%\Script1.ahk" &
for k, v in Reqs
{	Req := RegExReplace(StrSplit(v,",").4,"\..+$") ".exe"
	if (Text%k% = 1)
		DOS = %DOS% Move "%UpdDir%\%Req%" "%A2D%%Req%" &
	else if (Text%k% = -1)
	{	Util_Error("Are you sure you want to delete " Req "?", 0,,, 0)
		DOS = %DOS% Del "%A2D%%Req%" && Del "%UpdDir%\%Req%" &
	} else DOS = %DOS% Del "%UpdDir%\%Req%" &
}
DOS = %DOS% "%UpdDir%\A\Ahk2Exe.exe" /Script "%UpdDir%\Script2.ahk" & 
DOS = %DOS% rmdir /s /q %UpdDir%
FileCreateDir %UpdDir%\A\
FileCopy %A2D%Ahk2Exe.exe, %UpdDir%\A\Ahk2Exe.exe
For k, v in A_Args            ; Add quotes to parameters & escape any trailing \
	wk := StrReplace(v,"""","\"""), Par .= """" wk (SubStr(wk,0)="\"?"\":"") """ "
FileAppend,
(
DetectHiddenWindows on
WinKill      ahk_id %A_ScriptHwnd%
WinWaitClose ahk_id %A_ScriptHwnd%,,10
), %UpdDir%\Script1.ahk
FileAppend,
(
Par = %Par%
Loop Files, %UpdDir%\*.exe
txt .= "``n``t" A_LoopFileName
IfNotExist %A2D%Ahk2Exe.exe
	Mess := "``n``nAhk2Exe deleted. To reinstall use the Dash(board)."
if txt
	MsgBox 48, Ahk2Exe Updater, Failed to update:`%txt`%
else MsgBox 64, Ahk2Exe Updater, Update completed successfully. `%Mess`%
IfExist %A2D%Ahk2Exe.exe
	RunAsUser("%A2D%Ahk2Exe.exe", "/Restart " Par, A_WorkingDir)
RunAsUser(target, args:="", workdir:="") {
	try ShellRun(target, args, workdir)
	catch e
		Run `% args="" ? target : target " " args, `% workdir
}
ShellRun(prms*)
{	shellWindows := ComObjCreate("Shell.Application").Windows
	VarSetCapacity(_hwnd, 4, 0)
	desktop := shellWindows.FindWindowSW(0, "", 8, ComObj(0x4003, &_hwnd), 1)
	if ptlb := ComObjQuery(desktop
		, "{4C96BE40-915C-11CF-99D3-00AA004AE837}"  ; SID_STopLevelBrowser
		, "{000214E2-0000-0000-C000-000000000046}") ; IID_IShellBrowser
	{
		if DllCall(NumGet(NumGet(ptlb+0)+15*A_PtrSize),"ptr",ptlb,"ptr*", psv:=0) =0
		{	VarSetCapacity(IID_IDispatch, 16)
			NumPut(0x46000000000000C0, NumPut(0x20400,IID_IDispatch,"int64"), "int64")
			DllCall(NumGet(NumGet(psv+0)+15*A_PtrSize), "ptr", psv
				, "uint", 0, "ptr", &IID_IDispatch, "ptr*", pdisp:=0)
			shell := ComObj(9,pdisp,1).Application
			shell.ShellExecute(prms*)
			ObjRelease(psv)
		}
		ObjRelease(ptlb)
}	}
), %UpdDir%\Script2.ahk
if Priv
	RunWait *RunAs %ComSpec% /c "%DOS%",,Hide
else RunWait %ComSpec% /c "%DOS%",,Hide
return

GitHubDwnldUrl(Repo, Ext := ".zip", Typ := 1)
{	Ext := Typ=2 ? "" : Ext ? Ext : ".zip", Typ := Typ ? Typ : 1
	Req := ComObjCreate("Msxml2.XMLHTTP")
	Req.open("GET", "https://api.github.com/repos/" Repo "/releases/latest", 0)
	try Req.send()
	if (Req.status = 200)
	{	Res := Req.responseText, Type1 := "browser_download", Type2 := "zipball"
;		FileDelete GH.txt
;		FileAppend % Res, GH.txt
		while RegExMatch(Res,"i)""" Type%Typ% "_url"":""")
		{	Res := RegExReplace(Res,"iU)^.+""" Type%Typ% "_url"":""")
			Url := RegExReplace(Res,""".+$")
			if (!Ext || SubStr(url, 1-StrLen(Ext)) = Ext)
				return Url
}	}	}

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
