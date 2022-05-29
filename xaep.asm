%macro SEGCS 0
   db  02Eh
%endmacro

%macro MovSEG 2
  push %2
  pop  %1
%endmacro

%macro XchgSEG 2
  push %2
  push %1
  pop  %2
  pop  %1
%endmacro

SuccessExitCode EQU 0
ErrWF	   EQU 1
ErrOF	   EQU 2
ErrRF	   EQU 3
ErrMaskNF  EQU 4

ETX equ 0

PM_STACKSIZE equ 200h

segment code16 public align=16 use16
segment stackseg stack align=16


segment code16
..start:
Fix:
	cld
	push  ds
	MovSEG es, cs

.Tunedargv0:
	mov   si, 81h
	mov   di, ff
	lea   bx, [di-1]
	mov   cl, byte [80h]
	cmp   cl, 0
  jz    .emptycline
.NCH:
	lodsb
	cmp   al, 20h
  je    .SkipChar
	cmp   al, 9
  jne   .SaveChar
.SkipChar:
	mov   byte [es:bx], 0
	lea   di, [bx+1]
  jmp   short .DecChar
.SaveChar:
	stosb
	mov   bx, di
.DecChar:
	dec   cl
  jne   .NCH

.emptycline:
	MovSEG es, ds
	MovSEG ds, cs
	mov   SI, IntroMessage
	CALL  WriteIt
	cmp   byte [ff], 0
  jnz   .cfile
	mov   SI, UsageMessage

	CALL  WriteIt
	MOV   AL, SuccessExitCode
  JMP   short .QQ
.OFE:
	MOV   AL, ErrOF
.QQ:
	mov   [cs:xAEPCode], AL
  JMP   QuitIT

.cfile:
	pop   es
	mov   dx, ff
	mov   ax, 3D00h
	int   21h
  jc    .OFE
	mov   [ih], ax
	mov   bx, ax
	mov   cx, 32
	mov   dx, @exeheader
	call  ReadFromFile
	cmp   word [@exeheader], 5A4Dh
  je    .MZE
	cmp   word [@exeheader], 4D5Ah
  je    .MZE
	mov   byte [iexe], 0
	mov   byte [aepexe], 0
	xor   cx, cx
	xor   dx, dx
	mov   ax, 4202h
	int   21h
	mov   [aeps], ax
	test  dx, dx
  jnz   .aEPE
	xor   cx, cx
	xor   dx, dx
	mov   word [@ip_reg], 100h
	mov   word [mptr], _aepcom
  jmp   short .COME
.aEPE:
  jmp   @masknf
.MZE:
	cmp   word [@ip_reg], BYTE 00h
  je    .OkMZ
	cmp   word [@ip_reg], 100h
  jne   .aEPE
	mov   word [mptr], _aepcom
	mov   byte [aepexe], 0
.OkMZ:
	movzx eax, word [@para_in_head]
	movzx ecx, word [@cs_reg]
	add   eax, ecx
	shl   eax, 4
	movzx ecx, word [@ip_reg]
	add   eax, ecx
	and   eax, 0FFFFFh
	movzx ecx, word [@pages_in_file]
	movzx edx, word [@bytes_on_last]
	test  edx, edx
  jz    .nip
	dec   cx
.nip:
	shl   ecx, 9
	add   ecx, edx
	mov   [exesize], ecx
	sub   ecx, eax
	mov   [aeps], ecx

	mov   dx, ax
	mov   ecx, eax
	shr   ecx, 16

.COME:
	mov   ax, 4200h
	int   21h

	mov   bx, ss
	mov   ax, sp
	add   ax, BYTE 0Fh
	shr   ax, 4
	add   bx, ax
	mov   ax, es
	sub   bx, ax

	mov   ah, 4Ah
	int   21h
  jnc   .NE1
.MemErr:
	mov   si, MemoErr
  jmp   WriteError
.NE1:
	mov   ah, 48h
	mov   bx, 01000h
	int   21h
  jc    .MemErr
	mov   [buffer], ax

	mov   bx, [ih]
	mov   cx, word [aeps]
	mov   dx, [@ip_reg]

	mov   ds, [buffer]
	call  ReadFromFile

	MovSEG es, ds
	MovSEG ds, cs
	xor   di, di
	lea   dx, [di+400h]
	call  SearchStringByte
  jnc   @masknf
	mov   [o1], di

	call  SearchStringByte
  jnc   @masknf
	mov   [o2], di

	call  SearchStringByte
  jnc   @masknf
	mov   si, [es:di- (_aep04 - _aep03)+0Ah]
	mov   cx, [es:di- (_aep04 - _aep03)+0Dh]
	mov   di, si
	mov   dx, 0FE01h
	call  Decrypt2
	call  SearchStringByte
  jnc   @masknf
	cmp   di, bp
  jne   @masknf

	mov   si, [es:di- (_aep05 - _aep04)+0ah]    ; 2f4h
	mov   bx, [es:di- (_aep05 - _aep04)+0eh]    ; 0c1h
	cmp   byte [aepexe], 1
  je    .exe1
	mov   si, [es:di- (_aep05 - _aep04)+0ch]    ;
	mov   bx, [es:di- (_aep05 - _aep04)+0fh]    ;
.exe1:
	mov   bp, [es:di- (_aep05 - _aep04)+12h]
	mov   ax, [es:bx]
	mov   bx, [es:di - (_aep05 - _aep04)+1eh]

	mov   di, [o1]
	mov   dx, [es:di- (_aep02 - _aep01)+27h]
	mov   cx, [es:di- (_aep02 - _aep01)+2eh]
	cmp   byte [aepexe], 1
  je    .exe2
	mov   cx, [es:di- (_aep02 - _aep01)+20h]
.exe2:
	mov   di, [es:bx+2]			  ; 541h

	call  Decrypt1
	mov   di, [o1]
  jmp   short Continue

@masknf:
	mov   byte [cs:xAEPCode], ErrMaskNF
  jmp   QuitIT

Continue:
	mov   bx, [es:di- (_aep02 - _aep01)+57h]
	cmp   byte [aepexe], 1
  je    .exe3
	mov   bx, [es:di- (_aep02 - _aep01)+58h]
.exe3:
	xor   dx, dx
	call  GetCheckSum
	mov   di, [o2]
	mov   si, [es:di-(_aep03 - _aep02)+2]
	mov   cx, [es:di-(_aep03 - _aep02)+5]
	mov   di, si
	call  Decrypt2
	push  dx
	mov   word [_aepcom+8], _aep05

	lea   dx, [di+_aep06 - _aep05+20h]
	call  SearchStringByte
  jnc   @masknf
	cmp   bp, di
  jne   @masknf
	pop   dx
	xor   dx, 7ffh
	mov   si, [es:di-(_aep06 - _aep05)+6]
	mov   cx, [es:di-(_aep06 - _aep05)+9]
	mov   di, si
	call  Decrypt2

	mov   word [_aepcom+10], _aep13
	mov   dx, si
	call  SearchStringByte
  jnc   @masknf
	mov   [o3], di
	lea   bp, [di - (_aep07 - _aep06)]

	inc   di
	mov   cx, _aep08 - _aep07
	mov   si, _aep07
	rep   cmpsb
  jne   @masknf
	inc   di
	mov   cx, _aep09 - _aep08
	cmp   byte [aepexe], 1
  je    .exe4
	sub   cx, byte 9
	inc   bp
.exe4:
	mov   si, _aep08
	rep   cmpsb
  jne   near @masknf
	mov   si, bp
	mov   di, Decrypt3
	mov   cx, 26h
	MovSEG fs, es
	XchgSEG ds, es
	rep   movsb
	MovSEG ds, cs
	cmp   byte [aepexe], 1
  je    .exe5
	mov   byte [Decrypt3+25h], 59h
.exe5:
	mov   ah, 3Ch
	mov   dx, ofname
	xor   cx, cx
	int   21h
  jc    near @writefile_error
	mov   [oh], ax
	movzx edx, word [@para_in_head]
	shl   edx, 4
	movzx edi, word [@cs_reg]
	shl   edi, 4
	cmp   byte [aepexe], 1
  je    .exe6
	mov   ebx, edx
	mov   si, [o3]
	movzx edx, word [fs:si-0eh]
	mov   si, word [fs:si-13h]
	movzx edi, word [fs:si]
	sub   dx, 100h
	cmp   byte [iexe], 1
  jne   .exe6
	add   edx, ebx
.exe6:
	mov   bx, [ih]

	mov   ecx, edx
	shr   ecx, 16
	mov   ax, 4200h
	int   21h

	mov   word [@bytes_on_last], 0
	mov   ds, [buffer]
	MovSEG es, ds
	xor   dx, dx
.Nr:
	mov   ecx, 0F000h
	cmp   ecx, edi
  jb    .NN
	mov   ecx, edi
.NN:
	mov   bx, [cs:ih]
	call  ReadFromFile

	push  ecx
	push  edi
	xor   si, si
	call  Decrypt3
	pop   edi
	pop   ecx

	cmp   byte [cs:n], 0
  jne   .m
	cmp   word [0], 5A4Dh
  je    .mz
	cmp   word [0], 4D5Ah
  jne   .m
.mz:
	mov   byte [cs:oexe], 1
	mov   ax, word [2]
	and   ax, 0fh
	mov   word [cs:@bytes_on_last], ax
.m:
	xor   dx, dx
	mov   bx, [cs:oh]
	call  WriteToFile
	inc   byte [cs:n]
	sub   edi, ecx
  jnz   .Nr

	MovSEG ds, cs
	mov   dx, word [@bytes_on_last]
	test  dx, dx
  jz    QuitIT
	mov   bx, [oh]
	sub   dx, byte 10h
	mov   cx, -1
	mov   ax, 4202h
	int   21h
	xor   cx, cx
	call  WriteToFile
	cmp   byte [oexe], 1
  jnz   QuitIT
	call  CopyOverlay
QuitIT:
	MovSEG ds, cs
	movzx bx, [xAEPCode]
	cmp   bl, 0
  je    .GoExit
	dec   bx
	shl   bx, 1
	mov   si, [bx+ ExAEP]
	CALL  WriteIt
.GoExit:
	mov   ah, 4Ch
	int   21h

@writefile_error:
	mov   byte [cs:xAEPCode], ErrWF
  jmp   short QuitIT
@readfile_error:
	mov   byte [cs:xAEPCode], ErrRF
  JMP   short QuitIT

ReadFromFile:
	mov   ah, 3fh
	int   21h
  jc    @readfile_error
	cmp   ax, cx
  jne   @readfile_error
	ret

WriteToFile:
	mov   ah, 40h
	int   21h
  jc    @writefile_error
	cmp   ax, cx
  jne   @writefile_error
retn

CopyOverlay:
	mov   bx, [ih]
	xor   cx, cx
	xor   dx, dx
	mov   ax, 4202h
	int   21h
	mov   di, dx
	shl   edi, 16
	mov   di, ax
	mov   edx, [exesize]
	sub   edi, edx
  jnz   .OverlayExist
	ret
.OverlayExist:
	mov   ecx, edx
	shr   ecx, 16
	mov   ax, 4200h
	int   21h

	mov   ds, [buffer]
	xor   dx, dx
.Nr:
	mov   ecx, 08000h
	cmp   ecx, edi
  jb    .NN
	mov   ecx, edi
.NN:
	mov   bx, [cs:ih]
	call  ReadFromFile

	mov   bx, [cs:oh]
	call  WriteToFile
	sub   edi, ecx
  jnz   .Nr
	ret

GetCheckSum:
	add   dx, [es:bp]
	inc   bp
	inc   bp
	cmp   bp, bx
  jb    GetCheckSum
	ret

Decrypt1:
	mov   bx, [es:si]
	xor   bx, ax
	xor   bx, dx
	xor   bx, cx
	mov   [es:si], bx
	inc   si
	inc   si
	cmp   si, di
  jbe   Decrypt1
	ret

Decrypt2:
	mov   ax, [es:si]
	xor   ax, dx
	mov   [es:si], ax
	inc   si
	inc   si
  loop  Decrypt2
	ret

Decrypt3:
	times 26h db 90h
	retn

SearchStringByte:
; cs:ax = searched string
; from es:di to es:dx = searched place
; bx = string length
	mov   bx, [mptr]
	add   word [mptr], byte 2
	mov   ax, [bx]
	mov   bx, [bx+2]
	sub   bx, ax
	lea   bp, [di+bx]
	push  ax
SSByte:
	pop   si
	push  si
	mov   cx, bx	 ; length in bytes
	dec   si
znch:
	inc   si
	stc   ; Found !!!
  jcxz  SSexit

	mov   al, [es:di]
	inc   di
	dec   cx

	cmp   al, [si]
  je    znch

	cmp   byte [si], 0
  jne   fch
  jcxz  znch


	cmp   byte [si+1], 0
  jne   fch

	dec   cx
	inc   si
	inc   di
  jmp   short znch

fch:
	cmp   di, dx	 ; End of Second String
  jb    SSByte
SSexit:
	pop   si
	ret

WriteError:
	PUSH  CS
	POP   DS
	PUSH  AX
	PUSH  SI
	mov   SI,PreError
	CALL  WriteIt
	POP   SI
	CALL  WriteIt
	POP   AX
  jmp   QuitIT

WriteIt:
	CLD
	MOV   AH,02
	WriteItNext:
	LODSB
	CMP   AL,ETX
  JE    WriteItQuit
	MOV   DL,AL
	INT   21H
  JMP   short WriteItNext
	WriteItQuit:
	RET

ExAEP	dw MessageWF, MessageOF
	dw MessageRF, MessageMaskNF
_aepexe:
       dw  _aep01, _aep02, _aep03, _aep04, _aep05, _aep06, _aep07, _aep08
_aepcom:
       dw  _aep09, _aep10, _aep11, _aep12, _aep13, _aep06, _aep14, _aep08

_aep01:
 dd 050EC8B55h,0F6F0210Fh,0850F40C4h,001A800BFh,002A81075h,004A82375h,008A83575h,078E94975h
 dd 0E687FF01h,000F3815Bh,006C72E00h,000000062h,04683E687h,0B0E90102h,05AE78700h,0DA33E687h
 dd 0FC875953h,0F7874E4Eh,001024683h,08B009AE9h,08B2E005Eh,000FB810Fh,02E057300h,000C30E01h
 dd 001024683h
 db 0E9h,082h,000h
_aep02:
 dd 00000368Dh,02E0000B9h,000C3168Bh,04614312Eh
 db 046h,0E2h,0F9h
_aep03:
 dd 01EEC8B55h,0D08B1F0Eh,00000368Dh,02E0000B9h,046461431h,0F0F6F9E2h,064E6ADB0h,00776801Fh
 dd 055CF5D01h,056EC8B52h,04647BE57h,0CC4A4DBFh,04647FE81h,064E6ADB0h,05E5F0B75h,0EC03C0BAh
 dd 074C00B98h,0E6FEB006h,0CDFEEB64h,083D0F707h,080020446h,05A010976h,0BA52CF5Dh,080EC03DAh
 dd 0C0331AF2h
 db 0EEh,05Ah,0CFh
_aep04:
 dd 0A1E6C0FEh,0D38BDB33h,00000368Dh,000003E8Dh,000002E8Dh,045F1FFFFh,02EF145F1h
 db 062h,036h
_aep05:
 dd 033F8210Fh,00000BED0h,02E0000B9h,046461431h
 db 0E2h,0F9h
_aep06:
db 0beh,000h,000h,08bh,0feh,0bah,000h,000h,0bbh,000h,000h,0c0h,00ch
_aep07:
  db 0ach,032h
  db 0c3h,002h,0c6h,032h,0c7h,0f6h,0d0h,032h,0c2h,0f6h,0d8h,0aah,0c0h,044h,0ffh
_aep08:
  db 033h,0dah,033h,0d3h,0e2h,0e5h,08ch,0d8h,005h,000h,00fh,08eh,0d8h,08eh,0c0h
_aep09:
 dd 050EC8B55h,0F6F0210Fh,0850F40C4h,001A800C6h,002A81075h,004A82975h,008A84175h,07DE95475h
 dd 0D08CFF01h,0E687170Eh,000F3815Bh,006C72E00h,000000182h,0D08EE687h,001024683h,08C00B1E9h
 dd 087170ED0h,0E6875AE7h,05953DA33h,04E4EFC87h,0D08EF787h,001024683h,08B0095E9h,08B2E005Eh
 dd 0E4FB810Fh,02E057303h,001E00E01h,001024683h
 db 0EBh,07Eh

_aep10:
 dd 0B90000BEh,08B2E0000h,02E01E016h,046461431h
 db 0E2h,0F9h

_aep11:
 dd 01EEC8B55h,0D08B1F0Eh,0B90000BEh,0312E0000h,0E2464614h,0B0F0F6F9h,01F64E6ADh,001077680h
 dd 05255CF5Dh,05756EC8Bh,0BF4647BEh,081CC4A4Dh,0B04647FEh,07564E6ADh,0BA5E5F0Bh,098EC03C0h
 dd 00674C00Bh,064E6FEB0h,007CDFEEBh,04683D0F7h,076800204h,05D5A0109h,0DABA52CFh,0F280EC03h
 dd 0EEC0331Ah
 db 05Ah,0CFh
_aep12:
 dd 0A1E6C0FEh,0D38BDB33h,0BF0415BEh,0E0BD01DEh,0F1FFFF01h,0F145F145h
 db 02Eh,062h,036h
_aep13:
 dd 08B0000BEh,00000BE0Ch,000BAFE8Bh,00000BB00h,00CC051FCh
_aep14:
	mptr   dw _aepexe
	n   db 0
	o1  dw 0
	o2  dw 0
	o3  dw 0
	ofname	  db  'out.exe', 0
	xAEPCode  db  0
	aepexe	  db  1
	iexe	  db  1
	oexe	  db  0
	@exeheader	db 4dh, 5ah
	@bytes_on_last	dw 0
	@pages_in_file	dw 0
	@relocations	dw 0
	@para_in_head	dw 2
	@min_memory	dw 0
	@max_memory	dw 0
	@ss_reg 	dw 0
	@sp_reg 	dw 0
	@checksum	dw 0
	@ip_reg 	dw 0
	@cs_reg 	dw 0
	@reloctableoff	dw 1ch
	@overlaynumber	dw 0
	@emptystring	resb 20h

fsepsp	 dw 0
    db 0
ff  resb 100h
buffer dw  0
ih     dw  0
oh     dw  0
aeps   dd  0
exesize dd 0
MemoErr 	DB "DOS memory service failed!",ETX

IntroMessage:	DB "ÄÄ[Addition Encode-Protective remover]ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ"
		DB 13,10,"xAEP 0.01b by Oleg Prokhorov, ARR þ  [09-April-2000] þ Mail to: olegpro@mail.ru"
		DB 13,10,"ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ[ USE AT YOUR OWN RISK ]ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ",ETX

PreError	DB 13,10,"Install: ",ETX
UsageMessage	DB 13,10,"Usage: xaep filename",ETX

MessageMaskNF  DB 13,10,"xAEP: AEP signature not found.",ETX
MessageWF	DB 13,10,"xAEP: File writing's failed!",ETX
MessageOF	DB 13,10,"xAEP: File opening's failed!",ETX
MessageRF	DB 13,10,"xAEP: File reading's failed!",ETX

segment stackseg
	  resb	  PM_STACKSIZE	  ; real mode stack
