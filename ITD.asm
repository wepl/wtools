;*---------------------------------------------------------------------------
;  :Program.	ITD.asm
;  :Contents.	Image To Disk
;  :Author.	Bert Jahn
;  :Version.	$Id: ITD.asm 0.18 2012/12/19 03:57:43 wepl Exp wepl $
;  :History.	29.10.97 start, based on DIC source
;		24.11.98 some messages fixed when writing files larger than device
;		17.01.99 recompile because error.i changed
;		19.12.12 mulu32 replaced by utillib, correct size display/check for drives > 2GB,
;			 now requires v39
;		03.01.13 reading/writing files larger 4GB supported
;			 correct offset on writing if not starting on block #0
;			 async device operation implemented
;  :Requires.	OS V39+
;  :Copyright.	© 1997,1998,2012,2013 Bert Jahn, All Rights Reserved
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
	INCLUDE	lvo/locale.i
	INCLUDE	lvo/utility.i
	INCLUDE	dos/dos.i
	INCLUDE	devices/trackdisk.i
	INCLUDE	libraries/locale.i

	INCLUDE	macros/ntypes.i

TD_READ64	= 24
TD_WRITE64	= 25
TD_SEEK64	= 26
TD_FORMAT64	= 27
IO_HIGHOFFSET	= IO_ACTUAL

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
		ULONG	gl_rd_blocksize
		ULONG	gl_rd_async
		ULONG	gl_rd_force
		ULONG	gl_rc
		UBYTE	gl_grpsep	;loc_GroupSeparator
		ALIGNLONG
		LABEL	gl_SIZEOF

MAXDISKSIZE	= 2000000	;security -> max size file/device
MAXTRANSFER	= $1fe00	;print warning if above (130560)

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68000

Version	 = 1
Revision = 1

	IFD BARFLY
	PURE
	OUTPUT	C:ITD
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	BOPT	ODd-				;disable mul optimizing
	BOPT	ODe-				;disable mul optimizing
	;BOPT	sa+				;write symbol hunks
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

		move.b	#",",(gl_grpsep,GL)
		move.l	#38,d0
		lea	(_locname),a1
		jsr	(_LVOOpenLibrary,a6)
		tst.l	d0
		beq	.noloc
		move.l	d0,a6
		sub.l	a0,a0
		jsr	(_LVOOpenLocale,a6)
		tst.l	d0
		beq	.closeloc
		move.l	d0,a0
		move.l	(loc_GroupSeparator,a0),d0
		beq	.closeloc
		move.l	d0,a0
		move.b	(a0),(gl_grpsep,GL)
.closeloc	move.l	a6,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.noloc
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
		FlushOutput
		GetKey
		PrintLn
		PrintArgs
		Print
		CheckBreak
	INCLUDE	devices.i
		GetDeviceInfo
	INCLUDE	error.i
		PrintErrorDOS
		PrintErrorTD
	INCLUDE	strings.i
		FormatString

;##########################################################################

FILENAMELEN = 256

	NSTRUCTURE	local_main,0
		NSTRUCT	lm_len,8			;input file length 64-bit and write length
		NSTRUCT	lm_len1,28			;input file length ascii bytes
		NSTRUCT	lm_len2,16			;input file length ascii iec
		NSTRUCT	lm_dlen,8			;device length 64-bit
		NSTRUCT	lm_dlen1,28			;device length ascii bytes
		NSTRUCT	lm_dlen2,16			;device length ascii iec
		NSTRUCT	lm_name,FILENAMELEN		;input file name
		NSTRUCT	lm_di,devi_SIZEOF		;DeviceInfo
		NSTRUCT	lm_devname,DEVNAMELEN		;devicename without ":"
		NAPTR	lm_buffer			;buffer for io, 2x blocksize
		NSTRUCT	lm_start,8			;start offset 64-bit
		NULONG	lm_cycles			;amount of cycles
		NULONG	lm_msgport			;MessagePort
		NULONG	lm_ioreq			;IORequest
		NBYTE	lm_td64				;flag indicating if TD64 is required
		NBYTE	lm_pio				;pending io
		NALIGNLONG
		NLABEL	lm_SIZEOF

_Main		link	LOC,#lm_SIZEOF

	;open the file
		move.l	(gl_rd_file,GL),d1		;name
		move.l	#MODE_OLDFILE,d2		;mode
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOOpen,a6)
		move.l	d0,d7				;D7 = fh
		bne	.openok
		lea	(_openfile),a0
		bsr	_PrintErrorDOS
		bra	.erropen
.openok
	;get full filename
		move.l	d7,d1
		lea	(lm_name,LOC),a0
		clr.b	(a0)
		move.l	a0,d2
		move.l	#FILENAMELEN,d3
		jsr	(_LVONameFromFH,a6)

	;init vars
		clr.l	(lm_len,LOC)
		clr.l	(lm_len+4,LOC)

	;determine filelength 64-bit using 32-bit seeks (inefficient for large files)
	;depends on that seeks outside the file will leave the
	;current position unchanged
		move.l	d7,d1				;fh
		moveq	#0,d2				;offset
		move.l	#OFFSET_END,d3			;mode
		jsr	(_LVOSeek,a6)
		jsr	(_LVOIoErr,a6)			;v36/37 doesn't set rc correctly
		tst.l	d0
		beq	.seek_loop
.seekerr	lea	(_seekfile),a0
		bsr	_PrintErrorDOS
		bra	.errseek

.seek_loop	move.l	d7,d1				;fh
		move.l	#-$40000000,d2			;offset -1GB
		move.l	#OFFSET_CURRENT,d3		;mode
		jsr	(_LVOSeek,a6)
		jsr	(_LVOIoErr,a6)			;v36/37 doesn't set rc correctly
		tst.l	d0
		bne	.seek_last
		sub.l	d2,(lm_len+4,LOC)
		bne	.seek_loop
		addq.l	#1,(lm_len,LOC)
		bra	.seek_loop

.seek_last	move.l	d7,d1				;fh
		moveq	#0,d2				;offset
		move.l	#OFFSET_BEGINNING,d3		;mode
		jsr	(_LVOSeek,a6)
		add.l	d0,(lm_len+4,LOC)
		jsr	(_LVOIoErr,a6)			;v36/37 doesn't set rc correctly
		tst.l	d0
		bne	.seekerr

	;print file info
		movem.l	(lm_len,LOC),d0-d1		;value
		move.l	#10000,d2			;shift down border
		moveq	#16,d3				;buffer length
		lea	(lm_len2,LOC),a0		;buffer
		bsr	_lltoas
		movem.l	(lm_len,LOC),d0-d1		;value
		lea	(lm_len1,LOC),a0		;buffer
		bsr	_lltoa
		pea	(lm_len2,LOC)
		move.l	a0,-(a7)
		lea	(_m_loadfile),a0
		pea	(lm_name,LOC)
		move.l	a7,a1
		bsr	_PrintArgs
		add.l	#12,a7

	;remove trailing colon from device name
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
	;obtain device info
		lea	(lm_devname,LOC),a0
		lea	(lm_di,LOC),a1
		bsr	_GetDeviceInfo
		tst.l	d0
		beq	.nodevi

	;calculate device size
		move.l	(lm_di+devi_HighCyl,LOC),d0
		sub.l	(lm_di+devi_LowCyl,LOC),d0
		addq.l	#1,d0					;cylinders
		move.l	(lm_di+devi_Surfaces,LOC),d1
		move.l	(gl_utilbase,GL),a2			;A2 = utilbase
		jsr	(_LVOUMult32,a2)
		move.l	(lm_di+devi_BlocksPerTrack,LOC),d1
		jsr	(_LVOUMult32,a2)
		move.l	(lm_di+devi_SizeBlock,LOC),d1
		jsr	(_LVOUMult64,a2)
		move.l	d0,(lm_dlen+4,LOC)
		move.l	d1,(lm_dlen,LOC)
		exg.l	d0,d1				;value
		move.l	#10000,d2			;shift down border
		moveq	#16,d3				;buffer length
		lea	(lm_dlen2,LOC),a0		;buffer
		bsr	_lltoas
		movem.l	(lm_dlen,LOC),d0-d1		;value
		lea	(lm_dlen1,LOC),a0		;buffer
		bsr	_lltoa
	;print device info
		pea	(lm_dlen2,LOC)
		pea	(a0)				;(lm_dlen1,LOC)
		move.l	(lm_di+devi_HighCyl,LOC),-(a7)
		move.l	(lm_di+devi_LowCyl,LOC),-(a7)
		move.l	(lm_di+devi_BlocksPerTrack,LOC),-(a7)
		move.l	(lm_di+devi_Surfaces,LOC),-(a7)
		move.l	(lm_di+devi_SizeBlock,LOC),-(a7)
		move.l	(lm_di+devi_Unit,LOC),-(a7)
		pea	(lm_di+devi_Device,LOC)
		pea	(lm_devname,LOC)
		move.l	a7,a1
		lea	(_m_writedisk),a0
		bsr	_PrintArgs
		add.w	#10*4,a7

	;calculate blocksize
		move.l	(gl_rd_blocksize,GL),d0
		beq	.bscalc
		move.l	d0,a0
		move.l	(a0),d0
		moveq	#3,d1
		and.l	d0,d1
		bne	.bsbad
		cmp.l	(lm_di+devi_SizeBlock,LOC),d0
		bhs	.bsset
.bsbad		lea	(_badblocksize),a0
		bsr	_Print
		bra	.badblocksize
.bsset		move.l	d0,(gl_rd_blocksize,GL)
		bra	.bsprint
.bscalc		move.l	(lm_di+devi_BlocksPerTrack,LOC),d0
		move.l	(lm_di+devi_SizeBlock,LOC),d1
		jsr	(_LVOUMult32,a2)
		move.l	d0,(gl_rd_blocksize,GL)
.bsprint	moveq	#0,d0
		move.l	(gl_rd_blocksize,GL),d1		;value
		sub.w	#28,a7
		move.l	a7,a0				;buffer
		bsr	_lltoa
		move.l	a0,-(a7)			;string without leading zeros
		move.l	(gl_rd_blocksize,GL),d0
		move.l	(lm_di+devi_SizeBlock,LOC),d1
		jsr	(_LVOUDivMod32,a2)
		sub.l	a0,a0
		tst.l	d1				;reminder
		beq	.bsok
		lea	(_m_blocksize_wa),a0
.bsok		move.l	a0,-(a7)
		lea	(_m_blocksize),a0
		move.l	(4,a7),-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#28+12,a7
		cmp.l	#MAXTRANSFER,(gl_rd_blocksize,GL)
		bls	.bslok
		lea	(_m_blocksize_wl),a0
		bsr	_Print
.bslok
	;calculate start offset
		move.l	(lm_di+devi_LowCyl,LOC),d0
		move.l	(lm_di+devi_Surfaces,LOC),d1
		jsr	(_LVOUMult32,a2)
		move.l	(lm_di+devi_BlocksPerTrack,LOC),d1
		jsr	(_LVOUMult32,a2)
		move.l	(lm_di+devi_SizeBlock,LOC),d1
		jsr	(_LVOUMult64,a2)
		move.l	d0,(lm_start+4,LOC)
		move.l	d1,(lm_start,LOC)

	;allocate the block buffer
		move.l	(gl_rd_blocksize,GL),d0
		add.l	d0,d0					;2 times for async operation
		moveq	#MEMF_PUBLIC,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,(lm_buffer,LOC)
		bne	.bufferok
		lea	(_nobuffer),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.nobuffer
.bufferok
	;check filesize alignment
		movem.l	(lm_len,LOC),d0-d1
		move.l	(lm_di+devi_SizeBlock,LOC),d2
.fstst		tst.l	d0
		beq	.fsdiv
		lsr.l	#1,d0
		roxr.l	#1,d1
		bcs	.fsbad
		lsr.l	#1,d2
		bcs	.fsbad
		bra	.fstst
.fsdiv		move.l	d1,d0
		move.l	d2,d1
		jsr	(_LVOUDivMod32,a2)
		tst.l	d1				;reminder
		beq	.fsok
.fsbad		lea	(_m_filesize_wa),a0
		bsr	_Print
.fsok
	;check for large file/device
		tst.l	(gl_rd_force,GL)
		bne	.dsizeok
		tst.l	(lm_len,LOC)
		bne	.fsizefail
		cmp.l	#MAXDISKSIZE,(lm_len+4,LOC)
		blo	.fsizeok
.fsizefail	lea	(_bigfsize),a0
		bsr	_Print
		bra	.bigsize
.fsizeok
		tst.l	(lm_dlen,LOC)
		bne	.dsizefail
		cmp.l	#MAXDISKSIZE,(lm_dlen+4,LOC)
		blo	.dsizeok
.dsizefail	lea	(_bigdsize),a0
		bsr	_Print
		bra	.bigsize
.dsizeok
	;compare file to disk size, print warning, cut file size if device smaller
		lea	(lm_len,LOC),a1
		lea	(lm_dlen,LOC),a0
		cmp.l	(a0)+,(a1)+
		blo	.small
		bhi	.big
		move.l	(a1),d1
		cmp.l	(a0),d1
		blo	.small
		bhi	.big
		beq	.equal
.big		move.l	(a0),(a1)				;copy device length to file
		move.l	-(a0),-(a1)
		lea	(_tobig),a0
		bra	.p
.small		lea	(_tosmall),a0
.p		bsr	_Print
.equal
	;calculate cycle count
	;because we miss a 64-bit div for very large values this is only an approximation
	;we divide by 2 until length fits into 32-bit
		movem.l	(lm_len,LOC),d0-d1
		move.l	(gl_rd_blocksize,GL),d2
.cctst		tst.l	d0
		beq	.ccdiv
		lsr.l	#1,d0
		roxr.l	#1,d1
		lsr.l	#1,d2
		bra	.cctst
.ccdiv		move.l	d1,d0
		move.l	d2,d1
		jsr	(_LVOUDivMod32,a2)
		tst.l	d1					;remainder
		beq	.ccset
		addq.l	#1,d0
.ccset		move.l	d0,(lm_cycles,LOC)

	;ask for continue if force set
		tst.l	(gl_rd_force,GL)
		beq	.continue
		lea	(_m_continue),a0
		bsr	_Print
		bsr	_FlushOutput
		bsr	_GetKey
		move.b	d0,d2
		bsr	_PrintLn
		UPPER	d2
		cmp.b	#"Y",d2
		bne	.notcontinue
.continue
	;check requirement for TD64 (end behind 4GB)
		movem.l	(lm_start,LOC),d0-d1
		movem.l	(lm_len,LOC),d2-d3
		add.l	d3,d1
		addx.l	d2,d0
		tst.l	d0
		sne	(lm_td64,LOC)

	;inhibit the drive
		move.l	(gl_rd_device,GL),d1
		moveq	#-1,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)

	;create message port
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCreateMsgPort,a6)
		move.l	d0,(lm_msgport,LOC)
		bne	.portok
		lea	(_noport),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noport
.portok
	;create the IORequest structure
		move.l	d0,a0					;msgport
		move.l	#IOTD_SIZE,d0
		jsr	(_LVOCreateIORequest,a6)
		move.l	d0,(lm_ioreq,LOC)
		bne	.ioreqok
		lea	(_noioreq),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noioreq
.ioreqok
	;open the device
		lea	(lm_di+devi_Device,LOC),a0
		move.l	(lm_di+devi_Unit,LOC),d0
		move.l	(lm_ioreq,LOC),a1			;ioreq
		move.l	#0,d1					;flags
		move.l	d3,-(a7)				;BUG in fucking mfm.device
		jsr	(_LVOOpenDevice,a6)
		move.l	(a7)+,d3				;BUG in fucking mfm.device
		tst.l	d0
		beq	.deviceok
		lea	(_opendevice),a0
		bsr	_PrintErrorTD
		bra	.nodevice
.deviceok
	;get actual disk change count
		move.l	(lm_ioreq,LOC),a1
		move.w	#TD_CHANGENUM,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(lm_ioreq,LOC),a1
		move.l	(IO_ACTUAL,a1),(IOTD_COUNT,a1)		;the diskchange count

	;copy loop init
		move.l	(lm_buffer,LOC),a2			;A2 = buffer
		move.l	a2,a3
		add.l	(gl_rd_blocksize,GL),a3			;A3 = buffer
		movem.l	(lm_len,LOC),d4-d5			;D4:D5 = length
		moveq	#0,d6					;D6 = actual cycle counter
		sf	(lm_pio,LOC)
		bsr	_PrintLn

	;copy loop
.loop		lea	(_diskprogress),a0			;output progress
		move.l	(lm_cycles,LOC),d0
		subq.l	#1,d0
		sub.l	d6,d0
		bpl	.ccok
		moveq	#0,d0
.ccok		move.l	d0,-(a7)
		move.l	d6,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7

		bsr	_CheckBreak				;check for CTRL-C
		tst.l	d0
		bne	.break

	;read file
		move.l	d7,d1					;fh
		move.l	a2,d2					;buffer
		move.l	(gl_rd_blocksize,GL),d3			;length
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVORead,a6)
		cmp.l	d0,d3
		beq	.readok
		tst.l	d4
		bne	.readfail
		cmp.l	d0,d5
		beq	.readlast
.readfail	lea	(_readfile),a0
		bsr	_PrintErrorDOS
		bra	.break
	;if file is not device block aligned fill with zeros
	;and round up to block size of device
.readlast	lea	(a2,d0.l),a0				;start
		move.l	d0,d2
		move.l	(lm_di+devi_SizeBlock,LOC),d1
		subq.l	#1,d1
		add.l	d1,d0
		not.l	d1
		and.l	d1,d0
		move.l	d0,(gl_rd_blocksize,GL)
		sub.l	d2,d0					;bytes to fill
		add.l	d0,d5					;correct size
		lsr.l	#2,d0					;longs
		subq.l	#1,d0
.clr		clr.l	(a0)+
		dbf	d0,.clr
.readok

	;wait for previous wait operation to end
		bclr	#0,(lm_pio,LOC)
		beq	.noasyncwait
		move.l	(lm_ioreq,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOWaitIO,a6)
		tst.b	d0
		beq	.noasyncwait
		lea	(_writedisk),a0
		bsr	_PrintErrorTD
		bra	.break
.noasyncwait

	;write disk
		move.l	(lm_ioreq,LOC),a1
		move.l	a2,(IO_DATA,a1)				;buffer
		move.l	(lm_start+4,LOC),(IO_OFFSET,a1)		;begin on disk (offset)
		move.l	(gl_rd_blocksize,GL),d0
		tst.l	d4
		bne	.setlen
		cmp.l	d5,d0
		blo	.setlen
		move.l	d5,d0
		move.l	d0,(gl_rd_blocksize,GL)
.setlen		move.l	d0,(IO_LENGTH,a1)			;blocksize
		move.w	#ETD_WRITE,d0
		tst.l	(gl_rd_format,GL)
		beq	.noformat
		move.w	#ETD_FORMAT,d0
.noformat	tst.b	(lm_td64,LOC)
		beq	.notd64
		moveq	#TD_WRITE64,d0
		move.l	(lm_start,LOC),(IO_HIGHOFFSET,a1)	;begin on disk (offset)
.notd64		move.w	d0,(IO_COMMAND,a1)
		move.l	(gl_execbase,GL),a6
		tst.l	(gl_rd_async,GL)
		beq	.noasync
		jsr	(_LVOSendIO,a6)
		bset	#0,(lm_pio,LOC)
		bra	.writeok
.noasync	jsr	(_LVODoIO,a6)
		tst.b	d0
		beq	.writeok
		lea	(_writedisk),a0
		bsr	_PrintErrorTD
		bra	.break
.writeok
		moveq	#0,d0
		move.l	(gl_rd_blocksize,GL),d1
		sub.l	d1,d5
		subx.l	d0,d4					;bytes left
		add.l	d1,(lm_start+4,LOC)
		move.l	(lm_start,LOC),d1
		addx.l	d0,d1
		move.l	d1,(lm_start,LOC)			;start offset
		addq.l	#1,d6					;cycles
		exg.l	a2,a3					;buffer swap

		tst.l	d4
		bne	.loop
		tst.l	d5
		bne	.loop
		clr.l	(gl_rc,GL)				;success
.break
	;wait for previous wait operation to end
		bclr	#0,(lm_pio,LOC)
		beq	.asyncend
		move.l	(lm_ioreq,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOWaitIO,a6)
		tst.b	d0
		beq	.asyncend
		lea	(_writedisk),a0
		bsr	_PrintErrorTD
.asyncend
		move.l	(lm_ioreq,LOC),a1
		move.w	#ETD_UPDATE,(IO_COMMAND,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)

		tst.l	(gl_rd_force,GL)		;don't switch motor off if force used (assumed harddisk)
		bne	.skipmotor
		move.l	(lm_ioreq,LOC),a1
		move.l	#0,(IO_LENGTH,a1)
		move.w	#ETD_MOTOR,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
.skipmotor
		move.l	(lm_ioreq,LOC),a1
		jsr	(_LVOCloseDevice,a6)
.nodevice
		move.l	(lm_ioreq,LOC),a0
		jsr	(_LVODeleteIORequest,a6)
.noioreq
		move.l	(lm_msgport,LOC),a0
		jsr	(_LVODeleteMsgPort,a6)
.noport
		move.l	(gl_rd_device,GL),d1
		moveq	#0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)
.notcontinue
.bigsize
		move.l	(lm_buffer,LOC),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.nobuffer
.badblocksize
.nodevi
.errseek
		move.l	d7,d1				;fh
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOClose,a6)
.erropen
		unlk	LOC
		rts

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;----------------------------------------
; convert 64-bit unsigned long long into string rounded to IEC-prefix
; IN:	D0 = ULONG msl (most significant long)
;	D1 = ULONG lsl (lowest significant long)
;	D2 = ULONG max value left unconverted
;	D3 = ULONG buffer size
;	A0 = APTR  buffer to fill
; OUT:	-

_lltoas		movem.l	d3-d5/a2,-(a7)

		moveq	#0,d4			;shift count

.msl_loop	tst.l	d0
		beq	.msl_clear
		moveq	#9,d5
.msl_shift	lsr.l	#1,d0
		roxr.l	#1,d1
		dbf	d5,.msl_shift
		addq.l	#1,d4
		bra	.msl_loop
.msl_clear
		moveq	#10,d5
.lsl_loop	cmp.l	d2,d1
		blo	.lsl_end
		lsr.l	d5,d1
		addq.l	#1,d4
		bra	.lsl_loop
.lsl_end
		move.l	a0,a2
		lea	(.fmts),a0
		tst.w	d4
		beq	.noshift
		lea	(.fmt),a0
		move.b	(.iec-1,pc,d4.w),d0
		moveq	#"i",d5
.noshift	movem.w	d0/d5,-(a7)
		move.l	d1,-(a7)
		move.l	a7,a1
		move.l	d3,d0
		bsr	_FormatString

		movem.l	(a7)+,d0-d1/d3-d5/a2
		rts

.iec		dc.b	"KMGTPE"
.fmt		dc.b	"%ld %c%cB",0
.fmts		dc.b	"%ld B",0
	EVEN

;----------------------------------------
; convert 64-bit unsigned long long into string with delimiters
; LLONG_MAX/MIN has 20 digits
; IN:	D0 = ULONG msl (most significant long)
;	D1 = ULONG lsl (lowest significant long)
;	A0 = APTR  buffer to fill, 28 bytes at least
; OUT:	A0 = CPTR  converted ascii without leading zeros

_lltoa		movem.l	d2-d6/a2,-(a7)

		move.l	a0,a1

		lea	.tab,a2
		moveq	#2,d3			;delimiter count
		moveq	#0,d6			;flag number start

.loop		moveq	#"0",d2
		movem.l	(a2)+,d4-d5

.sub		sub.l	d5,d1
		subx.l	d4,d0
		bcs	.ov
		addq.l	#1,d2
		bra	.sub

.ov		add.l	d5,d1
		addx.l	d4,d0
		cmp.b	#"0",d2
		beq	.notstart
		bset	#0,d6
		bne	.notstart
		move.l	a1,a0
.notstart
		move.b	d2,(a1)+
		subq.w	#1,d3
		bne	.nodeli
		move.b	(gl_grpsep,GL),(a1)+
		moveq	#3,d3
.nodeli
		tst.l	(4,a2)
		bne	.loop
		add.b	#"0",d1
		move.b	d1,(a1)+
		clr.b	(a1)+

		movem.l	(a7)+,d2-d6/a2
		rts

.tab		dc.l	$8ac72304,$89e80000	;10000000000000000000
		dc.l	$de0b6b3,$a7640000	;1000000000000000000
		dc.l	$1634578,$5d8a0000	;100000000000000000
		dc.l	$2386f2,$6fc10000	;10000000000000000
		dc.l	$38d7e,$a4c68000	;1000000000000000
		dc.l	$5af3,$107a4000	;100000000000000
		dc.l	$918,$4e72a000	;10000000000000
		dc.l	$e8,$d4a51000	;1000000000000
		dc.l	$17,$4876e800	;100000000000
		dc.l	2,$540be400	;10000000000
		dc.l	0,$3b9aca00	;1000000000
		dc.l	0,$5f5e100	;100000000
		dc.l	0,$989680	;10000000
		dc.l	0,$f4240	;1000000
		dc.l	0,$186a0	;100000
		dc.l	0,$2710	;10000
		dc.l	0,$3e8	;1000
		dc.l	0,$64	;100
		dc.l	0,$a	;10
		dc.l	0,0

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

_defdev		dc.b	"DF0:",0

;Messages
_m_loadfile	dc.b	"input file ",155,"1m%s",155,"22m, %s bytes, %s",10,0
_m_writedisk	dc.b	"destination device ",155,"1m%s",155,"22m: (%s %ld)",10
		dc.b	"(blksize=%lu heads=%lu blktrk=%lu lcyl=%lu hcyl=%lu) %s bytes, %s",10,0
_m_filesize_wa	dc.b	"WARNING input file size not aligned to device's blocksize (filling up with zeros)",10,0
_m_blocksize	dc.b	"using blocksize of %s bytes%s",10,0
_m_blocksize_wa	dc.b	", WARNING blocksize not aligned to device's blocksize",0
_m_blocksize_wl	sprintx	"WARNING blocksize larger than $%lx bytes, some devices don't support that",MAXTRANSFER
		dc.b	10,0
_m_continue	dc.b	"press 'y' to continue",0
_diskprogress	dc.b	11,"writing block %lu left %lu  ",10,0

; Errors
_nomem		dc.b	"not enough free store",0
_nobuffer	dc.b	"can't allocate buffer",0
_noport		dc.b	"can't create MessagePort",0
_noioreq	dc.b	"can't create IO-Request",0
_nodev		dc.b	"device doesn't exist",0
_baddev		dc.b	"cannot handle this device",0
_badblocksize	dc.b	"blocksize cannot be smaller than blksize of device and must be divisible by 4",10,0
_bigfsize	dc.b	"file is too large",10,0
_bigdsize	dc.b	"device is too large",10,0
_tosmall	dc.b	"WARNING input file is smaller than device",10,0
_tobig		dc.b	"WARNING input file is bigger than device (writing not more than device capacity)",10,0

; Operationen
_readargs	dc.b	"read arguments",0
_openfile	dc.b	"open file",0
_seekfile	dc.b	"seek file",0
_readfile	dc.b	"read file",0
_writedisk	dc.b	"write disk",0
_getdevinfo	dc.b	"get device info",0
_opendevice	dc.b	"open device",0

;subsystems
_dosname	DOSNAME
_utilname	dc.b	"utility.library",0
_locname	dc.b	"locale.library",0

_template	dc.b	"File/A"		;file write to disk
		dc.b	",Device"		;name of device (default "DF0:)
		dc.b	",Format/S"		;format device
		dc.b	",BS=BlockSize/N"	;length of data block to transfer
		dc.b	",ASync/S"		;asynchronous operation
		dc.b	",ForceOverwriteLargeDevice/S"	;large file/device enable
		dc.b	0

_ver		VER
		dc.b	" ",155,"1mI",155,"22mmage ",155,"1mT",155,"22mo ",155,"1mD",155,"22misk by Bert Jahn"
		dc.b	10,0

;##########################################################################

	END
