// src/command64.asm
// KickAssembler v5.25 - Command 64 OS shell for C64
//
.encoding "petscii_mixed"

// Segment layout:
//   Main          $0801  BASIC SYS launcher (BasicUpstart2)
//   Utils         $0820  Hex parsing and string utilities
//   Api           $0920  INT 21h Service Bus (Jump Table)
//   Loader        $09C0  KERNAL binary loader wrapper
//   Path          $0A60  Directory search and path logic
//   Vmm           $0B00  Virtual Memory Manager (REU mapping)
//   File          $0D00  Handle-based File I/O
//   ApiStub       $1000  Stable OS Entry Point (Jump Table)
//   Petsci        $1040  PETSCII print routines
//   CommandTable  $1080  Fixed-width command dispatch table
//   CommandShell  $1180  Command loop, dispatcher, built-ins
//   VmmData       $1F90  VMM temporary storage

.file [name="command64.prg", segments="Main,Utils,Api,Loader,Path,Vmm,File,ApiStub,Petsci,CommandTable,CommandShell,VmmData"]

.segmentdef Main [start=$0801]
.segmentdef Utils [start=$0820]
.segmentdef Api [start=$09C0]
.segmentdef Loader [start=$0A50]
.segmentdef Path [start=$0AA0]
.segmentdef Vmm [start=$0B30]
.segmentdef File [start=$0CE0]
.segmentdef VmmData [start=$1FA0]

// Petsci, CommandTable, CommandShell, Api, Utils, Loader, Path, Vmm, File, and VmmData are defined by the imported source files.

#import "../include/command64.inc"
#import "command64/petsci.asm"
#import "command64/api.asm"
#import "command64/utils.asm"
#import "command64/loader.asm"
#import "command64/path.asm"
#import "command64/vmm.asm"
#import "command64/file.asm"
#import "command64/shell.asm"


// BASIC SYS launcher: injects a BASIC line at $0801 that does SYS $1200
// 'start' is the entry-point label defined in shell.asm (CommandShell segment).
.segment Main
BasicUpstart2(start)
