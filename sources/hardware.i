 IFND	HARDWARE_I
HARDWARE_I = 1
;*---------------------------------------------------------------------------
;  :Author.	Bert Jahn
;  :Contens.	macros hardware related
;  :History.	17.07.97 separated from whdl_coredump.s
;		26.12.98 cia names added
;		18.03.01 input masking of _GetCustomName changed
;		31.03.01 noop added
;		13.05.01 sprhdat and bplhdat added
;		27.08.01 _GetCustomName fixed
;  :Copyright.	© 1997,1998 Bert Jahn, All Rights Reserved
;  :Language.	68000 Assembler
;  :Translator.	Barfly 2.9
;---------------------------------------------------------------------------*
*##
*##	hardware.i
*##
*##	_customnames	names of custom registers
*##	_GetCustomName	-> name
*##	_cianames	names of cia registers

;----------------------------------------
; names of custom registers
; for using with "Sources:strings.i" _DoString

	IFND	noop
noop = $1fe
	ENDC

customnames	MACRO
	IFND	CUSTOMNAMES
CUSTOMNAMES = 1

_customnames
.base		dc.w	0		;first
		dc.w	noop/2		;last
		dc.l	0		;next list
		dc.w	.000-.base
		dc.w	.002-.base
		dc.w	.004-.base
		dc.w	.006-.base
		dc.w	.008-.base
		dc.w	.00a-.base
		dc.w	.00c-.base
		dc.w	.00e-.base
		dc.w	.010-.base
		dc.w	.012-.base
		dc.w	.014-.base
		dc.w	.016-.base
		dc.w	.018-.base
		dc.w	.01a-.base
		dc.w	.01c-.base
		dc.w	.01e-.base
		dc.w	.020-.base
		dc.w	.022-.base
		dc.w	.024-.base
		dc.w	.026-.base
		dc.w	.028-.base
		dc.w	.02a-.base
		dc.w	.02c-.base
		dc.w	.02e-.base
		dc.w	.030-.base
		dc.w	.032-.base
		dc.w	.034-.base
		dc.w	.036-.base
		dc.w	.038-.base
		dc.w	.03a-.base
		dc.w	.03c-.base
		dc.w	.03e-.base
		dc.w	.040-.base
		dc.w	.042-.base
		dc.w	.044-.base
		dc.w	.046-.base
		dc.w	.048-.base
		dc.w	.04a-.base
		dc.w	.04c-.base
		dc.w	.04e-.base
		dc.w	.050-.base
		dc.w	.052-.base
		dc.w	.054-.base
		dc.w	.056-.base
		dc.w	.058-.base
		dc.w	.05a-.base
		dc.w	.05c-.base
		dc.w	.05e-.base
		dc.w	.060-.base
		dc.w	.062-.base
		dc.w	.064-.base
		dc.w	.066-.base
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	.070-.base
		dc.w	.072-.base
		dc.w	.074-.base
		dc.w	0
		dc.w	.078-.base
		dc.w	.07a-.base
		dc.w	.07c-.base
		dc.w	.07e-.base
		dc.w	.080-.base
		dc.w	.082-.base
		dc.w	.084-.base
		dc.w	.086-.base
		dc.w	.088-.base
		dc.w	.08a-.base
		dc.w	.08c-.base
		dc.w	.08e-.base
		dc.w	.090-.base
		dc.w	.092-.base
		dc.w	.094-.base
		dc.w	.096-.base
		dc.w	.098-.base
		dc.w	.09a-.base
		dc.w	.09c-.base
		dc.w	.09e-.base
		dc.w	.0a0-.base
		dc.w	.0a2-.base
		dc.w	.0a4-.base
		dc.w	.0a6-.base
		dc.w	.0a8-.base
		dc.w	.0aa-.base
		dc.w	0
		dc.w	0
		dc.w	.0b0-.base
		dc.w	.0b2-.base
		dc.w	.0b4-.base
		dc.w	.0b6-.base
		dc.w	.0b8-.base
		dc.w	.0ba-.base
		dc.w	0
		dc.w	0
		dc.w	.0c0-.base
		dc.w	.0c2-.base
		dc.w	.0c4-.base
		dc.w	.0c6-.base
		dc.w	.0c8-.base
		dc.w	.0ca-.base
		dc.w	0
		dc.w	0
		dc.w	.0d0-.base
		dc.w	.0d2-.base
		dc.w	.0d4-.base
		dc.w	.0d6-.base
		dc.w	.0d8-.base
		dc.w	.0da-.base
		dc.w	0
		dc.w	0
		dc.w	.0e0-.base
		dc.w	.0e2-.base
		dc.w	.0e4-.base
		dc.w	.0e6-.base
		dc.w	.0e8-.base
		dc.w	.0ea-.base
		dc.w	.0ec-.base
		dc.w	.0ee-.base
		dc.w	.0f0-.base
		dc.w	.0f2-.base
		dc.w	.0f4-.base
		dc.w	.0f6-.base
		dc.w	.0f8-.base
		dc.w	.0fa-.base
		dc.w	.0fc-.base
		dc.w	.0fe-.base
		dc.w	.100-.base
		dc.w	.102-.base
		dc.w	.104-.base
		dc.w	.106-.base
		dc.w	.108-.base
		dc.w	.10a-.base
		dc.w	.10c-.base
		dc.w	.10e-.base
		dc.w	.110-.base
		dc.w	.112-.base
		dc.w	.114-.base
		dc.w	.116-.base
		dc.w	.118-.base
		dc.w	.11a-.base
		dc.w	.11c-.base
		dc.w	.11e-.base
		dc.w	.120-.base
		dc.w	.122-.base
		dc.w	.124-.base
		dc.w	.126-.base
		dc.w	.128-.base
		dc.w	.12a-.base
		dc.w	.12c-.base
		dc.w	.12e-.base
		dc.w	.130-.base
		dc.w	.132-.base
		dc.w	.134-.base
		dc.w	.136-.base
		dc.w	.138-.base
		dc.w	.13a-.base
		dc.w	.13c-.base
		dc.w	.13e-.base
		dc.w	.140-.base
		dc.w	.142-.base
		dc.w	.144-.base
		dc.w	.146-.base
		dc.w	.148-.base
		dc.w	.14a-.base
		dc.w	.14c-.base
		dc.w	.14e-.base
		dc.w	.150-.base
		dc.w	.152-.base
		dc.w	.154-.base
		dc.w	.156-.base
		dc.w	.158-.base
		dc.w	.15a-.base
		dc.w	.15c-.base
		dc.w	.15e-.base
		dc.w	.160-.base
		dc.w	.162-.base
		dc.w	.164-.base
		dc.w	.166-.base
		dc.w	.168-.base
		dc.w	.16a-.base
		dc.w	.16c-.base
		dc.w	.16e-.base
		dc.w	.170-.base
		dc.w	.172-.base
		dc.w	.174-.base
		dc.w	.176-.base
		dc.w	.178-.base
		dc.w	.17a-.base
		dc.w	.17c-.base
		dc.w	.17e-.base
		dc.w	.180-.base
		dc.w	.182-.base
		dc.w	.184-.base
		dc.w	.186-.base
		dc.w	.188-.base
		dc.w	.18a-.base
		dc.w	.18c-.base
		dc.w	.18e-.base
		dc.w	.190-.base
		dc.w	.192-.base
		dc.w	.194-.base
		dc.w	.196-.base
		dc.w	.198-.base
		dc.w	.19a-.base
		dc.w	.19c-.base
		dc.w	.19e-.base
		dc.w	.1a0-.base
		dc.w	.1a2-.base
		dc.w	.1a4-.base
		dc.w	.1a6-.base
		dc.w	.1a8-.base
		dc.w	.1aa-.base
		dc.w	.1ac-.base
		dc.w	.1ae-.base
		dc.w	.1b0-.base
		dc.w	.1b2-.base
		dc.w	.1b4-.base
		dc.w	.1b6-.base
		dc.w	.1b8-.base
		dc.w	.1ba-.base
		dc.w	.1bc-.base
		dc.w	.1be-.base
		dc.w	.1c0-.base
		dc.w	.1c2-.base
		dc.w	.1c4-.base
		dc.w	.1c6-.base
		dc.w	.1c8-.base
		dc.w	.1ca-.base
		dc.w	.1cc-.base
		dc.w	.1ce-.base
		dc.w	.1d0-.base
		dc.w	.1d2-.base
		dc.w	.1d4-.base
		dc.w	.1d6-.base
		dc.w	.1d8-.base
		dc.w	.1da-.base
		dc.w	.1dc-.base
		dc.w	.1de-.base
		dc.w	.1e0-.base
		dc.w	.1e2-.base
		dc.w	.1e4-.base
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	0
		dc.w	.1fc-.base
		dc.w	.1fe-.base
.000		dc.b	"bltddat",0
.002		dc.b	"dmaconr",0
.004		dc.b	"vposr",0
.006		dc.b	"vhposr",0
.008		dc.b	"dskdatr",0
.00a		dc.b	"joy0dat",0
.00c		dc.b	"joy1dat",0
.00e		dc.b	"clxdat",0
.010		dc.b	"adkconr",0
.012		dc.b	"pot0dat",0
.014		dc.b	"pot1dat",0
.016		dc.b	"potinp",0
.018		dc.b	"serdatr",0
.01a		dc.b	"dskbytr",0
.01c		dc.b	"intenar",0
.01e		dc.b	"intreqr",0
.020		dc.b	"dskpt",0
.022		dc.b	"dskptl",0
.024		dc.b	"dsklen",0
.026		dc.b	"dskdat",0
.028		dc.b	"refptr",0
.02a		dc.b	"vposw",0
.02c		dc.b	"vhposw",0
.02e		dc.b	"copcon",0
.030		dc.b	"serdat",0
.032		dc.b	"serper",0
.034		dc.b	"potgo",0
.036		dc.b	"joytest",0
.038		dc.b	"strequ",0
.03a		dc.b	"strvbl",0
.03c		dc.b	"strhor",0
.03e		dc.b	"strlong",0
.040		dc.b	"bltcon0",0
.042		dc.b	"bltcon1",0
.044		dc.b	"bltafwm",0
.046		dc.b	"bltalwm",0
.048		dc.b	"bltcpt",0
.04a		dc.b	"bltcptl",0
.04c		dc.b	"bltbpt",0
.04e		dc.b	"bltbptl",0
.050		dc.b	"bltapt",0
.052		dc.b	"bltaptl",0
.054		dc.b	"bltdpt",0
.056		dc.b	"bltdptl",0
.058		dc.b	"bltsize",0
.05a		dc.b	"bltcon0l",0
.05c		dc.b	"bltsizv",0
.05e		dc.b	"bltsizh",0
.060		dc.b	"bltcmod",0
.062		dc.b	"bltbmod",0
.064		dc.b	"bltamod",0
.066		dc.b	"bltdmod",0
.070		dc.b	"bltcdat",0
.072		dc.b	"bltbdat",0
.074		dc.b	"bltadat",0
.078		dc.b	"sprhdat",0
.07a		dc.b	"bplhdat",0
.07c		dc.b	"deniseid",0
.07e		dc.b	"dsksync",0
.080		dc.b	"cop1lc",0
.082		dc.b	"cop1lcl",0
.084		dc.b	"cop2lc",0
.086		dc.b	"cop2lcl",0
.088		dc.b	"copjmp1",0
.08a		dc.b	"copjmp2",0
.08c		dc.b	"copins",0
.08e		dc.b	"diwstrt",0
.090		dc.b	"diwstop",0
.092		dc.b	"ddfstrt",0
.094		dc.b	"ddfstop",0
.096		dc.b	"dmacon",0
.098		dc.b	"clxcon",0
.09a		dc.b	"intena",0
.09c		dc.b	"intreq",0
.09e		dc.b	"adkcon",0
.0a0		dc.b	"aud0pt",0
.0a2		dc.b	"aud0ptl",0
.0a4		dc.b	"aud0len",0
.0a6		dc.b	"aud0per",0
.0a8		dc.b	"aud0vol",0
.0aa		dc.b	"aud0dat",0
.0b0		dc.b	"aud1pt",0
.0b2		dc.b	"aud1ptl",0
.0b4		dc.b	"aud1len",0
.0b6		dc.b	"aud1per",0
.0b8		dc.b	"aud1vol",0
.0ba		dc.b	"aud1dat",0
.0c0		dc.b	"aud2pt",0
.0c2		dc.b	"aud2ptl",0
.0c4		dc.b	"aud2len",0
.0c6		dc.b	"aud2per",0
.0c8		dc.b	"aud2vol",0
.0ca		dc.b	"aud2dat",0
.0d0		dc.b	"aud3pt",0
.0d2		dc.b	"aud3ptl",0
.0d4		dc.b	"aud3len",0
.0d6		dc.b	"aud3per",0
.0d8		dc.b	"aud3vol",0
.0da		dc.b	"aud3dat",0
.0e0		dc.b	"bpl1pt",0
.0e2		dc.b	"bpl1ptl",0
.0e4		dc.b	"bpl2pt",0
.0e6		dc.b	"bpl2ptl",0
.0e8		dc.b	"bpl3pt",0
.0ea		dc.b	"bpl3ptl",0
.0ec		dc.b	"bpl4pt",0
.0ee		dc.b	"bpl4ptl",0
.0f0		dc.b	"bpl5pt",0
.0f2		dc.b	"bpl5ptl",0
.0f4		dc.b	"bpl6pt",0
.0f6		dc.b	"bpl6ptl",0
.0f8		dc.b	"bpl7pt",0
.0fa		dc.b	"bpl7ptl",0
.0fc		dc.b	"bpl8pt",0
.0fe		dc.b	"bpl8ptl",0
.100		dc.b	"bplcon0",0
.102		dc.b	"bplcon1",0
.104		dc.b	"bplcon2",0
.106		dc.b	"bplcon3",0
.108		dc.b	"bpl1mod",0
.10a		dc.b	"bpl2mod",0
.10c		dc.b	"bplcon4",0
.10e		dc.b	"clxcon2",0
.110		dc.b	"bpl0dat",0
.112		dc.b	"bpl1dat",0
.114		dc.b	"bpl2dat",0
.116		dc.b	"bpl3dat",0
.118		dc.b	"bpl4dat",0
.11a		dc.b	"bpl5dat",0
.11c		dc.b	"bpl6dat",0
.11e		dc.b	"bpl7dat",0
.120		dc.b	"spr0pt",0
.122		dc.b	"spr0ptl",0
.124		dc.b	"spr1pt",0
.126		dc.b	"spr1ptl",0
.128		dc.b	"spr2pt",0
.12a		dc.b	"spr2ptl",0
.12c		dc.b	"spr3pt",0
.12e		dc.b	"spr3ptl",0
.130		dc.b	"spr4pt",0
.132		dc.b	"spr4ptl",0
.134		dc.b	"spr5pt",0
.136		dc.b	"spr5ptl",0
.138		dc.b	"spr6pt",0
.13a		dc.b	"spr6ptl",0
.13c		dc.b	"spr7pt",0
.13e		dc.b	"spr7ptl",0
.140		dc.b	"spr0pos",0
.142		dc.b	"spr0ctl",0
.144		dc.b	"spr0data",0
.146		dc.b	"spr0datb",0
.148		dc.b	"spr1pos",0
.14a		dc.b	"spr1ctl",0
.14c		dc.b	"spr1data",0
.14e		dc.b	"spr1datb",0
.150		dc.b	"spr2pos",0
.152		dc.b	"spr2ctl",0
.154		dc.b	"spr2data",0
.156		dc.b	"spr2datb",0
.158		dc.b	"spr3pos",0
.15a		dc.b	"spr3ctl",0
.15c		dc.b	"spr3data",0
.15e		dc.b	"spr3datb",0
.160		dc.b	"spr4pos",0
.162		dc.b	"spr4ctl",0
.164		dc.b	"spr4data",0
.166		dc.b	"spr4datb",0
.168		dc.b	"spr5pos",0
.16a		dc.b	"spr5ctl",0
.16c		dc.b	"spr5data",0
.16e		dc.b	"spr5datb",0
.170		dc.b	"spr6pos",0
.172		dc.b	"spr6ctl",0
.174		dc.b	"spr6data",0
.176		dc.b	"spr6datb",0
.178		dc.b	"spr7pos",0
.17a		dc.b	"spr7ctl",0
.17c		dc.b	"spr7data",0
.17e		dc.b	"spr7datb",0
.180		dc.b	"color00",0
.182		dc.b	"color01",0
.184		dc.b	"color02",0
.186		dc.b	"color03",0
.188		dc.b	"color04",0
.18a		dc.b	"color05",0
.18c		dc.b	"color06",0
.18e		dc.b	"color07",0
.190		dc.b	"color08",0
.192		dc.b	"color09",0
.194		dc.b	"color10",0
.196		dc.b	"color11",0
.198		dc.b	"color12",0
.19a		dc.b	"color13",0
.19c		dc.b	"color14",0
.19e		dc.b	"color15",0
.1a0		dc.b	"color16",0
.1a2		dc.b	"color17",0
.1a4		dc.b	"color18",0
.1a6		dc.b	"color19",0
.1a8		dc.b	"color20",0
.1aa		dc.b	"color21",0
.1ac		dc.b	"color22",0
.1ae		dc.b	"color23",0
.1b0		dc.b	"color24",0
.1b2		dc.b	"color25",0
.1b4		dc.b	"color26",0
.1b6		dc.b	"color27",0
.1b8		dc.b	"color28",0
.1ba		dc.b	"color29",0
.1bc		dc.b	"color30",0
.1be		dc.b	"color31",0
.1c0		dc.b	"htotal",0
.1c2		dc.b	"hsstop",0
.1c4		dc.b	"hbstrt",0
.1c6		dc.b	"hbstop",0
.1c8		dc.b	"vtotal",0
.1ca		dc.b	"vsstop",0
.1cc		dc.b	"vbstrt",0
.1ce		dc.b	"vbstop",0
.1d0		dc.b	"sprhstrt",0
.1d2		dc.b	"sprhstop",0
.1d4		dc.b	"bplhstrt",0
.1d6		dc.b	"bplhstop",0
.1d8		dc.b	"hhposw",0
.1da		dc.b	"hhposr",0
.1dc		dc.b	"beamcon0",0
.1de		dc.b	"hsstrt",0
.1e0		dc.b	"vsstrt",0
.1e2		dc.b	"hcenter",0
.1e4		dc.b	"diwhigh",0
.1fc		dc.b	"fmode",0
.1fe		dc.b	"noop",0
	EVEN
	ENDC
		ENDM

;----------------------------------------
; return name custom register
; IN:	d0 =  UWORD  offset of custom register
; OUT:	d0 =  CPTR   name of register

GetCustomName	MACRO
	IFND	GETCUSTOMNAME
GETCUSTOMNAME=1
		IFND	CUSTOMNAMES
			customnames
		ENDC
		IFND	DOSTRINGNULL
			DoStringNull
		ENDC

_GetCustomName	and.l	#$000001ff,d0
		lsr.l	#1,d0
		lea	(_customnames),a0
		bra	_DoStringNull
	ENDC
	ENDM

;----------------------------------------
; names of cia registers
; for using with "Sources:strings.i" _DoString

cianames	MACRO
	IFND	CIANAMES
CIANAMES = 1

_cianames
.base		dc.w	0		;first
		dc.w	$f		;last
		dc.l	0		;next list
		dc.w	.0-.base
		dc.w	.1-.base
		dc.w	.2-.base
		dc.w	.3-.base
		dc.w	.4-.base
		dc.w	.5-.base
		dc.w	.6-.base
		dc.w	.7-.base
		dc.w	.8-.base
		dc.w	.9-.base
		dc.w	.a-.base
		dc.w	0
		dc.w	.c-.base
		dc.w	.d-.base
		dc.w	.e-.base
		dc.w	.f-.base
.0		dc.b	"pra",0
.1		dc.b	"prb",0
.2		dc.b	"ddra",0
.3		dc.b	"ddrb",0
.4		dc.b	"talo",0
.5		dc.b	"tahi",0
.6		dc.b	"tblo",0
.7		dc.b	"tbhi",0
.8		dc.b	"todlow",0
.9		dc.b	"todmid",0
.a		dc.b	"todhi",0
.c		dc.b	"sdr",0
.d		dc.b	"icr",0
.e		dc.b	"cra",0
.f		dc.b	"crb",0
	EVEN
	ENDC
		ENDM
		
;---------------------------------------------------------------------------

	ENDC

