;*---------------------------------------------------------------------------
;  :Program.	DIC.asm
;  :Contents.	Disk-Image-Creator
;  :Author.	Bert Jahn
;  :EMail.	wepl@kagi.com
;  :Address.	Franz-Liszt-Straße 16, Rudolstadt, 07404, Germany
;  :Version.	$Id: error.i 1.2 1998/12/06 13:42:20 jah Exp $
;  :History.	15.05.96
;		20.06.96 returncode supp.
;		01.06.97 _LVOWaitForChar added,  check for interactive terminal added
;		17.09.98 after a disk read error and 'cancel' it does not continue
;			 if last disk already reached now (reported by MrLarmer)
;		12.10.98 bugfix
;		17.01.99 recompile because error.i changed
;  :Requires.	OS V37+
;  :Copyright.	© 1996,1997,1998 Bert Jahn, All Rights Reserved
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

	STRUCTURE	Globals,0
		APTR	gl_execbase
		APTR	gl_dosbase
		APTR	gl_rdargs
		LABEL	gl_rdarray
		ULONG	gl_rd_device
		ULONG	gl_rd_size
		ULONG	gl_rd_fdisk
		ULONG	gl_rd_ldisk
		ULONG	gl_rc
		ALIGNLONG
		LABEL	gl_SIZEOF

BREAKCOUNT	= 1000
MAXFILENAMESIZE	= 30	;31 with the termination zero

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68000

Version	 = 0
Revision = 17

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
		move.l	#20,(gl_rc,GL)

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

.nostrucmem	moveq	#20,d0
		rts

;##########################################################################

	INCDIR	Sources:
	INCLUDE	dosio.i
		PrintLn
		PrintArgs
		Print
		FlushOutput
		CheckBreak
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

		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInput,a6)
		move.l	d0,d6			;d6 = stdin

		move.l	(gl_rd_fdisk,GL),d7	;d7 disknumber
		subq.l	#1,d7
.nextdisk	addq.l	#1,d7
		cmp.l	(gl_rd_ldisk,GL),d7
		bhi	.end

.again		move.l	d6,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOIsInteractive,a6)
		tst.l	d0
		beq	.readdisk

		lea	(_insdisk),a0
		move.l	(gl_rd_device,GL),-(a7)
		move.l	d7,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
		bsr	_FlushOutput
		
		move.l	d6,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFlush,a6)
		
.wait		move.l	d6,d1
		move.l	#100*1000,d2
		jsr	(_LVOWaitForChar,a6)
		tst.l	d0
		bne	.getc
		bsr	_CheckBreak
		tst.l	d0
		beq	.wait
		bra	.end
		
.getc		move.l	d6,d1
		jsr	(_LVOFGetC,a6)

.readdisk	move.l	(gl_rd_device,GL),a0
		bsr	_LoadDisk
		move.l	d1,d4			;D4 = size
		move.l	d0,d5			;D5 = buffer
		bne	.save
		
		move.l	d6,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOIsInteractive,a6)
		tst.l	d0
		beq	.end

		lea	(_tryagain),a0
		bsr	_Print
		bsr	_FlushOutput
		move.l	d6,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFlush,a6)
		move.l	d6,d1
		jsr	(_LVOFGetC,a6)
		cmp.b	#"a",d0
		blo	.4
		cmp.b	#"z",d0
		bhi	.4
		sub.b	#$20,d0
.4		cmp.b	#"C",d0
		beq	.nextdisk
		cmp.b	#"R",d0
		beq	.again
		bra	.end

NAMEBUFLEN = 16

.save		lea	(_filefmt),a0		;fmt
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
		move.l	d0,d2
		move.l	d5,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
		tst.l	d2
		beq	.end

		cmp.l	(gl_rd_ldisk,GL),d7
		bne	.nextdisk
		clr.l	(gl_rc,GL)
.end
		move.l	(gl_rd_device,GL),d1
		moveq	#0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)
		
		rts

;##########################################################################
;----------------------------------------
; Lesen einer Diskette
; Übergabe :	A0 = CPTR device name
; Rückgabe :	D0 = APTR loaded buffer OR NIL
;		D1 = LONG size of buffer

	NSTRUCTURE	local_dodisk,0
		NSTRUCT	ld_di,devi_SIZEOF	;DeviceInfo
		NSTRUCT	ld_devname,DEVNAMELEN	;devicename without ":"
		NLABEL	ld_SIZEOF

_LoadDisk	movem.l	d2-d7/a6,-(a7)
		link	LOC,#ld_SIZEOF
		moveq	#0,d7			;D7 = returncode (bufptr)
		moveq	#0,d6			;D6 = bufsize
		
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
		lea	(ld_devname,LOC),a0
		lea	(ld_di,LOC),a1
		bsr	_GetDeviceInfo
		tst.l	d0
		beq	.nodevi

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
		mulu32	d0,d2					;D2 = starttrack
	ENDC

		move.l	(ld_di+devi_HighCyl,LOC),d3
		sub.l	(ld_di+devi_LowCyl,LOC),d3
		addq.l	#1,d3
	IFEQ CPU-68020
		mulu.l	(ld_di+devi_Surfaces,LOC),d3
	ELSE
		move.l	(ld_di+devi_Surfaces,LOC),d0
		mulu32	d0,d3					;D3 = tracks
	ENDC

	IFEQ CPU-68020
		move.l	(ld_di+devi_SizeBlock,LOC),d4
		mulu.l	(ld_di+devi_BlocksPerTrack,LOC),d4
	ELSE
		move.l	(ld_di+devi_SizeBlock,LOC),d4
		move.l	(ld_di+devi_BlocksPerTrack,LOC),d0
		mulu32	d0,d4					;D4 = tracksize
	ENDC

		lea	(_m_diskgeo),a0
		move.l	d3,d6
		mulu32	d4,d6		;disksize = cyls * heads * blktrk * blksize
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
.add		addq.l	#1,d3				;D3 = tracks
		add.l	d4,d6				;D6 = readsize
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
		move.l	a0,d0				;D0 = devicename
		move.l	(ld_di+devi_Unit,LOC),d1	;D1 = unit
		move.l	d7,a1				;A1 = buffer
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
; Übergabe :	D0 = APTR  device name
;		D1 = ULONG unit number
;		D2 = ULONG start track
;		D3 = ULONG tracks
;		D4 = ULONG bytes per track
;		A1 = APTR  buffer to read data in
;		GL = STRUCT globals
; Rückgabe :	D0 = BOOL success

	NSTRUCTURE	local_readdisk,0
		NAPTR	lrd_device
		NULONG	lrd_unit
		NAPTR	lrd_buffer
		NAPTR	lrd_msgport
		LABEL	lrd_SIZEOF

_ReadDisk	movem.l	d2-d3/d7/a2/a6,-(a7)
		link	LOC,#lrd_SIZEOF
		move.l	d0,(lrd_device,LOC)
		move.l	d1,(lrd_unit,LOC)
		move.l	a1,(lrd_buffer,LOC)
		moveq	#-1,d7			;D7 = return (true)

		move.l	(gl_execbase,GL),a6	;A6 = execbase !!!
		jsr	(_LVOCreateMsgPort,a6)
		move.l	d0,(lrd_msgport,LOC)
		bne	.portok
		moveq	#0,d0
		lea	(_noport),a0
		sub.l	a1,a1
		bsr	_PrintError
		moveq	#0,d7
		bra	.noport
.portok		
		move.l	(lrd_msgport,LOC),a0
		move.l	#IOTD_SIZE,d0
		jsr	(_LVOCreateIORequest,a6)
		move.l	d0,a2
		tst.l	d0
		bne	.ioreqok
		moveq	#0,d0
		lea	(_noioreq),a0
		sub.l	a1,a1
		bsr	_PrintError
		moveq	#0,d7
		bra	.noioreq
.ioreqok
		move.l	(lrd_device,LOC),a0
		move.l	(lrd_unit,LOC),d0
		move.l	a2,a1			;ioreq
		move.l	#0,d1			;flags
	move.l	d3,-(a7)			;BUG in fucking mfm.device
		jsr	(_LVOOpenDevice,a6)
	move.l	(a7)+,d3			;BUG in fucking mfm.device
		tst.l	d0
		beq	.deviceok
		move.b	(IO_ERROR,a2),d0
		lea	(_opendevice),a0
		bsr	_PrintErrorTD
		moveq	#0,d7
		bra	.nodevice
.deviceok
		move.l	a2,a1
		move.w	#TD_CHANGENUM,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(IO_ACTUAL,a2),(IOTD_COUNT,a2)	;the diskchanges

		move.l	(lrd_buffer,LOC),(IO_DATA,a2)	;dest buf
		move.l	d2,d0
		mulu32	d4,d0
		move.l	d0,(IO_OFFSET,a2)		;begin at disk (offset)
		move.l	d4,(IO_LENGTH,a2)		;bytes per track
		move.w	#ETD_READ,(IO_COMMAND,a2)
		
		add.l	d2,d3				;d3 lasttrack

		bsr	_PrintLn
.loop		lea	(_diskprogress),a0		;output progress
		move.l	d3,-(a7)
		sub.l	d2,(a7)
		subq.l	#1,(a7)
		move.l	d2,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
		
		bsr	_CheckBreak			;check for CTRL-C
		tst.l	d0
		bne	.readbreak
		
		move.l	a2,a1				;read one track
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a2),d0
		bne	.readerr
.readfurther	addq.l	#1,d2
		cmp.l	d2,d3
		beq	.readok
		add.l	d4,(IO_OFFSET,a2)		;begin at disk (offset)
		add.l	d4,(IO_DATA,a2)			;dest buf
		bra	.loop

.readerr	lea	(_readdisk),a0
		bsr	_PrintErrorTD
		cmp.b	#TDERR_DiskChanged,(IO_ERROR,a2)
		beq	.readbreak
	;	tst.l	(gl_rd_ignoreerrors,GL)
	;	beq	.readbreak
		bsr	_PrintLn
		move.l	(IO_DATA,a2),a0			;fill unreadable area with "WRIP"
		move.l	(IO_LENGTH,a2),d0
		lsr.l	#2,d0
.fill		move.l	#"TDIC",(a0)+
		subq.l	#1,d0
		bne	.fill
		bra	.readfurther
.readbreak	moveq	#0,d7
.readok
		move.l	a2,a1
		move.l	#0,(IO_LENGTH,a1)
		move.w	#ETD_MOTOR,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)

		move.l	a2,a1
		jsr	(_LVOCloseDevice,a6)
		
.nodevice	move.l	a2,a0
		jsr	(_LVODeleteIORequest,a6)
		
.noioreq	move.l	(lrd_msgport,LOC),a0
		jsr	(_LVODeleteMsgPort,a6)
		
.noport		move.l	d7,d0
		unlk	LOC
		movem.l	(a7)+,d2-d3/d7/a2/a6
		rts

;##########################################################################


;##########################################################################

_defdev		dc.b	"DF0:",0
_insdisk	dc.b	10,"Insert disk %ld in drive %s and press RETURN (^C to cancel) ...",0
_tryagain	dc.b	"Retry/Cancel/Quit (r/c/Q) : ",0
_filefmt	dc.b	"Disk.%ld",0

;Messages
_m_readdisk	dc.b	"read from ",155,"1m%s",155,"22m: (%s %ld)",10,0
_m_diskgeo	dc.b	"(blksize=%ld heads=%ld blktrk=%ld lcyl=%ld hcyl=%ld) size=%ld",10,0
_m_savedisk	dc.b	"save disk as ",155,"3m%s ",155,"23m",10,0
_m_savefile	dc.b	"save file ",155,"3m%s ",155,"23m",10,0
_diskprogress	dc.b	11,"reading track %ld left %ld  ",10,0
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
		dc.b	",SIZE/K"		;number of bytes
		dc.b	",FD=FIRSTDISK/K/N"	;number of first disk
		dc.b	",LD=LASTDISK/K/N"	;number of last disk
		dc.b	0

_ver		VER
		dc.b	" ",155,"1mD",155,"22misk ",155,"1mI",155,"22mmage ",155,"1mC",155,"22mreator by Bert Jahn"
		dc.b	10,0

;##########################################################################

	END

