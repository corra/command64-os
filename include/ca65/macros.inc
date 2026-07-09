; include/ca65/macros.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; ca65 port of src/command64/petsci.asm's petPrintChar macro.
;
; Note: petPrintChar is the ONLY .macro in the entire Kick codebase
; (src/command64/petsci.asm:12), and it is never called anywhere — verified
; by grep, it's dead code. It's ported here purely for parity/completeness,
; not because anything currently needs it. petPrintString (also in
; petsci.asm) is a plain subroutine, not a macro, and is out of scope for
; this file — external apps never call it at assemble time; they reach OS
; functionality at runtime via "jsr OS_API" (see command64.inc) with a
; DOS_* selector in .A.

.MACRO petPrintChar
        jsr     KernalChROUT
.ENDMACRO

; --- Version banner convention ---
; Kick apps build their version banner with string concatenation:
;   .text "NAME v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
;   .text "." + BUILD_NUMBER
; ca65 has no "+"-on-strings operator, but none is needed: once BUILD_NUMBER
; arrives as a ".define BUILD_NUMBER \"42\""-style text-substitution token
; (generated per-build by the CMake layer, same as Kick's build_<name>.inc),
; a plain comma-separated .byte list assembles the same banner directly:
;
;   .byte   "NAME v", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE
;   .byte   ".", BUILD_NUMBER, PetCr, 0
;
; No .CONCAT()/.SPRINTF() required for this case — those pseudo-functions
; only matter if the banner needs to be built as a reusable named symbol at
; assemble time rather than emitted directly as data.
