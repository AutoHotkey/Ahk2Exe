;
; File encoding:  UTF-8 with BOM
;
PreprocessScript(ByRef ScriptText, AhkScript, Directives, PriorLines
, FileList := "", FirstScriptDir := "", Options := "", iOption := 0)
{	global DirDoneG, PriorLine, MjrVn
	SplitPath, AhkScript, ScriptName, ScriptDir
	if !IsObject(FileList)
	{
		FileList := [AhkScript]
		ScriptText := "; <COMPILER: v" A_AhkVersion ">`n"
		FirstScriptDir := ScriptDir
		IsFirstScript := true
		Options := { comm: ";", esc: "``" }
		OldWorkingDir := A_WorkingDir
		TempWD := new CTempWD(ScriptDir)
	}
	oldLineFile := DerefIncludeVars.A_LineFile
	DerefIncludeVars.A_LineFile := AhkScript
	
	if (MjrVn != 1)                       ; Handle v2+ default folder
	{	OldWorkingDirv2 := A_WorkingDir
		SetWorkingDir %ScriptDir%
	}
	IfNotExist, %AhkScript%
		if !iOption
			Util_Error((IsFirstScript ? "Script" : "#include") " file cannot be opened.", 0x32, """" AhkScript """")
		else return
	
	cmtBlock := 0, contSection := false, ignoreSection := false
	Loop, Read, %AhkScript%
	{	tline := Trim(A_LoopReadLine)
		if cmtBlock != 1
		{	if ignoreSection
			{	if StrStartsWith(tline, Options.comm "@Ahk2Exe-IgnoreEnd")
					ignoreSection := false
				continue
			}
			if !contSection
			{	if StrStartsWith(tline, Options.comm)
				{	StringTrimLeft, tline, tline, % StrLen(Options.comm)
					if !StrStartsWith(tline, "@Ahk2Exe-")
						continue
					StringTrimLeft, tline, tline, 9
					if StrStartsWith(tline, "IgnoreBegin")
						ignoreSection := true       ;v Skip 'Bin' & their 'Cont' directives
					else if Trim(tline) != "" && !(DirDoneG[A_Index] && IsFirstScript)
						Directives.Insert(RegExReplace(tline ; Save directive
						, "\s+" RegExEscape(Options.comm) ".*$")) ;Strip any actual comments
						, PriorLines.Push(PriorLine) ; Will be this directive's A_PriorLine
					continue
				} else if tline =
					continue
				else if StrStartsWith(tline, "/*")
				{	if StrStartsWith(tline, "/*@Ahk2Exe-Keep")
						cmtBlock := 2
					else if !(MjrVn != 1 && tline ~= "\*/$")
							cmtBlock := 1
					continue
				} else if (cmtBlock = 2 && StrStartsWith(tline, "*/"))
					continue
			}
			if StrStartsWith(tline, "(") && !IsFakeCSOpening(SubStr(tline,2))
				contSection := true
			else if StrStartsWith(tline, ")")
				contSection := false
			
			PriorLine := tline                   ; Save for a directive's A_PriorLine
			tline := RegExReplace(tline, "\s+" RegExEscape(Options.comm) ".*$", "")
			if !contSection 
			&& RegExMatch(tline, "i)^#Include(Again)?[ \t]*[, \t]\s*(.*)$", o)
			{	IsIncludeAgain := (o1 = "Again")
				IgnoreErrors := false
				IncludeFile := Trim(o2,"""'")      ; Drop any quotes (V2)
				if RegExMatch(IncludeFile, "\*[iI]\s+?(.*)", o)
					IgnoreErrors := true, IncludeFile := Trim(o1)

				if SubStr(IncludeFile, 1, 1) = "*" ; References to Embedded Scripts have
				{	ScriptText .= tline "`n"         ; a filename which starts with * and
					continue                         ; will be handled by the interpreter
				}
				if RegExMatch(IncludeFile, "^<(.+)>$", o)
				{	if IncFile2 := FindLibraryFile(o1, FirstScriptDir)
					{	IncludeFile := IncFile2
						goto _skip_findfile
				}	}
				IncludeFile := DerefIncludePath(IncludeFile, DerefIncludeVars)
				if InStr(FileExist(IncludeFile), "D")
				{	SetWorkingDir, %IncludeFile%
					continue
				}
				
				_skip_findfile:
				
				IncludeFile := Util_GetFullPath(IncludeFile)
				AlreadyIncluded := false
				for k,v in FileList
				if (v = IncludeFile)
				{	AlreadyIncluded := true
					break
				}
				if(IsIncludeAgain || !AlreadyIncluded)
				{	if !AlreadyIncluded
						FileList.Insert(IncludeFile)
					PreprocessScript(ScriptText, IncludeFile, Directives
					, PriorLines, FileList, FirstScriptDir, Options, IgnoreErrors)
				}
			} else if !contSection && tline ~= "i)^FileInstall[(, \t]"
			{	if tline ~= "^\w+\s+(:=|\+=|-=|\*=|/=|//=|\.=|\|=|&=|\^=|>>=|<<=)"
					continue ; This is an assignment!
				
				; workaround for `, detection
					EscapeChar := Options.esc
					EscapeCharChar := EscapeChar EscapeChar
					EscapeComma := EscapeChar ","
					EscapeTmp := chr(2)
					EscapeTmpD := chr(3)
					StringReplace, tline, tline, %EscapeCharChar%, %EscapeTmpD%, All
					StringReplace, tline, tline, %EscapeComma%, %EscapeTmp%, All
				
				if !RegExMatch(tline, "i)^FileInstall[ \t]*[(, \t][ \t]*([^,]+?)[ \t]*(,|$)", o) || o1 ~= "[^``]%"
					Util_Error("Error: Invalid ""FileInstall"" syntax found. Note that the first parameter must not be specified using a continuation section.", 0x12)
				_ := Options.esc
				StringReplace, o1, o1, %_%`%, `%, All
				StringReplace, o1, o1, %_%`,, `,, All
				StringReplace, o1, o1, %_%%_%,, %_%,, All
				
			; workaround for `, detection [END]
				StringReplace, o1, o1, %EscapeTmp%, `,, All
				StringReplace, o1, o1, %EscapeTmpD%, %EscapeChar%, All
				StringReplace, tline, tline, %EscapeTmp%, %EscapeComma%, All
				StringReplace, tline, tline, %EscapeTmpD%, %EscapeCharChar%, All
                                                       ;v Drop any quotes (V2)
				Directives.Push("AddResource *10 " Trim(StrReplace(o1,",","``,"),"""'"))
				PriorLines.Push(Chr(127) Trim(A_LoopReadLine)) ; 'Install' flag & line
				ScriptText .= tline "`n"
			} else if !contSection && RegExMatch(tline, "i)^#CommentFlag\s+(.+)$", o)
				Options.comm := o1, ScriptText .= tline "`n"
			else if !contSection && RegExMatch(tline, "i)^#EscapeChar\s+(.+)$", o)
				Options.esc := o1, ScriptText .= tline "`n"
			else if !contSection && RegExMatch(tline, "i)^#DerefChar\s+(.+)$", o)
				Util_Error("Error: #DerefChar is not supported.", 0x21)
			else if !contSection && RegExMatch(tline, "i)^#Delimiter\s+(.+)$", o)
				Util_Error("Error: #Delimiter is not supported.", 0x22)
			else
				ScriptText .= (contSection ? A_LoopReadLine : tline) "`n"
		} else if (tline~="^\*/" || MjrVn != 1 && tline~="\*/$")
			cmtBlock := 0                                    ; End block comment
	}                                                    ; End file-read loop
	Loop, % !!IsFirstScript ; Like "if IsFirstScript" but can "break" from block
	{	global AhkPath, AhkSw
		IfNotExist, %AhkPath%
			break ; Don't bother with auto-includes because the file does not exist
		Util_Status("Auto-including any functions called from a library...")
		AhkTypeRet := AHKType(AhkPath,0)
		if !AhkTypeRet
			Util_Error("Error: The AutoHotkey build used for auto-inclusion of library functions is not recognized.", 0x25, AhkPath)
		if (AhkTypeRet.Era = "Legacy")
			Util_Error("Error: Legacy AutoHotkey versions (prior to v1.1) can not be used to do auto-inclusion of library functions.", 0x26, AhkPath)
		
		if !((Modl:=DllCall("LoadLibraryEx","Str",AhkPath, "Ptr",0, "Int",2, "Ptr"))
		&& ((wk:=DllCall("FindResource","Ptr",Modl,"Str","#1","Ptr",10,"Ptr")) || 1)
		&& DllCall("FreeLibrary", "ptr", Modl)) ;^ ResourceID = 1?
			Util_Error("Error: Cannot determine AutoHotkey vintage.", 0x54, AhkPath)
		AhkSw := wk ? " /Script " : " ", ilib := Util_TempFile(, "ilib~")

		CmdLn = "%AhkPath%" %AhkSw% /iLib "%ilib%" /ErrorStdOut "%AhkScript%"
		if Store
		{	tmpErrorData := RunCMD(CmdLn, FirstScriptDir)
			ErrLev1 := ErrLev := ErrorLevel
		} else
		{	RunWait "%ComSpec%" /c "%CmdLn% 2>"%ilib%E"", %FirstScriptDir%
			, UseErrorLevel Hide            ;^ Editor may flag, but it's valid syntax
			ErrLev2 := ErrLev := ErrorLevel
			FileRead tmpErrorData,%ilib%E
			if ErrLev in 1,2                ; Avoid UNC path bug
			{	RunWait %CmdLn% 2>"%ilib%A", %FirstScriptDir%, UseErrorLevel Hide
				ErrLev3 := ErrLev := ErrorLevel
		}	} ;^^ Bug ref https://www.autohotkey.com/boards/viewtopic.php?f=14&t=90457
		if (ErrLev = 2)
		{	FileDelete %ilib%*
			Util_Error("Error: The script contains syntax errors.", 0x11,tmpErrorData)
		} else if (ErrLev)                ; Unexpected error has occurred
		{	FileDelete %ilib%*
			Util_Error("Error: Call for """ AhkPath """ has failed.`n(%comspec%="
			.  ComSpec ")`nError code is " ErrLev "`nErrLev1 = " ErrLev1
			. "`nErrLev2 = " ErrLev2 "`nErrLev3 = " ErrLev3, 0x51)
		}

		IfExist, %ilib%
		{	FileGetSize wk, %ilib%
			if wk > 3
			{	if (MjrVn != 1)
				{ Loop 4                      ; v1 - Generate random label prefix
					{ Random wk, 97, 122
						ScriptText .= Chr(wk)     ; Prevent possible '#Warn Unreachable'
					}                           ; Don't execute Auto_Includes directly
					ScriptText .= "_This_and_next_line_added_by_Ahk2Exe:`nExit`n"
				}
				PreprocessScript(ScriptText, ilib, Directives
				, PriorLines, FileList, FirstScriptDir, Options)
		}	}
		If (ilib)
			FileDelete, %ilib%*
		StringTrimRight, ScriptText, ScriptText, 1   ; Remove trailing newline
	}

	DerefIncludeVars.A_LineFile := oldLineFile
	if OldWorkingDir
		SetWorkingDir, %OldWorkingDir%
	
	if (MjrVn != 1)                     ; Handle v2+ default folder
		SetWorkingDir %OldWorkingDirv2%
}
; --------------------------- End PreprocessScript -----------------------------

IsFakeCSOpening(tline)
{	Loop, Parse, tline, %A_Space%%A_Tab%
		if !StrStartsWith(A_LoopField, "Join") && InStr(A_LoopField, ")")
			return true
	return false
}

FindLibraryFile(name, ScriptDir)
{	global StdLibDir
	libs := [ScriptDir "\Lib", A_MyDocuments "\AutoHotkey\Lib", StdLibDir]
	p := InStr(name, "_")
	if p
		name_lib := SubStr(name, 1, p-1)
	
	for each,lib in libs
	{	file := lib "\" name ".ahk"
		IfExist, %file%
			return file
		
		if !p
			continue
		
		file := lib "\" name_lib ".ahk"
		IfExist, %file%
			return file
}	}


StrStartsWith(ByRef v, ByRef w)
{	return SubStr(v, 1, StrLen(w)) = w
}

RegExEscape(t)
{	static _ := "\.*?+[{|()^$"
	Loop, Parse, _
		StringReplace, t, t, %A_LoopField%, \%A_LoopField%, All
	return t
}

Util_TempFile(d := "", f := "", xep := "")
{ static xe := ""
	if xep
		xe := xep
	if ( !StrLen(d) || !FileExist(d) )
		d := A_Temp
	Loop
	{ DllCall("QueryPerformanceCounter", "Int64*", Counter)
		tempName := d "\~Ahk2Exe~" xe "~" f Counter ".tmp"
	} until !FileExist(tempName)
	return tempName
}


RunCMD(CmdLine, WorkingDir:="", Codepage:="CP0", Fn:="RunCMD_Output", Slow:=1) 
{ Local         ; RunCMD v0.97 by SKAN on D34E/D67E 
                ;            @ autohotkey.com/boards/viewtopic.php?t=74647
                ; Based on StdOutToVar.ahk by Sean 
                ;            @ autohotkey.com/board/topic/15455-stdouttovar
                ; Modified by TAC109 to not use A_Args (disrupts Ahk2Exe)

	Slow := !! Slow, Fn := IsFunc(Fn) ? Func(Fn) : 0, P8 := (A_PtrSize=8)
	, DllCall("CreatePipe", "PtrP",hPipeR:=0, "PtrP",hPipeW:=0, "Ptr",0, "Int",0)
	, DllCall("SetHandleInformation", "Ptr",hPipeW, "Int",1, "Int",1)
	, DllCall("SetNamedPipeHandleState","Ptr",hPipeR, "UIntP",PIPE_NOWAIT:=1
		, "Ptr",0, "Ptr",0)

	, VarSetCapacity(SI, P8 ? 104 : 68, 0)        ; STARTUPINFO structure
	, NumPut(P8 ? 104 : 68, SI)                   ; size of STARTUPINFO
	, NumPut(STARTF_USESTDHANDLES:=0x100, SI, P8 ? 60 : 44,"UInt") ; dwFlags
	, NumPut(hPipeW, SI, P8 ? 88 : 60)            ; hStdOutput
	, NumPut(hPipeW, SI, P8 ? 96 : 64)            ; hStdError
	, VarSetCapacity(PI, P8 ? 24 : 16)            ; PROCESS_INFORMATION structure
	
	If !DllCall("CreateProcess", "Ptr",0, "Str",CmdLine, "Ptr",0,"Int",0,"Int",1
	, "Int",0x08000000 | DllCall("GetPriorityClass", "Ptr",-1, "UInt"), "Int",0
	, "Ptr", WorkingDir ? &WorkingDir : 0, "Ptr",&SI, "Ptr",&PI)
		Return Format("{1:}", "", ErrorLevel := -1
		, DllCall("CloseHandle", "Ptr",hPipeW), DllCall("CloseHandle","Ptr",hPipeR))

	DllCall("CloseHandle", "Ptr",hPipeW)
	, RnCMD := { "PID": NumGet(PI, P8? 16 : 8, "UInt") }
	, File := FileOpen(hPipeR, "h", Codepage), LineNum := 1,  sOutput := ""
	While  ( RnCMD.PID | DllCall("Sleep", "Int",Slow) )
	and  DllCall("PeekNamedPipe", "Ptr",hPipeR, "Ptr",0, "Int",0, "Ptr",0
	, "Ptr",0, "Ptr",0)
		While RnCMD.PID and StrLen(Line := File.ReadLine())
			sOutput .= Fn ? Fn.Call(Line, LineNum++) : Line

	RnCMD.PID := 0, hProcess := NumGet(PI, 0), hThread  := NumGet(PI, A_PtrSize)
	, DllCall("GetExitCodeProcess", "Ptr",hProcess, "PtrP",ExitCode:=0)
	, DllCall("CloseHandle", "Ptr",hProcess), DllCall("CloseHandle","Ptr",hThread)
	, DllCall("CloseHandle", "Ptr",hPipeR), ErrorLevel := ExitCode
	Return sOutput
}

class DerefIncludeVars
{	static A_IsCompiled := true
}

DerefIncludePath(path, vars, dosubset := 0)
{	static SharedVars := {A_AhkPath:1, A_AppData:1, A_AppDataCommon:1, A_ComputerName:1, A_ComSpec:1, A_Desktop:1, A_DesktopCommon:1, A_MyDocuments:1, A_ProgramFiles:1, A_Programs:1, A_ProgramsCommon:1, A_Space:1, A_StartMenu:1, A_StartMenuCommon:1, A_Startup:1, A_StartupCommon:1, A_Tab:1, A_Temp:1, A_UserName:1, A_WinDir:1}
	p := StrSplit(path, "%")
	path := p[1]
	n := 2
	while n < p.Length()
	{	vn := p[n]
		subs := StrReplace(StrReplace(vn, "````", "chr(2)"), "``~", "chr(3)")
		subs := dosubset ? StrSplit(subs, "~",, 3) : [vn]
		subs.2 := StrReplace(StrReplace(subs.2, "chr(2)", "``"), "chr(3)", "~")
		subs.3 := StrReplace(StrReplace(subs.3, "chr(2)", "``"), "chr(3)", "~")
		if ObjHasKey(vars, subs.1)
			path .= subset(vars[subs.1], subs) . p[++n]
		else if SharedVars[subs.1]
			vn := subs.1, path .= subset(%vn%, subs) . p[++n]
		else path .= "%" vn
		++n
	}
	if (n = p.Length())
		path .= "%" p[n]
	return path
}
; ^^ vv Can subset dereferenced value (only when used in Compiler Directives).
;
; Include at end of builtin variable name before end %, p2 [p3] all separated
;   by tilde "~".  p2 and p3 will be used as p2, p3 of 'RegExReplace'.
;
; E.g. %A_ScriptName~\.[^\.]+$~.exe% replaces extension with .exe.
;
; To include tilde as data in p2, p3, preceded with back-tick, i.e. `~
; To include back-tick character as data in p2, p3, double it, i.e. ``

subset(val, subs)      ; Returns subset of val using subs.2 & subs.3
{                      ; if no subs.2 or empty, return val unchanged
	return subs.2="" ? val : RegExReplace(val, subs.2, subs.3)
}
