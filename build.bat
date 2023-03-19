REM build all the assembly code "main" files in this directory
REM clean up before calling assembler 
del falkens1k.p
del *.lst
del *.sym

call zxasm falkens1k

REM call will auto run emulator EightyOne if installed
REM comment in or out usin rem which one to run

call falkens1k.p

