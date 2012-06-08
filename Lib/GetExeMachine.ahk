;
; File encoding:  UTF-8
;

GetExeMachine(exepath)
{
	exe := FileOpen(exepath, "r")
	if !exe
		return

	exe.Seek(60), exe.Seek(exe.ReadUInt()+4)
	return exe.ReadUShort()
}
