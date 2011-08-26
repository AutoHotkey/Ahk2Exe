
; This code is based on Ahk2Exe's changeicon.cpp

ReplaceAhkIcon(re, IcoFile, ExeFile)
{
	global _EI_HighestIconID
	static iconID := 159
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
	Loop, % ids._MaxIndex()
		DllCall("UpdateResource", "ptr", re, "ptr", 3, "ptr", ids[A_Index], "ushort", 0x409, "ptr", 0, "uint", 0, "uint")
	
	Loop, %wCount%
	{
		thisID := ids[A_Index]
		if !thisID
			thisID := ++ _EI_HighestIconID
		
		f.RawRead(ige+0, 12) ; read all but the offset
		NumPut(thisID, ige+12, "UShort")
		
		imgOffset := f.ReadUInt()
		oldPos := f.Pos
		f.Pos := imgOffset
		
		VarSetCapacity(iconData, iconDataSize := NumGet(ige+8, "UInt"))
		f.RawRead(iconData, iconDataSize)
		f.Pos := oldPos
		
		DllCall("UpdateResource", "ptr", re, "ptr", 3, "ptr", thisID, "ushort", 0x409, "ptr", &iconData, "uint", iconDataSize, "uint")
		
		ige += 14
	}
	
	DllCall("UpdateResource", "ptr", re, "ptr", 14, "ptr", iconID, "ushort", 0x409, "ptr", &rsrcIconGroup, "uint", rsrcIconGroupSize, "uint")
	return true
}

EnumIcons(ExeFile, iconID)
{
	; RT_GROUP_ICON = 14
	; RT_ICON = 3
	global _EI_HighestIconID
	static pEnumFunc := RegisterCallback("EnumIcons_Enum")
	
	hModule := DllCall("LoadLibraryEx", "str", ExeFile, "ptr", 0, "ptr", 2, "ptr")
	if !hModule
		return
	
	_EI_HighestIconID := 0
	if DllCall("EnumResourceNames", "ptr", hModule, "ptr", 3, "ptr", pEnumFunc, "uint", 0) = 0
	{
		DllCall("FreeLibrary", "ptr", hModule)
		return
	}
	
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

EnumIcons_Enum(hModule, type, name, lParam)
{
	global _EI_HighestIconID
	if (name < 0x10000) && name > _EI_HighestIconID
		_EI_HighestIconID := name
	return 1
}
