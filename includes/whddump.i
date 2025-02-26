;*---------------------------------------------------------------------------
;  :Module.	whddump.i
;  :Contens.	definitions for the dump file created by WHDLoad
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.de
;  :History.	30.03.00 term chunk added, whdload v11
;		03.01.10 included label added
;		18.10.12 ID_COLS added
;		16.07.23 ID_OPT added
;  :Copyright.	© 1998-2010,2012,2023 Bert Jahn, All Rights Reserved
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.9
;---------------------------------------------------------------------------*

 IFND WHDDUMP_I
WHDDUMP_I SET 1

	IFND	EXEC_TYPES_I
	INCLUDE	exec/types.i
	ENDC
	IFND	DOS_DOS_I
	INCLUDE	dos/dos.i
	ENDC

;=============================================================================

ID_WHDD	= 'WHDD'	;IFF type

ID_HEAD	= 'HEAD'	;header

	;
	; DON'T ASSUME ANYTHING ABOUT THIS CHUNK!
	; IT WILL DEFINITIVELY CHANGE IN THE NEXT WHDLOAD
	;
	STRUCTURE whdload_dump_header,0
		ULONG	wdh_BaseMemSize
		ULONG	wdh_ShadowMem		;no longer filled since 3-tile shadow memory
		ULONG	wdh_TermReason
		ULONG	wdh_TermPrimary
		ULONG	wdh_TermSecondary
TERMSTRINGLEN=256
		STRUCT	wdh_TermString,TERMSTRINGLEN
		ULONG	wdh_LastBlitPC
		ULONG	wdh_ExpMemLog
		ULONG	wdh_ExpMemPhy
		ULONG	wdh_ExpMemLen
		ULONG	wdh_ResLoadLog
		ULONG	wdh_ResLoadPhy
		ULONG	wdh_ResLoadLen
		ULONG	wdh_SlaveLog
		ULONG	wdh_SlavePhy
		ULONG	wdh_SlaveLen
SLAVENAMELEN=256
		STRUCT	wdh_SlaveName,SLAVENAMELEN
		STRUCT	wdh_DateStamp,ds_SIZEOF
		ULONG	wdh_kn
		ULONG	wdh_rw
		UWORD	wdh_cs
		UWORD	wdh_CPU			;AttnFlags
		WORD	wdh_WVer		;WHDLoad Version
		WORD	wdh_WRev		;WHDLoad Revision
		WORD	wdh_WBuild		;WHDLoad Build Number
		BYTE	wdh_fc
		BYTE	wdh_zpt
		ALIGNLONG
		LABEL	wdh_SIZEOF

ID_TERM	= 'TERM'	;termination reason text, starting whdload v11

ID_OPT	= 'OPT '	;all WHDLoad options, starting whdload v18.10

ID_CPU	= 'CPU '	;status of the cpu

	STRUCTURE whdload_dump_cpu,0
		STRUCT	wdc_regs,15*4
		ULONG	wdc_pc
		ULONG	wdc_usp
		ULONG	wdc_ssp			;isp on 20-40
		ULONG	wdc_msp			;20-40
		UWORD	wdc_sr
		UBYTE	wdc_sfc			;10-60
		UBYTE	wdc_dfc			;10-60
		ULONG	wdc_vbr			;10-60
		ULONG	wdc_caar		;20-30
		ULONG	wdc_cacr		;20-60
		ULONG	wdc_tt0			;30
		ULONG	wdc_tt1			;30
		ULONG	wdc_dtt0		;40-60
		ULONG	wdc_dtt1		;40-60
		ULONG	wdc_itt0		;40-60
		ULONG	wdc_itt1		;40-60
		ULONG	wdc_pcr			;60
		ULONG	wdc_buscr		;60
		STRUCT	wdc_srp,8		;30(64bit) 40-60(32bit)
		STRUCT	wdc_crp,8		;30
		STRUCT	wdc_drp,8		;51
		ULONG	wdc_tc			;30(32bit) 40-60(16bit)
		ULONG	wdc_mmusr		;30(16bit) 40(32bit)
		ULONG	wdc_urp			;40-60
		STRUCT	wdc_fpregs,8*12
		ULONG	wdc_fpcr
		ULONG	wdc_fpsr
		ULONG	wdc_fpiar
		LABEL	wdc_SIZEOF

ID_CUST	= 'CUST'

	STRUCTURE whdload_dump_custom,0
		STRUCT	wdcu_regs,$200
		STRUCT	wdcu_flags,$200
		LABEL	wdcu_SIZEOF

 BITDEF CUST,READ,0	;readable
 BITDEF CUST,WRITE,1	;writeable
 BITDEF CUST,MODI,7	;modified


ID_CIAA	= 'CIAA'
ID_CIAB	= 'CIAB'

	STRUCTURE whdload_dump_cia,0
		UBYTE	wdci_prai		;Port Register A Input
		UBYTE	wdci_prbi		;Port Register B Input
		UBYTE	wdci_prao		;Port Register A Output
		UBYTE	wdci_prbo		;Port Register B Output
		UBYTE	wdci_ddra		;Data Direction Register A
		UBYTE	wdci_ddrb		;Data Direction Register B
		UWORD	wdci_ta			;actual Timer A
		UWORD	wdci_tb			;actual Timer B
		UWORD	wdci_pa			;Latch Timer A
		UWORD	wdci_pb			;Latch Timer B
		ULONG	wdci_event		;event counter
		ULONG	wdci_alarm		;alarm of event counter
		UBYTE	wdci_sdr		;seriell port register
		UBYTE	wdci_icr		;Interrupt Control Request
		UBYTE	wdci_icm		;Interrupt Control Mask
		UBYTE	wdci_cra		;Control Register A
		UBYTE	wdci_crb		;Control Register B
		ALIGNLONG
		LABEL	wdci_SIZEOF

ID_SLAV	= 'SLAV'	;contains the slave binary (without executable header)

ID_MEM	= 'MEM '	;contains complete BaseMem

ID_EMEM	= 'EMEM'	;contains complete ExpMem

ID_COLS	= 'COLS'	;256 colors, written only on AGA machines
			;each color is 32-bit, format T...RRRGGGBBB....RRRGGGBBB, first MSB then LSB
			;as stored in LISA

;=============================================================================

 ENDC
