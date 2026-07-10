; src/external/format/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; App-private constants for format, not covered by the shared
; include/ca65/command64.inc (resolved via add_ca65_app's -I include/ca65).
; format.s .include's this file directly.

; ---------------------------------------------------------------------------
; Zero-page scratch ($70-$8F -- documented safe area for external programs)
; ---------------------------------------------------------------------------
BufPtrLo = $70          ; readLine: destination buffer pointer low byte
BufPtrHi = $71          ; readLine: destination buffer pointer high byte
MaxLen   = $72           ; readLine: max chars to accept (buffer is MaxLen+1)

; ---------------------------------------------------------------------------
; Disk-name / ID limits (CBM DOS convention, see wiki/tasks/format.md)
; ---------------------------------------------------------------------------
NAME_MAX_LEN = 16
ID_LEN       = 2
DEV_MIN      = 8
DEV_MAX      = 11
