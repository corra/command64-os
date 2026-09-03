---
feature: label-casm-native-migration
created: 2026-09-02
status: complete
taskwarrior: 53e5934a-4617-4263-a870-de7e1cfeb592
depends-on: Byte-Oracle Transition (WP1-WP6), complete and user-approved 2026-09-02
---

# Plan: LABEL — Full Migration to Native CASM (ca65 Retirement, Pilot)

## Status

**COMPLETE — user-approved 2026-09-02.** All seven increments implemented,
walkthrough (`brain/walkthroughs/2026-09-02-label-casm-native-migration.md`)
signed off, `label-derivation.md` reviewer-approved, `label.ref.hex`
provenance `CANONICAL-INDEPENDENT`, Taskwarrior task 41 closed. LABEL is
CASM-native; ca65 retired. (Taskwarrior task 42 — the `.INCLUDE`d-constant
ZP-selection CASM defect found along the way — remains open as a separate
follow-up.)

This is the **Stage 1 pilot** identified by
`brain/reviews/2026-09-01-external-applications-casm-native-viability.md`. It
is not a numbered CASM Phase/WP — it is a downstream application of CASM's
already-shipped language surface and the now-closed Byte-Oracle Transition
(`brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`,
`project-casm-byte-oracle-transition-complete`) to an external app. Treated
under full planning discipline because it swaps a build-provenance model and
introduces R6 relocation for an app that currently has none.

Precedent: BANNER
(`brain/plans/2026-08-20-banner-casm-native-migration.md`), a completed
single-file ca65→CASM-native migration. This plan follows its structure and
deviates only where LABEL genuinely differs (enumerated in Technical Notes).

## Objective

Retire LABEL's ca65/ld65 build entirely and make LABEL a CASM-native
application: source assembled only by the real native CASM assembler under
Command64, shipped from a checked-in reviewed hex manifest bound to source
hashes, backed by an independent byte + R6 relocation derivation record.

Concretely this delivers:

1. `src/external/label/label.s` converted to documented CASM syntax, all
   uppercase ASCII, self-contained (no `.include "command64.inc"`,
   no `.import`, no `.segment`, no ca65 `.define`).
2. **CASM-safe named constants for the OS API selectors, KERNAL vectors, OS
   globals, and PETSCII codes LABEL uses**, defined **inline at the top of
   `label.s`** (not a separate `.INCLUDE` file). Originally planned as
   `labelconst.s`; Increment 3 proved CASM 0.6.2 emits 3-byte absolute
   addressing for a ZP-valued constant defined in an `.INCLUDE`d file, so
   inline is required — and it matches the BANNER precedent and DASH's
   "constants in the prologue" contract. See Progress 2026-09-02 and
   Taskwarrior task 42 (the separate CASM defect).
3. A **build-time generated CASM-safe version source** replacing the ca65
   `.define VERSION_*` + generated `build_label.inc` mechanism (Scoping
   Decision 2).
4. `src/external/label/label.ref.hex` — the reviewed shipping manifest.
5. `src/external/label/label-derivation.md` (or a `brain/reviews/` record it
   links) — the independent byte + R6 relocation derivation, peer-reviewed.
6. `scripts/build_label_manifest.py` — a single-source manifest twin of
   `scripts/build_banner_manifest.py` (no ca65 cross-check machinery).
7. `CMakeLists.txt`: `add_ca65_app(label ...)` and its `Ca65_FOUND` fatal
   gate removed; a manifest-derived `label` target added mirroring `banner`'s;
   `IMAGE_BASE_PRG_TARGETS` unchanged in shape (still references
   `${LABEL_TARGET}`).
8. A dedicated `command64_label_test.d64` for live native assembly, per
   `.agents/workflows/per-phase-test-images.md`.

**Does NOT deliver:** any change to LABEL's behavior — the volume-name write
protocol, the interactive prompt, argument/prefix parsing, drive-command
bytes, error messages, or the OS-API/KERNAL call sequence. LABEL's rendered
and functional behavior must be provably unchanged (see Completion Gate),
*modulo* the deliberate `$3800`→`$3400` relocatable-base convention and R6
footer (see Technical Notes — this is the same delta BANNER accepted).

## Scoping Decisions (user-confirmed 2026-09-02)

1. **LABEL produces first the pilot artifact.** This plan delivers only
   LABEL. Cross-application migration prerequisites from the review (§
   "Cross-Application Migration Prerequisites") are folded in **only to the
   extent LABEL needs them** — the `labelconst.s` constants file and the
   generated-version workflow are built app-locally here, not as a shared
   framework. Generalizing them for COMP/FORMAT/CONWAY is explicitly a later
   decision, made when the second migration starts.
2. **Version/build number: build-time generated CASM-safe source.** A
   host script (`scripts/gen_label_version.py`) generates an
   all-uppercase-ASCII CASM source fragment (`labelver.s`) from two
   checked-in inputs — `src/external/label/LABEL_VERSION` (app-owned
   `MAJOR.MINOR.STAGE`, currently `0.4.0`, hand-bumped) and
   `src/external/label/BUILD_LABEL` (the persistent build counter) —
   replacing ca65's `.define VERSION_MAJOR`/`MINOR`/`STAGE` + generated
   `build_label.inc`. **LABEL keeps its own app version, not the repo
   `VERSION` file** — matching current behavior (`label.s` hardcodes
   `0.4.0`, distinct from repo `VERSION` `0.4.1`; every ca65 external app
   does likewise). The fragment defines `LABELVERMSG:` and is `.INCLUDE`d
   by `label.s`; it is a build product (not checked in). Both inputs are
   added to `label.ref.hex`'s source-hash gate, so a version bump forces a
   deliberate manifest regeneration rather than a silent stale ship. The
   `command64_label_test.d64` packaging step depends on the generated
   fragment.
   - **Byte-change note (updated 2026-09-02 after live observation +
     user decision):** the old ca65 build rendered `verMsg`'s
     `.byte "LABEL V"` through `-t c64`'s charmap as *shifted* PETSCII
     (`$CC $C1 ...` + `$D6` for `V`) → the banner rendered UPPERCASE,
     inconsistent with every other LABEL message (which are explicit
     unshifted hex and render *lowercase* on Command 64's mixed-case
     charset). "Same glyph" was wrong — the case visibly changes. The
     user chose to match **DEBUG's `DEBUG v0.5.0.1128` format**:
     `gen_label_version.py` emits the app name as shifted PETSCII
     (`$CC $C1 $C2 $C5 $CC` → uppercase glyph), then `$20 $56`
     (space + unshifted `V` → lowercase `v`), then `.BYTE "0.4.0.1047"`.
     Net difference from the retired ca65 file: **one byte, `$3706`
     `$D6`→`$56`** (`V`→`v`). Recorded in the derivation record and
     walkthrough.
3. **ca65 retirement happens in this same plan**, not a follow-up — like
   BANNER Scoping Decision 3. Any CASM-native syntax adopted for `label.s`
   is only unconditionally safe once ca65 no longer compiles it, so a split
   would leave an intermediate state where the wired-up ca65 build sees
   unsafe source.
4. **No ca65 differential is kept for LABEL.** Unlike DASH, LABEL will have
   no `label_ref` target and no dual-assembler subset constraint. The
   correctness oracle is the independent derivation record + live native
   `COMP`, per `.agents/workflows/canonical-byte-oracles.md`. (A one-time,
   non-committed ca65 build of the pre-migration source is still used in
   Increment 4 as *post-derivation* comparison evidence only — never as the
   derivation source.)
5. **Use new CASM features where appropriate** (user directive, mid-session
   2026-09-02). LABEL is not held to a ca65 intersection (Decision 4), so
   the conversion actively adopts CASM Phase 12-15 surface where it
   improves the source without risking behavior:
   - **Named constants** for OS/KERNAL entry points and drive-protocol
     magic numbers (`labelconst.s`, plus in-file names for the remaining
     literals in `label.s`).
   - **`@local` labels** (Phase 14) for every routine-internal
     loop/skip/done branch target — DASH-MOD precedent; purely additive,
     assembles byte-identically to plain labels. Routine entry points and
     data labels stay global.
   - **String literals** (`.BYTE "..."`, Phase 12 WP74) for LABEL's
     human-readable messages (`OKMSG`/`LENMSG`/`REQMSG`/`PROMPTMSG`/
     `DEVMSG`) and the generated version banner — native CASM emits raw
     unshifted PETSCII for `A`-`Z` (`$41`-`$5A`), byte-identical to the
     current explicit-hex message bytes, and there is no ca65 charmap to
     diverge from.
   - **Character literals** (`#' '`, `#'0'`, Phase 12 WP69) for the
     comparison sites currently written as `#$20` / `#'0'`-style pairs.
   - **`.RES`** (Phase 13) keeps its role for the runtime buffers.
   - **Not adopted:** the drive-command protocol strings
     (`CMDINIT`/`CMDU1`/`CMDBP`/`CMDU2`) stay explicit reviewed hex —
     protocol data, per the canonical-byte-oracle "prefer explicit
     reviewed numeric bytes" guidance, even though native CASM would emit
     them identically from a literal. `.ASSERT` (no comparison operator)
     and conditional assembly (no conditional need) have no useful site.
   This expands Increment 2's surface and its byte-diff risk, which
   Increment 3's same-base byte comparison is precisely there to catch.

6. **"Enough verification" = BANNER's bar plus R6.** Byte-identity of the
   pre-/post-conversion assemblies at the same base; a no-change rebuild
   that alters nothing; live `COMP` against the reviewed manifest under
   VICE; R6 relocation applied and verified at **two** additional load
   bases (matching DASH's `$3800`/`$5000`/`$9000` practice, scaled to
   `$3400` + two others); and a functional exercise of every LABEL code
   path (arg form, no-arg interactive form, prefix form, too-long error,
   open-failure error, drive-error passthrough, OK path). No destructive
   real-hardware formatting is required — LABEL writes a volume name, it
   does not format — but the live run must be against a scratch disk image.

## Scope

**Included:**

- `src/external/label/label.s` — full conversion (Increments 2-3).
- `src/external/label/labelconst.s` — new CASM-safe constants (Increment 1).
- `src/external/label/common.inc` — folded into `labelconst.s` and deleted,
  **or** kept and converted to CASM-safe form; decided in Increment 1
  (2 zero-page equates + 3 protocol constants — trivially small).
- `CMakeLists.txt` — remove `add_ca65_app(label ...)` (lines ~198-209) and
  the `LABEL_SRCS` ca65 glob's role as a ca65 input; add the
  `labelver.s` generator; add the manifest-derived `label` target
  (mirroring the `banner` block at ~1706-1730); add
  `command64_label_test_d64`; keep `set(LABEL_TARGET label)` pointed at the
  new target so `IMAGE_BASE_PRG_TARGETS` (line 1740) needs no change.
- `scripts/build_label_manifest.py` — new (Increment 4).
- `src/external/label/label.ref.hex` — new reviewed manifest (Increment 4).
- `src/external/label/label-derivation.md` — new derivation record, or a
  `brain/reviews/2026-09-02-label-casm-native-derivation.md` linked by path
  from the manifest (Increment 4). Follows
  `.agents/workflows/canonical-byte-oracles.md` "Native application
  manifest" class.
- `src/external/label/BUILD_LABEL` — reduced to the plain single-line
  counter form (`BUILD_BANNER`/`BUILD_DASH` shape) if `add_ca65_app`'s
  removal changes what maintains it; confirmed in Increment 5.
- `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` — add LABEL's
  manifest row with its provenance state.
- `wiki/label-utility.md` (+ `docs/`, `release/docs/` via `sync_docs`) —
  add an "Artifact Provenance" section mirroring `dash-utility.md`'s and
  stating ca65 is no longer part of LABEL's build.
- `src/external/AGENTS.md` "Child DOX Index" / any LABEL mention;
  `CHANGELOG.md`; `brain/KNOWLEDGE.md`; Taskwarrior; memory.

**Excluded:**

- Any change to LABEL's runtime behavior, command syntax, message text
  bytes, drive-command bytes, buffer sizes, or zero-page usage.
- Any change to how LABEL is packaged on `image.d64` beyond the
  compiled-PRG source swap (ca65 output → manifest-derived binary).
- Generalizing `labelconst.s` / the version generator into shared external
  infrastructure for other apps (Scoping Decision 1).
- Migrating COMP, FORMAT, CONWAY, or any other app.
- Any change to `casm` itself, the R6 format, or `hex_manifest_to_bin.py`.
- CASM anonymous-label support or any other CASM feature work.

## Technical Notes

### How LABEL differs from BANNER (and why each difference is bounded)

| Aspect | BANNER (done) | LABEL (this plan) | Handling |
| --- | --- | --- | --- |
| Prior toolchain | KickAssembler, then ca65 | ca65/ld65 only | Same retirement shape; remove `add_ca65_app`, add manifest target |
| Header | ca65 `header.s` stub | inline `.segment "HEADER"` + `.word __MAIN_START__` + `.import __MAIN_START__` | Delete all three; CASM emits the 2-byte load-address header itself |
| Shared API include | small, hand-inlined | `.include "command64.inc"` (shared ca65 header) + `common.inc` | New app-local `labelconst.s`; do **not** package the lowercase shared header |
| Version mechanism | `.define` + `build_banner.inc` | `.define VERSION_*` + `build_label.inc` | Build-time generated `labelver.s` (Scoping Decision 2) |
| Relocation | none → R6 at `$3400` | none → R6 at `$3400` | **New for LABEL**: derive + review an R6 ledger; verify at 3 bases |
| String literal in banner | `USAGE_STR` alphabetic | `verMsg` = `.byte "LABEL V", VERSION_MAJOR, ...` | Safe once ca65 gone (Scoping Decision 3); or keep as explicit hex + generated digits — decided in Increment 2 |
| Drive-command PETSCII | n/a | `cmdInit`/`cmdU1`/`cmdBP`/`cmdU2` already explicit hex | Keep verbatim as `.BYTE` hex — the file header comment already documents why shifted PETSCII breaks the 1541 parser |
| Message strings | hand-decoded hex | `okMsg`/`lenMsg`/`reqMsg`/`promptMsg`/`devMsg` already explicit hex | Keep verbatim (safest); converting to `.BYTE "..."` is optional and must be byte-proven |

### R6 relocation is the one genuinely new element

LABEL today is a fixed `$3800` PRG (`add_ca65_app` default base
`USER_PROG_START_HEX`, no `BASE_HEX` override) with a hand-written
`.word __MAIN_START__` header and **no relocation footer**. The OS external
command loader currently loads it at `$3800` and enters it.

Native CASM emits R6-relocatable output at implicit base `$3400` with a
`52 36` (`R6`) footer — the same form DASH ships. Before Increment 2, the
plan must **confirm the OS external-command loader applies R6 relocation to
LABEL the same way it does for DASH** (DASH proves the loader path exists;
this confirms LABEL travels it — i.e. LABEL is dispatched through the same
relocating loader, not a separate fixed-load path). If it does not, this is
a **stop condition** — disclose and defer; do not add a loader change to
this plan.

Relocation-eligibility derivation for LABEL (to be reviewed, not asserted):

- **Eligible**: absolute operands targeting in-image labels — the many
  `jmp`/`jsr` to `label.s`'s own routines, `lda CommandBuffer,y` **only if**
  `CommandBuffer` resolves in-image (it does not — it is a fixed OS global,
  see below), `ldx #<verMsg`/`ldy #>verMsg` high-byte forms, `.word`
  pointers (LABEL has none), `sta labelBuf,x` (in-image data).
- **Not eligible / no entry**: `OS_API` (`$1000`), all `Kernal*` vectors
  (`$FFxx`), OS globals `CommandBuffer`/`ParsePos`/`CurrentDevice`
  (fixed page-3 / OS addresses), zero-page scratch `$70`/`$71`, all
  `#<label` low-byte immediates (CASM clears `RELOCATABLE` for `<`),
  every `#immediate` numeric literal.
- LABEL's absolute in-image references are almost entirely code labels for
  branches-too-far-for-`bcc`/`beq` (`jmp skipToken`, `jmp openErr`, etc.)
  plus `labelBuf`/`statusBuf`/`labelBuf,x` data operands. The review
  estimated the shipping artifact at ~956 bytes incl. R6; the entry count
  will be small (tens, not hundreds) and far below the 4,096 cap.

### Constants LABEL actually needs (`labelconst.s` contents)

From `label.s` + `common.inc` + `command64.inc`, the required set:

- **OS API**: `OS_API = $1000`; selectors `DOS_PRINT_STR`,
  `DOS_PARSE_PREFIX`, `DOS_RELEASE_L15` (verify exact names/values against
  `include/ca65/command64.inc` and freeze as numeric equates).
- **KERNAL vectors**: `KERNALGETIN`, `KERNALCHROUT`, `KERNALCHRIN`,
  `KERNALSETNAM`, `KERNALSETLFS`, `KERNALOPEN`, `KERNALCLOSE`,
  `KERNALCHKIN`, `KERNALCHKOUT`, `KERNALCLRCHN`, `KERNALREADST` — all
  standard `$FFxx` addresses, hand-verified from the KERNAL jump table.
- **OS globals**: `COMMANDBUFFER`, `PARSEPOS`, `CURRENTDEVICE` — fixed
  addresses, hand-verified from the OS memory map (not guessed from the
  ca65 header).
- **PETSCII / protocol**: `PETCR = $0D`, `PETDEL = $14` (`$14` = DEL —
  verify), `CMD_CHANNEL = 15`, `DATA_CHANNEL = 2`, `VOL_NAME_LEN = 16`,
  `ARGIDX = $70`, `SAVEDDEVICE = $71`.

Every value in `labelconst.s` is a **bare-literal RHS** (CASM named-constant
rule — see `src/external/dash/AGENTS.md`). Each address is hand-derived from
a spec/memory-map source and cited in a comment, per
`project-casm-trusted-reference-rule` — not copied from the lowercase ca65
header as the authority (reading the header afterward to cross-check is
fine).

### Uppercase-ASCII conversion + collision audit

`label.s` is already almost entirely uppercase in structure but has
lowercase comments, lowercase mnemonics, and mixed-case labels
(`skipToken`, `notTokenNull`, `labelBuf`, ...). Whole-file uppercasing is
required (`scripts/check_casm_source_bytes.py` gate). Before renaming:
**audit for identifiers that differ only by case** (DEBUG has a real
`ParsePos`/`parsePos` collision — LABEL must be checked the same way).
`label.s`'s labels look collision-free but this is a checklist item, not an
assumption.

### `@local` labels

Optional. `label.s`'s internal loop/skip targets (`skipToken`,
`skipSpaces`, `sendInitLoop`, ...) could become `@LOOP`/`@DONE`-style
`@local`s (CASM Phase 14). This is a **readability nicety, not required for
migration**, and adds conversion surface + a byte-diff risk. Default:
**do not** convert to `@local` in this plan — keep the existing global
labels, just uppercased. Revisit as a separate cleanup if desired.

### Version banner

`verMsg` currently is:
`.byte "LABEL V", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, ".", BUILD_NUMBER, $0D, $00`

Two options, decided in Increment 2 with a byte proof:

- **A (preferred):** generated `labelver.s` emits
  `LABELVERMSG: .BYTE $4C,$41,$42,$45,$4C,$20,$56, <digits>, $0D, $00`
  as fully explicit bytes — the CMake generator computes the digit bytes
  from `VERSION` + `BUILD_LABEL`. Zero literal-encoding risk; matches the
  "prefer explicit reviewed numeric bytes" guidance.
- **B:** `label.s` keeps `.BYTE "LABEL V"` (safe uppercase run once ca65 is
  gone) and `.INCLUDE`s a generated `labelver.s` that provides only the
  version/build digit bytes. Slightly more readable, small residual risk,
  must be `COMP`-proven.

The generator script is small and CMake-driven; it reads the repo `VERSION`
file the same way other targets do (confirm the exact mechanism —
`build_config.inc` / `VERSION` — during Increment 2).

## Atomic Increments

1. **Constants + loader confirmation.**
   (a) Confirm the OS external-command loader applies R6 relocation to a
   dispatched LABEL exactly as for DASH (read the loader path; if it does
   not, **stop**). (b) Create `src/external/label/labelconst.s` with every
   equate hand-derived and comment-cited (table above); fold `common.inc`
   in and delete it, or convert it — decide and record. No `label.s` change
   yet. Verify each value against `include/ca65/command64.inc` and the OS
   memory map *after* deriving independently.

2. **Source conversion.** Convert `label.s`: remove `.include
   "command64.inc"`, `.include "common.inc"`, `.define VERSION_*`,
   `.include "build_label.inc"`, `.import __MAIN_START__`, `.segment
   "HEADER"`, `.word __MAIN_START__`, `.segment "CODE"`. Add `.INCLUDE
   "LABELCONST.S"` and `.INCLUDE "LABELVER.S"`. Uppercase the whole file
   (mnemonics, labels, comments); run the collision audit. Convert `.res`
   → `.RES` (byte-identical per DASH WP84). Decide `verMsg` option A/B.
   Keep all drive-command and message `.BYTE` hex verbatim. No behavior
   change intended.

3. **Byte-identity check vs pre-conversion.** Assemble the converted source
   with the real native `casm.prg` under VICE
   (`.agents/workflows/vice-mcp-testing.md`); confirm clean assembly
   (`CASM: INPUT VALIDATED`). Extract the PRG. Assemble the **pre-conversion**
   source the same way (it still parses under CASM only where syntax
   overlaps — if it does not, use the one-time non-committed ca65 build at
   `BASE_HEX 3400` as the same-base baseline instead, per Scoping
   Decision 4). Diff must be empty modulo the documented base/footer delta.
   Functionally exercise every LABEL path (Scoping Decision 5) against a
   scratch disk image. Fire overlay `test` events.

4. **Derive + review + capture manifest.** Produce the independent byte +
   R6 relocation derivation record (`.agents/workflows/canonical-byte-oracles.md`
   "Native application manifest" class): load address, address ledger,
   opcode/operand derivation, `.RES` fill, relocation eligibility ledger,
   sorted entry offsets, count/terminator/footer, byte count, SHA-256,
   source SHA-256(s). Run `scripts/casm_r6_verify.py` on the extracted PRG
   and cite it. Second-reviewer sign-off. Write
   `scripts/build_label_manifest.py` (twin of `build_banner_manifest.py`)
   and generate `src/external/label/label.ref.hex` with an explicit
   `--provenance` string. Read the one-time ca65 build now, as
   *post-derivation* differential evidence, and record it as
   `DIFFERENTIAL-ONLY`.

5. **Retire ca65; wire manifest target.** Remove `add_ca65_app(label ...)`
   and its `Ca65_FOUND` fatal branch; remove `label` from any ca65-only
   glob role. Add the `labelver.s` generator custom command. Add the
   manifest-derived `label` target (`add_custom_command` +
   `add_custom_target`, `hex_manifest_to_bin.py --source-dir`, mirroring
   `banner` at CMakeLists ~1706-1730). Keep `set(LABEL_TARGET label)`.
   Reduce `BUILD_LABEL` to plain counter form if needed. Add
   `command64_label_test_d64` (command64 + casm + label sources as SEQ +
   a scratch data disk if the functional test needs a second drive, per
   `project-vice-two-drive-test-setup`).

6. **Full-rebuild verification.** Fresh `cmake -B build` +
   `cmake --build build --target image_d64 test_image_d64
   command64_label_test_d64`. Confirm: all disks build clean, no
   warnings; `image.d64` carries the manifest-derived `label.prg`; no
   `add_ca65_app`/`__MAIN_START__`/`command64.inc` reference to LABEL
   remains; a no-change rebuild alters neither `label.prg` nor
   `label.ref.hex`; `check_casm_source_bytes.py` passes on the LABEL
   sources; `casm_oracle_inventory` (non-gating) lists the new manifest
   consistently.

7. **Documentation + tracker sync.** `wiki/label-utility.md` (Artifact
   Provenance), byte-oracle audit register row, `src/external/AGENTS.md`
   if it names LABEL's toolchain, `CHANGELOG.md`, `brain/KNOWLEDGE.md`,
   Taskwarrior, and a new memory (`project-label-casm-native`, shape of
   the DASH/BANNER provenance memories). Walkthrough doc.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/label/label.s` | Modify (Increment 2) |
| `src/external/label/common.inc` | Deleted; folded into `label.s`'s inline constants (Increments 1-2) |
| `src/external/label/labelver.s` | Create — build-time generated, not checked in (Increments 2/5) |
| `src/external/label/LABEL_VERSION` | Create — app-owned `MAJOR.MINOR.STAGE`, checked in (Increment 2) |
| `scripts/gen_label_version.py` | Create (Increment 2) |
| `src/external/label/build_label.inc` | Delete — ca65 generated version include (Increment 2) |
| `src/external/label/label.ref.hex` | Create (Increment 4) |
| `src/external/label/label-derivation.md` | Create (Increment 4) — or `brain/reviews/2026-09-02-label-casm-native-derivation.md` |
| `src/external/label/BUILD_LABEL` | Modify if form changes (Increment 5) |
| `scripts/build_label_manifest.py` | Create (Increment 4) |
| `CMakeLists.txt` | Modify (Increment 5) |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Modify (Increment 7) |
| `wiki/label-utility.md` | Modify (Increment 7) |
| `docs/label-utility.md`, `release/docs/label-utility.md` | Regenerated by `sync_docs` (Increment 7) |
| `src/external/AGENTS.md` | Modify if it names LABEL's toolchain (Increment 7) |
| `CHANGELOG.md`, `brain/KNOWLEDGE.md` | Modify (Increment 7) |
| `brain/walkthroughs/2026-09-02-label-casm-native-migration.md` | Create (Completion Gate) |

## Stop Conditions

- Increment 1 finds the OS external-command loader does **not** apply R6
  relocation to a dispatched LABEL the way it does for DASH — halt;
  disclose and defer (no loader change belongs in this plan).
- Increment 3's byte diff between pre-/post-conversion assemblies (at the
  same base) is non-empty — halt; the conversion changed behavior.
- Any live-VICE assembly reports a CASM diagnostic instead of
  `CASM: INPUT VALIDATED`.
- A reviewer cannot reproduce an address, byte count, hash, or a
  relocation entry from the derivation record — the manifest is not
  `CANONICAL-INDEPENDENT`; halt.
- Native CASM output ≠ the newly reviewed canonical derivation — stop,
  report first differing offset + context, classify before touching either
  side (`.agents/workflows/canonical-byte-oracles.md` mismatch rules).
- Increment 6's no-change rebuild alters `label.prg` or `label.ref.hex`,
  or `image_d64`/`test_image_d64` fails to build.
- Symbol count or R6 entry count approaches its CASM cap (512 / 4,096) —
  not expected for LABEL; if it happens, stop and reassess.
- A genuinely new defect (in CASM, the manifest tooling, the OS loader, or
  LABEL's own logic) is found outside this plan's scope: disclose and
  defer as a separate, separately-approved follow-up — do not fix inline
  without explicit user direction, and record any authorized deviation in
  Progress + the walkthrough.

## Documentation, Task, and DOX Updates

- **At approval:** create the Taskwarrior task; set frontmatter
  `taskwarrior:` UUID; add `wiki/tasks/label.md` entry if one is tracked.
- **At completion:** `wiki/label-utility.md` Artifact Provenance section
  (mirrored to `docs/`, `release/docs/` by `sync_docs`); byte-oracle audit
  register row with LABEL's provenance state; `src/external/AGENTS.md` if
  it names LABEL's toolchain; `CHANGELOG.md` (ca65 retirement + CASM-native
  adoption); `brain/KNOWLEDGE.md` closing note; Taskwarrior done; new
  `project-label-casm-native` memory.

## Completion Gate

All must be true before LABEL is marked migrated:

- Live VICE evidence: a real native-CASM assembly of the final `label.s`
  under Command64, `CASM: INPUT VALIDATED`, screenshots/register evidence
  per `.agents/workflows/vice-mcp-testing.md`, overlay `test` events fired.
- Functional evidence: every LABEL path exercised live (arg / no-arg
  interactive / prefix / too-long / open-failure / drive-error / OK), with
  the volume name confirmed written on a scratch disk image.
- Byte-identity evidence: pre-/post-conversion same-base PRG diff empty;
  no-change-rebuild diff empty.
- Oracle evidence: `label.ref.hex` bound to source hashes; a peer-reviewed
  independent byte + R6 derivation record linked by path; `casm_r6_verify.py`
  `PASS`; R6 relocation applied and verified at `$3400` + two other bases;
  live `COMP LABEL.PRG,LABEL.REF` → `FILES COMPARE OK`; provenance state
  recorded in the audit register.
- Build evidence: `image_d64` and `test_image_d64` build clean from a fresh
  `cmake -B build`; no ca65/`add_ca65_app`/`__MAIN_START__`/`command64.inc`
  reference to LABEL anywhere; `check_casm_source_bytes.py` passes.
- `brain/walkthroughs/2026-09-02-label-casm-native-migration.md` recording
  all of the above with live evidence, not intentions.
- Trackers synchronized.
- Explicit user approval of the walkthrough — this plan does not
  self-declare completion.

## Progress

- 2026-09-02: Plan drafted, pending approval. Scoping Decisions 1-5
  confirmed with the user (Decisions 1-2 via AskUserQuestion; 3-5 proposed
  here for confirmation at approval). Follows the completed BANNER
  migration precedent; the one materially new element is R6 relocation for
  an app that currently ships as a fixed-`$3800` non-relocatable PRG.
- 2026-09-02: **Plan approved by the user.** Taskwarrior task 41
  (`53e5934a-4617-4263-a870-de7e1cfeb592`, project `label`) created;
  frontmatter updated; status → approved.
- 2026-09-02: **Increment 1(a) — loader confirmation: PASS, no stop
  condition.** `src/command64/shell.asm:319-333` (`sdExt` external-command
  dispatch): after `jsr shellLoadPrg` and before `jsr UserProgStart` it
  calls `jsr relocateExternalCommand` (wraps `aptRelocate`,
  `src/command64/loader.asm:94`). An R6 PRG (footer magic checked at
  `loader.asm:120-128`) is relocated from its `$3400` build origin to
  `UserProgStart` ($3800); a non-R6 PRG has no footer and `aptRelocate`
  returns C=1, deliberately ignored. So LABEL becoming R6-at-`$3400`
  travels the identical dispatch+relocate path DASH/BANNER already prove.
  Matches `project-os-external-cmd-relocation` (the 2026-07-27 fix) and
  confirmed still present in the current tree.
- 2026-09-02: **Increment 1(b) — `src/external/label/labelconst.s`
  created.** Holds every KERNAL vector, OS_API selector, OS global, PETSCII
  code, ZP scratch, and drive-protocol constant LABEL uses, as
  bare-literal `NAME = $VALUE` equates, all-uppercase ASCII, each value
  hand-derived (KERNAL jump table / Command64 memory map / CBM DOS) and
  comment-cited, then cross-checked against `include/ca65/command64.inc`
  and `common.inc` — not copied from them as the authority. **Decision on
  `common.inc`:** folded into `labelconst.s`; `common.inc` will be deleted
  in Increment 2 (same increment that converts `label.s` and thereby
  breaks the ca65 build that still references it — kept until then so the
  pre-conversion ca65 baseline for Increment 3 stays buildable).
  `labelconst.s` is not yet `.INCLUDE`d by anything and not yet packaged.
- 2026-09-02: **User directive mid-session: "use new CASM features where
  appropriate."** Recorded as Scoping Decision 5; Scoping Decision 2
  refined (LABEL keeps its own app version, not repo `VERSION`; generator
  is `scripts/gen_label_version.py` reading `LABEL_VERSION` + `BUILD_LABEL`).
  Checked the language surface against the CASM programmer's reference /
  `project-casm-phase12..15-complete`: named constants, `@local` labels,
  string + character literals, `.RES` all available and appropriate;
  `.ASSERT` (no comparison operator) and conditional assembly have no
  useful LABEL site; multiplicative/paren arithmetic is documented
  unimplemented so it is avoided (LABEL needs only `symbol - 1` /
  `symbol + 1` addends, which are in the bounded-expression grammar).
- 2026-09-02: **Increment 2 — source conversion done (pre-VICE).**
  - `scripts/gen_label_version.py` + `src/external/label/LABEL_VERSION`
    (`0.4.0`) created; generator emits `labelver.s` as a single native
    `.BYTE "LABEL V0.4.0.1047", $0D, $00` string literal.
  - `label.s` fully rewritten: `.INCLUDE "LABELCONST.S"` / `.INCLUDE
    "LABELVER.S"` (the latter at the end, in the data area); removed
    `.include "command64.inc"`, `.include "common.inc"`, `.define
    VERSION_*`, `.include "build_label.inc"`, `.import __MAIN_START__`,
    `.segment "HEADER"`, `.word __MAIN_START__`, `.segment "CODE"`. Whole
    file uppercased. Every routine-internal branch target is now an
    `@local` under the single `START` scope; `PRINTERRCODE` and
    `LABELEXIT` stay global (callable subroutine / shared exit); data
    labels stay global. Messages → native string literals
    (`OKMSG`/`LENMSG`/`REQMSG`/`PROMPTMSG`/`DEVMSG`). `BUFNAME` → `.BYTE
    '#'`. Comparisons → char literals (`#' '`, `#'0'`, `#PETCR`,
    `#PETDEL`). Size sites use `VOL_NAME_LEN-1` / `VOL_NAME_LEN+1` /
    `STATUSBUFLEN-2` bounded-expression addends. Drive-command strings
    (`CMDINIT`/`CMDU1`/`CMDBP`/`CMDU2`) kept as explicit reviewed hex.
    `.res` → `.RES` (`STATUSBUF STATUSBUFLEN,$00` / `LABELBUF
    VOL_NAME_LEN,PADCHAR` / `LASTERRCODE 1`).
  - Collision audit: no two identifiers differ only by case
    (`check_casm_source_bytes.py` confirms).
  - `common.inc` deleted (`git rm`), folded into `labelconst.s`;
    `build_label.inc` deleted; `BUILD_LABEL` trimmed to the plain
    single-line counter form (`1047`).
  - `check_casm_source_bytes.py` passes on all three CASM sources. Comment
    text had to drop/uppercase every lowercase path reference (the checker
    rejects lowercase even in comments) — `banner.s` precedent.
  - **ca65 build of `label` is now broken** (uppercase `.INCLUDE`
    operands, `@local`, no `.segment`) — expected; Increment 5 removes the
    ca65 target. Not building `label` until then. The pre-conversion
    `label.s` remains in git history for Increment 3's same-base baseline.
  - **Not yet done in Increment 2:** live-VICE parse/assembly (that is
    Increment 3). No native CASM runs on the host, so first real proof the
    converted source assembles is the Increment 3 VICE run.
- 2026-09-02: **Increment 3 — live VICE, first run: CASM defect found in
  `.INCLUDE`d constants; plan deviation required.**
  - Test disk `build/command64_label_test.d64` built manually (cc1541):
    `command64` + `casm` + `comp` PRGs (lowercase `-f` spelling — an
    uppercase `-f CASM` first attempt gave `BAD COMMAND OR FILE NAME`
    because the shell looks up the unshifted-PETSCII name), plus `label.s`
    / `labelconst.s` / `labelver.s` as SEQ and the ca65 `$3400` baseline
    (`label.base`, 846 B, built one-time non-committed via `ca65 -t c64` +
    `ld65` with a `$3400`-patched copy of `build/build_label_cfg/`).
  - Boot confirmed (`Command 64-DOS Version 0.4.1.2680`, `C64[8]:>`).
    `CASM LABEL.S /O:LBL.PRG` → native CASM `0.6.2` build `1419`:
    `P1 DONE 00382`, `P2 DONE 00382`, `01186 BYTES`,
    **`CASM: INPUT VALIDATED`** — the converted syntax parses and
    assembles clean (`@local` labels, string/char literals, `.RES`,
    bounded-expression addends, `.INCLUDE` chain all accepted).
  - **But the output was 1186 B vs the baseline's ~846 B code/data.**
    Host diff of the extracted `LBL.PRG` against `label.base`: CASM
    emitted **3-byte absolute** addressing for every zero-page-valued
    named constant (`SAVEDDEVICE`=$71 → `8D 71 00`, `PARSEPOS`=$63 →
    `AC 63 00`, `PRINTPTRLO/HI`=$FB/$FC → `8D FB 00` / `8D FC 00`), where
    ca65 correctly used `85 71` / `A4 63` / `85 FB` / `85 FC`. Cascading
    +1-byte shifts → 760 diffs.
  - **Root cause (confirmed by a second VICE run):** CASM's zero-page
    addressing-mode selection for a *resolved, non-label-derived* named
    constant (the WP72 behaviour) **does not apply when the constant is
    defined in an `.INCLUDE`d file** — only when it is defined inline in
    the main source. `banner.s` defines its ZP constants (`PARSEPOS = $63`
    etc.) inline and `LDY PARSEPOS` correctly assembles to `A4 63`
    (`banner.ref.hex`); LABEL's identical `LDY PARSEPOS` assembled to
    `AC 63 00` solely because `PARSEPOS` came from `LABELCONST.S`.
  - **Verification:** rebuilt the disk with `labelconst.s`'s body inlined
    into the top of `label.s` (no `.INCLUDE` for constants; `LABELVER.S`
    still included, at the end, as data). Re-run: `P1/P2 DONE 00381`,
    **`00956 BYTES`**, `CASM: INPUT VALIDATED`. Host diff vs `label.base`:
    **exactly 6 differing bytes** — `$3700-$3704` (`CC C1 C2 C5 CC` →
    `4C 41 42 45 4C`, "LABEL" shifted→unshifted) and `$3706`
    (`D6` → `56`, "V") — i.e. only the deliberate, pre-documented version-
    banner unshift (Scoping Decision 2 note). All 844 other code/data
    bytes identical to the independent ca65 `$3400` baseline. Plus 110 B
    of R6 relocation table + `52 36` footer the baseline structurally
    lacks (to be derived/verified in Increment 4).
  - **DEVIATION FROM APPROVED PLAN (pending user sign-off):** the plan
    specified a separate `labelconst.s` include. That does not work with
    current CASM. Recommended resolution: **inline the constants into
    `label.s`** (matches the BANNER precedent and DASH's "constants in the
    prologue" contract), drop `labelconst.s` from the plan, and file the
    `.INCLUDE`d-constant ZP-selection defect as a **separate CASM task**
    (also relevant to the review's "minimal CASM-safe OS/API constants
    source" cross-app prerequisite and to COMP/FORMAT/CONWAY).
  - **Not yet done in Increment 3:** the functional exercise of every
    LABEL code path (arg / no-arg interactive / prefix / too-long /
    open-failure / drive-error / OK) — pending the deviation decision so
    the functional run uses the final source form.
- 2026-09-02: **Deviation approved by the user (AskUserQuestion): inline
  the constants, file the CASM bug separately.** Done:
  - `labelconst.s`'s body folded into the top of `label.s` (organized
    KERNAL / OS API / OS globals / ZP pointer / PETSCII / ZP scratch /
    protocol sections); `labelconst.s` deleted (was never committed).
    `check_casm_source_bytes.py` passes on `label.s` + `labelver.s`.
  - Taskwarrior task 42 (project `label`) filed for the CASM
    `.INCLUDE`d-constant ZP-selection defect. Not fixed here.
  - Memory `project-casm-included-constant-zp-absolute` written.
  - Scoping Decision 1, Objective item 2, and Expected Files updated to
    reflect inline constants.
  - Re-verification of the inlined `label.s` under VICE + the full
    functional sweep continue as the rest of Increment 3.
- 2026-09-02: **Increment 3 — inlined `label.s` re-verified + partial
  functional sweep.**
  - Native CASM (`0.6.2` b1419) on the real committed `label.s`:
    `P1/P2 00381`, `00956 BYTES`, `CASM: INPUT VALIDATED`. Extracted
    `LBL.PRG` sha256 `27cc28ee…`. Host diff vs the ca65 `$3400` baseline:
    **6 bytes**, all in `$3700-$3706` (version-banner "LABEL V"
    shifted→unshifted); 838 other shared bytes identical; + R6 table +
    `52 36` footer.
  - Functional (dispatched by name → loaded `$3800` → `relocateExternal
    command` applied R6):
    - `LABEL 9:FUNCNAME` → version banner, `LABEL UPDATED`, clean return
      to `C64[8]:>` — **OK path + prefix parse + R6 relocation all work.**
    - `LABEL ABCDEFGHIJKLMNOPQR` (18 chars) → version banner,
      `LABEL TOO LONG (MAX 16)`, clean return — **too-long path works.**
  - **FINDING — version banner now renders lowercase.** Command64 runs
    the mixed-case (lowercase) charset, where CHROUT of unshifted PETSCII
    `$41-$5A` displays *lowercase*. LABEL's other messages have always
    been explicit unshifted hex, so they already render lowercase
    ("label updated", "label too long…"). The **old** `verMsg` used a ca65
    `.byte "LABEL V"` string literal that ca65 `-t c64` turned into
    *shifted* `$CC…` → the banner alone rendered UPPERCASE, inconsistent
    with every other LABEL message. The new generated `LABELVERMSG`
    (unshifted) renders `label v0.4.0.1047` — lowercase, **consistent**
    with the rest of LABEL's output, but a visible case change from the
    retired build. My earlier "same glyph" claim was wrong: the case
    changes. **Needs a user decision** (accept the consistency fix, or
    have `gen_label_version.py` emit shifted `$C1-$DA` letter bytes to
    preserve the uppercase banner).
  - **Open / deferred within Increment 3:** no-arg interactive prompt
    path, open-error / drive-error path, and a positive confirmation that
    a prefixed volume-name write lands on the target disk (a `DIR 9` after
    the `9:` write unexpectedly listed device 8 — likely a two-drive test
    harness / device-state issue after `vice_autostart`, not a LABEL
    change since the code bytes are baseline-identical; to be re-checked
    with a cleaner drive-9 setup).
- 2026-09-02: **User decision on the banner: match DEBUG's format
  ("DEBUG v0.5.0.1128").** `gen_label_version.py` reworked: emits the app
  name as explicit *shifted* PETSCII (`$CC $C1 $C2 $C5 $CC` -> UPPERCASE
  glyph on the mixed-case charset), then `$20 $56` (space + unshifted 'V'
  = lowercase 'v' glyph), then `.BYTE "0.4.0.1047", $0D, $00` (digits/dots
  only in the string literal). `check_casm_source_bytes.py` passes
  (`labelver.s` has no letter bytes in its string literal).
- 2026-09-02: **Increment 3 re-run with the DEBUG-format banner + full
  functional sweep — GREEN.**
  - Native CASM `0.6.2` b1419 on the final `label.s` + `labelver.s`:
    `P1/P2 00382`, `00956 BYTES`, `CASM: INPUT VALIDATED`.
    Extracted `LBL.PRG` sha256 `d0246930…`.
  - **Host diff vs the independent ca65 `$3400` baseline: exactly 1 byte**
    — `$3706` `D6` -> `56` (shifted 'V' / uppercase glyph -> unshifted 'V'
    / lowercase 'v'), the user-approved DEBUG-format change. All 843 other
    shared code/data bytes identical. + 110 B R6 table + `52 36` footer
    (footer tail `3a 02 3d 02 00 34 34 00 52 36` — to be parsed with
    `casm_r6_verify.py` in Increment 4).
  - Functional, dispatched by name (loaded `$3800`, R6-relocated):
    - Banner renders **`LABEL v0.4.0.1047`** (uppercase LABEL glyph,
      lowercase v) — DEBUG format confirmed on screen.
    - `LABEL` (no arg) -> `LABEL NAME REQUIRED` (`@NOARGERR`).
    - `LABEL ABCDEFGHIJKLMNOPQR` -> `LABEL TOO LONG (MAX 16)`
      (`@TOOLONGERR`).
    - `LABEL 8:` -> interactive prompt `VOLUME LABEL (16 CHARS MAX)? `;
      typed `MYVOL` + CR -> input echoed -> `LABEL UPDATED`
      (`@LABELNOARG` readLoop + interactive OK path).
    - **Write persisted:** detached `label_func_test.d64`, BAM disk-name
      bytes = `4D 59 56 4F 4C A0*11` = "MYVOL" padded to 16 with `$A0`
      (`PADCHAR`) — the U1/B-P/U2 volume-name write is correct end to end.
    - `LABEL 11:x` (device absent) -> `DRIVE ERROR 05` — `@OPENERR` +
      `PRINTERRCODE` two-digit decimal formatting correct (the DASH-WP6-
      style X-as-tens-accumulator path).
    - Every run returned cleanly to `C64[8]:>`.
  - **Still open (moved to later increments):** R6 relocation verified at
    multiple load bases (Increment 4 derivation + Increment 6), live
    `COMP LABEL.PRG,LABEL.REF` against the reviewed manifest (needs the
    Increment 4 manifest). Minor untested sub-path: DEL/backspace editing
    inside the interactive readLoop.
  - **Increment 3 verdict: PASS.** Converted source assembles clean;
    output is byte-identical to an independent same-base ca65 reference
    except one deliberate, user-approved banner byte; all functional paths
    exercised behave correctly including the real drive-protocol write.
- 2026-09-02: **Increment 4 — derivation + manifest + live COMP: done
  (pending reviewer sign-off).**
  - `scripts/build_label_manifest.py` created (single-file twin of
    `build_banner_manifest.py`; 3 `source_sha256` entries — `label.s`,
    `LABEL_VERSION`, `BUILD_LABEL`).
  - `src/external/label/label.ref.hex` generated from the reviewed
    `LBL.PRG` (956 B, sha256 `d0246930…`). Round-trips:
    `hex_manifest_to_bin.py --source-dir` → byte-identical to native CASM
    output; source-hash gate exercised.
  - `src/external/label/label-derivation.md` written — Native-application-
    manifest + R6-PRG oracle classes:
    - **Code/data bytes:** independently corroborated by a same-base
      (`$3400`) ca65/ld65 build of the pre-migration source
      (`label_base3400.prg`, 846 B, sha256 `83161418…`, no R6 footer).
      843/844 image bytes identical; the 1 difference (`$3706` `D6`→`56`)
      is the approved DEBUG-format banner unshift. ca65 symbol map
      reconciles every routine/data address to the CASM layout — the
      migration is length-preserving.
    - **R6 ledger:** `scripts/casm_r6_verify.py` → `R6 VERIFY: PASS`
      (base `$3400`, 52 entries, ascending/unique, all in-image,
      relocates cleanly to `$3800`/`$5000`/`$9000`). Independent
      eligibility reconciliation: 45 three-byte absolute operands (every
      target matches the ca65 map) + 7 `#>label` high-byte immediates
      = 52, exactly CASM's count; zero entries for fixed addresses
      (`$1000`/`$FFxx`/`$039E`/`$033C`) or `#<label` low bytes.
  - **Live `COMP LABEL.PRG LABEL.REF` on the C64 → `FILES COMPARE OK`**
    (native CASM 0.6.2 b1419; assembled `label.s` on device 8, compared
    against the manifest-derived `label.ref`). Overlay `test`/`pass`
    event fired.
  - Audit-register row added
    (`brain/reviews/2026-09-01-casm-byte-oracle-audit.md`): LABEL native
    app → `label.ref.hex` `CANONICAL-INDEPENDENT` **pending reviewer
    sign-off**.
  - **Open in Increment 4:** the independent-reviewer sign-off on
    `label-derivation.md` (the workflow's peer-review step — the user or a
    second pass). Everything mechanical is complete.
- 2026-09-02: **Increments 5 + 6 — CMake rewire + full-rebuild verify: PASS.**
  - `CMakeLists.txt`: removed `add_ca65_app(label ...)` + its `Ca65_FOUND`
    fatal branch and the `LABEL_SRCS`/`LABEL_ENTRY` globs; updated the
    `find_package(Ca65)` comment. Added, next to the `banner` manifest
    target: the manifest-derived `label` target (`hex_manifest_to_bin.py
    --source-dir`, `C64_PRG_PATH` set, `set(LABEL_TARGET label)` — so
    `IMAGE_BASE_PRG_TARGETS` is unchanged). Added `label_version_src`
    (custom command running `gen_label_version.py` → `${CMAKE_BINARY_DIR}/
    labelver.s`) and `command64_label_test_d64` (command64 + casm + comp
    PRGs; PRE_BUILD `check_casm_source_bytes.py` gate; POST_BUILD packs
    `label.s` + generated `labelver.s` as SEQ and the manifest-derived
    `label.ref` as PRG).
  - `labelver.s` is now a build product in `${CMAKE_BINARY_DIR}`, not in
    the source tree (removed) — no `.gitignore` entry needed.
  - Fresh `rm -rf build && cmake -B build`: configures with **no
    warnings/errors**. Full `cmake --build build`: **all targets build
    clean**. `build/label.prg` sha256 `d0246930…` == the manifest.
    `image.d64` carries `LABEL` (position 3, as before);
    `test_image_d64` builds; `command64_label_test.d64` carries
    COMMAND64/CASM/COMP + LABEL.S/LABELVER.S/LABEL.REF.
  - **No-change rebuild:** `label.prg`, `image.d64`,
    `command64_label_test.d64` all byte-identical.
  - **Stale-source gate verified:** appending a comment to `label.s`
    without regenerating the manifest → hard build failure
    (`hex_manifest_to_bin.py: source file 'label.s' has changed since the
    manifest was generated`); reverting → clean. (Minor: the shared
    script's hint text says "regenerate ... with build_dash_manifest.py"
    — wrong script name for LABEL/BANNER; cosmetic, shared tooling, not
    fixed here.)
  - `scripts/casm_oracle_inventory.py`: added `label.ref.hex` to
    `NATIVE_MANIFESTS`; `reconciliation: OK`, 3 native manifests, 70/70
    declared sha256 + independent-derivation-claim.
  - No `add_ca65_app`/`__MAIN_START__`/`command64.inc`/`build_label.inc`
    reference to LABEL remains anywhere.
- 2026-09-02: **Increment 7 — docs + walkthrough + trackers: done.**
  - `wiki/label-utility.md`: version → `0.4.0.1047` / banner
    `LABEL v0.4.0.1047`; target-address line rewritten for R6 relocation;
    new **Artifact Provenance** section (manifest model, stale-source
    guard, generated banner, derivation record, `command64_label_test_d64`
    reassembly recipe); `drive error 05` error example corrected; the
    "no arguments prompts interactively" line made precise. `sync_docs`
    propagated to `docs/label-utility.md`.
  - `CHANGELOG.md` [Unreleased]/Added — LABEL CASM-native entry.
  - `brain/KNOWLEDGE.md` — new "LABEL → CASM-native" section after the
    Byte-Oracle Transition section.
  - `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` — LABEL native-app
    row.
  - `brain/task.md` — new "External Applications: CASM-Native Migration"
    section with LABEL's increment checklist + the task-42 note.
  - `brain/walkthroughs/2026-09-02-label-casm-native-migration.md` written
    (this WP's live-evidence record).
  - Taskwarrior: task 41 annotated (increments 1-7 complete, awaiting
    sign-off); task 42 annotated (repro + workaround pointers).
  - Memory: `project-label-casm-native-migration` updated to
    increments-1-7-complete; `project-casm-included-constant-zp-absolute`
    and `MEMORY.md` index entries added.
- 2026-09-02: **All seven increments implemented. Handing to the user for
  the Completion Gate:** (1) reviewer sign-off on `label-derivation.md`,
  (2) approval to close task 41. No self-declared completion.
