;*---------------------------------------------------------------------------
;  :Program.	sp.asm
;  :Contents.	saves iff picture form dump file created by WHDLoad
;  :Author.	Bert Jahn
;  :EMail.	wepl@kagi.com
;  :Address.	Franz-Liszt-Straße 16, Rudolstadt, 07404, Germany
;  :Version.	$Id: sp.asm 1.0 1998/11/22 13:43:15 jah Exp jah $
;  :History.	13.07.98 started
;		03.08.98 reworked for new dump file
;		12.10.98 cskip added
;		17.01.99 recompile because error.i changed
;  :Requires.	OS V37+
;  :Copyright.	© 1998 Bert Jahn, All Rights Reserved
;  :Language.	68020 Assembler
;  :Translator.	Barfly 2.9
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/memory.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i
	INCLUDE	hardware/custom.i
	
	INCLUDE	whddump.i
	INCLUDE	macros/ntypes.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars

	STRUCTURE	ArgArray,0
		ULONG	aa_output
		ULONG	aa_copstop
		ULONG	aa_height
		ULONG	aa_con0
		ULONG	aa_mod1
		ULONG	aa_mod2
		ULONG	aa_pt1
		ULONG	aa_pt2
		ULONG	aa_pt3
		ULONG	aa_pt4
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
	OUTPUT	C:SP
	SECTION	"",CODE
	MC68020

VER	MACRO
		dc.b	"SP 1.1 "
	DOSCMD	"WDate >t:date"
	INCBIN	"t:date"
		dc.b	" by Wepl"
	ENDM

		bra	.start
		dc.b	"$VER: "
		VER
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

		lea	(_ver),a0
		bsr	_Print

		lea	(gl_rdarray,GL),a0
		moveq	#aa_SIZEOF/4-1,d0
.0		clr.l	(a0)+
		dbf	d0,.0

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
		NAPTR	lm_fileptr
		NULONG	lm_filesize
		NAPTR	lm_header
		NAPTR	lm_cust
		NAPTR	lm_mem
		NULONG	lm_cmapsize
		NULONG	lm_bodysize
		NULONG	lm_destptr
		NSTRUCT	lm_colors,256*3
		NALIGNLONG
		NLABEL	lm_SIZEOF

_Main		movem.l	d2-d7/a2-a3/a6,-(a7)
		link	LOC,#lm_SIZEOF
		
		lea	(lm_colors,LOC),a0
		moveq	#256*3/8-1,d0
.clr4		clr.l	(a0)+
		clr.l	(a0)+
		dbf	d0,.clr4

		lea	(_name),a0
		bsr	_LoadFileMsg
		move.l	d1,(lm_filesize,LOC)
		move.l	d0,(lm_fileptr,LOC)
		beq	.afilefree

		clr.l	(lm_mem,LOC)
		clr.l	(lm_cust,LOC)
		clr.l	(lm_header,LOC)

		cmp.l	#20,d1
		blt	.filefree

		move.l	d0,a0
		cmp.l	#"FORM",(a0)+
		bne	.filefree
		subq.l	#8,d1
		cmp.l	(a0)+,d1
		bne	.filefree
		cmp.l	#ID_WHDD,(a0)+
		bne	.filefree
		subq.l	#4,d1
.idn		move.l	(a0)+,d0
		move.l	(a0)+,d2
		subq.l	#8,d1
		bcs	.filefree
		cmp.l	#ID_CUST,d0
		bne	.id1
		move.l	a0,(lm_cust,LOC)
.id1		cmp.l	#ID_MEM,d0
		bne	.id2
		move.l	a0,(lm_mem,LOC)
.id2		cmp.l	#ID_HEAD,d0
		bne	.id3
		move.l	a0,(lm_header,LOC)
.id3		add.l	d2,a0
		sub.l	d2,d1
		bcs	.filefree
		bne	.idn

		tst.l	(lm_mem,LOC)
		beq	.filefree
		tst.l	(lm_cust,LOC)
		beq	.filefree
		tst.l	(lm_header,LOC)
		beq	.filefree

		move.l	(lm_header,LOC),a0
		move.l	(wdh_BaseMemSize,a0),-(a7)
		pea	(_mem_text)
		bsr	_pf
		addq.l	#8,a7

		move.l	(lm_cust,LOC),a3	;A3 = custom

	;copy color entries
		lea	(color,a3),a0
		lea	(lm_colors,LOC),a1
		moveq	#31,d0
.sc2		move.w	(a0)+,d1
		bfextu	d1{20:4},d2
		mulu	#$11,d2
		move.b	d2,(a1)+
		bfextu	d1{24:4},d2
		mulu	#$11,d2
		move.b	d2,(a1)+
		bfextu	d1{28:4},d2
		mulu	#$11,d2
		move.b	d2,(a1)+
		dbf	d0,.sc2

	;print coplc's
		movem.l	(cop1lc,a3),d0-d1
		movem.l	d0-d1,-(a7)
		pea	(_cop_text)
		bsr	_pf
		add.w	#12,a7
	;dump copper lists
		bsr	_cdis
	;move cop writes to custom table
		bsr	_copwrite

	;overwrite with arguments
		bsr	_withargs

	;depth
		bfextu	(bplcon0,a3){1:3},d6
		bne	.3
		moveq	#8,d6			;D6 = depth
.3
	;height
		bfextu	(diwstrt,a3){0:8},d0
		bfextu	(diwstop,a3){0:8},d5
		tst.b	d5
		bmi	.4
		add.w	#256,d5
.4		sub.l	d0,d5			;D5 = height
	;width
	ifeq 1
		bfextu	(diwstrt,a3){8:8},d0
		bfextu	(diwstop,a3){8:8},d4
		add.w	#256,d4
		sub.l	d0,d4			;D4 = width
	else
		move.w	(ddfstop,a3),d4
		sub.w	(ddfstrt,a3),d4
		addq.w	#8,d4
		add.w	d4,d4			;D4 = width
	endc
		tst.b	(bplcon0,a3)
		bpl	.lores
		add.w	d4,d4
.lores

	;calc pic size
	;FORM+ILBM
		moveq	#12,d7
	;BMHD
		add.l	#28,d7
	;CAMG
		add.l	#12,d7
	;CMAP
		moveq	#1,d0
		lsl.l	d6,d0
		mulu	#3,d0
		move.l	d0,(lm_cmapsize,LOC)
		add.l	d0,d7
		addq.l	#8,d7
	;BODY
		move.l	d4,d0
		add.w	#15,d0
		lsr.l	#4,d0
		add.l	d0,d0
		mulu	d6,d0
		mulu	d5,d0
		move.l	d0,(lm_bodysize,LOC)
		add.l	d0,d7
		addq.l	#8,d7

		movem.l	d4-d6,-(a7)
		pea	_dim_text
		bsr	_pf
		add.w	#16,a7
		
		tst.w	d4
		beq	.adestfree
		tst.w	d5
		beq	.adestfree
		tst.w	d6
		beq	.adestfree

	;get mem
		move.l	d7,d0
		moveq	#MEMF_ANY,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,(lm_destptr,LOC)
		bne	.memok
		moveq	#0,d0
		lea	(_nomem),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.adestfree
.memok
		move.l	d0,a2
		move.l	#"FORM",(a2)+
		move.l	d7,(a2)
		subq.l	#8,(a2)+
		move.l	#"ILBM",(a2)+
	;BMHD
		move.l	#"BMHD",(a2)+
		move.l	#20,(a2)+
		move.w	d4,(a2)+
		move.w	d5,(a2)+
		clr.l	(a2)+			;xpos,ypos
		move.w	d6,d0
		move.b	d0,(a2)+
		clr.b	(a2)+			;mask
		clr.b	(a2)+			;compression
		clr.b	(a2)+			;pad
		clr.w	(a2)+			;trans col
		move.b	#10,(a2)+		;x aspect
		move.b	#11,(a2)+		;y aspect
		move.w	d4,(a2)+		;screen
		move.w	d5,(a2)+
	;CAMG
		move.l	#"CAMG",(a2)+
		move.l	#4,(a2)+
		clr.w	(a2)+
		move.w	(bplcon0,a3),(a2)+
	;CMAP
		move.l	#"CMAP",(a2)+
		move.l	(lm_cmapsize,LOC),d2
		move.l	d2,(a2)+
		lea	(lm_colors,LOC),a0
.cmap		move.w	(a0)+,(a2)+
		subq.l	#2,d2
		bne	.cmap
	;BODY
		move.l	#"BODY",(a2)+
		move.l	(lm_bodysize,LOC),(a2)+
		moveq	#0,d3			;d3 = plane

		move.w	d5,d3			;height

.9		lea	(bplpt,a3),a0
		move.w	d6,d1			;depth
.8		move.l	(a0),a1
		add.l	(lm_mem,LOC),a1
		move.w	d4,d0			;width
		add.w	#15,d0
		lsr.w	#4,d0
.7		move.w	(a1)+,(a2)+
		subq.w	#1,d0
		bne	.7
		sub.l	(lm_mem,LOC),a1
		move.l	a1,(a0)+
		subq.w	#1,d1
		bne	.8
		
		movem.w	(bpl1mod,a3),d0-d1
		lea	(bplpt,a3),a0
		moveq	#4-1,d2
.6		move.l	(a0),a1
		add.w	d0,a1
		move.l	a1,(a0)+
		move.l	(a0),a1
		add.w	d1,a1
		move.l	a1,(a0)+
		dbf	d2,.6
		
		subq.w	#1,d3
		bne	.9

		move.l	d7,d0
		move.l	(lm_destptr,LOC),a0
		move.l	(gl_rdarray+aa_output,GL),d1
		move.l	d1,a1
		bsr	_SaveFileMsg

		move.l	(lm_destptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.adestfree
.filefree
		move.l	(lm_fileptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afilefree
		unlk	LOC
		movem.l	(a7)+,d2-d7/a2-a3/a6
		rts

;##########################################################################

_cdis		moveq	#0,d4
		move.l	(cop1lc,a3),d5		;d5 = lc1
		move.l	(cop2lc,a3),d6		;d6 = lc2

.j1		move.l	d5,a0
.nlc		addq.l	#1,d4
		add.l	(lm_mem,LOC),a0
		
		move.l	d4,-(a7)
		pea	(_copdump_text)
		bsr	_pf
		add.l	#8,a7

.next		bsr	_pa
		cmp.l	#-2,(a0)
		beq	.e
		movem.w	(a0)+,d0-d1
		btst	#0,d0
		beq	.m
		btst	#0,d1
		beq	.w

.s		lsr.w	#1,d0
		ext.l	d0
		ror.l	#7,d0
		lsl.w	#7,d0
		lsr.l	#7,d0
		move.l	d0,-(a7)
		pea	.cskip
		bsr	_pf
		addq.l	#8,a7
		bra	.next

.w		lsr.w	#1,d0
		ext.l	d0
		ror.l	#7,d0
		lsl.w	#7,d0
		lsr.l	#7,d0
		move.l	d0,-(a7)
		pea	.cwait
		bsr	_pf
		addq.l	#8,a7
		bra	.next

.m		addq.w	#2,d0
		cmp.w	(a0),d0
		beq	.lm
		subq.w	#2,d0
		move.w	d0,-(a7)
		move.w	d1,-(a7)
		pea	.cmove
		bsr	_pf
		addq.l	#8,a7
		bsr	_pc
		cmp.w	#fmode,d0
		bhi	.fail
		cmp.w	#copjmp1,d0
		beq	.j1
		cmp.w	#copjmp2,d0
		bne	.next
		move.l	d6,a0
		bra	.nlc

.lm		subq.w	#2,d0
		addq.l	#2,a0
		move.w	d0,d2
		move.w	d1,d0
		move.w	(a0)+,d1
		movem.w	d0-d3,-(a7)
		cmp.w	#cop1lc,d2
		bne	.lm1
		move.l	(a7),d5
.lm1		cmp.w	#cop2lc,d2
		bne	.lm2
		move.l	(a7),d6
.lm2		pea	.clmove
		bsr	_pf
		add.w	#12,a7
		move.w	d2,d0
		bsr	_pc
		bra	.next

.e		pea	.cend
		bsr	_p

.q		moveq	#-1,d0
		rts

.fail		moveq	#0,d0
		rts

.cend		dc.b	"CEND",10,0
.cmove		dc.b	"CMOVE	#$%04x,$%04x	",0
.clmove		dc.b	"CLMOVE	#$%08lx,$%04x",0
.cwait		dc.b	"CWAIT	%d,%d",10,0
.cskip		dc.b	"CSKIP	%d,%d",10,0
	EVEN

;print address
_pa		movem.l	d0-d1/a0-a1,-(a7)
		sub.l	(lm_mem,LOC),a0
		move.l	a0,-(a7)
		pea	.1
		bsr	_pf
		addq.l	#8,a7
		movem.l	(a7)+,_MOVEMREGS
		rts
.1		dc.b	"$%06lx ",0

;print string
_p		movem.l	d0-d1/a0-a1,-(a7)
		move.l	(20,a7),a0
		bsr	_PrintArgs
		movem.l	(a7)+,_MOVEMREGS
		rtd	#4

;printf
_pf		movem.l	d0-d1/a0-a1,-(a7)
		move.l	(20,a7),a0
		lea	(24,a7),a1
		bsr	_PrintArgs
		movem.l	(a7)+,_MOVEMREGS
		rts

;print custom
_pc		movem.l	d0-d1/a0-a1,-(a7)
		bsr	_GetCustomName
		move.l	d0,-(a7)
		pea	.2
		bne	.1
		addq.l	#4,a7
		pea	.3
.1		bsr	_pf
		addq.l	#8,a7
		movem.l	(a7)+,_MOVEMREGS
		rts

.2		dc.b	"	;%s"
.3		dc.b	10,0
	EVEN

;##########################################################################

_copwrite	moveq	#-1,d5
		move.l	(gl_rdarray+aa_copstop,GL),d0
		beq	.cse
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,d5
		add.l	(lm_mem,LOC),d5
.cse
.j1		move.l	(cop1lc,a3),a0
.off		add.l	(lm_mem,LOC),a0

.c1n		cmp.l	#-2,(a0)
		beq	.c1e
		cmp.l	d5,a0
		beq	.c1e
		movem.w	(a0)+,d0-d1
		btst	#0,d0
		bne	.c1n
		cmp.w	#copjmp1,d0
		beq	.j1
		cmp.w	#copjmp2,d0
		bne	.c
		move.l	(cop2lc,a3),a0
		bra	.off
		
.c		cmp.w	#color,d0
		blo	.c1u
		cmp.w	#color+62,d0
		bhi	.c1u

	;color register
		bfextu	(bplcon3,a3){0:3},d2	;bank
		mulu	#256/8*3,d2
		lea	(lm_colors.w,LOC,d2.w),a1
		sub.w	#color,d0
		lsr.w	#1,d0
		mulu	#3,d0
		add.w	d0,a1
		bfextu	d1{20:4},d2
		mulu	#$11,d2
		bfextu	d1{24:4},d3
		mulu	#$11,d3
		bfextu	d1{28:4},d4
		mulu	#$11,d4
		btst	#9,(bplcon3,a3)		;LOCT ?
		bne	.c1l
		move.b	d2,(a1)+
		move.b	d3,(a1)+
		move.b	d4,(a1)
		bra	.c1n
.c1l		bfins	d2,(a1){4:4}
		bfins	d3,(1,a1){4:4}
		bfins	d4,(2,a1){4:4}
		bra	.c1n

.c1u		move.w	d1,(a3,d0.w)
		or.w	#$8080,($200.w,a3,d0.w)
		bra	.c1n
.c1e
		rts

;##########################################################################

_withargs
		move.l	(gl_rdarray+aa_height,GL),d0
		beq	.h
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,d5
.h
		move.l	(gl_rdarray+aa_con0,GL),d0
		beq	.0
		move.l	d0,a0
		bsr	_etoi
		move.w	d0,(bplcon0,a3)
.0
		move.l	(gl_rdarray+aa_mod1,GL),d0
		beq	.1
		move.l	d0,a0
		bsr	_etoi
		move.w	d0,(bpl1mod,a3)
.1		move.l	(gl_rdarray+aa_mod2,GL),d0
		beq	.2
		move.l	d0,a0
		bsr	_etoi
		move.w	d0,(bpl2mod,a3)
.2
		move.l	(gl_rdarray+aa_pt1,GL),d0
		beq	.p1
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,(bplpt,a3)
.p1		move.l	(gl_rdarray+aa_pt2,GL),d0
		beq	.p2
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,(bplpt+4,a3)
.p2		move.l	(gl_rdarray+aa_pt3,GL),d0
		beq	.p3
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,(bplpt+8,a3)
.p3		move.l	(gl_rdarray+aa_pt4,GL),d0
		beq	.p4
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,(bplpt+12,a3)
.p4
		rts

;##########################################################################

	INCDIR	Sources:
	INCLUDE	dosio.i
		PrintArgs
		Print
	INCLUDE	error.i
		PrintErrorDOS
	INCLUDE	files.i
		LoadFileMsg
		SaveFileMsg
	INCLUDE	hardware.i
		GetCustomName
	INCLUDE	strings.i
		etoi

;##########################################################################

_name		dc.b	".whdl_dump",0

_mem_text	dc.b	"BaseMemSize=$%lx",10,0
_cop_text	dc.b	"cop1lc=$%lx cop2lc=$%lx",10,0
_copdump_text	dc.b	"*** copperlist %ld ***",10,0
_badci_text	dc.b	"bad copper instruction: %8lx",10,0
_dim_text	dc.b	"width=%ld height=%ld depth=%ld",10,0

; Errors
_nomem		dc.b	"not enough free store",0

; Operationen
_readargs	dc.b	"read arguments",0

;subsystems
_dosname	dc.b	"dos.library",0

_template	dc.b	"OUTPUTFILE/A"
		dc.b	",cs=copstop/K"
		dc.b	",height/K"
		dc.b	",con0/K"
		dc.b	",mod1/K"
		dc.b	",mod2/K"
		dc.b	",pt1/K"
		dc.b	",pt2/K"
		dc.b	",pt3/K"
		dc.b	",pt4/K"
		dc.b	0

_ver		VER
		dc.b	10,0

;##########################################################################

	END

