---
feature: casm-phase9-wp48-included-source-diagnostics-and-tracebacks
created: 2026-07-29
status: approved-active
---

# Plan: CASM Phase 9 WP48 - Included-Source Diagnostics and Tracebacks

## Objective

Fix a real, currently-shipping defect: a diagnostic raised inside an
included file prints the **wrong filename** today, because nothing tracks
"which physical file is this byte actually from" once traversal enters a
nested frame. Replace the CLI-only top-level filename lookup with one that
also resolves catalog identity, and add a bounded include-site traceback
("included from `X` line `L` column `C`", innermost to root) so a failure
several levels deep can be traced back to its root cause.

Parent plan: `brain/plans/2026-07-25-casm-phase9-include-processing.md`.
Prerequisite plans: WP43-WP47, all complete. WP47's completion put CASM at
`0.1.49` build 1196 with `.INCLUDE` fully operational end-to-end; this plan
was written and reviewed with the user immediately after that closeout.

Branch: `feature/casm-phase9-wp48`, created from `feature/casm-stage9`
(which already carries WP47).

Taskwarrior: `797bb460-6d82-453c-8f55-7aa53d2eb095` (pending activation).

## User-Confirmed Scope Decisions

Three forks were resolved with the user before this plan was written:

1. **The wrong-filename gap is in scope and confirmed as the right target.**
   `CasmSourceFileId` (and everything derived from it -- token record
   `FILE_ID`, lookahead `FileId`, diagnostic-location `FileId`) tracks only
   the top-level file index and is never updated while a nested frame is
   active (`srCheckFileBoundary`, the only writer, is skipped whenever
   `CasmFrameDepth > 0`). A diagnostic raised inside an included file
   therefore names whichever top-level file was active when the outermost
   `.INCLUDE` was entered -- silently wrong, not merely incomplete. This is
   exactly the defect WP48's charter ("replace CLI-only filename lookup
   with catalog lookup") already targets.
2. **Provenance is re-tagged by bit-packing kind+id into the existing
   `FILE_ID` byte**, not by growing the token record. Root index (0-7) and
   catalog index (0-31) both fit in 7 bits: bit 7 flags kind (`0` = root,
   `1` = frame), bits 0-6 hold the id. This preserves "no token-record
   growth" (a WP44 constraint already on record) at the cost of changing
   what the existing `FILE_ID` byte *means* everywhere it is read -- an
   approved semantic amendment to an already-stable-ABI field, not a size
   change.
3. **The traceback's per-frame site column gets one new small array**
   (`CasmFrameSiteColumn`, 16 bytes) rather than reusing
   `CasmFrameResumeColumn`. The site line is free -- `CasmFrameResumeLineLo/
   Hi` (saved at push time) already equals the `.INCLUDE` statement's own
   line, because `ppsInclude`'s dedicated scanner leaves the statement's
   trailing NEWLINE token unconsumed at push time (verified: `lexerScanIncludeOperand`'s
   own comment, "leaving NEWLINE/EOF buffered"). The site *column* is not
   free: `CasmFrameResumeColumn` is where parsing resumes after the whole
   statement (post-quoted-filename), not the `.INCLUDE` keyword's own start
   column. Reusing it would show a less precise location under a field name
   that says "resume", not "site" -- the user chose the small new array for
   clean separation of concerns over on the smallest-footprint option.

## Prerequisites and Baseline

- WP47 is complete and user-approved at CASM `0.1.49` build 1196. MAIN
  `$3400` + `$4200` uses 16,718 of 16,896 measured bytes: 178 bytes free.
- `.INCLUDE` is fully operational: `casmRunPass`'s `crpInclude` dispatches
  real Pass 1 load/push/record and Pass 2 lookup/replay/push, verified by a
  full runtime matrix (`tests/src/casm_event`, four end-to-end fixture
  pairs on `casm_include_test_d64`).
- `diagPrintSourceContext` (`diagnostics.s`) prints a location's filename by
  indexing `cliSourceSlotLo/Hi` directly with `CasmDiagLocFileId`, gated on
  `CasmSourceCount >= 2` (a WP35 convenience: stay silent for the common
  single-top-level-file case). Both the index and the gate are wrong for an
  included file: the index names the wrong file, and the gate can suppress
  the filename entirely when exactly one top-level file was given even
  though the diagnostic is about a *different*, included file.
- `diagnostics.s` already imports from `source.s` (`sourceDrainLineTail`,
  several `CasmDiag*` echo fields) -- extending that import list with the
  WP46 frame-stack fields is not a new dependency edge, only a wider
  existing one. `diagnostics.s` has no import from `include.s` today; that
  edge is new, and non-circular (`include.s` has zero diagnostics.s imports
  in production; only two test-harness stubs reference `diagPrintFatal` by
  name for the linker, matching `casm_catalog.s`'s established precedent).
- The next free diagnostic number is `$39` (`CASM_DIAG_PHASE9_WP47_LAST =
  $38`). This plan does not expect to need it -- see Diagnostics below.

## Dependency Review and Reconciled Discrepancies

1. **The wrong-filename defect is live in the shipped `0.1.49` build, not
   hypothetical.** `srCheckFileBoundary` is the only writer of
   `CasmSourceFileId`, and `sourceRefill` explicitly skips calling it
   whenever `CasmFrameDepth > 0` (WP46's own depth-0-only gate, correct for
   its own purpose -- top-level file transitions are a depth-0 concept).
   Nothing else advances or overrides that field while a nested frame is
   active, so every byte fetched inside an included file is currently
   tagged with its *parent* top-level file's index, all the way down.
2. **Provenance capture happens on every single byte, not just at
   boundaries.** `sourceFetchPhysical`'s `sfpHaveByte`/`sfpEof` (source.s)
   write `CasmSourceResultFileId` on every fetch. The kind+id packing
   computation therefore runs on this hot path unconditionally; it must
   stay cheap (a `CasmFrameDepth` zero/nonzero branch plus, when nonzero,
   one array read and an OR with the kind flag -- a handful of cycles, not
   a new loop).
3. **The gate for printing a filename must change, not just the lookup.**
   Today's gate (`CasmSourceCount >= 2`) is a WP35 convenience for the
   *top-level* multi-file case and must be preserved for it (unaffected
   single-file assemblies must stay byte-identical). But it must no longer
   be the *only* condition: whenever the packed kind is "frame", the
   filename prints unconditionally, regardless of `CasmSourceCount` --
   Phase 0C.19 requires included-file diagnostics to always name their
   file, independent of how many top-level sources were given.
4. **The traceback needs no new capture at raise time -- it reads live,
   still-intact state.** `exitFatal` calls `diagPrintFatal` *before*
   `resourcesCleanup`, and nothing pops a frame or resets `CasmFrameDepth`
   between a failure site and that call (a rejected `sourceFramePush`
   changes no state; a mid-file failure never reaches the automatic-pop
   path, which only fires on real EOF). The frame stack at print time is
   therefore exactly the active chain that produced the diagnostic. This
   removes an entire category of "snapshot the chain at raise time"
   complexity the frozen contract's wording might otherwise suggest.
5. **A traceback line names the *parent* at each level, using the same
   (kind, id) identity resolution as the primary location.** For the frame
   at 1-based depth `D`, the values saved at array index `D-1`
   (`CasmFrameResumeLineLo/Hi`, the new `CasmFrameSiteColumn`) describe the
   position *in that frame's own parent* where the `.INCLUDE` occurred; the
   parent's own identity is root (if `D == 1`) or `CasmFrameCatalogIndex[D-2]`
   (if `D > 1`). This is one shared per-level computation, not a special
   case for the root end of the chain.
6. **A new cross-module edge, but not a new dependency direction.**
   Printing a catalog file's name requires `includeCatalogRead` and
   `CasmIncludeRecordStage` (`include.s`). `diagnostics.s` has no existing
   import from `include.s`, so this is new, but it introduces no cycle:
   `include.s` never imports from `diagnostics.s` in production. Per the
   frozen contract ("diagnostic rendering performs no filesystem I/O"),
   this is safe -- `includeCatalogRead` only reads the already-populated
   VMM metadata store, never the filesystem.
7. **`test_casm_pass1` and `test_casm_passcheck` do not currently link
   `include.s`.** They link `diagnostics.s` (whole-object linking, per this
   build's established pattern) but have never needed `include.s`, since
   nothing in their own harness code touches it. Once `diagnostics.s` gains
   a real `.import includeCatalogRead`/`CasmIncludeRecordStage` reference,
   both harnesses need `include.s` added to their module list or the link
   fails with an undefined symbol -- and, per every prior WP's own
   experience, adding that module's code+BSS will very likely force an
   envelope bump for both (they currently sit at `$4000`, comfortably below
   production's `$4200`, precisely because they have never carried
   `include.s`'s own footprint before).
8. **A traceback-rendering failure must not mask the primary diagnostic.**
   `diagPrintFatal`/`diagPrintSourceContext` are `rts`-only routines with no
   caller checking their own success -- `exitFatal` calls `diagPrintFatal`
   unconditionally and moves on to cleanup regardless. If `includeCatalogRead`
   fails while rendering one traceback line (a VMM transfer failure, not
   believed reachable given the store is already fully populated and
   read-only at this point), that failure must be handled locally -- skip
   or placeholder that one line -- never propagated in a way that could
   interfere with the primary message already printed or with the
   unconditional cleanup/exit that follows.
9. **No new `CASM_DIAG_*` diagnostic is needed for this work package.**
   Every WP44-WP47 diagnostic already covers its own failure mode (grammar,
   catalog, depth/cycle, event log, replay). WP48 is purely a rendering
   improvement over diagnostics that already fire correctly; the one
   internal failure mode identified above (finding 8) is handled by a local
   graceful fallback, not a new diagnostic code.

## Provenance Encoding

Reuse the existing `CASM_TOKEN_REC_FILE_ID` byte (and everything that
copies it downstream: `CasmSourceResultFileId`, `CasmLookaheadFileId`,
`CasmDiagLocFileId`, `CasmStmtLocFileId`) with a new bit-packed meaning:

| Bits | Meaning |
| --- | --- |
| 7 | `0` = top-level root, `1` = included frame (mirrors `CASM_INCLUDE_EVENT_PARENT_KIND_ROOT/FRAME`'s own root-vs-frame split, WP47) |
| 6-0 | root: `CasmSourceFileId` (0-7); frame: catalog index (0-31) |

New `common.inc` constants: `CASM_DIAG_FILEID_FRAME_FLAG = $80`,
`CASM_DIAG_FILEID_ID_MASK = $7F`. No record size or offset changes; the
existing `CASM_TOKEN_REC_SIZE = 39` assertion is untouched.

`sourceFetchPhysical` (source.s) computes the packed byte in place of the
current `lda CasmSourceFileId` at `sfpHaveByte`/`sfpEof`:

```
depth == 0:  packed = CasmSourceFileId                    (bit 7 clear)
depth  > 0:  packed = $80 | CasmFrameCatalogIndex[depth-1]
```

Every downstream copy (`lexerFill` into `CasmLookaheadFileId`/token
`FILE_ID`, `diagStampStmtLoc` into `CasmStmtLocFileId`, `diagSetLocFrom*`
into `CasmDiagLocFileId`) is unchanged code -- they already copy the byte
verbatim; only its meaning changes, at the one point it is produced.

## Rendering Changes

### `diagPrintIncludeIdentity` (private, new, `diagnostics.s`)

Shared by the primary-location filename line and every traceback line.
Given a packed (kind, id) byte, prints the corresponding name:

- root: existing behavior -- `cliSourceSlotLo/Hi[id]`.
- frame: `includeCatalogRead(id)`, then print
  `CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME` (the original,
  unfolded spelling already stored there per WP45). On a read failure
  (finding 8), print a fixed placeholder (`<INCLUDE?>` or similar) instead
  of propagating the error.

### `diagPrintSourceContext` changes

- Decode `CasmDiagLocFileId`'s kind bit. Print the `IN FILE` line when
  kind is frame (unconditionally) **or** kind is root and
  `CasmSourceCount >= 2` (existing WP35 gate, preserved for the top-level
  case). Delegate the actual name lookup to `diagPrintIncludeIdentity`.
- After the existing location/caret rendering, call the new traceback
  renderer (below) when `CasmFrameDepth > 0`.

### `diagPrintIncludeTraceback` (private, new, `diagnostics.s`)

For `D` from `CasmFrameDepth` down to `1`:

- Resolve the parent identity: root if `D == 1`, else
  `CasmFrameCatalogIndex[D-2]` tagged as frame.
- Print `"INCLUDED FROM "`, the parent's name (via
  `diagPrintIncludeIdentity`), `" LINE "`, `CasmFrameResumeLineLo/Hi[D-1]`,
  `" COLUMN "`, `CasmFrameSiteColumn[D-1]`, newline.

Bounded automatically by `CasmFrameDepth`'s own `CASM_INCLUDE_MAX_DEPTH`
(16) cap -- no separate bound needed. `CasmFrameDepth == 0` (a root-only
diagnostic) makes the loop a no-op, satisfying "root-only diagnostics print
no traceback" without a special case.

### `sourceFramePush` change (`source.s`)

Add one line: capture `CasmStmtLocColumn` into the new
`CasmFrameSiteColumn[depth]` array slot at push time, alongside the
existing resume-state save. `sourceFramePush`'s existing call signature
(`A` = catalog index; `CasmValue0/1Lo/Hi` = span) is unchanged -- this is
an added internal read of an already-global field (`state.s`'s
`CasmStmtLocColumn`), not a new input parameter.

## Constants and Diagnostics

- `common.inc`: `CASM_DIAG_FILEID_FRAME_FLAG = $80`,
  `CASM_DIAG_FILEID_ID_MASK = $7F`, both with `.assert`-backed bit-pattern
  checks matching this codebase's established convention.
- No new `CASM_DIAG_*` diagnostic values (Dependency Review finding 9).

## Scope

Included:

- `source.s`: `CasmFrameSiteColumn` (16-byte array); `sourceFramePush`
  extended to populate it; the packed-provenance computation in
  `sourceFetchPhysical`.
- `common.inc`: the two packing constants.
- `diagnostics.s`: `diagPrintIncludeIdentity`, `diagPrintIncludeTraceback`,
  the corrected `diagPrintSourceContext` gate/lookup, new imports from
  `include.s` and the extended import list from `source.s`.
- `CMakeLists.txt`: add `include.s` to `test_casm_pass1`/
  `test_casm_passcheck`'s module lists; measure and request whatever
  envelope bump results for both, and for production `casm` (178 bytes
  headroom is tight for this WP's own new code).
- A dedicated fixture/harness proving wrong-file-name-fixed and traceback
  rendering, likely extending `tests/src/casm_frame` (which already links
  `include.s` + `diagnostics.s` + real echo-buffer verification) rather
  than a new standalone harness, plus real end-to-end fixtures on
  `casm_include_test_d64` that deliberately fail inside a nested include to
  exercise the rendering path live.
- Task, plan, walkthrough, knowledge, changelog, and DOX synchronization.

Excluded:

- Any change to `includeCatalogLoad`/`includeCatalogLookup`/
  `includeEventRecord`/`includeEventReplay`/`sourceFramePush`'s existing
  call signature, or any Pass 1/Pass 2 traversal behavior -- WP48 is
  rendering-only.
- WP46 Scope Decision 3 (per-frame diagnostic echo save/restore) --
  reaffirmed deferred in WP47 and not reopened here.
- Any new `CASM_DIAG_*` value (finding 9).

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/source.s` | `CasmFrameSiteColumn`; `sourceFramePush` populates it; packed provenance in `sourceFetchPhysical` |
| `src/external/casm/common.inc` | `CASM_DIAG_FILEID_FRAME_FLAG`/`ID_MASK` |
| `src/external/casm/diagnostics.s` | `diagPrintIncludeIdentity`, `diagPrintIncludeTraceback`, corrected `diagPrintSourceContext`, new `include.s`/`source.s` imports |
| `CMakeLists.txt` | `include.s` added to `test_casm_pass1`/`test_casm_passcheck`; envelope bumps as measured |
| `tests/src/casm_frame/casm_frame.s` (or a new dedicated harness, decided during implementation) | wrong-filename-fixed and traceback-rendering coverage |
| `cmake/GenerateCasmTestFixtures.cmake` | new fixtures: nested-include failures for live rendering proof |
| `wiki/tasks/casm.md`, `brain/task.md` | synchronized task state |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md` | durable verified result at closeout |
| `brain/walkthroughs/2026-07-29-casm-phase9-wp48-included-source-diagnostics-and-tracebacks.md` | evidence and manual steps |
| `src/external/casm/AGENTS.md` | DOX update: FILE_ID's packed meaning becomes a durable local contract |

## Harness Design and Test Matrix

Static/unit coverage (harness choice finalized during implementation --
extending `tests/src/casm_frame` is the leading candidate since it already
links every needed module and already verifies real echo-buffer state):

- a diagnostic raised on the first statement of a once-nested included
  file names that file, not the parent;
- the same two levels deep;
- the traceback for a two-level failure shows exactly two lines, in
  innermost-to-root order, each naming the correct file and the correct
  `.INCLUDE` site line/column (not the resume column);
- a root-only diagnostic (no active frame) prints no traceback -- unchanged
  from today;
- a single-top-level-file assembly with no `.INCLUDE` at all still prints
  no `IN FILE` line -- WP35 behavior preserved byte-for-byte;
- a single-top-level-file assembly *with* an `.INCLUDE` whose failure is in
  the included file prints the `IN FILE` line even though
  `CasmSourceCount == 1` -- the fixed gate;
- depth-16 traceback (maximum nesting) renders all 16 lines without
  overrunning any buffer;
- sequential reinclusion: a failure in the second, cache-hit occurrence of
  a repeated include names that occurrence's own site line, not the first
  occurrence's.

Real end-to-end coverage on `casm_include_test_d64`: at least one fixture
pair deliberately fails inside a nested include (e.g. an unresolvable
symbol), so the user's runtime walkthrough sees real rendered output --
filename and traceback -- for a genuine failure, not only the harness's
programmatic assertions.

## Atomic Increments

1. After explicit approval, mark WP48 active in Taskwarrior,
   `wiki/tasks/casm.md`, and `brain/task.md`.
2. Add `common.inc` packing constants with compile-time assertions.
3. Add `CasmFrameSiteColumn` and extend `sourceFramePush` (source.s);
   change `sourceFetchPhysical`'s provenance capture to the packed form.
4. Add `diagPrintIncludeIdentity` and the corrected `diagPrintSourceContext`
   gate/lookup (diagnostics.s); verify the single-file, no-include case is
   byte-identical to today before proceeding.
5. Add `diagPrintIncludeTraceback` and wire it into
   `diagPrintSourceContext`.
6. Add `include.s` to `test_casm_pass1`/`test_casm_passcheck`'s module
   lists; measure and request the smallest adequate envelope bump for both
   and for production `casm`.
7. Add/extend the static harness coverage; add real failing-inside-include
   end-to-end fixtures on `casm_include_test_d64`.
8. Run static, narrow, regression, image, artifact, and no-change-build
   checks; create the walkthrough and present runtime instructions to the
   user.
9. After user runtime verification and explicit completion approval only,
   increment CASM's version-only stage, rebuild, synchronize closeout
   records, and complete WP48. Do not activate WP49 automatically.

## Failure and Cleanup

- The packed-provenance change touches a hot path
  (`sourceFetchPhysical`) but adds no new failure mode -- it is a pure
  computation, no OS call, no allocation.
- `diagPrintIncludeIdentity`'s catalog-read failure path never propagates a
  diagnostic of its own (finding 8); it degrades to a placeholder string
  and returns normally, so `diagPrintFatal`'s caller-blind `rts` contract
  is preserved exactly as today.
- No new resource (file handle, VMM allocation) is acquired by this WP.

## Verification

- `git diff --check` and all relevant ca65 compile-time assertions pass.
- The extended/new static harness passes its complete matrix, run by the
  user in the supported local emulator (never the broken `c64-testing` MCP
  or a web emulator).
- Existing standalone lexer, parser, source, catalog, frame, and
  include-event regression targets build without behavior changes.
- `test_casm_pass1`/`test_casm_passcheck` (now linking `include.s` for the
  first time) fit their measured envelope, or a measured overflow is
  presented to the user before any amendment.
- Two consecutive `cmake --build build --target casm` builds hold the same
  `BUILD_CASM` value after the first content-driven increment.
- `image_d64`, `test_image_d64`, `casm_overflow_test_d64`, and
  `casm_include_test_d64` build clean.
- A single-top-level-file, no-`.INCLUDE` assembly's diagnostic output is
  confirmed byte-identical to the pre-WP48 build (regression guard for the
  WP35 gate preservation).

## Documentation, Task, and DOX Updates

- Keep Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` synchronized
  at activation, verification, and closeout.
- Record stable implementation findings in `brain/KNOWLEDGE.md`.
- User-visible entry in `CHANGELOG.md` (diagnostics inside an included file
  now name the right file and show a traceback -- the fix to a real,
  previously-silent defect).
- Re-read the root, `src`, `src/external`, `src/external/casm`, `tests`,
  `wiki`, and `wiki/tasks` DOX chain before implementation and perform a
  closeout DOX pass.
- Update `src/external/casm/AGENTS.md`: the packed `FILE_ID` meaning
  becomes a durable local contract (any future code reading `FILE_ID`/
  `CasmSourceResultFileId`/`CasmLookaheadFileId`/`CasmDiagLocFileId`/
  `CasmStmtLocFileId` must decode the kind bit, not assume a raw top-level
  index).

## Stop Conditions

Stop, amend this plan, and request renewed approval if:

- code/BSS growth threatens the current `$4200` MAIN envelope beyond a
  small, presentable amendment (expected to be needed, per every prior
  Phase 9 WP's own experience, but the exact size is unmeasured until
  implementation);
- `test_casm_pass1`/`test_casm_passcheck`'s addition of `include.s` causes
  an envelope growth disproportionate to this WP's own rendering code
  (would suggest an unexpected coupling, not a simple size increase);
- the packed `FILE_ID` scheme cannot represent every real id (would
  contradict the 7-bit-fits-both-namespaces analysis above and needs
  re-derivation, not silent truncation);
- a traceback-rendering failure is found to interfere with the primary
  diagnostic or with cleanup/exit in any case;
- any existing parser, lexer, source, catalog, frame-stack, or
  diagnostic-rendering behavior regresses, including the WP35
  single-top-level-file silence.

## Completion Gate

WP48 is complete only after this plan is explicitly approved, implementation
and the full verification matrix pass, the user performs the runtime
walkthrough, the user explicitly approves completion, CASM advances its
version-only stage with a stable no-change build, and all durable records
agree. Completion does not activate WP49.

## Progress

- 2026-07-29: Drafted on `feature/casm-phase9-wp48` (branched from
  `feature/casm-stage9`, which carries WP47). User confirmed all three
  scope forks (fix the wrong-filename gap; bit-pack kind+id into the
  existing `FILE_ID` byte rather than growing the token record; add a
  dedicated `CasmFrameSiteColumn` array rather than reusing
  `CasmFrameResumeColumn`) before this plan was written. Investigation
  during drafting found the traceback needs no raise-time snapshot at all
  (the frame stack is still live and intact at `diagPrintFatal` time) and
  that `test_casm_pass1`/`test_casm_passcheck` will need `include.s` added
  to their module lists for the first time, likely forcing envelope bumps
  for both. Awaiting approval to activate.
- 2026-07-29: User approved and activated WP48. Implemented packed root/frame
  provenance, frame-site columns, catalog-backed included-file names, and
  bounded innermost-to-root traceback rendering. Diagnostic entry snapshots
  depth because best-effort line draining can pop a frame at child EOF; the
  frame arrays remain intact, so no raise-time chain snapshot is needed.
- 2026-07-29: User approved measured envelope increases: production `$4200`
  -> `$4300` (60-byte overflow), `test_casm_pass1` `$4000` -> `$4100`
  (158-byte overflow), and `test_casm_frame` `$4000` -> `$4100` (93-byte
  overflow). `test_casm_passcheck` still fits `$4000`. Narrow targets and all
  four disk images build; runtime walkthrough remains.
- 2026-07-29: Independent review found fatal line-tail draining could cross an
  unterminated child EOF and append parent bytes to the child's displayed
  source line. User approved a WP48 amendment. `sourceDrainLineTail` now latches
  the packed diagnostic identity and stops before appending a byte delivered
  from another frame/root; a second nested fixture chain exercises the
  unterminated-grandchild boundary. Candidate build advanced to 1200.
- 2026-07-29: Follow-up review found lexer lookahead may pop an unterminated
  diagnostic frame before fatal rendering. Traceback depth is now recovered
  from the packed catalog id and retained frame catalog array; a dedicated
  `CasmFrameRootFileId` array preserves the originating root across multi-pop
  transitions into another top-level file. Separate fixture chains cover
  post-pop reconstruction and active-frame drain-boundary stopping. Candidate
  build advanced to 1202.
- 2026-07-29: User runtime tests confirmed physical filenames and columns but
  showed every traceback site one line late (`LINE 3` instead of `LINE 2`).
  The plan's assumption that resume line equals statement line was false: the
  parser has consumed the newline before frame push. Added dedicated bounded
  `CasmFrameSiteLineLo/Hi` arrays populated from `CasmStmtLocLineLo/Hi`.
  Production and `test_casm_frame` retained their envelopes;
  `test_casm_pass1` overflowed `$4100` by 14 bytes, and the user approved
  `$4200` (242 bytes headroom). Candidate build advanced to 1203.
- 2026-07-29: Full image verification found `test_casm_event`, which also
  links `source.s` whole, overflowed `$1C00` by 31 bytes after the dedicated
  site-line arrays. User approved `$1D00`, leaving 225 bytes headroom.
- 2026-07-29: The user reported all runtime walkthrough tests pass and
  explicitly approved completion. Applied the planned version-only increment
  from `0.1.49` to `0.1.50` build 1204. The counter incremented exactly once,
  the no-change rebuild was stable, and all four disk images passed. WP49
  remains pending and inactive.
