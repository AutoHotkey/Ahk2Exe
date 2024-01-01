;
; File encoding:  UTF-8 with BOM
;
#Include <VersionRes>

ProcessDirectives(ExeFile, Module, Directives, PriorLines, IcoFile, VerInfo)
{	state := { ExeFile: ExeFile, Module: Module, resLang: 0x409, VerInfo: {}
	, IcoFile: IcoFile, PostExec:[], PostExec0:[], PostExec1:[], PostExec2:[] }
	state.VerInfo := VerInfo

	for k, Cmd in Directives
	{	DerefIncludeVars.A_PriorLine := state.PriorLine := PriorLines[k] 
		while SubStr(wk := DerefIncludePath(Directives[k+A_Index]
		, DerefIncludeVars, 1), 1, 4) ~= "i)^Cont$|^Nop $"
			Cmd .= SubStr(wk, 1, 4) = "Cont" ? SubStr(wk, 6) : ""
		Util_Status("Processing directive: " (SubStr(Cmd,1,11) = "AddResource"
			&& SubStr(PriorLines[k],1,1) = Chr(127) ? SubStr(PriorLines[k],2) : Cmd))
		state.Cmd := Cmd := DerefIncludePath(Cmd, DerefIncludeVars, 1)
		if !RegExMatch(Cmd, "^(\w+)(?:\s+(.+))?$", o)
			Util_Error("Error: Invalid directive: (D1)", 0x63, Cmd)
		args := [], nargs := 0
		StringReplace, o2, o2, ```,, `n, All
		Loop, Parse, o2, `,, %A_Space%%A_Tab%
		{
			StringReplace, ov, A_LoopField, `n, `,, All
			StringReplace, ov, ov, ``n, `n, All
			StringReplace, ov, ov, ``r, `r, All
			StringReplace, ov, ov, ``t, `t, All
			StringReplace, ov, ov,````, ``, All
			args.Insert(ov), nargs++
		}
		fn := Func("Directive_" o1)
		if !fn
			Util_Error("Error: Invalid directive: (D2)" , 0x63, Cmd)
		if (!fn.IsVariadic && (fn.MinParams-1 > nargs || nargs > fn.MaxParams-1))
			Util_Error("Error: Wrongly formatted directive: (D1)", 0x64, Cmd)
		fn.(state, args*)
	}
	if IcoFile := state.IcoFile
	{	Util_Status("Changing the main icon...")
		if !FileExist(IcoFile)
			Util_Error("Error changing icon: File does not exist.", 0x35, IcoFile)
		if !AddOrReplaceIcon(Module, IcoFile, ExeFile, 159)
			Util_Error("Error changing icon: Unable to read icon or icon was of the wrong format.", 0x42, IcoFile)
	}
	return state
}
; ---------------------------- Handle Directives -------------------------------
Directive_ConsoleApp(state)
{	state.ConsoleApp := true
}
Directive_Cont(state, txt*)
{                                          ; Handled above
}
Directive_Debug(state, txt*)
{	for k, v in txt
		wk .= k=1 ? v : ", " v
	Util_Error( "Debug: " wk, 0)
}
Directive_ExeName(state, txt)
{	global ExeFileG, StopCDExe
	if !StopCDExe
	{	SplitPath ExeFileG,, gdir,,gname
		SplitPath txt     ,, idir,,iname
		ExeFileG := (idir ? idir : gdir) "\" (iname ? iname : gname) ".exe"
}	}
Directive_Let(state, txt*)
{	for k in txt
	{	wk := StrSplit(txt[k], "=", "`t ", 2)
		if (wk.Length() != 2)
			Util_Error("Error: Wrongly formatted directive: (D2)", 0x64, state.Cmd)
		DerefIncludeVars[(wk.1 ~= "i)^U_" ? "" : "U_") wk.1] := wk.2
}	}
Directive_Nop(state, txt*)
{                                         ; Do nothing
}
Directive_Obey(state, name, txt, extra:=0)
{	global AhkPath, AhkSw, SilentMode
	IfExist %AhkPath%
	{	if !(extra ~= "^[0-9]$")
			Util_Error("Error: Wrongly formatted directive: (D3)", 0x64, state.Cmd)
		wk := Util_TempFile(, "Obey~")
		FileAppend % (txt~="^=" ? name ":" : "") txt "`nFileOpen(""" wk 0
		. """,""W"",""UTF-8"").Write(" name ")", %wk%, UTF-8
		Loop % extra
			FileAppend % "`nFileOpen(""" wk A_Index
			. """,""W"",""UTF-8"").Write(" name A_Index ")", %wk%, UTF-8
		if SilentMode
		{ ErrorData := RunCMD("""" AhkPath """ " AhkSw " /ErrorStdOut """ wk """")
			if ErrorLevel
			{	FileDelete %wk%*
				Util_Error("Error: 'Obey' directive cannot be executed.",0x68,ErrorData)
		}	} else RunWait "%AhkPath%" %AhkSw% "%wk%",,Hide
		Loop % extra + 1
		{	FileRead result, % "*p65001 " wk (cnt := A_Index - 1)
			DerefIncludeVars[(name~="i)^U_"?"":"U_") name (cnt ? cnt : "")] := result
		}
		FileDelete %wk%*
}	}
Directive_PostExec(state, txt, when="", WorkingDir="", Hidden=0, IgnoreErrors=0)
{	if !({"":1,0:1,1:1,2:1}[when] && {"":1,0:1,1:1}[Hidden] 
	&& {"":1,0:1,1:1}[IgnoreErrors])
		Util_Error("Error: Wrongly formatted directive: (D4)", 0x64, state.Cmd)
	state["PostExec" when].Push([txt, WorkingDir, Hidden, IgnoreErrors])
}
Directive_ResourceID(state, txt)
{	state.ResourceID := txt
}
Directive_Set(state, name, txt)
{	state.VerInfo[name] := txt
}
Directive_SetCompanyName(state, txt)
{	state.VerInfo.CompanyName := txt
}
Directive_SetCopyright(state, txt)
{	state.VerInfo.LegalCopyright := txt
}
Directive_SetDescription(state, txt)
{	state.VerInfo.FileDescription := txt
}
Directive_SetFileVersion(state, txt)
{	state.VerInfo.FileVersion := txt
}
Directive_SetInternalName(state, txt)
{	state.VerInfo.InternalName := txt
}
Directive_SetLanguage(state, txt)
{	state.VerInfo.Language := txt
}
Directive_SetLegalTrademarks(state, txt)
{	state.VerInfo.LegalTrademarks := txt
}
Directive_SetMainIcon(state, txt := "")
{	global StopCDIco
	if !StopCDIco
		state.IcoFile := txt
}
Directive_SetName(state, txt)
{	state.VerInfo.InternalName := state.VerInfo.ProductName := txt
}
Directive_SetOrigFilename(state, txt)
{	state.VerInfo.OriginalFilename := txt
}
Directive_SetProductName(state, txt)
{	state.VerInfo.ProductName := txt
}
Directive_SetProductVersion(state, txt)
{	state.VerInfo.ProductVersion := txt
}
Directive_SetVersion(state, txt)
{	state.VerInfo.FileVersion := state.VerInfo.ProductVersion := txt
}

Directive_UpdateManifest(state, admin, name = "", version = "", uiaccess = "")
{	xml := ComObjCreate("Msxml2.DOMDocument")
	xml.async := false
	xml.setProperty("SelectionLanguage", "XPath")
	xml.setProperty("SelectionNamespaces"
			, "xmlns:v1='urn:schemas-microsoft-com:asm.v1' "
			. "xmlns:v3='urn:schemas-microsoft-com:asm.v3'")
	if !xml.load("res://" state.ExeFile "/#24/#1") ; Load current manifest
		Util_Error("Error: Error opening destination file. (D2)", 0x31, state.Cmd)
	node := xml.selectSingleNode("/v1:assembly/v1:assemblyIdentity")
	if !node ; Not AutoHotkey v1.1?
		Util_Error("Error: Error opening destination file. (D3)", 0x31, state.Cmd)
	(version && node.setAttribute("version", version)) 
	(name && node.setAttribute("name", name))

	node := xml.selectSingleNode("/v1:assembly/v3:trustInfo/v3:security"
								. "/v3:requestedPrivileges/v3:requestedExecutionLevel")
	if !node ; Not AutoHotkey v1.1?
		Util_Error("Error: Error opening destination file. (D4)", 0x31, state.Cmd)
	(admin=1  && node.setAttribute("level", "requireAdministrator"))
	(admin=2  && node.setAttribute("level", "highestAvailable"))
	(uiaccess && node.setAttribute("uiAccess", "true"))
	xml := RTrim(xml.xml, "`r`n")
	VarSetCapacity(data, data_size := StrPut(xml, "utf-8") - 1)
	StrPut(xml, &data, "utf-8")
	
	if !DllCall("UpdateResource", "ptr", state.Module, "ptr", 24, "ptr", 1
									, "ushort", 1033, "ptr", &data, "uint", data_size, "uint")
		Util_Error("Error changing the version information. (D2)", 0x67, state.Cmd)
}

Directive_UseResourceLang(state, resLang)
{
	if resLang is not integer
		Util_Error("Error: Resource language must be an integer between 0 and 0xFFFF.", 0x65, state.Cmd)
	if resLang not between 0 and 0xFFFF
		Util_Error("Error: Resource language must be an integer between 0 and 0xFFFF.", 0x65, state.Cmd)
	state.resLang := resLang+0
}

Directive_AddResource(state, rsrc, resName := "")
{
	resType := "" ; auto-detect
	if RegExMatch(rsrc, "^\*(\w+)\s+(.+)$", o)
		resType := o1, rsrc := o2
	resFile := Util_GetFullPath(rsrc)
	if !FileExist(rsrc)
		Util_Error("Error: specified resource does not exist:", 0x36
		, SubStr(state.PriorLine,1,1)=Chr(127)?SubStr(state.PriorLine,2):state.Cmd)
	SplitPath, resFile, resFileName,, resExt
	if !resName
		resName := SubStr(state.PriorLine,1,1) = Chr(127) ? rsrc : resFileName
		, defResName := 1
	StringUpper, resName, resName
	if resType =
	{
		; Auto-detect resource type
		if resExt in bmp,dib
			resType := 2 ; RT_BITMAP
		else if resExt = ico
			resType := 14 ; RT_GROUP_ICON
		else if resExt = cur
			Util_Error("Error: Cursor resource adding is not supported yet!", 0x27, state.Cmd)
		else if resExt in htm,html,mht
			resType := 23 ; RT_HTML
		else if resExt = manifest
		{
			resType := 24 ; RT_MANIFEST
			if defResName
				resName := 1
		} else
			resType := 10 ; RT_RCDATA
	}
	if resType = 14
	{
		if resName is not integer
			resName := 0
		AddOrReplaceIcon(state.Module, resFile, state.ExeFile, resName)
		return
	}
	typeType := "str"
	nameType := "str"
	if resType is integer
		if resType between 0 and 0xFFFF
			typeType := "ptr"
	resName := resName ~= "^#\d+$" ? SubStr(resName, 2) : resName
	if resName is integer
		if resName between 0 and 0xFFFF
			nameType := "ptr"
	
	if resType in 4,5,6,9,23,24                       ; Deref text-type resources
	{	FileRead fData, %resFile%
		fData1 := DerefIncludePath(fData, DerefIncludeVars, 1)
		VarSetCapacity(fData, fSize := StrPut(fData1, "utf-8") - 1)
		StrPut(fData1, &fData, "utf-8")
	} 
	else if (resExt = "ahk" && resType = 10           ; Process AutoHotkey scripts
	&& SubStr(state.PriorLine,1,1) != Chr(127))       ; But not from FileInstall
	{	OldA_s := [], OldA_s.Push(DerefIncludeVars.A_ScriptFullPath) 
		OldA_s.Push(DerefIncludeVars.A_ScriptName)
		OldA_s.Push(DerefIncludeVars.A_ScriptDir)

		SplitPath, resFile, ScriptName, ScriptDir
		DerefIncludeVars.A_ScriptFullPath := resFile
		DerefIncludeVars.A_ScriptName     := ScriptName
		DerefIncludeVars.A_ScriptDir      := ScriptDir
		tempWD := new CTempWD(ScriptDir)

		PreprocessScript(fData1 := "", resFile, Directives := [], PriorLines := [])
		dirState := ProcessDirectives(state.ExeFile, state.Module
		, Directives, PriorLines, "", state.VerInfo)

		if dirState.ConsoleApp                     ; Pass any ConsoleApp up chain
			state.ConsoleApp := dirState.ConsoleApp
		for k, v in ["PostExec", "PostExec0", "PostExec1", "PostExec2"]
			state[v].Push(dirState[v]*)              ; Pass any PostExec up chain

		DerefIncludeVars.A_ScriptDir      := OldA_s.Pop()
		DerefIncludeVars.A_ScriptName     := OldA_s.Pop()
		DerefIncludeVars.A_ScriptFullPath := OldA_s.Pop()

		VarSetCapacity(fData, fSize := StrPut(fData1, "utf-8") - 1)
		StrPut(fData1, &fData, "utf-8")
	} 
	else
	{	FileGetSize, fSize, %resFile%
		VarSetCapacity(fData, fSize)
		FileRead, fData, *c %resFile%
	}
	pData := &fData
	if resType = 2
	{	; Remove BM header in order to make it a valid bitmap resource
		if fSize < 14
			Util_Error("Error: Impossible BMP file!", 0x66, state.Cmd)
		pData += 14, fSize -= 14
	}
	if !DllCall("UpdateResource", "ptr",state.Module, typeType,resType, nameType
	, resName, "ushort",state.resLang, "ptr",pData, "uint",fSize, "uint")
		Util_Error("Error adding resource:", 0x46, state.Cmd)
	VarSetCapacity(fData, 0)
}

ChangeVersionInfo(ExeFile, hUpdate, VerInfo)
{
	hModule := DllCall("LoadLibraryEx", "str", ExeFile, "ptr", 0, "ptr", 2, "ptr")
	if !hModule
		Util_Error("Error: Error opening destination file. (D1)", 0x31)
	
	hRsrc := DllCall("FindResource", "ptr", hModule, "ptr", 1, "ptr", 16, "ptr") ; Version Info\1
	hMem := DllCall("LoadResource", "ptr", hModule, "ptr", hRsrc, "ptr")
	vi := new VersionRes(DllCall("LockResource", "ptr", hMem, "ptr"))
	DllCall("FreeLibrary", "ptr", hModule)
	
	ffi := vi.GetDataAddr()
	props := SafeGetViChild(SafeGetViChild(vi, "StringFileInfo"), "040904b0")
	for k,v in VerInfo
	{	if (!v)
			props.DeleteChild(k)                   ; Remove any unwanted version info
		else
		{	if !(k = "Language")
				SafeGetViChild(props, k).SetText(v)  ; All properties, but not language
			if k in FileVersion,ProductVersion
			{	ver := VersionTextToNumber(v)
				hiPart := (ver >> 32)&0xFFFFFFFF, loPart := ver & 0xFFFFFFFF
				if (k = "FileVersion")
						NumPut(hiPart, ffi+8,  "UInt"), NumPut(loPart, ffi+12, "UInt")
				else NumPut(hiPart, ffi+16, "UInt"), NumPut(loPart, ffi+20, "UInt")
	}	}	}
	VarSetCapacity(newVI, 16384) ; Should be enough
	viSize := vi.Save(&newVI)
	
	if (wk := VerInfo.Language)                               ; Change language?
	{	NumPut(VerInfo.Language, newVI, viSize-4, "UShort")
	}
	DllCall("UpdateResource", "ptr", hUpdate, "ptr", 16, "ptr", 1
		, "ushort", 0x409, "ptr", 0, "uint", 0, "uint")         ; Delete lang 0x409
	if !DllCall("UpdateResource", "ptr", hUpdate, "ptr", 16, "ptr", 1, "ushort"
		, wk ? wk : 0x409, "ptr", &newVI, "uint", viSize, "uint") ; Add new language
		Util_Error("Error changing the version information. (D1)", 0x67)
}

VersionTextToNumber(v)
{
	r := 0, i := 0
	while i < 4 && RegExMatch(v, "O)^(\d+).?", o)
	{
		StringTrimLeft, v, v, % o.Len
		val := o[1] + 0
		r |= (val&0xFFFF) << ((3-i)*16)
		i ++
	}
	return r
}

SafeGetViChild(vi, name)
{
	c := vi.GetChild(name)
	if !c
	{
		c := new VersionRes()
		c.Name := name
		vi.AddChild(c)
	}
	return c
}

