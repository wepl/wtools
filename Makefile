#
# GNU Makefile for wtools
#
# supported platforms:
# Amiga	
#	'setenv AMIGA 1' for system detection
#	assign Includes: must point to system includes
#	requires WDate command, see WHDLoad-dev package Src/programs/WDate
#	basm default, use DEBUG=0 for vasm
# Linux/MacOSX
#	$INCLUDEOS3 must point to system includes
#	vasm default, use DEBUG=1 for basm (requires Vamos)
#
# $@ target
# $< first dependency
# $^ all dependencies
# print all make variables
#$(foreach v,$(.VARIABLES),$(info $(v) = $($(v))))
# print all make variables defined between both statements
#VARS_OLD := $(.VARIABLES)
#$(foreach v,$(filter-out $(VARS_OLD) VARS_OLD,$(.VARIABLES)),$(info $(v) = $($(v))))

BASMOPT=-isources
VASMOPT=-Isources
CC=vc -Iincludes $(CFLAGS) -sc

# different commands for build under Amiga or UNIX
ifdef AMIGA

# basm options: -x+ = use cachefile.library -s1+ = create SAS/D1 debug hunks
BASMOPT+=-x+ -s1+
VASMOPT+=-IIncludes:
CFLAGS=-IIncludes:
CP=Copy Clone
DATE=wdate >.date
DATEH=echo '\#define DATE "'`wdate`'"' >.date.h
MV=Copy
RM=Delete All

# on Amiga default=DEBUG
ifndef DEBUG
DEBUG=1
endif

else

# basm options: -x- = don't use cachefile.library -sa+ = create symbol hunks
BASMOPT+=-x- -sa+
VASMOPT+=-I$(INCLUDEOS3)
CFLAGS=-I$(INCLUDEOS3)
CP=cp -p
DATE=date "+(%d.%m.%Y)" | xargs printf >.date
DATEH=date '+\#define DATE "(%d.%m.%Y)"' >.date.h
MV=mv
RM=rm -fr
VAMOS=vamos -qC68020 -m4096 -s128 --
GCC=m68k-amigaos-gcc -g -Wall -Ilibrary -I. -O2 -noixemul

# on UNIX default=NoDEBUG
ifndef DEBUG
DEBUG=0
endif

endif

ifeq ($(DEBUG),1)

# Debug options
# ASM creates executables, ASMB binary files, ASMO object files
# BASM: -H to show all unused Symbols/Labels, requires -OG-
ASM=$(VAMOS) basm -v+ $(BASMOPT) -O+ -ODc- -ODd- -wo- -dDEBUG=1
ASMB=$(ASM)
ASMO=$(ASM)
ASMDEF=-d
ASMOUT=-o
CFLAGS+=-g
LN=vc -g

else

# Optimize options
# VASM: -wfail -warncomm -databss
ASMBASE=vasmm68k_mot $(VASMOPT) -ignore-mult-inc -nosym -quiet -wfail -opt-allbra -opt-clr -opt-lsl -opt-movem -opt-nmoveq -opt-pea -opt-size -opt-st -depend=make -depfile .depend/$@.dep
ASM=$(ASMBASE) -Fhunkexe
ASMB=$(ASMBASE) -Fbin
ASMO=$(ASMBASE) -Fhunk
ASMDEF=-D
ASMOUT=-o 
CFLAGS+=-O2 -size
LN=vc

endif

# objects and depend files are always created together
%.o: %.s | .depend
	${ASMO} $(ASMOUT)$@ $<

%.o: %.c | .depend
	$(CC) -deps -o $@ -c $<
	$(MV) $*.dep .depend/

ALL = CRC16 DIC FindAccess ITD SaveMem ViewT WArc wcmp
all: $(ALL)

#
# CRC16
#
CRC16: CRC16.asm | .depend
	$(DATE)
	${ASM} $(ASMOUT)$@ $<

#
# DIC
#
DIC: DIC.asm | .depend
	$(DATE)
	${ASM} $(ASMOUT)$@ $<

#
# FindAccess
#
FindAccess: FindAccess.asm | .depend
	$(DATE)
	${ASM} $(ASMOUT)$@ $<

#
# ITD
#
ITD: ITD.asm | .depend
	$(DATE)
	${ASM} $(ASMOUT)$@ $<

#
# WArc
#
WArc: WArc.c
	$(DATEH)
	$(CC) -o $@ $<

#
# wcmp
# use gcc because vbcc has no unistd.h for getopt()
#
wcmp: wcmp.c
	$(GCC) -o $@ $<

#
# SaveMem
#
SaveMem: SaveMem.asm | .depend
	$(DATE)
	${ASM} $(ASMOUT)$@ $<

#
# ViewT
#
ViewT: ViewT.c
	$(CC) -o $@ $<


# how to create additionally listing files
%.list: %.s | .depend
	$(ASM) $(ASMOUT)$(@:.list=.o) -L $@ $<

clean:
	$(RM) *.o *.list .date* .depend $(ALL)

# targets which must always built
.PHONY: all clean unused

.depend:
	@mkdir .depend

include $(wildcard .depend/*)
