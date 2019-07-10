#Include <VersionRes>

ProcessDirectives(ExeFile, module, cmds, IcoFile)
{
	state := { ExeFile: ExeFile, module: module, resLang: 0x409, verInfo: {}, IcoFile: IcoFile, PostExec: [] }
	for _,cmdline in cmds
	{
		Util_Status("Processing directive: " cmdline)
		if !RegExMatch(cmdline, "^(\w+)(?:\s+(.+))?$", o)
			Util_Error("Error: Invalid directive:", 0x63, cmdline)
		args := [], nargs := 0
		o2 := DerefIncludePath(o2, DerefIncludeVars, 1)
		StringReplace, o2, o2, ```,, `n, All
		Loop, Parse, o2, `,, %A_Space%%A_Tab%
		{
			StringReplace, ov, A_LoopField, `n, `,, All
			StringReplace, ov, ov, ``n, `n, All
			StringReplace, ov, ov, ``r, `r, All
			StringReplace, ov, ov, ``t, `t, All
			StringReplace, ov, ov, ````, ``, All
			args.Insert(ov), nargs++
		}
		fn := Func("Directive_" o1)
		if !fn
			Util_Error("Error: Invalid directive: " o1, 0x63)
		if (fn.MinParams-1) > nargs || nargs > (fn.MaxParams-1)
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

Directive_SetName(state, txt)
{	state.verInfo.Name := txt
}
Directive_SetDescription(state, txt)
{	state.verInfo.Description := txt
}
Directive_SetVersion(state, txt)
{	state.verInfo.Version := txt
}
Directive_SetCopyright(state, txt)
{	state.verInfo.Copyright := txt
}
Directive_SetOrigFilename(state, txt)
{	state.verInfo.OrigFilename := txt
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
Directive_OutputPreproc(state, fileName)
{	state.OutPreproc := fileName
}

Directive_RequireAdmin(state)
{
	work := Util_TempFile()
	FileAppend <assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0" xmlns:v3="urn:schemas-microsoft-com:asm.v3"><assemblyIdentity version="1.1.00.00" name="AutoHotkey" type="win32" /><dependency><dependentAssembly><assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*" /></dependentAssembly></dependency><compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1"><application><supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/><supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/><supportedOS Id="{e2011457-1546-43c5-a5fe-008deee3d3f0}"/><supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/><supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/></application></compatibility><v3:application><v3:windowsSettings xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings"><dpiAware>true</dpiAware></v3:windowsSettings></v3:application><v3:trustInfo><v3:security><v3:requestedPrivileges><v3:requestedExecutionLevel level="requireAdministrator" uiAccess="false" /></v3:requestedPrivileges></v3:security></v3:trustInfo></assembly> 
	, %work%
	Directive_AddResource(state, "*24 " work, 1)
	FileDelete %work%
}

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
	if !resFile
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
	
	if resType = 23
	{ 
		FileRead fData, %resFile%
		fData := DerefIncludePath(fData, DerefIncludeVars, 1)
		fSize := StrLen(fData) << !!A_IsUnicode
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
		Util_Error("Error: Error opening destination file.", 0x31)
	
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
		continue
		_VerInfo_Name:
		SafeGetViChild(props, "ProductName").SetText(v)
		SafeGetViChild(props, "InternalName").SetText(v)
		return
		_VerInfo_Description:
		SafeGetViChild(props, "FileDescription").SetText(v)
		return
		_VerInfo_Version:
		SafeGetViChild(props, "FileVersion").SetText(v)
		SafeGetViChild(props, "ProductVersion").SetText(v)
		ver := VersionTextToNumber(v)
		hiPart := (ver >> 32)&0xFFFFFFFF, loPart := ver & 0xFFFFFFFF
		NumPut(hiPart, ffi+8, "UInt"), NumPut(loPart, ffi+12, "UInt")
		NumPut(hiPart, ffi+16, "UInt"), NumPut(loPart, ffi+20, "UInt")
		return
		_VerInfo_Copyright:
		SafeGetViChild(props, "LegalCopyright").SetText(v)
		return
		_VerInfo_OrigFilename:
		SafeGetViChild(props, "OriginalFilename").SetText(v)
		return
		_VerInfo_CompanyName:
		SafeGetViChild(props, "CompanyName").SetText(v)
		return
		_VerInfo_LegalTrademarks:
		SafeGetViChild(props, "LegalTrademarks").SetText(v)
		return
	}
	
	VarSetCapacity(newVI, 16384) ; Should be enough
	viSize := vi.Save(&newVI)
	if !DllCall("UpdateResource", "ptr", hUpdate, "ptr", 16, "ptr", 1
	          , "ushort", 0x409, "ptr", &newVI, "uint", viSize, "uint")
		Util_Error("Error changing the version information.", 0x67)
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

Util_ObjIsEmpty(obj)
{
	for _,__ in obj
		return false
	return true
}
