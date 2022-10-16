goto UpdateEnd                                ; If fall-into, skip
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
	Text%k%N := VnN := RegExReplace(VnN,"\(.+$") ; Get new version
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

UpdGuiClose:
UpdGuiEscape:
Gui Upd:Destroy
UpdDirRem()
return

UpdTimer:
IfWinNotExist Ahk2Exe Updater
	return
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

UpdDirRem()
{	global
	If InStr(FileExist(UpdDir), "D")
		FileRemoveDir %UpdDir%, 1
}

UpdCsv(A2D, Req, UpdDir, Version)
{ IfExist %A2D%..\UX\installed-files.csv
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
DOS = "%A2D%Ahk2Exe.exe" /Script "%UpdDir%\Script1.ahk" &
txt := ""
for k, v in Reqs
{	Req := RegExReplace(StrSplit(v,",").4,"\..+$") ".exe"
	if (Text%k% = 1)
	{	DOS = %DOS% Move "%UpdDir%\%Req%" "%A2D%%Req%" &
		UpdCsv(A2D, Req, UpdDir, Text%k%N)
	} else if (Text%k% = -1)
	{	txt .= "`n`t" Req, UpdCsv(A2D, Req, UpdDir, "Delete")
		DOS = %DOS% Del "%A2D%%Req%" && Del "%UpdDir%\%Req%" &
	} else DOS = %DOS% Del "%UpdDir%\%Req%" &
}
if txt
	Util_Error("Are you sure you want to delete:" txt, 0,,, 0)
DOS = %DOS% "%UpdDir%\A\Ahk2Exe.exe" /Script "%UpdDir%\Script2.ahk" & 
DOS = %DOS% rmdir /s /q %UpdDir%
FileCreateDir %UpdDir%\A\
FileCopy %A2D%Ahk2Exe.exe, %UpdDir%\A\Ahk2Exe.exe
OnExit("UpdDirRem", 0)
For k, v in A_Args            ; Add quotes to parameters & escape any trailing \
	wk := StrReplace(v,"""","\"""), Par .= """" wk (SubStr(wk,0)="\"?"\":"") """ "

FileAppend,
(
#NoTrayIcon`nDetectHiddenWindows on
WinKill      ahk_id %A_ScriptHwnd%`nWinWaitClose ahk_id %A_ScriptHwnd%,,10
), %UpdDir%\Script1.ahk

FileAppend,
(
#NoTrayIcon`nPar = %Par%`nwk := []
Loop Files, %UpdDir%\*.exe
	txt .= "``n``t" A_LoopFileName, fail .= (fail ? "|" : "") A_LoopFileName
IfExist %UpdDir%\Script3c.csv
{	Loop Read, %A2D%..\UX\installed-files.csv
	{	if (A_Index = 1)
		{	hdr := A_LoopReadLine
			for k, v in StrSplit(Hdr,",")
				if (v = "path")
					break
		}	else wk[StrSplit(A_LoopReadLine,",")[k]] := A_LoopReadLine
	}
	Loop Read, %UpdDir%\Script3c.csv
		if !(fail && A_LoopReadLine ~= "i)(" StrReplace(fail,".","\.") ")""")
			if StrSplit(A_LoopReadLine,"|").2 = "Delete"
				wk.Delete(StrSplit(A_LoopReadLine,"|").1)
			else wk[StrSplit(A_LoopReadLine,"|").1] := StrSplit(A_LoopReadLine,"|").2
	FileDelete             %A2D%..\UX\installed-files.csv
	FileAppend `%hdr`%``n, %A2D%..\UX\installed-files.csv
	for k, v in wk
		FileAppend `%v`%``n, %A2D%..\UX\installed-files.csv
}
IfNotExist %A2D%Ahk2Exe.exe
	Mess := "``n``nAhk2Exe deleted. To reinstall:``n v1 - run the AHK installer
	,``n v2 - press 'Windows/Start', find & run 'AutoHotkey', select 'Compile'."
if txt
	MsgBox 48, Ahk2Exe Updater, Failed to update:`%txt`%``n`%Mess`%
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
), %UpdDir%\Script2.ahk

if Priv
	RunWait *RunAs "%ComSpec%" /c "%DOS%",, Hide UseErrorLevel
else RunWait     "%ComSpec%" /c "%DOS%",, Hide UseErrorLevel
MsgBox 48, Ahk2Exe Updater, Update abandoned.
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
UpdateEnd:
