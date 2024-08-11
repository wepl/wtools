/*
 *  transform WHDLoad data directories into VFS-archives
 *  decompress XPK packed files and call lha/zip to create archive
 *
 * 2021-01-20 started
 * 2021-07-14 lha working without XPK files
 * 2021-10-31 XPK decompression added
 *
 */

#include <stdio.h>

#include <dos/dos.h>
#include <xpk/xpk.h>
#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/xpkmaster.h>

#define TEMPLATE "Src/A,Remove/S,TmpDir,Verbose/S"
#define OPT_SRC		0
#define OPT_REMOVE	1
#define OPT_TMPDIR	2
#define OPT_VERBOSE	3
#define OPT_COUNT	4

LONG opts[OPT_COUNT];
STRPTR ext = "lha";
const char * defcmdlha = "lha -eFrZ3 -Qw a";	// default pack command for lha archives
const char * deftmpdir = "T:warc.tmp";	// default directory to store decompressed files
BPTR fhunc, fhdec;			// fhs for temporary list files
int cntdir, cntfile, cntxpk;		// counters directories, files, xpk-files
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
 * print verbose message
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
	}
}

/*
 * check if file is encrypted/compressed using XPK
 * checks if the file is completely compressed to avoid false
 * detections on disk images for example
 * Warning: file may be encrypted/compressed multiple times!
 * returns: 0=not-compressed 1=compresed 2=error
 */
int checkxpk(const char *name, ULONG size) {
	ULONG buf[32];
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
		verbose("checkxpk: %s packed=%lu unpacked=%lu\n",name,size,buf[3]);
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
 * returns: 0=error 1=success
 */
int unpackxpk(BPTR tmpdir, struct FileInfoBlock *fib, ULONG *outlen) {
	ULONG *in, *out;
	ULONG outbuflen, inbuflen;
	const char xpkname[] = XPKNAME;
	int xpkver = 5;
	LONG err;
	char errhead[] = "XPK-unpack failed";
	BPTR fh, olddir;
	
	// open the XPK library
	if (!XpkBase) {
		XpkBase = OpenLibrary (xpkname, xpkver);
		if (!XpkBase) {
			printf("cannot open %s version %d\n", xpkname, xpkver);
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
	fh = Open(fib->fib_FileName,MODE_NEWFILE);
	if (!fh) {
		doserr("open to write",fib->fib_FileName);
	} else {
		if (*outlen != Write(fh,out,*outlen)) {
			doserr("write",fib->fib_FileName);
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
 * in:
 * 	path	path
 * returns: 0=error 1=success
 */
int createdirparent(const char *path) {
	char * part, save;
	BPTR lock;

	part = PathPart(path);
	if (!part || part == path) {
		doserr("pathpart",path);		// to get at least a message
		return 0;
	}
	save = *part;
	*part = 0;
	if (! (lock = CreateDir(path))) {
		if (IoErr() != ERROR_DIR_NOT_FOUND) {
			doserr("create dir",path);
			return 0;
		}
		if (! createdirparent(path)) {
			// error message done by gettmpdirparent
			return 0;
		}
		// try again
		if (! (lock = CreateDir(path))) {
			doserr("create dir",path);
			return 0;
		}
	}
	UnLock(lock);
	*part = save;
	return 1;
}

/*
 * create the temporary sub-directory and return a lock of it
 * if directories above are missing create them also
 * in:
 * 	path	path of the dir to create
 * returns: 0=error lock-to-dir
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
 * recursive function to scan a directory
 * XPK files are decompressed
 * file names are written to fhunc/fhdec
 * in:
 * 	path	path name of the current dir
 * 	dir	directory name in the current dir to scan
 * returns: 0=error 1=success
 */
int scan(const char *path, const char *dir) {
	BPTR l, o, tmpdir=0;
	struct FileInfoBlock fib;
	int rc=0;
	char newpath[256], name[256];
	ULONG size;
	
	// build new path
	snprintf(newpath,sizeof(newpath),path);
	AddPart(newpath,dir,sizeof(newpath));

	// lock & change directory
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
			if (fib.fib_DirEntryType >= 0) {
				// directory
				cntdir++;
				verbose("dir: %s\n",name);
				if (! scan(newpath,fib.fib_FileName)) goto failed;
			} else {
				// file
				cntfile++;
				// check if file is XPK-compressed
				switch (checkxpk(fib.fib_FileName,fib.fib_Size)) {
					case 0:	// uncompressed
						cntsz += fib.fib_Size;
						verbose("file: %s size=%ld\n",name,fib.fib_Size);
						FPuts(fhunc,name); FPutC(fhunc,'\n');
						break;
					case 1:	// compressed
						cntxpk++;
						if (! tmpdir && ! (tmpdir = gettmpdir(newpath))) goto failed;
						if (! unpackxpk(tmpdir,&fib,&size)) goto failed;
						cntsz += size;
						cntszxpk += size - fib.fib_Size;
						verbose("filexpk: %s packed=%ld unpacked=%lu\n",name,fib.fib_Size,size);
						FPuts(fhdec,name); FPutC(fhdec,'\n');
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
 * create archive from the given directory
 * the directory must be located in the actual directory!
 * - scan the directory and decompress all xpk files to 'tmpdir'
 *   preserve file meta data
 * - if there were no xpk files just archive the directory using lha/zip
 * - if there were xpk files:
 *   lha: create archive via filelist from actual directory and 'tmpdir'
 *   zip: create archive via filelist from actual directory and in a
 *        second add all files from 'tmpdir'
 */
int packDir(const STRPTR dirname) {
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
		printf("%s: must be directory in the current dir\n",dirname);
		return rc;
	}

	// open the directory
	dir = Lock(dirname,SHARED_LOCK);
	if (!dir) {
		doserr("lock",dirname);
		return rc;
	}

	// build archive name
	snprintf(arcname,sizeof(arcname),"%s.%s",dirname,ext);

	// check if archive already exists
	arc = Open(arcname,MODE_OLDFILE);
	if (arc) {
		printf("archive '%s' already exists\n",arcname);
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
					printf("scanned '%s': dirs=%d files=%d size=%d xpkfiles=%d xpksaved=%d\n",
						dirname,cntdir,cntfile,cntsz,cntxpk,cntszxpk);
					rc = RETURN_OK;
				} else {
					printf("scanning failed!\n");
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
	printf("executing '%s'\n",cmd);
	rc = SystemTagList(cmd,NULL);
	if (rc != RETURN_OK) {
		printf("archiving '%s' failed\n",arcname);
		return rc;
	}

	// delete filelists
	//DeleteFile(listdec);
	//DeleteFile(listdir);

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
	printf("archive '%s' saved %d bytes\n",arcname,cntszarc);

	// delete unpacked XPK files
	if (cntxpk) {
		snprintf(cmd,sizeof(cmd),"Delete '%s' Quiet Force All",(char*)opts[OPT_TMPDIR]);
		rc = SystemTagList(cmd,NULL);
		if (rc != RETURN_OK) {
			printf("deleting unpacked XPK files failed: '%s'\n",cmd);
			return rc;
		}
	}

	// delete source files if option REMOVE is active

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
		rc = packDir((STRPTR) opts[OPT_SRC]);
		FreeArgs(rdargs);
	}
	if (XpkBase) { CloseLibrary(XpkBase); }
	return rc;
}

