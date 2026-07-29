---
feature: casm-phase9-wp47-ordered-include-graph-and-pass2-replay
created: 2026-07-29
status: complete
---

# Plan: CASM Phase 9 WP47 - Ordered Include Graph and Pass 2 Replay

## Objective

Wire real production `.INCLUDE` dispatch into `casmRunPass` for the first
time: Pass 1 resolves/loads/pushes a child through `include.s`/`source.s`
exactly as `tests/src/casm_frame` already proves by hand, and additionally
records one ordered include event per `.INCLUDE` encountered. Pass 2 replays
those events -- pushing each recorded child from the already-populated
catalog with zero source-filesystem I/O -- and defensively re-validates each
replayed step against the recorded event. `casmRunPass`'s `.INCLUDE` case
stops returning `CASM_DIAG_NOT_IMPLEMENTED`; this is the work package that
makes `.INCLUDE` actually assemble something for the first time in Phase 9.

Parent plan: `brain/plans/2026-07-25-casm-phase9-include-processing.md`.
Prerequisite plans: WP43
(`brain/plans/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md`),
WP44
(`brain/plans/2026-07-25-casm-phase9-wp44-quoted-include-operand-grammar.md`),
WP45
(`brain/plans/2026-07-25-casm-phase9-wp45-physical-file-catalog-and-dynamic-source-loading.md`),
WP46
(`brain/plans/2026-07-26-casm-phase9-wp46-frame-stack-nested-traversal-and-cycle-detection.md`).

Taskwarrior: `579096d9-ce77-44db-96a9-c32654238949` (pending activation).

## User-Confirmed Scope Decisions

Two forks were resolved with the user before this plan was written:

1. **WP46 Scope Decision 3 (per-frame diagnostic echo save/restore) stays
   deferred.** WP47 does not add per-frame echo-buffer save/restore. It
   remains a reset-at-boundary design (blank "previous line" text
   immediately after a push/pop/root-transition), exactly as WP46 shipped
   it. Revisiting that trade-off is explicitly left for a later, separate
   conversation -- most likely once WP48's included-file diagnostics work
   has exercised real included-file failures and the actual cost/benefit is
   clearer.
2. **Pass 2 replay re-derives child identity defensively.** At each
   `.INCLUDE` site during Pass 2, the dispatcher calls `includeCatalogFind`
   again (a VMM-only lookup against the already-populated catalog, no
   filesystem I/O) and compares the resulting catalog index against the
   next recorded event's child index, mirroring the existing
   `emitCheckPassAgreement` precedent: a defensive internal-consistency
   check not believed reachable through any legitimate source today, kept
   because it turns silent corruption into a diagnosed failure instead of a
   trusted-but-wrong replay.

## Prerequisites and Baseline

- WP46 is complete and user-approved at CASM `0.1.48` build 1191. MAIN
  `$3400` + `$4000` (297 blocks -- headroom last measured at 292 bytes free
  before WP46's version-only increment).
- `include.s` (WP45) exports `includeCatalogInit`, `includeResolveDevice`,
  `includeCatalogFind`, `includeCatalogLoad`, and the record-field constants
  (`CASM_INCLUDE_PHYS_REC_*`). **`includeCatalogInit` has no production call
  site yet** -- only `tests/src/casm_catalog`/`tests/src/casm_frame` call it.
  The 8KB metadata VMM allocation therefore is not yet granted during a real
  `casm` run at all; WP47 is the first work package that makes it happen.
- `source.s` (WP46) exports `sourceFramePush` and `CasmFrameDepth`. A
  successful `includeCatalogLoad` returns a catalog index in `X` with the
  full 128-byte record in `CasmIncludeRecordStage`
  (`CASM_INCLUDE_PHYS_REC_START_LO/HI`, `..._LENGTH_LO/HI`) -- exactly the
  shape `tests/src/casm_frame`'s `runFrameTraversal` already converts into a
  `sourceFramePush` call (`tests/src/casm_frame/casm_frame.s:266-291`). WP47
  production dispatch performs the identical conversion.
- `casm.s`'s `crpDir` still intercepts `CASM_DIRECTIVE_INCLUDE` before
  `emitDirective` and unconditionally returns `CASM_DIAG_NOT_IMPLEMENTED`
  (`src/external/casm/casm.s:269-282`), unchanged since WP44.
- `CasmStmtLocLineLo/Hi/Column/FileId` (state.s, stamped by
  `diagStampStmtLoc` at the start of every statement) already give the
  parent's include-site line/column/top-level-file-id at the moment
  `crpDir` runs, with no new capture needed.
- The next free diagnostic number is `$37`
  (`CASM_DIAG_PHASE9_WP46_LAST = $36`).
- `sourceRewind` (called once, between Pass 1 and Pass 2, in `casm.s`'s
  `startPass1`) resets the live traversal cursor and
  `sourceResetTraversal`'s fields but does **not** touch `CasmFrameDepth` or
  anything WP47 adds. This is safe for `CasmFrameDepth` itself (guaranteed
  back to 0 by the automatic-pop cascade before Pass 1's own EOF is ever
  reached -- Pass 2 setup only runs after Pass 1 returns success), but WP47's
  new event-replay cursor is a different field with no existing reset call
  and must get one.

## Dependency Review and Reconciled Discrepancies

1. **`includeCatalogInit` has never run in a production build.** `start:`
   (`casm.s`) must call it once, alongside `symbolsInit`/`sourceInit`,
   before any statement can be parsed. Ordering: after `sourceLoad` (the
   metadata store is independent of the source store, but placing it
   immediately after keeps every VMM-store `Init` call grouped, matching
   the existing `symbolsInit` -> `sourceLoad` -> `sourceOpen` sequence's own
   style) and clearly before `startPass1`. A failure here is a normal
   `startInitFatal` case, identical in shape to every other init call.
2. **The event-log region is metadata the same allocation already reserves.**
   WP45's header comment (`include.s:13-17`) already documents the second
   4096 bytes of the 8KB `CasmIncludeMetaSlot` allocation as
   "reserved, untouched space for WP47's include-event log". No second VMM
   allocation is needed or approved; WP47 stays within the existing
   four-VMM-slot ceiling (source, symbols, reloc, include-metadata) WP43
   already budgeted.
3. **Include-event record shape must finally freeze** (WP43 proposed 16
   bytes but explicitly deferred the exact fields to "the implementing WP").
   The frozen contract requires correspondence on parent identity,
   include-site location, child identity, and event ordinal. "Parent
   identity" is not uniform: a `.INCLUDE` can occur while traversing a
   top-level root (`CasmFrameDepth == 0`, identified by `CasmSourceFileId`,
   0-7) or while already inside a nested frame (`CasmFrameDepth > 0`,
   identified by `CasmFrameCatalogIndex[CasmFrameDepth-1]`, a catalog
   index) -- WP45/WP46 deliberately never unified top-level files into the
   catalog (that unification is WP48's job), so the event record cannot
   assume a single namespace for "parent id". A one-byte parent-kind tag
   plus a one-byte parent-id resolves this without waiting for WP48. See
   Event Record ABI below for the frozen layout.
4. **Pass 1 must record an event on every `.INCLUDE` occurrence, including a
   catalog hit** (Phase 0C.19: "Repeated includes expand every time... no
   implicit include-once behavior"). Event recording therefore happens
   after `includeCatalogLoad` succeeds (hit or miss) and before
   `sourceFramePush`, not conditioned on whether the catalog load actually
   performed file I/O.
5. **Pass 2 must not call `includeCatalogLoad`.** That entry point can
   perform a transient file open/read/close on a catalog miss -- exactly
   the source-filesystem I/O the frozen contract forbids in Pass 2. Pass 2
   calls `includeCatalogFind` only (WP45, already filesystem-free: it scans
   the already-populated catalog). Every physical file a valid Pass 2 replay
   ever needs was already cataloged by Pass 1, since Pass 2 only replays
   events Pass 1 itself recorded.
6. **The event-log replay cursor is new state with no existing reset
   call.** `sourceRewind` does not know about it and should not be taught
   to -- `source.s` has no dependency on `include.s`, and this cursor is
   `include.s`'s own concept (parallel to how the catalog itself lives
   there). WP47 adds a small, standalone `includeReplayReset` export in
   `include.s`, called from `casm.s` immediately alongside `sourceRewind`
   in the existing Pass 2 setup block.
7. **`casmRunPass`'s `.INCLUDE` dispatch must itself be pass-mode-aware**,
   unlike every existing `crpDir`/`crpInsn` path, which relies on lower
   layers (`emitRawByte`, `parserParseExpressionValue`) to already be
   pass-mode-correct on their own. Loading a file and appending it to the
   source store must never happen twice (Pass 1 only); pushing a frame and
   advancing the live cursor must happen identically in both passes (the
   emitted bytes for statements inside the included file depend on it).
   The new dispatch branches once on `CasmPassMode`, matching the existing
   `crpLabel` precedent (`casm.s:248-250`) of a single explicit branch
   rather than duplicating the whole directive-handling structure.
8. **Where the bridging code lives**: WP46's own dependency finding 4
   established that `include.s` never imports `source.s`'s traversal
   internals and should not start, and that the caller bridges
   `includeCatalogLoad`'s output into `sourceFramePush`'s input. The only
   production caller is `casmRunPass` (`casm.s`) -- `tests/src/casm_frame`
   was always a stand-in for this exact call site
   (`tests/src/casm_frame/casm_frame.s:18-25`, "this harness's own driver
   loop... manually performs what WP47's real production dispatch will
   eventually do"). WP47 therefore adds this bridging logic directly in
   `casm.s`, not a new module -- consistent with `crpDir`/`crpLabel`
   already being casm.s's own per-statement-type dispatch, not delegated
   elsewhere.
9. **Replay mismatch must be checked at two points, not one.** Per-`.INCLUDE`
   correspondence (parent identity/location/child identity) catches a
   reordered or substituted event; a **separate** final check -- "every
   recorded event was consumed, no event remains unread" at Pass 2's own
   combined EOF -- catches a *missing* trailing event (Pass 2 traversed
   fewer includes than Pass 1 recorded). Both are required by the frozen
   contract ("missing, extra, or reordered events are fatal"); the final
   check is not implied by the per-site check alone, since a replay that
   simply never reaches its last `.INCLUDE` (e.g. an early return path)
   would otherwise go undetected.
10. **`includeCatalogFind`'s existing "not found" signal must not be
    misread as "no more work to validate".** Per-site correspondence in
    Pass 2 calls `includeCatalogFind` on the operand `.INCLUDE` already
    parsed identically to Pass 1 (same immutable source bytes); a genuine
    miss here (a physical record that existed by this point in Pass 1 no
    longer resolving in Pass 2) is itself impossible under the "catalog
    persists unchanged across both passes" invariant (Dependency Review
    finding 5) and is treated as `CASM_DIAG_INCLUDE_REPLAY_MISMATCH`, not a
    silently-tolerated miss.

## Event Record ABI

16-byte record (WP43's proposed size, now frozen), stored at
`CasmIncludeMetaSlot` offset `4096 + ordinal * 16` (the reserved half of the
existing 8KB allocation -- `include.s`'s own header comment already carved
this out). Fits entirely within one 64-byte `CasmVmmBuffer` transfer window
(unlike the 128-byte physical record, no dual-window read/write is needed).

| Offset | Field | Meaning |
| --- | --- | --- |
| 0 | `CASM_INCLUDE_EVENT_PARENT_KIND` | `0` = top-level root, `1` = nested frame |
| 1 | `CASM_INCLUDE_EVENT_PARENT_ID` | `CasmSourceFileId` (kind 0) or catalog index (kind 1) |
| 2 | `CASM_INCLUDE_EVENT_PARENT_LINE_LO` | `CasmStmtLocLineLo` at the `.INCLUDE` site |
| 3 | `CASM_INCLUDE_EVENT_PARENT_LINE_HI` | `CasmStmtLocLineHi` |
| 4 | `CASM_INCLUDE_EVENT_PARENT_COLUMN` | `CasmStmtLocColumn` |
| 5 | `CASM_INCLUDE_EVENT_CHILD_INDEX` | catalog index of the pushed child |
| 6-7 | reserved | zero-filled; not read by WP47 |
| 8-15 | reserved | zero-filled; not read by WP47 |

`CASM_INCLUDE_EVENT_SIZE = 16`. `CASM_INCLUDE_EVENT_CAPACITY = 128` (frozen
contract). `128 * 16 = 2048 <= 4096` reserved bytes -- 2048 bytes of the
metadata allocation remain unused by Phase 9, matching WP43's own reserved
budget note.

No start/length/span fields: unlike the physical catalog record, an event
never needs to carry the child's byte span -- Pass 2 always re-reads it fresh
from the (already-populated, unchanged) catalog via `includeCatalogFind`,
identically to how Pass 1 obtains it via `includeCatalogLoad`.

## Storage and Control-Flow Additions

### `include.s`

- `CasmIncludeEventCount` (BSS, 1 byte): number of events recorded (Pass 1)
  / total events to replay (Pass 2, copied from the Pass-1-final count --
  see below).
- `CasmIncludeEventCursor` (BSS, 1 byte): Pass-2-only replay read cursor.
- `includeEventRecord` (new export): append one event at
  `CasmIncludeEventCount`, incrementing it. Inputs: the six populated
  fields above, staged by the caller (same stage-then-copy discipline as
  every other `include.s` VMM writer). Fails with
  `CASM_DIAG_INCLUDE_EVENT_LOG_FULL` at capacity, checked before any write.
- `includeEventReplay` (new export): read the event at
  `CasmIncludeEventCursor`, compare its six fields against caller-supplied
  candidates (parent kind/id/line/column, child index), advance the cursor
  on a match. Fails with `CASM_DIAG_INCLUDE_REPLAY_MISMATCH` on any field
  disagreement or if the cursor is already at `CasmIncludeEventCount`
  (an extra `.INCLUDE` Pass 1 never recorded).
- `includeReplayReset` (new export): `CasmIncludeEventCursor = 0`. Also
  freezes `CasmIncludeEventCount` for replay purposes -- Pass 1's own final
  count is exactly the value Pass 2 must fully consume, so no separate
  "final count" field is needed; `CasmIncludeEventCount` is simply never
  written again after Pass 1 completes.
- `includeReplayFinalCheck` (new export): called once at Pass 2's own
  combined EOF (depth 0, top-level content exhausted). Fails with
  `CASM_DIAG_INCLUDE_REPLAY_MISMATCH` unless
  `CasmIncludeEventCursor == CasmIncludeEventCount` (Dependency Review
  finding 9 -- catches a missing trailing event).
- `includeCatalogInit` gains the two new fields to its existing reset (event
  count and cursor both to 0), so a single init call still fully prepares
  Phase 9 state for a fresh run.

### `casm.s`

- `start:` gains `jsr includeCatalogInit` / `bcs startInitFatal` after the
  existing `sourceLoad`/`sourceOpen`/`lexerInit` block (Dependency Review
  finding 1).
- The Pass 2 setup block (inside `startPass1`, right where `sourceRewind`
  already runs) gains `jsr includeReplayReset` / `bcs startFatalNear`.
- `crpDir`'s `CASM_DIRECTIVE_INCLUDE` case is replaced with a real
  dispatch (`crpInclude`, private): `diagSetLocFromStmt` still runs first
  (unchanged -- any failure below reports the `.INCLUDE` site itself); then
  branch on `CasmPassMode`:
  - **`CASM_PASS_MODE_MEASURE` (Pass 1)**: `includeCatalogLoad` (device =
    the current active identity's resolved device -- top-level root's
    device or the active frame's own resolved device, both already known
    from existing state -- and the operand pointer, `CasmIncludeFilename`);
    on success, stage and call `includeEventRecord` with the parent
    kind/id/line/column (from `CasmFrameDepth`/`CasmSourceFileId`/
    `CasmFrameCatalogIndex`/`CasmStmtLoc*`) and the returned catalog index;
    then convert `CasmIncludeRecordStage`'s start/length into
    `CasmValue0/1Lo/Hi` (identical arithmetic to
    `tests/src/casm_frame/casm_frame.s:277-286`) and call
    `sourceFramePush`.
  - **`CASM_PASS_MODE_EMIT` (Pass 2)**: `includeCatalogFind` with the same
    captured key (device + operand) to re-derive the child's catalog index
    (Scope Decision 2); call `includeEventReplay` with the same six-field
    tuple Pass 1 would have recorded, verifying correspondence; on a match,
    read the (unchanged since Pass 1) catalog record and call
    `sourceFramePush` identically to the Pass 1 path.
  - Both branches return through the same `jmp casmRunPass` continuation
    as every other successful directive.
- `casmRunPass`'s own EOF path (`crpDone`) is unchanged; the final replay
  check (`includeReplayFinalCheck`) is not called from `casmRunPass` itself
  (which returns per-statement) but from `startPass1`, once, immediately
  after Pass 2's `casmRunPass` loop reports clean EOF and before
  `emitCheckPassAgreement` -- mirroring how `emitCheckPassAgreement` itself
  is already a distinct post-loop check, not folded into the dispatcher.

### Determining "current active identity" for the parent device/kind/id

A single new private helper in `casm.s`: if `CasmFrameDepth == 0`, kind =
root, id = `CasmSourceFileId`, device = re-derived on demand by running
`CasmSourceNames[CasmSourceFileId]` (cli.s's own preserved original
spelling, prefix intact) through the same `includeResolveDevice`-shaped
`DOS_PARSE_PREFIX` resolution `include.s` already applies to a child's
spelling, defaulting to `CurrentDevice` when unprefixed -- exactly the
frozen contract's own "captures `CurrentDevice` during initial load"
wording, just evaluated lazily instead of stored eagerly, which is
observably identical as long as `CurrentDevice` cannot change during a
`casm` run (true today: nothing in the CASM binary calls a device-changing
OS routine). This confirms **no new storage or `source.s` change is
needed** -- resolved during planning by grep (`CasmSourceNames` already
retains each top-level file's full original spelling, `cli.s:38`), so this
risk is closed rather than left open for an early implementation check.
Otherwise (`CasmFrameDepth > 0`): kind = frame, id =
`CasmFrameCatalogIndex[CasmFrameDepth-1]`, device = that catalog record's
own stored device (a single `includeCatalogRead` of the active frame's own
catalog index).

## Constants and Diagnostics

- `common.inc`: `CASM_INCLUDE_EVENT_SIZE = 16`, `CASM_INCLUDE_EVENT_CAPACITY
  = 128`, the six field-offset constants above, and
  `CASM_INCLUDE_EVENT_PARENT_KIND_ROOT = 0` /
  `CASM_INCLUDE_EVENT_PARENT_KIND_FRAME = 1`, each with the established
  `.assert`-backed contiguity/size convention.
- Two new diagnostics, contiguous from `$37`:
  - `$37` `CASM_DIAG_INCLUDE_EVENT_LOG_FULL`
  - `$38` `CASM_DIAG_INCLUDE_REPLAY_MISMATCH`
  - `CASM_DIAG_PHASE9_WP47_LAST = $38`, with the matching contiguity assert
    and `diagPrintFatal`/`diagMessageLo`/`diagMessageHi` table entries.

## Scope

Included:

- `include.s`: event-log storage, `includeEventRecord`,
  `includeEventReplay`, `includeReplayReset`, `includeReplayFinalCheck`;
  `includeCatalogInit` extended to reset the new fields.
- `casm.s`: `includeCatalogInit` call site in `start:`; `includeReplayReset`
  call site alongside `sourceRewind`; real `crpDir`/`crpInclude` dispatch
  for both pass modes, replacing `CASM_DIAG_NOT_IMPLEMENTED`;
  `includeReplayFinalCheck` call site in `startPass1` after Pass 2's clean
  EOF.
- `common.inc`: event-record layout constants, `$37-$38` diagnostics.
- `diagnostics.s`: messages/table entries for `$37-$38`.
- A dedicated `tests/src/casm_include_pass2/` (or similarly named) harness
  exercising real two-pass assembly through genuine `.INCLUDE` statements,
  and `casm_overflow_test_d64` packaging.
- Task, plan, walkthrough, knowledge, changelog, and DOX synchronization.

Excluded:

- Anything from WP46 Scope Decision 3 (echo save/restore) -- reaffirmed
  deferred per this plan's own Scope Decision 1.
- Included-source diagnostic filename correctness beyond what already works
  (still CLI-index-based for top-level files; unifying it with the catalog,
  and bounded include-site tracebacks, are WP48's job).
- Any change to `includeCatalogLoad`, `includeCatalogFind`,
  `includeCatalogRead`/`Write`, or `sourceFramePush`'s existing ABI --
  WP47 is purely a new caller and new event-log storage, not a revision of
  WP45/WP46's already-verified routines.
- Device/name canonicalization changes (WP45, unaffected).

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/include.s` | event-log storage, `includeEventRecord`/`includeEventReplay`/`includeReplayReset`/`includeReplayFinalCheck`, extended `includeCatalogInit` |
| `src/external/casm/casm.s` | `includeCatalogInit`/`includeReplayReset` call sites, real `.INCLUDE` dispatch (`crpInclude`), `includeReplayFinalCheck` call site |
| `src/external/casm/common.inc` | event-record layout constants, diagnostics `$37-$38` |
| `src/external/casm/diagnostics.s` | messages and table bounds for `$37-$38` |
| `tests/src/casm_include_pass2/casm_include_pass2.s` | new dedicated harness (name to be finalized at implementation) |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | new fixtures, target, `casm_overflow_test_d64` packaging, likely another MAIN envelope bump for `casm` itself |
| `wiki/tasks/casm.md`, `brain/task.md` | synchronized task state |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md` | durable verified result at closeout |
| `brain/walkthroughs/2026-07-29-casm-phase9-wp47-ordered-include-graph-and-pass2-replay.md` | evidence and manual steps |
| `src/external/casm/AGENTS.md` | only if implementation changes a durable local contract |

## Harness Design and Test Matrix

Unlike WP44-46's standalone harnesses, WP47's defining behavior is
**real two-pass production assembly through `.INCLUDE`** -- the natural
harness is `casm` itself (the production binary), driven through real
fixture `.s` sources on `casm_overflow_test_d64`/`test_image_d64`, the same
style already used for other end-to-end CASM behavior (e.g. the Phase 8
relocation fixtures). A dedicated standalone harness is still added for the
event-log ABI itself (append/replay/mismatch/full, independent of a full
assembly run), mirroring `tests/src/casm_catalog`'s precedent of unit-testing
one module's ABI directly.

Standalone event-log harness cases:

- append then replay N events in order, all fields matching;
- replay mismatch on each field independently (wrong parent kind, id, line,
  column, child index);
- replay against an empty/exhausted log (extra `.INCLUDE`);
- `includeReplayFinalCheck` failing when events remain unconsumed;
- event log full at `CASM_INCLUDE_EVENT_CAPACITY` (128), checked before any
  write.

Real end-to-end `casm` fixture cases (assembled for real, output PRG
inspected/compared against an equivalent flattened source, per the parent
plan's own verification matrix):

- single-level include assembling correctly (labels, branches, and byte
  emission spanning the include boundary agree with a hand-flattened
  equivalent source);
- multi-level nested includes, same equivalence check;
- sequential reinclusion of the same physical file;
- forward and backward label/branch references crossing an include
  boundary in both directions;
- static and relocatable output equivalence (Phase 9 parent plan's own
  verification-matrix line);
- a deliberately corrupted replay path is not user-reachable through any
  legitimate source (matching `emitCheckPassAgreement`'s own precedent) --
  the mismatch diagnostics are exercised only through the standalone
  harness's synthetic event-log manipulation, not a real fixture.
- depth/cycle/catalog-full/event-log-full failures already proven by WP45/
  WP46 propagate correctly through the new real dispatch path (a thin
  confirmation pass, not new coverage of logic WP45/WP46 already verified).

## Atomic Increments

1. After explicit approval, mark WP47 active in Taskwarrior,
   `wiki/tasks/casm.md`, and `brain/task.md`.
2. Add `common.inc` event-record constants and diagnostics `$37-$38` with
   compile-time assertions; add `diagnostics.s` messages/table entries.
3. Add `include.s`'s event-log storage, `includeEventRecord`,
   `includeReplayReset`, extended `includeCatalogInit` -- append-only path
   first, independently testable before replay exists.
4. Add `includeEventReplay` and `includeReplayFinalCheck`.
5. Add the standalone event-log harness; verify append/replay/mismatch/full
   cases before touching `casm.s`.
6. Wire `casm.s`: `includeCatalogInit`/`includeReplayReset` call sites,
   real `crpInclude` dispatch for both pass modes (including the on-demand
   root-device re-derivation helper), `includeReplayFinalCheck` call site.
7. Add real end-to-end `.INCLUDE` fixtures on `casm_overflow_test_d64`/
   `test_image_d64`; measure and, if needed, request the smallest adequate
   MAIN envelope bump before proceeding (established precedent: WP44-46 all
   needed one).
8. Run static, narrow, regression, image, artifact, and no-change-build
   checks; create the walkthrough and present runtime instructions to the
   user.
9. After user runtime verification and explicit completion approval only,
   increment CASM's version-only stage, rebuild, synchronize closeout
   records, and complete WP47. Do not activate WP48 automatically.

## Failure and Cleanup

- `includeEventRecord`'s capacity check runs before any VMM write; a
  rejected append leaves `CasmIncludeEventCount` unchanged.
- `includeEventReplay`'s comparison runs entirely from already-read data
  (the candidate tuple plus one read event record); a mismatch leaves
  `CasmIncludeEventCursor` unchanged and does not advance traversal.
- A Pass 1 `.INCLUDE` failure (catalog/depth/cycle/event-log-full) aborts
  the pass exactly as every other Pass 1 failure does today (`startFatal`
  path) -- no partial event or frame state needs manual unwinding beyond
  what the central resource cleanup sweep already performs.
- A Pass 2 replay-mismatch failure is a genuine internal-consistency defect
  (Scope Decision 2's own rationale), not a user-facing source error in any
  reachable case; it still routes through the same `startFatal` path with
  its own diagnostic, exactly like `emitCheckPassAgreement`'s existing
  disagreement path.

## Verification

- `git diff --check` and all relevant ca65 compile-time assertions pass.
- The standalone event-log harness passes its complete matrix.
- Real end-to-end `.INCLUDE` fixtures produce byte-identical output PRGs
  (static and relocatable) to their hand-flattened equivalents, run by the
  user in the supported local emulator (never the broken `c64-testing` MCP
  or a web emulator).
- Existing standalone lexer, parser, expression, symbol, VMM, relocation,
  include-grammar, catalog, and frame-stack regression targets build without
  behavior changes.
- Two consecutive `cmake --build build --target casm` builds hold the same
  `BUILD_CASM` value after the first content-driven increment.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` build clean.
- Confirm zero Pass 2 source-filesystem opens: a targeted check (either a
  code-path audit or an instrumented count, removed before closeout, per
  WP46's own precedent of temporary instrumentation) that
  `inputStreamOpen`/`fileio.s` open calls are not reached during Pass 2's
  `.INCLUDE` handling.

## Documentation, Task, and DOX Updates

- Keep Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` synchronized
  at activation, verification, and closeout.
- Record stable implementation findings in `brain/KNOWLEDGE.md`.
- User-visible change in `CHANGELOG.md` (`.INCLUDE` becomes real for the
  first time -- the single externally observable Phase 9 milestone this WP
  delivers).
- Re-read the root, `src`, `src/external`, `src/external/casm`, `tests`,
  `wiki`, and `wiki/tasks` DOX chain before implementation and perform a
  closeout DOX pass.
- Update `src/external/casm/AGENTS.md` only if implementation establishes or
  changes a durable local contract (the event-record layout, once frozen by
  real code rather than this plan alone).

## Stop Conditions

Stop, amend this plan, and request renewed approval if:

- the per-`.INCLUDE` correspondence check or the final event-count check
  cannot be expressed without duplicating `include.s`/`source.s` internals
  inside `casm.s`;
- code/BSS growth threatens the current `$4000` MAIN envelope beyond a
  small, presentable amendment (expected, per every prior Phase 9 WP);
- Pass 2 is found to require any source-filesystem operation to replay
  correctly (would contradict the frozen contract outright);
- flattened-vs-included output disagrees for any fixture in the
  verification matrix;
- any existing parser, lexer, source, catalog, frame-stack, or
  diagnostic-rendering behavior regresses.

## Completion Gate

WP47 is complete only after this plan is explicitly approved, implementation
and the full verification matrix pass, the user performs the runtime
walkthrough, the user explicitly approves completion, CASM advances its
version-only stage with a stable no-change build, and all durable records
agree. Completion does not activate WP48.

## Progress

- 2026-07-29: Drafted. User confirmed both scope forks (keep WP46 Scope
  Decision 3 deferred; Pass 2 replay re-derives and defensively compares
  child identity rather than trusting the event log alone) before this plan
  was written. Grep-confirmed during drafting that `CasmSourceNames`
  (cli.s) already retains each top-level file's original spelling with any
  device prefix intact, closing what would otherwise have been an open
  implementation risk around root-parent device resolution -- no new
  `source.s` storage is needed; the device is re-derived on demand.
  Awaiting approval to activate.
- 2026-07-29: User approved implementation. Two fixture decisions confirmed
  before increment 1: end-to-end include fixtures are packaged on
  `casm_overflow_test_d64` (parent plan finding 10; also genuinely
  exercises device inheritance under the user's two-drive VICE setup, where
  unprefixed children resolve to the fixture disk's device rather than the
  boot device), and flattened equivalence is proven by a CASM-vs-CASM
  output diff (assemble the `.INCLUDE` version and a hand-flattened
  equivalent, compare the two output PRGs) rather than a hand-derived
  `.ref` -- non-circular for the property under test, since an opcode-table
  defect would affect both runs identically and only an include-traversal
  defect can make them differ.
  DOX chain re-read. The `.s`-suffix contract
  (`src/external/casm/AGENTS.md`, `CMakeLists.txt:837-845`) applies to
  these fixtures since they are real CASM assembly source, paired with
  lowercase `cc1541 -f` disk names and uppercase in-source operands per the
  established case-pairing convention (`-f "casmfrc1"` <->
  `.INCLUDE "CASMFRC1"`). WP46's bare-name deviation was specific to its
  own harness fixtures and is not carried forward.
  Activated WP47 in Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md`.
- 2026-07-29 (increments 2-7): Implemented. `common.inc` froze the 16-byte
  event record (`CASM_INCLUDE_EVENT_*`, base anchored to the catalog's own
  extent so the two regions can never silently overlap) and diagnostics
  `$37-$38`; `diagnostics.s` gained both messages and the extended table
  bound. `include.s` gained the event log (`includeEventRecord`,
  `includeEventReplay`, `includeReplayReset`, `includeReplayFinalCheck`,
  private `includeEventOffset`), an extended `includeCatalogInit`, and a
  factored `includeCatalogLookup` -- the load-free half of
  `includeCatalogLoad`, so Pass 2 has an entry point that is *structurally*
  incapable of filesystem I/O rather than merely trusted not to do it.
  `casm.s` gained the first production `.INCLUDE` dispatch (`crpInclude`,
  `crpParentIdentity`, `crpStageEvent`), `includeCatalogInit`/
  `includeReplayReset`/`includeReplayFinalCheck` call sites, and 4 bytes of
  named dispatch scratch.
- 2026-07-29 (deviation from plan, user-approved): WP47's end-to-end
  fixtures ship on a NEW `casm_include_test_d64` image rather than joining
  `casm_overflow_test.d64` as originally planned. Adding them there left
  only ~10 free blocks (WP34's combined-cap pair alone occupies 277), and
  this WP's verification *writes* eight output PRGs back to the disk it
  reads from -- no room to run it, let alone re-run after a fix. The new
  image carries `casm.prg`, `comp.prg`, and the 12 fixtures, leaving 574
  blocks free. `casm_overflow_test.d64` returns to ~22 free blocks and
  still gains the `test_casm_event` harness.
- 2026-07-29 (defect found in review, pre-runtime): `crpParentIdentity`'s
  nested-parent path used `tax` to take the frame index from A, but A had
  already been overwritten by the parent-kind constant -- it would have
  indexed `CasmFrameCatalogIndex[0]` at every depth. Coincidentally correct
  at depth 1 (the only depth a two-level fixture reaches), and wrong from
  depth 2 up, where it would inherit the wrong parent's device. Fixed to an
  explicit `ldx CasmFrameDepth`. This is the same class of
  cancelling/coincidental correctness WP46's own walkthrough recorded, and
  is exactly why the three-level `casmip2` fixture exists.
- 2026-07-29 (MAIN envelope): `$4000` -> `$4200`. Measured: `$4000`
  overflowed by 104 bytes, `$4100` still overflowed by 78, putting the true
  minimum at 16,718 bytes. `$4200` (16,896) leaves 178 bytes headroom --
  the smallest round-page step above the minimum, matching this line's own
  precedent. `test_casm_catalog` needed a matching `$1B00` -> `$1C00` bump
  (it links `include.s` whole, so it carries the event-log code it never
  calls); `test_casm_frame`, `test_casm_include`, `test_casm_pass1`, and
  `test_casm_passcheck` all still fit unchanged.
- 2026-07-29 (static verification): Zero-Pass-2-source-I/O proven
  structurally rather than by instrumentation. `inputStreamOpen` (the only
  source-file open) has exactly two call sites, both in `source.s`: inside
  `sourceLoad` (called once from `start:`, before Pass 1) and inside
  `sourceAppendFile` (whose only caller anywhere is `includeCatalogLoad`,
  `include.s:611`). `includeCatalogLoad`'s only production call site is
  `casm.s:398`, inside `crpInclude`'s `CASM_PASS_MODE_MEASURE` branch. Pass
  2 routes to `includeCatalogLookup`, from which no open is reachable at
  all. Full build clean, `git diff --check` clean, `casm` build 1194 stable
  across a no-change rebuild, all four disk images build. `build/casm.prg`
  is 18,301 bytes, load address `$3800`, R6 footer `00 38 01 08 52 36`
  (base `$3800`, 2049 relocation entries). Awaiting the user's runtime
  verification before the version-only completion increment.
- 2026-07-29 (runtime verification): **User confirmed all tests pass.**
  `test_casm_event`'s 15 cases pass, and all four end-to-end pairs report
  `FILES COMPARE OK` -- the `.INCLUDE` form and its hand-flattened
  equivalent assemble to byte-identical output PRGs across single-level
  (labels and branches crossing the boundary in both directions),
  three-level nested, sequential-reinclusion, and relocatable
  (relocation-table-inclusive) cases. Passed on the first runtime attempt,
  unlike WP46, whose first run failed every real-traversal case: WP46 had
  already absorbed the hard traversal work, so WP47 built on a proven
  engine, and its one genuine defect was caught in review before running.
  Awaiting explicit completion approval before the version-only increment.
- 2026-07-29 (completion): **User approved completion.** Applied the sole
  authorized source change, `VERSION_STAGE` 48 -> 49; the content-hash build
  advanced to 1196 and a second build held stable. Full build clean,
  `git diff --check` clean, all four disk images pass. `build/casm.prg` is
  18,305 bytes, load address `$3800`, R6 footer `00 38 02 08 52 36` (base
  `$3800`, 2050 relocation entries). Closed WP47 in Taskwarrior,
  `wiki/tasks/casm.md`, and `brain/task.md`; durable findings recorded in
  `brain/KNOWLEDGE.md`; user-visible entry added to `CHANGELOG.md`; DOX
  closeout pass updated `src/external/casm/AGENTS.md` (the WP45 "no
  production call site / do not describe `.INCLUDE` as operational" contract
  was stale, and the Pass-2-must-not-call-`includeCatalogLoad` rule is now
  recorded as a durable local contract). **WP47 complete.** WP48 is
  unblocked in Taskwarrior by dependency resolution but deliberately not
  activated.
