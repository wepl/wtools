;*---------------------------------------------------------------------------
;  :Program.	Reloc.asm
;  :Contents.	relocate exe to absolut address
;  :Author.	Bert Jahn
;  :EMail.	wepl@kagi.com
;  :Version.	$Id: Reloc.asm 0.9 2012/01/07 00:09:17 wepl Exp wepl $
;  :History.	11.06.96
;		20.06.96 minor
;		11.08.96 BUG register d2 not saved in _AdrHunk and _OffHunk
;			 BUG MemoryFlags was not maked out from Hunk-ID's
;		25.08.96 argument ADR/K uses now _etoi (allows hexadecimal input)
;		17.01.99 recompile because error.i changed
;		02.05.10 FailReloc/S added, fails if exe has relocations and/or
;			 has more than one hunk
;			 symbol hunks fixed
;		06.01.12 missing initialization of aa_failrelocs fixed
;		26.01.15 new option CustReloc
;  :Requires.	OS V37+
;  :Copyright.	© 1996,1997,1998 Bert Jahn, All Rights Reserved
;  :Language.	68000 Assembler
;  :Translator.	Barfly V1.131
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/memory.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i
	INCLUDE	dos/doshunks.i
	
	INCLUDE	macros/ntypes.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars

	STRUCTURE	ArgArray,0
		ULONG	aa_input
		ULONG	aa_output
		ULONG	aa_adr
		ULONG	aa_quiet
		ULONG	aa_failrelocs
		ULONG	aa_custreloc
		LABEL	aa_SIZEOF

	NSTRUCTURE	Globals,0
		NAPTR	gl_execbase
		NAPTR	gl_dosbase
		NAPTR	gl_rdargs
		NSTRUCT	gl_rdarray,aa_SIZEOF
		NLONG	gl_rc
		NALIGNLONG
		NLABEL	gl_SIZEOF

DEFAULT_ADR	= $400

;##########################################################################

Version	 = 0
Revision = 9

	OUTPUT	C:Reloc
	PURE
	BOPT	O+			;enable optimizing
	BOPT	OG+			;enable optimizing
	BOPT	ODc-			;disable mulu optimizing
	BOPT	ODd-			;disable muls optimizing
	BOPT	wo-			;disable optimize warnings
	;BOPT	sa+			;create symbol hunk

	IFND	.passchk
	DOSCMD	"WDate >T:date"
.passchk
	ENDC

VER	MACRO
		sprintx	"Reloc %ld.%ld ",Version,Revision
	INCBIN	"T:date"
	ENDM

		bra	.start
		dc.b	0,"$VER: "
		VER
		dc.b	0
	EVEN
.start

;##########################################################################

		link	GL,#gl_SIZEOF
		move.l	(4).w,(gl_execbase,GL)
		clr.l	(gl_rdarray+aa_output,GL)
		clr.l	(gl_rdarray+aa_adr,GL)
		clr.l	(gl_rdarray+aa_quiet,GL)
		clr.l	(gl_rdarray+aa_failrelocs,GL)
		clr.l	(gl_rdarray+aa_custreloc,GL)
		move.l	#20,(gl_rc,GL)

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
		tst.l	(gl_rdarray+aa_output,GL)
		bne	.1
		move.l	(gl_rdarray+aa_input,GL),(gl_rdarray+aa_output,GL)
.1
		move.l	#DEFAULT_ADR,d0
		move.l	(gl_rdarray+aa_adr,GL),d1
		beq	.set_adr
		move.l	d1,a0
		bsr	_etoi
		tst.b	(a0)			;end of string reached ?
		beq	.set_adr
		moveq	#ERROR_BAD_NUMBER,d1	;otherwise error
		moveq	#0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOPrintFault,a6)
		bra	.badargs
.set_adr	move.l	d0,(gl_rdarray+aa_adr,GL)

		tst.l	(gl_rdarray+aa_quiet,GL)
		bne	.quiet
		lea	(_ver),a0
		bsr	_Print
.quiet

		bsr	_Main

.badargs
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

	NSTRUCTURE	local_main,0
		NAPTR	lm_srcptr
		NULONG	lm_srcsize
		NULONG	lm_destsize
		NULONG	lm_destptr
		NULONG	lm_relocptr
		NULONG	lm_reloc
		NLABEL	lm_SIZEOF

_Main		movem.l	d2/a2/a6,-(a7)
		link	LOC,#lm_SIZEOF
		clr.l	(lm_destptr,LOC)
		clr.l	(lm_relocptr,LOC)

		move.l	(gl_rdarray+aa_input,GL),a0
		pea	.r1
		tst.l	(gl_rdarray+aa_quiet,GL)
		beq	_LoadFileMsg
		bra	_LoadFile
.r1		move.l	d1,(lm_srcsize,LOC)
		move.l	d0,(lm_srcptr,LOC)
		beq	.nosource

chka0	MACRO
		cmp.l	a0,a1
		bls	.corruptexe
	ENDM

		move.l	(lm_srcptr,LOC),a0
		move.l	a0,a1
		add.l	(lm_srcsize,LOC),a1	;A1 = end of buffer
		chka0
		cmp.l	#HUNK_HEADER,(a0)+
		beq	.1
		lea	(_badexe),a0
		bsr	_Print
		bra	.freesource
.1
.nextname	chka0
		move.l	(a0)+,d0
		beq	.noname
		add.l	d0,d0
		add.l	d0,d0
		bmi	.corruptexe
		add.l	d0,a0
		bra	.nextname
.noname		chka0
		move.l	(a0)+,d7		;d7 = Anzahl der Hunks
		tst.l	(gl_rdarray+aa_failrelocs,GL)
		beq	.nomh
		cmp.l	#1,d7
		bne	.failmanyhunks
.nomh		addq.l	#8,a0			;lowhunk + highhunk
		move.l	a0,a3			;A3 = STRUCT hunksize's
		move.l	d7,d0
		moveq	#0,d1
.a		chka0
		move.l	(a0)+,d2
		and.l	#$00ffffff,d2
		lsl.l	#2,d2
		add.l	d2,d1
		subq.l	#1,d0
		bne	.a
		move.l	d1,(lm_destsize,LOC)
		
		move.l	d1,d0
		move.l	#MEMF_CLEAR,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,(lm_destptr,LOC)
		bne	.g
		lea	(_nomem),a0
		bsr	_Print
		bra	.freesource
.g
		tst.l	(gl_rdarray+aa_custreloc,GL)
		beq	.nocr1
		move.l	(lm_destsize,LOC),d0
		lsr.l	#1,d0			;16-bit per reloc
		move.l	#MEMF_ANY,d1
		jsr	(_LVOAllocVec,a6)
		move.l	d0,(lm_reloc,LOC)
		move.l	d0,(lm_relocptr,LOC)
		bne	.nocr1
		lea	(_nomem),a0
		bsr	_Print
		bra	.freedest
.nocr1
		move.l	a3,a0
		add.l	d7,a0
		add.l	d7,a0
		add.l	d7,a0
		add.l	d7,a0			;A0 = source
		move.l	(lm_srcptr,LOC),a1
		add.l	(lm_srcsize,LOC),a1	;A1 = end of buffer
		moveq	#0,d6			;D6 = actual hunk
		
.nexthunk	chka0
		move.l	(a0)+,d0
		and.l	#$00ffffff,d0		;mask MemoryFlags
		cmp.l	#HUNK_NAME,d0		;name
		beq	.addlws
		cmp.l	#HUNK_CODE,d0		;code
		beq	.code
		cmp.l	#HUNK_DATA,d0		;data
		beq	.data
		cmp.l	#HUNK_BSS,d0		;bss
		bne	.n1
		addq.l	#4,a0
		bra	.nexthunk
.n1		cmp.l	#HUNK_RELOC32,d0	;reloc32
		beq	.relocs
		cmp.l	#HUNK_RELOC16,d0	;reloc16
		beq	.relocs
		cmp.l	#HUNK_RELOC8,d0		;reloc8
		beq	.relocs
		cmp.l	#HUNK_EXT,d0		;ext
		beq	.ext
		cmp.l	#HUNK_SYMBOL,d0		;symbol
		beq	.symbol
		cmp.l	#HUNK_DEBUG,d0		;debug
		beq	.addlws
		cmp.l	#HUNK_END,d0		;end
		bne	.badhunk
		
		addq.l	#1,d6
		cmp.l	d6,d7			;last hunk ?
		beq	.endfind
		bra	.nexthunk

.code
.data		chka0
		move.l	d6,d0
		bsr	_AdrHunk
		move.l	a1,a2
		move.l	d0,a1
		move.l	(a0)+,d0
		lsl.l	#2,d0
		move.l	d0,d2
		bsr	_Copy
		beq	.corruptexe
		move.l	a2,a1
		add.l	d2,a0
		bra	.nexthunk

.addlws		chka0
		move.l	(a0)+,d0
		add.l	d0,d0
		add.l	d0,d0
		bmi	.corruptexe
		add.l	d0,a0
		bra	.nexthunk

.relocs		tst.l	(gl_rdarray+aa_failrelocs,GL)
		bne	.failrelocs
		chka0
		move.l	(a0)+,d2	;Anzahl der relocs
		beq	.nexthunk
		chka0
		move.l	(a0)+,d0	;hunk auf den sich relocs beziehen
		bsr	_OffHunk
		move.l	d0,d1		;d1 = address
		move.l	d6,d0
		bsr	_AdrHunk
		move.l	d0,a2
.n		chka0
		move.l	(a0)+,d0
		add.l	d1,(a2,d0.l)

		tst.l	(gl_rdarray+aa_custreloc,GL)
		beq	.nocr2
		add.l	a2,d0
		sub.l	(lm_destptr,LOC),d0
		move.l	(lm_reloc,LOC),a6
		move.w	d0,(a6)+
		move.l	a6,(lm_reloc,LOC)
.nocr2
		sub.l	#1,d2
		bne	.n
		bra	.relocs

.ext		chka0
		move.l	(a0),d0
		beq	.nexthunk
		and.l	#$00ffffff,d0
		add.l	d0,d0
		add.l	d0,d0
		bmi	.corruptexe
		add.l	d0,a0
		move.l	(a0)+,d0
		rol.l	#8,d0
		cmp.b	#1,d0
		beq	.1lw
		cmp.b	#2,d0
		beq	.1lw
		cmp.b	#3,d0
		beq	.1lw
		cmp.b	#129,d0
		beq	.morelw
		cmp.b	#130,d0
		beq	.more1lw
		cmp.b	#131,d0
		beq	.morelw
		cmp.b	#132,d0
		beq	.morelw
		bra	.badext

.1lw		addq.l	#4,a0
		bra	.ext
.more1lw	addq.l	#4,a0
.morelw		chka0
		move.l	(a0)+,d0
		add.l	d0,d0
		add.l	d0,d0
		bmi	.corruptexe
		add.l	d0,a0
		bra	.ext

.symbol		chka0
		move.l	(a0)+,d0
		beq	.nexthunk
		lsl.l	#2,d0
		add.l	d0,a0		;name
		addq.l	#4,a0		;value
		bra	.symbol
.endfind
		tst.l	(gl_rdarray+aa_quiet,GL)
		bne	.quiet
		lea	(_ok),a0
		move.l	(gl_rdarray+aa_adr,GL),-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
.quiet
		move.l	(lm_destsize,LOC),d0
		move.l	(lm_destptr,LOC),a0
		move.l	(gl_rdarray+aa_output,GL),a1
		pea	.r2
		tst.l	(gl_rdarray+aa_quiet,GL)
		beq	_SaveFileMsg
		bra	_SaveFile
.r2		tst.l	d0
		beq	.freereloc

		tst.l	(gl_rdarray+aa_custreloc,GL)
		beq	.success

		move.l	(lm_relocptr,LOC),a0
		move.l	(lm_reloc,LOC),a1
		move.l	a1,d0
		sub.l	a0,d0
		lsr.l	#1,d0		;count of relocs
		move.w	d0,(a1)+
		sub.l	a0,a1
		move.l	a1,d0		;length
		move.l	(gl_rdarray+aa_output,GL),a1
		bsr	_AppendOnFile
		tst.l	d0
		bne	.success
		move.l	(gl_rdarray+aa_output,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVODeleteFile,a6)
		bra	.freereloc

.success	clr.l	(gl_rc,GL)
		bra	.freereloc

.failrelocs	lea	(_failrelocs),a0
		bra	.printfail

.failmanyhunks	lea	(_failmanyhunks),a0
		bra	.printfail

.badext		lea	(_badext),a0
		bra	.printfail

.badhunk	lea	(_badhunk),a0
		bra	.printfail

.corruptexe	lea	(_corruptexe),a0

.printfail	bsr	_Print

.freereloc	move.l	(lm_relocptr,LOC),d0
		beq	.afterfreereloc
		move.l	d0,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afterfreereloc
.freedest	move.l	(lm_destptr,LOC),d0
		beq	.afterfreedest
		move.l	d0,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afterfreedest
.freesource
		move.l	(lm_srcptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.nosource
		unlk	LOC
		movem.l	(a7)+,d2/a2/a6
		rts

; IN:	d0=size a0=src a1=dest
; OUT:	d0=success

_Copy		movem.l	d1/a0-a2/a6,-(a7)

		move.l	(lm_srcptr,LOC),d1
		cmp.l	d1,a0			;check A0
		blo	.shit
		add.l	(lm_srcsize,LOC),d1
		lea	(a0,d0.l),a2
		cmp.l	d1,a2			;check A0+D0
		bhi	.shit

		move.l	(lm_destptr,LOC),d1
		cmp.l	d1,a1			;check A1
		blo	.shit
		add.l	(lm_destsize,LOC),d1
		lea	(a1,d0.l),a2
		cmp.l	d1,a2			;check A1+D0
		bhi	.shit

		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCopyMemQuick,a6)
		moveq	#-1,d0
		bra	.q

.shit		moveq	#0,d0
.q		movem.l	(a7)+,d1/a0-a2/a6
		tst.l	d0
		rts

; get start of hunk im mem
; IN:	d0=hunknumber
; OUT:	d0=address

_AdrHunk	movem.l	d1-d2/a0,-(a7)

		move.l	d0,d1
		move.l	(lm_destptr,LOC),d0
		move.l	a3,a0
		bra	.i
		
.a		move.l	(a0)+,d2
		lsl.l	#8,d2		;remove memory flags
		lsr.l	#6,d2		;multiply by 4 (LongWords)
		add.l	d2,d0		;increase memory pointer
		subq.l	#1,d1
.i		tst.l	d1
		bne	.a

		movem.l	(a7)+,d1-d2/a0
		rts

; get offset of hunk
; IN:	d0=hunknumber
; OUT:	d0=address

_OffHunk	movem.l	d1-d2/a0,-(a7)

		move.l	d0,d1
		move.l	(gl_rdarray+aa_adr,GL),d0
		move.l	a3,a0
		bra	.i
		
.a		move.l	(a0)+,d2
		lsl.l	#8,d2
		lsr.l	#6,d2
		add.l	d2,d0
		subq.l	#1,d1
.i		tst.l	d1
		bne	.a

		movem.l	(a7)+,d1-d2/a0
		rts

;##########################################################################

	INCDIR	Sources:
	INCLUDE	dosio.i
		PrintLn
		PrintArgs
		Print
	INCLUDE	error.i
		PrintError
		PrintErrorDOS
	INCLUDE	files.i
		GetFileName
		LoadFile
		LoadFileMsg
		SaveFile
		SaveFileMsg
		AppendOnFile
	INCLUDE	strings.i
		etoi

;##########################################################################

_ok		dc.b	"file has been relocated to address $%lx",10,0

_badexe		dc.b	"not executable",10,0
_corruptexe	dc.b	"executable is corrupt",10,0
_badhunk	dc.b	"unknown hunk",10,0
_badext		dc.b	"unknown ext resolution",10,0
_nomem		dc.b	"not enough free store",0
_failmanyhunks	dc.b	"executable contains more than one hunk",10,0
_failrelocs	dc.b	"executable contains relocations",10,0

; Operationen
_readargs	dc.b	"read arguments",0
_getfilemem	dc.b	"alloc mem for file",0
_allocdestmem	dc.b	"alloc temp dest mem",0
_openfile	dc.b	"open file",0
_getfilesize	dc.b	"get size of file",0
_readfile	dc.b	"read file",0
_writefile	dc.b	"write file",0

;subsystems
_dosname	dc.b	"dos.library",0

_template	dc.b	"INPUTFILE/A"		;name eines zu ladenden Files
		dc.b	",OUTPUTFILE"		;savefile name
		dc.b	",ADR/K"		;to relocate
		dc.b	",QUIET/S"
		dc.b	",FailRelocs/S"		;fail if program contains relocations
		dc.b	",CustReloc/S"		;create a file with custom relocations at the end of file
		dc.b	0

_ver		VER
		dc.b	10,0

;##########################################################################

	END

