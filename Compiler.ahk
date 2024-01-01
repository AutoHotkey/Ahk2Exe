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
	if BinFile =
	{	BinFile = %A_ScriptDir%\AutoHotkeySC.bin
		IfNotExist %BinFile%
			Util_Error("Error: No default Base file specified.`n`nIn the Ahk2Exe "
			. "GUI, select the default Base file to be used and press 'Save'.",0x34)
	}
	
	Util_DisplayHourglass()
	
	IfNotExist, %BinFile%
		Util_Error("Error: The selected Base file does not exist. (C1)"
		, 0x34, """" BinFile """")
	
	; Get temp file name. Remove any invalid "path/" from exe name (/ should be \)
	ExeFileTmp := Util_TempFile(, "exe~", RegExReplace(xe,"^.*/"))
	FileCopy, %BinFile%, %ExeFileTmp%, 1
	if (A_LastError)
		Util_Error("Error: Unable to copy Base file to destination. (C1)"
		, 0x41, """" ExeFileTmp """", "Error = " A_LastError)

	DerefIncludeVars.Delete("U_", "V_")         ; Clear Directives entries
	DerefIncludeVars.Delete("A_WorkFileName")
	DerefIncludeVars.Delete("A_PriorLine")

	BinType := AHKType(ExeFileTmp) ; Check that U32 .exe Base is used for Ahk2Exe
	if AhkFile~="i)\\Ahk2Exe.ahk$" &&(BinType.Summary!="U32" ||BinFile~="i).bin$")
		Util_Error("Ahk2Exe must be compiled with a Unicode 32-bit .exe Base file."
		, 0x2)

	DerefIncludeVars.A_AhkVersion := BinType.Version
	DerefIncludeVars.A_PtrSize    := BinType.PtrSize
	DerefIncludeVars.A_IsUnicode  := BinType.IsUnicode
	DerefIncludeVars.A_BasePath   := BinFile

	global AhkPath := UseAhkPath         ; = any /ahk parameter
	
	; V2 alphas and betas expected to match as breaking changes between versions
	if (AhkPath = "") ; Later v2 versions will have base as .exe, so should match
		if !(AhkPath := ExeFiles[BinType.Version BinType.Summary]) ; .exe vs base?
			for k, v in ExeFiles         ; If not exact match, use highest AHK version
				if SubStr(k, 1, 1) = SubStr(BinType.Version, 1, 1)
					AhkPath := v

	IfExist % wk := RegExReplace(AhkPath,"i)64.exe$", "32.exe")
		AhkPath := A_Is64bitOS ? AhkPath : wk ; 32-bit Windows can make 64-bit exe's
	
	IfNotExist, %AhkPath%
		Util_Error("Warning: AutoHotkey could not be located!`n`nAuto-includes "
. "from Function Libraries and any 'Obey' directives will not be processed.",0)

	global StdLibDir := Util_GetFullPath(AhkPath "\..\Lib")

	; v1.1.34 supports compiling with EXE, but in that case uses resource ID 1.
	ResourceID := SubStr(BinFile, -3)=".exe" ? ResourceID ? ResourceID : "#1" 
	: ">AUTOHOTKEY SCRIPT<"

	if (BinType.Description ~= "^AutoHotkey"  ; If an AutoHotkey .exe Base used,
	&& ResourceID ~= "i)^(#1|\(default\)|\(reset list\))$") ; with these IDs
		VerInfo := {FileDescription:0, CompanyName:0
		, ProductName:0, InternalName:0, LegalCopyright:0, OriginalFilename:0}
	else VerInfo := {}                        ; Version items to optionally remove

	ExeFileG := ExeFile
	BundleAhkScript(ExeFileTmp, ResourceID, AhkFile, UseMPRESS, CustomIcon
		, fileCP, BinFile, VerInfo)
	
	; the final step...
	Util_Status("Moving .exe to destination")

	Loop
	{	try                    ;v FileMove, but avoids copying permissions from temp
		{	FileCopy   %ExeFileTmp%, %ExeFileG%, 1
			FileDelete %ExeFileTmp%
			break
		}
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
			{	Buttons1 := Func("Buttons").Bind("&Unload", "&& &Reload")
				SetTimer % Buttons1, 50
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

BundleAhkScript(ExeFile, ResourceID, AhkFile, UseMPRESS, IcoFile
	, fileCP, BinFile, VerInfo)
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
	,	DllCall("UpdateResource", "ptr", Module, "ptr", 10 ; Also remove code
		, "ptr", 1, "ushort", 0x409, "ptr", 0, "uint", 0, "uint")

	SetWorkingDir %AhkFile%\..       ; For FileInstall, etc
	DerefIncludeVars.A_WorkFileName := ExeFile
	dirState := ProcessDirectives(ExeFile, Module, Directives, PriorLines
		, IcoFile, VerInfo)

	if Util_ObjNotEmpty(VerInfo)
	{	Util_Status("Changing version information...")
		ChangeVersionInfo(ExeFile, Module, VerInfo)
	}


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
		{	RunWait % """" wk """ -q " v " """ ExeFile """",, Hide UseErrorLevel
			if ErrorLevel
				Util_Error("Warning: " k " failed with error " ErrorLevel,0)
		} else Util_Error("Warning: """ wk """ not found.`n`n'Compress exe with " k
			. "' specified, but freeware " k ".EXE is not in compiler directory. "
			. "See 'Help' -> 'Check for updates' to install.",0)
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

Buttons(a, b)
{	IfWinNotExist Ahk2Exe Query
		return
	SetTimer,, Off
	WinActivate
	ControlSetText Button1, %a%
	ControlSetText Button2, %b%
}

RunPostExec(dirState, UseMPRESS := "")
{	for k, v in dirState["PostExec" UseMPRESS]
	{	Util_Status("PostExec" UseMPRESS ": " v.1)
		RunWait % v.1, % v.2 ? v.2 : A_ScriptDir, % "UseErrorLevel " (v.3?"Hide":"")
		if (ErrorLevel != 0 && !v.4)
			if (ErrorLevel = "ERROR") 
				Util_Error("Program not found:`n" v.1, 0x62)
			else Util_Error("Command failed with error " ErrorLevel ":`n" v.1, 0x62)
}	}

Util_GetFullPath(path)
{	Size := DllCall("GetFullPathName", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint")
	VarSetCapacity(fullpath, size << !!A_IsUnicode)
	fullpathR := DllCall("GetFullPathName", "str", path, "uint", size, "str", fullpath, "ptr", 0, "uint") ? fullpath : ""
	return fullpathR
}
