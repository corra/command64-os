---
feature: casm-progress-increment06-directive-integration
plan: brain/plans/2026-08-24-casm-progress-increment06-directive-integration.md
status: in-progress
---

# CASM Progress Increment 6 Directive Integration Walkthrough

## Status

Increment 6 is active. Atomic Increments 1-6 are complete; Atomic Increment 7
remains pending. This walkthrough does not close Increment 6.

## Scope Amendment

On 2026-08-24 the user explicitly restored `.RES`, `.FILL`, `.ALIGN`, and
`.INCBIN` directive cadence, superseding that part of Increment 2's scope trim.
Growth beyond the current `$7400` MAIN envelope remains separately gated.

## Atomic Increment 1 Evidence

### ABI and Storage

- Added three ordinary BSS bytes in `progress.s`:
  `CasmProgDirectiveKind` and `CasmProgDirectiveLo/Hi`.
- Added `progressBeginDirective`: stores A as the directive subtype and resets
  cumulative bytes.
- Added `progressDirectiveBytes`: stores caller-authoritative cumulative
  successfully accepted bytes from A/X.
- Added no zero page, emitter ownership, parser/directive record growth, file
  handle, VMM allocation, rendering, or emission hook.

### Focused Cases

`test_casm_progress` grew from 20 to 22 cases:

1. `U`: a stale `$AAAA` count is reset to zero while `CASM_DIRECTIVE_FILL` is
   retained as the active subtype.
2. `V`: `CASM_DIRECTIVE_INCBIN` remains selected while cumulative values
   0, 1, 255, 256, 257, and 65,535 are stored exactly.

### Build Evidence

- `cmake --build build --target test_casm_progress`: pass; build 1008,
  1,965 code bytes, 359 relocation points.
- `cmake --build build --target casm`: pass; build 1368, 24,961 code bytes,
  3,968 relocation points, within the existing `$7400` envelope.
- Immediate no-change rebuild of both targets: no counter increment or rebuild.
- `cmake --build build --target test_image_d64`: pass; rebuilt `test.d64`
  contains `test_casm_progre` and all existing post-build fixture appends
  completed successfully.
- `git diff --check`: pass before live verification.

### Live VICE Evidence

- VICE MCP: version 3.10, existing healthy MCP-owned session on port 7000.
- Reattached rebuilt `build/test.d64` to unit 8 and autostarted index 0 only to
  boot Command64.
- Screen RAM proved `Command 64-DOS Version` and `c64[8]:>` before dispatch.
- Generated exact PETSCII with
  `tools/vice_type_command.py "test_casm_progress"`; no hand-derived bytes.
- The harness printed all case markers through `U` and `V`, then
  `CASM PROGRESS: PASS`, and returned normally to `c64[8]:>`.
- Screenshot evidence: `/tmp/opencode/casm-progress-inc6-atomic1.png`.
- Final classification: PASS. VICE remains healthy and running.

## Pending

## Atomic Increment 2 Evidence

### Bounded Fixed-Fill Loop

- `emitFillLoop` now selects an outer chunk of `$0100` whenever the 16-bit
  remaining high byte is nonzero; otherwise it selects the final 1-255-byte
  tail. Zero count still exits before `emitByte`.
- `CasmFillChunkLo/Hi` owns only current chunk remaining.
  `CasmFillAcceptedLo/Hi` increments only after `emitByte` succeeds.
- The original `CasmEmitScratch0/1` authoritative remaining count, fill value,
  `emitByte` PC/overflow behavior, carry diagnostic, and Pass 1/2 mode gate are
  unchanged.
- No progress call or rendering occurs yet.

### Build and Live Evidence

- `test_casm_directives`: build 1008, 1,889 code bytes, 333 relocations.
  Its tenth case emits `.RES 257,$AA` from `$C000` and requires final PC
  `$C101`, proving one full chunk plus one-byte tail.
- `casm`: build 1369, 25,023 code bytes, 3,982 relocations; both relocation
  bases link within `$7400`.
- `test_casm_progress`: unchanged focused suite builds clean.
- Immediate no-change `test_casm_directives`/`casm` rebuild: stable.
- `casm_include_test_d64`: rebuilt clean with the changed harness.
- Live VICE 3.10: reattached the rebuilt image to unit 8, booted Command64,
  dispatched exact helper-generated PETSCII for `test_casm_directives`, observed
  10 pass dots and `CASM DIRECTIVES: PASS`, then normal `c64[8]:>` return.
- Screenshot evidence: `/tmp/opencode/casm-progress-inc6-atomic2.png`.

## Pending

- Atomic Increment 7: timing/envelope/no-change closeout.

## Atomic Increment 3 Envelope Gate

The candidate adds fixed-fill begin/chunk calls and a 34-column directive byte
line. Production and focused links pass (`casm`: 25,195 code bytes, 4,011
relocations; `test_casm_directives`: 2,103/379; `test_casm_progress`: 2,110/381).

The first aggregate build found `test_casm_bounds` lacked stand-ins for the two
new `emit.s` imports. A systematic audit of all six `emit.s` CMake boundaries
proved only the two narrow harnesses avoid real `progress.s`: directives already
had instrumented stand-ins; bounds now has intentionally unreachable no-op
stand-ins. This was an in-scope harness dependency defect, not product behavior.

Real-`progress.s` harness measurements then reached the approved envelope gate:

| Harness | Current | Overflow | Smallest round-page fit |
| --- | ---: | ---: | ---: |
| `test_casm_catalog` | `$2200` | 101 | `$2300` |
| `test_casm_event` | `$2200` | 137 | `$2300` |
| `test_casm_pass1` | `$6700` | 212 | `$6800` |
| `test_casm_passcheck` | `$6300` | 226 | `$6400` |
| `test_casm_frame` | `$6700` | 76 | `$6800` |
| `test_casm_listcap` | `$6B00` | 256 | `$6C00` |

`test_casm_faultsource` and `test_casm_spanread` still fit their existing
`$3700` envelopes. The user approved the six smallest one-page increases shown
above; the aggregate build and focused no-change builds pass with them.

### Focused Live Verification

- Rebuilt and reattached `build/test.d64` on device 8 and
  `build/casm_include_test.d64` on device 9 before testing.
- Proved the fresh Command64 boot from screen RAM row 0 as
  `Command 64-DOS Version 0.4.1.2680`.
- The first `test_casm_progress` run deterministically printed FAIL. RCA found
  a harness-only ABI violation: `caseDirectiveByteBoundaries` retained its
  array index in Y across `progressDirectiveBytes`, which explicitly clobbers
  Y. The rendered `P1: INCBIN 00001` was correct production behavior.
- Preserved the harness index on the 6502 stack, rebuilt the harness and both
  images, detached/reattached the images, and rebooted Command64. No production
  source changed for this correction.
- `test_casm_progress` then rendered the final `P1: INCBIN 65535`, printed
  `CASM PROGRESS: PASS`, and returned to `c64[8]:>`.
- After switching to device 9, `test_casm_directives` printed its 11 pass dots,
  `CASM DIRECTIVES: PASS`, and returned to `c64[9]:>`.
- `git diff --check` passes. VICE 3.10 remains healthy and running at the
  device-9 shell prompt.

## Completion Gate

- [x] Atomic Increment 1 focused state and boundary evidence complete.
- [x] Atomic Increment 2 bounded-loop and live harness evidence complete.
- [x] Atomic Increment 3 user sign-off received 2026-08-24.
- [x] Atomic Increment 4 user sign-off received 2026-08-24.
- [x] Atomic Increment 5 user sign-off received 2026-08-24.
- [x] Atomic Increment 6 user sign-off received 2026-08-24.
- [ ] Atomic Increment 7 complete.
- [ ] Full Increment 6 walkthrough approved by the user.

## Atomic Increment 4 Envelope Gate

The candidate adds `.INCBIN` begin notification, a private 16-bit cumulative
accepted-byte counter, and one post-consumption notification at each complete
input block boundary. The focused real-emitter harness synthesizes the same
up-to-256-byte read shape and checks 0, 1, 255, 256, 257, and 65,535 bytes.

- `test_casm_directives`: links, 2,311 code bytes and 423 relocations.
- `casm`: links inside `$7400`, 25,228 code bytes and 4,020 relocations.
- `test_casm_passcheck`: exceeds its approved `$6400` envelope by 5 bytes;
  smallest round-page fit is `$6500`.
- `test_casm_listcap`: exceeds its approved `$6C00` envelope by 35 bytes;
  smallest round-page fit is `$6D00`.
- `test_casm_frame`, `test_casm_faultsource`, and `test_casm_spanread`: fit.
- `git diff --check`: pass before the aggregate gate.

Per the approved stop conditions, CMake remains unchanged and live VICE testing
has not started. Verification resumes only after explicit envelope approval.

### Approved Verification

- User approved `$6500` for `test_casm_passcheck` and `$6D00` for
  `test_casm_listcap`, each the smallest round-page fit.
- `cmake -S . -B build`: pass.
- Complete affected aggregate plus rebuilt `test.d64` and
  `casm_include_test.d64`: pass.
- Exact no-change rebuild of `test_casm_passcheck`, `test_casm_listcap`,
  `test_casm_directives`, and `casm`: pass without build-counter drift.
- Fresh Command64 boot banner proved from screen RAM and screenshot under
  VICE 3.10.
- `test_casm_progress`: `CASM PROGRESS: PASS`, normal `c64[8]:>` return.
- `test_casm_directives`: 12 pass dots, `CASM DIRECTIVES: PASS`, normal
  `c64[9]:>` return after the declared 60-second deadline.
- VICE remains healthy and running at the device-9 shell prompt.

Atomic Increment 4 received explicit user approval on 2026-08-24.

## Atomic Increment 5 Failure And Pass Evidence

No production source changed. The focused real-emitter harness grew from 12 to
18 cases and now proves:

- fixed-fill overflow at `$FFFF` accepts the final addressable byte, reports
  `ADDRESS_OVERFLOW` on the next byte, and emits no partial-chunk notification;
- `.INCBIN` has the same overflow/no-partial-notification behavior even when
  its best-effort close also fails;
- an injected read failure remains primary over an injected close failure;
- an injected `emitByte` mirror failure remains primary over close failure;
- one fully consumed block notifies before a subsequent EOF close failure;
- a 257-byte `.INCBIN` produces two notifications and PC `$0101` in both
  `CASM_PASS_MODE_MEASURE` and `CASM_PASS_MODE_EMIT`.

Verification:

- `test_casm_directives`: 2,802 code bytes, 506 relocations; pass.
- Complete affected aggregate and rebuilt `casm_include_test_d64`: pass.
- Exact no-change `test_casm_directives` and `casm`: pass.
- Fresh Command64 banner proved from screen RAM under VICE 3.10.
- Live harness: 18 pass dots, `CASM DIRECTIVES: PASS`, normal `c64[9]:>` return.
- VICE remains healthy and running at the device-9 shell prompt.

Atomic Increment 5 received explicit user approval on 2026-08-24.

## Atomic Increment 6 Consolidated Regression Evidence

Build and no-change gates pass for `test_casm_directives`,
`test_casm_progress`, `test_casm_expr`, `test_casm_pass1`,
`test_casm_passcheck`, `test_casm_listcap`, `test_casm_frame`, and `casm`.
The rebuilt companion images are `casm_include_test.d64`,
`casm_phase12_test.d64`, `casm_listing_test.d64`, and
`casm_phase13_test.d64`.

Fresh live VICE 3.10 evidence:

- `test_casm_directives`: 18 dots, `CASM DIRECTIVES: PASS`, `c64[9]:>`.
- `test_casm_progress`: `CASM PROGRESS: PASS`, `c64[8]:>`.
- `test_casm_expr`: `CASM EXPR: PASS`, `c64[9]:>`.
- `test_casm_pass1`: `CASM PASS1: PASS`, `c64[9]:>` after one bounded
  deadline extension.
- `test_casm_listcap`: `CASM LISTCAP: PASS`, `c64[9]:>` after one bounded
  deadline extension.
- `test_casm_passcheck`: `CASM PASSCHECK: PASS`, `c64[9]:>`.
- `test_casm_frame`: `CASM FRAME: PASS`, `c64[9]:>`.

Phase 13 artifact comparison is not yet evidence. `casm casmres1.s` remained
at load/progress output through the two permitted observations at 30 and 60
seconds, with no shell return established. No third observation and no further
command were issued. Classification: inconclusive, pending a clean retry with a
longer declared deadline. The four required COMP comparisons remain pending.

### Phase 13 Recovery And Final Comparisons

The user approved a clean retry with 150 seconds before the first assembly
observation. A soft reset alone retained the previously dirtied companion disk,
and the first retry reached both CASM passes but reported `OUTPUT WRITE FAILED`.
This was setup failure evidence, not a cadence failure. Recovery followed the
media-provenance rule:

- detached device 9;
- forced fresh base generation of `casm_phase13_test.d64` through CMake;
- verified its directory no longer contained runtime `casmres1.prg` output;
- reattached device 9 and rebooted Command64.

Fresh production results, each with `CASM: INPUT VALIDATED` and normal
`c64[9]:>` return:

- `casm casmres1.s`; `comp casmres1.prg casmres1.ref`:
  `FILES COMPARE OK`.
- `casm casmfill1.s`; `comp casmfill1.prg casmfill1.ref`:
  `FILES COMPARE OK`.
- `casm casmalign1.s`; `comp casmalign1.prg casmalign1.ref`:
  `FILES COMPARE OK`.
- `casm casmincbin1.s`; `comp casmincbin1.prg casmincbin1.ref`:
  `FILES COMPARE OK`.

Atomic Increment 6 consolidated regression and artifact evidence is complete,
pending explicit user approval.

Atomic Increment 6 received explicit user approval on 2026-08-24.
