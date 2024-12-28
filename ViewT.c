
/* ViewT1.0 (ViewTooltypes)
 *
 *    by Phil Dietz
 *      18-Jan-94
 *
 *
 * DESCRIPTION: a *small* CLI program to view/edit ToolTypes for icons.
 *              It's residentiable as well. PublicDomain with source included.
 *
 *
 * GIBBERISH:   Here's a very simple program I threw together.
 *      I made it cuz I was sick of having to use Workbench to view
 * 	or change an icons ToolTypes.  My HD controller is quite slow
 * 	so manipulating an icon in a dir or layers of dirs is painful.
 *      Who said C couldn't write small code...[cough cough] :-)
 *      
 *
 * USAGE:  ViewT  FILE/A,VIEW/S,ADD/K,DEL/K/N
 *
 *         FILE/A - Path of file icon to view (without .info extension)
 *         VIEW/S - View's the tooltypes of the icon (default)
 *         ADD/K  - Add's the string after ADD to the icon's tooltypes
 *         DEL/K/N- Delete's the number of the ToolType line shown by VIEW.
 *
 *  ie  show tooltypes:  ViewT sys:wbstartup/SetDefMon
 *                   or  ViewT sys:wbstartup/SetDefMon view
 *
 *          add a type:  ViewT sys:wbstartup/SetDefMon add "FOOD=BIG TACO"
 *
 *      delete entry 5:  ViewT sys:wbstartup/SetDefMon del 5
 *
 *
 * REQUIREMENTS:  WB2.04 or greater
 *
 *
 * COMPILE:  compile: 'sc ViewT nolink'  (use SCOPTIONS provided)
 *           link   : 'slink viewt.o to ViewT  ND SC SD'
 *
 * Set tab size to 8.
 * I didn't clean the code so don't jump on me :-)
 * For small link utilites (w/ src) check out Newlist8.2 found on Aminet.
 */



#include <stdio.h>

#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/icon.h>

#include <exec/execbase.h>
#include <exec/memory.h>
#include <libraries/dos.h>
#include <libraries/dosextens.h>
#include <devices/conunit.h>
#include <workbench/workbench.h>

/* Defines */
#define TEMPLATE   "FILE/A,VIEW/S,ADD/K,DEL/K/N"
#define NUM        4

#define ARG_NAME	args[0]
#define ARG_VIEW	args[1]
#define ARG_ADD		args[2]
#define ARG_DEL		args[3]

/* Version String */
static char ver[]="$VER: ViewT1.0 (18-Jan-94)";

/* Protos */
void PRintf(struct DOSBase *, char *, long , ...);

void __saveds mymain(void)
{

	struct ExecBase		*SysBase = (*((struct ExecBase **) 4));
	struct IconBase		*IconBase;
	struct DOSBase		*DOSBase;
	struct WBStartup	*wbMsg = NULL;
	struct Process		*process;
	struct RDArgs		*rd;
	struct DiskObject	*dob=NULL;

	LONG	args[4];	/* ARGS template memory		*/
	int	rc=1;		/* return code..assume error	*/
	int	i,j;		/* general counter crap		*/

	char 	**table;
	int	count=0;

	process = (struct Process *) SysBase->ThisTask;
	if (!(process->pr_CLI)) {			/* WB-launched code */
		WaitPort (&process->pr_MsgPort);
		wbMsg = (struct WBStartup *) GetMsg (&process->pr_MsgPort);
	}

	if (SysBase->LibNode.lib_Version < 37) goto xit;

	DOSBase = (struct DOSBase  *)OpenLibrary ("dos.library", 37);
	IconBase= (struct IconBase *)OpenLibrary ("icon.library",37);

	if(DOSBase) {
		if(IconBase) {
			rd = ReadArgs(TEMPLATE, &args, NULL);	/* Parse args */

			if(rd) {
			
				if (ARG_NAME) {
					dob = GetDiskObjectNew((STRPTR)ARG_NAME);
					if(dob && dob->do_ToolTypes) {

	/* To add an entry we must */		while(dob->do_ToolTypes[count] && *dob->do_ToolTypes[count]) count++;	/* get number of tooltypes */
	/* make a completely new   */
	/* char. table (though we  */		if(ARG_ADD) {
	/* can copy most pointers) */			if(FindToolType(dob->do_ToolTypes,(STRPTR)ARG_ADD)) {
	/* Once we do that we      */				PutStr("ToolType already exists.\n");
	/* attach the new table    */				goto klose;
	/* to the old structure    */			}
	/* then save.		   */			table=(char **)AllocVec(sizeof(char *)*(count+2), MEMF_PUBLIC | MEMF_CLEAR);
	/* NOTE: it should be safe */			if(table) {
	/* since deallocation of   */				for(i=0;i<count;i++) table[i]=dob->do_ToolTypes[i];
	/* old table is done from  */				table[count]	=(char *)ARG_ADD;
	/* an internal freelist.   */				table[count+1]	=NULL;

								dob->do_ToolTypes=table;
								PutDiskObject((STRPTR)ARG_NAME,dob);
								FreeVec(table);
							}
						}
	/* Delete we just shift  */		else if(ARG_DEL) {
	/* the pointer list over */			j=*(LONG *)ARG_DEL;  /* put real number in j */
	/* the entry (aka write  */			if(j<1 || j>count) {
	/* over).                */				PutStr("Invalid ToolType number.\n");
								goto klose;
							}
							i=j-1;	/* position on entry to delete/overwrite */
							if(dob->do_ToolTypes[i]) {
								while(dob->do_ToolTypes[i+1]) {
									dob->do_ToolTypes[i]=dob->do_ToolTypes[i+1];
									i++;
								}
							}
							dob->do_ToolTypes[i]=NULL;
							PutDiskObject((STRPTR)ARG_NAME,dob);
						}
						else {  /* else VIEW */
							i=0;
							while(dob->do_ToolTypes[i] && *dob->do_ToolTypes[i]) {
								PRintf(DOSBase,"%ld. %s\n",i+1,(char *)dob->do_ToolTypes[i]);
								i++;	/* increment pointer pointer	*/
							}
							if(i==0) PutStr("No tooltypes.\n");
						}
					}
					else PRintf(DOSBase,"File '%s.info' missing.\n",(char *)ARG_NAME);
				}
				else PutStr("No file given.\n");
			}
			else PutStr("Missing argument.\n");

klose:			if(dob)   FreeDiskObject(dob);	/* Free disk object		*/
			if(rd)    FreeArgs(rd);		/* Free the readargs structure  */
			rc=0;				/* return good return code	*/

			CloseLibrary((struct Library *)IconBase);
		}
		CloseLibrary((struct Library *)DOSBase);
	}

xit:	if (wbMsg) {
		Forbid ();				/* Very important! */
		ReplyMsg ((struct Message *) wbMsg);	/* Must reply Workbench Msg */
	}
	process->pr_Result2=rc;
}

void PRintf(struct DOSBase *DOSBase, char *string, long arg, ...)
      {
      /* We're passing DOSBase cuz there are no globals in a RESIDENTIABLE
       * with NO cres.o startup code.
       */  
      VPrintf(string, &arg);
      }
