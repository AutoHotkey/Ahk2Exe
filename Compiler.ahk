;
; File encoding:  UTF-8 with BOM
;
#Include ScriptParser.ahk
#Include IconChanger.ahk
#Include Directives.ahk

AhkCompile(ByRef AhkFile, ExeFile="", ByRef CustomIcon="", BinFile="", UseMPRESS="", fileCP="")
{
	global ExeFileTmp, ExeFileG
	AhkFile := Util_GetFullPath(AhkFile)
	if AhkFile =
		Util_Error("Error: Source file not specified.", 0x33)

	SplitPath AhkFile,, Ahk_Dir,, Ahk_Name
	SplitPath ExeFile,, Edir,,    Ename
	ExeFile := (Edir ? Edir : Ahk_Dir) "\" (Ename ? Ename : Ahk_Name ) ".exe"
	ExeFile := Util_GetFullPath(ExeFile)

	;ExeFileTmp := ExeFile
	ExeFileTmp := Util_TempFile()
	
	if BinFile =
		BinFile = %A_ScriptDir%\AutoHotkeySC.bin
	
	Util_DisplayHourglass()
	
	IfNotExist, %BinFile%
		Util_Error("Error: The selected AutoHotkeySC binary does not exist. (C1)"
		, 0x34, """" BinFile """")
	
	try FileCopy, %BinFile%, %ExeFileTmp%, 1
	catch
		Util_Error("Error: Unable to copy AutoHotkeySC binary file to destination.", 0x41)

	DerefIncludeVars.Delete("U_", "V_")         ; Clear Directives entries
	DerefIncludeVars.Delete("A_WorkFileName")
	DerefIncludeVars.Delete("A_PriorLine")

	BinType := AHKType(ExeFileTmp)
	DerefIncludeVars.A_AhkVersion := BinType.Version
	DerefIncludeVars.A_PtrSize := BinType.PtrSize
	DerefIncludeVars.A_IsUnicode := BinType.IsUnicode ; Currently returns ""
	
	if !(BinType.IsUnicode)             ; Set A_IsUnicode
	{                                   ; Rationale for this code:-
		FileGetSize size, %ExeFileTmp%    ; For same code base each version bigger;
		Loop Files, %BinFile%\..\*bit.bin ; Unicode has more code than ANSI;
			if (A_LoopFileSize = size)      ; 64-bit has bigger pointers than 32-bit
				DerefIncludeVars.A_IsUnicode := InStr(A_LoopFileName,"Unicode") ? 1 : ""
	}
	ExeFileG := ExeFile
	BundleAhkScript(ExeFileTmp, AhkFile, CustomIcon, fileCP)
	
	if FileExist(A_ScriptDir "\mpress.exe") && UseMPRESS = 1
	{
		Util_Status("Compressing final executable with MPRESS...")
		RunWait, "%A_ScriptDir%\mpress.exe" -q -x "%ExeFileTmp%",, Hide
	}
	
	if FileExist(A_ScriptDir "\upx.exe") && UseMPRESS = -1
	{
		Util_Status("Compressing final executable with UPX...")
		RunWait, "%A_ScriptDir%\upx.exe" -q --all-methods "%ExeFileTmp%",, Hide
	}
	
	; the final step...
	Util_HideHourglass()
	Util_Status("Moving .exe to destination")

Loop
	{	FileMove, %ExeFileTmp%, %ExeFileG%, 1
		if !ErrorLevel
			break
		DetectHiddenWindows On
		if !WinExist("ahk_exe " ExeFileG)
			Util_Error("Error: Could not move final compiled binary file to "
			. "destination. (C1)", 0x45, """" ExeFileG """")
		else
		{	SetTimer Buttons, 50
			wk := """" RegExReplace(ExeFileG, "^.+\\") """"
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
	}	}
	if Reload
		run "%ExeFileG%", %ExeFileG%\..
	Util_Status("")
}

Buttons()
{	IfWinNotExist Ahk2Exe Query
		return
	SetTimer,, Off
	WinActivate
	ControlSetText Button1, &Unload
	ControlSetText Button2, && &Reload
}

BundleAhkScript(ExeFile, AhkFile, IcoFile="", fileCP="")
{
	; weird bug prevention, for non working default param 'fileCP'
	if fileCP is space
		fileCP := A_FileEncoding
	
	try FileEncoding, %fileCP%
	catch e
		Util_Error("Error: Invalid codepage parameter """ fileCP """ was given.", 0x53)
	
	SplitPath, AhkFile,, ScriptDir

	ExtraFiles := []
	Directives := PreprocessScript(ScriptBody, AhkFile, ExtraFiles)
	VarSetCapacity(BinScriptBody, BinScriptBody_Len := StrPut(ScriptBody, "UTF-8") - 1)
	StrPut(ScriptBody, &BinScriptBody, "UTF-8")
	
	module := DllCall("BeginUpdateResource", "str", ExeFile, "uint", 0, "ptr")
	if !module
		Util_Error("Error: Error opening the destination file. (C1)", 0x31)
	
	tempWD := new CTempWD(ScriptDir)

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
	if !DllCall("UpdateResource", "ptr", module, "ptr", 10, "str", ">AUTOHOTKEY SCRIPT<"
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
	
	for each,cmd in dirState.PostExec
	{
		Util_Status("PostExec: " cmd)
		RunWait, % cmd,, UseErrorLevel
		if (ErrorLevel != 0)
			Util_Error("Command failed with RC=" ErrorLevel ":`n" cmd, 0x62)
	}
	
	
	return
	
_FailEnd:
	gosub _EndUpdateResource
	Util_Error("Error adding script file:`n`n" AhkFile, 0x43)
	
_FailEnd2:
	gosub _EndUpdateResource
	Util_Error("Error adding FileInstall file:`n`n" file, 0x44)
	
_EndUpdateResource:
	if !DllCall("EndUpdateResource", "ptr", module, "uint", 0)
		Util_Error("Error: Error opening the destination file. (C2)", 0x31)
	return
}

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

Util_GetFullPath(path)
{
	VarSetCapacity(fullpath, 260 * (!!A_IsUnicode + 1))
	return DllCall("GetFullPathName", "str", path, "uint", 260, "str", fullpath, "ptr", 0, "uint") ? fullpath : ""
}
