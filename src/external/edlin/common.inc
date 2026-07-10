; src/external/edlin/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; App-private constants for edlin, not covered by the shared
; include/ca65/command64.inc (all KERNAL entry points and OS API
; constants now come from there, resolved via add_ca65_app's
; -I include/ca65). edlin.s .include's this file directly.
;
; No zero-page allocations yet in the Phase 0 scaffold. Phase 1 will claim
; scratch from the shared $70-$8F app-private range (see
; src/external/AGENTS.md) for VMM buffer tracking and must document its
; allocations here when added.
