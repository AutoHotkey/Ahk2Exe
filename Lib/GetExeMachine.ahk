;
; File encoding:  UTF-8 with BOM
;
; See https://www.autohotkey.com/boards/viewtopic.php?f=74&t=77686 for Unicode 
;  detection details

GetExeMachine(exepath)
{
	exe := FileOpen(exepath, "r")
	if !exe
		return

	exe.RawRead(fd, exe.Length)
	exe.Seek(60), exe.Seek(exe.ReadUInt()+4)

	mach := { Bits: exe.ReadUShort(), IsUnicode: !!RegExMatch(fd, "MsgBox\0") }
	exe.Close()

	return mach
}
