#Include ScriptParser.ahk
#Include IconChanger.ahk
#Include Directives.ahk

AhkCompile(ByRef AhkFile, ExeFile := "", ByRef CustomIcon := "", BinFile := "", UseMPRESS := "")
{
	global ExeFileTmp
	AhkFile := Util_GetFullPath(AhkFile)
	if AhkFile =
		Util_Error("Error: Source file not specified.")
	SplitPath, AhkFile,, AhkFile_Dir,, AhkFile_NameNoExt
	
	if ExeFile =
		ExeFile = %AhkFile_Dir%\%AhkFile_NameNoExt%.exe
	else
		ExeFile := Util_GetFullPath(ExeFile)
	
	ExeFileTmp := ExeFile
	
	if BinFile =
		BinFile = %A_ScriptDir%\AutoHotkeySC.bin
	
	Util_DisplayHourglass()
	
	IfNotExist, %BinFile%
		Util_Error("Error: The selected AutoHotkeySC binary does not exist.", 1, BinFile)
	
	try FileCopy, %BinFile%, %ExeFile%, 1
	catch
		Util_Error("Error: Unable to copy AutoHotkeySC binary file to destination.")
	
	BundleAhkScript(ExeFile, AhkFile, CustomIcon)
	
	if FileExist(A_ScriptDir "\mpress.exe") && UseMPRESS
	{
		Util_Status("Compressing final executable...")
		RunWait, "%A_ScriptDir%\mpress.exe" -q -x "%ExeFile%",, Hide
	}
	
	Util_HideHourglass()
	Util_Status("")
}

BundleAhkScript(ExeFile, AhkFile, IcoFile := "")
{
	SplitPath, AhkFile,, ScriptDir
	
	ExtraFiles := []
	Directives := PreprocessScript(ScriptBody, AhkFile, ExtraFiles)
	VarSetCapacity(BinScriptBody, BinScriptBody_Len := StrPut(ScriptBody, "UTF-8") - 1)
	StrPut(ScriptBody, &BinScriptBody, "UTF-8")
	
	module := DllCall("BeginUpdateResource", "str", ExeFile, "uint", 0, "ptr")
	if !module
		Util_Error("Error: Error opening the destination file.")
	
	tempWD := new CTempWD(ScriptDir)
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
			Util_Error("Could not change executable subsystem!")
	}
	
	for each,cmd in dirState.PostExec
	{
		Util_Status("PostExec: " cmd)
		RunWait, % cmd,, UseErrorLevel
		if (ErrorLevel != 0)
			Util_Error("Command failed with RC=" ErrorLevel ":`n" cmd)
	}
	
	
	return
	
_FailEnd:
	gosub _EndUpdateResource
	Util_Error("Error adding script file:`n`n" AhkFile)
	
_FailEnd2:
	gosub _EndUpdateResource
	Util_Error("Error adding FileInstall file:`n`n" file)
	
_EndUpdateResource:
	if !DllCall("EndUpdateResource", "ptr", module, "uint", 0)
		Util_Error("Error: Error opening the destination file.")
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
