/*
	$Id: wcmp.c 1.4 2017/10/09 01:58:15 wepl Exp wepl $

	a little, simple, quick cmp program
	advantages against the thousend other cmp's out there:
		- command line only
		- wide output hex And ascii (this was the reason for writing)
		- does not need to load whole file at once
		- std c, should be eatable by every compiler

	released under GNU Public License
	wepl, sometime ago ...

	vbcc:bin/vc -c99 -sc -O2 -Ivbcc:PosixLib/include -Lvbcc:PosixLib/AmigaOS3 -lposix -o wcmp wcmp.c
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>	/* getopt */

#define buflen 32768/2
#define maxpl 16	/* displayed diffs per line */

int opt_a=127;	/* display all latin1 chars, not only ascii */
int opt_c=0;	/* combine different chunks by these equal chars */
int opt_q=0;	/* quick, don't show the differences */
int opt_w=0;	/* output a WHDLoad patch list */

/**********************/

void cmpout(const unsigned char *c1, const unsigned char *c2, int p1, int p2, int len) {
  int j;
  const unsigned char *t;

  if (opt_q) return;
  if (opt_w) {	/* WHDLoad patch list */
    printf("\t\tPL_STR\t$%x,<",p1);		/* file1 offset */
    for (t=c2,j=0;j<len;j++,t++) putchar(*t < ' ' ? '*' : *t);
    putchar('>');
    for (j=0;j<=((p1>0xffff?0:1)+6+maxpl-len);j+=8) putchar('\t');
    putchar(';');
    for (j=0;j<len;j++,c1++) putchar(*c1 < ' ' ? '*' : *c1);
    putchar(' ');
    for (t=c2,j=0;j<len;j++) printf("%02x",*t++);
    putchar('\n');
  } else {	/* normal differences output */
    printf("%06x ",p1);				/* file1 offset */
    for (t=c1,j=0;j<len;j++) printf("%02x",*t++);
    for (j=0;j<=2*(maxpl-len);j++) putchar(' ');
    for (j=0;j<len;j++,c1++) putchar(*c1 < ' ' || *c1 > opt_a ? '.' : *c1);
    for (j=0;j<=maxpl-len;j++) putchar(' ');
    if  (p1 != p2) printf("%06x ",p2);		/* file2 offset */
    for (t=c2,j=0;j<len;j++) printf("%02x",*t++);
    for (j=0;j<=2*(maxpl-len);j++) putchar(' ');
    for (j=0;j<len;j++,c2++) putchar(*c2 < ' ' || *c2 > opt_a ? '.' : *c2);
    putchar('\n');
  }
}

/**********************/

int cmp(char *m1, char *m2, int o1, int o2, int len) {
  int i, diffs=0;
  unsigned char t1[maxpl+1]="", t2[maxpl+1]="";
  int dc=0;	/* count of different bytes in buff */
  int ds=0;	/* filepos of first stored byte in buff */
  
  for (i=0;i<len;i++) {
    if (*m1++ != *m2++) {
      /* output if the new cannot appended */
      if ( dc > 0 && ds+dc != i) {
	/* check if equal gap is smaller than requested chunk combination */
	if (i-ds-dc > opt_c) {
	  /* gap is larger so print out the buffer */
	  cmpout(t1,t2,o1+ds,o2+ds,dc);
	  dc = 0;
	} else {
	  /* gap is smaller, append the gap */
	  while (ds+dc < i) {
	    /* output if buff full */
	    if (dc == maxpl) {
	      cmpout(t1,t2,o1+ds,o2+ds,dc);
	      ds += dc;
	      dc = 0;
	    }
            /* append */
	    t1[dc] = t2[dc] = *(m1-1-i+ds+dc); dc++;
	  }
	}
      }
      /* output if buff full */
      if (dc == maxpl) {
        cmpout(t1,t2,o1+ds,o2+ds,dc);
        dc = 0;
      }
      /* append */
      if (dc == 0) ds = i;
      t1[dc]   = *(m1-1);
      t2[dc++] = *(m2-1);
      diffs++;
    }
  }
    
  /* output if bytes left in buff */
  if (dc > 0 )
    cmpout(t1,t2,o1+ds,o2+ds,dc);
  return diffs;
}

/**********************/

void usage(const char *s) {
  fprintf(stderr,
	"wcmp 0.3 (%s)\n"
	"usage: %s [-aqw] [-c count] file file\n"
	" -a display all latin1 chars, not only ascii\n"
	" -c combine different chunks by these count equal chars\n"
	" -q quick, don't show the differences\n"
	" -w output differences as WHDLoad patch list\n"
	,__DATE__,s);
  exit(20);
}

/**********************/

void error(const char *s) {
  perror(s);
  exit(20);
}

/**********************/

long getfilesize(FILE *fp, const char *name) {
  long pos;
  fseek(fp,0,SEEK_END);
  pos = ftell(fp);
  if (fseek(fp,0,SEEK_SET)) error(name);
  return pos;
}

/**********************/

int main(int argc, char *argv[]) {
  FILE *fp1,*fp2;
  int len1, len2, pos1=0, pos2=0;
  static char b1[buflen], b2[buflen]; /* Amiga !!! */
  int c, l, diffs=0,i;
  
  while ((c = getopt(argc, argv, "ac:hq?w")) != -1) {
    switch (c) {
    case 'a':
      opt_a = 255;
      break;
    case 'c':
      opt_c = atoi(optarg);
      break;
    case 'q':
      opt_q = 1;
      break;
    case 'w':
      opt_w = 1;
      break;
    default:
      usage(argv[0]);
    }
  }
  argc -= optind;
  if (argc != 2) usage(argv[0]);
  argv += optind;

  if (NULL == (fp1 = fopen(argv[0],"r"))) error(argv[0]);
  if (NULL == (fp2 = fopen(argv[1],"r"))) error(argv[1]);
  len1 = getfilesize(fp1,argv[0]);
  len2 = getfilesize(fp2,argv[1]);
  
  if (!opt_q && !opt_w) {
    printf("       %s ",argv[0]);
    for (i=strlen(argv[0]);i<49;i++) putchar(' ');
    printf("%s\n",argv[1]);
  }

  l = buflen;
  while (pos1!=len1 && pos2!=len2) {
    if (len1-pos1 < l) l = len1-pos1;
    if (len2-pos2 < l) l = len2-pos2;
    if (1 != fread(b1, l, 1, fp1)) error(argv[0]);
    if (1 != fread(b2, l, 1, fp2)) error(argv[1]);
    diffs += cmp (b1, b2, pos1, pos2, l);
    pos1 += l; pos2 += l;
  }
  
  printf(diffs == 0 ? "files are equal\n" : "files have %d different bytes\n",diffs);
  if (len1 != len2) printf("file '%s' is %d bytes %s than file '%s'\n",
    argv[0],abs(len1-len2),len1>len2?"larger":"shorter",argv[1]);
  
  if (diffs == 0) return 0; else return 5;
}

