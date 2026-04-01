# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of Amiga utility programs mostly related to WHDLoad. Programs are written in 68000 Assembly or C targeting AmigaOS. Cross-compilation on Linux/macOS is supported via VASM and vbcc.

## Build Commands

```sh
# Build all programs (uses vasm on Linux/macOS, basm on Amiga)
make

# Build a single program
make DIC

# Build with debug mode (uses basm + vamos on Linux)
make DEBUG=1

# Build optimized (default on Linux)
make DEBUG=0

# Run tests (VSNPrintF 64-bit format specifiers)
make test

# Clean all build artifacts
make clean
```

**Linux prerequisites:** Set `INCLUDEOS3` to point to AmigaOS cross-compilation headers. Install `vasmm68k_mot`, `vc` (vbcc), `m68k-amigaos-gcc`, and `vamos`.

## File Encoding — CRITICAL

Source files in `sources/` are **Latin-1 (ISO-8859)** encoded, NOT UTF-8. The Edit and Write tools corrupt non-ASCII bytes (e.g. `0xB9` = superscript `¹`).

**Always use `sed` or `perl` via Bash to edit these files:**
```sh
LC_ALL=C sed -i 's/old/new/g' sources/somefile.i
```
Always prefix with `LC_ALL=C` to prevent re-encoding of `0xB9` bytes.

If encoding was corrupted, fix with:
```sh
perl -pi -e 's/\xef\xbf\xbd/\xb9/g' sources/file.i
```

Check encoding with: `file sources/filename`

The Edit/Write tools are safe for `.asm`, `.c`, `.h` files in the project root.

## Code Architecture

### Directory Layout

- `*.asm` / `*.c` — individual utility programs (one file per program)
- `sources/*.i` — shared 68000 assembler macro libraries (included by all `.asm` programs)
- `includes/` — AmigaOS headers and LVO tables; `INCLUDEOS3` points here for cross-compilation
- `test/` — unit tests for shared macros (run via `make test` + vamos)

### Shared Macro Libraries (`sources/`)

Each `.asm` program includes macros from `sources/` rather than reimplementing common functionality:

- **`dosio.i`** — DOS I/O: `_Print`, `_PrintArgs`, `_VFPrintf`, `_CheckBreak`
- **`strings.i`** — String processing: `_VSNPrintF` (supports `%lld`/`%llu`/`%llx` 64-bit), `_atoi`, `_etoi`, `_StrLen`
- **`files.i`** — File operations
- **`devices.i`** — Device abstractions
- **`error.i`** — Error handling: `_PrintErrorDOS`
- **`hardware.i`** — Amiga custom chip register definitions

### Assembly Program Structure

Each `.asm` file is standalone and follows this pattern:
1. Header with metadata and revision history
2. LVO includes for exec/dos library calls
3. Global/local variable structures
4. Version string with embedded `.date` (generated at build time)
5. Main entry point + subroutines
6. `INCLUDE` of shared macros from `sources/`

### Build System Details

The Makefile selects assembler based on `DEBUG`:
- `DEBUG=0` (default on Linux): `vasmm68k_mot` with full optimizations (`-opt-allbra`, `-opt-clr`, etc.)
- `DEBUG=1` (default on Amiga): `basm` via `vamos` emulator with debug symbols

C programs use `vc` (vbcc) except `wcmp` which requires `m68k-amigaos-gcc` for POSIX `getopt`/`unistd.h`.

Date embedding: each build generates `.date` (for ASM `INCLUDE`) and `.date.h` (for C `#include`) at the start of each program's build rule.

## 68000 Pitfalls

- Indexed addressing `(d8,An,Xn.w)`: the **full word** of the index register matters
- `move.b` + `and.b` only clear the low byte — use `and.w` to clear the upper byte
  - Example: `move.b d4,d0` then `and.w #15,d0` before `move.b (0,a3,d0.w),(a4)+`
