#ifndef WHDLOAD_H
#define WHDLOAD_H
/*
**	whdload.h
**	include file for WHDLoad and Slaves
*/

#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif /* EXEC_TYPES_H */

/*
** Slave
*/

#define WHDLoadSlaveID "WHDLOADS"

struct WHDLoadSlave
{
	ULONG	ws_Security;	/* 0x70ff4e75, moveq -1,d0 + rts */
	char	ws_ID[8];	/* "WHDLOADS" */
	UWORD	ws_Version;	/* required WHDLoad version */
	UWORD	ws_Flags;
	ULONG	ws_BaseMemSize;	/* size of required memory (multiple of 0x1000) */
	ULONG	ws_ExecInstall;
	RPTR	ws_GameLoader;	/* Slave code, called by WHDLoad */
	RPTR	ws_CurrentDir;	/* subdirectory for data files */
	RPTR	ws_DontCache;	/* pattern for files not to cache */
	/* additional structure version 4 */
	UBYTE	ws_keydebug;	/* raw key code to quit with debug */
	UBYTE	ws_keyexit;	/* raw key code to exit */
	/* additional structure version 8 */
        LONG	ws_ExpMem;       /* size of required expansions memory */
	/* additional structure version 10 */
	RPTR	ws_name;	/* name of the installed program */
	RPTR	ws_copy;	/* year and owner of the copyright */
	RPTR	ws_info;	/* additional informations (author, version...) */
	/* additional structure version 16 */
	RPTR	ws_kickname;	/* name of kickstart image */
	ULONG	ws_kicksize;	/* size of kickstart image */
	UWORD	ws_kickcrc;	/* CRC16 of kickstart image */
	/* additional structure version 17 */
	RPTR	ws_config;	/* configuration of splash window buttons */
	/* additional structure version 20 */
	RPTR	ws_MemConfig;	/* additional base+exp memory configurations */
};

#endif	/* WHDLOAD_H */
