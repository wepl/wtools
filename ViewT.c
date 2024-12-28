
/* ViewT1.0 (ViewTooltypes)
 * by Phil Dietz 18-Jan-94
 * 2024-12-28 Wepl: made compile using vbcc, fixed args
 *
 * DESCRIPTION: a *small* CLI program to view/edit ToolTypes for icons.
 *              It's residentiable as well. PublicDomain with source included.
 *
 * GIBBERISH:   Here's a very simple program I threw together.
 *      I made it cuz I was sick of having to use Workbench to view
 * 	or change an icons ToolTypes.  My HD controller is quite slow
 * 	so manipulating an icon in a dir or layers of dirs is painful.
 *      Who said C couldn't write small code...[cough cough] :-)
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
 * REQUIREMENTS:  WB2.04 or greater
 *
 * Set tab size to 8.
 */

#include <stdio.h>

#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/icon.h>

#include <exec/execbase.h>
#include <exec/memory.h>
#include <libraries/dos.h>
#include <libraries/dosextens.h>

/* Defines */
#define TEMPLATE   "FILE/A,VIEW/S,ADD/K,DEL/K/N"
#define NUM        4

#define ARG_NAME	args[0]
#define ARG_VIEW	args[1]
#define ARG_ADD		args[2]
#define ARG_DEL		args[3]

LONG args[NUM];	/* ARGS template memory		*/

/* Version String */
static char ver[] = "$VER: ViewT 1.1 (28-Dec-24)";

int main(void)
{

	struct IconBase		*IconBase;
	struct RDArgs		*rd;
	struct DiskObject	*dob=NULL;

	int	rc = RETURN_FAIL;		/* return code..assume error	*/
	int	i,j;		/* general counter crap		*/

	STRPTR *table = NULL;
	int	count=0;

	IconBase= (struct IconBase *)OpenLibrary ("icon.library",37);

		if(IconBase) {
			rd = ReadArgs(TEMPLATE, args, NULL);	/* Parse args */

			if(rd) {
				rc = RETURN_ERROR;
			
				if (ARG_NAME) {
					dob = GetDiskObject((STRPTR)ARG_NAME);
					if(dob && dob->do_ToolTypes) {

	/* To add an entry we must */		while(dob->do_ToolTypes[count] && *dob->do_ToolTypes[count]) count++;	/* get number of tooltypes */
	/* make a completely new   */
	/* char. table (though we  */		if(ARG_ADD) {
	/* can copy most pointers) */			if(FindToolType(dob->do_ToolTypes,(STRPTR)ARG_ADD)) {
	/* Once we do that we      */				printf("ToolType already exists.\n");
	/* attach the new table    */				goto klose;
	/* to the old structure    */			}
	/* then save.		   */			table = AllocVec(sizeof(char *)*(count+2), MEMF_PUBLIC | MEMF_CLEAR);
	/* NOTE: it should be safe */			if(table) {
	/* since deallocation of   */				for(i=0;i<count;i++) table[i]=dob->do_ToolTypes[i];
	/* old table is done from  */				table[count]	=(char *)ARG_ADD;
	/* an internal freelist.   */				table[count+1]	=NULL;

								dob->do_ToolTypes=table;
								if (! PutDiskObject((STRPTR)ARG_NAME,dob)) {
									printf("error writing icon\n");
								} else {
									rc = RETURN_OK;
								}
								FreeVec(table);
							}
						}
	/* Delete we just shift  */		else if(ARG_DEL) {
	/* the pointer list over */			j=*(LONG *)ARG_DEL;  /* put real number in j */
	/* the entry (aka write  */			if(j<1 || j>count) {
	/* over).                */				printf("Invalid ToolType number.\n");
								rc = RETURN_WARN;
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
							if (! PutDiskObject((STRPTR)ARG_NAME,dob)) {
								printf("error writing icon\n");
							} else {
								rc = RETURN_OK;
							}
						}
						else {  /* else VIEW */
							i=0;
							while(dob->do_ToolTypes[i] && *dob->do_ToolTypes[i]) {
								printf("%ld. %s\n", i+1, dob->do_ToolTypes[i]);
								i++;	/* increment pointer pointer	*/
							}
							if(i==0) printf("No tooltypes.\n");
							rc = RETURN_OK;
						}
					}
					else printf("File '%s.info' missing.\n",(char *)ARG_NAME);
				}
				else printf("No file given.\n");
			}
			else printf("Missing argument.\n");

klose:			if(dob)   FreeDiskObject(dob);	/* Free disk object		*/
			if(rd)    FreeArgs(rd);		/* Free the readargs structure  */

			CloseLibrary((struct Library *)IconBase);
		}
	return rc;

}

