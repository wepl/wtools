;*---------------------------------------------------------------------------
;  Test program for _VSNPrintF 64-bit support
;  Tests %llx, %lld, %llu format specifiers
;  Requires AmigaOS, dos.library v37+
;*---------------------------------------------------------------------------

	INCLUDE	lvo/exec.i
	INCLUDE	lvo/dos.i
	INCLUDE	sources/strings.i

BUFSIZE = 256

	; open dos.library v37
	move.l	(4).w,a6
	lea	(.dosname,pc),a1
	moveq	#37,d0
	jsr	(_LVOOpenLibrary,a6)
	move.l	d0,a5			;a5 = dosbase
	move.l	d0,d1
	beq	.exit

	; buffer on stack
	sub.w	#BUFSIZE,sp
	move.l	sp,a4			;a4 = buffer

	;--- 32-bit baseline ---
	lea	(.f1,pc),a1
	lea	(.args1,pc),a2
	bsr	.dotest

	;--- %lx ---
	lea	(.f2,pc),a1
	lea	(.args2,pc),a2
	bsr	.dotest

	;--- %llx ---
	lea	(.f3,pc),a1
	lea	(.args3,pc),a2
	bsr	.dotest

	;--- %llx zero ---
	lea	(.f4,pc),a1
	lea	(.args4,pc),a2
	bsr	.dotest

	;--- %llx high only ---
	lea	(.f5,pc),a1
	lea	(.args5,pc),a2
	bsr	.dotest

	;--- %llx low only ---
	lea	(.f6,pc),a1
	lea	(.args6,pc),a2
	bsr	.dotest

	;--- %lld positive ---
	lea	(.f7,pc),a1
	lea	(.args7,pc),a2
	bsr	.dotest

	;--- %lld negative ---
	lea	(.f8,pc),a1
	lea	(.args8,pc),a2
	bsr	.dotest

	;--- %lld -1 ---
	lea	(.f9,pc),a1
	lea	(.args9,pc),a2
	bsr	.dotest

	;--- %lld 0 ---
	lea	(.f10,pc),a1
	lea	(.args10,pc),a2
	bsr	.dotest

	;--- %llu max uint64 ---
	lea	(.f11,pc),a1
	lea	(.args11,pc),a2
	bsr	.dotest

	;--- %llu 10 billion ---
	lea	(.f12,pc),a1
	lea	(.args12,pc),a2
	bsr	.dotest

	;--- mixed 32+64 bit ---
	lea	(.f14,pc),a1
	lea	(.args14,pc),a2
	bsr	.dotest

	;--- field width ---
	lea	(.f15,pc),a1
	lea	(.args15,pc),a2
	bsr	.dotest

	;--- %'ld grouping ---
	lea	(.f16,pc),a1
	lea	(.args16,pc),a2
	bsr	.dotest

	;--- %'ld small (no grouping) ---
	lea	(.f17,pc),a1
	lea	(.args17,pc),a2
	bsr	.dotest

	;--- %'ld negative ---
	lea	(.f18,pc),a1
	lea	(.args18,pc),a2
	bsr	.dotest

	;--- %'lld grouping ---
	lea	(.f19,pc),a1
	lea	(.args19,pc),a2
	bsr	.dotest

	;--- %'llu max uint64 ---
	lea	(.f20,pc),a1
	lea	(.args20,pc),a2
	bsr	.dotest

	add.w	#BUFSIZE,sp

.close	move.l	(4).w,a6
	move.l	a5,a1
	jsr	(_LVOCloseLibrary,a6)

.exit	moveq	#0,d0
	rts

;----------------------------------------
; format into buffer and print
; IN: a1=fmt, a2=args, a4=buffer, a5=dosbase

.dotest	move.l	a4,a0
	move.l	#BUFSIZE,d0
	bsr	_VSNPrintF
	; print buffer
	move.l	a5,a6
	move.l	a4,d1
	jsr	(_LVOPutStr,a6)
	rts

;----------------------------------------
; data

.dosname	dc.b	"dos.library",0

	;--- Test 1: basic 32-bit %ld %lx %lu ---
.f1	dc.b	"32-bit:  %ld %lx %lu",10,0
	EVEN
.args1	dc.l	-42,$DEADBEEF,12345

	;--- Test 2: %lx 32-bit hex ---
.f2	dc.b	"%%lx:    %lx expect CAFEBABE",10,0
	EVEN
.args2	dc.l	$CAFEBABE

	;--- Test 3: %llx 64-bit hex ---
.f3	dc.b	"%%llx:   %llx expect 123456789ABCDEF0",10,0
	EVEN
.args3	dc.l	$12345678,$9ABCDEF0

	;--- Test 4: %llx zero ---
.f4	dc.b	"%%llx 0: %llx expect 0",10,0
	EVEN
.args4	dc.l	0,0

	;--- Test 5: %llx high word only ($1:00000000) ---
.f5	dc.b	"%%llx h: %llx expect 100000000",10,0
	EVEN
.args5	dc.l	1,0

	;--- Test 6: %llx low word only ---
.f6	dc.b	"%%llx l: %llx expect DEADBEEF",10,0
	EVEN
.args6	dc.l	0,$DEADBEEF

	;--- Test 7: %lld positive (1,000,000,000,000 = $E8:D4A51000) ---
.f7	dc.b	"%%lld+:  %lld expect 1000000000000",10,0
	EVEN
.args7	dc.l	$000000E8,$D4A51000

	;--- Test 8: %lld negative (-1,000,000,000,000 = $FFFFFF17:2B5AF000) ---
.f8	dc.b	"%%lld-:  %lld expect -1000000000000",10,0
	EVEN
.args8	dc.l	$FFFFFF17,$2B5AF000

	;--- Test 9: %lld -1 ($FFFFFFFF:FFFFFFFF) ---
.f9	dc.b	"%%lld-1: %lld expect -1",10,0
	EVEN
.args9	dc.l	$FFFFFFFF,$FFFFFFFF

	;--- Test 10: %lld 0 ---
.f10	dc.b	"%%lld 0: %lld expect 0",10,0
	EVEN
.args10	dc.l	0,0

	;--- Test 11: %llu max uint64 (2^64-1) ---
.f11	dc.b	"%%llu m: %llu expect 18446744073709551615",10,0
	EVEN
.args11	dc.l	$FFFFFFFF,$FFFFFFFF

	;--- Test 12: %llu 10,000,000,000 ($2:540BE400) ---
.f12	dc.b	"%%llu:   %llu expect 10000000000",10,0
	EVEN
.args12	dc.l	$00000002,$540BE400

	;--- Test 14: mixed 32-bit and 64-bit ---
	; %ld=999  %llx=$AABBCCDD11223344  %llu=10000000000
.f14	dc.b	"mixed:   %ld %llx %llu",10,0
	EVEN
.args14	dc.l	999
	dc.l	$AABBCCDD,$11223344
	dc.l	$00000002,$540BE400

	;--- Test 15: field width with 64-bit ---
.f15	dc.b	"width:   [%20lld] [%020lld]",10,0
	EVEN
.args15	dc.l	$000000E8,$D4A51000	;1000000000000
	dc.l	$000000E8,$D4A51000	;1000000000000

	;--- Test 16: %'ld thousands grouping ---
.f16	dc.b	"%%'ld:   %'ld expect 1,000,000",10,0
	EVEN
.args16	dc.l	1000000

	;--- Test 17: %'ld small number (no grouping) ---
.f17	dc.b	"%%'ld s: %'ld expect 42",10,0
	EVEN
.args17	dc.l	42

	;--- Test 18: %'ld negative ---
.f18	dc.b	"%%'ld-:  %'ld expect -1,000,000",10,0
	EVEN
.args18	dc.l	-1000000

	;--- Test 19: %'lld thousands grouping ---
.f19	dc.b	"%%'lld:  %'lld expect 1,000,000,000,000",10,0
	EVEN
.args19	dc.l	$000000E8,$D4A51000

	;--- Test 20: %'llu max uint64 ---
.f20	dc.b	"%%'llu:  %'llu expect 18,446,744,073,709,551,615",10,0
	EVEN
.args20	dc.l	$FFFFFFFF,$FFFFFFFF

;----------------------------------------
; include the VSNPrintF implementation

	VSNPrintF

