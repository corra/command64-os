// build/command64.asm
// KickAssembler v5.25 - MS-DOS 4.0 shell for C64
//
// Segment layout:
//   Main          $0801  BASIC SYS launcher (BasicUpstart2)
//   Petsci        $1000  PETSCII print routines
//   CommandTable  $1100  Fixed-width command dispatch table
//   CommandShell  $1200  Command loop, dispatcher, built-in handlers
//   Utils         $1600  Hex parsing and string utilities
//   Loader        $1680  KERNAL binary loader wrapper
//   Path          $1700  Directory search and path logic
//   Vmm           $1800  Virtual Memory Manager (REU mapping)
//   VmmData       $1B00  VMM temporary storage

.file [name="command64.prg", segments="Main,Petsci,CommandTable,CommandShell,Utils,Loader,Path,Vmm,VmmData"]

.segmentdef Main [start=$0801]
.segmentdef VmmData [start=$1B00]
// Petsci, CommandTable, CommandShell, Utils, Loader, Path, Vmm, and VmmData are defined by the imported source files.

#import "../include/command64.inc"
#import "../src/command64/petsci.asm"
#import "../src/command64/utils.asm"
#import "../src/command64/loader.asm"
#import "../src/command64/path.asm"
#import "../src/command64/vmm.asm"
#import "../src/command64/shell.asm"


// BASIC SYS launcher: injects a BASIC line at $0801 that does SYS $1200
// 'start' is the entry-point label defined in shell.asm (CommandShell segment).
.segment Main
BasicUpstart2(start)
