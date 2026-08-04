# DEBUG REU and Address Syntax WP6 Detailed Plan

**Status:** Approved; implementation in progress

**Created:** 2026-08-06

**Parent plan:** `brain/plans/2026-08-03-debug-reu-and-address-syntax.md`

**Work package:** WP6, Chunked `XM` Transfers

**Implementation target:** `src/external/debug/debug.s`,
`CMakeLists.txt` (envelope expansion, Section 4)

**Implementation branch:** `feature/debug-reu-address-wp6` (branched from
`debug` after WP5 merged, commit `28ae49f`)

## 1. Purpose

Replace `XM`'s temporary `XM PREFLIGHT OK` indicator with a real, chunked
`DOS_VMM_READ`/`DOS_VMM_WRITE` transfer: every window WP5 already proved
valid gets moved in bounded chunks, restaging OS parameters before each
one, stopping immediately on a runtime OS failure, and reporting exact
transferred progress either way.

## 2. Confirmed Baseline

1. WP5 is merged into `debug` (commit `28ae49f`). `cmdReuMove`'s full
   grammar and both window validators (`validateReuWindow`,
   `validateC64Window`) are implemented and correct; on success it
   currently prints `msgReuMovePreflightOk` and returns — WP6 replaces
   only that tail, not the parsing/validation that precedes it.
2. DEBUG build 1124: 8,033 code bytes, 959 relocation points.
3. `debug.s` has **no separate BSS segment** — the whole file is under a
   single `.segment "CODE"` (verified: `grep '\.segment' debug.s` finds
   only `"HEADER"` and `"CODE"`). Every "BSS-looking" declaration
   (registers, the registry, `inputBuf`, `sysInfoBuf`, WP5's transfer
   state, etc.) is therefore *inside* the measured `code_bytes` figure
   already, not separately allocated. This means `code_bytes` from
   `reloc.py` **is** the true total `MAIN` footprint — there is no hidden
   BSS to add on top. Confirmed by cross-checking: `debug_3800.cfg`
   declares `BSS: load = MAIN, type = bss` but `debug.s` never switches
   into that segment, so it is unused.
4. **Exact envelope headroom: 159 bytes** (`8192 - 8033`), verified two
   ways: (a) `code_bytes` already represents the true footprint per item
   3, and (b) `ld65` did not raise a "does not fit" error at WP5's build,
   which it reliably does the moment a `MEMORY` area's assigned segments
   exceed its declared `size` — a successful link is itself proof the
   footprint was `<= 8192` bytes at that point.
5. 159 bytes is not enough for WP6. Prior work packages' code growth:
   WP3 +318 bytes (6,885→7,203... adjusted for WP2 baseline), WP4 +458
   bytes (7,349→7,615 is WP5's own delta; WP4's was 7,615-7,349=... see
   Section 4 for the precise growth table). WP6 needs a transfer loop,
   two new helper routines, OS parameter staging, progress tracking, and
   new message strings — comparable to or larger than WP4's growth.
   **Section 4 resolves this before any WP6 source code is written.**
6. `DOS_VMM_READ` ($59) and `DOS_VMM_WRITE` ($5A) share one contract
   (`src/command64/api.asm:278-304`, backed by `vmmReadBlock`/
   `vmmWriteBlock` in `vmm.asm:321-374`):
   - Input: `VmmSegLo/Hi` ($68/$69), `VmmOffLo/Hi` ($6A/$6B), `VmmBank`
     ($6C) identify the REU side; `X/Y` = the C64 buffer pointer Lo/Hi;
     `HexValLo/Hi` ($66/$67) = the byte count for this call.
   - Output: C=0 success, C=1 failure (`A` = an OS error code).
   - The OS performs the DMA in a single hardware burst for whatever byte
     count is given — it does **not** itself cap or chunk anything, and
     it does **not** reject a zero byte count before handing it to the
     REU chip. A `HexValLo/Hi == $0000` request would be interpreted by
     real REU hardware as a 65536-byte transfer (the classic REU
     zero-means-max quirk), not a no-op. This is exactly why the parent
     plan's Section 8.5 requires WP6 to never construct a zero-length
     chunk, and why the 256-byte chunk cap (Section 5) exists: it keeps
     every chunk length in `1-256`, nowhere near the `$0000` ambiguity
     zone.
   - Assume `OS_API` clobbers `A`, `X`, `Y`, carry, and `$66-$6C`
     (parent plan Section 7.4) — every parameter must be restaged before
     every single chunk's call, with no assumption that any previous
     call's staging survives.
7. `VmmSegLo/Hi/OffLo/Hi/Bank` are already visible to `debug.s` via
   `command64.inc`'s transitive `.include "vmm.inc"` (same include chain
   WP3 already relies on for `VMM_ERR_INVALID`/`VMM_ERR_NOMEM`).
8. WP5's transfer state (`reuMoveHandle`, `reuMoveOffLo/Hi`,
   `reuMoveAddrLo/Hi`, `reuMoveLenLo/Hi`, `reuMoveDir`) already holds
   everything needed to *start* a transfer. WP5's plan flagged that
   `parseVmmOffset`'s reuse of `reuXferParaLo/Hi` (WP3's scratch) should
   be revisited "if a future work package needs `reuXferParaLo/Hi` and
   `parseVmmOffset`'s staging to coexist with overlapping lifetimes" —
   WP6's chunk loop is exactly that case (Section 6 gives WP6 its own
   dedicated chunk-length scratch instead of reusing `reuXferParaLo/Hi`,
   resolving that flagged item as anticipated).
9. DEBUG's private zero page `$70-$7F` remains fully occupied; WP6 adds
   no zero-page state (all new state is ordinary linked storage, same as
   every prior REU work package).

## 3. Scope

### 3.1 Included

- Expand DEBUG's `MAIN` linker envelope (Section 4) as a prerequisite,
  before any WP6 transfer code is written.
- Implement `stageReuTransfer`: compute the next chunk's length
  (`min(remaining, 256)`) and stage every `DOS_VMM_READ`/`DOS_VMM_WRITE`
  parameter fresh from WP5's/WP6's BSS state.
- Implement `advanceReuTransfer`: after a successful chunk, advance the
  REU offset and C64 address, decrement the remaining length, and
  accumulate the transferred-byte count.
- Implement the chunk loop itself, dispatching to `DOS_VMM_READ` (for
  `reuMoveDir=0`, `R`) or `DOS_VMM_WRITE` (`reuMoveDir=1`, `W`) per
  chunk.
- Stop immediately on the first runtime OS failure; report exact
  transferred-so-far progress rather than silently discarding it.
- Replace `msgReuMovePreflightOk`'s tail-call in `cmdReuMove` with the
  real transfer, preserving every parsing/validation step WP5 already
  implemented unchanged.
- Add message strings for transfer success (with the transferred count)
  and transfer failure (with the partial transferred count).
- Build and inspect DEBUG size/relocation/BSS growth against the
  expanded envelope.
- Verify round-trip transfers, chunk/page/allocation-boundary crossings,
  and partial-failure evidence under VICE.

### 3.2 Excluded

- Any change to `XA`, `XD`, `XS`, `Q`, `freeAllReu`, `parseVmmOffset`,
  `validateReuWindow`, or `validateC64Window` beyond what Section 4's
  envelope change requires (none — the envelope change is purely a
  linker configuration number, not a source edit).
- `page:offset` parsing changes (already complete, WP5).
- New private zero-page state.
- DEBUG version/changelog bump for the combined REU+syntax feature
  (deferred to WP7).

## 4. Envelope Expansion (Prerequisite)

### 4.1 The Constraint

`add_ca65_app(debug "${DEBUG_ENTRY}" DEBUG_SRCS 1012 "2000")`
(`CMakeLists.txt:185`) passes `"2000"` as `PRG_SIZE_HEX` into
`add_ca65_app` (`cmake/Ca65.cmake`), which substitutes it directly into
the generated `debug_<base>.cfg`'s `MAIN: start = $<base>, size =
$2000, ...` line. This is a **build-configuration number, not a hardware
limit** — real C64 RAM is free and unused well beyond `$5800` (DEBUG's
current end) up to at least `$C000` (where `VmmMctBase`'s 4096-byte
Memory Control Table lives; `UserProgEnd = $CFFF` per
`include/vmm.inc`/`include/command64.inc`).

### 4.2 The Real Constraint: The `$6000+` Test-Fixture Convention

The actual ceiling that matters is **not** hardware — it is the
documented convention (established after WP1/WP2's own test-plan
correction, and reused throughout every WP3-WP5 walkthrough) that manual
test fixtures are poked at `$6000+` because that is *above* DEBUG's own
occupied range. Growing `MAIN` past `$6000` would make DEBUG's own code
start overlapping the addresses every existing walkthrough uses for its
`E 6000 60` / `E 6100 EA EA EA 60` fixtures — silently corrupting DEBUG's
own running code the same way `[[project-conway-fixed-buffer-hazard]]`
documents for an unrelated app's hardcoded buffers. Any envelope
expansion must keep DEBUG's occupied range safely below `$6000`.

### 4.3 Proposed Expansion

At base `$3800`, DEBUG's current end is `$3800 + 8033 = $5761`
(`0x1F61`). Proposed: grow `MAIN`'s `size` from `$2000` (8192 bytes) to
**`$2400`** (9216 bytes, +1024 bytes) in `CMakeLists.txt:185`'s
`add_ca65_app` call (the sole edit — `cmake/Ca65.cmake`'s template
already substitutes whatever `PRG_SIZE_HEX` it is given).

- New ceiling: `$3800 + $2400 = $5C00` — a full `1024`-byte gap remains
  below `$6000`, comfortably preserving the test-fixture convention with
  margin for WP7's own (doc-only, but worth a safety margin regardless)
  closeout.
- New headroom after WP6 starts: `159 + 1024 = 1183` bytes, versus prior
  work-package growth of roughly 300-460 bytes each (Section 2, item 5) —
  WP6's genuinely new logic (a transfer loop plus two small helpers) is
  comparable in scope, so this margin should hold with room to spare for
  WP7 to not have to revisit this decision.
- This is a **single-line, low-risk, trivially reversible** change: one
  hex literal in one `add_ca65_app` call. It does not touch `debug.s`,
  does not change any command's grammar or behavior, and does not affect
  any other app's build (`add_ca65_app` generates a per-app `.cfg`; no
  other app shares DEBUG's memory-area declaration).

### 4.4 Alternative Considered: Consolidate Instead Of Expand

Trimming WP1-5's existing code to reclaim bytes instead of growing the
envelope was considered and rejected for WP6: it would require re-
auditing already-verified, already-shipped command logic for marginal
savings, with real regression risk, to save an amount of headroom
(unknown until attempted) that the single-line envelope change achieves
immediately and provably. Consolidation remains available as a *later*
lever if a future work package needs still more room and expanding
further would approach `$6000`.

### 4.5 Documentation Impact

Once the envelope changes, `wiki/debug-utility.md`/`docs/debug-utility.md`
and any doc citing DEBUG's occupied address range (the WP2 test-plan
correction is the precedent for this exact kind of update) need their
range updated from "approximately `$3800-$5800`" to "approximately
`$3800-$6000`" language, without implying the `$6000+` test convention
itself changed — it has not; the gap to it just shrank from ~2400 bytes
to ~1024. Handled in WP6's Section 11 documentation pass, not WP7, since
it's a direct consequence of WP6's own envelope change.

## 5. Chunking Contract

Recommended maximum chunk size: 256 bytes (parent plan Section 5.5),
chosen to keep every chunk's length in `1-256` — never `0`, which real
REU hardware would interpret as a 65536-byte transfer (Section 2, item
6).

`chunkLen = min(remainingLen, 256)`:

- If `remainingHi == 0`: `remainingLo` is `1-255` (never `0` — the loop
  terminates before staging a chunk once `remaining` reaches `0`, see
  Section 7), so `chunkLen = remainingLo` fits one byte, always `>= 1`.
- Otherwise (`remainingHi != 0`, i.e. `remaining >= 256`):
  `chunkLen = 256` exactly (`HexValHi=$01, HexValLo=$00` when staged).

## 6. New BSS State

Add ordinary linked BSS, declared with WP5's transfer state:

```text
reuMoveChunkLo: .byte 0   ; current chunk's length (1-256), computed fresh
reuMoveChunkHi: .byte 0   ; each iteration by stageReuTransfer
reuMoveXferLo:  .byte 0   ; running transferred-byte count, for progress
reuMoveXferHi:  .byte 0   ; reporting on both success and partial failure
```

Four bytes. This is WP6's own dedicated scratch, not a reuse of WP3's
`reuXferParaLo/Hi` — resolving the coexistence concern WP5's plan flagged
(Section 2, item 8): `parseVmmOffset` (during parsing, before the
transfer loop exists) and `stageReuTransfer`/`advanceReuTransfer` (during
the transfer loop, long after parsing has finished) never run
concurrently in practice, but giving the chunk length its own bytes
removes any need to reason about that at all, and the four extra bytes
are cheap given Section 4's expanded envelope.

No zero-page growth. Total growth: 4 bytes, versus WP5's 8-byte transfer
state.

## 7. `stageReuTransfer`

Contract:

- In: WP5's transfer state (`reuMoveHandle`, `reuMoveOffLo/Hi`,
  `reuMoveAddrLo/Hi`, `reuMoveLenLo/Hi` — the last now doubling as
  "remaining length," Section 8) must already reflect the current
  position (unchanged on the first call; advanced by the prior
  `advanceReuTransfer` call on every subsequent one).
- Out: `reuMoveChunkLo/Hi` holds this iteration's chunk length (Section
  5); `VmmSegLo=$00`, `VmmSegHi`/`VmmBank` = the selected handle's
  registry identity, `VmmOffLo/Hi` = `reuMoveOffLo/Hi`, `HexValLo/Hi` =
  `reuMoveChunkLo/Hi`, `X/Y` = `reuMoveAddrLo/Hi` — every `OS_API`
  parameter for `DOS_VMM_READ`/`DOS_VMM_WRITE` freshly staged.
- Clobbers: `A`, `X`, `Y`.

Algorithm:

1. Compute `chunkLen = min(remaining, 256)` (Section 5) into
   `reuMoveChunkLo/Hi`.
2. `VmmSegLo = 0` (always — DOS_VMM_READ/WRITE's `SegLo` is reserved,
   matching every existing caller's convention, e.g. DASH's
   `VMMSEGLO ($68) IS ALWAYS WRITTEN AS A LITERAL 0 BEFORE EVERY`
   allocation call — same convention applies to the transfer calls).
3. `VmmSegHi = reuSegHi,x` / `VmmBank = reuBank,x` where `x =
   reuMoveHandle` (the registry identity for the already-validated,
   already-active handle — no re-validation needed here; WP5's
   `validateReuWindow` already proved the handle active and in range
   before the transfer loop can start).
4. `VmmOffLo/Hi = reuMoveOffLo/Hi` (the current REU-relative cursor).
5. `HexValLo/Hi = reuMoveChunkLo/Hi`.
6. `X/Y = reuMoveAddrLo/Hi` (the current C64 cursor).

## 8. `advanceReuTransfer`

Contract:

- In: `reuMoveChunkLo/Hi` holds the chunk length that was *just
  successfully transferred* (the caller only invokes this after `OS_API`
  returns C=0).
- Out: `reuMoveOffLo/Hi`, `reuMoveAddrLo/Hi` advanced by the chunk
  length; `reuMoveLenLo/Hi` (remaining) decremented by it;
  `reuMoveXferLo/Hi` (transferred-so-far) incremented by it.
- Clobbers: `A`.

Algorithm (parent plan Section 8.5, steps 1-4 — step 5, "restage the
next request," is the loop's own next iteration calling
`stageReuTransfer` again, not part of this routine):

1. `reuMoveOffLo/Hi += reuMoveChunkLo/Hi` (16-bit add; cannot overflow
   past `$FFFF` mid-transfer because `validateReuWindow` already proved
   the *final* end-exclusive value fits, and every intermediate cursor
   position is `<=` that proven end).
2. `reuMoveAddrLo/Hi += reuMoveChunkLo/Hi` (same reasoning via
   `validateC64Window`).
3. `reuMoveLenLo/Hi -= reuMoveChunkLo/Hi` (16-bit subtract; cannot
   underflow because `chunkLen <= remaining` by construction, Section
   5).
4. `reuMoveXferLo/Hi += reuMoveChunkLo/Hi` (16-bit add; cannot overflow
   `$FFFF` because it can never exceed the original total requested
   length, which `parseHexArg` already capped at `$FFFF`).

No carry-preserving 17-bit arithmetic is needed here, unlike WP5's window
validators — every intermediate value is provably within 16 bits by the
preflight proof already established before the loop starts.

## 9. Transfer Loop (Replaces `msgReuMovePreflightOk`'s Tail)

Where WP5's `cmdReuMove` currently does, after `validateC64Window`
succeeds:

```asm
crmC64WindowOk:
    lda #<msgReuMovePreflightOk
    ldy #>msgReuMovePreflightOk
    jsr API_PRINT_STR
    clc
    rts
```

WP6 replaces this tail with:

```asm
crmC64WindowOk:
    jmp executeReuTransfer
```

`executeReuTransfer`:

1. `reuMoveXferLo/Hi = 0` (reset the progress counter for this
   command).
2. Loop: if `reuMoveLenLo/Hi == 0` (remaining is zero), all requested
   bytes are transferred — go to step 6 (success).
3. `jsr stageReuTransfer`.
4. Dispatch on `reuMoveDir`: `A = DOS_VMM_WRITE` if `1`, else `A =
   DOS_VMM_READ`. `jsr OS_API`.
5. On C=1 (failure): go to step 7 (partial failure). On C=0: `jsr
   advanceReuTransfer`, then repeat from step 2.
6. Success: print the transfer-complete message (Section 10) including
   `reuMoveXferLo/Hi` (which now equals the original requested length
   exactly, since the loop only reaches here when remaining hit zero).
   `clc; rts`.
7. Partial failure: print the transfer-failed message (Section 10)
   including `reuMoveXferLo/Hi` (whatever was successfully moved before
   the failing chunk) and the OS's returned error in `A`. `sec; rts`
   (through `reuError`-equivalent plumbing — Section 10 resolves the
   exact selector).

No parser, handle, direction, or preflight bounds error can reach this
routine at all — every one of WP5's validation steps already returns
through `reuError` before `crmC64WindowOk`'s label, satisfying the parent
plan's Section 8.5 closing rule ("No parser, handle, direction, or
preflight bounds error may begin DMA").

## 10. Success and Failure Reporting

### 10.1 Success

New message, printed with the transferred count appended:

```text
XM XFER=xxxx OK
```

(`xxxx` = `reuMoveXferHi` then `reuMoveXferLo` via `printHex8` twice,
matching every other 16-bit field's display convention in this file.)
Replaces `XM PREFLIGHT OK` as `XM`'s success text now that a real
transfer exists — WP5's indicator was explicitly temporary
scaffolding (WP5 plan Section 10) meant to be replaced here.

### 10.2 Partial Failure

A runtime `OS_API` failure mid-transfer is a new failure mode with no
existing conceptual sibling in the fifteen-item selector taxonomy other
than `REU_ERR_PARTIAL_TRANSFER`, which the parent plan's Section 6.7
already reserves for exactly this case and which no prior work package
has used yet (`XA`/`XD`/`freeAllReu` use `REU_ERR_VMM_NOMEM`/
`REU_ERR_VMM_UNAVAILABLE`/`REU_ERR_CLEANUP` for their own OS-call
failures; none of those apply here). On partial failure:

```text
XM XFER=xxxx FAILED
```

printed via the same `reuXferHi`/`Lo` display, then routed through
`reuError` with `A = REU_ERR_PARTIAL_TRANSFER` so the command still
returns C=1 like every other DEBUG error path, while the partial-progress
line has already been printed first (the count would otherwise be lost —
`reuError` only prints the generic `error` text, never a value).

This is the first WP6 use of `REU_ERR_PARTIAL_TRANSFER`; no other
selector is introduced.

## 11. Atomic Implementation Increments

### Increment 0: Envelope Expansion

1. Change `CMakeLists.txt:185`'s `add_ca65_app(debug ...)` call's size
   argument from `"2000"` to `"2400"`.
2. Build `debug` with no other changes; confirm it still links
   successfully (proves the expansion alone is inert) and that
   `code_bytes` is unchanged (8,033) — only the *ceiling* moved, not the
   content.
3. Update `wiki/debug-utility.md`/`docs/debug-utility.md`'s occupied-
   range language per Section 4.5.

Exit criterion: the expanded envelope builds clean with zero source
changes, proving the expansion itself introduces no regression before
any WP6 logic is added on top of it.

### Increment 1: `stageReuTransfer` and `advanceReuTransfer`

1. Add the 4 bytes of WP6 BSS state (Section 6).
2. Implement `stageReuTransfer` (Section 7) and `advanceReuTransfer`
   (Section 8).
3. Build DEBUG; these routines are unreachable dead code at this point
   (not yet wired into `cmdReuMove`) — confirmed via static grep that no
   call site exists yet, purely to measure their isolated code-size cost
   against the new headroom before wiring them in.

Exit criterion: both routines assemble cleanly; measured code growth is
consistent with the envelope expansion's margin (Section 4.3).

### Increment 2: Transfer Loop and Real DMA

1. Implement `executeReuTransfer` (Section 9).
2. Replace `cmdReuMove`'s `msgReuMovePreflightOk` tail with `jmp
   executeReuTransfer` (Section 9).
3. Add the success/failure messages and `REU_ERR_PARTIAL_TRANSFER`
   wiring (Section 10).
4. Build DEBUG.
5. Verify under VICE: a round-trip transfer (write a known pattern via
   `F`, `XM ... W` into REU, clear the source range, `XM ... R` back out,
   confirm via `D`/`C`) for both flat and page-relative offsets, single-
   chunk and multi-chunk (>256 byte) transfers, and a transfer crossing a
   256-byte chunk boundary, a 4KB page boundary, and ending exactly at an
   allocation's capacity.

Exit criterion: round-trip transfers are byte-exact for both flat and
page-relative commands, matching the parent plan's Section 10.5 round-
trip cases; no DMA occurs for any command that fails WP5's own
validation (regression-checked, not re-implemented).

### Increment 3: Partial-Failure Evidence

1. Verify partial-progress reporting without fabricating a real hardware
   failure — per `[[feedback-vice-testing]]`, do not improvise a raw-
   state poke to force `OS_API` to fail. If a legitimate trigger exists
   (e.g., an allocation freed mid-transfer by a *separate*, real `XD`
   command is not possible mid-single-command-execution since DEBUG is
   single-threaded, so no such legitimate trigger is expected to exist
   for this feature). Document this as a **known verification gap**:
   confirm the failure-handling code path is correct by static review of
   Section 9 steps 5/7 rather than a live-fault-injection test, and ask
   the user how they want this evidence gap handled (a real hardware
   fault is genuinely hard to construct safely) rather than inventing a
   workaround.

Exit criterion: the success path is fully VICE-verified; the failure
path is statically reviewed and the verification gap is explicitly
surfaced to the user, not silently skipped or faked.

### Increment 4: WP6 Regression and Completion Gate

1. Build `debug`, `image_d64`, and `test_image_d64`.
2. Re-run WP1 `G`/`T`/`P`/`Q` via
   [[reference-vice-checkpoint-verification]], and the WP2-WP5
   `XA`/`XD`/`XS`/`XM`-preflight smoke matrix (WP5's own negative cases
   must still reject before reaching `executeReuTransfer` at all).
3. Inspect registry/BSS storage, the expanded envelope's actual final
   usage, and relocation output.
4. Update task, changelog, memory, and DOX records, including the
   envelope-expansion note (Section 4.5).
5. Produce the manual walkthrough and obtain user confirmation.

Exit criterion: `XM` performs real, correct, chunked transfers with no
regression to WP1-WP5 behavior, and the envelope expansion is documented
everywhere the parent plan's Section 12 requires.

## 12. VICE Verification Matrix

Follow `.agents/workflows/vice-mcp-testing.md` and
[[reference-vice-checkpoint-verification]].

### Round-Trip (Single Chunk)

```text
XA 0100                       ; handle 0, 4KB
F 6000 L 0080 DE               ; fill $6000-$607F with $DE
XM 0 0000 6000 0080 W          ; stash to REU
F 6000 L 0080 00               ; clear the staging range
XM 0 0000 6000 0080 R          ; fetch back
D 6000 L 0080                  ; expect $DE throughout
```

### Round-Trip (Multi-Chunk, >256 Bytes)

```text
XA 0100
F 6000 L 0300 A5                ; 768 bytes, three 256-byte chunks
XM 0 0000 6000 0300 W
F 6000 L 0300 00
XM 0 0000 6000 0300 R
D 6000 L 0300                   ; expect $A5 throughout, all three chunks
```

### Page and Allocation Boundary Crossing

```text
XA 1000                         ; handle 1, 64KB
XM 1 0FF0 6000 0020 W           ; crosses 0000:0FFF -> 0001:0000
XM 1 000F:0FF0 6000 0020 W      ; ends exactly at allocation capacity
```

### Flat/Page Round-Trip Equivalence

```text
F 6000 L 0010 7E
XM 1 1000 6000 0010 W
XM 1 0001:0000 6100 0010 R      ; read back via the equivalent page form
C 6000 6100 0010                ; expect identical bytes
```

### Regression: No DMA On Any WP5-Rejected Command

Re-run WP5's own negative matrix (malformed `page:offset`, out-of-window,
C64 wrap, bad direction, trailing input, invalid/inactive handle) and
confirm none reach `XM XFER=` output — only the pre-existing `ERROR` text,
proving `executeReuTransfer` is unreachable from any invalid command.

## 13. Build and Static Verification

1. Build `debug` after each increment.
2. Build `image_d64` before VICE work; `test_image_d64` at the completion
   gate.
3. Require no warnings or errors attributable to WP6.
4. Record DEBUG code bytes and relocation count against WP5's merged
   baseline (build 1124: 8,033 code bytes, 959 relocation points) and
   against the expanded `$2400` envelope.
5. Confirm the binary remains within the expanded 9,216-byte `MAIN`
   envelope, with the actual final headroom recorded precisely (not
   estimated) via the same "successful link proves it fits" method
   Section 2 item 4 used.
6. Confirm BSS growth is exactly 4 bytes beyond WP5's state.
7. Confirm no new `$70-$7F` symbol or ownership.
8. Let CMake update `BUILD_DEBUG`; never edit generated includes.

## 14. Documentation and Tracking

After plan approval and before source implementation:

1. Create `wiki/tasks/debug-reu-address-syntax-wp6.md`.
2. Create and activate the matching Taskwarrior task via the `task` CLI.
3. Synchronize `brain/task.md`.

During implementation:

- Record build and verification evidence after each increment.
- Add `CHANGELOG.md` behavior when the real transfer lands and is
  verified, including the envelope expansion as its own noted change.
- Update `brain/MEMORY.md` when the 4-byte WP6 scratch is added and when
  the envelope expansion's new occupied-range figure is confirmed.
- Update `wiki/debug-utility.md`/`docs/debug-utility.md`'s occupied-range
  language (Section 4.5) and command reference for `XM` (finally
  publishable as a working command — WP2-WP5 all deferred `XM`'s public
  documentation since it wasn't functionally complete until now).
- Perform the mandatory DOX closeout: `src/external/debug/AGENTS.md`
  already documents "DEBUG owns at most four VMM allocations" and
  "Validate complete commands and address windows before execution or
  VMM calls" (WP5 confirmed no drift there); WP6 should add a line
  documenting the `MAIN` envelope's current size and the "keep DEBUG's
  end address below `$6000`" constraint (Section 4.2) as a durable
  contract for whoever next needs to grow it further.

## 15. Approval Questions

Resolved 2026-08-06:

1. The envelope expansion from `$2000` to `$2400` (Section 4.3) is
   approved as written, including the single-line `CMakeLists.txt`
   change and the resulting `$3800-$5C00` occupied range.
2. The success message format `XM XFER=xxxx OK` (Section 10.1) is
   approved as written.
3. `REU_ERR_PARTIAL_TRANSFER` (Section 10.2) is approved for reuse,
   alongside printing the partial-progress line before routing through
   `reuError`.
4. Static code review of the failure-handling path (Section 11,
   Increment 3), with the live-verification gap explicitly documented in
   the walkthrough rather than faked via a fault-injection workaround, is
   approved. No legitimate live-failure trigger was identified or
   proposed as an alternative.

## 16. Completion Gate

WP6 may be presented for user confirmation when:

1. The envelope expansion is approved, applied, and inert on its own
   (Increment 0's exit criterion).
2. `XM` performs real chunked transfers for both `R` and `W`, byte-exact
   round-trip, for flat and page-relative operands.
3. Transfers correctly cross 256-byte chunk boundaries, 4KB page
   boundaries, and end exactly at an allocation's capacity, without
   wrap or out-of-bounds DMA.
4. Every parameter is restaged fresh before every chunk (static review
   confirms `stageReuTransfer` is called every iteration, never assuming
   prior staging survives).
5. No command that fails WP5's own preflight validation reaches any DMA
   call (regression-verified).
6. A runtime OS failure mid-transfer stops immediately, reports exact
   transferred progress, and returns through `REU_ERR_PARTIAL_TRANSFER`
   (statically reviewed; live verification gap explicitly acknowledged
   per Approval Question 4's resolution).
7. No new private zero-page state exists; BSS growth is exactly 4 bytes.
8. DEBUG remains relocatable and inside its expanded linker envelope.
9. WP1-WP5 regressions still pass.
10. Task, changelog, memory, and DOX records are synchronized, including
    the envelope-expansion documentation.
11. A manual walkthrough is available.

Do not mark WP6 complete until the user confirms the walkthrough.
