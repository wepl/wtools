;*---------------------------------------------------------------------------
;  :Program.	DIC.asm
;  :Contents.	Disk-Image-Creator
;  :Author.	Bert Jahn
;  :History.	15.05.96
;		20.06.96 returncode supp.
;		01.06.97 _LVOWaitForChar added,  check for interactive terminal added
;		17.09.98 after a disk read error and 'cancel' it does not continue
;			 if last disk already reached now (reported by MrLarmer)
;		12.10.98 bugfix
;		17.01.99 recompile because error.i changed
;		11.01.00 pedantic mode and skipping tracks added
;			 error handling changed
;		24.02.00 multiple tracks can be skipped now (taken from wwarp ;-)
;		21.07.00 bug: retry after diskchange fixed (Andreas Falkenhahn)
;		22.07.00 option 'Name' added (Andreas Falkenhahn)
;		11.06.03 bug with device inhibit fixed (JOTD)
;		16.07.04 using utility.library for mulu32
;			 dont (allow) skip on fatal read errors
;			 no longer eats own error messages
;		08.05.08 skiptrack fixed for disks containing more than MAXTRACKS tracks
;			 (previously higher tracks has been randomly skipped because
;			 internal table was too short)
;		30.03.21 read single sectors if track read fails and trackdisk is
;			 present and Skip is selected
;		22.11.22 fix SkipTrack function which got broken in last change
;			 now single sector reads after error can be performed on all
;			 devices (not only trackdisk) but not on skipped tracks
;		2025-02-26 imported to wtools
;  :Requires.	OS V37+
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.16
;  :To Do.
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/execbase.i
	INCLUDE	exec/io.i
	INCLUDE	exec/memory.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i
	INCLUDE	devices/trackdisk.i
	INCLUDE	lvo/utility.i

	INCLUDE	macros/ntypes.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

MAXTRACKS	= 160

	STRUCTURE	Globals,0
		APTR	gl_execbase
		APTR	gl_dosbase
		APTR	gl_utilbase
		ULONG	gl_stdin
		APTR	gl_rdargs
		LABEL	gl_rdarray
		ULONG	gl_rd_device
		ULONG	gl_rd_name
		ULONG	gl_rd_st
		ULONG	gl_rd_size
		ULONG	gl_rd_fdisk
		ULONG	gl_rd_ldisk
		ULONG	gl_rd_pedantic
		ULONG	gl_rc
		STRUCT	gl_skip,MAXTRACKS
		UBYTE	gl_interactive
		ALIGNLONG
		LABEL	gl_SIZEOF

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars

Version	 = 1
Revision = 4

	IFD BARFLY
	PURE
	OUTPUT	C:DIC
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	ENDC

VER	MACRO
		db	"DIC ","0"+Version,".","0"+Revision," "
	INCBIN	".date"
	ENDM

		bra	.start
		dc.b	0,"$VER: "
		VER
		dc.b	0
	EVEN
.start

;##########################################################################

		move.l	#gl_SIZEOF,d0
		move.l	#MEMF_CLEAR,d1
		move.l	(4).w,a6
		jsr	(_LVOAllocMem,a6)
		tst.l	d0
		beq	.nostrucmem
		move.l	d0,GL
		move.l	a6,(gl_execbase,GL)
		move.l	#RETURN_FAIL,(gl_rc,GL)

		move.l	#37,d0
		lea	(_dosname),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOOpenLibrary,a6)
		move.l	d0,(gl_dosbase,GL)
		beq	.nodoslib

		move.l	#37,d0
		lea	(_utilname),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOOpenLibrary,a6)
		move.l	d0,(gl_utilbase,GL)
		beq	.noutillib

		lea	(_ver),a0
		bsr	_Print

		lea	(_defdev),a0
		move.l	a0,(gl_rd_device,GL)

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
		move.l	(gl_rd_device,GL),a0
		tst.b	(a0)
		beq	.baddev
.chkdev		move.b	(a0)+,d0
		tst.b	(a0)
		bne	.chkdev
		cmp.b	#":",d0
		beq	.devok
.baddev		lea	(_baddevname),a0
		bsr	_Print
		bra	.badargs
.devok
		move.l	(gl_rd_size,GL),d0
		beq	.01
		move.l	d0,a0
		bsr	_etoi
		tst.b	(a0)
		beq	.0
		lea	(_badsize),a0
		bsr	_Print
		bra	.badargs
.0		move.l	d0,(gl_rd_size,GL)
		lea	(_withsize),a0
		move.l	d0,-(a7)
		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
.01
		moveq	#1,d1			;default
		move.l	(gl_rd_fdisk,GL),d0
		beq	.1
		move.l	d0,a0
		move.l	(a0),d1
.1		move.l	d1,(gl_rd_fdisk,GL)

		moveq	#-1,d1			;default - no limit
		move.l	(gl_rd_ldisk,GL),d0
		beq	.2
		move.l	d0,a0
		move.l	(a0),d1
.2		move.l	d1,(gl_rd_ldisk,GL)

		tst.l	(gl_rd_name,GL)
		beq	.noname
		moveq	#1,d0
		move.l	d0,(gl_rd_fdisk,GL)
		move.l	d0,(gl_rd_ldisk,GL)
.noname

	;parse tracks
		move.l	(gl_rd_st,GL),a0
		move.l	a0,d0
		beq	.pt_end

.pt_loop	bsr	.pt_getnum
		move.b	(a0)+,d1
		beq	.pt_single
		cmp.b	#",",d1
		beq	.pt_single
		cmp.b	#"-",d1
		beq	.pt_area
		cmp.b	#"*",d1
		beq	.pt_step
		bra	.pt_err

.pt_single	st	(gl_skip,GL,d0.w)
.pt_check	tst.b	d1
		beq	.pt_end
		cmp.b	#",",d1
		beq	.pt_loop
		bra	.pt_err
		
.pt_step	move.l	d0,d2			;D2 = start
		move.l	#MAXTRACKS-1,d3		;D3 = last
.pt_step0	bsr	.pt_getnum		;D0 = skip
		tst.l	d0
		ble	.pt_err
.pt_step1	cmp.l	d2,d3
		blo	.pt_err
.pt_step_l	st	(gl_skip,GL,d2.w)
		add.l	d0,d2
		cmp.l	d2,d3
		bhs	.pt_step_l
		move.b	(a0)+,d1
		bra	.pt_check

.pt_area	move.l	d0,d2			;D2 = start
		bsr	.pt_getnum
		move.l	d0,d3			;D3 = last
		moveq	#1,d0			;D0 = skip
		cmp.b	#"*",(a0)
		bne	.pt_step1
		addq.l	#1,a0
		bra	.pt_step0

.pt_getnum	move.l	(a7)+,a1
		move.l	a0,a3
		bsr	_atoi
		cmp.l	a0,a3
		beq	.pt_err
		cmp.l	#MAXTRACKS,d0
		bhs	.pt_err
		jmp	(a1)

.pt_err		lea	(_txt_badtracks),a0
		bsr	_Print
		bra	.badargs

.pt_end
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInput,a6)
		move.l	d0,(gl_stdin,GL)

		move.l	#RETURN_ERROR,(gl_rc,GL)
		bsr	_Main
.badargs
		move.l	(gl_rdargs,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFreeArgs,a6)
.noargs
		move.l	(gl_utilbase,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.noutillib
		move.l	(gl_dosbase,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.nodoslib
		move.l	(gl_rc,GL),d7

		move.l	#gl_SIZEOF,d0
		move.l	GL,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeMem,a6)

		move.l	d7,d0
		rts

.nostrucmem	moveq	#RETURN_FAIL,d0
		rts

;##########################################################################

	INCLUDE	dosio.i
		PrintLn
		PrintArgs
		Print
		FlushOutput
		CheckBreak
		GetKey
	INCLUDE	files.i
		SaveFileMsg
	INCLUDE	strings.i
		CopyString
		FormatString
		DoString
		etoi
	INCLUDE	devices.i
		GetDeviceInfo
	INCLUDE	error.i
		PrintErrorTD

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

_Main		move.l	(gl_rd_device,GL),d1
		moveq	#-1,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)
		tst.l	d0
		beq	.errinhibit

		move.l	(gl_rd_fdisk,GL),d7	;d7 disknumber
		subq.l	#1,d7
.nextdisk	addq.l	#1,d7
		cmp.l	(gl_rd_ldisk,GL),d7
		bhi	.success

	;check if interactive console
		move.l	(gl_stdin,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOIsInteractive,a6)
		tst.l	d0
		sne	(gl_interactive,GL)
		beq	.readdisk

	;prompt user to insert disk
		lea	(_insdisk),a0
		move.l	(gl_rd_device,GL),-(a7)
		move.l	d7,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
		bsr	_FlushOutput
		move.l	(gl_stdin,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFlush,a6)
		
	;wait for return
.wait		bsr	_GetKey
		cmp.b	#3,d0			;^C ?
		beq	.end
		cmp.b	#13,d0			;CR ?
		bne	.wait
		bsr	_PrintLn

	;read the disk image
.readdisk	move.l	(gl_rd_device,GL),a0
		bsr	_LoadDisk
		move.l	d1,d4			;D4 = size
		move.l	d0,d5			;D5 = buffer
		beq	.end
		
NAMEBUFLEN = 16

	;save disk image
		lea	(_filefmt),a0		;fmt
		move.l	d7,-(a7)
		move.l	a7,a1			;args
		sub.l	#NAMEBUFLEN,a7
		move.l	a7,a2			;buffer
		moveq	#NAMEBUFLEN,d0		;bufsize
		bsr	_FormatString
		move.l	(gl_rd_name,GL),d0
		beq	.noname
		move.l	d0,a2
.noname		move.l	d4,d0			;size
		tst.l	(gl_rd_size,GL)
		beq	.s
		cmp.l	(gl_rd_size,GL),d0
		bls	.s
		move.l	(gl_rd_size,GL),d0
.s		move.l	d5,a0			;buffer
		move.l	a2,a1			;filename
		bsr	_SaveFileMsg
		add.l	#NAMEBUFLEN+4,a7
		move.l	d0,d2			;save return code
		move.l	d5,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
		tst.l	d2
		beq	.end			;if save file has failed

		bra	.nextdisk

.success	clr.l	(gl_rc,GL)

.end		move.l	(gl_rd_device,GL),d1
		moveq	#0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)
		tst.l	d0
		beq	.errinhibit
		
		rts

.errinhibit	lea	(_inhibit),a0
		bra	_PrintErrorDOS

;##########################################################################
;----------------------------------------
; read disk
; IN:	A0 = CPTR device name
; OUT:	D0 = APTR loaded buffer OR NIL
;	D1 = LONG size of buffer

	NSTRUCTURE	local_dodisk,0
		NSTRUCT	ld_di,devi_SIZEOF		;DeviceInfo
		NSTRUCT	ld_devname,DEVNAMELEN		;devicename without ":"
		NLABEL	ld_SIZEOF

_LoadDisk	movem.l	d2-d7/a6,-(a7)
		link	LOC,#ld_SIZEOF
		moveq	#0,d7				;D7 = returncode (bufptr)
		moveq	#0,d6				;D6 = bufsize
		
	;remove ":" from device name
		lea	(ld_devname,LOC),a1
		moveq	#DEVNAMELEN-1,d0
.c		move.b	(a0)+,(a1)+
		dbeq	d0,.c
		clr.b	-(a1)
		clr.b	-(a1)				:remove ":"

	;get geometry for device
		lea	(ld_devname,LOC),a0
		lea	(ld_di,LOC),a1
		bsr	_GetDeviceInfo
		tst.l	d0
		beq	.nodevi

	;print device name
		lea	(_m_readdisk),a0
		move.l	(ld_di+devi_Unit,LOC),-(a7)
		pea	(ld_di+devi_Device,LOC)
		pea	(ld_devname,LOC)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#12,a7
		
		move.l	(ld_di+devi_LowCyl,LOC),d0
		move.l	(ld_di+devi_Surfaces,LOC),d1
		move.l	(gl_utilbase,GL),a6
		jsr	(_LVOUMult32,a6)
		move.l	d0,d2				;D2 = first track

		move.l	(ld_di+devi_HighCyl,LOC),d0
		sub.l	(ld_di+devi_LowCyl,LOC),d0
		addq.l	#1,d0
		move.l	(ld_di+devi_Surfaces,LOC),d1
		jsr	(_LVOUMult32,a6)
		move.l	d0,d3				;D3 = amount of tracks

		move.l	(ld_di+devi_SizeBlock,LOC),d0
		move.l	(ld_di+devi_BlocksPerTrack,LOC),d1
		jsr	(_LVOUMult32,a6)
		move.l	d0,d4				;D4 = tracksize

		move.l	d3,d0
		move.l	d4,d1
		jsr	(_LVOUMult32,a6)
		move.l	d0,d6				;D6 = disksize

	;print geometry
		lea	(_m_diskgeo),a0
		move.l	d6,-(a7)
		move.l	(ld_di+devi_HighCyl,LOC),-(a7)
		move.l	(ld_di+devi_LowCyl,LOC),-(a7)
		move.l	(ld_di+devi_BlocksPerTrack,LOC),-(a7)
		move.l	(ld_di+devi_Surfaces,LOC),-(a7)
		move.l	(ld_di+devi_SizeBlock,LOC),-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#6*4,a7

	;calculate readlen / tracks
		tst.l	(gl_rd_size,GL)
		beq	.sok
		cmp.l	(gl_rd_size,GL),d6
		bls	.sok
		moveq	#0,d3
		moveq	#0,d6
.add		addq.l	#1,d3					;D3 = amount of tracks
		add.l	d4,d6					;D6 = bufsize
		cmp.l	(gl_rd_size,GL),d6
		blo	.add
.sok
		move.l	d6,d0
		move.l	#MEMF_ANY,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,d7
		bne	.memok
		moveq	#0,d0
		lea	(_nomem),a0
		lea	(_getdiskmem),a1
		bsr	_PrintError
		bra	.nomem
.memok
		lea	(ld_di+devi_Device,LOC),a0
		move.l	a0,d0					;D0 = devicename
		move.l	(ld_di+devi_Unit,LOC),d1		;D1 = unit
		move.l	d7,a1					;A1 = buffer
		bsr	_ReadDisk
		tst.l	d0
		bne	.ok

		move.l	d7,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
		moveq	#0,d6
		moveq	#0,d7
.ok
.nomem
.nodevi
		move.l	d6,d1
		move.l	d7,d0
		unlk	LOC
		movem.l	(a7)+,d2-d7/a6
		rts

;----------------------------------------
; Lesen Diskette
; IN:	D0 = APTR  device name
;	D1 = ULONG unit number
;	D2 = ULONG start track
;	D3 = ULONG tracks
;	D4 = ULONG bytes per track
;	A1 = APTR  buffer to read data in
;	GL = STRUCT globals
; OUT:	D0 = BOOL success

	NSTRUCTURE	local_readdisk,0
		NAPTR	lrd_device
		NULONG	lrd_unit
		NAPTR	lrd_buffer
		NAPTR	lrd_msgport
		NBYTE	lrd_skipall
		NBYTE	lrd_fatal
		NBYTE	lrd_trysec
		NALIGNLONG
		LABEL	lrd_SIZEOF

_ReadDisk	movem.l	d2-d3/d5/d7/a2/a6,-(a7)
		link	LOC,#lrd_SIZEOF
		move.l	d0,(lrd_device,LOC)
		move.l	d1,(lrd_unit,LOC)
		move.l	a1,(lrd_buffer,LOC)
		sf	(lrd_skipall,LOC)
		sf	(lrd_trysec,LOC)
		moveq	#0,d7				;D7 = return (false)

		move.l	(gl_execbase,GL),a6		;A6 = execbase
		jsr	(_LVOCreateMsgPort,a6)
		move.l	d0,(lrd_msgport,LOC)
		bne	.portok
		moveq	#0,d0
		lea	(_noport),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noport
.portok		
		move.l	(lrd_msgport,LOC),a0
		move.l	#IOTD_SIZE,d0
		jsr	(_LVOCreateIORequest,a6)
		move.l	d0,a2				;A2 = ioreq
		tst.l	d0
		bne	.ioreqok
		moveq	#0,d0
		lea	(_noioreq),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noioreq
.ioreqok
		move.l	(lrd_device,LOC),a0
		move.l	(lrd_unit,LOC),d0
		move.l	a2,a1				;ioreq
		move.l	#0,d1				;flags
	move.l	d3,-(a7)				;BUG in fucking mfm.device
		jsr	(_LVOOpenDevice,a6)
	move.l	(a7)+,d3				;BUG in fucking mfm.device
		tst.l	d0
		beq	.deviceok
		move.b	(IO_ERROR,a2),d0
		lea	(_opendevice),a0
		bsr	_PrintErrorTD
		bra	.nodevice
.deviceok

	;get actual diskchange count
		move.l	a2,a1				;ioreq
		move.w	#TD_CHANGENUM,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(IO_ACTUAL,a2),(IOTD_COUNT,a2)

		add.l	d2,d3				;D3 = last track

.retry		bsr	_PrintLn
.loop
	;check if track should be skipped
		cmp.l	#MAXTRACKS,d2
		bhs	.noskip
		tst.b	(gl_skip,GL,d2.w)
		bne	.skipbyarg
.noskip
	;check for CTRL-C
		bsr	_CheckBreak
		tst.l	d0
		bne	.break

	;print progress
		lea	(_diskprogress),a0
		move.l	d3,-(a7)
		sub.l	d2,(a7)
		subq.l	#1,(a7)
		move.l	d2,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7

	;read the track
		clr.b	(IO_ERROR,a2)
		move.w	#ETD_READ,(IO_COMMAND,a2)
		move.l	d4,(IO_LENGTH,a2)		;bytes per track
		move.l	d2,d0
		move.l	d4,d1
		move.l	(gl_utilbase,GL),a0
		jsr	(_LVOUMult32,a0)
		move.l	d0,(IO_OFFSET,a2)		;begin at disk (offset)
		add.l	(lrd_buffer,LOC),d0
		move.l	d0,(IO_DATA,a2)			;dest buf
		move.l	a2,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a2),d0
		beq	.readok
		lea	(_readdisk),a0
		bsr	_PrintErrorTD
		
		tst.l	(gl_rd_pedantic,GL)
		bne	.break

	;check if error is fatal
		sf	(lrd_fatal,LOC)
		cmp.b	#TDERR_NotSpecified,(IO_ERROR,a2)	;device error?
		blo	.fatal
		cmp.b	#TDERR_DiskChanged,(IO_ERROR,a2)
		blo	.notfatal
.fatal		st	(lrd_fatal,LOC)
.notfatal

	;set new changenum for retry if disk changed
		cmp.b	#TDERR_DiskChanged,(IO_ERROR,a2)
		bne	.notchg
		move.l	a2,a1				;ioreq
		move.w	#TD_CHANGENUM,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(IO_ACTUAL,a2),(IOTD_COUNT,a2)
.notchg

	;how to continue
		move.b	(gl_interactive,GL),d0
		add.b	d0,d0
		add.b	(lrd_fatal,LOC),d0
		beq	.skip				;nonfatal noninteractive
		addq.b	#1,d0
		beq	.break				;fatal noninteractive
		addq.b	#1,d0
		beq	.asklong			;nonfatal interactive

.askshort	lea	(_tryshort),a0
		bsr	_Print
		bsr	_FlushOutput
		
.waitshort	bsr	_GetKey
		cmp.b	#3,d0				;Ctrl-C
		beq	.break
		UPPER	d0
		cmp.b	#"R",d0
		beq	.waitend
		cmp.b	#"Q",d0
		beq	.waitend
		cmp.b	#13,d0				;Return
		bne	.waitshort
		bra	.waitend

.asklong	tst.b	(lrd_skipall,LOC)
		bne	.skip
		tst.b	(lrd_trysec,LOC)
		bne	.trysec

		lea	(_trylong),a0
		bsr	_Print
		bsr	_FlushOutput
		
.waitlong	bsr	_GetKey
		cmp.b	#3,d0				;Ctrl-C
		beq	.break
		UPPER	d0
		cmp.b	#"R",d0
		beq	.waitend
		cmp.b	#"S",d0
		beq	.waitend
		cmp.b	#"A",d0
		beq	.waitend
		cmp.b	#"T",d0
		beq	.waitend
		cmp.b	#"Q",d0
		beq	.waitend
		cmp.b	#13,d0				;Return
		bne	.waitlong
		
.waitend	cmp.b	#13,d0				;Return
		bne	.no13
		moveq	#"Q",d0
.no13		lsl.w	#8,d0
		move.b	#10,d0
		swap	d0
		move.l	d0,-(a7)
		move.l	a7,a0
		bsr	_Print
		move.l	(a7)+,d0
		rol.l	#8,d0
		cmp.b	#"R",d0
		beq	.retry
		cmp.b	#"S",d0
		beq	.skip
		cmp.b	#"Q",d0
		beq	.break
		cmp.b	#"A",d0
		beq	.skipall

.trysec		st	(lrd_trysec,LOC)
	;try reading single sectors
		move.l	d4,d5				;D5 = bytes per track -> bytes left
	;for each sector
.tdloop		clr.b	(IO_ERROR,a2)
		move.w	#ETD_READ,(IO_COMMAND,a2)
		move.l	#512,(IO_LENGTH,a2)		;single sector
		move.l	d2,d0				;actual track
		addq.l	#1,d0				;one more
		move.l	d4,d1				;bytes per track
		move.l	(gl_utilbase,GL),a0
		jsr	(_LVOUMult32,a0)
		sub.l	d5,d0				;bytes left
		move.l	d0,(IO_OFFSET,a2)		;begin at disk (offset)

	IFEQ 1
	;print actual offset
	move.l	d0,-(a7)
	lea	.1,a0
	move.l	a7,a1
	bsr	_PrintArgs
	move.l	(a7)+,d0
	bra	.2
.1	db	"%ld",10,0,0
.2
	ENDC

		add.l	(lrd_buffer,LOC),d0
		move.l	d0,(IO_DATA,a2)			;dest buf
		move.l	a2,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a2),d0
		beq	.tdok
	;error message for each failed sector
		move.l	d4,d0				;bytes per track
		sub.l	d5,d0				;bytes left
		divu	#512,d0
		move.l	d0,-(a7)
		lea	(_badsector),a0
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		move.b	(IO_ERROR,a2),d0
		lea	(_readdisk),a0
		bsr	_PrintErrorTD
	;fill sector data area with pattern "TDIC"
		move.l	(IO_DATA,a2),a0
		moveq	#512/4-1,d0
.tdfill		move.l	#"TDIC",(a0)+
		dbf	d0,.tdfill
	;set new changenum for retry if disk changed
		cmp.b	#TDERR_DiskChanged,(IO_ERROR,a2)
		bne	.tdnotchg
		move.l	a2,a1				;ioreq
		move.w	#TD_CHANGENUM,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(IO_ACTUAL,a2),(IOTD_COUNT,a2)
.tdnotchg

.tdok		sub.w	#512,d5				;bytes left
		bne	.tdloop
		bsr	_PrintLn
		bra	.readok

	;skip all errors
.skipall	st	(lrd_skipall,LOC)
	;skip this track
.skip		bsr	_PrintLn
.skipbyarg
	;fill track data area with pattern "TDIC"
		move.l	d2,d0
		move.l	d4,d1
		move.l	(gl_utilbase,GL),a0
		jsr	(_LVOUMult32,a0)
		add.l	(lrd_buffer,LOC),d0
		move.l	d0,a0
		move.l	d4,d0
		lsr.l	#2,d0
.fill		move.l	#"TDIC",(a0)+
		subq.l	#1,d0
		bne	.fill
		
	;next track
.readok		addq.l	#1,d2
		cmp.l	d2,d3
		bne	.loop

		lea	(_lineback),a0
		bsr	_Print
		
		moveq	#-1,d7
.break

	;switch drive motor off
		move.l	a2,a1
		move.l	#0,(IO_LENGTH,a1)
		move.w	#ETD_MOTOR,(IO_COMMAND,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)

		move.l	a2,a1
		jsr	(_LVOCloseDevice,a6)
		
.nodevice	move.l	a2,a0
		jsr	(_LVODeleteIORequest,a6)
		
.noioreq	move.l	(lrd_msgport,LOC),a0
		jsr	(_LVODeleteMsgPort,a6)
		
.noport		move.l	d7,d0				;return code
		unlk	LOC
		movem.l	(a7)+,_MOVEMREGS
		rts

;##########################################################################

_defdev		dc.b	"DF0:",0
_insdisk	dc.b	10,"Insert disk %ld into drive %s and press RETURN (^C to cancel) ...",0
_trylong	dc.b	"Retry/Skip/skip All/Try sectors/Quit (r/s/a/t/Q): ",0
_tryshort	dc.b	"Retry/Quit (r/Q): ",0
_filefmt	dc.b	"Disk.%ld",0
_txt_badtracks	dc.b	"Invalid SKIPTRACK/K specification",10,0

;Messages
_m_readdisk	dc.b	"read from ",155,"1m%s",155,"22m: (%s %ld)",10,0
_m_diskgeo	dc.b	"(blksize=%ld heads=%ld blktrk=%ld lcyl=%ld hcyl=%ld) size=%ld",10,0
_m_savedisk	dc.b	"save disk as ",155,"3m%s ",155,"23m",10,0
_m_savefile	dc.b	"save file ",155,"3m%s ",155,"23m",10,0
_diskprogress	dc.b	11,155,"Kreading track %ld left %ld",10,0
_withsize	dc.b	"limited reading of $%lx=%ld bytes",10,0
_lineback	dc.b	11,155,"K",0

; Errors
_nomem		dc.b	"not enough free store",0
_noport		dc.b	"can't create MessagePort",0
_noioreq	dc.b	"can't create IO-Request",0
_nodev		dc.b	"device doesn't exist",0
_baddev		dc.b	"cannot handle this device",0
_baddevname	dc.b	"specified device must have trailing colon",10,0
_badsize	dc.b	"illegal argument for SIZE/K",10,0
_badsector	dc.b	"sector #%ld ",0

; Operationen
_readargs	dc.b	"read arguments",0
_inhibit	dc.b	"inhibit filesystem",0
_getdiskmem	dc.b	"alloc mem for disk",0
_readdisk	dc.b	"read disk",0
_getdevinfo	dc.b	"get dev info",0
_opendevice	dc.b	"open device",0

;subsystems
_dosname	DOSNAME
_utilname	dc.b	"utility.library",0

_template	dc.b	"DEVICE"		;name of device (default "DF0:)
		dc.b	",NAME"			;name of image, implies FD=1 and LD=1
		dc.b	",SKIPTRACK/K"		;dont read these tracks
		dc.b	",SIZE/K"		;number of bytes
		dc.b	",FD=FIRSTDISK/K/N"	;number of first disk
		dc.b	",LD=LASTDISK/K/N"	;number of last disk
		dc.b	",PEDANTIC/S"		;quit on unreadable tracks
		dc.b	0

_ver		VER
		dc.b	" ",155,"1mD",155,"22misk ",155,"1mI",155,"22mmage ",155,"1mC",155,"22mreator by Bert Jahn"
		dc.b	10,0

;##########################################################################

	END

