/*
 * transform WHDLoad data directories into VFS-archives and vice versa
 * decompress XPK packed files and call lha/zip to create archive
 * or the reverse direction (unarchive and restore data directories)
 *
 * if Src is a file:
 *	.info -> un/archive data directories of this icon/slave and update icon
 *	.lha/zip -> unarchive to directory of filename and delete archive
 *	else failing
 * if Src is a directory:
 *	pack this directory into an archive of this name and delete directory
 *	if Scan/S is set search this directory for WHDLoad icons and create archives
 *	if Scan/S and UnArc/S is set search this directory for WHDLoad icons and unarchive
 *
 * only files are archived, no directories, that way empty directories are not
 * restored while UnArc/S is used, but this is no problem when using SavePath/K with
 * WHDLoad
 *
 * files starting with @ cannot be archived with lha when files are specified
 * (e.g. game Scrabble), could be supported by switching to specify only parent
 * directory, but requires a lot of new code
 *
 * for best performance the following commands should be made Resident:
 * 	delete
 * lha claims to be reentrant but fails in version 2.15
 *
 * 2021-01-20 started
 * 2021-07-14 lha working without XPK files
 * 2021-10-31 XPK decompression added
 * 2024-12-22 final for xmas 2024
 *
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include <dos/dos.h>
#include <xpk/xpk.h>
#include <whdload.h>
#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/icon.h>
#include <proto/xpkmaster.h>

#define MAXFILENAMELEN 108	// dos.library doesn't support more
#define MAXPATHNAMELEN 256	// dos.library doesn't support more

//static const char USED min_stack[] = "$STACK:20480";

#define TEMPLATE "Src/A,Scan/S,UnArc/S,NoDelete/S,TmpDir/K,Verbose/S"
#define OPT_SRC		0
#define OPT_SCAN	1
#define OPT_UNARC	2
#define OPT_NODELETE	3
#define OPT_TMPDIR	4
#define OPT_VERBOSE	5
#define OPT_COUNT	6

LONG opts[OPT_COUNT];
const char * extlha = ".lha";
const char * extzip = ".zip";
const char * extinfo = ".info";
const char * defcmdlha = "lha -rNYZ3 -Qa -Qo -Qw a";	// default pack command for lha archives
const char * defxcmdlha = "lha -aN -Qa x";	// default unpack command for lha archives
const char * defcmdzip = "zip -RND";	// default pack command for zip archives
const char * defxcmdzip = "unzip";	// default unpack command for zip archives
const char * deftmpdir = "T:warc.tmp";	// default directory to store decompressed files
int cntwhd = 0;				// count WHDLoad icons encountered
int cntwhdnodata = 0;			// count WHDLoad icons encountered without data objects
int cntupdicon = 0;			// count of icons updated
int cntdir = 0;				// count processed directories
int cntfile = 0;			// count processed files
int cntxpk = 0;				// count xpk-files
int cntarchived = 0;			// count archives created
int cntunarchived = 0;			// count archives extracted
int cntsz = 0;				// file size sum of files archived
int cntszarc = 0;			// file size sum of archives created
int cntarcdir;				// archive: count processed directories
int cntarcfile;				// archive: count processed files
int cntarcxpk;				// archive: count xpk-files
int cntarcsz;				// archive: file size sum to archive
int cntarcxpkdiff;			// archive: file size saved due xpk before archiving
struct Library *XpkBase = NULL;		// xpkmaster.library
struct Library *IconBase = NULL;	// icon.library

/*
 * disable vbcc Ctrl-C handling
 */
void _chkabort(void) { }

/*
 * check for Ctrl-C
 * out:
 * 	1 if Ctrl-C was pressed
 *
 */
int checkbreak(void) {
	if (CheckSignal(SIGBREAKF_CTRL_C)) {
		fprintf(stderr, "*** Break\n");
		return 1;
	}
	return 0;
}

/*
 * print dos error
 * in:
 * 	op	operation tried to perform
 * 	obj	object working on
 *
 */
void doserr(const char *op, const char *obj) {
	char buf[80];
	snprintf(buf,sizeof(buf),"%s '%s'",op,obj);
	PrintFault(IoErr(),buf);
}

/*
 * print error message with added newline
 * in:
 * 	msg	format string
 * 	...	args
 *
 */
void error(const char *msg, ...) {
	char buf[80];
	snprintf(buf, sizeof(buf), "error: %s\n", msg);
	va_list args;
	va_start(args, msg);
	vprintf(buf, args);
}

/*
 * print info message with added newline
 * in:
 * 	msg	format string
 * 	...	args
 *
 */
void info(const char *msg, ...) {
	va_list args;
	va_start(args, msg);
	vprintf(msg, args);
	putchar('\n');
}

/*
 * print Verbose/S message with added newline
 * in:
 * 	msg	format string
 * 	...	args
 *
 */
void verbose(const char *msg, ...) {
	if (opts[OPT_VERBOSE]) {
		va_list args;
		va_start(args, msg);
		vprintf(msg, args);
		putchar('\n');
	}
}

/*
 * check if file is encrypted/compressed using XPK
 * checks if the file is completely compressed to avoid false
 * detections on disk images for example
 * Warning: file may be encrypted/compressed multiple times!
 * in:
 *	name	file name
 *	size	file size
 * out:
 *	0=not-compressed 1=compressed 2=error
 */
int checkxpk(const char *name, ULONG size) {
	ULONG buf[32/4];		// XPK header size required to check
	BPTR fh;
	// check for min filesize
	if (size <= sizeof(buf)) return 0;
	// read XPK header
	fh = Open(name,MODE_OLDFILE);
	if (!fh) {
		doserr("open",name);
		return 2;
	}
	if (sizeof(buf) != Read(fh,buf,sizeof(buf))) {
		doserr("read",name);
		Close(fh);
		return 2;
	}
	Close(fh);
	if (buf[0] == ('X'<<24|'P'<<16|'K'<<8|'F') && buf[1] == size-8) {
		verbose("checkxpk: '%s' packed=%lu unpacked=%lu",name,size,buf[3]);
		return 1;
	}
	return 0;
}

/*
 * decrypt/uncompress a file using XPK
 * the file must be located in the current directory
 * to support multiple times compressed files efficient it first uncompress to
 * memory and writes it to the given temporary directory after the last decompression
 * as the last step it copies meta data (flags, comment)
 * in:
 * 	tmpdir	directory lock to store the decompressed file, if NULL overwrite source
 * 	fib	FileInfoBlock of file to decompress, required for filename and meta data
 * 	size	variable to return uncompressed size
 * out:
 *	0=error 1=success
 */
int unpackxpk(BPTR tmpdir, struct FileInfoBlock *fib, ULONG *outlen) {
	ULONG *in, *out;
	ULONG outbuflen, inbuflen;

	char errhead[20+MAXFILENAMELEN];
	snprintf(errhead, sizeof(errhead), "unpackxpk: '%s'", fib->fib_FileName);
	verbose(errhead);

	if (checkbreak()) return 0;

	// open the XPK library
	if (!XpkBase) {
		const char *xpkname = XPKNAME;
		int xpkver = 5;
		XpkBase = OpenLibrary (xpkname, xpkver);
		if (!XpkBase) {
			error("cannot open %s version %d", xpkname, xpkver);
			return 0;
		}
	}

	// unpack
	LONG err = XpkUnpackTags(
		XPK_InName, fib->fib_FileName,
		XPK_GetOutBuf, &out,
		XPK_GetOutLen, outlen,
		XPK_GetOutBufLen, &outbuflen,
		TAG_DONE
	);
	if (err != XPKERR_OK) {
		XpkPrintFault(err, errhead);
		return 0;
	}

	// check if compressed/encrypted another time
	while (*outlen >= 16 && out[0] == ('X'<<24|'P'<<16|'K'<<8|'F') && out[1] == *outlen-8) {
		// unpack
		in = out;
		inbuflen = outbuflen;
		err = XpkUnpackTags(
			XPK_InBuf, in,
			XPK_InLen, *outlen,
			XPK_GetOutBuf, &out,
			XPK_GetOutLen, outlen,
			XPK_GetOutBufLen, &outbuflen,
			TAG_DONE
		);
		// free unpacked input file
		FreeMem(in, inbuflen);
		// check unpack return code
		if (err != XPKERR_OK) {
			XpkPrintFault(err, errhead);
			return 0;
		}
	}

	// change directory if requested
	BPTR olddir;
	if (tmpdir) {
		olddir = CurrentDir(tmpdir);
	}

	// write unpacked file
	err = 0;
	BPTR fh = Open(fib->fib_FileName, MODE_NEWFILE);
	if (!fh) {
		doserr("xpkunpack open for write", fib->fib_FileName);
	} else {
		if (*outlen != Write(fh, out, *outlen)) {
			doserr("xpkunpack write", fib->fib_FileName);
		} else {
			err = 1;
		}
		Close(fh);
	}

	// set meta data
	if (err) {
		if (
			! SetFileDate(fib->fib_FileName, &fib->fib_Date) ||
			! SetProtection(fib->fib_FileName, fib->fib_Protection) ||
			fib->fib_Comment[0] ? ! SetComment(fib->fib_FileName, fib->fib_Comment) : 0
		) {
			doserr("xpkunpack set meta data", fib->fib_FileName);
			err = 0;
		}
	}

	// change back directory if requested
	if (tmpdir) {
		CurrentDir(olddir);
	}

	// free buffer
	FreeMem(out, outbuflen);

	return err;
}

/*
 * create parent dir of the given path
 * works recursive
 * in:
 * 	path	path
 * out:
 *	0=error 1=success
 */
int createdirparent(const char *path) {
	char *part, savedchar;
	BPTR lock;

	// verbose("createdirparent '%s'", path);

	part = PathPart(path);
	if (!part || part == path) {
		doserr("createdirparent pathpart", path);		// to get at least a message
		return 0;
	}
	savedchar = *part;
	*part = 0;
	if (! (lock = CreateDir(path))) {
		int err = IoErr();
		if (err != ERROR_DIR_NOT_FOUND && err != ERROR_OBJECT_NOT_FOUND) {
			doserr("createdirparent create dir", path);
			return 0;
		}
		if (! createdirparent(path)) return 0;
		// try again
		if (! (lock = CreateDir(path))) {
			doserr("createdirparent create dir 2nd", path);
			return 0;
		}
	}
	UnLock(lock);
	*part = savedchar;
	return 1;
}

/*
 * create the temporary sub-directory and return a lock of it
 * if directories above are missing create them also
 * in:
 * 	path	path of the dir to create
 * out:
 *	0=error lock-to-dir
 */
BPTR gettmpdir(const char *path) {
	char buf[MAXPATHNAMELEN];
	BPTR lock;

	// verbose("gettmpdir '%s'", path);

	snprintf(buf, sizeof(buf), (char*)opts[OPT_TMPDIR]);
	// if path is non empty add it
	if (path && path[0]) AddPart(buf, path, sizeof(buf));

	if (lock = Lock(buf, SHARED_LOCK)) return lock;
	if (lock = CreateDir(buf)) return lock;
	int err = IoErr();
	if (err == ERROR_DIR_NOT_FOUND || err == ERROR_OBJECT_NOT_FOUND) {
		// possible error message created by createdirparent
		if (! createdirparent(buf)) return 0;
		// try again
		if (lock = CreateDir(buf)) return lock;
	}
	doserr("gettmpdir create dir", buf);
	return 0;
}

/*
 * print quoted string + new line to file
 * in:
 * 	fh	file handle
 * 	text	string to print
 * out:
 *	0=error 1=success
 */
int putline(BPTR fh, const char *txt) {
	if (FPrintf(fh, "\"%s\"\n", txt) < 0) {
		char buffer[MAXPATHNAMELEN];
		NameFromFH(fh, buffer, sizeof(buffer));
		doserr("writing filelist", buffer);
		return 0;
	}
	return 1;
}

/*
 * recursive function to scan a directory for later archiving
 * XPK files are decompressed to directory tmpdir
 * file names are written to filehandles fhunc/fhdec
 * in:
 * 	path	path name of the current dir
 * 	dir	directory name in the current dir to scan
 * out:
 *	0=error 1=success
 */
int archivescan(const char *path, const char *dirname, BPTR fhunc, BPTR fhdec) {
	int rc=0;		// default = failed
	char name[MAXPATHNAMELEN];
	BPTR tmpdir = 0;

	if (checkbreak()) return rc;

	// build new path
	char newpath[MAXPATHNAMELEN];
	snprintf(newpath, sizeof(newpath), path);
	AddPart(newpath, dirname, sizeof(newpath));

	// lock & change to directory
	BPTR dir = Lock(dirname, SHARED_LOCK);
	if (!dir) {
		doserr("lock", dirname);
		return rc;
	}
	BPTR olddir = CurrentDir(dir);

	// scan directory
	struct FileInfoBlock fib;
	if (! Examine(dir, &fib)) {
		doserr("examine", dirname);
	} else {
		while (ExNext(dir, &fib)) {
			snprintf(name, sizeof(name), newpath);
			AddPart(name, fib.fib_FileName, sizeof(name));
			// do we need special handling for links here?
			if (fib.fib_DirEntryType >= 0) {
				// directory
				cntarcdir++;
				verbose("dir:  '%s'", name);
				if (! archivescan(newpath, fib.fib_FileName, fhunc, fhdec)) goto failed;
			} else {
				// file
				cntarcfile++;
				cntarcsz += fib.fib_Size;
				// check if file is XPK-compressed
				switch (checkxpk(fib.fib_FileName, fib.fib_Size)) {
					case 0:	// uncompressed
						verbose("file: '%s' size=%ld", name, fib.fib_Size);
						if (! putline(fhunc, name)) goto failed;
						break;
					case 1:	// compressed
						cntarcxpk++;
						if (! tmpdir && ! (tmpdir = gettmpdir(newpath))) goto failed;
						ULONG size;
						if (! unpackxpk(tmpdir, &fib, &size)) goto failed;
						cntarcxpkdiff += size - fib.fib_Size;
						verbose("xpk:  '%s' packed=%ld unpacked=%lu",
							name, fib.fib_Size, size);
						if (! putline(fhdec, name)) goto failed;
						break;
					case 2:	// error
						goto failed;
				}
			}
		}
		if (IoErr() != ERROR_NO_MORE_ENTRIES) {
			doserr("exnext", dirname);
		} else {
			rc = 1;		// success
		}
	}

	failed:		// on error inside ExNext loop

	// return to old directory and unlock
	CurrentDir(olddir);
	UnLock(dir);

	// free tmpdir
	if (tmpdir) UnLock(tmpdir);

	return rc;
}

/*
 * print and execute given command
 * in:
 * 	cmd	command to execute
 * out:
 *	return code of command
 */
int system(const STRPTR cmd) {
	verbose("executing '%s'", cmd);
	return SystemTagList(cmd, NULL);
}

/*
 * delete given file/directory recursively
 * in:
 * 	dir	file/directory name to delete
 * out:
 *	0=success >0=error
 */
int delete(const STRPTR dirname) {
	int rc;
	char cmd[256];
	snprintf(cmd,sizeof(cmd),"Delete \"%s\" Quiet Force All", dirname);
	rc = system(cmd);
	if (rc != RETURN_OK) {
		error("deleting failed: '%s'", cmd);
	}
	return rc;
}

/*
 * delete given file/directory recursively only if NoDelete/S is not set
 * in:
 * 	dir	file/directory name to delete
 * out:
 *	0=success >0=error
 */
int deleteOpt(const STRPTR dirname) {
	if (opts[OPT_NODELETE]) {
		return RETURN_OK;
	} else {
		verbose("deleting '%s'", dirname);
		return delete(dirname);
	}
}

/*
 * create archive from the given directory
 * the directory must be located in the actual directory!
 * - scan the directory and decompress all xpk files to 'tmpdir'
 *   and preserve file meta data
 * - if there were no xpk files just archive the directory using lha/zip
 * - if there were xpk files:
 *   lha: create archive via filelist from actual directory and 'tmpdir'
 *   zip: create archive via filelist from actual directory and in a
 *        second run add all files from 'tmpdir'
 */
int archive(const STRPTR dirname, char arcname[MAXFILENAMELEN]) {
	int rc = RETURN_ERROR;
	char listunc[] = "T:warc.list.unc";
	char listdec[] = "T:warc.list.dec";

	info("archiving '%s'", dirname);

	if (checkbreak()) return RETURN_ERROR;

	// make sure the given directory is located in the current dir
	if (FilePart(dirname) != dirname) {
		error("archive: '%s' must be directory in the current dir", dirname);
		return rc;
	}

	// open the directory
	BPTR dir = Lock(dirname, SHARED_LOCK);
	if (!dir) {
		doserr("lock", dirname);
		return rc;
	}

	// build archive name
	snprintf(arcname, MAXFILENAMELEN, "%s%s", dirname, extlha);

	// check if archive already exists
	BPTR arc = Open(arcname, MODE_OLDFILE);
	if (arc) {
		error("archive '%s' already exists", arcname);
		Close(arc);
	} else {
		// open filelist for uncompressed files
		BPTR fhunc = Open(listunc, MODE_NEWFILE);
		if (!fhunc) {
			doserr("open", listunc);
		} else {
			// put homedir for lha into the file
			FPrintf(fhunc, "\"%s/\"\n", dirname);
			// open filelist for decompressed files
			BPTR fhdec = Open(listdec, MODE_NEWFILE);
			if (!fhdec) {
				doserr("open", listdec);
			} else {
				// put homedir for lha into the file
				FPrintf(fhdec, "\"%s/\"\n", (char*)opts[OPT_TMPDIR]);

				// change to the directory
				BPTR olddir = CurrentDir(dir);

				// iterate over all entries in the actual directory
				cntarcdir = cntarcfile = cntarcxpk = cntarcsz = cntarcxpkdiff = 0;	// counters
				if (archivescan(NULL, NULL, fhunc, fhdec)) {
					info("scanned '%s': dirs=%d files=%d size=%d xpkfiles=%d xpksaved=%d",
						dirname,cntarcdir,cntarcfile,cntarcsz,cntarcxpk,cntarcxpkdiff);
					cntdir += cntarcdir;
					cntfile += cntarcfile;
					cntxpk += cntarcxpk;
					cntsz += cntarcsz;
					rc = RETURN_OK;
				} else {
					error("scan/unpack failed!");
				}

				// return directory
				CurrentDir(olddir);

				// free filelist decompressed
				Close(fhdec);
			}
			// free filelist uncompressed
			Close(fhunc);
		}
	}

	// free directory
	UnLock(dir);

	// leave on error
	if (rc != RETURN_OK) {
		// delete unpacked XPK files
		if (cntarcxpk) delete((char*)opts[OPT_TMPDIR]);
		return rc;
	}

	// create archive
	char cmd[256];
	int cmdlen = snprintf(cmd, sizeof(cmd), "%s %s @%s", defcmdlha, arcname, listunc);
	if (cntarcxpk) {
		snprintf(cmd+cmdlen, sizeof(cmd)-cmdlen, " @%s", listdec);
	}
	rc = system(cmd);

	// delete unpacked XPK files
	if (cntarcxpk) delete((char*)opts[OPT_TMPDIR]);

	// check archive result
	if (rc != RETURN_OK) {
		error("archiving '%s' failed", arcname);
		return rc;
	} else {
		cntarchived++;
	}

	// delete filelists
	DeleteFile(listdec);
	DeleteFile(listunc);

	// get archive size for statistics
	arc = Open(arcname, MODE_OLDFILE);
	if (! arc) {
		doserr("open created archive", arcname);
		return RETURN_ERROR;
	}
	Seek(arc, 0, OFFSET_END);
	int arclen = Seek(arc, 0, OFFSET_BEGINNING);
	Close(arc);
	cntszarc += arclen;
	info("archive '%s' saved %ld bytes", arcname, cntarcsz-arclen);

	return rc;
}

/*
 * posix clib
 */
int strcasecmp(const char *s1, const char *s2) {
	int result;

	if (s1 == s2) return 0;
	if (s1 == NULL) return 1;
	if (s2 == NULL) return -1;

	while ((result = tolower(*s1) - tolower(*s2++)) == 0)
		if (*s1++ == '\0') break;

	return result;
}

/*
 * unarchive file from the actual directory
 * 	arcname	name of archive to extract
 * 	newname name of the directory created for the archive, filled by this function
 * out:
 *	RETURN_OK, RETURN_ERROR
 */
int unarchive(const STRPTR arcname, char dirname[MAXFILENAMELEN]) {

	info("unarchiving '%s'", arcname);

	if (checkbreak()) return RETURN_ERROR;

	size_t namelen = strlen(arcname);
	size_t extlen = strlen(extlha);
	if (namelen <= extlen) return RETURN_ERROR;
	size_t baselen = namelen - extlen;
	const char *xcmd;
	if (strcasecmp(arcname+baselen, extlha) == 0) {
		xcmd = defxcmdlha;
	} else if (strcasecmp(arcname+baselen, extzip) == 0) {
		xcmd = defxcmdzip;
	} else return RETURN_ERROR;

	// create data directory to store archive content
	strncpy(dirname, arcname, baselen);
	dirname[baselen] = 0;
	BPTR dir = CreateDir(dirname);
	if (! dir) {
		doserr("create dir", dirname);
		return RETURN_ERROR;
	}

	// lock from CreateDir is an exclusive lock, SystemTagList cannot dup it
	if (! ChangeMode(CHANGE_LOCK, dir, ACCESS_READ)) {
		doserr("change mode lock", dirname);
		UnLock(dir);
		return RETURN_ERROR;
	}

	// enter directory
	BPTR olddir = CurrentDir(dir);

	// extract
	char cmd[256];
	snprintf(cmd, sizeof(cmd), "%s /%s", xcmd, arcname);
	int rc = system(cmd);

	// return directory
	CurrentDir(olddir);
	UnLock(dir);

	// return
	if (rc != RETURN_OK) {
		error("unarchiving failed: '%s'",cmd);
		delete(dirname);
	} else {
		cntunarchived++;
	}
	return rc;
}

/*
 * amiga.lib
 */
void NewList(struct MinList *lh)
{
	lh->mlh_Head = (struct MinNode *)&(lh->mlh_Tail);
	lh->mlh_Tail = NULL;
	lh->mlh_TailPred = (struct MinNode *)&(lh->mlh_Head);
}

/*
 * check if name has given extension
 * in:
 * 	name	name to check
 * 	ext	extension to check
 * out:
 *	0=hasn't <>0=has
 */
int cmpExt(const char *name, const char *ext) {
	size_t namelen = strlen(name);
	size_t extlen = strlen(ext);
	if (namelen > extlen && strcasecmp(name+namelen-extlen, ext) == 0) {
		return 1;
	} else {
		return 0;
	}
}

/*
 * check if name has one of the supported archive extensions
 * in:
 * 	name	name to check
 * out:
 *	0=hasn't <>0=has
 */
int cmpExtArc(const char *name) {
	if (cmpExt(name, extlha) || cmpExt(name, extzip)) {
		return 1;
	} else {
		return 0;
	}
}

// structure to hold already processed data directories/archives
struct WorkNode {
	struct MinNode wn_Node;
	char wn_pre[MAXFILENAMELEN];	// name before processing
	char wn_post[MAXFILENAMELEN];	// name after processing
};

/*
 * add work entry to list with given data
 * in:
 * 	list	MinList to add MinNode
 * 	pre	object name before processing
 * 	post	object name after processing
 * out:
 *	1=success 0=nomemory
 */
int addWork(struct MinList *list, const char *pre, const char *post) {
	struct WorkNode *node = AllocVec(sizeof(struct WorkNode), 0);
	if (!node) {
		error("no memory for node '%s'", pre);
		return 0;
	}
	strcpy(node->wn_pre, pre);
	strcpy(node->wn_post, post);
	AddHead((struct List *) list, (struct Node *) node);
	return 1;
}

/*
 * find work entry in list with given wn_pre
 * in:
 * 	list	MinList of struct WorkNode
 * 	pre	entry to search
 * out:
 *	success
 */
const char * findWork(struct MinList *list, const char *pre) {
	struct WorkNode *node;
	for (	node = (struct WorkNode *) list->mlh_Head ;
		node->wn_Node.mln_Succ != NULL ;
		node = (struct WorkNode *) node->wn_Node.mln_Succ
	) {
		if (strcasecmp(node->wn_pre, pre) == 0) return node->wn_post;
	}
	return NULL;
}

/*
 * append data object to existing data option
 * in:
 * 	arg	data option
 * 	data	object to add
 * out:
 *	-
 */
void addData(char *arg, const char *data) {
	if (arg[0]) strcat(arg, ",");
	strcat(arg, data);
}

/*
 * analyse given icon located in the current directory
 * if DefaultTool is WHDLoad search ToolTypes
 * if ToolType Data is found perform Un/Archive for all data objects not already processed
 * else load Slave and check for slv_CurrentDir, perform Un/Archive if exists
 * processed data objects are remembered in list
 * update/add icons Data ToolType if something has changed
 * in:
 *	path	NULL or path of current directory for info message if not verbose
 * 	iconname name of icon to check, must be located in the actual directory!
 * 	list	list of already processed data objects
 * out:
 *	RETURN_OK	all processed successful
 *	RETURN_WARN	file is no icon or not a WHDLoad one
 *	RETURN_ERROR	error ocurred
 */
int processIcon(const STRPTR path, const STRPTR iconname, struct MinList *list) {
	struct MinList loclist;		// local list to hold data objects processed here
	NewList(&loclist);

	verbose("processing icon '%s'", iconname);

	if (checkbreak()) return RETURN_ERROR;

	// open icon.library
	if (!IconBase) {
		const char *iconlibname = "icon.library";
		const int iconlibver = 44;
		IconBase = OpenLibrary (iconlibname, iconlibver);
		if (!IconBase) {
			error("cannot open %s version %d", iconlibname, iconlibver);
			return RETURN_ERROR;
		}
	}

	// cut '.info' extension
	size_t iconnamelen = strlen(iconname);
	if (iconnamelen >= MAXFILENAMELEN) return RETURN_ERROR;
	size_t extlen = strlen(extinfo);
	if (iconnamelen <= extlen) return RETURN_ERROR;
	size_t baselen = iconnamelen - extlen;
	char base[MAXFILENAMELEN];
	strcpy(base, iconname);
	base[baselen] = 0;

	// open icon
	struct DiskObject *icon = GetDiskObject(base);
	if (icon == NULL) {
		doserr("open icon", iconname);
		return RETURN_WARN;
	}

	// check DefaultTool = WHDLoad
	if (icon->do_Type != WBPROJECT) {
		verbose("icon '%s' is no project icon", iconname);
		FreeDiskObject(icon);
		return RETURN_WARN;
	}
	const char * deftool = "WHDLoad";
	if (strcasecmp(icon->do_DefaultTool, deftool) != 0) {
		verbose("icon '%s' has not DefaultTool '%s'", iconname, deftool);
		FreeDiskObject(icon);
		return RETURN_WARN;
	}

	// WHDLoad icon found
	if (path && ! opts[OPT_VERBOSE]) info("checking '%s/%s'", path, iconname);
	cntwhd++;

	// search Data option
	const char * ttnamedata = "Data";
	char * ttdata = FindToolType(icon->do_ToolTypes, ttnamedata);
	char argdata[256];
	char newargdata[256] = "";
	if (ttdata) {
		// ToolType data found
		if (strlen(ttdata) >= sizeof(argdata)) {
			error("icon data too long '%s'", ttdata);
			FreeDiskObject(icon);
			return RETURN_ERROR;
		}
		strcpy(argdata, ttdata);
		verbose("data '%s' found in icon '%s'", argdata, iconname);
	} else {
		// search Slave option
		const char * ttnameslave = "Slave";
		char * ttslave = FindToolType(icon->do_ToolTypes, ttnameslave);
		if (ttslave == NULL) {
			error("icon '%s' has no %s ToolType", iconname, ttnameslave);
			FreeDiskObject(icon);
			return RETURN_ERROR;
		}
		// read Slave
		BPTR fhslave = Open(ttslave, MODE_OLDFILE);
		if (! fhslave) {
			doserr("open Slave", ttslave);
			FreeDiskObject(icon);
			return RETURN_ERROR;
		}
		Seek(fhslave,0,OFFSET_END);
		size_t len = Seek(fhslave,0,OFFSET_BEGINNING);
		ULONG *slaveexe = AllocVec(len, 0);
		if (slaveexe == NULL) {
			error("no memory for Slave '%s', %ld bytes", ttslave, len);
			Close(fhslave);
			FreeDiskObject(icon);
			return RETURN_ERROR;
		}
		if (len != Read(fhslave, slaveexe, len)) {
			doserr("read Slave",ttslave);
			FreeVec(slaveexe);
			Close(fhslave);
			FreeDiskObject(icon);
			return RETURN_ERROR;
		}
		Close(fhslave);
		// check Slave
		struct WHDLoadSlave *slave = (struct WHDLoadSlave *) (slaveexe + 8);	// skip executable header
		if (strncmp(slave->ws_ID, WHDLoadSlaveID, sizeof(slave->ws_ID)) != 0) {
			error("invalid Slave structure '%s'", ttslave);
			FreeVec(slaveexe);
			FreeDiskObject(icon);
			return RETURN_ERROR;
		}
		// if no data directory leave
		if (slave->ws_CurrentDir == 0) {
			FreeVec(slaveexe);
			FreeDiskObject(icon);
			cntwhdnodata++;
			return RETURN_OK;
		}
		// copy ws_CurrentDir
		const char * slvdata = (char*)slave + slave->ws_CurrentDir;
		if (strlen(slvdata) >= sizeof(argdata)) {
			error("Slave data too long '%s'", slvdata);
			FreeVec(slaveexe);
			FreeDiskObject(icon);
			return RETURN_ERROR;
		}
		strcpy(argdata, slvdata);
		FreeVec(slaveexe);
		verbose("data '%s' found in Slave '%s' from icon '%s'", argdata, ttslave, iconname);
	}
	// split data on ","
	char tmpargdata[sizeof(argdata)];
	strcpy(tmpargdata, argdata);	// because strtok() modifies the string!
	for (char *data = strtok(tmpargdata, ","); data != NULL; data = strtok(NULL, ",")) {
		// foreach data object
		// check if already processed
		const char *newdataptr = findWork(list, data);
		if (newdataptr) {
			// already processed
			addData(newargdata, newdataptr);
		} else {
			// has it an archive extension?
			if (cmpExtArc(data)) {
				// is an archive
				if (opts[OPT_UNARC]) {
					// unarchive
					char newdata[MAXFILENAMELEN];
					if (unarchive(data, newdata) != RETURN_OK) goto cleanup;
					if (! addWork(&loclist, data, newdata)) goto cleanup;
					addData(newargdata, newdata);
				} else {
					// nothing to do
					addData(newargdata, data);
				}
			} else {
				// is no archive
				if (opts[OPT_UNARC]) {
					// nothing to do
					addData(newargdata, data);
				} else {
					// archive
					char newdata[MAXFILENAMELEN];
					if (archive(data, newdata) != RETURN_OK) goto cleanup;
					if (! addWork(&loclist, data, newdata)) goto cleanup;
					addData(newargdata, newdata);
				}
			}
		}
	}

	// update icon if something has changed
	if (strcmp(argdata, newargdata)) {
		STRPTR *ttarray = NULL;
		// prepend Data=
		int len = strlen(newargdata);
		char *s;
		for (s = newargdata + len; len >= 0; len--) *(s+6) = *s--;
		strcpy(newargdata, ttnamedata);
		newargdata[4] = '=';
		// already present?
		if (ttdata) {
			// replace existing ToolType Data
			STRPTR *tt;
			for ( tt = icon->do_ToolTypes; *tt; tt++ ) {
				if (*tt + 5 == ttdata) {
					*tt = newargdata;
					break;
				}
			}
			if (! *tt) {
				error("ToolType not found");
				goto cleanup;
			}
		} else {
			// add new ToolType Data
			// we must copy existing ToolTypes to add a new one
			STRPTR *tt = icon->do_ToolTypes;
			int len = 2 * sizeof(tt);	// new one + terminator
			while (*tt++) len += sizeof(tt);
			ttarray = AllocVec(len, 0);
			if (! ttarray) {
				error("no memory for new ToolType");
				goto cleanup;
			}
			tt = icon->do_ToolTypes;
			icon->do_ToolTypes = ttarray;
			STRPTR *ttnew = ttarray;
			while (*tt) *ttnew++ = *tt++;
			*ttnew++ = newargdata;
			*ttnew = NULL;
		}
		if (! PutDiskObject(base, icon)) {
			doserr("write icon", iconname);
			if (ttarray) FreeVec(ttarray);
			goto cleanup;
		}
		if (ttarray) FreeVec(ttarray);
		info("icon '%s' updated", iconname);
		cntupdicon++;
	}

	// close icon
	FreeDiskObject(icon);

	// propagate processed data objects to provided list
	// delete replaced data objects
	struct WorkNode *node, *next;
	for (	node = (struct WorkNode *) loclist.mlh_Head;
		(next = (struct WorkNode *) node->wn_Node.mln_Succ) != NULL;
		node = next
	) {
		Remove((struct Node *) node);
		AddHead((struct List *) list, (struct Node *) node);
		deleteOpt(node->wn_pre);	// rc is ignored, can anyway no handled useful
	}

	return RETURN_OK;

	// cleanup if something has failed in the data loop, or when updating the icon
	cleanup:

	// close icon
	FreeDiskObject(icon);

	// delete new created data objects
	for (	node = (struct WorkNode *) loclist.mlh_Head;
		(next = (struct WorkNode *) node->wn_Node.mln_Succ) != NULL;
		node = next
	) {
		Remove((struct Node *) node);
		info("deleting '%s'", node->wn_post);
		delete(node->wn_post);	// rc is ignored, can anyway no handled useful
		FreeVec(node);
	}

	return RETURN_ERROR;
}

/*
 * scan given directory recursively for .info files
 * process (un/archive) all found WHDLoad data archives/directories
 * in:
 * 	path	path name of the current dir (initial NULL)
 * 	dir	directory name in the current dir to scan
 * out:
 *	RETURN_OK, RETURN_ERROR
 */
int scan(const char *path, const char *dirname) {
	int rc = RETURN_ERROR;		// default = failed
	struct MinList list;
	NewList(&list);

	// build new path
	char newpath[MAXPATHNAMELEN];
	snprintf(newpath, sizeof(newpath), path);
	AddPart(newpath, dirname, sizeof(newpath));
	// remove trailing slash, possible if warc got called with dir and trailing slash
	char *s = newpath; while (*s++); s -= 2; if (*s == '/') *s = 0;

	verbose("scanning: '%s'", newpath);

	// lock & change to directory
	BPTR dir = Lock(dirname, SHARED_LOCK);
	if (!dir) {
		doserr("scan lock dirname", dirname);
		return RETURN_ERROR;
	}
	BPTR olddir = CurrentDir(dir);

	// scan directory
	struct FileInfoBlock fib;
	if (! Examine(dir, &fib)) {
		doserr("scan examine dirname", dirname);
	} else {
		while (ExNext(dir, &fib)) {
			// do we need special handling for links here?
			if (fib.fib_DirEntryType >= 0) {
				// directory
				cntdir++;
				if (scan(newpath, fib.fib_FileName)) goto failed;
			} else {
				// file
				cntfile++;
				// check if file is icon
				if (cmpExt(fib.fib_FileName, extinfo)) {
					// process icon
					// no error on RETURN_WARN
					if (processIcon(newpath, fib.fib_FileName, &list) >= RETURN_ERROR) goto failed;
				}
			}
		}
		if (IoErr() != ERROR_NO_MORE_ENTRIES) {
			doserr("scan exnext", dirname);
		} else {
			rc = RETURN_OK;		// success
		}
	}

	failed:		// on error inside ExNext loop

	// return to old directory and unlock
	CurrentDir(olddir);
	UnLock(dir);

	// free list nodes created by processIcon
	struct MinNode *node, *next;
	for (	node = list.mlh_Head;
		(next = node->mln_Succ) != NULL;
		node = next
	) {
		FreeVec(node);
	}

	return rc;
}

/*
 * main
 */
int main (void) {
	int rc = RETURN_FAIL;
	struct RDArgs *rdargs;

	opts[OPT_TMPDIR] = (ULONG) deftmpdir;
	rdargs = ReadArgs(TEMPLATE, opts, NULL);
	if (rdargs == NULL) {
		PrintFault(IoErr(),NULL);
	} else {
		// check arguments
		// TmpDir must not already exist
		BPTR lock;
		if ((lock = Lock((char*)opts[OPT_TMPDIR], SHARED_LOCK)) != 0) {
			UnLock(lock);
			error("TmpDir '%s' already exists!", (char*)opts[OPT_TMPDIR]);
		} else {
			// check if Src is directory or file
			char *src = (char*) opts[OPT_SRC];
			lock = Lock(src, SHARED_LOCK);
			if (lock == 0) {
				doserr("open", src);
			} else {
				struct FileInfoBlock fib;
				if (! Examine(lock, &fib)) {
					doserr("examine", src);
					UnLock(lock);
				} else {
					// enter parent directory of Src required for un/archive and processIcon
					BPTR parent = ParentDir(lock);
					BPTR olddir = CurrentDir(parent);
					// free the lock because the object gets deleted on un/archive
					UnLock(lock);
					// check for dir/file
					// do we need special handling for links here?
					if (fib.fib_DirEntryType >= 0) {
						// directory
						// scan or archive
						if (opts[OPT_SCAN]) {
							// scan directory
							// may be not relative to current dir!
							CurrentDir(olddir);
							rc = scan(NULL, src);
							info("summary: whdicons=%ld whdnodata=%ld updicon=%ld dirs=%ld files=%ld xpkfiles=%ld archived=%ld unarchived=%ld",
								cntwhd, cntwhdnodata, cntupdicon, cntdir, cntfile, cntxpk, cntarchived, cntunarchived);
							if (cntarchived) info("archived %ld bytes files into %ld bytes archives, saved %ld", cntsz, cntszarc, cntsz-cntszarc);
						} else {
							// archive
							char arcname[MAXFILENAMELEN];
							rc = archive(fib.fib_FileName, arcname);
							if (rc == RETURN_OK) rc = deleteOpt(fib.fib_FileName);
						}
					} else {
						// file
						if (cmpExtArc(fib.fib_FileName)) {
							// unarchive
							char dirname[MAXFILENAMELEN];
							rc = unarchive(fib.fib_FileName, dirname);
							if (rc == RETURN_OK) rc = deleteOpt(fib.fib_FileName);
						} else if (cmpExt(fib.fib_FileName, extinfo)) {
							// process icon
							struct MinList list;
							NewList(&list);
							rc = processIcon(NULL, fib.fib_FileName, &list);
							struct MinNode *node, *next;
							for (	node = list.mlh_Head;
								(next = node->mln_Succ) != NULL;
								node = next
							) {
								FreeVec(node);
							}
						} else {
							error("invalid file '%s', must be an archive or icon", src);
						}
					}
					// return to initial directory
					CurrentDir(olddir);
					UnLock(parent);
				}
			}
		}
		FreeArgs(rdargs);
	}
	if (XpkBase) CloseLibrary(XpkBase);
	if (IconBase) CloseLibrary(IconBase);
	return rc;
}

