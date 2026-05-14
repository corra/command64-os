// build/command64.asm
// KickAssembler v5.25 - MS-DOS 4.0 shell for C64
//
// Segment layout:
//   Main          $0801  BASIC SYS launcher (BasicUpstart2)
//   Petsci        $1000  PETSCII print routines
//   CommandTable  $1100  Fixed-width command dispatch table
//   CommandShell  $1200  Command loop, dispatcher, built-in handlers

.file [name="command64.prg", segments="Main,Petsci,CommandTable,CommandShell"]

.segmentdef Main [start=$0801]
// Petsci, CommandTable, and CommandShell are defined by the imported source files.

#import "../include/command64.inc"
#import "../src/command64/petsci.asm"
#import "../src/command64/shell.asm"

// BASIC SYS launcher: injects a BASIC line at $0801 that does SYS $1200
// 'start' is the entry-point label defined in shell.asm (CommandShell segment).
.segment Main
BasicUpstart2(start)
