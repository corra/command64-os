---
feature: format-casm-native-migration
created: 2026-09-02
status: complete
taskwarrior: 1c11e31a-be94-49b2-bc49-d511f7bef45d
depends-on: LABEL CASM-native migration (complete, merged to main 2026-09-02, commit 39b0ef5)
---

# Plan: FORMAT — Migration to Native CASM (ca65 Retirement)

## Status

**COMPLETE — user-approved 2026-09-02.** All seven increments implemented,
walkthrough (`brain/walkthroughs/2026-09-02-format-casm-native-migration.md`)
signed off, `format-derivation.md` reviewer-approved, `format.ref.hex`
provenance `CANONICAL-INDEPENDENT`, Taskwarrior task closed. FORMAT is
CASM-native; ca65 retired.

Stage 2 of the external-applications CASM-native migration
(`brain/reviews/2026-09-01-external-applications-casm-native-viability.md`).
Directly follows the completed LABEL pilot
(`brain/plans/2026-09-02-label-casm-native-migration.md`,
`brain/walkthroughs/2026-09-02-label-casm-native-migration.md`) — this plan
reuses LABEL's proven shape and only calls out where FORMAT differs.

## Objective

Retire FORMAT's ca65/ld65 build and make FORMAT a CASM-native application:
`format.s` assembled only by native CASM under Command64, `format.prg`
shipped from a reviewed hex manifest (`src/external/format/format.ref.hex`)
bound to source hashes, backed by an independent byte + R6 relocation
derivation record.

Delivers:

1. `src/external/format/format.s` — self-contained native CASM (constants
   inline, `@local` labels, native string/character literals, `.RES`
   storage; no `.include "command64.inc"`, no `.import`, no `.segment`, no
   ca65 `.define`).
2. Inline named constants replacing `command64.inc` + `common.inc`.
3. Build-time generated version banner: `src/external/format/FORMAT_VERSION`
   (`0.1.0`) + `BUILD_FORMAT` → `scripts/gen_format_version.py` →
   `formatver.s` (build product).
4. `src/external/format/format.ref.hex` + `scripts/build_format_manifest.py`
   + `src/external/format/format-derivation.md`.
5. `CMakeLists.txt`: `add_ca65_app(format …)` removed; manifest-derived
   `format` target + `command64_format_test_d64` added; `FORMAT_TARGET`
   still points at `format` so `IMAGE_BASE_PRG_TARGETS` is unchanged.
6. `wiki/format-utility.md` (new, mirroring `wiki/label-utility.md`),
   synced to `docs/`; `CHANGELOG.md`; `brain/KNOWLEDGE.md`; audit register
   row.
7. `scripts/casm_oracle_inventory.py` — `format.ref.hex` added to
   `NATIVE_MANIFESTS`.

**Does NOT deliver:** any change to FORMAT's command syntax, parsing rules,
validation rules, the two-step destructive confirmation, the interactive
prompt flow, or the `DOS_SEND_COMMAND` call sequence — **except** the two
deliberate, enumerated changes in Scoping Decisions 1 and 2 below (message
case and the `:N:` command byte).

## Scoping Decisions (user-confirmed 2026-09-02)

1. **On-screen case: banner uppercase, all other messages lowercase.**
   FORMAT's entire UI currently renders **uppercase** because ca65 `-t c64`
   shifts the letters in its `.byte "…"` string literals (verified:
   `build/format.prg` offset 965 holds `C6 CF D2 CD C1 D4` = "FORMAT"
   shifted). Native CASM emits **unshifted** letter bytes, which render
   *lowercase* on Command 64's mixed-case charset. This migration accepts
   that: every prompt / error / result message becomes a native
   `.BYTE "…"` string literal rendering lowercase (matching LABEL, whose
   messages have always rendered lowercase). The **version banner** keeps
   the app-name glyph uppercase — `gen_format_version.py` emits `FORMAT` as
   shifted PETSCII then `" v"` + digits, exactly like LABEL's
   `LABELVERMSG` (`FORMAT v0.1.0.<build>`). This is a broad, intentional
   visual change, enumerated byte-for-byte in the derivation record.

2. **The `:N:` drive-command bytes are corrected to explicit unshifted
   hex.** `litNColon: .byte ":N:"` currently assembles under ca65 `-t c64`
   to `$3A $CE $3A` — a **shifted** `N` (`$CE`), verified at
   `build/format.prg` offset 1358. The 1541 command parser matches the NEW
   command against `N` = `$4E`; `$CE` is very likely rejected as a syntax
   error, meaning **the shipped ca65 FORMAT may never have successfully
   formatted a disk** (the task-spec end-to-end VICE verification checkbox
   in `wiki/tasks/format.md` is unchecked). The CASM-native `LITNCOLON`
   emits `$3A $4E $3A $00` (explicit reviewed bytes — canonical-byte-oracle
   guidance for protocol payloads, same rule LABEL's `CMDINIT`/`CMDU1`
   follow). Increment 3 establishes the *old* FORMAT's real behaviour
   against a scratch disk first, then proves the new one formats
   correctly. If the old build is confirmed broken, that is disclosed as a
   fixed defect, not hidden.

3. **App-specific tooling twins.** `scripts/gen_format_version.py` and
   `scripts/build_format_manifest.py` are copies of LABEL's, parameterised
   for FORMAT. LABEL's scripts and shipped wiring are **not touched**.
   Generalising the two into shared `gen_app_version.py` /
   `build_app_manifest.py` is deferred to a separate cleanup once 3-4
   CASM-native apps exist.

4. **ca65 retired in this same plan** (like LABEL / BANNER) — the
   CASM-native syntax and the message-case change are only unconditionally
   safe once ca65 no longer compiles `format.s`.

5. **No ca65 differential kept.** No `format_ref` target. The correctness
   oracle is `format-derivation.md` + live `COMP` +
   `casm_r6_verify.py`. A one-time, non-committed ca65 build is used in
   Increment 4 only as post-derivation comparison evidence.

6. **Use new CASM features** (as LABEL): inline named constants, `@local`
   for every routine-internal branch target (routine entry points —
   `printStr`, `readLine`, `appendStr`, `computeDevDigits`,
   `parseDeviceDigits`, `validateDeviceNum`, `validateName`, `validateId`,
   `validateCharset`, `rtrimName`, `rtrimConfirm`, `compareNames`,
   `promptDevice`, `promptName`, `promptId`, `confirmDestructive`,
   `sendFormatCommand` — stay global), native string literals for
   messages, character literals for comparisons (`#','`, `#':'`, `#' '`,
   `#'0'`, `#'9'+1`, `#'1'`, the `#'Y'`/`#'y'` confirm keys — all
   byte-identical to the current explicit hex), `.RES` for the BSS block.
   `.ASSERT` / conditional assembly have no useful site.

7. **Verification bar: VICE scratch-disk format, no hardware.** The
   completion gate requires an end-to-end format of a throwaway `.d64`
   under VICE — confirm gate (Y/N + name re-type), the assembled command
   bytes checked explicitly, `DOS_SEND_COMMAND` status response reported,
   and the re-attached image mounting with the given name/ID and an empty
   directory — plus LABEL's bar: same-base byte comparison, no-change
   rebuild, live `COMP`, R6 verified at `$3400` + two other bases, and the
   full non-destructive path sweep (CLI parse, prefix, each validation
   error, each interactive reprompt, Y/N abort, name-mismatch abort). No
   real 1541 hardware.

## Technical Notes

### How FORMAT differs from LABEL

| Aspect | LABEL (done) | FORMAT | Handling |
| --- | --- | --- | --- |
| Source size | ~10.5 KB | ~15.4 KB + 1 KB inc | comfortably under CASM's 64 KB cap; no concern |
| Messages | already unshifted hex (lowercase) | **string literals, ca65-shifted (uppercase)** | convert to native `.BYTE "…"` → lowercase (Decision 1) |
| Drive payload | `CMDINIT`/`CMDU1`/… explicit hex, kept verbatim | `litNColon` = `.byte ":N:"` → ca65 **shifts the `N`** | `LITNCOLON: .BYTE $3A,$4E,$3A,$00` — corrected (Decision 2) |
| Exit | `RTS` to shell | `DOS_EXIT` via `OS_API` | keep — add `DOS_EXIT = $4C` inline constant |
| Interactive input | one `readLoop` | shared `readLine` subroutine + 3 prompt loops + a confirm re-type | all internal loops → `@local`; `readLine` etc stay global |
| ZP scratch | `$70/$71` | `$70/$71/$72` (`BufPtrLo/Hi`, `MaxLen`) + `$FB/$FC` (`PrintPtrLo/Hi`) | inline constants (Decision 6; not `.INCLUDE` — CASM defect, see below) |
| Relocation | none → R6 `$3400` | none → R6 `$3400` | identical: `sdExt` loader relocates (confirmed for LABEL, re-checked) |
| ca65 differential | clean 843/844, 1 intentional byte | many intentional byte differences | derivation reference = ca65 build of a *messages-forced-unshifted* copy (see below) |

### CASM `.INCLUDE`d-constant defect (Taskwarrior task 42)

CASM 0.6.2 emits 3-byte absolute addressing for a zero-page-valued named
constant defined in an `.INCLUDE`d file (found during LABEL Increment 3;
`project-casm-included-constant-zp-absolute`). FORMAT's constants
(`BufPtrLo = $70`, `MaxLen = $72`, `PrintPtrLo = $FB`, `ParsePos = $63`,
…) **must be defined inline in `format.s`**, not in an include. This is
already a given, not a risk to discover.

### Independent byte reference

Because Decision 1 changes a large number of bytes, a raw ca65 `-t c64`
build is not a clean reference. The independent codegen check is a **ca65
build, linked at `$3400`, of a derivation-only copy of `format.s` in which
every `.byte "…"` string is mechanically rewritten to explicit unshifted
hex, `:N:` is `$4E`, and the banner is in DEBUG form** — i.e. a copy that
*should* match native CASM byte-for-byte. The rewrite is a scriptable,
line-by-line-reviewable transform (ASCII→unshifted PETSCII is the identity
map for `$20-$5A` and `$5B-$7A`→graphics is simply not used). ca65 and CASM
still select opcodes / addressing modes / branch displacements
independently, so an agreement on the resulting stream is genuine
corroboration. Target: byte-identical, or a small enumerated set each
traced to a cause.

### Command-string assembly

`sendFormatCommand` builds `CmdBuf` = `<DevDigits>` + `":N:"` + `<NameBuf>`
+ `","` + `<IdBuf>` + `$00`. `DevDigits` are `'0'`-`'9'` (charmap-invariant),
`NameBuf`/`IdBuf` are user bytes passed through verbatim. Only `LITNCOLON`
and `LITCOMMA` are literal protocol bytes — both frozen as explicit hex.
The live format test checks the exact `CmdBuf` contents before the send
(via a VICE memory read at `CmdBuf`).

## Atomic Increments

1. **Constants + protocol bytes + reference-transform prep.**
   (a) Re-confirm the `sdExt` loader relocates a dispatched R6 FORMAT
   (one read of `shell.asm` — expected trivially true from LABEL).
   (b) Enumerate the inline constant block (from `command64.inc` +
   `common.inc`, hand-derived + cited per `project-casm-trusted-reference-rule`).
   (c) Freeze `LITNCOLON` / `LITCOMMA` as explicit hex.
   (d) Write `scripts/gen_format_version.py` (twin of
   `gen_label_version.py`, `APP_NAME = "FORMAT"`); create `FORMAT_VERSION`
   (`0.1.0`); trim `BUILD_FORMAT` to the plain counter form.
   No `format.s` edit yet.

2. **Source conversion.** Rewrite `format.s`: strip ca65 machinery; add the
   inline constants + `.INCLUDE "FORMATVER.S"` (at the end, data area);
   uppercase the whole file; collision-audit identifiers; convert every
   routine-internal label to `@local`; convert messages to native
   `.BYTE "…"` string literals; convert comparison sites to character
   literals; `.res` → `.RES`; `LITNCOLON`/`LITCOMMA` to explicit hex.

3. **Live VICE — the hard gate.**
   (a) Package `command64_format_test.d64` (command64 + casm + comp +
   `format.s` + `formatver.s` as SEQ + the manifest-derived `format.ref`).
   (b) `CASM FORMAT.S /O:FMT.PRG` → require `CASM: INPUT VALIDATED`.
   (c) Extract `FMT.PRG`; byte-compare against the Increment-4 independent
   reference at `$3400`; every difference enumerated + explained.
   (d) **Old-FORMAT baseline:** run the *current shipped* `format.prg`
   against a throwaway `.d64` on device 9 and record what it actually does
   (formats / syntax-errors / other).
   (e) **New-FORMAT functional sweep:** CLI parse (`FORMAT 9:VOL,42`),
   `<dev>:` prefix, each validation error (bad device / bad name / bad
   ID), each interactive reprompt, Y/N abort, name-mismatch abort, and a
   full end-to-end format of a scratch device-9 `.d64` — check `CmdBuf`
   bytes before send, capture the `RESULT:` status line, detach + re-attach
   and confirm the image mounts with the given name/ID and an empty
   directory. Fire overlay `test` events.

4. **Derivation + manifest.** Build the `$3400` independent reference
   (Technical Notes). Write `format-derivation.md` (Native-app-manifest +
   R6-PRG classes: address ledger, message-byte enumeration, `:N:` fix,
   relocation-eligibility ledger reconciled to CASM's entry count via
   `casm_r6_verify.py`). Write `scripts/build_format_manifest.py` (twin);
   generate `format.ref.hex`. Live `COMP FMT.PRG FORMAT.REF` →
   `FILES COMPARE OK`. Reviewer sign-off.

5. **CMake rewire.** Remove `add_ca65_app(format …)` + its `Ca65_FOUND`
   fatal branch + the `FORMAT_SRCS`/`FORMAT_ENTRY` globs; update the
   `find_package(Ca65)` comment. Add the manifest-derived `format` target
   + `formatver.s` generator custom command + `command64_format_test_d64`
   (with the `check_casm_source_bytes.py` PRE_BUILD gate). Keep
   `set(FORMAT_TARGET format)`. Add `format.ref.hex` to
   `scripts/casm_oracle_inventory.py`.

6. **Full-rebuild verification.** Fresh `rm -rf build && cmake -B build` +
   full `cmake --build build` — no warnings/errors; `image.d64` carries
   `FORMAT` from the manifest; `test_image_d64` builds; no-change rebuild
   byte-identical; stale-source gate fires on a `format.s` edit;
   `casm_oracle_inventory` reconciliation OK; no
   `add_ca65_app`/`__MAIN_START__`/`command64.inc`/`build_format.inc`
   reference to FORMAT remains.

7. **Docs + walkthrough + trackers.** New `wiki/format-utility.md`
   (mirroring `label-utility.md`, incl. an Artifact Provenance section and
   noting the case change + `:N:` fix), synced to `docs/`; `CHANGELOG.md`;
   `brain/KNOWLEDGE.md`; audit register row; `brain/task.md` FORMAT
   checklist; `wiki/tasks/format.md` end-to-end checkbox updated;
   `brain/walkthroughs/2026-09-02-format-casm-native-migration.md`;
   Taskwarrior; memory (`project-format-casm-native-migration`).

## Expected Files

| File | Action |
| --- | --- |
| `src/external/format/format.s` | Modify (Increment 2) |
| `src/external/format/common.inc` | Delete — folded into inline constants (Increment 2) |
| `src/external/format/FORMAT_VERSION` | Create (Increment 1) |
| `src/external/format/formatver.s` | Build product — generated to `${CMAKE_BINARY_DIR}`, not checked in |
| `src/external/format/BUILD_FORMAT` | Modify — trim to plain counter (Increment 1) |
| `src/external/format/format.ref.hex` | Create (Increment 4) |
| `src/external/format/format-derivation.md` | Create (Increment 4) |
| `scripts/gen_format_version.py` | Create (Increment 1) |
| `scripts/build_format_manifest.py` | Create (Increment 4) |
| `scripts/casm_oracle_inventory.py` | Modify (Increment 5) |
| `CMakeLists.txt` | Modify (Increment 5) |
| `wiki/format-utility.md` | Create (Increment 7) |
| `docs/format-utility.md` | Generated by `sync_docs` (Increment 7) |
| `wiki/tasks/format.md` | Modify — check the end-to-end box (Increment 7) |
| `CHANGELOG.md`, `brain/KNOWLEDGE.md`, `brain/task.md` | Modify (Increment 7) |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Modify (Increment 4/7) |
| `brain/walkthroughs/2026-09-02-format-casm-native-migration.md` | Create (Completion Gate) |

## Stop Conditions

- Increment 1(a) finds the `sdExt` loader does **not** relocate a
  dispatched FORMAT — halt, disclose, defer (no loader change here).
- Any live CASM assembly reports a diagnostic instead of
  `CASM: INPUT VALIDATED`.
- Increment 3(c) byte differences that are **not** fully explained by the
  enumerated Decision-1/Decision-2 transforms — halt; classify before
  touching either side (`.agents/workflows/canonical-byte-oracles.md`).
- The scratch-disk format in Increment 3(e) does not produce a clean,
  correctly-named, empty-directory image — halt; the new command
  construction is wrong.
- A reviewer cannot reproduce an address / byte / R6 entry from
  `format-derivation.md`.
- Increment 6 no-change rebuild alters `format.prg` or `format.ref.hex`,
  or `image_d64` / `test_image_d64` fails to build.
- Symbol or R6 count approaches a CASM cap (512 / 4096) — not expected.
- A genuinely new defect outside this plan's scope (in CASM, the OS
  `DOS_SEND_COMMAND` handler, the manifest tooling): disclose and defer as
  a separate follow-up; do not fix inline without explicit direction, and
  record any authorized deviation in Progress + the walkthrough. (The
  `:N:` shifted-`N` issue is **in** scope — the command construction is
  being rebuilt.)

## Documentation, Task, and DOX Updates

- **At approval:** create the Taskwarrior task; set frontmatter
  `taskwarrior:`.
- **At completion:** `wiki/format-utility.md` (+ `docs/` via `sync_docs`),
  `wiki/tasks/format.md`, byte-oracle audit register row, `CHANGELOG.md`,
  `brain/KNOWLEDGE.md`, `brain/task.md`, Taskwarrior done, new memory
  `project-format-casm-native-migration`.

## Completion Gate

All true before FORMAT is marked migrated:

- Live VICE: `CASM: INPUT VALIDATED` on the final `format.s`; screenshots /
  register evidence per `.agents/workflows/vice-mcp-testing.md`; overlay
  `test` events fired.
- Byte comparison vs the independent `$3400` ca65 reference — every
  difference enumerated and traced to Decision 1 or Decision 2 (or an
  empty diff).
- End-to-end scratch-disk format under VICE: confirm gate exercised,
  `CmdBuf` bytes verified, drive status reported, re-attached image mounts
  with the given name/ID and empty directory.
- Non-destructive path sweep (CLI / prefix / 3 validation errors / 3
  reprompts / Y-abort / mismatch-abort) all behave per `wiki/tasks/format.md`.
- Old-FORMAT baseline behaviour recorded (so any "it now works" change is
  explicit).
- Oracle: `format.ref.hex` source-hash-bound; `format-derivation.md`
  peer-reviewed; `casm_r6_verify.py` PASS at `$3400` + two bases; live
  `COMP FMT.PRG FORMAT.REF` → `FILES COMPARE OK`; provenance state in the
  audit register.
- Build: fresh `cmake -B build` + `image_d64` + `test_image_d64` clean;
  no-change rebuild identical; stale-source gate verified; no ca65 / `.inc`
  reference to FORMAT anywhere; `check_casm_source_bytes.py` passes.
- `brain/walkthroughs/2026-09-02-format-casm-native-migration.md` with live
  evidence.
- Trackers synchronized.
- Explicit user approval of the walkthrough + reviewer sign-off on
  `format-derivation.md`.

## Progress

- 2026-09-02: Plan drafted. Scoping Decisions 1-7 confirmed with the user
  (1-3, 7 via AskUserQuestion; 4-6 carried from the LABEL precedent). Key
  risk surfaced up front: the shipped ca65 FORMAT sends a shifted `N`
  (`$CE`) in its NEW command and may never have formatted a disk
  successfully — Increment 3 establishes that baseline before the
  CASM-native version corrects it.
- 2026-09-02: **Plan approved.** Taskwarrior task 43
  (`1c11e31a-be94-49b2-bc49-d511f7bef45d`, project `format`); status →
  approved.
- 2026-09-02: **Increment 1 done.**
  - (a) Loader: `src/command64/shell.asm:319-326` — `sdExt` still calls
    `jsr relocateExternalCommand` between `shellLoadPrg` and `jsr
    UserProgStart`. FORMAT-as-R6-at-`$3400` relocates like LABEL. No stop
    condition.
  - (b) Inline constant block enumerated (all hand-derived / cited, then
    cross-checked against `command64.inc` + `common.inc`, not copied):
    OS API — `OS_API=$1000`, `DOS_PRINT_STR=$09`, `DOS_EXIT=$4C`,
    `DOS_PARSE_PREFIX=$57`, `DOS_SEND_COMMAND=$58`; KERNAL —
    `KERNALGETIN=$FFE4`, `KERNALCHROUT=$FFD2`; OS globals —
    `COMMANDBUFFER=$033C`, `PARSEPOS=$63` (ZP); ZP pointer —
    `PRINTPTRLO=$FB`/`PRINTPTRHI=$FC`; PETSCII — `PETCR=$0D`,
    `PETDEL=$14`; app ZP scratch — `BUFPTRLO=$70`/`BUFPTRHI=$71`/
    `MAXLEN=$72`; limits — `NAME_MAX_LEN=16`, `ID_LEN=2`, `DEV_MIN=8`,
    `DEV_MAX=11`.
  - (c) Protocol bytes frozen: `LITNCOLON: .BYTE $3A,$4E,$3A,$00`
    (unshifted `N` — the fix); `LITCOMMA: .BYTE $2C,$00`.
  - (d) `scripts/gen_format_version.py` created (twin of
    `gen_label_version.py`, `APP_NAME="FORMAT"`); `FORMAT_VERSION` =
    `0.1.0`; `BUILD_FORMAT` trimmed to `1013`. Generated `FORMATVERMSG`:
    `.BYTE $C6,$CF,$D2,$CD,$C1,$D4,$20,$56` (shifted "FORMAT" + space +
    lowercase `v`) then `.BYTE "0.1.0.1013", $0D, $00`.
    `check_casm_source_bytes.py` passes.
  - Note for Increment 2: CASM char literals **cannot take an addend**
    (`'9'+1` is illegal — CASM ref WP69). `parseDeviceDigits`'s
    `cmp #'9'+1` becomes `CMP #$3A`. `cmp #(DEV_MAX+1)` /
    `cmp #(NAME_MAX_LEN+1)` become `CMP #DEV_MAX+1` / `CMP #NAME_MAX_LEN+1`
    (no parens — the form that worked for LABEL's `VOL_NAME_LEN-1`).
- 2026-09-02: **Increment 2 done — plus a finding that de-risks Decision 1.**
  - **Probe: native CASM accepts lowercase inside a string literal.** A
    one-off fixture (`.BYTE "device (8-11): "`, nothing else lowercase)
    assembled clean under native CASM 0.6.2 b1419 and emitted the **raw
    lowercase PETSCII** `64 65 76 69 63 65 …` (verified by extracting the
    PRG). So Decision 1's lowercase messages can be **plain native string
    literals** — no explicit-hex fallback needed. Memory
    `reference-casm-lowercase-in-string-literals`.
  - **`scripts/check_casm_source_bytes.py` relaxed** to allow `$61-$7A`
    inside `"…"` / `'…'` literals (tracks quote + comment state); its
    identifier-collision check now blanks literal *and* comment content
    first (so a message word like "format" is not read as a `FORMAT`
    identifier). LABEL still passes; a lowercase *mnemonic* still fails.
  - `format.s` fully rewritten: ca65 machinery stripped; inline constants
    (the Increment-1 block) + `.INCLUDE "FORMATVER.S"` at the end;
    uppercased outside literals; every routine-internal branch target →
    `@local` (18 routine entry points + `START` / `NEEDINTERACTIVE` /
    `DOCONFIRMANDFORMAT` / `DOEXIT` stay global — the last three because
    they're cross-scope JMP targets after the subroutines); all 18
    messages → native lowercase `.BYTE "…"`; comparison sites → char
    literals or explicit hex (`#$3A` for `'9'+1`, `#DEV_MAX+1` /
    `#NAME_MAX_LEN+1` no-paren addends); `LITNCOLON: .BYTE $3A,$4E,$3A,$00`
    (fixed `N`), `LITCOMMA: .BYTE $2C,$00`; `.res` → `.RES`; `asl a` →
    `ASL A`.
  - `common.inc` + `build_format.inc` deleted; `BUILD_FORMAT` trimmed to
    `1013`. `check_casm_source_bytes.py` passes on `format.s` +
    generated `formatver.s`.
  - ca65 `format` target is now broken (expected; removed in Increment 5).
  - **Not yet done in Increment 2:** live CASM assembly (Increment 3).
- 2026-09-02: **Increment 3 — GREEN, with two Scoping-Decision corrections
  from live evidence.**
  - **CORRECTION to Decision 2 — the shipped ca65 FORMAT is NOT broken.**
    Ran `build/format.prg` (the ca65 build, `$CE` shifted `N`) against a
    scratch device-9 `.d64` under VICE: it reached the confirm gate,
    accepted `Y` + the name re-type, sent the command, and the drive
    returned `RESULT: 00, OK,00,00`. Detached: the scratch disk's BAM name
    changed `ORIGINALNAME` → `NEWVOL`, id `5A` → `42`, directory emptied.
    **The 1541 (VICE's emulation) accepts the shifted `$CE` as the NEW
    command.** So `$CE`→`$4E` in the CASM-native `LITNCOLON` is a
    canonical-byte *cleanup* (explicit reviewed protocol byte), **not a
    bug fix**. Behaviour is unchanged. Plan header comment + Decision 2
    wording updated.
  - **CORRECTION to Decision 1's direction — messages need UPPERCASE-ASCII
    source, not lowercase.** KERNAL CHROUT on the mixed-case charset maps
    PETSCII `$41-$5A` → screen `$01-$1A` (displays LOWERCASE) and `$61-$7A`
    → screen `$41-$5A` (displays UPPERCASE) — case is inverted (same as
    `reference-vice-load-time-and-case`). My first conversion wrote the
    messages as literal lowercase (`.BYTE "format drive"`), which CASM's
    lexer accepted (proven: emits raw `$66 $6F …`) but which then rendered
    **UPPERCASE** on screen — no visible change from the old build.
    Fixed: messages are UPPERCASE-ASCII string literals (`.BYTE "FORMAT
    DRIVE "` …, exactly like LABEL) → CASM emits `$46 $4F …` → render
    **lowercase**. The one-off `check_casm_source_bytes.py` relaxation
    drafted for the lowercase-literal attempt is **reverted** (no app
    needs it); the lexer fact is kept in memory
    `reference-casm-lowercase-in-string-literals`.
  - **Assembly:** native CASM 0.6.2 b1419, `CASM FORMAT.S /O:FMT.PRG` →
    `P1/P2 DONE 00615`, `01865 BYTES`, `CASM: INPUT VALIDATED`. Extracted
    `FMT.PRG` (repackaged as `format` for shell dispatch — verified same
    sha256 `2a5bb431…`, the `/O:` name is just the assembly output name).
  - **Byte comparison:** independent reference = ca65 `-t c64` build,
    linked at `$3400`, of a mechanically-transformed copy of the final
    `format.s` (every `.BYTE "…"` → explicit unshifted hex, `@`-prefixes
    stripped, `.RES`→`.res`, ca65 header segment). Reference
    `format_ref3400.prg` 1541 B, sha256 `8588fc31…`.
    **CASM image (1539 B, `$3400..$3A02`) vs reference: 0 differences.**
    + 324 B R6 table + `52 36` footer.
  - **R6:** `casm_r6_verify.py` PASS — base `$3400`, 159 entries,
    ascending/unique, all in-image (pages `$34..$3A`), relocates cleanly
    to `$3800`/`$5000`/`$9000`.
  - **Functional (CASM-native, dispatched by name):**
    - Banner renders `FORMAT v0.1.0.1013` (uppercase `FORMAT` glyph,
      lowercase `v`).
    - `FORMAT 9:X,4` (id 1 char) → `error: id must be exactly 2 chars.`
      **rendered lowercase**, clean return to `C64[8]:>`.
    - `FORMAT 9:REFORMATTED,AB` → banner, `format drive 9 - all data will
      be lost. continue? (y/n)` (lowercase), `Y`, `re-enter disk name to
      confirm:` → `REFORMATTED` → `formatting...` → `result: 00, ok,00,00`.
      Detached device 9: BAM name `PREFORMAT` → `REFORMATTED`, id `11` →
      `AB`, directory emptied. **End-to-end format works with `$4E`.**
  - **Still open for later in the sweep (Increment 3 tail / Completion
    Gate):** interactive prompt path (no-comma invocation), Y/N abort,
    name-mismatch abort, transport-error path, DEL editing in `readLine` —
    all non-destructive, low-risk given byte-identity to the independent
    reference.
- 2026-09-02: **Increment 4 — derivation + manifest + live COMP: done
  (pending reviewer sign-off).**
  - `scripts/build_format_manifest.py` (twin of `build_label_manifest.py`;
    3 `source_sha256` — `format.s` / `FORMAT_VERSION` / `BUILD_FORMAT`).
  - `src/external/format/format.ref.hex` generated from the reviewed
    `FMT.PRG` (1865 B, sha256 `2a5bb431…`). Round-trips:
    `hex_manifest_to_bin.py --source-dir` → byte-identical to native CASM
    output.
  - `src/external/format/format-derivation.md` — Native-app-manifest +
    R6-PRG classes. Independent reference = ca65 `-t c64` `$3400` build of
    a mechanically-transformed `format.s` (every `.BYTE "…"` → explicit
    unshifted hex; `@` stripped; `.RES`→`.res`), `format_ref3400.prg`
    1541 B sha256 `8588fc31…`. **Byte comparison: 0 differences** across
    all 1539 image bytes; the three design changes (message case, `:N:`
    byte, banner) are enumerated and pre-applied to the reference. R6
    ledger reconciled: 131 absolute operands + 28 `#>` high-byte
    immediates = **159, exactly CASM's count**; 0 for fixed addrs / `#<`
    low bytes. `casm_r6_verify.py` PASS `$3800`/`$5000`/`$9000`.
  - **Live `COMP FMT.PRG FORMAT.REF` on the C64 → `FILES COMPARE OK`**
    (native CASM 0.6.2 b1419). Overlay `test`/`pass` event fired.
  - **Open:** reviewer sign-off on `format-derivation.md`; audit-register
    row + `casm_oracle_inventory.py` `NATIVE_MANIFESTS` (Increment 5).
- 2026-09-02: **Increments 5 + 6 + 7 done.**
  - **Increment 5 (CMake):** removed `add_ca65_app(format …)` + fatal
    branch + `FORMAT_SRCS`/`FORMAT_ENTRY` globs; `find_package(Ca65)`
    comment updated. Added the manifest-derived `format` target
    (`C64_PRG_PATH` set, `set(FORMAT_TARGET format)` — `IMAGE_BASE_PRG_TARGETS`
    unchanged), `format_version_src` (runs `gen_format_version.py` →
    `${CMAKE_BINARY_DIR}/formatver.s`), and `command64_format_test_d64`
    (command64 + casm + comp; PRE_BUILD `check_casm_source_bytes.py`;
    POST_BUILD packs `format.s` + `formatver.s` SEQ + `format.ref` PRG).
    `format.ref.hex` added to `casm_oracle_inventory.py` `NATIVE_MANIFESTS`.
    `formatver.s` build product, not checked in; `common.inc`/
    `build_format.inc` deleted; `BUILD_FORMAT` trimmed to `1013`.
  - **Increment 6 (verify):** fresh `rm -rf build && cmake -B build` +
    full `cmake --build build` — **no warnings/errors**. `build/format.prg`
    sha256 `2a5bb431…` == manifest. `image.d64` carries `FORMAT` (pos 4);
    `test_image_d64` builds. No-change rebuild: `format.prg` / `image.d64`
    / test disk byte-identical. Stale-source gate fires on a `format.s`
    edit; reverting → clean. `casm_oracle_inventory` `reconciliation: OK`,
    5 native manifests, 72/72. No ca65/`.inc` reference to FORMAT anywhere.
  - **Increment 7 (docs):** `wiki/format-utility.md` created (+ `SYNC_FILES`
    entry, synced to `docs/`); `wiki/tasks/format.md` end-to-end box
    checked + Status section; `CHANGELOG.md` Added entry; `brain/KNOWLEDGE.md`
    "FORMAT → CASM-native" section; audit-register row (pending reviewer
    sign-off); `brain/task.md` FORMAT checklist; walkthrough
    `brain/walkthroughs/2026-09-02-format-casm-native-migration.md`.
  - **Increment 3 functional sweep completed** (interactive prompt,
    reprompt-on-invalid, Y/N abort, name-mismatch abort with the target
    disk verified untouched) — see the walkthrough.
- 2026-09-02: **All seven increments implemented. Handing to the user for
  the Completion Gate:** (1) reviewer sign-off on `format-derivation.md`,
  (2) approval to close the FORMAT Taskwarrior task. No self-declared
  completion.
