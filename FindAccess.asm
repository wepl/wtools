;*---------------------------------------------------------------------------
;  :Program.	FindAccess.asm
;  :Contents.	Search for access to a given address
;  :Author.	Bert Jahn
;  :History.	08.02.96
;		31.03.97 bug removed, scanning out of range
;		17.01.99 recompile because error.i changed
;		2025-02-26 imported to wtools
;  :Requires.	OS V37+
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Barfly V1.131
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
		ULONG	rda_input
		ULONG	rda_adr
		ULONG	rda_org
		LABEL	rda_SIZEOF

	NSTRUCTURE	Globals,0
		NAPTR	gl_execbase
		NAPTR	gl_dosbase
		NAPTR	gl_rdargs
		NSTRUCT	gl_rdarray,rda_SIZEOF
		NALIGNLONG
		NLABEL	gl_SIZEOF

;##########################################################################

	IFD BARLFY
	PURE
	OUTPUT	C:FindAccess
	ENDC


VER	MACRO
		dc.b	"FindAccess 1.3 "
	INCBIN	".date"
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
		clr.l	(rda_org+gl_rdarray,GL)

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

		move.l	(gl_rdarray+rda_org,GL),d0
		beq	.a_ok
		move.l	d0,a0
		bsr	_etoi
		tst.b	(a0)
		bne	.a_badnum
		move.l	d0,(gl_rdarray+rda_org,GL)
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

	NSTRUCTURE	LocalMain,0
		NALIGNLONG
		NLABEL	lm_SIZEOF

_Main		link	LOC,#lm_SIZEOF
		move.l	(gl_rdarray+rda_input,GL),a0
		bsr	_LoadFileMsg
		move.l	d0,D6			;D6 = src ptr
		beq	.end
		move.l	d1,d7			;D7 = src size
		
		lea	(_msg),a0
		move.l	(gl_rdarray+rda_org,GL),-(a7)
		add.l	d7,(a7)
		move.l	(gl_rdarray+rda_org,GL),-(a7)
		move.l	(gl_rdarray+rda_adr,GL),-(a7)
		move.l	(a7),-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#16,a7
		
		move.l	d6,d5		;scan point
		
.loop		bsr	_CheckBreak
		tst.l	d0
		bne	.free
		move.l	(gl_rdarray+rda_adr,GL),d0
		move.l	d5,d1
		sub.l	d6,d1
		add.l	(gl_rdarray+rda_org,GL),d1	;offset
		move.l	d5,a0		;buffer
		move.l	d6,a1
		add.l	d7,a1		;end
		sub.l	a2,a2		;registers
		bsr	_FindAccess
		move.l	d1,d4			;D4 = at address found
		move.l	d1,d5
		cmp.w	#FA_nothing,d0
		beq	.free
		cmp.w	#FA_AbsL,d0
		beq	.AbsL
		cmp.w	#FA_AbsW,d0
		beq	.AbsW
		cmp.w	#FA_RelL,d0
		beq	.RelL
		cmp.w	#FA_RelW,d0
		beq	.RelW
		cmp.w	#FA_RelB,d0
		beq	.RelB
		bra	.free

.AbsL		lea	(_Abs),a0
		lea	(_foundL),a2
		addq.l	#4,d5
		bra	.all
.AbsW		lea	(_Abs),a0
		lea	(_foundW),a2
		addq.l	#2,d5
		bra	.all
.RelL		lea	(_Rel),a0
		lea	(_foundL),a2
		addq.l	#4,d5
		bra	.all
.RelW		lea	(_Rel),a0
		lea	(_foundW),a2
		addq.l	#2,d5
		bra	.all
.RelB		lea	(_Rel),a0
		lea	(_foundB),a2
		addq.l	#2,d5

.all		bsr	_Print
		move.l	a2,a0
		move.l	d4,a1
		add.w	#12,a1
		move.l	-(a1),-(a7)
		move.l	-(a1),-(a7)
		move.w	-(a1),-(a7)
		moveq	#0,d0
		move.b	-(a1),d0
		move.w	d0,-(a7)
		move.b	-(a1),d0
		move.w	d0,-(a7)
		move.l	-(a1),-(a7)
		move.l	-(a1),-(a7)
		move.l	d4,-(a7)
		sub.l	d6,(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#6*4+2,a7
		bra	.loop
.free
		move.l	d6,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.end
		unlk	LOC
		rts

;----------------------------------------
; IN:	D0 = LONG address to search
;	D1 = LONG address on which the buffer was relocted original
;			(offset from buffer start to real address "zero")
;	A0 = APTR buffer start
;	A1 = APTR buffer end
;	A2 = STRUCT array of LONG's = registers D0-A7 (or NIL)
; OUT:	D0 = LONG result
;	D1 = LONG address of access

FA_nothing	= 0
FA_AbsL		= 1
FA_AbsW		= 2
FA_RelB		= 3
FA_RelW		= 4
FA_RelL		= 5

_FindAccess	movem.l	d2-d7,-(a7)
	;make a0 even (up round)
		move.l	a0,d2
		addq.l	#1,d2
		and.b	#$fe,d2
		move.l	d2,a0
	;make a1 even (down round)
		move.l	a1,d2
		and.b	#$fe,d2
		move.l	d2,a1
	;check for buffer >= 4 bytes
		move.l	a1,d2
		sub.l	a0,d2
		bcs	.nothing
		cmp.l	#4,d2
		blo	.nothing

	;check for "AbsW" possible
		moveq	#%110,d7	;D7 = status
		cmp.l	#$7fff,d0
		bgt	.abswno
		cmp.l	#-$8000,d0
		blt	.abswno
		bset	#0,d7		;D7.0 = AbsW possible
.abswno
		neg.l	d1
		add.l	d0,d1		;D1 = distance to searched address relative to contens d2
		move.l	d1,d3
		addq.l	#4,d1		;D1 = distance + 4
		addq.l	#2,d3		;D3 = distance + 2

		move.w	(a0)+,d2
		subq.l	#2,d1
		subq.l	#2,d3
	;here all checks for WORD+BYTE for first word only
	;absolut word
.1AbsW		btst	#0,d7
		beq	.1relW
		cmp.w	d0,d2
		bne	.1relW
		moveq	#FA_AbsW,d0
		move.l	a0,d1
		subq.l	#2,d1
		bra	.end
	;relative word
.1relW		cmp.l	#-$8000,d3
		blt	.1relend
		cmp.l	#$7fff,d3
		bgt	.1relend
		cmp.w	d3,d2
		bne	.1relB
		moveq	#FA_RelW,d0
		move.l	a0,d1
		subq.l	#2,d1
		bra	.end
	;relative byte
.1relB		cmp.w	#-$80,d3
		blt	.1relend
		cmp.w	#$7f,d3
		bgt	.1relend
		cmp.b	d3,d2
		bne	.1relend
		moveq	#FA_RelB,d0
		move.l	a0,d1
		subq.l	#2,d1
		bra	.end
.1relend
		bra	.next		;perhaps buffer = 2 byte !
		
.loop		swap	d2
		move.w	(a0)+,d2
		subq.l	#2,d1
		subq.l	#2,d3
	;absolut long
.AbsL		cmp.l	d0,d2
		bne	.AbsW
		moveq	#FA_AbsL,d0
		move.l	a0,d1
		subq.l	#4,d1
		bra	.end
	;absolut word
.AbsW		btst	#0,d7
		beq	.relL
		cmp.w	d0,d2
		bne	.relL
		moveq	#FA_AbsW,d0
		move.l	a0,d1
		subq.l	#2,d1
		bra	.end
	;relative long
.relL		cmp.l	d1,d2
		bne	.relW
		moveq	#FA_RelL,d0
		move.l	a0,d1
		subq.l	#4,d1
		bra	.end
	;relative word
.relW		btst	#1,d7		;D7.1 = RelW possible
		beq	.relend
		cmp.l	#-$8000,d3
		bge	.relW_1
		bclr	#1,d7
		bra	.relend
.relW_1		cmp.l	#$7fff,d3
		bgt	.relend
		cmp.w	d3,d2
		bne	.relB
		moveq	#FA_RelW,d0
		move.l	a0,d1
		subq.l	#2,d1
		bra	.end
	;relative byte
.relB		btst	#2,d7		;D7.2 = RelB possible
		beq	.relend
		cmp.w	#-$80,d3
		bge	.relB_1
		bclr	#2,d7
		bra	.relend
.relB_1		cmp.w	#$7f,d3
		bgt	.relend
		cmp.b	d3,d2
		bne	.relend
		moveq	#FA_RelB,d0
		move.l	a0,d1
		subq.l	#2,d1
		bra	.end
.relend

.next		cmp.l	a0,a1
		bhi	.loop

.nothing	moveq	#FA_nothing,d0

.end		movem.l	(a7)+,d2-d7
		rts

;##########################################################################

	INCLUDE	dosio.i
		CheckBreak
	INCLUDE	error.i
		PrintErrorDOS
	INCLUDE	files.i
		LoadFileMsg
	INCLUDE	strings.i
		etoi

;##########################################################################

_Abs		dc.b	"Absolut  ",0
_Rel		dc.b	"Relative ",0
_foundL		dc.b	" Long at $%6lx -> %08lx %08lx ",155,"1m%02x%02x%04x",155,"22m %08lx %08lx",10,0
_foundW		dc.b	" Word at $%6lx -> %08lx %08lx ",155,"1m%02x%02x",155,"22m %08lx %08lx",10,0
_foundB		dc.b	" Byte at $%6lx -> %08lx %08lx %02x",155,"1m%02x",155,"22m %08lx %08lx",10,0

_msg		dc.b	"scanning accesses to $%lx (%ld)  file: $%lx-$%lx",10,0
_readargs	dc.b	"read arguments",0
_dosname	dc.b	"dos.library",0
_template	dc.b	"FILE/A"		;name eines zu ladenden Files
		dc.b	",ADDRESS/A"		;to search
		dc.b	",ORG"			;orginal address of file (def = 0)
		dc.b	0

_ver		VER
		dc.b	10,0

;##########################################################################

	END

