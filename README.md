# wtools

A collection of Amiga utility programs created in the context of
[WHDLoad](https://whdload.de). Some of these programs are also part of the
WHDLoad distribution.

All programs are written in 68000 Assembly or C and target AmigaOS.
Cross-compilation on Linux and macOS is supported via VASM and vbcc.

## Programs

### AllocAbs
Allocates memory at a specific absolute address using `exec.AllocAbs`.

### AllocMemReverse
Patches `exec.AllocMem` to always use the `MEM_REVERSE` flag, causing memory
to be allocated from the top of available memory.

### amos2exe
Extracts the Amiga hunk executable embedded in AMOS-compiled programs.

### bin2pic
Converts raw binary image data to IFF picture format. Supports various Amiga
graphics modes including interlaced and Extra Half-Brite (EHB).

### CRC16
Calculates a CRC16 checksum for files, with optional offset and length
parameters.

### DIC (Disk Image Creator)
Reads disk or partition data and creates image files. Supports any disks which
fits into available memory.

### FindAccess
Searches executable files for instructions accessing a given memory address.
Useful for reverse engineering and debugging.

### FreeAbs
Frees memory previously allocated at an absolute address. Complements AllocAbs.

### ITD (Image To Disk)
Writes disk image files back to physical disks or partitions. The reverse
operation of DIC. Requires OS V39+.

### Reloc
Relocates Amiga hunk-format executables to absolute addresses.

### SaveMem
Saves a memory range to a file.

### SP (Save Picture)
Saves IFF pictures from WHDLoad dump files. Includes a copper list
disassembler. Requires a 68020 or higher CPU.

### ViewT (View ToolTypes)
A small CLI program to view and edit Amiga icon ToolTypes without requiring
Workbench. Written in C.

### WArc
Transforms WHDLoad data directories into LHA/ZIP archives and vice versa.
Can decompress XPK-packed files and scan directories for WHDLoad installations.
Written in C.

### WBuild
Increments a build number stored in a file and outputs it to stdout. Used for
build automation.

### WDate
Generates date strings suitable for `$VER` version string assembly directives.
Used in the build process to embed version information.

### wcmp
A compact binary file comparison utility with hex and ASCII output. Supports
WHDLoad patch list output format. Written in C.

