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
; Split into two categories (see Phase 2 detail in the implementation
; plan): PERSISTENT state that must survive across command-loop
; iterations, and reusable TRANSIENT command-scratch that any command
; may clobber since the command loop is strictly sequential, never
; re-entrant. New phases should default to reusing a transient field
; over claiming a fresh byte -- the $70-$8F budget is down to 1 free
; byte ($8F) after Phase 2.
;
; --- Persistent state ---
BufBaseSegHi     = $70 ; VMM allocation identity: SegHi (X returned by DOS_ALLOC_MEM)
BufBaseBank      = $71 ; VMM allocation identity: Bank (Y returned by DOS_ALLOC_MEM)
BufEndLo         = $72 ; End-of-text offset from buffer base (EDLIN's ENDTXT)
BufEndHi         = $73
BufIsVmm         = $7B ; 1 = VMM-backed buffer, 0 = base-RAM fallback active
EdCurrentLineLo  = $8D ; Editor's actual current line (EDLIN's CURRENT), 1-based.
EdCurrentLineHi  = $8E ; Only List/Insert/Delete/Quit (never List) update this,
                       ; and only by explicitly copying a findLine result into
                       ; it -- findLine's own CurLine*/CurPtr* output below is
                       ; NOT this; it's transient, see Phase 2 detail.
;
; --- Transient command-scratch (reused freely across commands/phases) ---
CurPtrLo         = $74 ; findLine output: byte offset of the line it found
CurPtrHi         = $75
CurLineLo        = $76 ; findLine output: line number reached (target, or last+1 at EOF)
CurLineHi        = $77
WindowBaseOffLo  = $78 ; VMM offset the scan window was last loaded from
WindowBaseOffHi  = $79
WindowValidLen   = $7A ; Bytes currently valid in the scan window (0 = empty)
TmpLenLo         = $7C ; bufReadWindow/printDec16 scratch
TmpLenHi         = $7D
FindTargetLo     = $7E ; findLine input: target line number (1-based; $FFFF = scan to EOF)
FindTargetHi     = $7F
ScanPtrLo        = $80 ; RAM-fallback scan pointer; also printDec16's working value
ScanPtrHi        = $81
EndPtrLo         = $82 ; RAM-fallback scan end pointer (fallbackBuf + BufEnd)
EndPtrHi         = $83
LineCountLo      = $84 ; displayLines: lines remaining to print
LineCountHi      = $85
PdTableIdx       = $86 ; printDec16 scratch (promoted from Phase 1's temporary debug dump --
PdDigit          = $87 ; the routine itself was never temporary, only that call site was)
Line1Lo          = $88 ; parseRange: line1, stashed while line2 is parsed
Line1Hi          = $89
Line1Given       = $8A ; parseRange: 1 = line1 was present, 0 = defaulted
Line2Given       = $8B ; parseRange: 1 = line2 was present, 0 = defaulted
PageRowCount     = $8C ; displayLines: rows printed since the last Continue (Y/N)? prompt

; --- Buffer sizing ---
BUF_ALLOC_PARAGRAPHS = $0400 ; 1024 paragraphs = exactly 4 VMM pages = 16KB
WINDOW_SIZE           = 128  ; scanWindow / file-load chunk size, bytes
FALLBACK_BUF_SIZE     = 2048 ; base-RAM buffer size when no REU is present

; --- Screen geometry (fixed 40x25, no dynamic IOCTL query) ---
SCREEN_LINES          = 25   ; total rows; List/Page reserve the last one for the prompt
