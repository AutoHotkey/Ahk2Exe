goto UpdateEnd                                ; If fall-into, skip to near end
Update:
Reqs:=[(wk:="AutoHotkey/Ahk2Exe") ",,,Ahk2Exe.exe"
,"https://www.autohotkey.com/mpress/mpress.219.zip,,,Mpress.exe"
,"UPX/UPX," (A_Is64bitOS?"64.zip":"32.zip") ",,Upx.exe", wk ",,2,BinMod.ahk"]
A2D := A_ScriptDir "\"
if !A_IsCompiled                               ; Compile Ahk2Exe to test updates
	RunWait "%A_AhkPath%" "%A_ScriptFullPath%" /compress 0
		/in "%A_ScriptFullPath%" /base "%A_AhkPath%\..\AutoHotkeyU32.exe"
UpdGui:=1, Priv:="", UpdDirRem(), UpdDir := Util_TempFile(,"Update", "Update")
FileCreateDir %UpdDir%
Gui Upd:Destroy
;Gui Upd:Font, s9, simsun                      ; To test overlapping GUI fields
;Gui Upd:Font, , Segoe UI Variable             ; English default
Gui Upd:+Owner1
Gui Upd:Font, bold
Gui Upd:Add, Text, Center w300, Status of Updates
Gui Upd:Font, norm
Gui Upd:Show, w350 h160, % "  Checking ..."
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
			/compress 0
	}
	IfEqual UpdGui, 0, break
	VnO := AHKType(RegExReplace(A2D Reqa.4,"i)ahk$","exe"),0).Version
	Text%k%V := VnO := RegExReplace(VnO,"\(.+$") ; Get old version
	VnN := AHKType(RegExReplace(UpdDir "\" Reqa.4,"i)ahk$","exe"),0).Version
	Text%k%N := VnN := RegExReplace(VnN,"\(.+$") ; Get new version
	if VnN
		Text := VnO ? VnN<=VnO ? "  Up-to-date" : "  Update to" : "  Install"
	else Text := "  Offline   "
	Gui Upd:Add, Button,   x17 yp25 h15 vHlp%k%, ?
	GuiControl Upd:+g,   Hlp%k%, % Help%k% 
	Gui Upd:Add, Text,     xp20, % RegExReplace(Reqa.4, "\..+$")
	Gui Upd:Add, Text,     xp50, % VnO
	Gui Upd:Add, Checkbox, xp75 vText%k% Check3 gUpdChk, % Text
	Gui Upd:Add, Text,     xp105,% VnN=VnO ? "" : VnN
	Gui Upd:Show,, % "  Checking " SubStr("    ...", 5-k)
}
if UpdGui
{	Gui Upd:Add, Button, % "x120 yp30 w80 h15 vUpd " (Text1||Text2||Text3||Text4
		 ? "" : "Disabled"), % " Update?"
	Gui Upd:Show,, Ahk2Exe Updater
	FileAppend `n, %A2D%Test.txt
	IfNotExist %A2D%Test.txt, SetTimer UpdTimer, 50
	FileDelete %A2D%Test.txt
} else Gui Upd:Destroy
return

UpdTimer:
IfWinNotExist Ahk2Exe Updater,, return
SetTimer,, Off
Priv := "*RunAs"
SendMessage 0x160c,, 1, Button9, Ahk2Exe Updater  ; BCM_SETSHIELD := 0x160c
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

GetCsv(A2D, Req, UpdDir, Version)
{	If FileExist(A2D "..\UX\installed-files.csv") && !Store
	{ path := """Compiler\" Req """"
		if (Version != "Delete")
		{	FileReadLine wk, %A2D%\..\UX\installed-files.csv, 1
			wk := StrSplit(wk, ",")
			FileDelete %UpdDir%\Script3.*
			FileAppend,                                        ; V2 code
			(
			#NoTrayIcon`n#Include "%A2D%..\UX\inc\hashfile.ahk"
			FileAppend hashfile("%UpdDir%\%Req%"), "%UpdDir%\Script3.hsh"
			), %UpdDir%\Script3.ahk
			RunWait "%A2D%..\UX\AutoHotkeyUX.exe" "%UpdDir%\Script3.ahk"
			FileRead hash, %UpdDir%\Script3.hsh
			for k, v in wk
				txt .= txt ? "," %v% : %v%
			FileAppend      %path%|%txt%`n,  %UpdDir%\Script3c.csv
		} else FileAppend	%path%|Delete`n, %UpdDir%\Script3c.csv
}	}

UpdButtonUpdate?:
Gui Submit, NoHide
FileDelete %UpdDir%\Script*.*
wk=#Requires AutoHotkey v1.1`nToolTip Ahk2Exe Updater``nRunning...`nTgt=%A2D%`n
wk=%wk%Srx=%UpdDir%`nStore=%Store%`n#NoTrayIcon`nDetectHiddenWindows on`n
wk=%wk%Src:=SubStr(Srx,1,-1) "x"`nFileMoveDir `%Srx`%`,`%Src`%`,r`n
wk=%wk%WinKill ahk_id %A_ScriptHwnd%`nWinWaitClose ahk_id %A_ScriptHwnd%`,`,10`n
FileAppend %wk%, %UpdDir%\Script1.ahk
txt := ""
for k, v in Reqs
{	Req := RegExReplace(StrSplit(v,",").4,"\..+$") ".exe"
	if (Text%k% = 1)
	{	wk=FileDelete `%Tgt`%%Req%`nFileCopy `%Src`%\%Req%`,`%Tgt`%%Req%
	,1`nif A_LastError=0`nFileDelete `%Src`%\%Req%`nelse MsgBox A_LastError
	= %A_LastError%``n``nFileCopy `%Src`%\%Req%`,`%Tgt`%%Req%
		GetCsv(A2D, Req, UpdDir, Text%k%N)
	} else if (Text%k% = -1)
	{	txt .= "`n`t" Req, GetCsv(A2D, Req, UpdDir, "Delete")
		wk=FileDelete `%Tgt`%%Req%`nif A_LastError=0`nFileDelete `%Src`%\%Req%
	} else wk=FileDelete `%Src`%\%Req%
	FileAppend %wk%`n, %UpdDir%\Script1.ahk
} 
if txt
	Util_Error("Are you sure you want to delete:" txt, 0,,, 0)
FileCreateDir %UpdDir%\A\
FileCopy %A2D%Ahk2Exe.exe, %UpdDir%\A\Ahk2Exe.exe
For k, v in A_Args            ; Add quotes to parameters & escape any trailing \
	wk := StrReplace(v,"""","\"""), Par .= """" wk (SubStr(wk,0)="\"?"\":"") """ "


FileAppend,
(
Par = %Par%`nwk := []
Loop Files, `%Src`%\*.exe
	txt .= "``n``t" A_LoopFileName, fail .= (fail ? "|" : "") A_LoopFileName
IfExist `%Src`%\Script3c.csv
{	Loop Read, `%Tgt`%..\UX\installed-files.csv
	{	if (A_Index = 1)
		{	hdr := A_LoopReadLine
			for k, v in StrSplit(Hdr,",")
				if (v = "path")
					break
		}	else wk[StrSplit(A_LoopReadLine,",")[k]] := A_LoopReadLine
	}
	Loop Read, `%Src`%\Script3c.csv
		if !(fail && A_LoopReadLine ~= "i)(" StrReplace(fail,".","\.") ")""")
			if StrSplit(A_LoopReadLine,"|").2 = "Delete"
				wk.Delete(StrSplit(A_LoopReadLine,"|").1)
			else wk[StrSplit(A_LoopReadLine,"|").1] := StrSplit(A_LoopReadLine,"|").2
	FileDelete             `%Tgt`%..\UX\installed-files.csv
	FileAppend `%hdr`%``n, `%Tgt`%..\UX\installed-files.csv
	for k, v in wk
		FileAppend `%v`%``n, `%Tgt`%..\UX\installed-files.csv
}
ToolTip
IfNotExist `%Tgt`%Ahk2Exe.exe
	Mess:="``n``nAhk2Exe deleted. To reinstall:``n``n v1 - Run the AHK installer."
. "``n v2 - Press 'Windows/Start', find & run AutoHotkey Dash => Compile.``n"
. " Microsoft Store version - Uninstall and reinstall the package."
if txt`n	MsgBox 48, Ahk2Exe Updater, Failed to update:`%txt`%``n`%Mess`%
else MsgBox 64, Ahk2Exe Updater, Update completed successfully. `%Mess`%
wk=#NoTrayIcon``nDetectHiddenWindows on``nWinKill ahk_id `%A_ScriptHwnd`%``n
wk=`%wk`%WinWaitClose ahk_id `%A_ScriptHwnd`%,,10``n
FileAppend `%wk`%, `%Src`%\Script2.ahk
If FileExist(wk := Tgt "Ahk2Exe.exe")
{	ToolTip Ahk2Exe Updater``nRestarting Ahk2Exe...
	if (Store)`n  Run "`%wk`%" /restart `%Par`%, A_WorkingDir
	else       RunAsUser(wk,  "/Restart " Par,   A_WorkingDir)
}
if !(Store)
{	txt = "`%Src`%\A\Ahk2Exe.exe" /Script "`%Src`%\Script2.ahk" &  
	RunWait "%ComSpec%" /c "`%txt`% rmdir /s /q "`%Src`%"",, Hide
} else FileRemoveDir `%Src`%,1

RunAsUser(target, args:="", workdir:="")
{	try ShellRun(target, args, workdir)
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
	{	if DllCall(NumGet(NumGet(ptlb+0)+15*A_PtrSize),"ptr",ptlb,"ptr*", psv:=0) =0
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
), %UpdDir%\Script1.ahk


if !(Store)
{	if Priv
		RunWait *RunAs "%UpdDir%\A\Ahk2Exe.exe" /Script "%UpdDir%\Script1.ahk"
		,,Hide UseErrorLevel
	else	RunWait    "%UpdDir%\A\Ahk2Exe.exe" /Script "%UpdDir%\Script1.ahk"
		,,Hide UseErrorLevel
	MsgBox 48, Ahk2Exe Updater, Update abandoned.
}	else if !(Priv)
		RunWait "%UpdDir%\Script1.ahk",,Hide UseErrorLevel
	else MsgBox 48, Ahk2Exe Updater, This MS Store app can't be updated this way.
return

GitHubDwnldUrl(Repo, Ext := ".zip", Typ := 1)
{	Ext := Typ=2 ? "" : Ext ? Ext : ".zip", Typ := Typ ? Typ : 1
	Req := ComObjCreate("Msxml2.XMLHTTP")
	Req.open("GET", "https://api.github.com/repos/" Repo "/releases/latest", 0)
	try Req.send()
	if (Req.status = 200)
	{	Res := Req.responseText, Type1 := "browser_download", Type2 := "zipball"
		while RegExMatch(Res,"i)""" Type%Typ% "_url"":""")
		{	Res := RegExReplace(Res,"iU)^.+""" Type%Typ% "_url"":""")
			Url := RegExReplace(Res,""".+$")
			if (!Ext || SubStr(url, 1-StrLen(Ext)) = Ext)
				return Url
}	}	}

UpdDirRem()
{	global
	If InStr(FileExist(UpdDir), "D")
		FileRemoveDir %UpdDir%, 1
}

HelpU(a)
{	Run "https://www.autohotkey.com/boards/viewtopic.php?f=6&t=65095"
}

UpdGuiClose:
UpdGuiEscape:
Gui Upd:Destroy
UpdDirRem(), UpdGui := 0
Exit

UpdateEnd:
Help0 := Func("Help").Bind(0,"Ahk2Exe", "Scripts.htm#ahk2exe") ; Help topics
Help1 := Func("HelpU").Bind(0)            ; All initialised at beginning
Help2 := Func("Help").Bind(0,"Compression", "Scripts.htm#mpress")
Help3 := Func("Help").Bind(0,"Compression", "Scripts.htm#mpress")
Help4 := Func("Help").Bind(0,"PostExec directive (Ahk2Exe)"
	,"misc/Ahk2ExeDirectives.htm#PostExec")
