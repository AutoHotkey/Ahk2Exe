
; This code is based on Ahk2Exe's changeicon.cpp

AddOrReplaceIcon(re, IcoFile, ExeFile, iconID := 0)
{
	global _CI_HighestIconID, _CIG_HighestIconGroupID
	
	CountIcons(ExeFile)
	
	if !iconID
	{
		CountIconGroups(ExeFile)
		iconID := ++ _CIG_HighestIconGroupID
	}
	
	ids := EnumIcons(ExeFile, iconID)
	if !IsObject(ids)
		return false
	
	f := FileOpen(IcoFile, "r")
	if !IsObject(f)
		return false
	
	VarSetCapacity(igh, 8), f.RawRead(igh, 6)
	if NumGet(igh, 0, "UShort") != 0 || NumGet(igh, 2, "UShort") != 1
		return false
	
	wCount := NumGet(igh, 4, "UShort")
	
	VarSetCapacity(rsrcIconGroup, rsrcIconGroupSize := 6 + wCount*14)
	NumPut(NumGet(igh, "Int64"), rsrcIconGroup, "Int64") ; fast copy
	
	ige := &rsrcIconGroup + 6
	
	; Delete all the images
	Loop, % ids.MaxIndex()
		DllCall("UpdateResource", "ptr", re, "ptr", 3, "ptr", ids[A_Index], "ushort", 0x409, "ptr", 0, "uint", 0, "uint")
	
	Loop, %wCount%
	{
		thisID := ids[A_Index]
		if !thisID
			thisID := ++ _CI_HighestIconID
		
		f.RawRead(ige+0, 12) ; read all but the offset
		NumPut(thisID, ige+12, "UShort")
		
		imgOffset := f.ReadUInt()
		oldPos := f.Pos
		f.Pos := imgOffset
		
		VarSetCapacity(iconData, iconDataSize := NumGet(ige+8, "UInt"))
		f.RawRead(iconData, iconDataSize)
		f.Pos := oldPos
		
		if !DllCall("UpdateResource", "ptr", re, "ptr", 3, "ptr", thisID, "ushort", 0x409, "ptr", &iconData, "uint", iconDataSize, "uint")
			return false
		
		ige += 14
	}
	
	return !!DllCall("UpdateResource", "ptr", re, "ptr", 14, "ptr", iconID, "ushort", 0x409, "ptr", &rsrcIconGroup, "uint", rsrcIconGroupSize, "uint")
}

CountIcons(ExeFile)
{
	; RT_ICON = 3
	global _CI_HighestIconID
	
	if _CI_HighestIconID
		return
	
	static pEnumFunc := RegisterCallback("CountIcons_Enum")
	
	hModule := DllCall("LoadLibraryEx", "str", ExeFile, "ptr", 0, "ptr", 2, "ptr")
	if !hModule
		return
	
	_CI_HighestIconID := 0
	DllCall("EnumResourceNames", "ptr", hModule, "ptr", 3, "ptr", pEnumFunc, "uint", 0)
	
	DllCall("FreeLibrary", "ptr", hModule)
}

CountIconGroups(ExeFile)
{
	; RT_GROUP_ICON = 14
	global _CIG_HighestIconGroupID
	
	if _CIG_HighestIconGroupID
		return
	
	static pEnumFunc := RegisterCallback("CountIconGroups_Enum")
	
	hModule := DllCall("LoadLibraryEx", "str", ExeFile, "ptr", 0, "ptr", 2, "ptr")
	if !hModule
		return
	
	_CIG_HighestIconGroupID := 0
	DllCall("EnumResourceNames", "ptr", hModule, "ptr", 14, "ptr", pEnumFunc, "uint", 0)
	
	DllCall("FreeLibrary", "ptr", hModule)
}

EnumIcons(ExeFile, iconID)
{
	; RT_GROUP_ICON = 14
	hModule := DllCall("LoadLibraryEx", "str", ExeFile, "ptr", 0, "ptr", 2, "ptr")
	if !hModule
		return
	
	hRsrc := DllCall("FindResource", "ptr", hModule, "ptr", iconID, "ptr", 14, "ptr")
	hMem := DllCall("LoadResource", "ptr", hModule, "ptr", hRsrc, "ptr")
	pDirHeader := DllCall("LockResource", "ptr", hMem, "ptr")
	pResDir := pDirHeader + 6
	
	wCount := NumGet(pDirHeader+4, "UShort")
	iconIDs := []
	
	Loop, %wCount%
	{
		pResDirEntry := pResDir + (A_Index-1)*14
		iconIDs[A_Index] := NumGet(pResDirEntry+12, "UShort")
	}
	
	DllCall("FreeLibrary", "ptr", hModule)
	return iconIDs
}

CountIcons_Enum(hModule, type, name, lParam)
{
	global _CI_HighestIconID
	if (name < 0x10000) && name > _CI_HighestIconID
		_CI_HighestIconID := name
	return 1
}


CountIconGroups_Enum(hModule, type, name, lParam)
{
	global _CIG_HighestIconGroupID
	if (name < 0x10000) && name > _CIG_HighestIconGroupID
		_CIG_HighestIconGroupID := name
	return 1
}
