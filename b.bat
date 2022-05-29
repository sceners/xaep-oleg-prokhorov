@echo off
nasm -fobj xaep.asm
alink -m xaep -oEXE
del xaep.obj
del xaep.map
