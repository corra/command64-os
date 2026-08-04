# DEBUG REU/Address Syntax WP3 Walkthrough

**Status:** Confirmed by user 2026-08-04

**Build:** DEBUG 0.4.0 build 1122

**Branch:** `feature/debug-reu-address-wp3`

## Automated Evidence

- `cmake --build build --target debug image_d64 test_image_d64` passed with
  no warnings or errors attributable to WP3.
- DEBUG rebuilt clean at 7,349 code bytes and 851 relocation points, within
  the existing 8KB `MAIN` envelope (up from WP2's merged baseline of 6,885
  bytes / 762 relocations).
- BSS growth is exactly 3 bytes (`reuXferParaLo`, `reuXferParaHi`,
  `reuXferSlot`) beyond WP2's 20-byte registry; no new private zero-page
  state.
- Static grep of `src/external/debug/debug.s` found zero references to
  `DOS_VMM_READ`, `DOS_VMM_WRITE`, or `DOS_GET_SYSTEM_INFO`.
  `DOS_ALLOC_MEM`/`DOS_FREE_MEM` appear only in `cmdReuAlloc`, `cmdReuFree`,
  and `freeAllReu`.
- VICE 3.10 booted `build/image.d64`, displayed the Command64 0.4.1 banner,
  and launched DEBUG 0.4.0 build 1122 by name from the shell.
- VICE matrix results (REU enabled):
  - `XA 0001` -> `00: SEG=02 BANK=00 PARA=0001 PAGES=01 SIZE=0010`
  - `XA 0100` -> `01: SEG=03 BANK=00 PARA=0100 PAGES=01 SIZE=1000` (matches
    the parent plan's Section 2.2 example exactly)
  - `XA 1000` -> `02: SEG=04 BANK=00 PARA=1000 PAGES=10 SIZE=10000` (the
    64KB boundary; confirms the 17-bit `SIZE=10000` literal path)
  - `XA 0000` and `XA 1001` -> `ERROR`, no registry change
  - A fourth `XA 0001` succeeds (slot 03); a fifth concurrent `XA 0001` ->
    `ERROR` (registry full) before any OS call
  - `XD 0` -> silent success; a repeated `XD 0` -> `ERROR` (inactive);
    `XD 9` -> `ERROR` (out of range, rejected before any OS call)
  - `XA 0001` after the free reuses slot 00 (lowest free slot)
  - `Q` with four active allocations -> clean return to `c64[8]:>`
  - DEBUG restarted; `XD 0`/`1`/`2`/`3` each -> `ERROR` (inactive),
    confirming no allocation leaked across `Q`/restart
- VICE matrix results (REU disabled -- the `REU` VICE resource was cleared
  before Command64's own boot, since the OS's VMM-available flag latches at
  Command64 startup and does not update from a mid-session toggle):
  - `XA 0001` -> `ERROR` (VMM unavailable)
  - `XD 0` -> `ERROR` (no active handle, rejected before any OS call)
  - `Q` -> clean return to `c64[8]:>` with nothing to clean up

## Not Yet Re-Verified: WP1 `G`/`T`/`P` Regression

WP3 does not modify `cmdGo` or `cmdTraceProceedCommon`, so this is a
regression check, not new WP3 behavior. An automated re-check attempted in
this pass reused `$6000`/`$6100` as execution targets on a freshly booted
`image.d64` without first poking fixture bytes there, which crashed back to
BASIC -- a test-setup gap (the fixture bytes from WP1/WP2's own walkthrough
session were not present on a clean boot), not a WP3 code defect. Please
run this manually as part of confirming the walkthrough:

```text
E 6000 60
E 6100 EA EA EA 60
G =6000
T =6100
P =6100
Q
```

Expected:

- `G =6000` executes the installed `RTS` and returns to the `-` prompt
  without printing an error.
- `T =6100` traces to `PC=$6101` and disassembles `NOP`.
- `P =6100` proceeds to `PC=$6101` and disassembles `NOP`.
- `Q` returns to a shell prompt matching `c64[<device>]:>`.

## `XA` Allocation Confirmation

Run:

```text
XA 0001
XA 0100
XA 1000
XA 0000
XA 1001
```

Expected:

- `XA 0001` allocates and prints `00: SEG=xx BANK=xx PARA=0001 PAGES=01
  SIZE=0010`.
- `XA 0100` allocates and prints `01: SEG=xx BANK=xx PARA=0100 PAGES=01
  SIZE=1000`.
- `XA 1000` allocates and prints `02: SEG=xx BANK=xx PARA=1000 PAGES=10
  SIZE=10000`.
- `XA 0000` and `XA 1001` both print `ERROR` and allocate nothing.

## Registry-Full Confirmation

Run:

```text
XA 0001
XA 0001
```

Expected: the first line allocates handle `03` (the fourth slot); the
second prints `ERROR` with no allocation.

## `XD` Release Confirmation

Run:

```text
XD 0
XD 0
XD 9
```

Expected: the first line frees handle `0` silently (no output, returns to
the `-` prompt); the second prints `ERROR` (already inactive); the third
prints `ERROR` (out of range).

## `Q` Cleanup Confirmation

With one or more allocations still active (from the sequences above), run:

```text
Q
```

Expected: DEBUG exits cleanly to `c64[<device>]:>`. Restart DEBUG and run
`XD 0`, `XD 1`, `XD 2`, `XD 3`: every one should print `ERROR` (inactive),
confirming no allocation survived `Q`.

## REU-Disabled Confirmation

Reboot Command64 with REU disabled (VICE `REU` resource cleared before the
Command64 boot, not mid-session), launch DEBUG, and run:

```text
XA 0001
XD 0
Q
```

Expected: `XA 0001` and `XD 0` both print `ERROR`; `Q` returns cleanly to
`c64[<device>]:>` with nothing to clean up.

## Confirmation Gate

The user confirmed this walkthrough on 2026-08-04, including authorizing
closeout with the `G`/`T`/`P` regression re-check performed as documented
in WP1/WP2 rather than re-run fresh in this pass (that code path is
unmodified by WP3). WP3 is marked complete in the wiki task,
`brain/task.md`, and Taskwarrior UUID
`49b81383-9e58-4f51-95f2-f7f7ad3a0427`.
