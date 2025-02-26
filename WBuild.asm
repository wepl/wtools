;*---------------------------------------------------------------------------
;  :Program.	WBuild.asm
;  :Contents.	increases build number in file .build (default name)
;		also prints number to stdout (without line feed)
;  :Author.	Bert Jahn
;  :Version.	$Id: WBuild.asm 1.1 2020/01/29 16:02:43 wepl Exp wepl $
;  :History.	2020-01-27 converted from Oberon source
;			   removed newline from .build file
;			   filename can be specified
;  :Requires.	OS V37+
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.16
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
		ULONG	rda_filename
		LABEL	rda_SIZEOF

BUFLEN = 16

	NSTRUCTURE	Globals,0
		NAPTR	gl_execbase
		NAPTR	gl_dosbase
		NULONG	gl_rc
		NAPTR	gl_rdargs
		NSTRUCT	gl_rdarray,rda_SIZEOF
		NLONG	gl_build
		NSTRUCT	gl_buf,BUFLEN
		NALIGNLONG
		NLABEL	gl_SIZEOF

;##########################################################################

	PURE
	SECTION	"",CODE
	OUTPUT	C:WBuild
	BOPT	O+		;enable optimizing
	BOPT	OG+		;enable optimizing
	BOPT	ODd-		;disable mul optimizing
	BOPT	ODe-		;disable mul optimizing
	BOPT	wo-		;no optimize warnings

VER	MACRO
		dc.b	"WBuild 1.0 "
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
		lea	_def_filename,a0
		move.l	a0,(gl_rdarray+rda_filename,GL)
		clr.l	(gl_build,GL)
		move.l	#RETURN_FAIL,(gl_rc,GL)

		move.l	#37,d0
		lea	(_dosname),a1
		move.l	(gl_execbase,GL),a6
		jsr	_LVOOpenLibrary(a6)
		move.l	d0,(gl_dosbase,GL)
		beq	.nodoslib

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
		bsr	_Main

		move.l	(gl_rdargs,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFreeArgs,a6)
.noargs
		move.l	(gl_dosbase,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.nodoslib
		move.l	(gl_rc,GL),d0
		unlk	GL
		rts

;##########################################################################

_Main		move.l	(gl_rdarray+rda_filename,GL),d1	;name
		move.l	#MODE_READWRITE,d2		;mode
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOOpen,a6)
		move.l	d0,d7				;D7 = fh
		bne	.openok
		lea	(_openfile),a0
		bsr	_PrintErrorDOS
		bra	.erropen
.openok
		move.l	d7,d1				;fh
		lea	(gl_buf,GL),a0
		move.l	a0,d2				;buffer
		move.l	#BUFLEN-1,d3			;length
		jsr	(_LVORead,a6)
		move.l	d0,d6				;D6 = length
		bne	.readok
		jsr	(_LVOIoErr,a6)
		tst.l	d0				;new/empty file?
		beq	.inc
		lea	(_readfile),a0
		bsr	_PrintErrorDOS
		bra	.errread
.readok		clr.b	(gl_buf,GL,d0.l)		;terminate string

		move.l	d2,d1				;buffer
		lea	(gl_build,GL),a0
		move.l	a0,d2
		jsr	(_LVOStrToLong,a6)
		tst.l	d0				;amount chars converted
		bgt	.inc
	;if no chars we assume a wrong file, to avoid corruption cancel the operation
		lea	(_badcontent),a0
		bsr	_Print
		bra	.errread

.inc		addq.l	#1,(gl_build,GL)

	;rewind
		move.l	d7,d1				;fh
		moveq	#0,d2				;offset
		move.l	#OFFSET_BEGINNING,d3		;mode
		jsr	(_LVOSeek,a6)

		move.l	d7,d1				;fh
		lea	_format,a0
		move.l	a0,d2
		lea	(gl_build,GL),a0
		move.l	a0,d3
		jsr	(_LVOVFPrintf,a6)

	;truncate the file
		move.l	d7,d1				;fh
		moveq	#0,d2				;offset
		move.l	#OFFSET_CURRENT,d3		;mode
		jsr	(_LVOSetFileSize,a6)

		lea	_format,a0
		move.l	a0,d1
		lea	(gl_build,GL),a0
		move.l	a0,d2
		jsr	(_LVOVPrintf,a6)

		move.l	#RETURN_OK,(gl_rc,GL)
.errread
		move.l	d7,d1			;fh
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOClose,a6)
.erropen
		rts

;##########################################################################

	INCDIR	Sources:
	INCLUDE	error.i
		PrintErrorDOS
	INCLUDE	strings.i
		Print

;##########################################################################

_readargs	dc.b	"read arguments",0
_openfile	dc.b	"open file",0
_readfile	dc.b	"read file",0
_badcontent	dc.b	"file has non numeric content, aborting",10,0
_dosname	dc.b	"dos.library",0
_template	dc.b	"File"			;file name
		dc.b	0
_def_filename	dc.b	".build",0
_format		dc.b	"%ld",0

;##########################################################################

	END
