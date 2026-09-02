; src/external/casm/cond.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Phase 15 (Conditional Assembly) bounded state: the conditional-nesting
; stack and the Pass-1 branch-decision bitmap.
;
; WP93 (design freeze) owns storage only -- this translation unit emits no
; executable code, calls no OS service, and performs no initialization.
; WP95 adds condResetForPass (called per pass by casm.s, alongside the
; CasmCurrentScope reset) and the push/pop/scan logic; WP96/97 add the
; `.if`/`.elseif`/`.else`/`.endif`/`.ifdef`/`.ifndef` handling that reads
; and writes these fields.
;
; Design: brain/plans/2026-09-01-casm-phase15-wp93-design-freeze.md (D3, D4).

.include "common.inc"

.export CasmCondDepth
.export CasmCondEmitting
.export CasmCondBranchTaken
.export CasmCondSeenElse
.export CasmCondParentEmitting
.export CasmCondOpenLineLo
.export CasmCondOpenLineHi
.export CasmCondOpenColumn
.export CasmCondOpenFileId
.export CasmCondSiteCounterLo
.export CasmCondSiteCounterHi
.export CasmCondDecisionBitmap

.segment "BSS"

CasmCondStateStart:

; Current conditional nesting depth. 0 = no open `.IF` (assembly proceeds
; exactly as pre-Phase-15). 1..CASM_COND_MAX_DEPTH index the per-level
; arrays below (index d-1). Reset to 0 at the start of each pass.
CasmCondDepth: .res 1

; Per-level parallel arrays (index = depth - 1), mirroring source.s's
; frame-stack layout convention.
;
;  CasmCondEmitting        1 = this level's current branch emits; 0 = suppressed.
;  CasmCondBranchTaken     1 = some branch at this level has already been taken,
;                          so every later `.ELSEIF`/`.ELSE` here stays suppressed.
;  CasmCondSeenElse        1 = `.ELSE` already seen at this level -- a following
;                          `.ELSEIF`/`.ELSE` is CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE.
;  CasmCondParentEmitting  snapshot of the enclosing level's emit state at the
;                          `.IF` that opened this level. A level nested inside a
;                          suppressed outer level never emits regardless of its
;                          own condition.
;  CasmCondOpenLineLo/Hi   the opening `.IF`/`.IFDEF`/`.IFNDEF`'s source line and
;  CasmCondOpenColumn      column and
;  CasmCondOpenFileId      packed file id, for CASM_DIAG_UNTERMINATED_CONDITIONAL.
CasmCondEmitting:       .res CASM_COND_MAX_DEPTH
CasmCondBranchTaken:    .res CASM_COND_MAX_DEPTH
CasmCondSeenElse:       .res CASM_COND_MAX_DEPTH
CasmCondParentEmitting: .res CASM_COND_MAX_DEPTH
CasmCondOpenLineLo:     .res CASM_COND_MAX_DEPTH
CasmCondOpenLineHi:     .res CASM_COND_MAX_DEPTH
CasmCondOpenColumn:     .res CASM_COND_MAX_DEPTH
CasmCondOpenFileId:     .res CASM_COND_MAX_DEPTH

; Pass-1 branch-decision record. Each `.IF`/`.ELSEIF`/`.IFDEF`/`.IFNDEF`
; that is *reached while its enclosing level is emitting* bumps
; CasmCondSiteCounter and, in Pass 1, writes its taken/not-taken result
; as one bit here (site N -> byte N>>3, bit N&7). Pass 2 replays bit N for
; the Nth reached site instead of re-evaluating the condition -- the
; `.INCLUDE` catalogLoad -> catalogLookup pattern -- so Pass 1 and Pass 2
; are guaranteed to take identical branches regardless of forward
; references or `.INCLUDE` source-offset ordering. Counter reset to 0 per
; pass; overflow past CASM_COND_MAX_SITES -> CASM_DIAG_CONDITIONAL_SITE_OVERFLOW.
CasmCondSiteCounterLo: .res 1
CasmCondSiteCounterHi: .res 1
CasmCondDecisionBitmap: .res CASM_COND_BITMAP_BYTES

CasmCondStateEnd:

.assert CasmCondEmitting - CasmCondDepth = 1, error, "CASM conditional stack layout changed"
.assert CasmCondOpenFileId - CasmCondEmitting = 7 * CASM_COND_MAX_DEPTH, error, "CASM conditional per-level array layout changed"
.assert CasmCondDecisionBitmap - CasmCondSiteCounterLo = 2, error, "CASM conditional site-counter layout changed"
.assert CasmCondStateEnd - CasmCondStateStart = 1 + 8 * CASM_COND_MAX_DEPTH + 2 + CASM_COND_BITMAP_BYTES, error, "CASM conditional state size changed"
