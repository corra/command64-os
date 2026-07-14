; src/external/comp/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; App-private constants for COMP. Zero-page allocations use the external-app
; scratch range documented in src/external/AGENTS.md.

; ---------------------------------------------------------------------------
; Zero-page scratch ($70-$8F -- safe for external programs)
; ---------------------------------------------------------------------------
File1Handle   = $70
File2Handle   = $71
ArgStart      = $72
OffsetLo      = $73
OffsetMid     = $74
OffsetHi      = $75
MismatchCount = $76
Read1Count    = $77
Read2Count    = $78
CompareCount  = $79
IndexSave     = $7A
Byte1Save     = $7B
Byte2Save     = $7C
StopFlag      = $7D
SizeDiffFlag  = $7E
DestIndex     = $7F

; ---------------------------------------------------------------------------
; Parser / compare constants
; ---------------------------------------------------------------------------
FILENAME_MAX   = 39
CHUNK_SIZE     = 64
MAX_MISMATCHES = 10

PARSE_OK        = 0
PARSE_MISSING   = 1
PARSE_EXTRA     = 2
PARSE_OPTION    = 3
PARSE_TOO_LONG  = 4
