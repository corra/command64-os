---
feature: casm-dash-include-adoption
created: 2026-07-30
status: draft
---

# Plan: DASH Adoption of New CASM Features

## Objective

Update DASH's native-assembly workflow to use every CASM capability added
since DASH's source-subset rules were frozen, so DASH stops working around
limitations CASM no longer has.

## Research Finding: There Is Exactly One Adoptable Feature

A full inventory of CASM's current feature set (v0.1.50, build 1204, Phase 9
complete, Phase 10 inactive except non-runtime WP50) against DASH's
`AGENTS.md` restriction list found only one restriction that CASM has since
lifted:

| DASH restriction | Still true? | Notes |
| --- | --- | --- |
| No segment directives | Yes | Unchanged; CASM has no segment concept. |
| No string literals | Yes, except `.INCLUDE` | `"` is valid **only** as a `.INCLUDE "FILENAME.S"` operand (1-63 printable bytes). No general string token exists. |
| No equates | Yes | Directive set is frozen at exactly six: `.ORG .BYTE .WORD .INCLUDE .STATIC .RELOC`. No `.EQU`/`=`/`.SET`. Nothing in any approved plan adds one. |
| `asl` must be `asl a` | Yes | Accumulator addressing is a distinct grammar production; no bare-mnemonic fallback. |
| Bounded expressions only | Yes | Grammar is still exactly `['<'|'>'] (NUMBER\|IDENTIFIER) [('+'|'-') NUMBER]`. No parens-as-grouping, no `*`/`/`. `(zp),Y` / `(zp,X)` / `(abs)` remain fixed addressing-mode punctuation, not general grouping — `LDA (BASE+OFFSET),Y` is still illegal. |
| Multi-file CLI (1-8 files) | Already in use | This is what DASH's current 7-file command line already exploits (Phase 7, WP34). No change. |
| **`.INCLUDE` unusable** | **No — now operational** | Landed at WP47 (`0.1.49`), hardened at WP48 (`0.1.50`). Proven in nested/forward-reference/diamond-dedup fixtures (`casmip1-4.seq` families). Bounds: 16 nesting levels, 32-file catalog, 128 include events, same 65,535-byte combined-source cap as today. |

No macro facility, no local/scoped labels, and no `/M`/`/L` map/listing output
exist either, and none are in-flight (Phase 10 only touches listing output,
not source-language surface area). So "leverage them all" reduces to one
concrete question: **should DASH adopt `.INCLUDE`, and how?**

## Why This Isn't a Free Win: The Case-Sensitivity Conflict

DASH's dual-assembler contract requires the *same bytes on disk* to feed both
native CASM (via `command64_casm_utils.d64`, PETSCII, case set by `cc1541 -f`)
and the ca65 cross-check (via `dash_wrapper.s`, reading the literal lowercase
host filenames `dscr.s`, `dfmt.s`, etc. from `src/external/dash/`).

If `dmain.s` grows its own `.INCLUDE "DSCR.S"` chain to pull in the other six
files, **both** toolchains read that line, because both toolchains read
`dmain.s`'s actual bytes:

- **Native CASM**: needs the uppercase spelling. `.INCLUDE "DSCR.S"` (raw
  uppercase ASCII = unshifted-PETSCII letter codes) resolves via
  `includeCatalogLookup` against the disk's directory entry, exactly the
  same byte-matching mechanism already proven by today's
  `CASM DMAIN.S DSCR.S ...` command line — that's the same keystroke bytes,
  same lookup. No new risk here.
- **ca65 cross-check**: resolves `.include` operands as literal filesystem
  paths on a case-sensitive Linux filesystem, against the real (lowercase)
  file `src/external/dash/dscr.s`. `"DSCR.S"` does not match `dscr.s` and the
  `dash_ref` build fails.

One file, one byte sequence, two incompatible case requirements. This is why
DASH cannot simply add `.INCLUDE` lines to `dmain.s` today.

## Is This Actually Worth Solving Right Now?

The original motivation for keeping the source list on one command line
("prefixes cost 2 bytes per source token against the shell's 80-byte
`CommandBuffer`") is **not currently a blocker** — the existing 7-file line is
67 bytes, 13 bytes under the limit. So `.INCLUDE` adoption is not fixing a
live failure; it is:

1. Removing a manually-maintained invariant (`AGENTS.md`: "the CASM command
   line's order and `dash_wrapper.s`'s `.include` order must match exactly,
   or ... the comparison is meaningless") — today that order is duplicated in
   two places (the documented CLI command and `dash_wrapper.s`) and kept in
   sync by hand. `[[project-casm-wp46-cancelling-bugs-false-pass]]`-style
   risk: nothing stops the two from silently drifting.
2. Dogfooding a completed CASM feature (Phase 9) on a real consumer, which is
   the kind of proof `dash.ref.hex`'s non-circular cross-check exists for.
3. Freeing future `CommandBuffer` headroom for WP6-8 page content growth.

None of these is urgent. Given that, this plan offers two options rather than
mandating the larger one.

## Option A (Recommended): Full Retrofit With a ca65 Include Shim

Make `dmain.s` the single entry point for **both** toolchains, eliminating
the duplicated order list entirely.

1. Append to `dmain.s` (after its existing code, before nothing needs to
   follow since `ddata.s` must stay last):
   ```text
   .INCLUDE "DSCR.S"
   .INCLUDE "DFMT.S"
   .INCLUDE "DSYS.S"
   .INCLUDE "DAPP.S"
   .INCLUDE "DVMM.S"
   .INCLUDE "DDATA.S"
   ```
   Six sibling includes, depth 1, 7 files total — far inside the 16-level/
   32-file/128-event bounds.
2. Collapse `dash_wrapper.s` to a single include:
   ```text
   .include "dmain.s"
   ```
   removing the other six explicit `.include` lines. Order is now governed
   in exactly one place, read by both toolchains.
3. Add a small ca65-only resolution shim so `"DSCR.S"` resolves on a
   case-sensitive host filesystem: a new CMake step generates uppercase
   symlinks (`DSCR.S -> dscr.s`, etc.) into a build-tree directory (e.g.
   `${CMAKE_BINARY_DIR}/dash_ref_includes/`) and appends that directory to
   the `dash_ref` target's ca65 `-I` search path (via a new optional
   `EXTRA_INCLUDE_DIRS` argument to `add_ca65_app`, or a target-specific
   `-I` appended after the call — whichever is less invasive to the shared
   macro). This is ca65-only tooling; it changes nothing about the reviewed
   PETSCII source, the manifest, or the packaged disk image.
4. Update the native workflow section of DASH's `AGENTS.md` to document the
   new one-file invocation:
   ```text
   DRIVE 9
   CASM DMAIN.S /O:DASH.PRG
   COMP DASH.PRG DASH.REF
   ```
5. Regenerate `dash.ref.hex` via `scripts/build_dash_manifest.py` (the
   documented deliberate, reviewed act) once the new structure is verified,
   since the CASM invocation that produces it has changed even though no
   DASH behavior has.

**Risk**: touches build plumbing (`dash_wrapper.s`, `CMakeLists.txt`,
`cmake/Ca65.cmake`) and the reviewed manifest's provenance chain. Fully
reversible; no runtime/ABI change to DASH itself.

## Option B (Lower-Risk Fallback): Adopt `.INCLUDE` Only Going Forward

Leave the seven existing files and the current multi-file CLI/`dash_wrapper.s`
exactly as they are — zero risk to what's already shipped and reviewed. Scope
`.INCLUDE` to *new* content only: if WP6-8 introduce substantial new
page-specific source material that doesn't fit cleanly as more top-level CLI
files (approaching the 8-file CLI cap or the `CommandBuffer` limit), pull it
in via `.INCLUDE` from within the file that needs it, evaluating the same
case-sensitivity shim at that point, scoped narrowly to the new file(s).

This defers the case-sensitivity shim work indefinitely and may never need
it if WP6-8 don't hit the CLI's 8-file cap.

## Recommendation

Option A. The case conflict has a small, bounded, ca65-only fix; the payoff
(single source of truth for build order, proven Phase 9 dogfooding, headroom
for WP6-8) is worth the one-time plumbing change, and nothing about DASH's
own ABI, ZP usage, or runtime behavior changes. Option B is the fallback if
the user wants zero build-system churn right now.

## Atomic Increments (Option A)

1. Prototype the ca65 include shim in isolation (a throwaway two-file test
   under a scratch directory) to confirm ca65's `-I` resolves an uppercase
   symlink to a lowercase target on this filesystem before touching DASH.
2. Add the shim mechanism to `cmake/Ca65.cmake` / `CMakeLists.txt`, scoped to
   the `dash_ref` target only.
3. Rewrite `dmain.s` to append the six `.INCLUDE` lines; collapse
   `dash_wrapper.s` to the single `.include "dmain.s"`.
4. Build `dash_ref` (ca65 path) and confirm identical relocation-point count
   and code-byte count to the current 90-point/1151-byte baseline (no
   behavior change expected — only the file-loading mechanism changed).
5. Update `AGENTS.md`'s Native Assembly Workflow section.
6. User runs the new single-file `CASM DMAIN.S /O:DASH.PRG` on real/VICE
   hardware, confirms `COMP DASH.PRG DASH.REF` still matches byte-for-byte.
7. Regenerate `dash.ref.hex` via the deliberate manifest script; user reviews
   the diff (should be none, since output bytes are unchanged) before it's
   accepted.

## Verification

- `dash_ref` ca65 build byte count and relocation-point count match the
  pre-change baseline exactly (1151 code bytes, 90 relocation points) —
  `.INCLUDE` restructuring must not change emitted bytes, only how source is
  assembled.
- Native CASM `COMP DASH.PRG DASH.REF` still matches byte-for-byte at
  `$3400`.
- `.INCLUDE` nesting stays at depth 1 with 7 total files — nowhere near the
  16-level/32-file/128-event bounds, so no new failure mode is introduced.
- `scripts/check_casm_source_bytes.py`'s uppercase-ASCII gate still passes on
  the modified `dmain.s` (the six new `.INCLUDE "X.S"` lines are already
  uppercase ASCII).

## Stop Conditions

- ca65's `-I` search does not resolve a case-differing symlink on the build
  host (would force Option B, or an alternate shim such as copying instead of
  symlinking).
- `dash_ref` byte count or relocation-point count changes after the
  restructuring (would indicate the include mechanism altered emitted code,
  not just source loading — investigate before proceeding).
- Any `.INCLUDE`-related diagnostic appears when native CASM is run
  interactively that the fixture suite didn't already cover.

## Completion Gate

Present the shim mechanism, the before/after `AGENTS.md` workflow, the
byte-count/relocation-count equivalence proof, and the user's own
`COMP DASH.PRG DASH.REF` result on real/VICE hardware. Ask whether to accept
the regenerated `dash.ref.hex` manifest before closing this plan.
