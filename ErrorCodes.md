Possible Errors
=========================================

### `(0x00+)` General

- `(0x0)` Compilation was successful.
- `(0x1)` Error: Unknown error.
- `(0x2)` Compilation was cancelled.
- `(0x3)` Error: Bad parameters
	
    
### `(0x10+)` Syntax

- `(0x1)` Error: The script contains syntax errors.
- `(0x2)` Error: Invalid "FileInstall" syntax found. Note that the first parameter must not be specified using a continuation section.
	
    
### `(0x20+)` Not supported & AutoHotkey version dependent

- `(0x1)` Error: #DerefChar is not supported.
- `(0x2)` Error: #Delimiter is not supported.
- `(0x3)` Error: /NoDecompile is not supported.
- `(0x4)` Error: Password protection is not supported.
- `(0x5)` Error: The AutoHotkey build used for auto-inclusion of library functions is not recognized.
- `(0x6)` Error: Legacy AutoHotkey versions (prior to v1.1) can not be used to do auto-inclusion of library functions.
- `(0x7)` Error: Cursor resource adding is not supported yet.

    
### `(0x30+)` File open & Not found

- `(0x1)` Error: Error opening the destination file.
- `(0x2)` Script or #include cannot be opened.
- `(0x3)` Error: Source file not specified.
- `(0x4)` Error: The selected AutoHotkeySC binary does not exist.
- `(0x5)` Error changing icon: File does not exist.
- `(0x6)` Error: Specified resource does not exist.
	
    
### `(0x40+)` File write

- `(0x1)` Error: Unable to copy AutoHotkeySC binary file to destination.
- `(0x2)` Error changing icon: Unable to read icon or icon was of the wrong format.
- `(0x3)` Error adding script file
- `(0x4)` Error adding FileInstall file
- `(0x5)` Error: Could not move final compiled binary file to destination.
- `(0x6)` Error adding resource.
	
    
### `(0x50+)` Miscellaneous

- `(0x1)` You cannot drop more than one file of each type into this window!
- `(0x2)` Error: cannot find AutoHotkey help file!
- `(0x3)` Error: Invalid codepage parameter was given.


### `(0x60+)` Compiler directives

- `(0x1)` Could not change executable subsystem.
- `(0x2)` Command failed with RC=n.
- `(0x3)` Error: Invalid directive.
- `(0x4)` Error: Wrongly formatted directive.
- `(0x5)` Error: Resource language must be an integer between 0 and 0xFFFF.
- `(0x6)` Error: Impossible BMP file.
- `(0x7)` Error changing the version information.
