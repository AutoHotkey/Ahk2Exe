﻿;
; File encoding:  UTF-8 with BOM
;

; Based on code from SciTEDebug.ahk
AHKType(exeName)
{
	FileGetVersion, vert, %exeName%
	if !vert
		return
	
	StringSplit, vert, vert, .
	vert := vert4 | (vert3 << 8) | (vert2 << 16) | (vert1 << 24)
	
	exeMachine := GetExeMachine(exeName)
	if !exeMachine
		return
	
	if (exeMachine != 0x014C) && (exeMachine != 0x8664)
		return
	
	if !(VersionInfoSize := DllCall("version\GetFileVersionInfoSize", "str", exeName, "uint*", null, "uint"))
		return
	
	VarSetCapacity(VersionInfo, VersionInfoSize)
	if !DllCall("version\GetFileVersionInfo", "str", exeName, "uint", 0, "uint", VersionInfoSize, "ptr", &VersionInfo)
		return
	
	if !DllCall("version\VerQueryValue", "ptr", &VersionInfo, "str", "\VarFileInfo\Translation", "ptr*", lpTranslate, "uint*", cbTranslate)
		return
	
	wLanguage := NumGet(lpTranslate+0, "UShort")
	wCodePage := NumGet(lpTranslate+2, "UShort")
	id := Format("{:04X}{:04X}", wLanguage, wCodePage)

	FileDescription := ""
	FileVersion := ""
	Loop Parse, % "FileDescription,FileVersion", `,
	{
		if !DllCall("version\VerQueryValue", "ptr", &VersionInfo, "str", "\StringFileInfo\" id "\" A_LoopField, "ptr*", pField, "uint*", cbField)
			return
		%A_LoopField% := StrGet(pField, cbField)
	}
	
	Type := { Version: FileVersion
		, IsUnicode: InStr(FileDescription, "Unicode") ? 1 : ""
		, PtrSize: exeMachine=0x8664 ? 8 : 4 }
	
	; We're dealing with a legacy version if it's prior to v1.1
	Type.Era := vert >= 0x01010000 ? "Modern" : "Legacy"
	
	return Type
}
