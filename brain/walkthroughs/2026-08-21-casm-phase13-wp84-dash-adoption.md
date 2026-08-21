# CASM Phase 13 WP84 DASH Adoption of .RES Completion Gate

## Status

**Approved by the user on 2026-08-21.** WP84 is complete.

## Result

DASH's real source (`src/external/dash/ddata.s`) now uses CASM's Phase 13
`.RES count[, value]` in place of five long hand-written zero/fill-byte
`.BYTE` lists. Both narrowings from the master plan's original framing
were confirmed with the user before implementation:

1. **`.ASSERT` DASH adoption deferred entirely** — the master plan's own
   targets (`DISPATCHRETURN`/`DISPATCHRETURNMINUSONE`'s offset-by-one
   invariant, buffer-size checks) are all equality invariants that WP83
   already found CASM's comparison-operator-free expression grammar
   cannot express with `.ASSERT`'s nonzero-only truthiness. Left for a
   future CASM work package that adds a real comparison operator.
2. **`.FILL` DASH adoption narrowed to `.RES`** — independently verified
   that ca65 has **no `.FILL` directive at all** (`'.FILL' is not a
   recognized control command`), which would have broken the dual-
   assembler cross-check `AGENTS.md` requires. `BORDERROW`'s nonzero fill
   run uses `.RES 38, $40` instead — verified byte-identical to `.FILL`'s
   would-be output on both assemblers via a standalone `ca65`+`ld65` test
   before touching DASH's real source.

Runtime bytes are unchanged: the regenerated `dash.ref.hex` is byte-for-
byte identical to the pre-conversion manifest (same 4,766 bytes, same
SHA-256), confirmed independently three ways (live `COMP`, host-side
`cc1541 -X` extraction + SHA-256, and `build_dash_manifest.py`'s own
`--cross-check`).

## Implementation

- `src/external/dash/ddata.s`: five sites converted --
  - `FMTBUF` (5 zero bytes) → `.RES 5`
  - `SYSINFOBUF` (24 zero bytes) → `.RES 24`
  - `APPBUF` (24 zero bytes) → `.RES 24`
  - `BORDERROW` (corner + 38x`$40` + corner) → `.BYTE $5B` / `.RES 38, $40`
    / `.BYTE $5B`
  - `VMMBUFFER` (256 zero bytes) → `.RES 256`
  Only `VMMBUFFER`'s comment actually explained the "CASM has no reserve
  directive" workaround (trimmed); `FMTBUF`/`SYSINFOBUF`/`APPBUF`'s
  comments are purely descriptive and were left untouched — a correction
  to the plan's own initial assumption that all four needed a comment
  edit.
- `src/external/dash/AGENTS.md`: new bullet in the "Dual-Assembler
  Subset" list documenting `.RES count[, value]` as shared with ca65's
  own `.res` (verified to emit literal fill bytes, not just reserve BSS
  space), and explicitly warning `.FILL` has no ca65 equivalent at all.
- `src/external/dash/dash.ref.hex`: regenerated via
  `build_dash_manifest.py --cross-check build/dash_ref.prg` from a real
  native-CASM-on-hardware run. Same bytes, same hash; fresh
  `source_sha256` entries (only `ddata.s`'s own hash changed, as
  expected) and updated provenance text recording this WP.

### Verification performed

1. **ca65 cross-check build** (`dash_ref` target): builds clean against
   the edited source, confirming the dual-assembler subset claim before
   any hardware/VICE time was spent.
2. **Native CASM assembly + COMP**: `command64_casm_utils.d64` attached
   at unit 9 (`DRIVE 9` to switch `CurrentDevice`), `CASM DMAIN.S
   /O:DASH.PRG` under VICE 3.10 with the default-attached 16MB REU.
   `COMP DASH.PRG DASH.REF` → `FILES COMPARE OK`.
3. **Independent host-side confirmation**: `dash.prg` extracted directly
   from the host `.d64` file via `cc1541 -X` (no second live-VICE round
   trip needed) — SHA-256 `3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578
   362f311b79757b814b`, exactly matching the pre-conversion
   `dash.ref.hex`'s own recorded hash.
4. **Manifest regeneration**: `build_dash_manifest.py --cross-check`
   confirmed the same 4,766 bytes/hash and wrote fresh `source_sha256`
   entries.
5. **Relocation spot-check**: fresh Command64 boot, `image.d64` at unit
   8. Default dispatch (`$3800`) rendered the System page correctly.
   `LOAD DASH 5000`/`RUN 5000` rendered correctly; Applications page
   (F3, sent as the real PETSCII/GETIN byte `$86` `dmain.s` checks for)
   reported `dash 5000-5ef3`. `LOAD DASH 9000`/`RUN 9000` rendered
   correctly; Applications page reported `dash 9000-9ef3` — both exactly
   matching WP71's own recorded results at these addresses.
6. **Regression**: full clean rebuild from scratch (`rm -rf build &&
   cmake -B build && cmake --build build`) completed with zero errors,
   zero overflows, zero unresolved externals. `test_casm_expr`/
   `test_casm_pass1`/`test_casm_frame` all re-run live in VICE against
   the fresh binaries, all PASS -- confirming this WP's DASH-only changes
   left CASM's own regression suite untouched.

### Notes from the session

- VICE crashed twice, unprompted, mid-session (once during the
  regression pass between witnesses). Each time a fresh instance was
  started per the workflow's one-clean-restart allowance; the remaining
  work was re-verified from a fresh Command64 boot with identical
  results both times.
- The Command64 shell does not clear the screen when an application
  quits back to it -- `DASH`'s own last-drawn screen content remains
  visible underneath the shell prompt until the next full redraw. This
  produced a visually confusing (but functionally correct) screen during
  the `$5000`/`$9000` relocation tests; resolved by reading registers
  (confirming the CPU was genuinely idle in KERNAL, not stuck inside
  DASH) and by taking a fresh screenshot after issuing each command
  rather than trusting a stale cached one.
- DASH's F3 (Applications page) key stopped responding to the named
  `vice_keyboard_key_press("F3")` call after its first successful use in
  a session; sending the real PETSCII/GETIN byte `$86` that `dmain.s`'s
  own `CPX #$86` check expects via `vice_keyboard_petscii` worked
  reliably instead.

## Envelope Changes

None. This WP touches only DASH's own source and its manifest; no CASM
production or test-harness envelope was affected.

## Regression Evidence

- Full clean rebuild from scratch: every target links and packs clean,
  no overflow, no unresolved externals.
- `test_casm_expr`: `CASM EXPR: PASS` (live VICE, `casm_phase12_test.d64`).
- `test_casm_pass1`: `CASM PASS1: PASS` (live VICE, same disk).
- `test_casm_frame`: `CASM FRAME: PASS` (live VICE, `casm_phase13_test.d64`).

## Live VICE Evidence

- VICE 3.10 C64SC answered MCP ping throughout (two unprompted crashes
  and clean restarts mid-session, see Notes above).
- `CASM DMAIN.S /O:DASH.PRG` → clean shell return, no diagnostic.
- `COMP DASH.PRG DASH.REF` → `FILES COMPARE OK`.
- `dash.prg` extracted from the host disk image: 4,766 bytes, SHA-256
  matching the pre-conversion manifest exactly.
- Relocation at `$3800`/`$5000`/`$9000`: all three rendered the System
  page correctly; Applications page confirmed `dash 5000-5ef3` and
  `dash 9000-9ef3`.
- Every dispatch ended with a clean `c64[8]:>`/`c64[9]:>` shell return.

## Manual Confirmation

1. Boot `build/command64_casm_utils.d64`'s companion Command64 disk,
   attach `command64_casm_utils.d64` on a second unit, `DRIVE <unit>`.
2. `CASM DMAIN.S /O:DASH.PRG`, then `COMP DASH.PRG DASH.REF`; expect
   `FILES COMPARE OK`.
3. Boot `build/image.d64`; run `dash` (default `$3800`), confirm the
   System page renders. `LOAD DASH 5000`/`RUN 5000` and `LOAD DASH 9000`/
   `RUN 9000`; confirm the Applications page (F3) reports the matching
   range at each address.
4. Confirm CASM's own version banner still reads `CASM V0.3.0` (no CASM
   version bump this WP -- it's a DASH-only change).

## Completion Gate

- [x] All five `.RES` conversions live-verified: ca65 cross-check clean,
      native CASM assembly COMP-identical to the ca65 reference.
- [x] Regenerated `dash.ref.hex` proven byte-identical to the
      pre-conversion manifest (three independent confirmations).
- [x] Relocation spot-check clean at `$3800`/`$5000`/`$9000`.
- [x] `AGENTS.md` updated to document `.RES`/`.FILL` in the
      dual-assembler subset.
- [x] Full production rebuild (`image_d64`) confirmed stable, no-change
      rebuild verified.
- [x] CASM's own regression witnesses confirmed clean.
- [x] Walkthrough recorded here.
- [x] **User explicitly approves closing WP84.** Approved 2026-08-21.

WP84 is complete. Phase 13 remains open for WP85 (consolidated
verification and version promotion to `0.4.0`).
