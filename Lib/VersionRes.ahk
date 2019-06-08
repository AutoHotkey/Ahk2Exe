
class VersionRes
{
	Name := ""
	Data := ""
	IsText := true
	DataSize := 0
	Children := []
	
	__New(addr := 0)
	{
		if !addr
			return this
		
		wLength := NumGet(addr+0, "UShort"), addrLimit := addr + wLength, addr += 2
		wValueLength := NumGet(addr+0, "UShort"), addr += 2
		wType := NumGet(addr+0, "UShort"), addr += 2
		szKey := StrGet(addr), addr += 2*(StrLen(szKey)+1), addr := (addr+3)&~3
		ObjSetCapacity(this, "Data", size := wValueLength*(wType+1))
		this.Name := szKey
		this.DataSize := wValueLength
		this.IsText := wType
		DllCall("msvcrt\memcpy", "ptr", this.GetDataAddr(), "ptr", addr, "ptr", size, "cdecl"), addr += size, addr := (addr+3)&~3
		;if wType
		;	ObjSetCapacity(this, "Data", -1)
		while addr < addrLimit
		{
			size := (NumGet(addr+0, "UShort") + 3) & ~3
			this.Children.Insert(new VersionRes(addr))
			addr += size
		}
	}
	
	_NewEnum()
	{
		return this.Children._NewEnum()
	}
	
	AddChild(node)
	{
		this.Children.Insert(node)
	}
	
	GetChild(name)
	{
		for k,v in this
			if v.Name = name
				return v
	}
	
	GetText()
	{
		if this.IsText
			return this.Data
	}
	
	SetText(txt)
	{
		this.Data := txt
		this.IsText := true
		this.DataSize := StrLen(txt)+1
	}
	
	GetDataAddr()
	{
		return ObjGetAddress(this, "Data")
	}
	
	Save(addr)
	{
		orgAddr := addr
		addr += 2
		NumPut(ds:=this.DataSize, addr+0, "UShort"), addr += 2
		NumPut(it:=this.IsText, addr+0, "UShort"), addr += 2
		addr += 2*StrPut(this.Name, addr+0, "UTF-16")
		addr := (addr+3)&~3
		realSize := ds*(it+1)
		DllCall("msvcrt\memcpy", "ptr", addr, "ptr", this.GetDataAddr(), "ptr", realSize, "cdecl"), addr += realSize
		addr := (addr+3)&~3
		for k,v in this
			addr += v.Save(addr)
		size := addr - orgAddr
		NumPut(size, orgAddr+0, "UShort")
		return size
	}
}
