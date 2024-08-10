# Ahk2Exe #

Ahk2Exe is the official AutoHotkey script to EXE converter, which is written itself in AutoHotkey v1.1. It compiles v1.1 and v2+ scripts into executables.

https://www.autohotkey.com/


## How to compile Ahk2Exe ##

Ahk2Exe must be compiled with itself as it uses compiler directives. 

The compilation will also need to use files from a recent AutoHotkey v1.1 self-contained binary, such as an installed version of AutoHotkey.

After unpacking all the source files, run Ahk2Exe.ahk, and drag and drop Ahk2Exe.ahk onto the converter window.

The embedded 'Base' compiler directive will use a suitable Base file from the installed AutoHotkey (see above). Alternatively select a suitable v1.1 32-bit Unicode Base file to use.

Press the 'Convert' button.

The resulting Ahk2Exe.exe file should be copied to the Compiler sub-folder under the folder containing AutoHotkey.exe for proper operation.


## To do ##

  - Handle FileInstall on same-line If* commands.

