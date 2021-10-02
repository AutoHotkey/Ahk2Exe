;
; File encoding:  UTF-8 with BOM
;
#Include ScriptParser.ahk
#Include IconChanger.ahk
#Include Directives.ahk

AhkCompile(AhkFile, ExeFile, ResourceID, CustomIcon, BinFile, UseMPRESS, fileCP)
{
	global ExeFileTmp, ExeFileG, SilentMode

	tempWD := new CTempWD(AhkWorkingDir)   ; Original Ahk2Exe starting directory
	SplitPath AhkFile,, Ahk_Dir,, Ahk_Name
	SplitPath ExeFile,, Edir,,    Ename
	ExeFile := (Edir ? Edir : Ahk_Dir) "\" (xe:= Ename ? Ename : Ahk_Name ) ".exe"
	ExeFile := Util_GetFullPath(ExeFile)
	if (CustomIcon != "")
	{	SplitPath CustomIcon,, Idir,, Iname
		CustomIcon := (Idir ? Idir : Ahk_Dir) "\" (Iname ? Iname : Ahk_Name ) ".ico"
		CustomIcon := Util_GetFullPath(CustomIcon)
	}
	; Get temp file name. Remove any invalid "path/" from exe name (/ should be \)
	ExeFileTmp := Util_TempFile(, "exe~", RegExReplace(xe,"^.*/"))
	
	if BinFile =
		BinFile = %A_ScriptDir%\AutoHotkeySC.bin
	
	Util_DisplayHourglass()
	
	IfNotExist, %BinFile%
		Util_Error("Error: The selected Base file does not exist. (C1)"
		, 0x34, """" BinFile """")
	
	try FileCopy, %BinFile%, %ExeFileTmp%, 1
	catch
		Util_Error("Error: Unable to copy Base file to destination."
		, 0x41, """" ExeFileTmp """")

	DerefIncludeVars.Delete("U_", "V_")         ; Clear Directives entries
	DerefIncludeVars.Delete("A_WorkFileName")
	DerefIncludeVars.Delete("A_PriorLine")

	BinType := AHKType(ExeFileTmp)
	DerefIncludeVars.A_AhkVersion := BinType.Version
	DerefIncludeVars.A_PtrSize := BinType.PtrSize
	DerefIncludeVars.A_IsUnicode := BinType.IsUnicode

	global AhkPath := UseAhkPath         ; = any /ahk parameter
	
	; V2 alphas and betas expected to match as breaking changes between versions
	if (AhkPath="") ; Later v2 versions will have base as .exe, and so must match
		if !(AhkPath:=ExeFiles[BinType.Version BinType.Summary]) ;Match .exe to base
			if SubStr(BinType.Version, 1, 1) = 1
				for k, v in ExeFiles ; If not exact v1 match, use highest v1 AHK version
					if SubStr(k, 1, 1) = 1
						AhkPath := v

	IfNotExist, %AhkPath%
		Util_Error("Warning: AutoHotkey could not be located!`n`nAuto-includes "
. "from Function Libraries and any 'Obey' directives will not be processed.",0)

global StdLibDir := Util_GetFullPath(AhkPath "\..\Lib")

	; v1.1.34 supports compiling with EXE, but in that case uses resource ID 1.
	ResourceID := SubStr(BinFile, -3)=".exe" ? ResourceID ? ResourceID : "#1" 
	: ">AUTOHOTKEY SCRIPT<"

	ExeFileG := ExeFile
	BundleAhkScript(ExeFileTmp, ResourceID, AhkFile, UseMPRESS, CustomIcon, fileCP, BinFile)
	
	; the final step...
	Util_Status("Moving .exe to destination")

	Loop
	{	FileMove, %ExeFileTmp%, %ExeFileG%, 1
		if !ErrorLevel
			break
		Util_HideHourglass()
		DetectHiddenWindows On
		if !WinExist("ahk_exe " ExeFileG)
			Util_Error("Error: Could not move final compiled binary file to "
			. "destination. (C1)", 0x45, """" ExeFileG """")
		else	
		{	wk := """" RegExReplace(ExeFileG, "^.+\\") """"
			if SilentMode
				Util_Error(wk " is still running, and needs "
				.  "to be unloaded to allow replacement with this new version.", 0x45)
			else
			{	SetTimer Buttons, 50
				MsgBox 51,Ahk2Exe Query,% "Warning: " wk " is still running, and needs "
				.  "to be unloaded to allow replacement with this new version."
				. "`n`n Press the appropriate button to continue. ('Reload' unloads "
				. "and reloads the new " wk " without any parameters.)"
				IfMsgBox Cancel
					Util_Error("Error: Could not move final compiled binary file to "
					. "destination. (C2)", 0x45, """" ExeFileG """")
				WinClose     ahk_exe %ExeFileG%
				WinWaitClose ahk_exe %ExeFileG%,,1
				IfMsgBox No
					Reload := 1
	}	}	}
	if Reload
		run "%ExeFileG%", %ExeFileG%\..
	Util_HideHourglass()
	Util_Status("")
	return ExeFileG
}
; ---------------------------- End of AHKCompile -------------------------------

Buttons()
{	IfWinNotExist Ahk2Exe Query
		return
	SetTimer,, Off
	WinActivate
	ControlSetText Button1, &Unload
	ControlSetText Button2, && &Reload
}

BundleAhkScript(ExeFile, ResourceID, AhkFile, UseMPRESS, IcoFile,fileCP,BinFile)
{
	if fileCP is space
		if SubStr(DerefIncludeVars.A_AhkVersion,1,1) = 2
			fileCP := "UTF-8"           ; Default for v2 is UTF-8
		else fileCP := A_FileEncoding
	
	try FileEncoding, %fileCP%
	catch e
		Util_Error("Error: Invalid codepage parameter """ fileCP """ was given.", 0x53)
	
	PreprocessScript(ScriptBody, AhkFile, Directives := [], PriorLines := [])

	VarSetCapacity(BinScriptBody, BinScriptBody_Len:=StrPut(ScriptBody,"UTF-8")-1)
	StrPut(ScriptBody, &BinScriptBody, "UTF-8")
	
	Module := DllCall("BeginUpdateResource", "str", ExeFile, "uint", 0, "ptr")
	if !Module
		Util_Error("Error: Error opening the destination file. (C1)", 0x31)

	if BinFile ~= "i)\\Ahk2Exe.exe$" ;If base is self, oust Ahk2Exe logo from .exe
		DllCall("UpdateResource", "ptr", Module, "ptr", 10
		, "str", "LOGO.PNG", "ushort", 0x409, "ptr", 0, "uint", 0, "uint")

	SetWorkingDir %AhkFile%\..       ; For FileInstall, etc
	DerefIncludeVars.A_WorkFileName := ExeFile
	dirState := ProcessDirectives(ExeFile, Module, Directives, PriorLines,IcoFile)

	Util_Status("Adding: Master Script")
	ResourceID := Format("{:U}", ResourceID ~= "i)^\(default\)$|^\(reset list\)$"
		? dirState.ResourceID = "" ? "#1" : dirState.ResourceID : ResourceID)

	if !DllCall("UpdateResource", "ptr", Module, "ptr", 10
			, "ptr", ResourceID ~= "^#\d+$" ? SubStr(ResourceID, 2) : &ResourceID
			, "ushort",0x409, "ptr",&BinScriptBody, "uint",BinScriptBody_Len, "uint")
		goto _FailEnd
		
	gosub _EndUpdateResource
	
	if dirState.ConsoleApp
	{
		Util_Status("Marking executable as a console application...")
		if !SetExeSubsystem(ExeFile, 3)
			Util_Error("Could not change executable subsystem!", 0x61)
	}
	SetWorkingDir %A_ScriptDir%      ; For BinMod, etc
	
	RunPostExec(dirState)
	
	for k,v in [{MPRESS:"-x"},{UPX:"--all-methods --compress-icons=0"}][UseMPRESS]
	{	Util_Status("Compressing final executable with " k " ...")
		if FileExist(wk := A_ScriptDir "\" k ".exe")
			RunWait % """" wk """ -q " v " """ ExeFile """",, Hide
		else Util_Error("Warning: """ wk """ not found.`n`n'Compress exe with " k
			. "' specified, but freeware " k ".EXE is not in compiler directory.",0)
			, UseMPRESS := 9
	}
	RunPostExec(dirState, UseMPRESS)
	
	return                             ; BundleAhkScript() exits here
	
_FailEnd:
	gosub _EndUpdateResource
	Util_Error("Error adding script file:`n`n" AhkFile, 0x43)
	
_FailEnd2:
	gosub _EndUpdateResource
	Util_Error("Error adding FileInstall file:`n`n" file, 0x44)
	
_EndUpdateResource:
	if !DllCall("EndUpdateResource", "ptr", Module, "uint", 0)
	{	Util_Error("Error: Error opening the destination file. (C2)", 0
		,,"This error may be caused by your anti-virus checker.`n"
		. "Press 'OK' to try again, or 'Cancel' to abandon.")
		goto _EndUpdateResource
	}
	return
}
; -------------------------- End of BundleAhkScript ----------------------------

class CTempWD
{	__New(newWD)
	{	this.oldWD := A_WorkingDir
		SetWorkingDir % newWD
	}
	__Delete()
	{	SetWorkingDir % this.oldWD
}	}

RunPostExec(dirState, UseMPRESS := "")
{	for k, v in dirState["PostExec" UseMPRESS]
	{	Util_Status("PostExec" UseMPRESS ": " v.1)
		RunWait % v.1, % v.2 ? v.2 : A_ScriptDir, % "UseErrorLevel " (v.3?"Hide":"")
		if (ErrorLevel != 0 && !v.4)
			Util_Error("Command failed with RC=" ErrorLevel ":`n" v.1, 0x62)
}	}

Util_GetFullPath(path)
{	Size := DllCall("GetFullPathName", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint")
	VarSetCapacity(fullpath, size << !!A_IsUnicode)
	fullpathR := DllCall("GetFullPathName", "str", path, "uint", size, "str", fullpath, "ptr", 0, "uint") ? fullpath : ""
	return fullpathR
}
