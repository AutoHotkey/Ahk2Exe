;
; File encoding:  UTF-8 with BOM
;
#Include ScriptParser.ahk
#Include IconChanger.ahk
#Include Directives.ahk

AhkCompile(ByRef AhkFile, ExeFile="", ByRef CustomIcon="", BinFile="", UseMPRESS="", fileCP="")
{
	global ExeFileTmp, ExeFileG, SilentMode, ForceReload

	SetWorkingDir %AhkWorkingDir%
	SplitPath AhkFile,, Ahk_Dir,, Ahk_Name
	SplitPath ExeFile,, Edir,,    Ename
	ExeFile := (Edir ? Edir : Ahk_Dir) "\" (xe:= Ename ? Ename : Ahk_Name ) ".exe"
	ExeFile := Util_GetFullPath(ExeFile)
	if (CustomIcon != "")
	{	SplitPath CustomIcon,, Idir,, Iname
		CustomIcon := (Idir ? Idir : Ahk_Dir) "\" (Iname ? Iname : Ahk_Name ) ".ico"
		CustomIcon := Util_GetFullPath(CustomIcon)
	}
	SetWorkingDir %Ahk_Dir%             ; Initial folder for any #Include's

	; Get temp file name - remove any invalid "path/" from exe name (/ should be \)
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
	ResourceId := SubStr(BinFile, -3) = ".exe" ? "#1" : ">AUTOHOTKEY SCRIPT<"

	ExeFileG := ExeFile
	BundleAhkScript(ExeFileTmp, ResourceId, AhkFile, UseMPRESS, CustomIcon, fileCP)
	
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
		else {	
			if ForceReload {
				WinGet, ExePid, PID, ahk_exe %ExeFileG%
				Process, Close, %ExePid%
				Process, WaitClose, %ExePid%, 1
			}else {
				wk := """" RegExReplace(ExeFileG, "^.+\\") """"
				if SilentMode {
					Util_Error(wk " is still running, "
					.  "and needs to be unloaded to allow replacement with this new version."
					. "`nPass /ForceReload to always reload when compiling.", 0x45)
				} else {
					SetTimer Buttons, 50
					MsgBox 51,Ahk2Exe Query,% "Warning: " wk " is still running, "
					.  "and needs to be unloaded to allow replacement with this new version."
					. "`n`n Press the appropriate button to continue."
					. " ('Reload' unloads and reloads the new " wk " without any parameters.)"
					IfMsgBox Cancel
						Util_Error("Error: Could not move final compiled binary file to "
						. "destination. (C2)", 0x45, """" ExeFileG """")
					WinClose     ahk_exe %ExeFileG%
					WinWaitClose ahk_exe %ExeFileG%,,1
					IfMsgBox No
						Reload := 1
				}
			}
		}	
	}
	if ForceReload || Reload
		Run "%ExeFileG%", %ExeFileG%\..
	Util_HideHourglass()
	Util_Status("")
	Return ExeFileG
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

BundleAhkScript(ExeFile, ResourceId, AhkFile, UseMPRESS, IcoFile, fileCP)
{
	if fileCP is space
		if SubStr(DerefIncludeVars.A_AhkVersion,1,1) = 2
			fileCP := "UTF-8"           ; Default for v2 is UTF-8
		else fileCP := A_FileEncoding
	
	try FileEncoding, %fileCP%
	catch e
		Util_Error("Invalid codepage parameter """ fileCP """ was given.", 0x53)
	
	SplitPath, AhkFile,, ScriptDir

	ExtraFiles := []
	Directives := PreprocessScript(ScriptBody, AhkFile, ExtraFiles)

	VarSetCapacity(BinScriptBody, BinScriptBody_Len := StrPut(ScriptBody, "UTF-8") - 1)
	StrPut(ScriptBody, &BinScriptBody, "UTF-8")
	
	module := DllCall("BeginUpdateResource", "str", ExeFile, "uint", 0, "ptr")
	if !module
		Util_Error("Error opening the destination file. (C1)", 0x31)
	
	SetWorkingDir % ScriptDir

	DerefIncludeVars.A_WorkFileName := ExeFile
	dirState := ProcessDirectives(ExeFile, module, Directives, IcoFile)
	IcoFile := dirState.IcoFile
	
	if outPreproc := dirState.OutPreproc
	{
		f := FileOpen(outPreproc, "w", "UTF-8-RAW")
		f.RawWrite(BinScriptBody, BinScriptBody_Len)
		f := ""
	}
	
	Util_Status("Adding: Master Script")
	if !DllCall("UpdateResource", "ptr", module, "ptr", 10
			, "ptr", ResourceId ~= "^#\d+$" ? SubStr(ResourceId, 2) : &ResourceId
			, "ushort", 0x409, "ptr", &BinScriptBody, "uint", BinScriptBody_Len, "uint")
		goto _FailEnd
		
	for each,file in ExtraFiles
	{
		Util_Status("Adding: " file)
		StringUpper, resname, file
		
		IfNotExist, %file%
			goto _FailEnd2
		
		; This "old-school" method of reading binary files is way faster than using file objects.
		FileGetSize, filesize, %file%
		VarSetCapacity(filedata, filesize)
		FileRead, filedata, *c %file%
		if !DllCall("UpdateResource", "ptr", module, "ptr", 10, "str", resname
				  , "ushort", 0x409, "ptr", &filedata, "uint", filesize, "uint")
			goto _FailEnd2
		VarSetCapacity(filedata, 0)
	}
	
	gosub _EndUpdateResource
	
	if dirState.ConsoleApp
	{
		Util_Status("Marking executable as a console application...")
		if !SetExeSubsystem(ExeFile, 3)
			Util_Error("Could not change executable subsystem!", 0x61)
	}
	SetWorkingDir %A_ScriptDir%
	
	RunPostExec(dirState)
	
	for k,v in [{MPRESS:"-x"},{UPX:"--all-methods --compress-icons=0"}][UseMPRESS]
	{	Util_Status("Compressing final executable with " k " ...")
		if FileExist(wk := A_ScriptDir "\" k ".exe")
			RunWait % """" wk """ -q " v " """ ExeFile """",, Hide
		else Util_Error("""" wk """ not found.`n`n'Compress exe with " k
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
	if !DllCall("EndUpdateResource", "ptr", module, "uint", 0)
	{	Util_Error("Error opening the destination file. (C2)", 0
		,,"This error may be caused by your anti-virus checker.`n"
		. "Press 'OK' to try again, or 'Cancel' to abandon.")
		goto _EndUpdateResource
	}
	return
}
; -------------------------- End of BundleAhkScript ----------------------------

class CTempWD
{
	__New(newWD)
	{
		this.oldWD := A_WorkingDir
		SetWorkingDir % newWD
	}
	__Delete()
	{
		SetWorkingDir % this.oldWD
	}
}

RunPostExec(dirState, UseMPRESS := "")
{	for k, v in dirState["PostExec" UseMPRESS]
	{	Util_Status("PostExec" UseMPRESS ": " v.1)
		RunWait % v.1, % v.2 ? v.2 : A_ScriptDir, % "UseErrorLevel " (v.3?"Hide":"")
		if (ErrorLevel != 0 && !v.4)
			Util_Error("Command failed with RC=" ErrorLevel ":`n" v.1, 0x62)
}	}

Util_GetFullPath(path)
{
	VarSetCapacity(fullpath, 260 * (!!A_IsUnicode + 1))
	return DllCall("GetFullPathName", "str", path, "uint", 260, "str", fullpath, "ptr", 0, "uint") ? fullpath : ""
}
