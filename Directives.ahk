#Include <VersionRes>

ProcessDirectives(ExeFile, module, cmds, IcoFile)
{
	state := { ExeFile: ExeFile, module: module, resLang: 0x409, verInfo: {}, IcoFile: IcoFile, PostExec: [] }
	global priorlines
	for _,cmdline in cmds
	{
		Util_Status("Processing directive: " cmdline)
		DerefIncludeVars.A_PriorLine := priorlines.RemoveAt(1) 
		if !RegExMatch(cmdline, "^(\w+)(?:\s+(.+))?$", o)
			Util_Error("Error: Invalid directive:", 0x63, cmdline)
		args := [], nargs := 0
		StringReplace, o2, o2, ```,, `n, All
		Loop, Parse, o2, `,, %A_Space%%A_Tab%
		{
			StringReplace, ov, A_LoopField, `n, `,, All
			StringReplace, ov, ov, ``n, `n, All
			StringReplace, ov, ov, ``r, `r, All
			StringReplace, ov, ov, ``t, `t, All
			StringReplace, ov, ov, ````, ``, All
			args.Insert(DerefIncludePath(ov, DerefIncludeVars, 1)), nargs++
		}
		fn := Func("Directive_" o1)
		if !fn
			Util_Error("Error: Invalid directive: " o1, 0x63)
		if (!fn.IsVariadic && (fn.MinParams-1 > nargs || nargs > fn.MaxParams-1))
		|| (fn.IsVariadic && !nargs)
			Util_Error("Error: Wrongly formatted directive:", 0x64, cmdline)
		fn.(state, args*)
	}
	
	if !Util_ObjIsEmpty(state.verInfo)
	{
		Util_Status("Changing version information...")
		ChangeVersionInfo(ExeFile, module, state.verInfo)
	}
	
	if IcoFile := state.IcoFile
	{
		if !FileExist(IcoFile)
			Util_Error("Error changing icon: File does not exist.", 0x35, IcoFile)
		
		Util_Status("Changing the main icon...")
		if !AddOrReplaceIcon(module, IcoFile, ExeFile, 159)
			Util_Error("Error changing icon: Unable to read icon or icon was of the wrong format.", 0x42, IcoFile)
	}
	return state
}

Directive_OutputPreproc(state, fileName) ; Directive not documented?
{	state.OutPreproc := fileName
}
Directive_Let(state, txt*)
{	for k in txt
	{	wk := StrSplit(txt[k], "=", "`t ", 2)
		if (wk.Length() != 2)
			Util_Error("Error: Wrongly formatted directive:", 0x64, "Let " wk.1)
		DerefIncludeVars["U_" wk.1] := wk.2
}	}
Directive_Set(state, name, txt)
{	state.verInfo[name] := txt
}
Directive_SetVersion(state, txt)
{	state.verInfo.Version := txt
}
Directive_SetName(state, txt)
{	state.verInfo.InternalName := state.verInfo.ProductName := txt
}
Directive_SetDescription(state, txt)
{	state.verInfo.FileDescription := txt
}
Directive_SetCopyright(state, txt)
{	state.verInfo.LegalCopyright := txt
}
Directive_SetOrigFilename(state, txt)
{	state.verInfo.OriginalFilename := txt
}
Directive_SetCompanyName(state, txt)
{	state.verInfo.CompanyName := txt
}
Directive_SetLegalTrademarks(state, txt)
{	state.verInfo.LegalTrademarks := txt
}
Directive_SetMainIcon(state, txt := "")
{	state.IcoFile := txt
}
Directive_PostExec(state, txt)
{	state.PostExec.Insert(txt)
}
Directive_ConsoleApp(state)
{	state.ConsoleApp := true
}
Directive_UpdateManifest(state, admin = "", name = "", version = "")
{	SetManifest(state, admin, name, version)
}
Directive_Debug(state, txt)
{	Util_HideHourglass()
	MsgBox 8257,,% "Debug: " txt
	IfMsgBox Cancel
	{	FileDelete % state.ExeFile
		Exit
}	}

Directive_UseResourceLang(state, resLang)
{
	if resLang is not integer
		Util_Error("Error: Resource language must be an integer between 0 and 0xFFFF.", 0x65, resLang)
	if resLang not between 0 and 0xFFFF
		Util_Error("Error: Resource language must be an integer between 0 and 0xFFFF.", 0x65, resLang)
	state.resLang := resLang+0
}

Directive_AddResource(state, rsrc, resName := "")
{
	resType := "" ; auto-detect
	if RegExMatch(rsrc, "^\*(\w+)\s+(.+)$", o)
		resType := o1, rsrc := o2
	resFile := Util_GetFullPath(rsrc)
	if !FileExist(rsrc)
		Util_Error("Error: specified resource does not exist:", 0x36, rsrc)
	SplitPath, resFile, resFileName,, resExt
	if !resName
		resName := resFileName, defResName := true
	StringUpper, resName, resName
	if resType =
	{
		; Auto-detect resource type
		if resExt in bmp,dib
			resType := 2 ; RT_BITMAP
		else if resExt = ico
			resType := 14 ; RT_GROUP_ICON
		else if resExt = cur
			Util_Error("Error: Cursor resource adding is not supported yet!", 0x27)
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
		AddOrReplaceIcon(state.module, resFile, state.ExeFile, resName)
		return
	}
	typeType := "str"
	nameType := "str"
	if resType is integer
		if resType between 0 and 0xFFFF
			typeType := "uint"
	if resName is integer
		if resName between 0 and 0xFFFF
			nameType := "uint"
	
	if resType in 4,5,6,9,23,24   ; Deref text-type resources
	{ 
		FileRead fData, %resFile%
		fData1 := DerefIncludePath(fData, DerefIncludeVars, 1)
		VarSetCapacity(fData, fSize := StrPut(fData1, "utf-8") - 1)
		StrPut(fData1, &fdata, "utf-8")
	} else {
		FileGetSize, fSize, %resFile%
		VarSetCapacity(fData, fSize)
		FileRead, fData, *c %resFile%
	}
	pData := &fData
	if resType = 2
	{
		; Remove BM header in order to make it a valid bitmap resource
		if fSize < 14
			Util_Error("Error: Impossible BMP file!", 0x66)
		pData += 14, fSize -= 14
	}
	if !DllCall("UpdateResource", "ptr",state.module, typeType,resType, nameType
	, resName, "ushort",state.resLang, "ptr",pData, "uint",fSize, "uint")
		Util_Error("Error adding resource:", 0x46, rsrc)
	VarSetCapacity(fData, 0)
}

ChangeVersionInfo(ExeFile, hUpdate, verInfo)
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
	for k,v in verInfo
	{
		if IsLabel(lbl := "_VerInfo_" k)
			gosub %lbl%
		else SafeGetViChild(props, k).SetText(v)  ; Miscellaneous properties
		continue
		_VerInfo_Version:
		SafeGetViChild(props, "FileVersion").SetText(v)
		SafeGetViChild(props, "ProductVersion").SetText(v)
		ver := VersionTextToNumber(v)
		hiPart := (ver >> 32)&0xFFFFFFFF, loPart := ver & 0xFFFFFFFF
		NumPut(hiPart, ffi+8, "UInt"), NumPut(loPart, ffi+12, "UInt")
		NumPut(hiPart, ffi+16, "UInt"), NumPut(loPart, ffi+20, "UInt")
		return
	}
	
	VarSetCapacity(newVI, 16384) ; Should be enough
	viSize := vi.Save(&newVI)
	if !DllCall("UpdateResource", "ptr", hUpdate, "ptr", 16, "ptr", 1
						, "ushort", 0x409, "ptr", &newVI, "uint", viSize, "uint")
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

SetManifest(state, admin = "", name = "", version = "")
{
	xml := ComObjCreate("Msxml2.DOMDocument")
	xml.async := false
	xml.setProperty("SelectionLanguage", "XPath")
	xml.setProperty("SelectionNamespaces"
			, "xmlns:v1='urn:schemas-microsoft-com:asm.v1' "
			. "xmlns:v3='urn:schemas-microsoft-com:asm.v3'")
	if !xml.load("res://" state.ExeFile "/#24/#1") ; Load current manifest
		Util_Error("Error: Error opening destination file. (D2)", 0x31)

	
	node := xml.selectSingleNode("/v1:assembly/v1:assemblyIdentity")
	if !node ; Not AutoHotkey v1.1?
		Util_Error("Error: Error opening destination file. (D3)", 0x31)
	(version && node.setAttribute("version", version)) 
	(name && node.setAttribute("name", name))

	node := xml.selectSingleNode("/v1:assembly/v3:trustInfo/v3:security"
								. "/v3:requestedPrivileges/v3:requestedExecutionLevel")
	if !node ; Not AutoHotkey v1.1?
		Util_Error("Error: Error opening destination file. (D4)", 0x31)
	(admin && node.setAttribute("level", "requireAdministrator"))
	
	xml := RTrim(xml.xml, "`r`n")
	VarSetCapacity(data, data_size := StrPut(xml, "utf-8") - 1)
	StrPut(xml, &data, "utf-8")
	
	if !DllCall("UpdateResource", "ptr", state.module, "ptr", 24, "ptr", 1
									, "ushort", 1033, "ptr", &data, "uint", data_size, "uint")
		Util_Error("Error changing the version information. (D2)", 0x67)
}

Util_ObjIsEmpty(obj)
{
	for _,__ in obj
		return false
	return true
}
