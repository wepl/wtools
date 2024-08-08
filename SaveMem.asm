;*---------------------------------------------------------------------------
;  :Program.	SaveMem.asm
;  :Contents.	write memory to a file
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.de
;  :History.	2024-08-08 created
;  :Requires.	OS V37+
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.16, vasm
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i

	INCLUDE	macros/ntypes.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars

	STRUCTURE	ReadArgsArray,0
		CPTR	rda_name
		APTR	rda_adr
		ULONG	rda_size
		LABEL	rda_SIZEOF

	NSTRUCTURE	Globals,0
		NAPTR	gl_execbase
		NAPTR	gl_dosbase
		NAPTR	gl_rdargs
		NSTRUCT	gl_rdarray,rda_SIZEOF
		NALIGNLONG
		NLABEL	gl_SIZEOF

;##########################################################################

	IFD BARFLY
	PURE
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	ENDC

VER	MACRO
		dc.b	"SaveMem 1.0 "
	DOSCMD	"WDate >t:date"
	INCBIN	"t:date"
		dc.b	" by Bert Jahn"
	ENDM

		bra	.start
		dc.b	"$VER: "
		VER
		dc.b	" V37+"
	CNOP 0,2
.start

;##########################################################################

		link	GL,#gl_SIZEOF		;GL = PubMem
		move.l	(4),(gl_execbase,GL)

		move.l	#37,d0
		lea	(_dosname),a1
		move.l	(gl_execbase,GL),a6
		jsr	_LVOOpenLibrary(a6)
		move.l	d0,(gl_dosbase,GL)
		beq	.nodoslib

		lea	(_ver),a0
		bsr	_Print

		lea	(_template),a0
		move.l	a0,d1
		lea	(gl_rdarray,GL),a0
		move.l	a0,d2
		moveq	#0,d3
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOReadArgs,a6)
		move.l	d0,(gl_rdargs,GL)
		bne	.argsok
		lea	(_readargs),a0
		bsr	_PrintErrorDOS
		bra	.noargs
.argsok
		move.l	(gl_rdarray+rda_adr,GL),a0
		bsr	_etoi
		tst.b	(a0)
		bne	.a_badnum
		move.l	d0,(gl_rdarray+rda_adr,GL)

		move.l	(gl_rdarray+rda_size,GL),a0
		bsr	_etoi
		tst.b	(a0)
		bne	.a_badnum
		move.l	d0,(gl_rdarray+rda_size,GL)
		bra	.a_ok

.a_badnum	moveq	#ERROR_BAD_NUMBER,d1
		moveq	#0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOPrintFault,a6)
		bra	.opend
.a_ok
		bsr	_Main
.opend
		move.l	(gl_rdargs,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFreeArgs,a6)
.noargs
		move.l	(gl_dosbase,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.nodoslib
		unlk	GL
		moveq	#0,d0
		rts

;##########################################################################

_Main		move.l	(gl_rdarray+rda_size,GL),d0
		move.l	(gl_rdarray+rda_adr,GL),a0
		move.l	(gl_rdarray+rda_name,GL),a1
		bra	_SaveFileMsg

;##########################################################################

	INCDIR	Sources:
	INCLUDE	dosio.i
		Print
		PrintArgs
	INCLUDE	error.i
		PrintErrorDOS
	INCLUDE	files.i
		SaveFileMsg
	INCLUDE	strings.i
		etoi

;##########################################################################

_readargs	dc.b	"read arguments",0
_dosname	dc.b	"dos.library",0
_template	dc.b	"Name/A"		;filename to write
		dc.b	",Address/A"		;start address
		dc.b	",Size/A"		;amount of bytes to write
		dc.b	0

_ver		VER
		dc.b	10,0

;##########################################################################

	END
