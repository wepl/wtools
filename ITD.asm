;*---------------------------------------------------------------------------
;  :Program.	ITD.asm
;  :Contents.	Image To Disk
;  :Author.	Bert Jahn
;  :Version.	$Id: ITD.asm 0.17 1999/01/17 14:18:31 jah Exp jah $
;  :History.	29.10.97 start, based on DIC source
;		24.11.98 some messages fixed when writing files larger than device
;		17.01.99 recompile because error.i changed
;		19.12.12 mulu32 replaced by utillib, correct size display/check for drives > 2GB,
;			 now requires v39
;  :Requires.	OS V39+
;  :Copyright.	© 1997,1998,2012 Bert Jahn, All Rights Reserved
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
	INCLUDE	lvo/utility.i
	INCLUDE	dos/dos.i
	INCLUDE	devices/trackdisk.i

	INCLUDE	macros/ntypes.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	STRUCTURE	Globals,0
		APTR	gl_execbase
		APTR	gl_dosbase
		APTR	gl_utilbase
		APTR	gl_rdargs
		LABEL	gl_rdarray
		ULONG	gl_rd_file
		ULONG	gl_rd_device
		ULONG	gl_rd_format
		ULONG	gl_rc
		ALIGNLONG
		LABEL	gl_SIZEOF

BREAKCOUNT	= 1000
MAXDISKSIZE	= 2000000	;security -> max size file/device

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68000

Version	 = 0
Revision = 18

	IFD BARFLY
	PURE
	OUTPUT	C:ITD
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	ENDC

	IFND	.passchk
	DOSCMD	"WDate >T:date"
.passchk
	ENDC

VER	MACRO
		sprintx	"ITD %ld.%ld ",Version,Revision
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
		jsr	_LVOOpenLibrary(a6)
		move.l	d0,(gl_dosbase,GL)
		beq	.nodoslib

		move.l	#39,d0
		lea	(_utilname),a1
		jsr	_LVOOpenLibrary(a6)
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
		bsr	_Main

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

.nostrucmem	moveq	#20,d0
		rts

;##########################################################################

	INCDIR	Sources:
	INCLUDE	dosio.i
		PrintLn
		PrintArgs
		Print
		CheckBreak
	INCLUDE	files.i
		LoadFileMsg
	INCLUDE	devices.i
		GetDeviceInfo
	INCLUDE	error.i
		PrintErrorTD

;##########################################################################

	NSTRUCTURE	local_main,0
		NSTRUCT	lm_di,devi_SIZEOF			;DeviceInfo
		NSTRUCT	lm_devname,DEVNAMELEN			;devicename without ":"
		NLABEL	lm_SIZEOF

_Main		link	LOC,#lm_SIZEOF

		move.l	(gl_rd_file,GL),a0
		bsr	_LoadFileMsg
		move.l	d0,d7					;D7 = file
		beq	.nofile
		move.l	d1,d6					;D6 = file length
		beq	.nofile
		
		cmp.l	#MAXDISKSIZE,d6
		blo	.fsizeok
		lea	(_bigfsize),a0
		bsr	_Print
		bra	.bigfsize
.fsizeok
		move.l	(gl_rd_device,GL),a0
		lea	(lm_devname,LOC),a1
		moveq	#DEVNAMELEN-1,d0
.c		move.b	(a0)+,(a1)+
		dbeq	d0,.c
		clr.b	-(a1)
		move.b	-(a1),d0
		cmp.b	#":",d0
		bne	.1
		clr.b	(a1)
.1
		lea	(lm_devname,LOC),a0
		lea	(lm_di,LOC),a1
		bsr	_GetDeviceInfo
		tst.l	d0
		beq	.nodevi

		lea	(_m_writedisk),a0
		move.l	(lm_di+devi_Unit,LOC),-(a7)
		pea	(lm_di+devi_Device,LOC)
		pea	(lm_devname,LOC)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#12,a7

		move.l	(lm_di+devi_HighCyl,LOC),d0
		sub.l	(lm_di+devi_LowCyl,LOC),d0
		addq.l	#1,d0					;cylinders
		move.l	(lm_di+devi_Surfaces,LOC),d1
		move.l	(gl_utilbase,GL),a0
		jsr	(_LVOUMult32,a0)
		move.l	(lm_di+devi_BlocksPerTrack,LOC),d1
		jsr	(_LVOUMult32,a0)
		move.l	(lm_di+devi_SizeBlock,LOC),d1
		jsr	(_LVOUMult64,a0)
		move.l	d0,d5
		move.l	d1,d4					;D4:D5 = disk size

		moveq	#0,d2
		tst.l	d1
		bne	.k
		cmp.l	#1000000,d0
		blo	.go
.k		moveq	#"K",d2
		and.w	#-1<<10,d0
		move.w	d1,d3
		and.w	#$3ff,d3
		or.w	d3,d0
		moveq	#10,d3
		ror.l	d3,d0
		lsr.l	d3,d1
		bne	.m
		cmp.l	#1000000,d0
		blo	.go
.m		moveq	#"M",d2
		and.w	#-1<<10,d0
		move.w	d1,d3
		and.w	#$3ff,d3
		or.w	d3,d0
		moveq	#10,d3
		ror.l	d3,d0
.go
		lea	(_m_diskgeo),a0
		move.l	d2,-(a7)
		move.l	d0,-(a7)
		move.l	(lm_di+devi_HighCyl,LOC),-(a7)
		move.l	(lm_di+devi_LowCyl,LOC),-(a7)
		move.l	(lm_di+devi_BlocksPerTrack,LOC),-(a7)
		move.l	(lm_di+devi_Surfaces,LOC),-(a7)
		move.l	(lm_di+devi_SizeBlock,LOC),-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#7*4,a7

		tst.l	d4
		bne	.dsizefail
		cmp.l	#MAXDISKSIZE,d5
		blo	.dsizeok
.dsizefail	lea	(_bigdsize),a0
		bsr	_Print
		bra	.bigdsize
.dsizeok
		cmp.l	d5,d6
		beq	.equal
		blo	.small
		move.l	d5,d6
		lea	(_tobig),a0
		bra	.p
.small		lea	(_tosmall),a0
.p		bsr	_Print
.equal
		move.l	(gl_rd_device,GL),d1
		moveq	#-1,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)
		
		move.l	(gl_execbase,GL),a6			;A6 = execbase !!!
		jsr	(_LVOCreateMsgPort,a6)
		move.l	d0,d4					;D4 = msgport
		bne	.portok
		moveq	#0,d0
		lea	(_noport),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noport
.portok		
		move.l	d4,a0
		move.l	#IOTD_SIZE,d0
		jsr	(_LVOCreateIORequest,a6)
		move.l	d0,a2					;A2 = ioreq
		tst.l	d0
		bne	.ioreqok
		moveq	#0,d0
		lea	(_noioreq),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noioreq
.ioreqok
		lea	(lm_di+devi_Device,LOC),a0
		move.l	(lm_di+devi_Unit,LOC),d0
		move.l	a2,a1					;ioreq
		move.l	#0,d1					;flags
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
		move.l	a2,a1
		move.w	#TD_CHANGENUM,(IO_COMMAND,a2)
		jsr	(_LVODoIO,a6)
		move.l	(IO_ACTUAL,a2),(IOTD_COUNT,a2)		;the diskchanges

		move.l	(lm_di+devi_BlocksPerTrack,LOC),d0
		move.l	(lm_di+devi_SizeBlock,LOC),d1
		move.l	(gl_utilbase,GL),a0
		jsr	(_LVOUMult32,a0)
		move.l	d0,d5					;D5 = track size
		
		moveq	#0,d2					;D2 = actual track

		move.l	d6,d3
		add.l	d5,d3
		subq.l	#1,d3
		divu	d5,d3
		ext.l	d3					;D3 = tracks to write

		move.l	d7,(IO_DATA,a2)				;buffer
		clr.l	(IO_OFFSET,a2)				;begin on disk (offset)
		move.l	d5,(IO_LENGTH,a2)			;bytes per track
		
		bsr	_PrintLn
.loop		lea	(_diskprogress),a0			;output progress
		move.l	d3,-(a7)
		subq.l	#1,(a7)
		move.l	d2,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
		
		bsr	_CheckBreak				;check for CTRL-C
		tst.l	d0
		bne	.readbreak
		
		tst.l	(gl_rd_format,GL)
		beq	.write
.format
		move.w	#ETD_FORMAT,(IO_COMMAND,a2)
		move.l	a2,a1					;read one track
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a2),d0
		bne	.readerr
		bra	.verify
.write
		move.w	#ETD_WRITE,(IO_COMMAND,a2)
		move.l	a2,a1					;read one track
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a2),d0
		bne	.readerr
.verify
		addq.l	#1,d2
		subq.l	#1,d3
		beq	.readok
		add.l	d5,(IO_OFFSET,a2)			;begin on disk (offset)
		add.l	d5,(IO_DATA,a2)				;buffer
		bra	.loop

.readok		clr.l	(gl_rc,GL)				;success
		bra	.update

.readerr	lea	(_writedisk),a0
		bsr	_PrintErrorTD
.readbreak
.update
		move.l	a2,a1
		move.w	#ETD_UPDATE,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)

		move.l	a2,a1
		move.l	#0,(IO_LENGTH,a1)
		move.w	#ETD_MOTOR,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)

		move.l	a2,a1
		jsr	(_LVOCloseDevice,a6)
.nodevice
		move.l	a2,a0
		jsr	(_LVODeleteIORequest,a6)
.noioreq
		move.l	d4,a0
		jsr	(_LVODeleteMsgPort,a6)
.noport
		move.l	(gl_rd_device,GL),d1
		moveq	#0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)
.bigdsize
.nodevi
.bigfsize
		move.l	d7,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)

.nofile		unlk	LOC
		rts

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

_defdev		dc.b	"DF0:",0

;Messages
_m_writedisk	dc.b	"write to ",155,"1m%s",155,"22m: (%s %ld)",10,0
_m_diskgeo	dc.b	"(blksize=%lu heads=%lu blktrk=%lu lcyl=%lu hcyl=%lu) size=%lu %lcByte",10,0
_diskprogress	dc.b	11,"writing track %ld left %ld  ",10,0

; Errors
_nomem		dc.b	"not enough free store",0
_noport		dc.b	"can't create MessagePort",0
_noioreq	dc.b	"can't create IO-Request",0
_nodev		dc.b	"device doesn't exist",0
_baddev		dc.b	"cannot handle this device",0
_bigfsize	dc.b	"file is too large",10,0
_bigdsize	dc.b	"device is too large",10,0
_tosmall	dc.b	"WARNING file is smaller than device",10,0
_tobig		dc.b	"WARNING file is bigger than device",10,0

; Operationen
_readargs	dc.b	"read arguments",0
_writedisk	dc.b	"write disk",0
_getdevinfo	dc.b	"get dev info",0
_opendevice	dc.b	"open device",0

;subsystems
_dosname	DOSNAME
_utilname	dc.b	"utility.library",0

_template	dc.b	"FILE/A"		;file write to disk
		dc.b	",DEVICE"		;name of device (default "DF0:)
		dc.b	",FORMAT/S"		;format device
		dc.b	0

_ver		VER
		dc.b	" ",155,"1mI",155,"22mmage ",155,"1mT",155,"22mo ",155,"1mD",155,"22misk by Bert Jahn"
		dc.b	10,0

;##########################################################################

	END

