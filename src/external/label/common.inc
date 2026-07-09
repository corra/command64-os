; src/external/label/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; App-private constants for label, not covered by the shared
; include/ca65/command64.inc (all KERNAL entry points and OS API
; constants now come from there, resolved via add_ca65_app's
; -I include/ca65). label.s .include's this file directly.

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
