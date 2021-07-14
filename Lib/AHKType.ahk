;
; File encoding:  UTF-8 with BOM
;

; Based on code from SciTEDebug.ahk
AHKType(exeName, Unicode:=1)
{
	Type := {}

	FileGetVersion, vert, %exeName%
	if !vert
		return

	StringSplit, vert, vert, .
	vert := vert4 | (vert3 << 8) | (vert2 << 16) | (vert1 << 24)
	; We're dealing with a legacy version if it's prior to v1.1
	Type.Era := vert >= 0x01010000 ? "Modern" : "Legacy"
	

	if (Unicode)
	{	exeFile := FileOpen(exeName, "r")
		if !exeFile
			return
		exeFile.RawRead(exeData, exeFile.Length)
		exeFile.Close()

		; Get PtrSize based on machine type in PE header
		exeMachine := NumGet(exeData, NumGet(exeData, 60, "uint") + 4, "ushort")
		Type.PtrSize := {0x8664: 8, 0x014C: 4}[exeMachine]
		if !Type.PtrSize
			return  ; Not a valid exe (or belongs to an unsupported platform)

		; Get IsUnicode based on the presence of a string matching our encoding
		Type.IsUnicode := (!RegExMatch(exeData, "MsgBox\0") = !A_IsUnicode) ? 1 : ""
		Type.Summary := Type.PtrSize=8 ? "U64" : Type.IsUnicode ? "U32" : "A32"
	}
	if !(VersionInfoSize := DllCall("version\GetFileVersionInfoSize"
		, "str", exeName, "uint*", null, "uint"))
		return

	VarSetCapacity(VersionInfo, VersionInfoSize)
	if !DllCall("version\GetFileVersionInfo", "str", exeName, "uint", 0
		, "uint", VersionInfoSize, "ptr", &VersionInfo)
		return

	if !DllCall("version\VerQueryValue", "ptr", &VersionInfo, "str"
		, "\VarFileInfo\Translation", "ptr*", lpTranslate, "uint*", cbTranslate)
		return

	wLanguage := NumGet(lpTranslate+0, "UShort")
	wCodePage := NumGet(lpTranslate+2, "UShort")
	id := Format("{:04X}{:04X}", wLanguage, wCodePage)

	Loop Parse, % "FileVersion,FileDescription",`,
		if DllCall("version\VerQueryValue", "ptr", &VersionInfo, "str"
		, "\StringFileInfo\" id "\" A_LoopField, "ptr*", pField, "uint*", cbField)
			Type[SubStr(A_LoopField,5)] := StrGet(pField, cbField)
	
	return Type
}
