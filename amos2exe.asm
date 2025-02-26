;*---------------------------------------------------------------------------
;  :Program.	amos2exe.asm
;  :Contents.	extracts amiga hunk exe from amos-compiled program
;		only second hunk with relocation information from third
;		hunk is extracted
;  :Author.	Bert Jahn
;  :History.	13.10.14 initial
;  :Requires.	OS V37+
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Barfly Vc$2.9
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/memory.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i
	
	INCLUDE	macros/ntypes.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars

	STRUCTURE	ArgArray,0
		ULONG	aa_input
		ULONG	aa_output
		LABEL	aa_SIZEOF

	NSTRUCTURE	Globals,0
		NAPTR	gl_execbase
		NAPTR	gl_dosbase
		NAPTR	gl_rdargs
		NSTRUCT	gl_rdarray,aa_SIZEOF
		NALIGNLONG
		NLABEL	gl_SIZEOF

;##########################################################################

	PURE
	OUTPUT	C:amos2exe
	SECTION	"",CODE,RELOC16

		bra	.start
		dc.b	"$VER: Amos2Exe 1.0 "
	DOSCMD	"WDate >t:date"
	INCBIN	"t:date"
		dc.b	" by Bert Jahn"
		dc.b	" V37+",0
	CNOP 0,2
.start

;##########################################################################

		link	GL,#gl_SIZEOF
		move.l	(4).w,(gl_execbase,GL)

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

	NSTRUCTURE	local_main,0
		NAPTR	lm_srcptr
		NULONG	lm_srcsize
		NULONG	lm_destsize
		NULONG	lm_destptr
		NULONG	lm_relocptr
		NLABEL	lm_SIZEOF

_Main		movem.l	d2-d7/a2-a3/a6,-(a7)
		link	LOC,#lm_SIZEOF
	;load source file
		move.l	(gl_rdarray+aa_input,GL),a0
		bsr	_LoadFileMsg
		move.l	d1,(lm_srcsize,LOC)
		move.l	d0,(lm_srcptr,LOC)
		beq	.end

	;get dest size
		move.l	d0,a0
		cmp.l	#$3f3,(a0)+
		bne	.ff
		tst.l	(a0)+
		bne	.ff
		move.l	(a0)+,d2	;number of hunks
		tst.l	(a0)+		;first hunk
		bne	.ff
		move.l	(a0)+,d0	;last hunk
		addq.l	#1,d0
		cmp.l	d0,d2
		bne	.ff
		cmp.l	#3,d2		;min hunk number
		blo	.ff
		lsl.l	#2,d2
		add.l	d2,a0
		cmp.l	#$3e9,(a0)+
		bne	.ff
		move.l	(a0)+,d0
		and.l	#$ffffff,d0
		lsl.l	#2,d0
		add.l	d0,a0
		cmp.l	#$3f2,(a0)+
		bne	.ff
		cmp.l	#$3e9,(a0)+
		bne	.ff
		move.l	(a0)+,d2
		move.l	a0,a2		;a2 = packed code
		and.l	#$ffffff,d2
		lsl.l	#2,d2		;d2 = packed code size
		add.l	d2,a0
		cmp.l	#$3f2,(a0)+
		bne	.ff
		cmp.l	#$3e9,(a0)+
		bne	.ff
		move.l	(a0)+,d3
		move.l	a0,a3		;a3 = reloc
		and.l	#$ffffff,d3
		lsl.l	#2,d3		;d3 = reloc size
		add.l	d3,a0
		cmp.l	#$3f2,(a0)+
		beq	.fo
.ff		lea	(_badfile),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.afterfreedest
.fo
	;unpacked length
		move.l	d2,d5		;d5 = unpacked code size
		cmp.l	#'xVdg',(a2)
		bne	.pn
		move.l	(4,a2),d5
.pn
	;unpack relocs
		clr.l	(lm_relocptr,LOC)
		cmp.l	#'xVdg',(a3)
		bne	.ro
		move.l	(4,a3),d0
		moveq	#MEMF_ANY,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,(lm_relocptr,LOC)
		bne	.rmemok
		moveq	#0,d0
		lea	(_nomem),a0
		lea	(_allocdestmem),a1
		bsr	_PrintError
		bra	.afterfreedest
.rmemok
		move.l	d0,a1
		addq.l	#8,a3
		move.l	(a3)+,d1	;packed length
		move.l	d1,d2
.rpp		move.l	(a3)+,(a1)+
		subq.l	#4,d2
		bhi	.rpp
		move.l	d0,a3
		movem.l	d0-a6,-(a7)
		move.l	d0,d3
		bsr	UnSquash
		movem.l	(a7)+,d0-a6
.ro
	;count relocs
		move.l	a3,a0
		moveq	#0,d4		;d4 = reloc count
.rn		move.b	(a0)+,d0
		beq	.re
		subq.b	#1,d0
		beq	.rn
		addq.l	#1,d4
		bra	.rn
.re
	;sum
		moveq	#(6+2+4+1)*4,d0
		add.l	d4,d0
		add.l	d4,d0
		add.l	d4,d0
		add.l	d4,d0
		add.l	d5,d0
		move.l	d0,(lm_destsize,LOC)

	;alloc destination mem
		moveq	#MEMF_ANY,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,(lm_destptr,LOC)
		bne	.memok
		moveq	#0,d0
		lea	(_nomem),a0
		lea	(_allocdestmem),a1
		bsr	_PrintError
		bra	.afterfreedest
.memok

	;processing
		move.l	(lm_destptr,LOC),a0
		move.l	#$3f3,(a0)+
		clr.l	(a0)+
		move.l	#1,(a0)+
		clr.l	(a0)+
		clr.l	(a0)+
		move.l	d5,d0
		lsr.l	#2,d0
		move.l	d0,(a0)+
		move.l	#$3e9,(a0)+
		move.l	d0,(a0)+

		cmp.l	#'xVdg',(a2)
		bne	.cp
		addq.l	#8,a2
		move.l	(a2)+,d1	;packed length
		move.l	d1,d0
		move.l	a0,a1
.cpp		move.l	(a2)+,(a1)+
		subq.l	#4,d0
		bhi	.cpp
		movem.l	d0-a6,-(a7)
		move.l	a0,d3
		bsr	UnSquash
		movem.l	(a7)+,d0-a6
		add.l	d5,a0
		bra	.uo
		
.cp		move.l	(a2)+,(a0)+
		subq.l	#4,d2
		bhi	.cp

.uo		move.l	#$3ec,(a0)+
		move.l	d4,(a0)+	;reloc count
		clr.l	(a0)+		;hunk

		moveq	#0,d1
.rel		moveq	#0,d0
		move.b	(a3)+,d0
		beq	.rele
		cmp.b	#1,d0
		bne	.rels
		add.l	#$1fc,d1
		bra	.rel
.rels		add.l	d0,d0
		add.l	d0,d1
		move.l	d1,(a0)+
		bra	.rel
.rele
		clr.l	(a0)+
		move.l	#$3f2,(a0)+

	;save file
		move.l	(lm_destsize,LOC),d0
		move.l	(lm_destptr,LOC),a0
		move.l	(gl_rdarray+aa_output,GL),d1
		bne	.save
		move.l	(gl_rdarray+aa_input,GL),d1
.save		move.l	d1,a1
		bsr	_SaveFileMsg

	;free destination memory
		move.l	(lm_destptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afterfreedest
		move.l	(lm_relocptr,LOC),d0
		beq	.afterfreereloc
		move.l	d0,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afterfreereloc
		move.l	(lm_srcptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)

.end		unlk	LOC
		movem.l	(a7)+,d2-d7/a2-a3/a6
		rts

;##########################################################################
**********************************
*Entry
*	
*	D3 Address
*	D1 Length
*
*Exit
*	D3 Unsquashed Length positive
*	   or 
*	   Error negative:-
*			     -1 Check on data bad!
*			     -2 Unsquasher was going to overwrite
*				memory that was out of bounds!		
UnSquash:
	MOVE.L	D3,D0
	ADD.L	D0,D1
	MOVEA.L	D1,A0
	MOVEA.L	D0,A1
	MOVEA.L	-(A0),A2
	move.l	a2,d7
	ADDA.L	A1,A2
	MOVE.L	-(A0),D5
	MOVE.L	-(A0),D0
	EOR.L	D0,D5
L22446E	LSR.L	#1,D0
	BNE.S	L224476
	BSR	L2244E8
L224476	BCS.S	L2244AE
	MOVEQ	#8,D1
	MOVEQ	#1,D3
	LSR.L	#1,D0
	BNE.S	L224484
	BSR	L2244E8
L224484	BCS.S	L2244D4
	MOVEQ	#3,D1
	CLR.W	D4
L22448A	BSR	L2244F4
	MOVE.W	D2,D3
	ADD.W	D4,D3
L224492	MOVEQ	#7,D1
L224494	LSR.L	#1,D0
	BNE.S	L22449A
	BSR.S	L2244E8
L22449A	ROXL.L	#1,D2
	DBF	D1,L224494
	cmp.l	a1,a2
	ble.b	bad_squash_mem
	MOVE.B	D2,-(A2)
	DBF	D3,L224492
	BRA.S	L2244E0
L2244A8	MOVEQ	#8,D1
	MOVEQ	#8,D4
	BRA.S	L22448A
L2244AE	MOVEQ	#2,D1
	BSR.S	L2244F4
	CMP.B	#2,D2
	BLT.S	L2244CA
	CMP.B	#3,D2
	BEQ.S	L2244A8
	MOVEQ	#8,D1
	BSR.S	L2244F4
	MOVE.W	D2,D3
	MOVE.W	#$C,D1
	BRA.S	L2244D4
L2244CA	MOVE.W	#9,D1
	ADD.W	D2,D1
	ADDQ.W	#2,D2
	MOVE.W	D2,D3
L2244D4	BSR.S	L2244F4
L2244D6	SUBQ.W	#1,A2
	cmp.l	a1,a2
	blt.b	bad_squash_mem
	MOVE.B	0(A2,D2.W),(A2)
	DBF	D3,L2244D6
L2244E0	CMPA.L	A2,A1
	BLT.S	L22446E
	tst.l	d5
	beq.b	check_ok
	moveq.l	#-1,d3
	rts
check_ok:
	move.l	d7,d3
	RTS
bad_squash_mem:
	moveq.l	#-2,d3
	rts

L2244E8	MOVE.L	-(A0),D0
	EOR.L	D0,D5
	MOVE	#$10,CCR
	ROXR.L	#1,D0
	RTS

L2244F4	SUBQ.W	#1,D1
	CLR.W	D2
L2244F8	LSR.L	#1,D0
	BNE.S	L224506
	MOVE.L	-(A0),D0
	EOR.L	D0,D5
	MOVE	#$10,CCR
	ROXR.L	#1,D0
L224506	ROXL.L	#1,D2
	DBF	D1,L2244F8
	RTS

;##########################################################################

	INCDIR	Sources:
	INCLUDE	dosio.i
;		PrintLn
;		PrintArgs
;		Print
	INCLUDE	error.i
;		PrintError
		PrintErrorDOS
	INCLUDE	files.i
		LoadFileMsg
		SaveFileMsg

;##########################################################################

; Errors
_nomem		dc.b	"not enough free store",0

; Operationen
_readargs	dc.b	"read arguments",0
_allocdestmem	dc.b	"alloc temp dest mem",0
_badfile	dc.b	"bad file format",0

;subsystems
_dosname	dc.b	"dos.library",0

_template	dc.b	"INPUTFILE/A"		;name eines zu ladenden Files
		dc.b	",OUTPUTFILE"		;savefile name
		dc.b	0

;##########################################################################

	END

