;*---------------------------------------------------------------------------
;  :Program.	CRC16.asm
;  :Contents.	calculate CRC16 checksum
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.de
;  :Address.	Clara-Zetkin-Straße 52, Zwickau, 08058, Germany
;  :Version.	$Id: FindAccess.asm 1.2 1999/01/17 14:18:12 jah Exp jah $
;  :History.	08.12.03 started
;  :Requires.	OS V37+
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.16
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/execbase.i
	INCLUDE	exec/memory.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i

	INCLUDE	macros/ntypes.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars

	STRUCTURE	ReadArgsArray,0
		ULONG	rda_file
		ULONG	rda_offset
		ULONG	rda_length
		LABEL	rda_SIZEOF

	NSTRUCTURE	Globals,0
		NAPTR	gl_execbase
		NAPTR	gl_dosbase
		NULONG	gl_rc
		NAPTR	gl_rdargs
		NSTRUCT	gl_rdarray,rda_SIZEOF
		NSTRUCT	gl_crc,256*2
		NALIGNLONG
		NLABEL	gl_SIZEOF

;##########################################################################

	PURE
	SECTION	"",CODE
	OUTPUT	C:CRC16
	BOPT	O+		;enable optimizing
	BOPT	OG+		;enable optimizing
	BOPT	ODd-		;disable mul optimizing
	BOPT	ODe-		;disable mul optimizing
	BOPT	wo-		;no optimize warnings

VER	MACRO
		dc.b	"CRC16 1.1 "
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
		clr.l	(rda_offset+gl_rdarray,GL)
		clr.l	(rda_length+gl_rdarray,GL)
		move.l	#RETURN_FAIL,(gl_rc,GL)

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
		move.l	(gl_rdarray+rda_offset,GL),d0
		beq	.offset_ok
		move.l	d0,a0
		bsr	_etoi
		tst.b	(a0)
		bne	.a_badnum
		move.l	d0,(gl_rdarray+rda_offset,GL)
.offset_ok
		move.l	(gl_rdarray+rda_length,GL),d0
		beq	.a_ok
		move.l	d0,a0
		bsr	_etoi
		tst.b	(a0)
		bne	.a_badnum
		move.l	d0,(gl_rdarray+rda_length,GL)
		bra	.a_ok

.a_badnum	moveq	#ERROR_BAD_NUMBER,d1
		moveq	#0,d2
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
		move.l	(gl_rc,GL),d0
		unlk	GL
		rts

;##########################################################################

	NSTRUCTURE	LocalMain,0
		NALIGNLONG
		NLABEL	lm_SIZEOF

_Main		move.l	(gl_rdarray+rda_file,GL),d1	;name
		move.l	#MODE_OLDFILE,d2		;mode
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOOpen,a6)
		move.l	d0,d7				;D7 = fh
		bne	.openok
		lea	(_readfile),a0
		bsr	_PrintErrorDOS
		bra	.erropen
.openok
		move.l	d7,d1				;fh
		moveq	#0,d2				;offset
		move.l	#OFFSET_END,d3			;mode
		jsr	(_LVOSeek,a6)
		tst.l	d0
		bmi	.seekerr
		move.l	d7,d1				;fh
		moveq	#0,d2				;offset
		move.l	#OFFSET_BEGINNING,d3		;mode
		jsr	(_LVOSeek,a6)
		move.l	d0,d5				;D5 = ULONG file size
		bhi	.seekok
.seekerr	lea	(_seekfile),a0
		bsr	_PrintErrorDOS
		bra	.errseek
.seekok
		cmp.l	(gl_rdarray+rda_offset,GL),d5
		bls	.erroffset
		move.l	(gl_rdarray+rda_length,GL),d0
		beq	.length_ok
		add.l	(gl_rdarray+rda_offset,GL),d0
		cmp.l	d0,d5
		blo	.errlength
.length_ok
		move.l	d5,d0
		sub.l	(gl_rdarray+rda_offset,GL),d0
		move.l	(gl_rdarray+rda_length,GL),d1
		beq	.size_ok
		move.l	d1,d0
.size_ok	move.l	d0,d4				;D4 = ULONG check size
		move.l	#MEMF_ANY,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,d6				;D6 = APTR buffer
		beq	.errmem

		move.l	d7,d1				;fh
		move.l	(gl_rdarray+rda_offset,GL),d2	;offset
		move.l	#OFFSET_BEGINNING,d3		;mode
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOSeek,a6)
		tst.l	d0
		bpl	.seek_ok
		lea	(_readfile),a0
		bsr	_PrintErrorDOS
		bra	.errseek2
.seek_ok
		move.l	d7,d1				;fh
		move.l	d6,d2				;buffer
		move.l	d4,d3				;length
		jsr	(_LVORead,a6)
		cmp.l	d4,d0
		beq	.readok
		lea	(_readfile),a0
		bsr	_PrintErrorDOS
		bra	.errread
.readok
		move.l	d4,d1
		move.l	d6,a0
		bsr	_CRC16
		move.l	d0,(gl_rc,GL)
		lea	(_msg),a0
		move.l	d0,-(a7)
		move.l	d0,-(a7)
		move.l	d4,-(a7)
		move.l	d4,-(a7)
		move.l	(gl_rdarray+rda_offset,GL),-(a7)
		move.l	(gl_rdarray+rda_offset,GL),-(a7)
		move.l	(gl_rdarray+rda_file,GL),-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#7*4,a7
.errread
.errseek2
		move.l	d6,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
		bra	.errseek

.errmem		lea	(_nomem),a0
		bra	.err
.errlength	lea	(_badlength),a0
		bra	.err
.erroffset	lea	(_badoffset),a0
.err		moveq	#0,d0
		lea	(_readfile),a1
		bsr	_PrintError
.errseek		
		move.l	d7,d1			;fh
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOClose,a6)
.erropen
		rts

;---------------------------------------------------------------------------*
; ANSI CRC16
; IN:	d0 = ULONG length
;	a0 = APTR  address
; OUT:	d0 = UWORD crc checksum

_CRC16		movem.l	d2-d3,-(a7)

	;calculate crc-table
		lea	(gl_crc,GL),a1
		moveq	#0,d3
.crc2		move.l	d3,d1
		moveq	#7,d2
.crc3		lsr.w	#1,d1
		bcc	.crc4
		eor.w	#$a001,d1
.crc4		dbf	d2,.crc3
		move.w	d1,(a1)+
		addq.b	#1,d3
		bne	.crc2

		move.l	d0,d1
		beq	.end
		moveq	#0,d0
		moveq	#0,d2
		lea	(gl_crc,GL),a1

.loop		moveq	#0,d2
		move.b	(a0)+,d2
		eor.b	d0,d2
		lsr.w	#8,d0
		add.w	d2,d2
		move.w	(a1,d2.w),d3
		eor.w	d3,d0
		subq.l	#1,d1
		bne	.loop

.end		movem.l	(a7)+,_MOVEMREGS
		rts

;##########################################################################

	INCDIR	Sources:
	INCLUDE	error.i
		PrintErrorDOS
	INCLUDE	strings.i
		Print
		etoi

;##########################################################################

_msg		dc.b	"File '%s' Offset=$%lx=%ld Length=$%lx=%ld CRC16=$%lx=%ld",10,0
_readargs	dc.b	"read arguments",0
_readfile	dc.b	"read file",0
_seekfile	dc.b	"seek file",0
_badoffset	dc.b	"offset is outside the file",0
_badlength	dc.b	"length is larger than file",0
_nomem		dc.b	"not enough memory",0
_dosname	dc.b	"dos.library",0
_template	dc.b	"FILE/A"		;file name
		dc.b	",OFFSET/K"		;offset read from
		dc.b	",LENGTH/K"		;data length for crc
		dc.b	0

_ver		VER
		dc.b	10,0

;##########################################################################

	END

