;*---------------------------------------------------------------------------
;  :Program.	DIC.asm
;  :Contents.	Disk-Image-Creator
;  :Author.	Bert Jahn
;  :EMail.	wepl@kagi.com
;  :Address.	Franz-Liszt-Straße 16, Rudolstadt, 07404, Germany
;  :Version.	$Id: DIC.asm 0.18 2000/01/16 16:22:07 jah Exp jah $
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
;  :Requires.	OS V37+
;  :Copyright.	© 1996,1997,1998,1999,2000 Bert Jahn, All Rights Reserved
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.9
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

	INCLUDE	macros/ntypes.i
	INCLUDE	macros/mulu32.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

MAXTRACKS	= 160

	STRUCTURE	Globals,0
		APTR	gl_execbase
		APTR	gl_dosbase
		ULONG	gl_stdin
		APTR	gl_rdargs
		LABEL	gl_rdarray
		ULONG	gl_rd_device
		ULONG	gl_rd_st
		ULONG	gl_rd_size
		ULONG	gl_rd_fdisk
		ULONG	gl_rd_ldisk
		ULONG	gl_rd_pedantic
		ULONG	gl_rc
		STRUCT	gl_skip,MAXTRACKS
		ALIGNLONG
		LABEL	gl_SIZEOF

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68000

Version	 = 0
Revision = 19

	PURE
	OUTPUT	C:DIC

	IFND	.passchk
	DOSCMD	"WDate >T:date"
.passchk
	ENDC

VER	MACRO
		sprintx	"DIC %ld.%ld ",Version,Revision
	INCBIN	"T:date"
	ENDM

		bra	.start
		dc.b	0,"$VER: "
		VER
		dc.b	0
		dc.b	"$Id: DIC.asm 0.18 2000/01/16 16:22:07 jah Exp jah $",10,0
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
		jsr	_LVOOpenLibrary(a6)
		move.l	d0,(gl_dosbase,GL)
		beq	.nodoslib

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

	;parse tracks
		lea	(gl_skip,GL),a0
		move.w	#MAXTRACKS-1,d0
.pt_clr		clr.b	(a0)+
		dbf	d0,.pt_clr
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

	INCDIR	Sources:
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
		move.l	d4,d0			;size
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
		
		rts

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
		move.b	-(a1),d0
		cmp.b	#":",d0
		bne	.1
		clr.b	(a1)
.1
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
		
		move.l	(ld_di+devi_LowCyl,LOC),d2
	IFEQ CPU-68020
		mulu.l	(ld_di+devi_Surfaces,LOC),d2
	ELSE
		move.l	(ld_di+devi_Surfaces,LOC),d0
		mulu32	d0,d2					;D2 = first track
	ENDC

		move.l	(ld_di+devi_HighCyl,LOC),d3
		sub.l	(ld_di+devi_LowCyl,LOC),d3
		addq.l	#1,d3
	IFEQ CPU-68020
		mulu.l	(ld_di+devi_Surfaces,LOC),d3
	ELSE
		move.l	(ld_di+devi_Surfaces,LOC),d0
		mulu32	d0,d3					;D3 = amount of tracks
	ENDC

	IFEQ CPU-68020
		move.l	(ld_di+devi_SizeBlock,LOC),d4
		mulu.l	(ld_di+devi_BlocksPerTrack,LOC),d4
	ELSE
		move.l	(ld_di+devi_SizeBlock,LOC),d4
		move.l	(ld_di+devi_BlocksPerTrack,LOC),d0
		mulu32	d0,d4					;D4 = tracksize
	ENDC

	;print geometry
		lea	(_m_diskgeo),a0
		move.l	d3,d6
		mulu32	d4,d6			;disksize = cyls * heads * blktrk * blksize
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
		NALIGNLONG
		LABEL	lrd_SIZEOF

_ReadDisk	movem.l	d2-d3/d7/a2/a6,-(a7)
		link	LOC,#lrd_SIZEOF
		move.l	d0,(lrd_device,LOC)
		move.l	d1,(lrd_unit,LOC)
		move.l	a1,(lrd_buffer,LOC)
		sf	(lrd_skipall,LOC)
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

	;setup the ioreq
		move.l	(lrd_buffer,LOC),(IO_DATA,a2)	;dest buf
		move.l	d2,d0
		mulu32	d4,d0
		move.l	d0,(IO_OFFSET,a2)		;begin at disk (offset)
		move.l	d4,(IO_LENGTH,a2)		;bytes per track
		move.w	#ETD_READ,(IO_COMMAND,a2)
		
		add.l	d2,d3				;D3 = last track

		bsr	_PrintLn
.loop		lea	(_diskprogress),a0		;output progress
		move.l	d3,-(a7)
		sub.l	d2,(a7)
		subq.l	#1,(a7)
		move.l	d2,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
		
	;check for CTRL-C
		bsr	_CheckBreak
		tst.l	d0
		bne	.break
		
	;check if track should be skipped
		tst.b	(gl_skip,GL,d2.w)
		bne	.skip

	;read the track
		move.l	a2,a1				;read one track
		clr.b	(IO_ERROR,a2)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a2),d0
		beq	.readok
		lea	(_readdisk),a0
		bsr	_PrintErrorTD

		tst.l	(gl_rd_pedantic,GL)
		bne	.break
		
		tst.b	(lrd_skipall,LOC)
		bne	.skip

		move.l	(gl_stdin,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOIsInteractive,a6)
		tst.l	d0
		beq	.skip

		lea	(_tryagain),a0
		bsr	_Print
		bsr	_FlushOutput
		
.wait		bsr	_GetKey
		cmp.b	#3,d0				;Ctrl-C
		beq	.break
		UPPER	d0
		cmp.b	#"R",d0
		beq	.waitend
		cmp.b	#"S",d0
		beq	.waitend
		cmp.b	#"A",d0
		beq	.waitend
		cmp.b	#"Q",d0
		beq	.waitend
		cmp.b	#13,d0				;Return
		bne	.wait
		
.waitend	lsl.w	#8,d0
		or.w	#10,d0
		clr.w	-(a7)
		move.w	d0,-(a7)
		move.l	a7,a0
		bsr	_Print
		move.l	(a7)+,d0
		rol.l	#8,d0
		cmp.b	#"R",d0
		beq	.loop
		cmp.b	#"S",d0
		beq	.skip
		cmp.b	#"Q",d0
		beq	.break
		cmp.b	#13,d0				;Return
		beq	.break

	;skip all errors
		st	(lrd_skipall,LOC)

.skip
	;fill track data area with pattern "TDIC"
		move.l	(IO_DATA,a2),a0
		move.l	(IO_LENGTH,a2),d0
		lsr.l	#2,d0
.fill		move.l	#"TDIC",(a0)+
		subq.l	#1,d0
		bne	.fill
		
	;next track
.readok		add.l	d4,(IO_OFFSET,a2)		;begin at disk (offset)
		add.l	d4,(IO_DATA,a2)			;dest buf
		addq.l	#1,d2
		cmp.l	d2,d3
		bne	.loop

		bsr	_PrintLn
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
		movem.l	(a7)+,d2-d3/d7/a2/a6
		rts

;##########################################################################

_defdev		dc.b	"DF0:",0
_insdisk	dc.b	10,"Insert disk %ld into drive %s and press RETURN (^C to cancel) ...",0
_tryagain	dc.b	"Retry/Skip/skip All/Quit (r/s/a/Q): ",0
_filefmt	dc.b	"Disk.%ld",0
_txt_badtracks	dc.b	"Invalid SKIPTRACK/K specification",10,0

;Messages
_m_readdisk	dc.b	"read from ",155,"1m%s",155,"22m: (%s %ld)",10,0
_m_diskgeo	dc.b	"(blksize=%ld heads=%ld blktrk=%ld lcyl=%ld hcyl=%ld) size=%ld",10,0
_m_savedisk	dc.b	"save disk as ",155,"3m%s ",155,"23m",10,0
_m_savefile	dc.b	"save file ",155,"3m%s ",155,"23m",10,0
_diskprogress	dc.b	11,155,"Kreading track %ld left %ld",10,0
_withsize	dc.b	"limited reading of $%lx=%ld bytes",10,0

; Errors
_nomem		dc.b	"not enough free store",0
_noport		dc.b	"can't create MessagePort",0
_noioreq	dc.b	"can't create IO-Request",0
_nodev		dc.b	"device doesn't exist",0
_baddev		dc.b	"cannot handle this device",0
_badsize	dc.b	"illegal argument for SIZE/K",10,0

; Operationen
_readargs	dc.b	"read arguments",0
_getdiskmem	dc.b	"alloc mem for disk",0
_readdisk	dc.b	"read disk",0
_getdevinfo	dc.b	"get dev info",0
_opendevice	dc.b	"open device",0

;subsystems
_dosname	DOSNAME

_template	dc.b	"DEVICE"		;name of device (default "DF0:)
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

