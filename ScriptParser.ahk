
PreprocessScript(ByRef ScriptText, AhkScript, ExtraFiles, FileList := "", FirstScriptDir := "", Options := "", iOption := 0)
{
	SplitPath, AhkScript, ScriptName, ScriptDir
	if !IsObject(FileList)
	{
		FileList := [AhkScript]
		ScriptText := "; <COMPILER: v" A_AhkVersion ">`n"
		FirstScriptDir := ScriptDir
		IsFirstScript := true
		Options := { comm: ";", esc: "``", directives: [] }
		
		OldWorkingDir := A_WorkingDir
		SetWorkingDir, %ScriptDir%
	}
	
	IfNotExist, %AhkScript%
		if !iOption
			Util_Error((IsFirstScript ? "Script" : "#include") " file """ AhkScript """ cannot be opened.")
		else return
	
	cmtBlock := false, contSection := false, ignoreSection := false
	Loop, Read, %AhkScript%
	{
		tline := Trim(A_LoopReadLine)
		if !cmtBlock
		{
			if ignoreSection
			{
				if (tline == Options.comm "@Ahk2Exe-IgnoreEnd")
					ignoreSection := false
				continue
			}
			if !contSection
			{
				if StrStartsWith(tline, Options.comm)
				{
					StringTrimLeft, tline, tline, % StrLen(Options.comm)
					if !StrStartsWith(tline, "@Ahk2Exe-")
						continue
					StringTrimLeft, tline, tline, 9
					if tline = IgnoreBegin
						ignoreSection := true
					else if tline !=
						Options.directives.Insert(tline)
					continue
				}
				else if tline =
					continue
				else if StrStartsWith(tline, "/*")
				{
					if (tline == "/*@Ahk2Exe-Keep")
						continue
					cmtBlock := true
					continue
				}
				else if StrStartsWith(tline, "*/")
					continue ; Will only happen in a 'Keep' section
			}
			if StrStartsWith(tline, "(") && !IsFakeCSOpening(tline)
				contSection := true
			else if StrStartsWith(tline, ")")
				contSection := false
			
			tline := RegExReplace(tline, "\s+" RegExEscape(Options.comm) ".*$", "")
			if !contSection && RegExMatch(tline, "i)^#Include(Again)?[ \t]*[, \t]?\s+(.*)$", o)
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
				StringReplace, IncludeFile, IncludeFile, `%A_LineFile`%, %AhkScript%, All
				
				if InStr(FileExist(IncludeFile), "D")
				{
					SetWorkingDir, %IncludeFile%
					continue
				}
				
				_skip_findfile:
				
				IncludeFile := Util_GetFullPath(IncludeFile)
				
				AlreadyIncluded := false
				for k,v in FileList
				if (v = IncludeFile)
				{
					AlreadyIncluded := true
					break
				}
				if(IsIncludeAgain || !AlreadyIncluded)
				{
					if !AlreadyIncluded
						FileList.Insert(IncludeFile)
					PreprocessScript(ScriptText, IncludeFile, ExtraFiles, FileList, FirstScriptDir, Options, IgnoreErrors)
				}
			}else if !contSection && tline ~= "i)^FileInstall[, \t]"
			{
				if tline ~= "^\w+\s+(:=|\+=|-=|\*=|/=|//=|\.=|\|=|&=|\^=|>>=|<<=)"
					continue ; This is an assignment!
				
				; workaround for `, detection
					EscapeChar := Options.esc
					EscapeCharChar := EscapeChar EscapeChar
					EscapeComma := EscapeChar ","
					EscapeTmp := chr(2)
					EscapeTmpD := chr(3)
					StringReplace, tline, tline, %EscapeCharChar%, %EscapeTmpD%, All
					StringReplace, tline, tline, %EscapeComma%, %EscapeTmp%, All
				
				if !RegExMatch(tline, "i)^FileInstall[ \t]*[, \t][ \t]*([^,]+?)[ \t]*(,|$)", o) || o1 ~= "[^``]%"
					Util_Error("Error: Invalid ""FileInstall"" syntax found. Note that the first parameter must not be specified using a continuation section.")
				_ := Options.esc
				StringReplace, o1, o1, %_%`%, `%, All
				StringReplace, o1, o1, %_%`,, `,, All
				StringReplace, o1, o1, %_%%_%,, %_%,, All
				
				; workaround for `, detection [END]
					StringReplace, o1, o1, %EscapeTmp%, `,, All
					StringReplace, o1, o1, %EscapeTmpD%, %EscapeChar%, All
					StringReplace, tline, tline, %EscapeTmp%, %EscapeComma%, All
					StringReplace, tline, tline, %EscapeTmpD%, %EscapeCharChar%, All
				
				ExtraFiles.Insert(o1)
				ScriptText .= tline "`n"
			}else if !contSection && RegExMatch(tline, "i)^#CommentFlag\s+(.+)$", o)
				Options.comm := o1, ScriptText .= tline "`n"
			else if !contSection && RegExMatch(tline, "i)^#EscapeChar\s+(.+)$", o)
				Options.esc := o1, ScriptText .= tline "`n"
			else if !contSection && RegExMatch(tline, "i)^#DerefChar\s+(.+)$", o)
				Util_Error("Error: #DerefChar is not supported.")
			else if !contSection && RegExMatch(tline, "i)^#Delimiter\s+(.+)$", o)
				Util_Error("Error: #Delimiter is not supported.")
			else
				ScriptText .= (contSection ? A_LoopReadLine : tline) "`n"
		}else if StrStartsWith(tline, "*/")
			cmtBlock := false
	}
	
	Loop, % !!IsFirstScript ; equivalent to "if IsFirstScript" except you can break from the block
	{
		static AhkPath := A_IsCompiled ? A_ScriptDir "\..\AutoHotkey.exe" : A_AhkPath
		IfNotExist, %AhkPath%
			break ; Don't bother with auto-includes because the file does not exist
		
		Util_Status("Auto-including any functions called from a library...")
		ilibfile := A_Temp "\_ilib.ahk", preprocfile := ScriptDir "\_ahk2exe.tmp~"
		IfExist, %ilibfile%, FileDelete, %ilibfile%
		IfExist, %preprocfile%, FileDelete, %preprocfile%
		AhkType := AHKType(AhkPath)
		if AhkType = FAIL
			Util_Error("Error: The AutoHotkey build used for auto-inclusion of library functions is not recognized.", 1, AhkPath)
		if AhkType = Legacy
			Util_Error("Error: Legacy AutoHotkey versions (prior to v1.1) are not allowed as the build used for auto-inclusion of library functions.", 1, AhkPath)
		tmpErrorLog := Util_TempFile()
		RunWait, "%AhkPath%" /iLib "%ilibfile%" /ErrorStdOut "%AhkScript%" 2>"%tmpErrorLog%", %FirstScriptDir%, UseErrorLevel
		FileRead,tmpErrorData,%tmpErrorLog%
		FileDelete,%tmpErrorLog%
		if (ErrorLevel = 2)
			Util_Error("Error: The script contains syntax errors.",1,tmpErrorData)
		IfExist, %ilibfile%
		{
			PreprocessScript(ScriptText, ilibfile, ExtraFiles, FileList, FirstScriptDir, Options)
			FileDelete, %ilibfile%
		}
		StringTrimRight, ScriptText, ScriptText, 1 ; remove trailing newline
	}
	
	if OldWorkingDir
		SetWorkingDir, %OldWorkingDir%
	
	if IsFirstScript
		return Options.directives
}

IsFakeCSOpening(tline)
{
	Loop, Parse, tline, %A_Space%%A_Tab%
		if !StrStartsWith(A_LoopField, "Join") && InStr(A_LoopField, ")")
			return true
	return false
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

StrStartsWith(ByRef v, ByRef w)
{
	return SubStr(v, 1, StrLen(w)) = w
}

RegExEscape(t)
{
	static _ := "\.*?+[{|()^$"
	Loop, Parse, _
		StringReplace, t, t, %A_LoopField%, \%A_LoopField%, All
	return t
}

Util_TempFile(d:="")
{
	if ( !StrLen(d) || !FileExist(d) )
		d:=A_Temp
	Loop
		tempName := d "\~temp" A_TickCount ".tmp"
	until !FileExist(tempName)
	return tempName
}
