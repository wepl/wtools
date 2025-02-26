;*---------------------------------------------------------------------------
;  :Program.	bin2pic.asm
;  :Contents.	Bin 2 IFF-pic
;  :Author.	Bert Jahn
;  :History.	V 0.1 17.10.95
;		0.2	13.01.96 anpassung auf macros
;		0.3	02.03.96 cf2 support added
;		0.4	20.05.96 chaoseng added / buf with extcols removed
;		0.5	17.02.04 Pinball Wizard ("Unit") added
;		15.06.08 cf1 support added
;		2019-11-01 support for Poker Nights added
;		2020-06-01 pf_offsetcols changed from word to long
;		2021-11-28 fixed init of aa_inleav, more info output
;		2025-02-26 imported to wtools
;  :Requires.	OS V37+
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Barfly V1.128
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
		ULONG	aa_inleav
		LABEL	aa_SIZEOF

	NSTRUCTURE	Globals,0
		NAPTR	gl_execbase
		NAPTR	gl_dosbase
		NAPTR	gl_rdargs
		NSTRUCT	gl_rdarray,aa_SIZEOF
		NALIGNLONG
		NLABEL	gl_SIZEOF

;##########################################################################

	IFD BARLFY
	PURE
	OUTPUT	C:Bin2Pic
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	BOPT	sa+				;write symbol hunks
	ENDC

VER	MACRO
		dc.b	"bin2pic 0.9 "
	INCBIN	".date"
		dc.b	" by Bert Jahn"
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
		clr.l	(gl_rdarray+aa_output,GL)
		clr.l	(gl_rdarray+aa_inleav,GL)

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

	STRUCTURE	PicFmt,0
		APTR	pf_succ
		ULONG	pf_size
		UWORD	pf_flags
		UWORD	pf_depth
		UWORD	pf_width
		UWORD	pf_height
		UWORD	pf_offsetpic
		ULONG	pf_offsetcols
		APTR	pf_cols
		LABEL	pf_SIZEOF

	BITDEF	PFF,OWNCOLS,0		;own color table is in file
	BITDEF	PFF,HAM,1		;picture is in HAM
	BITDEF	PFF,INLEAV,2		;source picture is already interleaved saved
	BITDEF	PFF,EXTCOLS,3		;extern palettefile
	BITDEF	PFF,FIXCOLS,4		;fix colors via pf_cols

_picfmts
.ce		dc.l	.ab3d		;next		;converted own first 32 cols + 320x200x5
		dc.l	40064		;size
		dc.w	PFFF_OWNCOLS	;flags
		dc.w	5		;depth
		dc.w	320		;width
		dc.w	200		;height
		dc.w	64		;offset pic
		dc.l	0		;offset cols
.ab3d		dc.l	.cf1a		;next
		dc.l	71680		;size
		dc.w	0		;flags
		dc.w	8		;depth
		dc.w	320		;width
		dc.w	224		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.cf1a		dc.l	.cf1b		;next
		dc.l	41152		;size
		dc.w	0		;flags
		dc.w	4		;depth
		dc.w	320		;width
		dc.w	256		;height
		dc.w	32		;offset pic
		dc.l	0		;offset cols
.cf1b		dc.l	.cf2f		;next
		dc.l	51464		;size
		dc.w	0		;flags
		dc.w	5		;depth
		dc.w	320		;width
		dc.w	256		;height
		dc.w	64		;offset pic
		dc.l	0		;offset cols
.cf2f		dc.l	.cf2e		;next
		dc.l	40960		;size
		dc.w	PFFF_EXTCOLS	;flags
		dc.w	4		;depth
		dc.w	320		;width
		dc.w	256		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.cf2e		dc.l	.cf2d		;next
		dc.l	53760		;size
		dc.w	PFFF_EXTCOLS	;flags
		dc.w	4		;depth
		dc.w	320		;width
		dc.w	336		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.cf2d		dc.l	.cf2c		;next
		dc.l	67200		;size
		dc.w	PFFF_EXTCOLS	;flags
		dc.w	5		;depth
		dc.w	320		;width
		dc.w	336		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.cf2c		dc.l	.cf2b		;next
		dc.l	53920		;size
		dc.w	PFFF_EXTCOLS	;flags
		dc.w	4		;depth
		dc.w	320		;width
		dc.w	337		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.cf2b		dc.l	.cf2a		;next
		dc.l	36000		;size
		dc.w	PFFF_EXTCOLS	;flags
		dc.w	3		;depth
		dc.w	320		;width
		dc.w	300		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.cf2a		dc.l	.cf2		;next
		dc.l	51400		;size
		dc.w	PFFF_EXTCOLS	;flags
		dc.w	5		;depth
		dc.w	320		;width
		dc.w	257		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.cf2		dc.l	.dsa2		;next
		dc.l	41120		;size
		dc.w	PFFF_EXTCOLS	;flags
		dc.w	4		;depth
		dc.w	320		;width
		dc.w	257		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols

.dsa2		dc.l	.dsa		;next
		dc.l	46400		;size
		dc.w	0	;flags
		dc.w	4		;depth
		dc.w	320		;width
		dc.w	290		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.dsa		dc.l	.beast2		;next
		dc.l	48000		;size
		dc.w	PFFF_INLEAV	;flags
		dc.w	6		;depth
		dc.w	320		;width
		dc.w	200		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
	;Shadow of the beast
.beast2		dc.l	.beast		;next
		dc.l	24000		;size
		dc.w	0		;flags
		dc.w	3		;depth
		dc.w	320		;width
		dc.w	200		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
.beast		dc.l	.rc2		;next
		dc.l	40000		;size
		dc.w	0		;flags
		dc.w	5		;depth
		dc.w	320		;width
		dc.w	200		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
	;Robocop 2
.rc2		dc.l	.rc2_f		;next
		dc.l	42368		;size
		dc.w	PFFF_OWNCOLS|PFFF_HAM	;flags
		dc.w	6		;depth
		dc.w	320		;width
		dc.w	176		;height
		dc.w	128		;offset pic
		dc.l	0		;offset cols
.rc2_f		dc.l	.rc2_small	;next
		dc.l	61568		;size
		dc.w	PFFF_OWNCOLS|PFFF_HAM	;flags
		dc.w	6		;depth
		dc.w	320		;width
		dc.w	256		;height
		dc.w	128		;offset pic
		dc.l	0		;offset cols
.rc2_small	dc.l	.rc3		;next
		dc.l	32034		;size
		dc.w	PFFF_OWNCOLS	;flags
	;	dc.w	PFFF_OWNCOLS|PFFF_HAM	;flags
		dc.w	4		;depth
		dc.w	320		;width
		dc.w	200		;height
		dc.w	34		;offset pic
		dc.l	2		;offset cols
	;Robocop 3
.rc3		dc.l	.wip		;next
		dc.l	32032		;size
		dc.w	PFFF_OWNCOLS|PFFF_INLEAV	;flags
		dc.w	4		;depth
		dc.w	320		;width
		dc.w	200		;height
		dc.w	32		;offset pic
		dc.l	0		;offset cols
	;XYMOX WindItUp
.wip		dc.l	.pn		;next
		dc.l	70400		;size
		dc.w	0		;flags
		dc.w	4		;depth
		dc.w	640		;width
		dc.w	220		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
	;Poker Nights
.pn		dc.l	.pn2		;next
		dc.l	34848		;size
		dc.w	PFFF_HAM|PFFF_FIXCOLS	;flags
		dc.w	6		;depth
		dc.w	192		;width
		dc.w	242		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
		dl	.pn_cols
.pn_cols	dl	$00000333,$07400555,$0A600D00,$0B700888
		dl	$0F00011F,$0AAA0F95,$0FB70FF0,$0DDD0FFF
.pn2		dc.l	.pn3		;next
		dc.l	149280		;size
		dc.w	PFFF_OWNCOLS	;flags
		dc.w	4		;depth
		dc.w	848		;width
		dc.w	352		;height
		dc.w	0		;offset pic
		dc.l	352*848/2	;offset cols
.pn3		dc.l	.pn4		;next
		dc.l	1728		;size
		dc.w	PFFF_FIXCOLS	;flags
		dc.w	4		;depth
		dc.w	96		;width
		dc.w	36		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
		dl	.pn_cols
.pn4		dc.l	.pn5		;next
		dc.l	2720		;size
		dc.w	PFFF_FIXCOLS	;flags
		dc.w	4		;depth
		dc.w	64		;width
		dc.w	85		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
		dl	.pn_cols
.pn5		dc.l	.pn6		;next
		dc.l	2592		;size
		dc.w	PFFF_FIXCOLS	;flags
		dc.w	4		;depth
		dc.w	96		;width
		dc.w	36		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
		dl	.pn_cols
.pn6		dc.l	0		;next
		dc.l	61440		;size
		dc.w	PFFF_HAM|PFFF_FIXCOLS	;flags
		dc.w	6		;depth
		dc.w	320		;width
		dc.w	256		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols
		dl	.pn_cols

_picfmtdummy	dc.l	0		;next
		dc.l	0		;size
		dc.w	0		;flags
		dc.w	0		;depth
		dc.w	0		;width
		dc.w	0		;height
		dc.w	0		;offset pic
		dc.l	0		;offset cols

;##########################################################################

	NSTRUCTURE	local_main,0
		NAPTR	lm_srcptr
		NULONG	lm_srcsize
		NULONG	lm_bodysize
		NULONG	lm_cmapsize
		NULONG	lm_destsize
		NULONG	lm_destptr
		NSTRUCT	lm_tmpfile,256		;tmp filename (palette)
		NULONG	lm_tmpptr
		NLONG	lm_tmpsize
		NLABEL	lm_SIZEOF

_Main		movem.l	d2/a2/a6,-(a7)
		link	LOC,#lm_SIZEOF
		move.l	(gl_rdarray+aa_input,GL),a0
		bsr	_LoadFileMsg
		move.l	d1,(lm_srcsize,LOC)
		move.l	d0,(lm_srcptr,LOC)
		beq	.end

	;special formats with id
		move.l	(lm_srcptr,LOC),a0
		lea	(_picfmtdummy),a2
		cmp.l	#"Unit",(a0)
		bne	.not_unit
		addq.l	#4,a0
		move.w	(a0)+,(pf_depth,a2)
		move.w	(a0)+,(pf_width,a2)
		move.w	(a0)+,(pf_height,a2)
		move.w	(a0)+,d0		;color entries count
		sub.l	(lm_srcptr,LOC),a0
		move.l	a0,(pf_offsetcols,a2)
		lsl.w	#1,d0
		add.w	d0,a0
		move.w	a0,(pf_offsetpic,a2)
		move.w	#PFFF_OWNCOLS,(pf_flags,a2)
		bra	.found
.not_unit

	;search slave
		lea	(_picfmts),a2		;A2 = slave
		move.l	(lm_srcsize,LOC),d1
.next		cmp.l	(pf_size,a2),d1
		beq	.found
		move.l	(pf_succ,a2),a2
		move.l	a2,d0
		beq	.freefile
		bra	.next
.found
		btst	#PFFB_EXTCOLS,(pf_flags+1,a2)
		beq	.s2
		move.l	(gl_rdarray+aa_input,GL),a0
		lea	(lm_tmpfile,LOC),a1
		move.l	#256,d0
		bsr	_CopyString
		lea	(lm_tmpfile,LOC),a0
		bsr	_RemoveExtension
		lea	(_extcols),a0
		lea	(lm_tmpfile,LOC),a1
		move.l	#256,d0
		bsr	_AppendString
		lea	(lm_tmpfile,LOC),a0
		bsr	_LoadFileMsg
		move.l	d1,(lm_tmpsize,LOC)
		move.l	d0,(lm_tmpptr,LOC)
		beq	.afterfreetmp
.s2
		lea	(_format),a0
		move.l	(pf_offsetcols,a2),-(a7)
		move.w	(pf_offsetpic,a2),-(a7)
		move.w	(pf_flags,a2),-(a7)
		move.w	(pf_depth,a2),-(a7)
		move.w	(pf_height,a2),-(a7)
		move.w	(pf_width,a2),-(a7)
		move.l	(lm_srcsize,LOC),-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#4+2+2+2+2+2+4,a7

	;calc size dest
	;BODY
		move.w	(pf_width,a2),d0
		add.w	#15,d0			;round up
		lsr.w	#4,d0
		add.w	d0,d0
		mulu.w	(pf_depth,a2),d0
		mulu.w	(pf_height,a2),d0	;depth*width*height/8
		move.l	d0,(lm_bodysize,LOC)
		addq.l	#8,d0		;BODY+size
	;CMAP
		moveq	#1,d1
		move.w	(pf_depth,a2),d2
		lsl.w	d2,d1
		mulu.w	#3,d1		;3 byte per col
		move.l	d1,(lm_cmapsize,LOC)
		addq.l	#8,d1		;CMAP+size
		add.l	d1,d0
	;BMHD
		add.l	#28,d0
	;CAMG
		moveq	#PFFB_HAM,d2
		move.w	(pf_flags,a2),d1
		btst	d2,d1
		beq	.nocmag
		add.l	#4+4+4,d0	;CAMG,size,viewmode
.nocmag
	;FORM
		add.l	#12,d0		;FORM,size,ILBM
		move.l	d0,(lm_destsize,LOC)
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
	;build savefile
	;IFF header
		move.l	(lm_destptr,LOC),a0			;A0 = dest
		move.l	#"FORM",(a0)+
		move.l	(lm_destsize,LOC),(a0)
		subq.l	#8,(a0)+		;size
		move.l	#"ILBM",(a0)+
	;CAMG
		moveq	#PFFB_HAM,d2
		move.w	(pf_flags,a2),d1
		btst	d2,d1
		beq	.nocamg2
		move.l	#"CAMG",(a0)+
		move.l	#4,(a0)+
		move.l	#$800,(a0)+
.nocamg2
	;BMHD
		move.l	#"BMHD",(a0)+
		move.l	#20,(a0)+
		move.w	(pf_width,a2),(a0)+
		move.w	(pf_height,a2),(a0)+
		clr.l	(a0)+			;xpos,ypos
		move.w	(pf_depth,a2),d0
		move.b	d0,(a0)+
		clr.b	(a0)+			;mask
		clr.b	(a0)+			;compression
		clr.b	(a0)+			;pad
		clr.w	(a0)+			;trans col
		move.b	#10,(a0)+		;x aspect
		move.b	#11,(a0)+		;y aspect
		move.w	(pf_width,a2),(a0)+	;screen
		move.w	(pf_height,a2),(a0)+
	;CMAP
		move.l	#"CMAP",(a0)+
		move.l	(lm_cmapsize,LOC),(a0)+	;size
		btst	#PFFB_EXTCOLS,(pf_flags+1,a2)
		beq	.def
.extcols	move.l	(lm_cmapsize,LOC),d0
		move.l	(lm_tmpptr,LOC),a1
.nc		move.w	(a1)+,(a0)+
		subq.l	#2,d0
		bne	.nc
		bra	.cmapfertig
.def		lea	(_defcols),a1
		btst	#PFFB_FIXCOLS,(pf_flags+1,a2)
		beq	.nofixcols
		move.l	(pf_cols,a2),a1
.nofixcols
		moveq	#PFFB_OWNCOLS,d2
		move.w	(pf_flags,a2),d1
		btst	d2,d1
		beq	.nocols
		move.l	(lm_srcptr,LOC),a1
		add.l	(pf_offsetcols,a2),a1
.nocols		moveq	#1,d2
		move.w	(pf_depth,a2),d1
		lsl.w	d1,d2
		subq.w	#1,d2
.collp		move.w	(a1)+,d0
		move.w	d0,d1
		and.w	#$0F00,d1
		lsr.w	#4,d1
		move.b	d1,(a0)+
		move.w	d0,d1
		and.w	#$00F0,d1
		move.b	d1,(a0)+
		move.w	d0,d1
		and.w	#$000F,d1
		lsl.w	#4,d1
		move.b	d1,(a0)+
		dbf	d2,.collp
.cmapfertig
	;BODY
		move.l	#"BODY",(a0)+
		move.l	(lm_bodysize,LOC),(a0)+
		move.l	(lm_srcptr,LOC),a1
		add.w	(pf_offsetpic,a2),a1
		move.w	(pf_flags,a2),d1
		tst.l	(gl_rdarray+aa_inleav,GL)
		beq	.s1
		bchg	#PFFB_INLEAV,d1		;invert flags value
.s1		btst	#PFFB_INLEAV,d1
		bne	.inleav
	;src not interleaved
		move.w	(pf_height,a2),d0
		subq.w	#1,d0

.lph		move.w	(pf_depth,a2),d2
		subq.w	#1,d2

.lpd		move.w	(pf_width,a2),d1
		add.w	#15,d1			;round up
		lsr.w	#4,d1
		subq.w	#1,d1

.lpw		move.w	(a1)+,(a0)+		;copy one line
		dbf	d1,.lpw
	;next line				;skip planebytes-linebytes
		move.w	(pf_width,a2),d1
		add.w	#15,d1
		lsr.w	#4,d1			;round up
		add.w	d1,d1			;in bytes
		move.w	d0,-(a7)
		move.w	(pf_height,a2),d0
		subq.w	#1,d0
		mulu.w	d0,d1
		move.w	(a7)+,d0
		add.l	d1,a1
		dbf	d2,.lpd
	;next plane				;skip -(planebytes*depth))+linebytes
		move.w	(pf_depth,a2),d2
		mulu.w	(pf_height,a2),d2
		moveq	#0,d1
		move.w	(pf_width,a2),d1
		add.w	#15,d1
		lsr.w	#4,d1			;round up
		add.w	d1,d1			;in bytes
		mulu.w	d1,d2
		sub.l	d1,d2
		sub.l	d2,a1
		dbf	d0,.lph
		bra	.bodyend

	;source already interleaved
.inleav		move.l	(lm_bodysize,LOC),d0
		lsr.l	#1,d0
.piclp		move.w	(a1)+,(a0)+
		subq.l	#1,d0
		bne	.piclp
.bodyend
		sub.l	(lm_destsize,LOC),a0
		cmp.l	(lm_destptr,LOC),a0
		beq	.right
		
		lea	(_calcerr),a0
		bsr	_Print
.right
		move.l	(lm_destsize,LOC),d0
		move.l	(lm_destptr,LOC),a0
		move.l	(gl_rdarray+aa_output,GL),d1
		bne	.save
		move.l	(gl_rdarray+aa_input,GL),d1
.save		move.l	d1,a1
		bsr	_SaveFileMsg

		move.l	(lm_destptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afterfreedest
.freetmp
		btst	#PFFB_EXTCOLS,(pf_flags+1,a2)
		beq	.afterfreetmp
		move.l	(lm_tmpptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afterfreetmp
.freefile
		move.l	(lm_srcptr,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)

.end		unlk	LOC
		movem.l	(a7)+,d2/a2/a6
		rts

_defcols	dc.w	0,$fff,$ddd,$bbb,$999,$777,$555,$222		;grey
		dc.w	15,13,11,9,7,5,3,1				;blue
		dc.w	$f0,$d0,$b0,$90,$70,$50,$30,$10			;green
		dc.w	$f00,$d00,$b00,$900,$700,$500,$300,$100		;red

;##########################################################################

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
	INCLUDE	strings.i
		CopyString
		RemoveExtension
		AppendString

;##########################################################################

_format		dc.b	"filesize = %ld",10
		dc.b	"width = %d",10
		dc.b	"height = %d",10
		dc.b	"depth = %d",10
		dc.b	"flags = $%x",10
		dc.b	"offsetpic = $%x",10
		dc.b	"offsetcols = $%lx",10
		dc.b	0
_extcols	dc.b	".pal",0

; Errors
_nomem		dc.b	"not enough free store",0
_calcerr	dc.b	"calculation of pic FAIL !!!",10,0

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
		dc.b	",INLEAV/S"		;toggle interleaved flag
		dc.b	0

_ver		VER
		dc.b	10,0

;##########################################################################

	END

