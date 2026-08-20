---
feature: banner-casm-native-migration
created: 2026-08-20
status: proposed
taskwarrior: TBD (created on approval)
depends-on: CASM Phase 12 (WP65-WP75), complete
---

# Plan: BANNER — Full Migration to Native CASM (Phase 12 Adoption + ca65 Retirement)

## Status

**Proposed, not yet approved.** Drafted 2026-08-20 for user review, per
this project's per-work-package-plan-approval requirement
(`.agents/workflows/phased-implementation-planning.md`). No implementation
is authorized until this plan is approved.

Not a numbered CASM Phase/WP itself — this is a downstream application of
CASM Phase 12's already-shipped, already-closed language surface
(`brain/plans/2026-08-19-casm-phase12-wp75-verification-walkthrough-completion-gate.md`)
to an external app. Treated under the same planning discipline because of
its size (source refactor + a full build-provenance model swap).

## Objective

Two things, done together because the second is what makes the first
safe:

1. **Refactor `banner.s`'s source** to use CASM Phase 12 syntax
   throughout: named constants (WP65) for the zero-page workspace and
   OS/KERNAL entry points, string literals (WP74) for `USAGE_STR`, and
   character literals (WP69) for the punctuation/flag comparisons in
   `GET_GLYPH_INDEX` and `PARSE_ARGS`.
2. **Retire `banner`'s ca65 build path entirely.** BANNER becomes a
   CASM-native application: assembled only by the real native CASM
   assembler (never by ca65), following DASH's manifest-provenance model
   (`src/external/dash/dash.ref.hex` / `scripts/hex_manifest_to_bin.py`)
   but *without* DASH's ca65 cross-check step, since ca65 parity is no
   longer a goal at all.

**Does NOT deliver:** any change to BANNER's rendering behavior, output
format, command syntax, or supported glyph set. This is a source-form and
build-provenance migration only — the rendered banner output must be
provably unchanged (see Completion Gate).

## Scoping Decisions (user-confirmed 2026-08-20)

1. **No ca65 parity constraint.** Unlike DASH, BANNER does not need to
   stay within a "dual-assembler safe subset." Character literals and
   string literals may be used freely per their native CASM semantics
   (WP69/WP74), including for uppercase letters, without checking ca65's
   `-t c64` charmap divergence — because after this plan, ca65 no longer
   builds BANNER at all.
2. **Compiled `banner.prg` still ships**, on `command64_casm_utils.d64`,
   produced via a DASH-style reviewed hex manifest: a live native-CASM
   run's output is captured, reviewed, and transcribed to
   `src/external/banner/banner.ref.hex`, which `hex_manifest_to_bin.py`
   turns into the shipped PRG at build time. Never a live CASM invocation
   as part of `cmake --build`, and never ca65 output — matching DASH's own
   "regenerating the manifest is a deliberate, reviewed act" rule
   (`scripts/build_dash_manifest.py`'s header comment).
3. **ca65 removal happens in this same plan**, not a separate follow-up —
   the syntax choices in Objective #1 are only unconditionally safe once
   Scoping Decision #1 holds, so splitting these into two plans would
   leave an intermediate state where the source uses syntax that is
   already unsafe for the ca65 build still wired up to compile it.

## Scope

**Included:**
- `src/external/banner/banner.s`: named-constant, string-literal, and
  character-literal adoption (Objective #1).
- Deleting `src/external/banner/header.s` (ca65 PRG-header stub, no
  longer needed once ca65 doesn't build BANNER).
- `CMakeLists.txt`: remove `add_ca65_app(banner ...)` and its
  `Ca65_FOUND` fatal-error gate (lines ~360-366), remove `BANNER_SRCS`/
  `BANNER_TARGET` ca65 wiring, add a manifest-derived `banner` target
  mirroring `dash`'s (lines ~1304-1348), update
  `command64_casm_utils_d64`'s `PRGS` list (line ~1683) to depend on the
  new target.
- New `scripts/build_banner_manifest.py` (single-source twin of
  `scripts/build_dash_manifest.py`, no `--cross-check`/
  `--allow-host-bytes` machinery since no ca65 build exists to
  cross-check against or accidentally source from).
- New `src/external/banner/banner.ref.hex` (the reviewed manifest).
- `src/external/banner/BUILD_BANNER`: reduced to DASH's plain
  single-line counter format (`BUILD_DASH`'s form) — the current
  two-line form (counter + hash) is a ca65 `add_ca65_app` artifact that
  no longer applies once that helper is removed.
- `wiki/banner-utility.md` (synced to `docs/`/`release/docs/` by the
  existing `sync_docs` target): add an "Artifact Provenance" section
  mirroring `dash-utility.md`'s, describing the manifest model and
  explicitly stating ca65 is no longer part of BANNER's build.
- `CHANGELOG.md`, `brain/KNOWLEDGE.md`, memory: record the migration.

**Excluded:**
- Any change to `image.d64`'s existing source-only distribution of
  `banner.s` (already correct — see Technical Notes below).
- Any change to BANNER's rendered output, glyph table, command syntax, or
  buffer sizes.
- Generalizing `build_dash_manifest.py` into a shared multi-app script —
  out of scope; a banner-specific twin is smaller and lower-risk (see
  Technical Notes).
- Retroactively applying this same ca65-retirement pattern to CONWAY or
  any other ca65 app — not requested, not evaluated here.

## Technical Notes

### Why ca65 parity mattered before, and why dropping it is safe

`banner.s` currently ships two ways: as raw `.s` source on `image.d64`
(meant to be assembled live by the end user via native CASM — see the
existing `image_d64` `POST_BUILD` comment, "assembling it with CASM is
meant to be part of the end-user experience, not a pre-built command")
and as a ca65-compiled PRG on `command64_casm_utils.d64` (the dev-utility
disk). Because both forms existed, the source had to assemble
*identically* under both toolchains — the same constraint documented in
`src/external/dash/AGENTS.md`'s "Dual-Assembler Subset" section, which
exists because `cmake/Ca65.cmake` invokes ca65 with `-t c64` (PETSCII
target charmap translation), which remaps letters to different byte
values than native CASM's raw keyboard bytes (`'T'` → ca65 `$D4`, native
CASM `$54`). This is exactly why `banner.s` currently hand-writes every
`USAGE_STR`/font-table byte as an explicit hex value instead of using any
higher-level literal syntax — under the current dual-build setup, that
caution is still correct.

Once Scoping Decision #1/#3 land — ca65 never builds BANNER again — that
constraint disappears entirely for this file. There is no second
toolchain's output to diverge from. String and character literals become
exactly as safe here as they are in any pure-native-CASM CASM test
fixture.

### `image.d64`'s existing distribution is already correct

`image.d64` already ships `banner.s` as a `SEQ` file appended directly by
name (`CMakeLists.txt` ~line 1648), not through the `PRGS` compiled-target
list — it was never routed through ca65 for that disk. This plan changes
nothing about that `add_custom_command`; only `command64_casm_utils.d64`'s
compiled-PRG packaging (currently ca65-sourced) changes.

### Manifest tooling: banner-specific twin, not a generalized script

`scripts/build_dash_manifest.py` is DASH-specific (hardcoded
`DASH_SOURCE_NAMES`, default paths, and the `--cross-check`/
`--allow-host-bytes` ca65-guard machinery that has no BANNER equivalent).
`scripts/hex_manifest_to_bin.py`, by contrast, is already generic — its
own docstring calls it a converter "for CASM trusted reference fixtures,"
not DASH-specific — and needs no changes; the new `banner` CMake target
calls it exactly the way the `dash` target does, pointed at
`banner.ref.hex` and `src/external/banner/`.

`scripts/build_banner_manifest.py` will be a smaller twin of
`build_dash_manifest.py`: takes a reviewed `banner.prg` (extracted from a
live native-CASM run) and a `--provenance` string, computes and writes
`# bytes:`, `# sha256:`, and a single `# source_sha256: banner.s=<hash>`
line (WP9-style stale-artifact protection, scaled down from DASH's seven
files to BANNER's one) into `banner.ref.hex`. No `--cross-check` flag, no
`--allow-host-bytes` flag, no `CA65_REFERENCE` path — those exist in the
DASH script solely to guard against ca65 output being mistaken for
native-CASM output, which cannot happen here because there is no ca65
build of BANNER to confuse it with.

### Zero-page and OS/KERNAL named constants

Every raw address currently carrying a hand-written comment becomes a
named constant, applying WP65 (and relying on WP72's zero-page-width fix
so these assemble identically to the literals they replace):

| Constant | Value | Currently at |
| --- | --- | --- |
| `PARSEPOS` | `$63` | `banner.s:30` |
| `BANNERLINELEN` | `$72` | `banner.s:130` |
| `BANNERROWIDX` | `$73` | `banner.s:134` |
| `BANNERCHARIDX` | `$74` | `banner.s:138` |
| `BANNERGLYPHPRLO` | `$75` | `banner.s:170` |
| `BANNERGLYPHPRHI` | `$76` | `banner.s:156` |
| `TEMPLO` | `$64` | `banner.s:160` |
| `TEMPHI` | `$65` | `banner.s:162` |
| `BANNERTOTALLEN` | `$78` | `banner.s:73` |
| `BANNERSTRIDX` | `$79` | `banner.s:98` |
| `PRINTPTRLO` | `$FB` | `banner.s:376` |
| `PRINTPTRHI` | `$FC` | `banner.s:377` |
| `OS_API` | `$1000` | `banner.s:23` |
| `DOS_EXIT` | `$4C` | `banner.s:22` |
| `KERNALCHROUT` | `$FFD2` | 8 call sites |
| `COMMANDBUFFER` | `$033C` | 5 call sites |

Per `src/external/AGENTS.md`, `$70-$8F` is the shared app-private
zero-page scratch range; `$63`/`$64`/`$65`/`$FB`/`$FC` fall outside it
(pre-existing, unchanged by this plan — named constants document the
existing allocation, they don't move it).

### String and character literals

- `USAGE_STR` (`banner.s:393-397`) becomes two `.BYTE "..."` lines per
  WP74, matching DASH's own precedent (`.BYTE "0.1.4"`), now safe for the
  full alphabetic content per Scoping Decision #1.
- `GET_GLYPH_INDEX`'s 15 punctuation comparisons (`banner.s:288-361`)
  convert `CMP #$21 ; '!'`-style pairs to `CMP #'!'`, removing the
  hand-decoded comment entirely.
- `PARSE_ARGS`'s flag/help detection (`'/'`, `'-'`, `'?'`, `'H'`,
  `banner.s:44-56`) and every `SPACE`/`CR` comparison convert the same
  way: `CMP #' '`, `CMP #$0D` stays numeric (not printable) but gains a
  `PETCR` named constant instead.
- Case-range *exclusive* bounds (`$7B` = one past `'z'`, `$5B` = one past
  `'Z'`, `$3A` = one past `'9'`) stay as explicit hex — WP69 character
  literals cannot take an addend (`'z'+1` is not legal), so these
  boundary checks are not candidates for conversion; a comment noting the
  bound they represent is the right level of clarity here.

### What Phase 12 features do NOT apply here

Documented so this isn't silently dropped without explanation during
review:
- **WP68 arithmetic operators** (`*`, `/`, `<<`, `>>`, etc.): CASM's own
  compile-time expression operators, not new 6502 runtime instructions.
  The glyph-pointer multiply (`INDEX*6` via shift/add,
  `banner.s:152-173`) multiplies a *runtime* register value and is
  unrelated to this feature — left untouched.
- **WP66 `*` current-address symbol**: no safe application. Sizing
  `MESSAGE_BUF` via `* - MESSAGE_BUF` would combine two relocatable
  values, which WP64's frozen representability rule rejects
  (`CASM_DIAG_EXPR_RELOC_UNSUPPORTED`).
- **WP67 parenthesized expressions**: no multi-operator arithmetic exists
  in the source to group — no candidate sites.

## Atomic Increments

1. **Source refactor — constants pass.** Add the named-constant block
   (table above) to the top of `banner.s`; replace every raw-address
   reference with its named constant. No behavioral change; verify by
   diffing the assembled PRG (see Increment 3) against a pre-refactor
   baseline assembly.
2. **Source refactor — literals pass.** Convert `USAGE_STR` to `.BYTE
   "..."` form and the punctuation/flag/space comparisons to character
   literals, per the Technical Notes tables above. Same no-behavior-change
   expectation.
3. **Live-VICE verification of the refactored source.** Assemble
   `banner.s` (post Increments 1-2) with the real native `casm.prg` under
   VICE, per `.agents/workflows/vice-mcp-testing.md`. Confirm a clean
   assembly, extract the resulting `banner.prg`, and diff it byte-for-byte
   against a `banner.prg` assembled from the pre-refactor source the same
   way — they must be identical. Functionally exercise the rendered
   output (a short message, a wrapped multi-line message, punctuation
   glyphs, `/?`  usage help) and visually confirm no rendering regression.
4. **Capture the reviewed manifest.** Write
   `scripts/build_banner_manifest.py`. Run it against the Increment 3 PRG
   with an explicit `--provenance` string, producing
   `src/external/banner/banner.ref.hex`.
5. **Retire the ca65 build path.** Delete `src/external/banner/header.s`;
   remove `add_ca65_app(banner ...)`, its `Ca65_FOUND` fatal-error branch,
   and the `BANNER_SRCS`/`BANNER_ENTRY`/`BANNER_TARGET` ca65 wiring from
   `CMakeLists.txt`; add the manifest-derived `banner` target (mirroring
   `dash`'s `add_custom_command`/`add_custom_target` pair); point
   `command64_casm_utils_d64`'s `PRGS` list at the new target. Reduce
   `BUILD_BANNER` to the plain single-line counter form.
6. **Full rebuild verification.** Clean `cmake -B build` +
   `cmake --build build --target image_d64 command64_casm_utils_d64`;
   confirm both disks build, `image.d64` still carries `banner.s` as
   source unchanged, `command64_casm_utils.d64` carries the
   manifest-derived `banner.prg`, and no `add_ca65_app`/`BANNER_TARGET`/
   ca65 reference to BANNER remains anywhere in `CMakeLists.txt`. A
   no-change rebuild must not alter either artifact.
7. **Documentation and tracker sync.** Update `wiki/banner-utility.md`
   (Artifact Provenance section), `CHANGELOG.md`, `brain/KNOWLEDGE.md`,
   Taskwarrior, and memory.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/banner/banner.s` | Modify (Increments 1-2) |
| `src/external/banner/header.s` | Delete (Increment 5) |
| `src/external/banner/BUILD_BANNER` | Modify (Increment 5) |
| `src/external/banner/banner.ref.hex` | Create (Increment 4) |
| `scripts/build_banner_manifest.py` | Create (Increment 4) |
| `CMakeLists.txt` | Modify (Increment 5) |
| `wiki/banner-utility.md` | Modify (Increment 7) |
| `docs/banner-utility.md`, `release/docs/banner-utility.md` | Regenerated by `sync_docs` (Increment 7) |
| `CHANGELOG.md` | Modify (Increment 7) |
| `brain/KNOWLEDGE.md` | Modify (Increment 7) |

## Stop Conditions

- Increment 3's byte-for-byte diff between pre- and post-refactor
  assemblies is non-empty — halt, the refactor changed behavior, do not
  proceed to manifest capture.
- Any live-VICE assembly reports a CASM diagnostic instead of success.
- Increment 6's no-change rebuild alters `banner.prg` or `banner.ref.hex`.
- `command64_casm_utils_d64` or `image_d64` fails to build after
  Increment 5's CMake changes.
- Any approved directory-entry/byte-space ceiling on an affected disk
  image is exceeded.
- A genuinely new defect (in CASM itself, in the manifest tooling, or in
  BANNER's own logic) is discovered outside this plan's scope: disclose
  and defer as a separate follow-up, per this project's default — do not
  fix inline without explicit direction.

## Documentation, Task, and DOX Updates

- **At approval:** create the Taskwarrior task for this plan.
- **At completion:** `wiki/banner-utility.md` (provenance section),
  `CHANGELOG.md` (ca65 retirement + Phase 12 adoption entry),
  `brain/KNOWLEDGE.md` (closing note), Taskwarrior marked done, and a new
  memory recording that BANNER is now CASM-native (no ca65), following
  the same shape as the existing DASH-provenance memories.

## Completion Gate

- Live VICE evidence: a real native-CASM assembly of the final
  `banner.s`, screenshots/register evidence per
  `.agents/workflows/vice-mcp-testing.md`, and the functional
  render-output check from Increment 3.
- Byte-identity evidence: pre-/post-refactor PRG diff (Increment 3) and
  no-change-rebuild diff (Increment 6), both empty.
- `command64_casm_utils_d64` and `image_d64` both build clean from a
  fresh `cmake -B build`.
- No remaining reference to ca65/`add_ca65_app`/`header.s` for BANNER
  anywhere in the tree.
- A `brain/walkthroughs/2026-08-20-banner-casm-native-migration.md`
  recording all of the above with live evidence, not just intentions.
- Trackers synchronized (see above).
- Explicit user approval of the walkthrough — this plan does not
  self-declare completion.

## Progress

- 2026-08-20: Plan drafted, pending approval. Scoping Decisions 1-3
  confirmed by user via AskUserQuestion in the same session.
- 2026-08-20: **Known open defect noted for safety review — does not
  block this plan's current design.** WP75 Increment 5 (live-VICE fixture
  sweep, same day) found a reproducible CASM regression: `casmarithfwd.s`
  (`LDA FWDCONST*2` / `FWDCONST = 5` — a forward-referenced named constant
  combined with a WP68 arithmetic operator, resolving to a zero-page-
  eligible value) fails with `CASM: PASS 1/2 MISMATCH` instead of its
  documented `CASM: INPUT VALIDATED`. Logged as Taskwarrior task 45; WP75
  is paused pending root-cause (not yet fixed). This plan's frontmatter
  lists `depends-on: CASM Phase 12 (WP65-WP75), complete` — **that
  dependency is not actually satisfied yet**, since WP75 itself is
  paused on task 45.
  Cross-checked against this plan's own design: the Technical Notes
  section ("What Phase 12 features do NOT apply here") already excludes
  WP68 arithmetic operators entirely — BANNER's named-constant table
  (Zero-page and OS/KERNAL named constants) uses plain constants only,
  never a constant combined with an arithmetic operator, so task 45's
  specific failure shape (forward-reference *combined with* an
  arithmetic operator) has no matching site in this plan's current scope.
  **Before this plan's Increment 3 (live-VICE verification) runs**,
  re-confirm task 45 is still isolated to the arithmetic-operator
  combination and hasn't widened — a quick live assembly of the
  constants-only refactor is enough; do not assume this note stays
  accurate if task 45's root cause turns out to be broader than currently
  characterized (e.g. if it turns out to affect any forward-referenced
  named constant, not just ones combined with an operator).
