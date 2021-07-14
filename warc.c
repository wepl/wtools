/*
 *  transform WHDLoad data directories into VFS-archives
 *  decompress XPK packed files and call lha/zip to create archive
 *
 * 2021-01-20 started
 * 2021-07-14 lha working without XPK files
 *
 */

#include <stdio.h>

#include <dos/dos.h>
#include <proto/dos.h>
#include <proto/exec.h>

#define TEMPLATE "Dir/A,Remove/S"
#define OPT_DIR		0
#define OPT_REMOVE	1
#define OPT_COUNT	2

LONG opts[OPT_COUNT];
STRPTR ext = "lha";
const char * defcmdlha = "lha -eFrZ3 -Qw a";	// default pack command for lha archives
const char * deftmppath = "T:warc.tmp";	// default path to store decompressed files
BPTR fhunc, fhdec;			// fhs for temporary list files
int cntdir, cntfile, cntxpk;		// counters directories, files, xpk-files
int cntsz, cntszxpk, cntszarc;		// size of all files uncompressed, size saved by xpk, saved by archive

/*
 * check if file is encrypted/compressed using XPK
 * checks if the file is completely compressed to avoid false
 * detections on disk images for example
 * Warning: file may be encrypted/compressed multiple times!
 * returns: 0=not-compressed 1=compresed 2=error
 */
int checkxpk(const char *name, ULONG size) {
	ULONG buf[4];
	BPTR fh;
	// check for min filesize
	if (size <= sizeof(buf)) return 0;
	// read XPK header
	fh = Open(name,MODE_OLDFILE);
	if (!fh) {
		PrintFault(IoErr(),name);
		return 2;
	}
	if (sizeof(buf) != Read(fh,buf,sizeof(buf))) {
		PrintFault(IoErr(),name);
		Close(fh);
		return 2;
	}
	Close(fh);
	if (buf[0] == 'X'<<24|'P'<<16|'K'<<8|'F' && buf[1] == size-8) {
		// printf("xpk: %s packed=%lu unpacked=%lu\n",name,size,buf[3]);
		return 1;
	}
	return 0;
}

/*
 * decrypt/uncompress a file using XPK
 * to support multiple times compressed files first uncompress to 
 * memory and write it to temporary directory at the end
 * as last step copy meta data (flags, comment)
 * returns: 0=error 1=success
 */
int unpackxpk(const char *path, const char *name, ULONG *size) {
	ULONG buf[4];
	BPTR fh;
	fh = Open(name,MODE_OLDFILE);
	if (!fh) {
		PrintFault(IoErr(),name);
		return 0;
	}
	if (sizeof(buf) != Read(fh,buf,sizeof(buf))) {
		PrintFault(IoErr(),name);
		Close(fh);
		return 0;
	}
	Close(fh);
	*size = buf[3];

	printf("xpkunpack failed: %s %s %lu\n",path,name,*size);
	return 0;
}

/*
 * recursive function to scan a directory
 * XPK files are decompressed
 * file names are written to fhunc/fhdec
 * returns: 0=error 1=success
 */
int scan(const char *path, const char *dir) {
	BPTR l, o;
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
		PrintFault(IoErr(),dir);
		return rc;
	}
	o = CurrentDir(l);

	// scan directory
	if (! Examine(l,&fib)) {
		PrintFault(IoErr(),dir);
	} else {
		while (ExNext(l,&fib)) {
			snprintf(name,sizeof(name),newpath);
			AddPart(name,fib.fib_FileName,sizeof(name));
			if (fib.fib_DirEntryType >= 0) {
				// directory
				cntdir++;
				printf("dir: %s\n",name);
				if (! scan(newpath,fib.fib_FileName)) goto failed;
			} else {
				// file
				cntfile++;
				// check if file is XPK-compressed
				switch (checkxpk(fib.fib_FileName,fib.fib_Size)) {
					case 0:	// uncompressed
						cntsz += fib.fib_Size;
						printf("file: %s size=%ld\n",name,fib.fib_Size);
						FPuts(fhunc,name); FPutC(fhunc,'\n');
						break;
					case 1:	// compressed
						cntxpk++;
						if (! unpackxpk(newpath,fib.fib_FileName,&size)) goto failed;
						cntsz += size;
						cntszxpk += size - fib.fib_Size;
						printf("filexpk: %s packed=%ld unpacked=%lu\n",name,fib.fib_Size,size);
						FPuts(fhdec,name); FPutC(fhdec,'\n');
						break;
					case 2:	// error
						goto failed;
				}
			}
		}
		if (IoErr() != ERROR_NO_MORE_ENTRIES) {
			PrintFault(IoErr(),dir);
		} else {
			rc = 1;
		}
	}
	
	failed:		// on error inside ExNext loop

	// return to old directory and unlock
	CurrentDir(o);
	UnLock(l);
	return rc;
}

/*
 * create archive from the given directory
 * the directory must be located in the actual directory!
 * - scan the directory and decompress all xpk files
 *   lha: save to separate path 'deftmppath'
 *   zip: overwrite original files
 *   preserve file meta data
 * - zip or if there were no xpk files just archive the directory using lha/zip
 * - if there were xpk files:
 *   lha: create archive via filelist from actual directory and 'deftmppath'
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
		PrintFault(IoErr(),dirname);
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
			PrintFault(IoErr(),listunc);
		} else {
			// put homedir for lha into the file
			FPuts(fhunc,dirname); FPutC(fhunc,'/'); FPutC(fhunc,'\n');
			// open filelist for decompressed files
			fhdec = Open(listdec,MODE_NEWFILE);
			if (!fhdec) {
				PrintFault(IoErr(),listdec);
			} else {
				// put homedir for lha into the file
				FPuts(fhdec,deftmppath); FPutC(fhdec,'/'); FPutC(fhdec,'\n');

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
		PrintFault(IoErr(),arcname);
		return RETURN_ERROR;
	}
	Seek(arc,0,OFFSET_END);
	len = Seek(arc,0,OFFSET_BEGINNING);
	Close(arc);
	cntszarc = cntsz - len;
	printf("archive '%s' saved %d bytes\n",arcname,cntszarc);

	// delete unpacked XPK files
	if (cntxpk) {
		snprintf(cmd,sizeof(cmd),"Delete '%s' Quiet Force All",deftmppath);
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

	rdargs = ReadArgs(TEMPLATE, opts, NULL);
	if (rdargs == NULL) {
		PrintFault(IoErr(),NULL);
	} else {
		rc = packDir((STRPTR) opts[OPT_DIR]);
		FreeArgs(rdargs);
	}
	return rc;
}

