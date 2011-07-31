
PreprocessScript(ByRef ScriptText, AhkScript, ExtraFiles, FileList="", FirstScriptDir="")
{
	SplitPath, AhkScript, ScriptName, ScriptDir
	if !IsObject(FileList)
	{
		FileList := [AhkScript]
		ScriptText := "; <COMPILER: " A_AhkVersion ">`n"
		FirstScriptDir := ScriptDir
		IsFirstScript := true
		
		OldWorkingDir := A_WorkingDir
		SetWorkingDir, %ScriptDir%
	}
	
	IfNotExist, %AhkScript%
		Util_Error((IsFirstScript ? "Script" : "#include") " file """ AhkScript """ cannot be opened.")
	
	cmtBlock := false, contSection := false
	Loop, Read, %AhkScript%
	{
		tline := Trim(A_LoopReadLine)
		if !cmtBlock
		{
			if !contSection
			{
				if SubStr(tline, 1, 1) = ";"
					continue
				else if tline =
					continue
				else if SubStr(tline, 1, 2) = "/*"
				{
					cmtBlock := true
					continue
				}
			}
			if SubStr(tline, 1, 1) = "("
				contSection := true
			else if SubStr(tline, 1, 1) = ")"
				contSection := false
			
			tline := RegExReplace(tline, "\s+;.*$", "")
			if !contSection && RegExMatch(tline, "i)#Include(Again)?\s+(.*)$", o)
			{
				IsIncludeAgain := (o1 = "Again")
				IgnoreErrors := false
				IncludeFile := o2
				if RegExMatch(IncludeFile, "\*[iI]\s+?(.*)", o)
					IgnoreErrors := true, IncludeFile := Trim(o1)
				
				if RegExMatch(IncludeFile, "^<(.+)>$", o)
				{
					if IncFile2 := FindLibraryFile(o1, FirstScriptDir)
					{
						IncludeFile := IncFile2
						goto _skip_findfile
					}
				}
				
				StringReplace, IncludeFile, IncludeFile, `%A_ScriptDir`%, %FirstScriptDir%, All
				StringReplace, IncludeFile, IncludeFile, `%A_AppData`%, %A_AppData%, All
				StringReplace, IncludeFile, IncludeFile, `%A_AppDataCommon`%, %A_AppDataCommon%, All
				
				if FileExist(IncludeFile) = "D"
				{
					SetWorkingDir, %IncludeFile%
					continue
				}
				
				_skip_findfile:
				
				IncludeFile := Util_GetFullPath(IncludeFile)
				
				AlreadyIncluded := FileList._HasKey(IncludeFile)
				if(IsIncludeAgain || !AlreadyIncluded)
				{
					if !AlreadyIncluded
						FileList._Insert(IncludeFile)
					PreprocessScript(ScriptText, IncludeFile, ExtraFiles, FileList, FirstScriptDir)
				}
			}else if !contSection && RegExMatch(tline, "i)^FileInstall[ \t]*[, \t][ \t]*([^,]+?)[ \t]*,", o) ; TODO: implement `, detection
			{
				if o1 ~= "[^``]%"
					Util_Error("Error: Invalid ""FileInstall"" syntax found. ")
				StringReplace, o1, o1, ```%, `%, All
				StringReplace, o1, o1, ```,, `,, All
				ExtraFiles._Insert(o1)
				ScriptText .= tline "`n"
			}else
				ScriptText .= (contSection ? A_LoopReadLine : tline) "`n"
		}else if SubStr(tline, 1, 2) = "*/"
			cmtBlock := false
	}
	
	if IsFirstScript
	{
		Util_Status("Auto-including any functions called from a library...")
		ilibfile = %A_Temp%\_ilib.ahk
		FileDelete, "%ilibfile%"
		RunWait, "%A_ScriptDir%\..\AutoHotkey.exe" /iLib "%ilibfile%" "%AhkScript%", %A_ScriptDir%
		IfExist, %ilibfile%
			PreprocessScript(ScriptText, ilibfile, ExtraFiles, FileList, FirstScriptDir)
	}
	
	if OldWorkingDir
		SetWorkingDir, %OldWorkingDir%
}

FindLibraryFile(name, ScriptDir)
{
	libs := [ScriptDir "\Lib", A_MyDocuments "\AutoHotkey\Lib", A_ScriptDir "\..\Lib"]
	p := InStr(name, "_")
	if p
		name_lib := SubStr(name, 1, p-1)
	
	for each,lib in libs
	{
		file := lib "\" name ".ahk"
		IfExist, %file%
			return file
		
		if !p
			continue
		
		file := lib "\" name_lib ".ahk"
		IfExist, %file%
			return file
	}
}
