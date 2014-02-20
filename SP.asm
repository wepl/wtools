;*---------------------------------------------------------------------------
;  :Program.	sp.asm
;  :Contents.	saves iff picture form dump file created by WHDLoad
;  :Author.	Bert Jahn, Philippe Muhlheim
;  :Version.	$Id: SP.asm 1.17 2012/03/21 17:20:26 wepl Exp wepl $
;  :History.	13.07.98 started
;		03.08.98 reworked for new dump file
;		12.10.98 cskip added
;		17.01.99 recompile because error.i changed
;		15.03.99 cop/k and width/k added
;		08.08.00 argument for CopStop will be validated now
;			 CopStop added to the copperlist dump
;		18.03.01 Ctrl-C for copdis added, better error handling
;		31.03.01 support for ehb pictures added
;			 noop added
;		29.09.01 NoCopLst/S added
;			 fmode=3 workaround added (Oxygene/Control titel picture)
;		27.01.02 examines s:whdload.prefs for dump file path
;		14.03.02 support for lace pictures (Psygore)
;		22.02.08 more infos on diwstrt/stop for copper disassembler
;			 output values on cwait exchanged
;		13.05.08 extra infos for bplcon0 added
;			 dumps multiple copper lists if lc1 will be changed
;			 better lace support
;		12.12.10 now checks for 68020 available
;		21.03.12 parsing whdload.prefs fixed
;		18.10.12 support for COLS chunk added
;		20.02.14 using dos.AddPart to form dump file name
;  :Requires.	OS V37+
;  :Language.	68020 Assembler
;  :Translator.	Barfly 2.9
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/execbase.i
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
		ULONG	aa_cop
		ULONG	aa_copstop
		ULONG	aa_width
		ULONG	aa_height
		ULONG	aa_con0
		ULONG	aa_mod1
		ULONG	aa_mod2
		ULONG	aa_pt1
		ULONG	aa_pt2
		ULONG	aa_pt3
		ULONG	aa_pt4
		ULONG	aa_nocoplst
		LABEL	aa_SIZEOF

MAXNAMELEN=256

	NSTRUCTURE	Globals,0
		NAPTR	gl_execbase
		NAPTR	gl_dosbase
		NAPTR	gl_rdargs
		NSTRUCT	gl_rdarray,aa_SIZEOF
		NSTRUCT	gl_name,MAXNAMELEN
		NALIGNLONG
		NLABEL	gl_SIZEOF

;##########################################################################

	PURE
	OUTPUT	C:SP
	SECTION	"",CODE
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	MC68020

VER	MACRO
		dc.b	"SP 1.12 "
	DOSCMD	"WDate >t:date"
	INCBIN	"t:date"
		dc.b	" by Wepl,Psygore"
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

		move.l	(gl_execbase,GL),a0
		btst	#AFB_68020,(AttnFlags+1,a0)
		bne	.cpuok
		lea	(_20req),a0
		bsr	_Print
		bra	.cpufail
.cpuok
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
		move.l	(gl_rdarray+aa_copstop,GL),d0
		beq	.copstop
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,(gl_rdarray+aa_copstop,GL)
		ble	.copstoperr
		tst.b	(a0)
		beq	.copstop
.copstoperr	lea	(_badcopstop),a0
		bsr	_Print
		bra	.opend
.copstop

		bsr	_Main
.opend
		move.l	(gl_rdargs,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFreeArgs,a6)
.noargs
.cpufail
		move.l	(gl_dosbase,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.nodoslib
		unlk	GL
		moveq	#0,d0
		rts

;##########################################################################

_getname	movem.l	d2-d7,-(a7)
		pea	_name

	;load global configuration
		lea	(_cfgname),a0
		move.l	a0,d1
		move.l	#MODE_OLDFILE,d2	;mode
		move.l	(gl_dosbase,GL),a6	;A6 = dosbase
		jsr	(_LVOOpen,a6)
		move.l	d0,d6			;D6 = fh
		beq	.g_end
		move.l	#MAXNAMELEN,d5		;D5 = buffer size
		sub.l	d5,a7			;A7 = buffer

.g_next		move.l	d6,d1			;fh
		move.l	a7,d2			;buffer
		move.l	d5,d3			;buffer size
		bsr	_FGetS
		tst.l	d0
		beq	.g_free
	;remove comments
		move.l	a7,a0
		move.l	a7,a1
.g_sn		move.b	(a0)+,d0
		cmp.b	#";",d0
		bne	.g_sw
		moveq	#0,d0
.g_sw		move.b	d0,(a1)+
		bne	.g_sn
	;remove space and tabs at end of line
		subq.l	#1,a1
.g_sl		subq.l	#1,a1
		cmp.l	a1,a7
		bhi	.g_sc
		cmp.b	#" ",(a1)
		beq	.g_sk
		cmp.b	#"	",(a1)
		bne	.g_sc
.g_sk		clr.b	(a1)
		bra	.g_sl
.g_sc
	;check for contens
		tst.b	(a7)			;empty line
		beq	.g_next

		moveq	#13,d0			;string length
		lea	_cfgid,a0
		move.l	a7,a1			;actual global cfg line
		bsr	_StrNCaseCmp
		tst.l	d0
		bne	.g_next
		
		lea	(13,a7),a0
		lea	(gl_name,GL),a1
		move.l	a1,(a7,d5.l)
.cpy		move.b	(a0)+,(a1)+
		bne	.cpy

		lea	(gl_name,GL),a0
		move.l	a0,d1
		lea	_name,a0
		move.l	a0,d2
		move.l	#MAXNAMELEN,d3
		jsr	(_LVOAddPart,a6)

.g_free		add.l	d5,a7			;free buffer
		move.l	d6,d1
		jsr	(_LVOClose,a6)
.g_end						;end global config
		move.l	(a7)+,a0
		movem.l	(a7)+,_MOVEMREGS
		rts

;##########################################################################

	NSTRUCTURE	local_main,0
		NAPTR	lm_fileptr
		NULONG	lm_filesize
		NAPTR	lm_header
		NAPTR	lm_cust
		NAPTR	lm_mem
		NAPTR	lm_cols
		NULONG	lm_cmapsize
		NULONG	lm_bodysize
		NULONG	lm_destptr
		NSTRUCT	lm_colors,256*3
		NSTRUCT	lm_custlace,512*2	;second custom area
		NWORD	lm_widthskip		;amount of bytes which are displayed
						;but will not be written to dest
		NBYTE	lm_ehb			;extra half brite
		NBYTE	lm_lace			;lace
		NBYTE	lm_custlacetrue		;bool if second custom area is inited
		NALIGNLONG
		NLABEL	lm_SIZEOF

_Main		movem.l	d2-d7/a2-a3/a6,-(a7)
		link	LOC,#lm_SIZEOF
		
		lea	(lm_colors,LOC),a0
		moveq	#256*3/8-1,d0
.clr4		clr.l	(a0)+
		clr.l	(a0)+
		dbf	d0,.clr4

		bsr	_getname
		bsr	_LoadFileMsg
		move.l	d1,(lm_filesize,LOC)	;D1 = dump size
		move.l	d0,(lm_fileptr,LOC)
		beq	.afilefree

		clr.l	(lm_cols,LOC)
		clr.l	(lm_mem,LOC)
		clr.l	(lm_cust,LOC)
		clr.l	(lm_header,LOC)
		clr.b	(lm_custlacetrue,LOC)

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
.idn		move.l	(a0)+,d0		;chunk id
		move.l	(a0)+,d2		;chunk size
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
.id3		cmp.l	#ID_COLS,d0
		bne	.id4
		move.l	a0,(lm_cols,LOC)
.id4		add.l	d2,a0
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
	;copy colors from COLS chunk if available
		move.l	(lm_cols,LOC),d0
		beq	.cols_end
		move.l	d0,a0
		lea	(lm_colors,LOC),a1
		move.w	#255,d0
.cols_lp	move.l	(a0)+,d1
		bfextu	d1{4:4},d2
		bfextu	d1{20:4},d3
		lsl.l	#4,d2
		or.l	d3,d2
		move.b	d2,(a1)+
		bfextu	d1{8:4},d2
		bfextu	d1{24:4},d3
		lsl.l	#4,d2
		or.l	d3,d2
		move.b	d2,(a1)+
		bfextu	d1{12:4},d2
		bfextu	d1{28:4},d3
		lsl.l	#4,d2
		or.l	d3,d2
		move.b	d2,(a1)+
		dbf	d0,.cols_lp
.cols_end

	;print coplc's
		movem.l	(cop1lc,a3),d0-d1
		movem.l	d0-d1,-(a7)
		pea	(_cop_text)
		bsr	_pf
		add.w	#12,a7
	;overwrite with arguments
		move.l	(gl_rdarray+aa_cop,GL),d0
		beq	.ncop
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,(cop1lc,a3)
.ncop
	;dump copper lists
		tst.l	(gl_rdarray+aa_nocoplst,GL)
		bne	.nocoplst
		bsr	_cdis
		tst.l	d0
		beq	.cdis_fail
.nocoplst
	;move cop writes to custom table
		bsr	_copwrite

	;overwrite with arguments
		bsr	_withargs

	;depth
		bfextu	(bplcon0,a3){1:3},d6
		btst	#4,(bplcon0+1,a3)
		beq	.3
		addq.l	#8,d6			;D6 = depth
.3
	;height
		bfextu	(diwstrt,a3){0:8},d0
		bfextu	(diwstop,a3){0:8},d5
		tst.b	d5
		bmi	.4
		add.w	#256,d5
.4		sub.l	d0,d5			;D5 = height

	;check lace
		btst	#2,(bplcon0+1,a3)
		sne	(lm_lace,LOC)
		beq	.nolace
		add.l	d5,d5			;height*2
		tst.b	(lm_custlacetrue,LOC)
		bne	.nolace
		lea	_custlace_missing,a0
		bsr	_Print
		beq	.custlace_missing
.nolace
	;width
		bfextu	(diwstrt,a3){8:8},d0
		bfextu	(diwstop,a3){8:8},d4
		add.w	#256,d4
		sub.l	d0,d4			;D4 = width

		movem.l	d4-d6,-(a7)

		move.w	(ddfstop,a3),d4
		move.w	#$fe,d0
		and.w	d0,d4
		and.w	(ddfstrt,a3),d0
		sub.w	d0,d4
		moveq	#16,d3
		btst	#0,(fmode+1,a3)
		beq	.ddf1
		add.w	d3,d3
.ddf1		btst	#1,(fmode+1,a3)
		beq	.ddf2
		add.w	d3,d3
.ddf2		add.w	d4,d4
		add.w	d3,d4
		subq.w	#1,d3
		not.w	d3
		and.w	d3,d4			;D4 = width

		move.l	d4,-(a7)
		pea	_dimcalc_text
		bsr	_pf
		add.w	#20,a7

		tst.b	(bplcon0,a3)
		bpl	.lores
		add.w	d4,d4
.lores
		move.l	(gl_rdarray+aa_height,GL),d0
		beq	.h
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,d5
.h
		move.w	d4,(lm_widthskip,LOC)
		move.l	(gl_rdarray+aa_width,GL),d0
		beq	.w
		move.l	d0,a0
		bsr	_etoi
		move.l	d0,d4
.w		move.w	(lm_widthskip,LOC),d0
		sub.w	d4,d0
		asr.w	#3,d0
		move.w	d0,(lm_widthskip,LOC)

	;check ehb
		btst	#2,(bplcon2,a3)		;KILLEHB
		beq	.noehb
		move.w	(bplcon0,a3),d0
		and.w	#%1111110001010000,d0
		cmp.w	#%0110000000000000,d0	;HIRES=HAM=DPF=SHRES=0 depth=6
		seq	(lm_ehb,LOC)
.noehb

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
		tst.b	(lm_ehb,LOC)
		beq	.noehb2
		moveq	#1<<5,d0
.noehb2		mulu	#3,d0
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

		lea	(lm_custlace,LOC),a6
		tst.b	(lm_lace,LOC)
		beq	.nolace3
		btst	#7,(vposr,a3)		;short or long frame?
		bne	.nolace3
		exg.l	a3,a6
.nolace3
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
		add.w	(lm_widthskip,LOC),a1
		move.l	a1,(a0)+
		move.l	(a0),a1
		add.w	d1,a1
		add.w	(lm_widthskip,LOC),a1
		move.l	a1,(a0)+
		dbf	d2,.6

		tst.b	(lm_lace,LOC)
		beq	.nolace2
		exg.l	a3,a6
.nolace2
		subq.w	#1,d3
		bne	.9
.end
		move.l	d7,d0
		move.l	(lm_destptr,LOC),a0
		move.l	(gl_rdarray+aa_output,GL),d1
		move.l	d1,a1
		bsr	_SaveFileMsg

		move.l	(lm_destptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.adestfree
.custlace_missing
.cdis_fail
.filefree
		move.l	(lm_fileptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afilefree
		unlk	LOC
		movem.l	(a7)+,d2-d7/a2-a3/a6
		rts

;##########################################################################

_cdis		moveq	#0,d4			;d4 = list number
		move.l	(cop1lc,a3),d5		;d5 = lc1
		move.l	(cop2lc,a3),d6		;d6 = lc2

.j1		move.l	d5,a0
.nlc		addq.l	#1,d4
		add.l	(lm_mem,LOC),a0
		
		move.l	d4,-(a7)
		pea	(_copdump_text)
		bsr	_pf
		add.l	#8,a7

.next
	;check Ctrl-C
		move.l	a0,-(a7)
		bsr	_CheckBreak
		move.l	(a7)+,a0
		tst.l	d0
		bne	.fail
		
	;check memory bounds
		move.l	(lm_mem,LOC),d0
		cmp.l	a0,d0
		bhi	.fail_mem
		move.l	(lm_header,LOC),a1
		add.l	(wdh_BaseMemSize,a1),d0
		subq.l	#4,d0
		cmp.l	a0,d0
		blo	.fail_mem

	;check copstop
		move.l	a0,d0
		sub.l	(lm_mem,LOC),d0
		cmp.l	(gl_rdarray+aa_copstop,GL),d0
		beq	.copstop

		bsr	_pa			;print address
		cmp.l	#-2,(a0)
		beq	.e
		movem.w	(a0)+,d0-d1
		btst	#0,d0
		beq	.m
		btst	#0,d1
		beq	.w

	;skip
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

	;wait
.w		lsr.w	#1,d0
		ext.l	d0
		ror.l	#7,d0
		lsl.w	#7,d0
		lsr.l	#7,d0
		swap	d0
		move.l	d0,-(a7)
		pea	.cwait
		bsr	_pf
		addq.l	#8,a7
		bra	.next

	;move
.m		cmp.w	#diwstrt,d0
		beq	.mw
		cmp.w	#diwstop,d0
		beq	.mw
		cmp.w	#bplcon0,d0
		beq	.mw
		addq.w	#2,d0
		cmp.w	(a0),d0
		beq	.lm
		subq.w	#2,d0
.mw		move.w	d0,-(a7)
		move.w	d1,-(a7)
		pea	.cmove
		bsr	_pf
		addq.l	#8,a7
		bsr	_pc
		cmp.w	#noop,d0
		bhi	.fail_adr
		cmp.w	#copjmp1,d0
		beq	.j1
		cmp.w	#copjmp2,d0
		bne	.next
		move.l	d6,a0
		bra	.nlc

	;move long
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
		move.w	(-6,a0),d1
		bsr	_pc
		bra	.next

.e		pea	.cend
		bsr	_p
		cmp.l	(cop1lc,a3),d5		;has lc1 changed? maybe lace
		bne	.j1

.q		moveq	#-1,d0
		rts
.copstop	lea	(.cs),a0
		bsr	_Print
		bra	.q

.fail		moveq	#0,d0
		rts
.fail_mem	lea	(.mem),a0
		bsr	_Print
		bra	.fail
.fail_adr	lea	(.adr),a0
		bsr	_Print
		bra	.fail

.cend		dc.b	"CEND",10,0
.cmove		dc.b	"CMOVE	#$%04x,$%04x	",0
.clmove		dc.b	"CLMOVE	#$%08lx,$%04x",0
.cwait		dc.b	"CWAIT	%d,%d			;v,h",10,0
.cskip		dc.b	"CSKIP	%d,%d",10,0
.mem		dc.b	"copperlist outside BaseMem!",10,0
.adr		dc.b	"invalid CMOVE destination!",10,0
.cs		dc.b	"*** copstop ***",10,0
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
	EVEN

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
		tst.l	d0
		beq	.end
		move.l	d0,-(a7)
		pea	.2
		bsr	_pf
		addq.l	#8,a7
		cmp.w	#diwstrt,(2,a7)
		bne	.nodiwstrt
		moveq	#0,d0
		move.w	(6,a7),d0
		ror.l	#8,d0
		lsl.w	#8,d0
		lsr.l	#8,d0
.diw		swap	d0
		move.l	d0,-(a7)
		pea	.diwstrt
		bsr	_pf
		addq.l	#8,a7
		bra	.end
.nodiwstrt	cmp.w	#diwstop,(2,a7)
		bne	.nodiwstop
		moveq	#0,d0
		move.w	(6,a7),d0
		ror.l	#8,d0
		lsl.w	#8,d0
		lsr.l	#8,d0
		or.l	#256<<16,d0	;set h8
		btst	#7,d0
		bne	.diw
		or.w	#256,d0		;set v8
		bra	.diw
.nodiwstop	cmp.w	#bplcon0,(2,a7)
		bne	.nobplcon0
		move.w	(6,a7),d0
		bfextu	d0{31-2:1},d1
		move	d1,-(a7)
		bfextu	d0{31-9:1},d1
		move	d1,-(a7)
		bfextu	d0{31-10:1},d1
		move	d1,-(a7)
		bfextu	d0{31-11:1},d1
		move	d1,-(a7)
		bfextu	d0{31-14:3},d1
		btst	#4,d0
		beq	.nobpl3
		bset	#3,d1
.nobpl3		move	d1,-(a7)
		bfextu	d0{31-15:1},d1
		move	d1,-(a7)
		pea	.bplcon0
		bsr	_pf
		add.w	#6*2+4,a7
.nobplcon0
.end		pea	.3
		bsr	_p
		movem.l	(a7)+,_MOVEMREGS
		rts

.2		dc.b	"	;%s",0
.3		dc.b	10,0
.diwstrt	dc.b	" v=%d h=%d",0
.bplcon0	dc.b	" 15:hires=%d 14-12,4:bpu=%d 11:ham=%d 10:dpf=%d 9:color=%d 2:lace=%d",0
	EVEN

;##########################################################################

_copwrite
		move.l	(cop1lc,a3),d5		;d5 = lc1
		move.l	(cop2lc,a3),d6		;d6 = lc2

		moveq	#-1,d7			;d7 = copstop
		move.l	(gl_rdarray+aa_copstop,GL),d0
		beq	.cse
		move.l	d0,d7
		add.l	(lm_mem,LOC),d7
.cse
.j1		move.l	(cop1lc,a3),a0
.off		add.l	(lm_mem,LOC),a0

.c1n		cmp.l	#-2,(a0)
		beq	.c1e
		cmp.l	d7,a0			;copstop
		beq	.c1s
		movem.w	(a0)+,d0-d1
		btst	#0,d0			;skip/wait
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
		cmp.l	(cop1lc,a3),d5		;has lc1 changed? maybe lace
		beq	.c1s
	;copy custom
		move.l	a3,a0
		lea	(lm_custlace,LOC),a3
		move.l	a3,a1
		move.w	#512/2-1,d0
.copy		move.l	(a0)+,(a1)+
		dbf	d0,.copy
		st	(lm_custlacetrue,LOC)
		bra	.j1
.c1s
		move.l	(lm_cust,LOC),a3
		rts

;##########################################################################

_withargs
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
		CheckBreak
		FGetS
	INCLUDE	error.i
		PrintErrorDOS
	INCLUDE	files.i
		LoadFileMsg
		SaveFileMsg
	INCLUDE	hardware.i
		GetCustomName
	INCLUDE	strings.i
		etoi
		StrNCaseCmp
		AppendString

;##########################################################################

_cfgname	dc.b	"s:whdload.prefs",0
_cfgid		dc.b	"coredumppath=",0
_name		dc.b	".whdl_dump",0

_mem_text	dc.b	"BaseMemSize=$%lx",10,0
_cop_text	dc.b	"cop1lc=$%lx cop2lc=$%lx",10,0
_copdump_text	dc.b	"*** copperlist %ld ***",10,0
_badci_text	dc.b	"bad copper instruction: %8lx",10,0
_dim_text	dc.b	"using: width=%ld height=%ld depth=%ld",10,0
_dimcalc_text	dc.b	"calculated: ddfwidth=%ld diwwidth=%ld height=%ld depth=%ld",10,0

; Errors
_nomem		dc.b	"not enough free store",0
_badcopstop	dc.b	"invalid argument for CopStop",10,0
_custlace_missing dc.b	"custlace table is missing for lace picture",10,0

; Operationen
_readargs	dc.b	"read arguments",0

;subsystems
_dosname	dc.b	"dos.library",0

_template	dc.b	"OutputFile/A"
		dc.b	",Cop/K"
		dc.b	",CS=CopStop/K"
		dc.b	",W=Width/K"
		dc.b	",H=Height/K"
		dc.b	",con0/K"
		dc.b	",mod1/K"
		dc.b	",mod2/K"
		dc.b	",pt1/K"
		dc.b	",pt2/K"
		dc.b	",pt3/K"
		dc.b	",pt4/K"
		dc.b	",NCL=NoCopList/S"
		dc.b	0

_20req		dc.b	"Sorry, this program requires at least a 68020.",10,0
_ver		VER
		dc.b	10,0

;##########################################################################

	END

