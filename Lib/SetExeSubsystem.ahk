;
; File encoding:  UTF-8
;

SetExeSubsystem(exepath, subSys)
{
	exe := FileOpen(exepath, "rw", "UTF-8-RAW")
	if !exe
		return false
	; By mere coincidence the address of OptHeader->Subsystem is the same for both 32 and 64-bit executables
	exe.Seek(60), exe.Seek(exe.ReadUInt()+92)
	exe.WriteUShort(subSys)
	return true
}
