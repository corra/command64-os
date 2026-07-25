---
feature: casm-phase8-wp38-default-origin-and-static-override
created: 2026-07-24
status: planned
---

# Plan: CASM Phase 8 WP38 - Optional `.ORG`, Default Relocatable Origin, and `/S` Wiring

## Objective

Implement Phase 0C.14 Contract item 1: flip `.ORG` from required to optional,
default an assembly with no `.ORG` to relocatable mode at `$3400`, wire `/S`
to force static mode, and reject a late `.ORG` (one arriving after the first
label or emitted byte). This WP produces no relocation table and no R6
footer -- output remains a plain PRG either way; only the origin-selection
and header-write mechanics change. WP39-WP41 build the actual relocation
classification, storage, and R6 serialization on top of this.

Taskwarrior: `e8d31694-0602-42bd-8234-416f3af5b31a` (unblocked by WP37's
completion).

Prerequisite: CASM Phase 8 WP37 is complete and approved (CASM `0.1.39`
build 1143, Phase 0C.14 frozen in `brain/KNOWLEDGE.md`). Approval of this
plan is required before activation or source edits, per the CASM
`AGENTS.md` gate.

## Baseline

- CASM `0.1.39` build 1143. MAIN headroom unchanged from WP36/WP37 (189 of
  13568 bytes) -- WP37 made no functional change.
- `emitInit` (`emit.s:78-86`) resets `CasmOrgSet`, `CasmPcOverflow`,
  `CasmEmitLen`, and forces `CasmPassMode = CASM_PASS_MODE_EMIT` at the
  start of every call, but **never touches `CasmPc` itself.** This is a
  real, previously load-bearing gap: today it is safe only because `.ORG`
  is mandatory and always the first statement, so both Pass 1 and Pass 2
  re-parse the identical `.ORG` and `emitOrg`'s `eoSet:` unconditionally
  overwrites `CasmPc` from the operand before anything else runs. Once
  `.ORG` becomes optional, nothing would reset `CasmPc` between Pass 1 and
  Pass 2 for a no-`.ORG` assembly -- Pass 2 would silently inherit Pass 1's
  *final* program counter as its starting point instead of the origin.
- `emitRequireOrg` (`emit.s:388-399`) is called from exactly three sites --
  `emitInstruction` (`:136`), `emitByteList` (`:320`), `emitWordList`
  (`:356`) -- and rejects with `CASM_DIAG_ORG_REQUIRED` if `CasmOrgSet` is
  still 0. **`crpLabel` (`casm.s`, the label-statement dispatch branch) calls
  none of this today** -- a label defined before `.ORG` is not rejected; it
  silently captures whatever `CasmPc` happens to hold (today always `$0000`
  in that unreachable case, since no fixture has ever exercised it). This
  is a genuine latent gap in the master plan's "`.org` ... before any label
  or emitted byte" constraint, not merely an absent feature -- found by
  tracing every `CasmOrgSet` consumer, not assumed from the diagnostic's
  name.
- `CASM_DIAG_DUPLICATE_ORG = $20` ("CASM: DUPLICATE ORG",
  `diagnostics.s:1104`) fires when a second `.ORG` arrives while
  `CasmOrgSet` is already 1. `CASM_DIAG_ORG_REQUIRED = $21` ("CASM: ORG
  REQUIRED", `diagnostics.s:1106`) fires when byte emission is attempted
  before any `.ORG`. Both messages already read correctly for a broader
  "output has already started" meaning without rewording.
- `emitOrg`'s existing header write (`emit.s:301-307`) calls `emitRawByte`
  twice for the 2-byte load address, which already no-ops correctly under
  `CASM_PASS_MODE_MEASURE` (Phase 0C.5's single emission-gate design,
  `emit.s`'s own comment: "`.ORG`'s header write and every `emitRawByte`
  call automatically no-op under `CASM_PASS_MODE_MEASURE`"). Any new
  implicit header write that also goes through `emitRawByte` inherits this
  safety with no new pass-mode branching.
- `parserParseStatement` already stamps the current statement's location
  via `diagStampStmtLoc` (`parser.s:81`) before returning to `casmRunPass`,
  for every statement type including labels -- confirmed by reading the
  call site, not assumed. A new failure raised from `crpLabel`'s branch can
  rely on this already-current stamped location without an extra
  `diagSetLocFromStmt` call.
- `CasmCliOptions`/`CASM_OPT_STATIC` (`cli.s`) is fully populated by
  `cliParse`, which runs (`casm.s:98`) well before `emitInit`'s first call
  (`casm.s:137`) -- `/S` is a stable, already-known fact by the time origin
  selection needs to consult it.

## Dependency Review and Discrepancies Reconciled

1. **`CasmPc` priming must move into `emitInit`, unconditionally, every
   pass.** The cross-pass-carry hazard above is real and would otherwise
   make Pass 2 silently disagree with Pass 1 the moment `.ORG` is absent.
   Resolving it in `emitInit` (rather than in the new implicit-origin
   trigger) is simpler than it first appears: `.ORG`, if present, is still
   required to be the first statement and unconditionally overwrites
   `CasmPc` before any label or byte, so priming a default value first and
   letting `.ORG` overwrite it second is equivalent to today's behavior
   whenever `.ORG` is actually given, and correct new behavior whenever it
   is not.
2. **Static mode (`/S` or a source that turns out to use `.ORG`) must not
   silently adopt the relocatable default.** `emitInit` cannot know in
   advance whether a given pass's source will contain `.ORG` -- that is
   only discovered once the first statement is parsed. The only fact
   `emitInit` *can* know up front is whether `/S` was given. Resolution
   (Contract item 2 below): `emitInit` primes `CasmPc = $3400` and marks
   "relocatable-eligible" only when `/S` is not set; under `/S`,
   `CasmPc` is left unprimed (or primed to a recognizably-unset sentinel)
   and the existing "reject emission with no origin" behavior is
   preserved, scoped now to exactly the `/S`-without-`.ORG` case.
3. **One unified flag replaces `CasmOrgSet`'s narrower meaning and closes
   the label-before-`.ORG` gap in the same change.** Today's `CasmOrgSet`
   means "an explicit `.ORG` has been processed this pass." Renaming it to
   `CasmOutputStarted` and broadening its meaning to "a label, a byte, or
   an explicit `.ORG` has already been processed this pass" lets a single
   check in `emitOrg` catch both the existing duplicate-`.ORG` case and the
   new late-`.ORG`-after-implicit-default case with no new diagnostic --
   both are, structurally, "`.ORG` arrived after output had already
   started." Reusing `CASM_DIAG_DUPLICATE_ORG` for both is recommended (see
   the open question below) since its existing message text does not
   claim *which* prior event started output.
4. **The header write and the "mark started" side effect must be shared by
   four call sites, not duplicated.** `emitInstruction`, `emitByteList`,
   and `emitWordList` already call `emitRequireOrg`; `crpLabel` needs a new
   call it does not have today. A single exported routine (working name
   `emitMarkStarted`, replacing `emitRequireOrg`'s exported name since its
   contract changes from "reject" to "mark, and conditionally establish")
   serves all four:
   - If `CasmOutputStarted` is already set, return immediately (no-op) --
     this is the common case for every statement after the first.
   - If not yet set and `/S` was given: fail with `CASM_DIAG_ORG_REQUIRED`
     (today's exact existing behavior, now reached only from this
     narrower condition -- not dead, contrary to what a mechanical port of
     WP33's "declared but unreachable" precedent would suggest).
   - If not yet set and `/S` was not given: this is the first qualifying
     event of a relocatable assembly. Write the 2-byte header from the
     *current* `CasmPc` (already `$3400` via `emitInit`'s priming, item 1)
     through the existing `emitRawByte` pair, exactly mirroring `emitOrg`'s
     own write, then set `CasmOutputStarted`.
   `emitOrg` becomes the fourth caller of the same underlying "already
   started" check (reject if set), but keeps its own explicit-origin header
   write (using the parsed operand, not `CasmPc`'s primed default) and its
   own `CasmPc` assignment -- it does not call `emitMarkStarted` itself, to
   avoid a double header write; it sets `CasmOutputStarted` directly after
   its own checks pass, matching today's structure.
5. **No change is needed to `casmRunPass`'s pass-mode gating.** The flag
   update in item 3 is deliberately *not* pass-mode-gated -- it must run
   identically in Pass 1 and Pass 2 so a misplaced `.ORG` is caught in
   Pass 1 (before any output file exists) exactly as reliably as in Pass 2.
   Only the header *byte write* is pass-mode-sensitive, and it inherits
   that correctly for free through `emitRawByte`'s existing single gate
   (item above, Baseline).
6. **No MAIN size or zero-page impact is expected.** `CasmOutputStarted`
   reuses `CasmOrgSet`'s existing BSS byte (rename, not addition); the
   `emitMarkStarted` call sites already exist for three of the four
   callers (a rewritten body, not a new call), and `crpLabel`'s new call
   is one small addition to an existing branch. This WP is not expected to
   need an `add_ca65_app` size bump, though the implementing increment
   still measures actual `ld65 -m` output before assuming so, per every
   prior phase's precedent.

## Diagnostic Reuse Decision (resolved 2026-07-24)

The user confirmed reusing `CASM_DIAG_DUPLICATE_ORG` ("CASM: DUPLICATE ORG")
for the late-`.ORG` case (a `.ORG` arriving after an *implicit* default
origin already started output, not only after a second explicit `.ORG`),
rather than adding a new diagnostic identifier. No new `CASM_DIAG_*` value
or message-table entry is needed by this WP; `$30` remains the next free
identifier for WP40's relocation-table-capacity diagnostic.

## Scope

Included in WP38:

- `emit.s`: `emitInit`'s `CasmPc`/relocatable-eligibility priming (item 1-2);
  rename `CasmOrgSet` to `CasmOutputStarted` and broaden its semantics
  (item 3); replace `emitRequireOrg` with `emitMarkStarted` implementing
  the shared check/header-write/flag-set behavior (item 4); update
  `emitOrg` to check-and-set the same flag instead of `CasmOrgSet` directly.
- `casm.s`: add the `emitMarkStarted` call to `crpLabel` before
  `symbolsInsert`.
- `cli.s`/`common.inc`: no change expected -- `/S` parsing already exists
  (WP0B); only its consumption changes.
- Diagnostics: no new identifier -- the late-`.ORG` case reuses
  `CASM_DIAG_DUPLICATE_ORG` per the resolved decision above.
- Fixtures proving: a no-`.ORG` program assembling successfully with a
  `$3400`-based header and plausible output; every existing static
  (`.ORG`-bearing) trusted-reference fixture re-confirmed byte-identical;
  `/S` with `.ORG` (unchanged behavior); `/S` without `.ORG`
  (`CASM_DIAG_ORG_REQUIRED`, still reachable); a label appearing before an
  `.ORG` that then follows it (new rejection, closing the latent gap);
  two `.ORG` statements (existing rejection, unchanged observable
  behavior); an instruction before `.ORG` with no `/S` (now legal --
  previously `CASM_DIAG_ORG_REQUIRED`, now silently accepted as the
  relocatable default).

Excluded from WP38 (deferred to WP39-WP41 per the Phase 0C.14 breakdown):

- any relocation classification (`CASM_EXPR_FLAG_RELOCATABLE` production,
  `CASM_PARSER_STMT_RELOCATABLE`);
- any relocation-table storage or capacity diagnostic;
- any R6 footer serialization;
- `.STATIC`/`.RELOC` source preamble directives (frozen out of scope for
  all of Phase 8, per Phase 0C.14 Contract item 2).

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md` | this document |
| `src/external/casm/emit.s` | `emitInit` priming; `CasmOutputStarted` rename; `emitMarkStarted` replacing `emitRequireOrg`; `emitOrg` update |
| `src/external/casm/casm.s` | `crpLabel` gains the `emitMarkStarted` call; version-only increment at completion |
| `cmake/GenerateCasmTestFixtures.cmake` (or equivalent) | new fixtures per Scope |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md` (Phase 0C.15), `CHANGELOG.md` | completion records |

## ABI, Storage, and Runtime Effects

- `CasmOrgSet` renamed `CasmOutputStarted`, same BSS byte, broadened
  meaning (Dependency Review item 3). No size change.
- `emitRequireOrg` (exported) is replaced by `emitMarkStarted` (exported)
  with a different contract: never fails when output has already started;
  fails only under `/S` with no `.ORG` yet; otherwise may perform a header
  write as a side effect. Callers (`emitInstruction`, `emitByteList`,
  `emitWordList`) need no change beyond the call target's name, since the
  call-and-branch-on-carry shape is identical.
- `crpLabel` (`casm.s`) gains one new call before `symbolsInsert`.
- No new persistent zero-page state; no new VMM allocation; no MAIN size
  change expected (to be confirmed by measurement during implementation).

## Verification and Fixture Strategy

- Every existing static (`.ORG`-first) trusted-reference fixture re-run
  unmodified and confirmed byte-identical, proving the explicit-`.ORG` path
  is unaffected.
- A new no-`.ORG` fixture assembling successfully, with its PRG header
  bytes confirmed to be `$3400` little-endian and its program bytes
  matching a hand-derived expected sequence (not CASM's own claimed
  output).
- `/S` with `.ORG`: unchanged acceptance.
- `/S` without `.ORG`: `CASM_DIAG_ORG_REQUIRED`, confirmed still reachable
  and correctly located.
- A label before a later `.ORG`: new rejection (closing the latent gap),
  confirmed with the correct diagnostic and location.
- Two `.ORG` statements: existing rejection, confirmed unchanged.
- An instruction before any `.ORG`, no `/S`: now legal, confirmed to
  produce the same bytes as the equivalent program written with an
  explicit `.ORG $3400` at the top (byte-for-byte equivalence between
  implicit and explicit `$3400`, which is the real cross-check that the
  priming and header-write mechanics are equivalent, not just "it doesn't
  crash").

## Atomic Implementation Increments

1. Implement `emitInit`'s conditional priming (Dependency Review items 1-2).
2. Rename `CasmOrgSet` to `CasmOutputStarted`; implement `emitMarkStarted`
   replacing `emitRequireOrg`; update the three existing call sites'
   target name only.
3. Update `emitOrg` to use the renamed flag with unchanged observable
   duplicate-`.ORG` behavior.
4. Add the `emitMarkStarted` call to `crpLabel`.
5. Implement the resolved late-`.ORG` diagnostic reuse (no new identifier).
6. Add fixtures per the Verification and Fixture Strategy section; build
   and measure MAIN headroom via `ld65 -m`.
7. User runtime verification in the supported local emulator; record a
   walkthrough.
8. Version-only completion increment, no-change rebuild check, all three
   disk images, `brain/KNOWLEDGE.md` Phase 0C.15 entry, task/changelog
   updates, request completion approval.

## Failure and Cleanup

No new resource-ownership path is introduced -- output file creation,
registration, and abort-on-failure are unchanged from today (`casm.s`'s
existing `fileCreateOutput`/`outputAbort`/central-cleanup sequence). A
rejected implicit or explicit origin fails before any byte is written in
the failing pass, consistent with every existing diagnostic path.

## Documentation and DOX Closeout

Update this plan's Progress section, `brain/KNOWLEDGE.md` (new Phase 0C.15
entry amending 0C.14 with as-built detail, per the WP28/WP33 precedent),
`wiki/tasks/casm.md`, `brain/task.md`, `CHANGELOG.md`, and Taskwarrior.
`AGENTS.md` needs a real update after this WP: it currently documents no
relocatable-output behavior at all.

## Stop Conditions

Stop if CASM Phase 8 WP37 is not complete and approved. Stop if
implementation surfaces a further material discrepancy against this
document (in particular, if `emitRawByte`'s pass-mode gate turns out not to
cover the new implicit header write the way Dependency Review item 5
assumes), requiring this document to be amended and re-approved.

## Completion Gate

WP38 is complete when: every fixture in the Verification and Fixture
Strategy section passes; a no-`.ORG` assembly and an equivalent explicit
`.ORG $3400` assembly produce byte-identical output; every existing static
trusted reference remains byte-identical; MAIN headroom is measured and
recorded; the user completes a runtime walkthrough; and the user explicitly
approves completion, together with the version-only increment and
`brain/KNOWLEDGE.md`/task/changelog updates.

## Progress

- 2026-07-24: Drafted after WP37's approval. Found, by tracing every
  `CasmOrgSet` consumer directly rather than assuming from the diagnostic
  names, two real mechanism gaps beyond what the Phase 0C.14 freeze
  flagged as open: (1) `emitInit` never primes `CasmPc`, which is only
  safe today because `.ORG` is mandatory-and-first and unconditionally
  overwrites it -- this becomes a real Pass-1/Pass-2 disagreement hazard
  the moment `.ORG` is optional; (2) `crpLabel` never calls
  `emitRequireOrg` at all today, so "a label before `.ORG`" is not actually
  rejected despite the master plan's explicit "before any label or emitted
  byte" wording -- a latent gap, not a feature to add. Designed a unified
  mechanism resolving both: `emitInit` conditionally primes `CasmPc` based
  on `/S` (known before Pass 1 via `CasmCliOptions`, already stable by
  that point); a single broadened `CasmOutputStarted` flag (renamed from
  `CasmOrgSet`) and a new shared `emitMarkStarted` routine (replacing
  `emitRequireOrg`) serve all four qualifying call sites --
  `emitInstruction`, `emitByteList`, `emitWordList`, and a new call added
  to `crpLabel` -- with no duplicated header-write logic and no new
  pass-mode branching, since the existing `emitRawByte` single-gate design
  already makes the new implicit header write safe under
  `CASM_PASS_MODE_MEASURE` for free. One open question left for approval:
  whether the late-`.ORG` case reuses `CASM_DIAG_DUPLICATE_ORG` (recommended)
  or gets a new diagnostic identifier.
