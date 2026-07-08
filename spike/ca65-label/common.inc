; spike/ca65-label/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Shared constants/equates for the ca65 port of the label spike. Unlike
; the conway spike, this app is single-file, but the constants still live
; in their own .inc to keep label.s focused on logic (mirrors how
; include/command64.inc separates OS API constants from app code).

; ---------------------------------------------------------------------------
; KERNAL entry points (see include/command64.inc)
; ---------------------------------------------------------------------------
KernalChROUT = $FFD2
KernalGetIn  = $FFE4
KernalChRIN  = $FFCF
KernalSETLFS = $FFBA
KernalSETNAM = $FFBD
KernalOPEN   = $FFC0
KernalCLOSE  = $FFC3
KernalREADST = $FFB7
KernalCHKIN  = $FFC6
KernalCHKOUT = $FFC9
KernalCLRCHN = $FFCC

; ---------------------------------------------------------------------------
; Command64 OS API (fixed addresses — this OS's own jump table, not KERNAL)
; ---------------------------------------------------------------------------
DOS_PRINT_STR    = $09  ; petPrintString function selector for jsr $1000
DOS_PARSE_PREFIX = $57  ; parse target device prefix from ZP pointer

PetCr  = $0D
PetDel = $14

PrintPtrLo = $FB
PrintPtrHi = $FC

ParsePos      = $63
CommandBuffer = $033C
CurrentDevice = $039E

; ---------------------------------------------------------------------------
; Zero-page scratch ($70/$71 -- documented safe area for external programs)
; ---------------------------------------------------------------------------
ArgIdx      = $70
SavedDevice = $71

; ---------------------------------------------------------------------------
; Drive protocol constants
; ---------------------------------------------------------------------------
CMD_CHANNEL  = 15
DATA_CHANNEL = 2
VOL_NAME_LEN = 16
