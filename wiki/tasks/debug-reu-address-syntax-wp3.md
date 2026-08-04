# Task Spec: DEBUG REU/Address Syntax WP3

## Objective

Implement `XA`/`XD` allocation-lifecycle behavior and route `Q` through
cleanup, per `brain/plans/2026-08-05-debug-reu-address-syntax-wp3.md`.

Taskwarrior UUID: `49b81383-9e58-4f51-95f2-f7f7ad3a0427`

## Scope

- Implement `XA paragraphs`: parse, validate `$0001-$1000`, find a free
  registry slot, call `DOS_ALLOC_MEM`, register on success, print the
  documented summary.
- Implement `XD handle`: parse an active handle, call `DOS_FREE_MEM`, clear
  the record only after success.
- Implement `freeAllReu` and route `Q` through it; exit only on full
  cleanup success.
- Call no `DOS_VMM_READ`, `DOS_VMM_WRITE`, or `DOS_GET_SYSTEM_INFO`.
- Preserve WP1/WP2 behavior.

## Increments

- [x] Increment 1: `XA` allocation, build, and VICE verification.
- [x] Increment 2: `XD` release, build, and VICE verification.
- [x] Increment 3: `freeAllReu` and `Q` routing, build, and VICE
      verification.
- [x] Increment 4: full regression, artifact audit, documentation, DOX, and
      user-confirmed walkthrough.

## Acceptance

- [x] `XA` allocates, registers, and reports within its documented bounds.
- [x] `XD` releases and clears only on OS success; failures preserve state.
- [x] `freeAllReu`/`Q` release every possible active allocation with no
      early exit, and `Q` exits only on full success.
- [x] No new VMM/system-info API call or private zero-page state.
- [x] DEBUG remains relocatable and inside its existing linker envelope.
- [x] The user confirms the walkthrough before WP3 is marked complete.

## Evidence

DEBUG builds: 1120 (`XA`, 7,203 code bytes / 822 relocations), 1121 (`XD`,
7,265 / 835), 1122 (`freeAllReu`/`Q`, 7,349 / 851; within the 8KB `MAIN`
envelope).

VICE matrix (REU enabled, `build/image.d64`, device 8):

- `XA 0001` -> `00: SEG=02 BANK=00 PARA=0001 PAGES=01 SIZE=0010`
- `XA 0100` -> `01: SEG=03 BANK=00 PARA=0100 PAGES=01 SIZE=1000` (matches the
  parent plan's Section 2.2 example exactly)
- `XA 1000` -> `02: SEG=04 BANK=00 PARA=1000 PAGES=10 SIZE=10000` (64KB
  boundary; confirms the 17-bit `SIZE=10000` literal path)
- `XA 0000` and `XA 1001` -> `ERROR`, no registry change
- Fourth `XA 0001` succeeds (slot 03); fifth concurrent `XA 0001` ->
  `ERROR` (registry full) before any OS call
- `XD 0` -> silent success; repeated `XD 0` -> `ERROR` (inactive); `XD 9`
  -> `ERROR` (out of range, rejected before any OS call)
- `XA 0001` after the free reuses slot 00 (lowest free slot)
- `Q` with four active allocations -> clean return to `c64[8]:>`
- DEBUG restarted; `XD 0`/`1`/`2`/`3` each -> `ERROR` (inactive), confirming
  no allocation leaked across `Q`/restart

VICE matrix (REU disabled, fresh Command64 boot with the `REU` VICE
resource cleared before boot — the DOS-side VMM-available flag latches at
Command64 startup, so REU must be off before the OS boots, not toggled
mid-session):

- `XA 0001` -> `ERROR` (VMM unavailable)
- `XD 0` -> `ERROR` (no active handle, rejected before any OS call)
- `Q` -> clean return to `c64[8]:>` with nothing to clean up

Static verification: `grep` confirms zero `DOS_VMM_READ`/`DOS_VMM_WRITE`/
`DOS_GET_SYSTEM_INFO` call sites in `debug.s`; BSS growth is exactly 3
bytes (`reuXferParaLo`, `reuXferParaHi`, `reuXferSlot`) beyond WP2's
20-byte registry; `image_d64` and `test_image_d64` both build clean.

**Update 2026-08-05**: WP1's `G`/`T`/`P` smoke tests are now re-verified
by an automated checkpoint/register-based procedure (non-temporary `exec`
checkpoints at `$6000` and DEBUG's computed breakpoint target `$6101`,
inspected via `vice_read_registers`/`vice_read_memory` instead of
screen-text OCR), replacing the earlier manual-only re-check. See
`brain/walkthroughs/2026-08-05-debug-reu-address-syntax-wp3.md`'s "WP1
`G`/`T`/`P` Regression: Now Automated" section for the full method,
including the finding that temporary checkpoints did not reliably hold
execution for inspection in this MCP. (An initial attempt in this pass
had reused `$6000`/`$6100` without poking fixture bytes first, crashing a
fresh boot back to BASIC — a test-setup gap, not a WP3 code defect, since
`cmdGo`/`cmdTraceProceedCommon` are untouched by this work package.)
