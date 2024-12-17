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
 * 2021-01-20 started
 * 2021-07-14 lha working without XPK files
 * 2021-10-31 XPK decompression added
 *
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include <dos/dos.h>
#include <xpk/xpk.h>
#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/xpkmaster.h>

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
const char * defcmdlha = "lha -eFrYZ3 -Qw a";	// default pack command for lha archives
const char * defxcmdlha = "lha -CF -Qa x";	// default unpack command for lha archives
const char * defcmdzip = "zip -RND";	// default pack command for lha archives
const char * defxcmdzip = "unzip";	// default unpack command for zip archives
const char * deftmpdir = "T:warc.tmp";	// default directory to store decompressed files
BPTR fhunc, fhdec;			// filehandles for temporary list files
int cntdir;				// count processed directories
int cntfile;				// count processed files
int cntxpk;				// count processed/uncompressed xpk-files
int cntsz, cntszxpk, cntszarc;		// size of all files uncompressed, size saved by xpk, saved by archive
struct Library *XpkBase;		// xpkmaster.library

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
	if (buf[0] == 'X'<<24|'P'<<16|'K'<<8|'F' && buf[1] == size-8) {
		verbose("checkxpk: '%s' packed=%lu unpacked=%lu",name,size,buf[3]);
		return 1;
	}
	return 0;
}

/*
 * decrypt/uncompress a file using XPK
 * the file must be located in the current directory
 * to support multiple times compressed files first uncompress to 
 * memory and write it to temporary directory at the end
 * as last step copy meta data (flags, comment)
 * in:
 * 	tmpdir	directory lock to store the decompressed file, if NULL overwrite source
 * 	fib	FileInfoBlock of file to decompress
 * 	size	variable to return uncompressed size
 * out:
 *	0=error 1=success
 */
int unpackxpk(BPTR tmpdir, struct FileInfoBlock *fib, ULONG *outlen) {
	ULONG *in, *out;
	ULONG outbuflen, inbuflen;
	const char xpkname[] = XPKNAME;
	int xpkver = 5;
	LONG err;
	char errhead[] = "XPK-unpack failed";
	BPTR fh, olddir;

	verbose("unpackxpk: '%s'", fib->fib_FileName);

	// open the XPK library
	if (!XpkBase) {
		XpkBase = OpenLibrary (xpkname, xpkver);
		if (!XpkBase) {
			error("cannot open %s version %d", xpkname, xpkver);
			return 0;
		}
	}

	// unpack
	err = XpkUnpackTags(
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
	while (*outlen >= 16 && out[0] == 'X'<<24|'P'<<16|'K'<<8|'F' && out[1] == *outlen-8) {
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
		FreeMem(in,inbuflen);
		// check unpack return code
		if (err != XPKERR_OK) {
			XpkPrintFault(err, errhead);
			return 0;
		}
	}

	// change directory if requested
	if (tmpdir) {
		olddir = CurrentDir(tmpdir);
	}

	// write unpacked file
	err = 0;
	fh = Open(fib->fib_FileName, MODE_NEWFILE);
	if (!fh) {
		doserr("open to write", fib->fib_FileName);
	} else {
		if (*outlen != Write(fh, out, *outlen)) {
			doserr("write", fib->fib_FileName);
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
			doserr("set meta data",fib->fib_FileName);
			err = 0;
		}
	}

	// change back directory if requested
	if (tmpdir) {
		CurrentDir(olddir);
	}

	// free buffer
	FreeMem(out,outbuflen);

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
	char * part, savedchar;
	BPTR lock;

	part = PathPart(path);
	if (!part || part == path) {
		doserr("pathpart",path);		// to get at least a message
		return 0;
	}
	savedchar = *part;
	*part = 0;
	if (! (lock = CreateDir(path))) {
		if (IoErr() != ERROR_DIR_NOT_FOUND) {
			doserr("create dir",path);
			return 0;
		}
		if (! createdirparent(path)) {
			return 0;
		}
		// try again
		if (! (lock = CreateDir(path))) {
			doserr("create dir",path);
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
	char buf[256];
	BPTR lock;

	snprintf(buf,sizeof(buf),(char*)opts[OPT_TMPDIR]);
	AddPart(buf,path,sizeof(buf));

	if (lock = Lock(buf,SHARED_LOCK)) return lock;	// should not happen
	if (lock = CreateDir(buf)) return lock;
	if (IoErr() == ERROR_DIR_NOT_FOUND) {
		if (! createdirparent(buf)) {
			// error message done by createdirparent
			return 0;
		}
		// try again
		if (lock = CreateDir(buf)) return lock;
	}
	doserr("create dir",buf);
	return 0;
}

/*
 * print string + new line to file
 * in:
 * 	fh	file handle
 * 	text	string to print
 * out:
 *	0=error 1=success
 */
int putline(BPTR fh, const char *txt) {
	if (FPuts(fh,txt) != 0 || FPutC(fh,'\n') != '\n') {
		char buffer[256];
		NameFromFH(fh, buffer, sizeof(buffer));
		doserr("writing filelist", buffer);
		return 0;
	}
	return 1;
}

/*
 * recursive function to scan a directory for later compression
 * XPK files are decompressed to directory tmpdir
 * file names are written to filehandles fhunc/fhdec
 * in:
 * 	path	path name of the current dir
 * 	dir	directory name in the current dir to scan
 * out:
 *	0=error 1=success
 */
int scan(const char *path, const char *dir) {
	BPTR l, o, tmpdir=0;
	struct FileInfoBlock fib;
	int rc=0;		// default = failed
	char newpath[256], name[256];
	ULONG size;

	// build new path
	snprintf(newpath,sizeof(newpath),path);
	AddPart(newpath,dir,sizeof(newpath));

	// lock & change to directory
	l = Lock(dir,SHARED_LOCK);
	if (!l) {
		doserr("lock",dir);
		return rc;
	}
	o = CurrentDir(l);

	// scan directory
	if (! Examine(l,&fib)) {
		doserr("examine",dir);
	} else {
		while (ExNext(l,&fib)) {
			snprintf(name,sizeof(name),newpath);
			AddPart(name,fib.fib_FileName,sizeof(name));
			// do we need special handling for links here?
			if (fib.fib_DirEntryType >= 0) {
				// directory
				cntdir++;
				verbose("dir:  '%s'",name);
				if (! scan(newpath,fib.fib_FileName)) goto failed;
			} else {
				// file
				cntfile++;
				// check if file is XPK-compressed
				switch (checkxpk(fib.fib_FileName,fib.fib_Size)) {
					case 0:	// uncompressed
						cntsz += fib.fib_Size;
						verbose("file: '%s' size=%ld",name,fib.fib_Size);
						if (! putline(fhunc,name)) goto failed;
						break;
					case 1:	// compressed
						cntxpk++;
						if (! tmpdir && ! (tmpdir = gettmpdir(newpath))) goto failed;
						if (! unpackxpk(tmpdir,&fib,&size)) goto failed;
						cntsz += size;
						cntszxpk += size - fib.fib_Size;
						verbose("filexpk: '%s' packed=%ld unpacked=%lu",name,fib.fib_Size,size);
						if (! putline(fhdec,name)) goto failed;
						break;
					case 2:	// error
						goto failed;
				}
			}
		}
		if (IoErr() != ERROR_NO_MORE_ENTRIES) {
			doserr("exnext",dir);
		} else {
			rc = 1;
		}
	}
	
	failed:		// on error inside ExNext loop

	// return to old directory and unlock
	CurrentDir(o);
	UnLock(l);

	// free tmpdir
	if (tmpdir) UnLock(tmpdir);

	return rc;
}

/*
 * delete given directory recursively
 * in:
 * 	dir	directory name to delete
 * out:
 *	0=success >0=error
 */
int deleteDir(const STRPTR dirname) {
	int rc;
	char cmd[256];
	snprintf(cmd,sizeof(cmd),"Delete \"%s\" Quiet Force All", dirname);
	rc = SystemTagList(cmd, NULL);
	if (rc != RETURN_OK) {
		error("deleting directory failed: '%s'", cmd);
	}
	return rc;
}

/*
 * delete given directory recursively only if NoDelete/S is not set
 * in:
 * 	dir	directory name to delete
 * out:
 *	0=success >0=error
 */
int deleteDirOpt(const STRPTR dirname) {
	if (opts[OPT_NODELETE]) {
		return RETURN_OK;
	} else {
		return deleteDir(dirname);
	}
}

/*
 * print and execute given command
 * in:
 * 	cmd	command to execute
 * out:
 *	return code of command
 */
int system(const STRPTR cmd) {
	info("executing '%s'", cmd);
	return SystemTagList(cmd, NULL);
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
int archiveDir(const STRPTR dirname) {
	int rc = RETURN_ERROR;
	BPTR dir, old, arc;
	char arcname[256];
	char listunc[] = "T:warc.list.unc";
	char listdec[] = "T:warc.list.dec";
	struct FileInfoBlock fib;
	char cmd[256];
	int len;

	// make sure the given directory is located in the current dir
	if (FilePart(dirname) != dirname) {
		error("archiveDir: '%s' must be directory in the current dir",dirname);
		return rc;
	}

	// open the directory
	dir = Lock(dirname,SHARED_LOCK);
	if (!dir) {
		doserr("lock",dirname);
		return rc;
	}

	// build archive name
	snprintf(arcname,sizeof(arcname),"%s%s",dirname,extlha);

	// check if archive already exists
	arc = Open(arcname,MODE_OLDFILE);
	if (arc) {
		error("archive '%s' already exists", arcname);
		Close(arc);
	} else {
		// open filelist for uncompressed files
		fhunc = Open(listunc,MODE_NEWFILE);
		if (!fhunc) {
			doserr("open",listunc);
		} else {
			// put homedir for lha into the file
			FPuts(fhunc,dirname); FPutC(fhunc,'/'); FPutC(fhunc,'\n');
			// open filelist for decompressed files
			fhdec = Open(listdec,MODE_NEWFILE);
			if (!fhdec) {
				doserr("open",listdec);
			} else {
				// put homedir for lha into the file
				FPuts(fhdec,(char*)opts[OPT_TMPDIR]); FPutC(fhdec,'/'); FPutC(fhdec,'\n');

				// change to the directory
				old = CurrentDir(dir);

				// iterate over all entries in the actual directory
				cntdir = cntfile = cntxpk = cntsz = cntszxpk = 0;	// counters
				if (scan(NULL,NULL)) {
					info("scanned '%s': dirs=%d files=%d size=%d xpkfiles=%d xpksaved=%d",
						dirname,cntdir,cntfile,cntsz,cntxpk,cntszxpk);
					rc = RETURN_OK;
				} else {
					error("scanning failed!");
				}

				// return directory
				CurrentDir(old);

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
	if (rc != RETURN_OK) return rc;

	// create archive
	len = snprintf(cmd,sizeof(cmd),"%s %s @%s",defcmdlha,arcname,listunc);
	if (cntxpk) {
		snprintf(cmd+len,sizeof(cmd)-len," @%s",listdec);
	}
	rc = system(cmd);
	if (rc != RETURN_OK) {
		error("archiving '%s' failed", arcname);
		return rc;
	}

	// delete filelists
	DeleteFile(listdec);
	DeleteFile(listunc);

	// get archive size for statistics
	arc = Open(arcname,MODE_OLDFILE);
	if (! arc) {
		doserr("open",arcname);
		return RETURN_ERROR;
	}
	Seek(arc,0,OFFSET_END);
	len = Seek(arc,0,OFFSET_BEGINNING);
	Close(arc);
	cntszarc = cntsz - len;
	info("archive '%s' saved %d bytes",arcname,cntszarc);

	// delete unpacked XPK files
	if (cntxpk) {
		rc = deleteDir((char*)opts[OPT_TMPDIR]);
	}

	return rc;
}

/*
 * standard clib
 */
int strcasecmp(const char *s1, const char *s2) {
	int offset,ch;
	unsigned char a,b;

	offset = 0;
	ch = 0;
	while( *(s1+offset) != 0 ) {
		/* check for end of s2 */
		if ( *(s2+offset)==0) return( *(s1+offset) );
		a = (unsigned)*(s1+offset);
		b = (unsigned)*(s2+offset);
		ch = toupper(a) - toupper(b);
		if ( ch<0 || ch>0 ) return(ch);
		offset++;
	}
	return(ch);
}

/*
 * unarchive file from the actual directory
 * 	arcname	name of archive to extract
 * out:
 *	RETURN_OK, RETURN_ERROR
 */
int unarchive(const STRPTR arcname) {
	info("unarchiving '%s'", arcname);
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
	char data[256];
	strncpy(data, arcname, baselen);
	data[baselen] = 0;
	BPTR dir = CreateDir(data);
	if (! dir) {
		doserr("create dir", data);
		return RETURN_ERROR;
	}
	// lock from CreateDir is an exclusive lock, SystemTagList cannot dup it
	if (! ChangeMode(CHANGE_LOCK, dir, ACCESS_READ)) {
		doserr("change mode lock", data);
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
		deleteDir(data);
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

/*
 * analyse given icon
 * if DefaultTool is WHDLoad search ToolTypes
 * if ToolType Data is found perform Un/Archive for all data directories not already processed
 * else load Slave and check for slv_CurrentDir, perform Archive if exists
 * processed data directories are remembered in datalist
 * update/add icons Data ToolType if something has changed
 * in:
 * 	name	name of icon to check, must be located in the actual directory!
 * 	list	list of already processed data directories
 * out:
 *	RETURN_OK, RETURN_ERROR
 */
int processIcon(const STRPTR name, struct MinList *list) {
	verbose("processIcon: '%s'", name);
	error("processIcon: not implemented");
	return RETURN_ERROR;
}

/*
 * scan given directory recursively for .info files
 * process (un/archive) all found WHDLoad data directories
 * in:
 * 	dirname	name of directory to scan
 * out:
 *	RETURN_OK, RETURN_ERROR
 */
int scanDir(const STRPTR dirname) {
	verbose("scanDir: '%s'", dirname);
	error("scanDir: not implemented");
	return RETURN_ERROR;
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
				if (! Examine(lock,&fib)) {
					doserr("examine",src);
					UnLock(lock);
				} else {
					// enter parent directory of Src required for file and archiveDir modes
					BPTR parent = ParentDir(lock);
					BPTR olddir = CurrentDir(parent);
					// free the lock because the object may get deleted on success
					UnLock(lock);
					// check for dir/file
					if (fib.fib_DirEntryType >= 0) {
						// directory
						// scan or archive
						if (opts[OPT_SCAN]) {
							// may not relative to current dir!
							CurrentDir(olddir);
							rc = scanDir(src);
						} else {
							rc = archiveDir(fib.fib_FileName);
							if (rc == RETURN_OK) rc = deleteDirOpt(fib.fib_FileName);
						}
					} else {
						// file
						if (cmpExtArc(fib.fib_FileName)) {
							rc = unarchive(fib.fib_FileName);
							if (rc == RETURN_OK) {
								if (! DeleteFile(fib.fib_FileName)) {
									doserr("delete", fib.fib_FileName);
									rc = RETURN_WARN;
								}
							}
						} else if (cmpExt(fib.fib_FileName, extinfo)) {
							struct MinList list;
							NewList(&list);
							rc = processIcon(fib.fib_FileName, &list);
							struct MinNode *node;
							for ( node = list.mlh_Head ; node->mln_Succ != NULL ; node = node->mln_Succ )
								FreeVec(node);
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
	if (XpkBase) { CloseLibrary(XpkBase); }
	return rc;
}

