# DEBUG REU and Address Syntax WP5 Detailed Plan

**Status:** Approved; implementation in progress

**Created:** 2026-08-06

**Parent plan:** `brain/plans/2026-08-03-debug-reu-and-address-syntax.md`

**Work package:** WP5, Unified `XM` Parsing and Preflight

**Implementation target:** `src/external/debug/debug.s`

**Implementation branch:** `feature/debug-reu-address-wp5` (branched from
`debug` after WP4 merged, commit `b81afcf`)

## 1. Purpose

Give `XM` a complete, correct grammar and preflight validation — parsing
the handle, allocation-relative offset (flat or `page:offset`), C64
address, length, and direction, then proving the REU-side and C64-side
transfer windows are in bounds — without performing any DMA. `DOS_VMM_READ`
and `DOS_VMM_WRITE` are not called anywhere in WP5; the chunked transfer
itself is WP6.

## 2. Confirmed Baseline

1. WP4 is merged into `debug` (commit `b81afcf`). `cmdReuMove` still `jmp
   reuStub` (`debug.s:617`). DEBUG build 1123: 7,615 code bytes, 893
   relocation points.
2. `cmdExtended` leaves `Y` at `cmdReuMove`'s first argument position
   (after `XM` and any leading spaces), exactly as it does for
   `cmdReuAlloc`/`cmdReuFree`/`cmdReuStatus`.
3. `parseReuHandle` (active-required mode), `requireEnd`, `skipSpaces`,
   and `parseHexArg` are unchanged and directly reusable. `parseHexArg`
   parses 1-4 hex digits into `HexValLo/Hi`, rejects zero digits and a 5th
   digit, and leaves `Y` at the first non-hex byte.
4. `getReuRecord`/the registry arrays (`reuActive`, `reuSegHi`, `reuBank`,
   `reuParagraphLo`, `reuParagraphHi`) are unchanged. WP5 reads
   `reuParagraphLo/Hi,x` for the selected handle's exact requested
   paragraph capacity — the same field WP3's `printReuAllocSummary` and
   WP4's `printReuStatusOne` already read for display.
5. The `paragraphs == $1000` 17-bit capacity edge case already has a
   proven pattern in `printReuAllocSummary` (`debug.s`, WP3): branch on
   `reuXferParaHi == $10` before doing a 16-bit-only computation. WP5's
   window validation reuses the same branch shape for the analogous
   "capacity is exactly 65536" case (Section 5.2).
6. Second-character case normalization (shifted vs. unshifted PETSCII,
   `and #$7F` after an `A`-`Z` range check) is already established in
   `cmdExtended` (`debug.s`, WP2) for `A`/`D`/`M`/`S`. WP5's direction
   token (`R`/`W`) reuses the identical normalization shape.
7. DEBUG's private zero page `$70-$7F` remains fully occupied; WP5 adds no
   zero-page state. The 8KB `MAIN` envelope has substantial headroom after
   WP4's build (7,615 code bytes; BSS on the order of 200 bytes including
   the WP2 registry, WP3's 3-byte scratch, and WP4's 24-byte
   `sysInfoBuf`).
8. No OS API call is introduced in WP5. `DOS_VMM_READ`/`DOS_VMM_WRITE` stay
   fully unreferenced in `debug.s` until WP6.

## 3. Scope

### 3.1 Included

- Implement `cmdReuMove`'s full grammar: `XM handle offset|page:offset
  address length direction`.
- Add dedicated transfer BSS state for the parsed/normalized fields.
- Implement `parseVmmOffset` for both the flat and `page:offset` forms.
- Parse the C64 address (16-bit hex) and length (16-bit hex, zero
  rejected).
- Parse and normalize the direction token (`R` or `W`, shifted/unshifted).
- Require end-of-input after the direction.
- Implement exact allocation-window validation (`validateReuWindow`),
  correctly handling the `$10000`-byte (`paragraphs == $1000`) capacity
  edge case.
- Implement C64-window validation (`validateC64Window`), rejecting a
  window that would wrap past `$FFFF` without silently continuing at
  `$0000`.
- On full validation success, print a distinct "preflight ok, not yet
  implemented" indicator (temporary — WP6 replaces this with the real
  transfer) so VICE evidence can distinguish "parsed and validated
  correctly" from "reached the unimplemented stub without full
  validation," mirroring WP2's precedent of distinguishable temporary
  stubs.
- Build and inspect DEBUG size/relocation/BSS growth.
- Verify parsing, normalization equivalence, and every boundary rejection
  under VICE, entirely without DMA.

### 3.2 Excluded

- Any call to `DOS_VMM_READ` or `DOS_VMM_WRITE`.
- Chunked transfer, `stageReuTransfer`, `advanceReuTransfer`, progress
  tracking, or partial-failure handling (WP6).
- Any change to `XA`, `XD`, `XS`, `Q`, or `freeAllReu`.
- New private zero-page state.
- DEBUG version/changelog bump for the combined REU+syntax feature
  (deferred to WP7).

## 4. `XM` Grammar

```text
XM handle offset address length R
XM handle offset address length W
XM handle page:offset address length R
XM handle page:offset address length W
```

- `handle`: one DEBUG registry handle, must be active (parsed exactly as
  `XD`'s handle, via `parseReuHandle` with the active-required mode).
- `offset` / `page:offset`: one allocation-relative operand (Section 5).
- `address`: one C64 address, `$0000-$FFFF`, 1-4 hex digits.
- `length`: one nonzero byte count, `$0001-$FFFF`, 1-4 hex digits.
- `direction`: exactly one character, `R` or `W` (shifted or unshifted).
- Trailing input after the direction is rejected.

## 5. `parseVmmOffset`

Contract:

- In: `Y` = the offset operand's first byte.
- Out success: normalized 16-bit flat offset stored in dedicated transfer
  state (`reuMoveOffLo/Hi`, Section 7); `Y` past the complete operand;
  `A=0`; C=0.
- Out failure: `A` = `REU_ERR_PAGE_OFFSET` or `REU_ERR_VALUE_RANGE`
  (Section 8); C=1; `Y` at the failure position.

Algorithm (mirrors the parent plan's Section 6.6 exactly):

1. `jsr parseHexArg` for the first hex component. On C=1, fail with
   `REU_ERR_VALUE_RANGE` (malformed or 5-digit first component).
2. Inspect `inputBuf,y`. If it is not `:`, this is the flat form: copy
   `HexValLo/Hi` directly into `reuMoveOffLo/Hi` and return success — the
   16-bit range is already guaranteed by `parseHexArg`'s 4-digit cap, so
   no extra bound check is needed for the flat form.
3. If it is `:`: `iny`, then `jsr parseHexArg` for the second component.
   On C=1, fail with `REU_ERR_VALUE_RANGE` (covers both `0001:` with
   nothing after the colon, since `parseHexArg` rejects zero digits, and
   `0001:000G`).
4. The first component is now the page number (in `HexValLo/Hi` from step
   1 — stash it in transfer scratch before step 3 overwrites `HexValLo/Hi`
   with the second component). Require `page <= $000F`: reject `page`'s
   stashed value with `REU_ERR_PAGE_OFFSET` if `pageHi <> 0` or `pageLo >
   $0F`.
5. The second component is the within-page offset. Require `offset <=
   $0FFF`: reject with `REU_ERR_PAGE_OFFSET` if `offsetHi > $0F` (a
   4-digit hex value already caps at `$FFFF`, so this single comparison
   is sufficient — `offsetHi > $0F` catches everything above `$0FFF`).
6. Compute `flatOffset = (page << 12) | offset`. Since `page <= $000F` and
   `offset <= $0FFF`, this fits exactly in 16 bits with no overflow:
   shift the stashed page value left 4 bits (into the high nibble of the
   high byte) and OR in the offset's low 12 bits. Store into
   `reuMoveOffLo/Hi`.
7. Return C=0.

Distinguishing cases (parent plan Section 6.6, verified against this
algorithm):

- `0001:` → `parseHexArg` on the second component sees a delimiter/null
  immediately and rejects (zero digits) → `REU_ERR_VALUE_RANGE`.
- `0001:1000` → second component parses to `$1000`, `offsetHi ($10) > $0F`
  → `REU_ERR_PAGE_OFFSET`.
- `0010:0000` → first component `$0010`, `pageLo ($10) > $0F` →
  `REU_ERR_PAGE_OFFSET`.
- `0003:0000` → parses successfully to flat offset `$3000`; whether it
  fits the selected allocation is `validateReuWindow`'s job (Section 6),
  not `parseVmmOffset`'s.

`parseVmmOffset` must not read the registry or call any OS API — it only
produces a normalized 16-bit offset. Capacity is validated later.

## 6. Window Validation

### 6.1 Shared End-Exclusive Arithmetic

Both REU-window and C64-window validation need the same overflow-safe
"base + length" computation, since both `base` and `length` are 16-bit
values whose sum can genuinely need a 17th bit (e.g., `offset=$FFFF,
length=$0001` sums to exactly `$10000`, a valid boundary case per the
parent plan, not an error). Add one shared helper:

```text
computeEndExclusive
In:  A/Y = base Lo/Hi (or a fixed pair of BSS cells), X/? = length Lo/Hi
Out: 16-bit wrapped sum in dedicated scratch, C=1 if the true 17-bit sum
     is >= $10000 (i.e., a carry out of the 16-bit add occurred), C=0
     otherwise.
```

In practice this is implemented inline at both call sites (REU window,
C64 window) as a plain 16-bit add with the carry preserved, rather than a
subroutine — the two callers use different BSS source fields, and the
addition itself is four instructions. Keep the *logic* shared by writing
it once and modeling both validators on the identical shape, but do not
force a subroutine boundary that would need extra parameter-passing
scratch for no real benefit. Document both sites identically so a future
reader can see they are the same proof.

### 6.2 `validateReuWindow`

Contract:

- In: `reuMoveOffLo/Hi` (normalized offset, from `parseVmmOffset`),
  `reuMoveLenLo/Hi` (requested length), `X` = the selected active handle.
- Out success: C=0.
- Out failure: C=1, `A` = `REU_ERR_ALLOC_WINDOW`.

Algorithm:

1. `length != 0` is already guaranteed by the length parser (Section 4;
   `parseHexArg` rejects zero digits, and the grammar requires a nonzero
   length operand — reject explicitly at the parse site, not here, so
   this validator can assume a nonzero length).
2. Compute `endLo/Hi = offset + length` with carry preserved.
3. If no carry: `endLo/Hi` is the true 17-bit-safe end-exclusive value
   and is `< $10000` by construction. Compare it against the allocation's
   exact byte capacity:
   - If `reuParagraphHi,x == $10` (the `$1000`-paragraph, exactly-65536-
     byte case — same test `printReuAllocSummary` already uses): capacity
     is `$10000`, and any `< $10000` end is automatically within it. Pass.
   - Otherwise, compute `capacityLo/Hi = reuParagraphLo/Hi,x << 4` (same
     shift-left-4 loop `printReuAllocSummary` already uses for `SIZE=`,
     safe from overflow here because `paragraphs < $1000` implies
     `paragraphs * 16 < $10000`). Compare `endLo/Hi <= capacityLo/Hi`
     (unsigned 16-bit compare); fail with `REU_ERR_ALLOC_WINDOW` if
     `end > capacity`.
4. If carry set: the true end is `$10000 + endLo/Hi` (post-wrap). This is
   `<= $10000` only when `endLo/Hi == $0000` exactly (i.e., the true sum
   is precisely `$10000`, the one valid boundary value beyond a plain
   16-bit compare). If `endLo/Hi <> $0000`, fail with
   `REU_ERR_ALLOC_WINDOW` (true end `> $10000`, always invalid — no
   allocation can exceed 64KB, parent plan Section 13). If `endLo/Hi ==
   $0000`, the request ends at exactly `$10000`; this is valid only if
   the allocation's capacity is also exactly `$10000`
   (`reuParagraphHi,x == $10`); otherwise fail with
   `REU_ERR_ALLOC_WINDOW`.

This directly implements the parent plan's Section 8.2 rules
(`normalizedOffset <= $FFFF` is already guaranteed by `parseVmmOffset`'s
16-bit storage; `endExclusive <= $10000`; `endExclusive <= exact
allocation capacity`; the `== $10000` boundary case).

### 6.3 `validateC64Window`

Contract:

- In: `reuMoveAddrLo/Hi` (parsed C64 address), `reuMoveLenLo/Hi`
  (requested length).
- Out success: C=0.
- Out failure: C=1, `A` = `REU_ERR_C64_WINDOW`.

Algorithm:

1. Compute `endLo/Hi = address + length` with carry preserved.
2. If no carry: always valid (`end < $10000`, no wrap possible; the C64
   address space ceiling is fixed and there is no per-request capacity to
   compare against, unlike the REU side).
3. If carry set: valid only when `endLo/Hi == $0000` (true end exactly
   `$10000`, i.e., the window runs up to and including `$FFFF`). Any
   other post-carry value means the request would wrap past `$FFFF`; fail
   with `REU_ERR_C64_WINDOW` per the parent plan Section 8.3's explicit
   "do not wrap to `$0000`" rule.

## 7. New BSS State

Add ordinary linked BSS, declared with the existing WP3/WP4 transfer
scratch:

```text
reuMoveHandle: .byte 0   ; parsed handle (X is clobbered by later parses)
reuMoveOffLo:  .byte 0   ; normalized allocation-relative offset (parseVmmOffset output)
reuMoveOffHi:  .byte 0
reuMoveAddrLo: .byte 0   ; parsed C64 address
reuMoveAddrHi: .byte 0
reuMoveLenLo:  .byte 0   ; parsed length
reuMoveLenHi:  .byte 0
reuMoveDir:    .byte 0   ; 0 = R (fetch), 1 = W (stash) -- consumed by WP6
```

Eight bytes. `parseVmmOffset`'s own page/offset stashing (Section 5, step
4) reuses `reuXferParaLo/Hi` (WP3's existing scratch, already understood
to be destroyed across any REU command's internal computation) rather than
adding yet more dedicated bytes for a value that is fully consumed before
`XM`'s own dedicated state is finalized.

**Reuse risk analysis (resolved 2026-08-06)**: no runtime corruption is
possible in this design — DEBUG is single-threaded with no interrupt-
driven code touching `reuXferParaLo/Hi` during ordinary parsing (the only
CBINV hijack happens inside `G`/`T`/`P`'s `launchProgram`, unrelated to
`XM`), the only call between `parseVmmOffset`'s stash and read-back is
`parseHexArg` (which only touches `HexValLo/Hi`, never
`reuXferParaLo/Hi`), and any later reuse by `validateReuWindow` for its
own capacity-shift arithmetic (Section 6.2) happens strictly after
`parseVmmOffset` has already finished and copied its result into the
dedicated `reuMoveOffLo/Hi` fields — sequential, non-overlapping
lifetimes, the same pattern `DebugTemp` and `reuXferParaLo/Hi` itself
already use safely across WP2-WP4.

The real cost is not correctness but a **documentation/discipline
burden**: every future reader touching this scratch must know its value
is meaningless across a `JSR` boundary or between commands — trustworthy
only immediately after being set. This burden already exists since WP3;
WP5 adds one more consumer of the same rule rather than a new risk.
Approved to reuse `reuXferParaLo/Hi` on that basis, but flagging this
explicitly: if a future work package (WP6's chunked transfer, or a later
REU command) needs `reuXferParaLo/Hi` and `parseVmmOffset`'s staging to
coexist with overlapping lifetimes, or if this reuse pattern is ever found
to make a bug harder to diagnose in practice, splitting `parseVmmOffset`'s
staging into its own dedicated 2-byte field is a cheap, low-risk follow-up
— not a redesign. Revisit if WP6 or later work finds the shared-scratch
convention getting in the way.

No zero-page growth. Total growth: 8 bytes, versus WP4's 24-byte
`sysInfoBuf` and WP3's 3-byte scratch.

## 8. Error Selector Usage Summary (WP5)

| Selector | WP5 trigger |
|---|---|
| `REU_ERR_MISSING_ARG` | any of handle/offset/address/length/direction absent |
| `REU_ERR_VALUE_RANGE` | malformed handle, malformed offset component, malformed address, malformed or zero length |
| `REU_ERR_TRAILING_INPUT` | extra tokens after the direction |
| `REU_ERR_INACTIVE_HANDLE` | handle parses but is not active |
| `REU_ERR_PAGE_OFFSET` | `page:offset` form with `page > $000F` or `offset > $0FFF` |
| `REU_ERR_ALLOC_WINDOW` | REU-side window exceeds the selected allocation |
| `REU_ERR_C64_WINDOW` | C64-side window would wrap past `$FFFF` |
| `REU_ERR_DIRECTION` | direction token present but not `R`/`W` |

All eight already exist in the WP2 taxonomy; WP5 introduces no new
selector.

## 9. Command Flow (`cmdReuMove`)

1. `lda #1; jsr parseReuHandle`. On C=1, `jmp reuError`.
2. Stash the handle in `reuMoveHandle` (needed later for
   `validateReuWindow`'s registry read; `X` will be repeatedly overwritten
   by subsequent parses).
3. `jsr skipSpaces`; `jsr parseVmmOffset`. On C=1, `jmp reuError`.
4. `jsr skipSpaces`; parse the C64 address via `parseHexArg` into
   `reuMoveAddrLo/Hi`. On C=1, fail with `REU_ERR_VALUE_RANGE`.
5. `jsr skipSpaces`; parse the length via `parseHexArg` into
   `reuMoveLenLo/Hi`. On C=1, fail with `REU_ERR_VALUE_RANGE`. If the
   parsed value is `$0000`, fail with `REU_ERR_VALUE_RANGE` (zero length
   is syntactically a valid hex parse but a semantically invalid transfer
   length — reject explicitly here, since `parseHexArg` cannot distinguish
   "zero digits" from "the digit zero").
6. `jsr skipSpaces`; read one direction character. Missing (null) fails
   `REU_ERR_MISSING_ARG`. Normalize shifted/unshifted exactly as
   `cmdExtended` does; `R` → `reuMoveDir=0`, `W` → `reuMoveDir=1`; anything
   else fails `REU_ERR_DIRECTION`. Advance `Y` past the direction
   character.
7. `jsr requireEnd`. On C=1, fail `REU_ERR_TRAILING_INPUT`.
8. `ldx reuMoveHandle; jsr validateReuWindow`. On C=1, `jmp reuError`.
9. `jsr validateC64Window`. On C=1, `jmp reuError`.
10. All validation passed: print the temporary preflight-ok indicator
    (Section 10) and return C=0.

Every failure path in steps 1-9 returns before step 10, so no "preflight
ok" text can ever print for an invalid command — this is the VICE-testable
proof that validation is complete before any (future) DMA.

## 10. Temporary Success Indicator

WP5 has no transfer to perform yet. On full validation success, print:

```text
XM PREFLIGHT OK
```

(new message `msgReuMovePreflightOk`, CR-terminated, single line) instead
of `msgStub`'s generic `not yet implemented`. This makes VICE evidence
unambiguous: a validated `XM` command reaches a distinct string that a
malformed one cannot reach through any path, exactly mirroring WP2's own
requirement that each stub be "structurally distinct so VICE checkpoints
can prove routing." WP6 replaces this print with the real transfer and
its own success/failure reporting.

## 11. Atomic Implementation Increments

### Increment 1: `parseVmmOffset` and Flat/Page Equivalence

1. Add the 8 bytes of WP5 BSS state (Section 7).
2. Implement `parseVmmOffset` (Section 5).
3. Wire `cmdReuMove` only through handle + offset parsing (stop after
   Section 9 step 3 for this increment; print the temporary indicator
   immediately after a successful offset parse, without yet parsing
   address/length/direction, purely to exercise the parser in isolation).
4. Build DEBUG.
5. Verify under VICE: the parent plan's Section 10.4 equivalent-forms
   matrix (`0000==0000:0000`, `0FFF==0000:0FFF`, `1000==0001:0000`,
   `1020==0001:0020`, `FFFF==000F:0FFF`) and malformed-forms matrix
   (`:`, `0001:`, `:0020`, `0001::0020`, `0001:1000`, `0010:0000`,
   `000G:0000`, `0001:000G`, `0001:0020X`), asserting on
   `reuMoveOffLo/Hi`'s actual stored bytes via `vice_read_memory` (not
   screen text — see [[reference-vice-checkpoint-verification]]) to prove
   flat and page forms normalize to byte-identical state.

Exit criterion: every equivalent flat/page pair produces identical stored
bytes; every malformed form is rejected with the documented selector.

### Increment 2: Full Grammar and `requireEnd`

1. Extend `cmdReuMove` through address, length, direction, and
   `requireEnd` (Section 9 steps 4-7).
2. Build DEBUG.
3. Verify missing/malformed address, missing/malformed/zero length,
   missing/invalid direction, and trailing input all reject with the
   correct selector, and that a fully well-formed command (still
   unvalidated against a real allocation, since window validation is
   Increment 3) reaches the temporary indicator.

Exit criterion: the complete grammar parses and rejects correctly; no
window validation yet.

### Increment 3: Window Validation

1. Implement `validateReuWindow` and `validateC64Window` (Section 6).
2. Wire them into `cmdReuMove` (Section 9 steps 8-9).
3. Build DEBUG.
4. Verify under VICE against real allocations from `XA`: the parent plan's
   Section 10.5 preflight-relevant cases (round-trip-eligible windows at
   offset zero, at the final valid allocation byte, ending exactly at
   allocation capacity; rejecting one byte beyond capacity; crossing a
   page boundary within capacity; flat/page-equivalent access to the same
   normalized location; rejecting `0000:1000` and `000F:0FFF`+length-two;
   accepting `000F:0FFF`+length-one only for a 64KB allocation; rejecting
   zero length; rejecting invalid direction; rejecting missing/trailing
   operands; rejecting a C64-side wrap) — every negative case verified by
   confirming the temporary indicator does *not* print and the correct
   selector's generic error does, since WP5 performs no DMA to inspect.

Exit criterion: every invalid window is rejected before the temporary
indicator can print; every valid window (including both 64KB-allocation
boundary cases) reaches it.

### Increment 4: WP5 Regression and Completion Gate

1. Build `debug`, `image_d64`, and `test_image_d64`.
2. Re-run WP1 `G`/`T`/`P`/`Q` via the checkpoint/register procedure from
   [[reference-vice-checkpoint-verification]], and the WP2/WP3/WP4
   `XA`/`XD`/`XS`/`Q` smoke matrix.
3. Inspect registry/BSS storage, DEBUG envelope, and relocation output.
4. Confirm zero `DOS_VMM_READ`/`DOS_VMM_WRITE` call sites (static grep).
5. Update task, changelog, memory, and DOX records.
6. Produce the manual walkthrough and obtain user confirmation.

Exit criterion: `XM` parsing and preflight validation pass with no
regression to WP1-WP4 behavior, and no DMA has been introduced.

## 12. Build and Static Verification

1. Build `debug` after each increment.
2. Build `image_d64` before VICE work; `test_image_d64` at the completion
   gate.
3. Require no warnings or errors attributable to WP5.
4. Record DEBUG code bytes and relocation count against WP4's merged
   baseline (build 1123: 7,615 code bytes, 893 relocation points).
5. Confirm the binary remains within the existing 8KB `MAIN` envelope.
6. Confirm BSS growth is exactly 8 bytes beyond WP4's state.
7. Confirm no new `$70-$7F` symbol or ownership.
8. Confirm `DOS_VMM_READ` and `DOS_VMM_WRITE` remain uncalled anywhere in
   `debug.s`.
9. Let CMake update `BUILD_DEBUG`; never edit generated includes.

## 13. VICE Verification Matrix

Follow `.agents/workflows/vice-mcp-testing.md` and
[[reference-vice-checkpoint-verification]] for the `G`/`T`/`P`/`Q`
regression leg. All `XM`-specific assertions use `vice_read_memory`
against the WP5 BSS fields (Section 7) and screen text for the
error/indicator strings, not screen-text decoding of numeric state.

### Setup

```text
XA 0100    ; handle 0, 4KB (one page) -- fits page 0 only
XA 1000    ; handle 1, 64KB (all sixteen pages) -- boundary allocation
```

### Flat/Page Equivalence (against handle 1)

```text
XM 1 0000 6000 0001 R   ; PREFLIGHT OK
XM 1 0000:0000 6000 0001 R   ; PREFLIGHT OK, identical stored state
XM 1 1000 6000 0001 R   ; PREFLIGHT OK
XM 1 0001:0000 6000 0001 R   ; PREFLIGHT OK, identical stored state
```

### Malformed `page:offset`

```text
XM 1 : 6000 0001 R
XM 1 0001: 6000 0001 R
XM 1 :0020 6000 0001 R
XM 1 0001::0020 6000 0001 R
XM 1 0001:1000 6000 0001 R
XM 1 0010:0000 6000 0001 R
```

### Allocation-Window Boundary (against handle 0, 4KB)

```text
XM 0 0000 6000 1000 R   ; exactly fills the 4KB allocation -- PREFLIGHT OK
XM 0 0000 6000 1001 R   ; one byte beyond -- REU_ERR_ALLOC_WINDOW
XM 0 0FFF 6000 0001 R   ; final valid byte -- PREFLIGHT OK
XM 0 1000 6000 0001 R   ; one byte past capacity -- REU_ERR_ALLOC_WINDOW
```

### Allocation-Window 64KB Boundary (against handle 1)

```text
XM 1 000F:0FFF 6000 0001 R   ; ends at exactly $10000 -- PREFLIGHT OK
XM 1 000F:0FFF 6000 0002 R   ; would exceed $10000 -- REU_ERR_ALLOC_WINDOW
```

### C64-Window Wrap

```text
XM 0 0000 FFFF 0002 R   ; would wrap past $FFFF -- REU_ERR_C64_WINDOW
XM 0 0000 FFFF 0001 R   ; ends exactly at $10000 -- PREFLIGHT OK
```

### Direction and Trailing Input

```text
XM 0 0000 6000 0001 X   ; REU_ERR_DIRECTION
XM 0 0000 6000 0001     ; REU_ERR_MISSING_ARG
XM 0 0000 6000 0001 R EXTRA   ; REU_ERR_TRAILING_INPUT
```

### Zero Length and Inactive/Invalid Handle

```text
XM 0 0000 6000 0000 R   ; REU_ERR_VALUE_RANGE
XM 9 0000 6000 0001 R   ; REU_ERR_VALUE_RANGE (handle out of range)
XD 0
XM 0 0000 6000 0001 R   ; REU_ERR_INACTIVE_HANDLE
```

## 14. Documentation and Tracking

After plan approval and before source implementation:

1. Create `wiki/tasks/debug-reu-address-syntax-wp5.md`.
2. Create and activate the matching Taskwarrior task via the `task` CLI.
3. Synchronize `brain/task.md`.

During implementation:

- Record build and verification evidence after each increment.
- Add `CHANGELOG.md` behavior only when `XM` parsing/validation lands and
  is verified.
- Update `brain/MEMORY.md` when the 8-byte transfer state is added.
- Defer public DEBUG user-guide command syntax for `XM` to WP7.
- Perform the mandatory DOX closeout: `src/external/debug/AGENTS.md`
  already documents "DEBUG owns at most four VMM allocations" and the
  base-memory/REU boundary; confirm no wording drift, add a line noting
  `XM` validates windows before any transfer once WP5 lands.

## 15. Approval Questions

Resolved 2026-08-06:

1. The temporary success indicator is `XM PREFLIGHT OK` (Section 10),
   approved as written.
2. The flat offset form relies on `parseHexArg`'s existing 4-digit cap for
   its 16-bit range guarantee, with no redundant explicit `<= $FFFF`
   check, consistent with `XA`'s paragraph-count parsing. Approved as
   written.
3. `parseVmmOffset`'s transient page/offset staging reuses
   `reuXferParaLo/Hi` (Section 7). Approved after an explicit risk
   analysis found no runtime corruption is possible in this design (see
   Section 7's "Reuse risk analysis"); flagged there as a cheap,
   low-risk follow-up to split into dedicated scratch later if a future
   work package needs overlapping lifetimes or the shared convention
   proves to get in the way in practice.
4. Increment 1's intermediate handle+offset-only wiring (Section 11) is
   accepted as engineering scaffolding, not a public contract change,
   matching WP2's precedent of undocumented interim stubs.

## 16. Completion Gate

WP5 may be presented for user confirmation when:

1. `XM`'s full grammar parses correctly: handle, flat or `page:offset`
   operand, C64 address, length, direction, end-of-input.
2. Flat and `page:offset` forms normalize to byte-identical stored state
   for every equivalent pair in the parent plan's Section 10.4 matrix.
3. Every malformed page/offset form is rejected with the documented
   selector before window validation runs.
4. `validateReuWindow` accepts and rejects exactly the cases in Section
   13's allocation-window matrix, including both `$1000`-paragraph 64KB
   boundary cases.
5. `validateC64Window` rejects a wrap past `$FFFF` and accepts a window
   ending exactly at `$10000`.
6. No `DOS_VMM_READ` or `DOS_VMM_WRITE` call exists anywhere in
   `debug.s`.
7. No new private zero-page state exists; BSS growth is exactly 8 bytes.
8. DEBUG remains relocatable and inside its linker envelope.
9. WP1-WP4 regressions still pass, verified via
   [[reference-vice-checkpoint-verification]] for `G`/`T`/`P`/`Q`.
10. Task, changelog, memory, and DOX records are synchronized.
11. A manual walkthrough is available.

Do not mark WP5 complete until the user confirms the walkthrough.
