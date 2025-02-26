;*---------------------------------------------------------------------------
;  :Program.	AllocMemReverse.asm
;  :Contents.	patch exec.AllocMem to always use MEM_REVERSE
;  :Author.	Bert Jahn
;  :History.	29.08.06 created
;		2025-02-26 imported to wtools
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.9
;---------------------------------------------------------------------------*
;####################################################################

	INCDIR	Includes:
	INCLUDE	exec/execbase.i
	INCLUDE	exec/memory.i
	INCLUDE lvo/exec.i

;####################################################################

	IFD BARFLY
	OUTPUT	C:AllocMemReverse
	BOPT	O+				;enable optimizing
	BOPT	OG+				;enable optimizing
	ENDC

		bra	.start
		dc.b	"$VER: AllocMemReverse 1.0 "
	INCBIN	".date"
		dc.b	" by Wepl",0
	EVEN
.start

	;check exec version
		move.l	(4),a6
		cmp.w	#37,(LIB_VERSION,a6)
		blo	.badver

	;check if already patched
		move.l	(_LVOAllocMem+2,a6),a0
		cmp.l	#"AMRP",-(a0)
		beq	.already

	;alloc memory for patch
		move.l	#_end-_start,d0
		move.l	#MEMF_REVERSE,d1
		jsr	(_LVOAllocMem,a6)
		move.l	d0,d7
		beq	.nomem

	;disable interrupts/multitasking
		jsr	(_LVODisable,a6)

	;patch function
		move.l	a6,a1
		move.w	#_LVOAllocMem,a0
		move.l	d7,d0
		addq.l	#4,d0
		jsr	(_LVOSetFunction,a6)
		move.l	d0,_end-4

	;copy patch
		lea	(_start),a0
		move.l	d7,a1
		moveq	#(_end-_start+3)/4-1,d0
.copy		move.l	(a0)+,(a1)+
		dbf	d0,.copy

	;flush caches
		jsr	(_LVOCacheClearU,a6)

	;enable interrupts/multitasking
		jsr	(_LVOEnable,a6)

	;return
		moveq	#0,d0
		rts

.nomem		moveq	#10,d0
		rts

.already	moveq	#1,d0
		rts

.badver		moveq	#20,d0
		rts

_start		dc.l	"AMRP"
		bset	#MEMB_REVERSE,d1
		jmp	$10000000
_end
		

;####################################################################

	END

