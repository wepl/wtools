;*---------------------------------------------------------------------------
;  :Program.	WDate.asm
;  :Contents.	Create Date-String for $VER ... INCBIN
;  :Author.	Bert Jahn
;  :EMail.	jah@pub.th-zwickau.de
;  :Address.	Franz-Liszt-Straße 16, Rudolstadt, 07404, Germany
;  :History.	V 1.0 27-Feb-95
;		V 1.1 07.01.96 format changed (INT -> DOS)
;  :Copyright.	Public Domain
;  :Language.	68000 Assembler
;  :Translator.	Barfly V1.117
;---------------------------------------------------------------------------*
;####################################################################

	INCDIR	Includes:
	INCLUDE	dos/datetime.i
	INCLUDE	lvo/dos.i
	INCLUDE lvo/exec.i

	INCLUDE	macros/ntypes.i
	
	NSTRUCTURE	globals,0
		NSTRUCT	gl_datetime,dat_SIZEOF
		NSTRUCT	gl_strtime,LEN_DATSTRING
		NSTRUCT	gl_strdate,LEN_DATSTRING
		NALIGNLONG
		NLABEL  gl_SIZEOF
		
;####################################################################

	PURE				;set pure-bit
		bra	.start
		dc.b	"$VER: WDate 1.1 "
	DOSCMD	"WDate >T:date"
	INCBIN	"T:date"
		dc.b	" by Bert Jahn"
		dc.b	" (Create DateString for $VER using INCBIN)",0
	EVEN
.start
		link	a5,#gl_SIZEOF		;a5 = global vars
		moveq	#37,d0
		lea	(_dosname),a1
		move.l	(4),a6
		jsr	(_LVOOpenLibrary,a6)
		tst.l	d0
		beq	.quit
		move.l	d0,a6			;a6 = dosbase global !
		
		lea	(gl_datetime+dat_Stamp,a5),a0
		move.l	a0,d1
		jsr	(_LVODateStamp,a6)

		lea	(gl_datetime,a5),a0
		move.b	#FORMAT_DOS,(dat_Format,a0)
		clr.b	(dat_Flags,a0)
		clr.l	(dat_StrDay,a0)
		lea	(gl_strdate,a5),a1
		move.l	a1,(dat_StrDate,a0)
		lea	(gl_strtime,a5),a1
		move.l	a1,(dat_StrTime,a0)
		move.l	a0,d1
		jsr	(_LVODateToStr,a6)
		tst.l	d0
		beq	.closedos

		lea	(_outstr),a0
		move.l	a0,d1
		pea	(gl_strtime,a5)
		pea	(gl_strdate,a5)
		move.l	a7,d2
		jsr	(_LVOVPrintf,a6)
		addq.l	#8,a7

.closedos	move.l	a6,a1
		move.l	(4),a6
		jsr	(_LVOCloseLibrary,a6)
.quit		unlk	a5
		moveq	#0,d0
		rts

;####################################################################

_outstr		dc.b	"(%s%s)",0
_dosname	dc.b	"dos.library",0

;####################################################################

	END

