// src/command64.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
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
//   ApiStub       $1000  Stable OS Entry Point (Jump Table) — fixed: external
//                        apps hardcode `jsr $1000`, must never move.
//   Petsci        packed immediately after ApiStub — no external code
//   CommandTable  packed immediately after Petsci    references these three
//   CommandShell  packed immediately after CommandTable  segments' addresses,
//                        so they float to reclaim the padding that otherwise
//                        went unused between fixed-address segments.
//   VmmData       $1FA0  VMM temporary storage — fixed: FileScratch/
//                        vmmInitialized/vmmTempByte are hardcoded absolute
//                        addresses in command64.inc, must never move.
//   AppTable      $2000  App Table segment (apptable.asm)

.file [name="command64.prg", segments="Main,Utils,Api,Loader,Path,Vmm,File,ApiStub,Petsci,CommandTable,CommandShell,VmmData,AppTable,ShellExt"]

.segmentdef Main [start=$0801]
.segmentdef Utils [start=$0820]
.segmentdef Api [startAfter="Utils"]
.segmentdef Loader [startAfter="Api"]
.segmentdef Path [startAfter="Loader"]
.segmentdef Vmm [startAfter="Path"]
.segmentdef File [startAfter="Vmm"]
.segmentdef Petsci [startAfter="ApiStub"]
.segmentdef CommandTable [startAfter="Petsci"]
.segmentdef CommandShell [startAfter="CommandTable"]
.segmentdef VmmData [start=$1FA0]
.segmentdef AppTable [start=$2000]
.segmentdef ShellExt [startAfter="AppTable"]

// Api, Utils, Loader, Path, Vmm, and File get their segment contents from the
// imported source files; ApiStub keeps its own fixed start=$1000 declared
// inline in api.asm. Petsci/CommandTable/CommandShell chain via startAfter
// so they pack immediately behind one another with no wasted padding.

#import "../include/command64.inc"
#import "command64/petsci.asm"
#import "command64/api.asm"
#import "command64/utils.asm"
#import "command64/loader.asm"
#import "command64/path.asm"
#import "command64/vmm.asm"
#import "command64/file.asm"
#import "command64/apptable.asm"
#import "command64/shell.asm"


// BASIC SYS launcher: injects a BASIC line at $0801 that does SYS $1200
// 'start' is the entry-point label defined in shell.asm (CommandShell segment).
.segment Main
BasicUpstart2(start)
