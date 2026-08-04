# DEBUG REU/Address Syntax WP4 Walkthrough

**Status:** Awaiting user confirmation

**Build:** DEBUG 0.4.0 build 1123

**Branch:** `feature/debug-reu-address-wp4`

## Automated Evidence

- `cmake --build build --target debug image_d64 test_image_d64` passed with
  no warnings or errors attributable to WP4.
- DEBUG rebuilt clean at 7,615 code bytes and 893 relocation points, within
  the existing 8KB `MAIN` envelope (up from WP3's merged baseline of 7,349
  bytes / 851 relocations).
- BSS growth is exactly 24 bytes (`sysInfoBuf`) beyond WP3's state; no new
  private zero-page state.
- Static grep of `src/external/debug/debug.s` found zero references to
  `DOS_VMM_READ` or `DOS_VMM_WRITE`. `DOS_GET_SYSTEM_INFO` appears only in
  `cmdReuStatus`'s bare-`XS` branch.
- VICE 3.10 booted `build/image.d64`, displayed the Command64 0.4.1 banner,
  and launched DEBUG 0.4.0 build 1123 by name from the shell.
- VICE matrix results (REU enabled):
  - `XS` (fresh, zero allocations) -> `VMM ACTIVE`, `PAGES TOTAL=1000
    ALLOC=0DD0 FREE=0230`, `NONE`
  - `XA 0001`, `XA 0100`, then `XS` -> two rows, byte-identical to their
    original `XA` output lines
  - `XS 1` -> `01: SEG=03 BANK=00 PARA=0100 PAGES=01 SIZE=1000`, identical
    to the original `XA 0100` line
  - `XS 9` -> `ERROR` (out of range)
  - `XD 1` (silent success), then `XS 1` -> `ERROR` (inactive)
  - `XA 0001` (reuses slot 1), then `XS 1 EXTRA` -> `ERROR` (trailing
    input)
  - `Q`, restart, `XS` -> `NONE` (no leaked allocation)
- VICE matrix results (REU disabled -- confirmed by reading
  `vmmInitialized` at `$1FA0` directly, which required a `vice_reset`
  after clearing the VICE `REU` resource; the setting alone did not take
  hardware effect before a reset):
  - `XS` -> `VMM INACTIVE`, `PAGES TOTAL=0000 ALLOC=0000 FREE=0000`, `NONE`

## Unresolved Caveat (Not a WP4 Defect)

`ahGetSystemInfo`'s `VmmAllocPages`/`VmmFreePages` (from its
`$C000-$CFFF` Memory Control Table scan, in `src/command64/api.asm`) were
observed to *decrease* between consecutive `XS` calls despite only new
allocations happening in between (no frees). `TOTAL`, `ALLOC`, and `FREE`
always summed to `$1000` correctly in both readings, so the arithmetic is
internally consistent, but the `ALLOC` count itself appears unstable
across calls. `debug.s` only displays the struct's bytes exactly as
`DOS_GET_SYSTEM_INFO` returns them -- this is outside WP4's own scope and
likely points at the MCT scan in `api.asm` or page marking in `vmm.asm`.
Recorded in `CHANGELOG.md` and `brain/MEMORY.md`; flagged for a separate
investigation, not fixed here.

## WP1 `G`/`T`/`P` Regression: Automated (2026-08-05)

WP4 does not modify `cmdGo` or `cmdTraceProceedCommon`. This gap (manual
in the initial WP3/WP4 passes) is now closed with a checkpoint/register-
based procedure — see `brain/walkthroughs/2026-08-05-debug-reu-address-
syntax-wp3.md`'s "WP1 `G`/`T`/`P` Regression: Now Automated" section for
the full method and findings (non-temporary checkpoints only; verify
fixture pokes and trace/proceed landings by `vice_read_memory`/
`vice_read_registers`, not screen text). Re-run against this WP4 build
(1123) with the same sequence and got the same results: `G =6000` and
`T`/`P =6100` land exactly on `PC=$6000`/`$6101` as checkpoint-confirmed,
and `Q` returns cleanly to `c64[8]:>`.

```text
E 6000 60
E 6100 EA EA EA 60
G =6000
T =6100
P =6100
Q
```

## `XS handle` Confirmation

Run:

```text
XA 0001
XS 0
XS 9
XD 0
XS 0
```

Expected:

- `XS 0` prints the identical line `XA 0001` just printed.
- `XS 9` prints `ERROR` (out of range).
- `XD 0` frees silently.
- `XS 0` prints `ERROR` (inactive).

## Bare `XS` Confirmation

Run:

```text
XS
XA 0001
XA 0100
XS
XD 0
XS
```

Expected:

- The first `XS` (no allocations) prints `VMM ACTIVE`, a `PAGES` line, and
  `NONE`.
- After two allocations, `XS` prints `VMM ACTIVE`, a `PAGES` line, and two
  allocation rows.
- After freeing one, `XS` prints one remaining row.

## REU-Disabled Confirmation

Reboot Command64 with REU disabled (VICE `REU` resource cleared, then a
reset performed, before the Command64 boot -- confirm with a fresh boot
rather than a mid-session toggle), launch DEBUG, and run:

```text
XS
```

Expected: `VMM INACTIVE`, `PAGES TOTAL=0000 ALLOC=0000 FREE=0000`, `NONE`.

## Confirmation Gate

Do not mark WP4 complete until the user confirms this walkthrough and
accepts the unresolved MCT-scan caveat (Section above) as out-of-scope
follow-up work rather than a WP4 blocker. The `G`/`T`/`P`/`Q` regression
check is now fully automated evidence (Section above), not a manual item.
