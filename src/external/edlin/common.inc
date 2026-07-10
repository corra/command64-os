; src/external/edlin/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; App-private constants for edlin, not covered by the shared
; include/ca65/command64.inc (all KERNAL entry points and OS API
; constants now come from there, resolved via add_ca65_app's
; -I include/ca65). edlin.s .include's this file directly.
;
; Zero-page scratch, claimed from the shared $70-$8F app-private range
; (see src/external/AGENTS.md — uncoordinated across apps, but apps are
; never concurrently resident, so this is safe). Phase 1 (buffer.s):
; brain/plans/2026-07-09-edlin-implementation-phases.md.
;
; $70-$85 are the Phase 1 buffer-core fields. $86/$87 are reused only by
; the Phase 1 temporary debug-dump decimal printer (printDec16 in edlin.s),
; which also borrows $7C/$7D and $80/$81 as scratch since it only ever
; runs after buffer/findLine work for a given call has fully completed —
; safe to alias, not concurrently live. $88-$8F remain free for Phase 3+.
BufBaseSegHi     = $70 ; VMM allocation identity: SegHi (X returned by DOS_ALLOC_MEM)
BufBaseBank      = $71 ; VMM allocation identity: Bank (Y returned by DOS_ALLOC_MEM)
BufEndLo         = $72 ; End-of-text offset from buffer base (EDLIN's ENDTXT)
BufEndHi         = $73
CurPtrLo         = $74 ; Byte offset of current line's start (EDLIN's POINTER)
CurPtrHi         = $75
CurLineLo        = $76 ; Virtual current/reached line number (EDLIN's CURRENT)
CurLineHi        = $77
WindowBaseOffLo  = $78 ; VMM offset the scan window was last loaded from
WindowBaseOffHi  = $79
WindowValidLen   = $7A ; Bytes currently valid in the scan window (0 = empty)
BufIsVmm         = $7B ; 1 = VMM-backed buffer, 0 = base-RAM fallback active
TmpLenLo         = $7C ; bufReadWindow scratch: computed read length
TmpLenHi         = $7D
FindTargetLo     = $7E ; findLine input: target line number (1-based; $FFFF = scan to EOF)
FindTargetHi     = $7F
ScanPtrLo        = $80 ; RAM-fallback scan pointer (findLine/bufLoadFile copy)
ScanPtrHi        = $81
EndPtrLo         = $82 ; RAM-fallback scan end pointer (fallbackBuf + BufEnd)
EndPtrHi         = $83
LineCountLo      = $84 ; reserved for future dedicated line-count callers
LineCountHi      = $85
PdTableIdx       = $86 ; printDec16 (temporary, Phase 1 debug dump only)
PdDigit          = $87

; --- Buffer sizing ---
BUF_ALLOC_PARAGRAPHS = $0400 ; 1024 paragraphs = exactly 4 VMM pages = 16KB
WINDOW_SIZE           = 128  ; scanWindow / file-load chunk size, bytes
FALLBACK_BUF_SIZE     = 2048 ; base-RAM buffer size when no REU is present
