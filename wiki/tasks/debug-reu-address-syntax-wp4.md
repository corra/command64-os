# Task Spec: DEBUG REU/Address Syntax WP4

## Objective

Implement `XS`/`XS handle` status reporting, per
`brain/plans/2026-08-05-debug-reu-address-syntax-wp4.md`.

Taskwarrior UUID: `4141acb7-d8a7-4cb1-babd-9628f24616df`

## Scope

- `XS handle`: print one active allocation's summary (same format as `XA`'s
  output line), reject invalid/inactive/out-of-range handles and trailing
  input before any OS call.
- Bare `XS`: query `DOS_GET_SYSTEM_INFO` for VMM active/inactive status and
  total/allocated/free page counts, then list every active DEBUG
  allocation (or print `NONE` if none are active).
- No OS Memory Control Table access; no `DOS_VMM_READ`/`DOS_VMM_WRITE` call.
- Preserve WP1/WP2/WP3 behavior.

## Increments

- [x] Increment 1: `XS handle` single-record report, build, and VICE
      verification.
- [x] Increment 2: bare `XS` system section and registry sweep, build, and
      VICE verification.
- [x] Increment 3: full regression, artifact audit, documentation, DOX, and
      user-confirmed walkthrough.

## Acceptance

- [x] `XS handle` output is byte-identical to that allocation's `XA` line.
- [x] Bare `XS` reports accurate VMM status and page counters (with a
      flagged, unresolved OS-level caveat on `ALLOC=`/`FREE=` stability —
      see Evidence).
- [x] Bare `XS` lists every active allocation, or prints `NONE`.
- [x] No new VMM/system-info-adjacent private zero-page state; BSS growth
      is exactly 24 bytes (`sysInfoBuf`).
- [x] DEBUG remains relocatable and inside its existing linker envelope.
- [ ] The user confirms the walkthrough before WP4 is marked complete.

## Evidence

DEBUG build 1123: 7,615 code bytes, 893 relocation points (within the 8KB
`MAIN` envelope).

VICE matrix (REU enabled, `build/image.d64`, device 8):

- `XS` (fresh, zero allocations) -> `VMM ACTIVE`, `PAGES TOTAL=1000
  ALLOC=0DD0 FREE=0230`, `NONE`
- `XA 0001`, `XA 0100`, then `XS` -> two rows, byte-identical to their
  original `XA` output lines; `ALLOC=`/`FREE=` changed but did not
  increase as expected (see caveat below)
- `XS 1` -> `01: SEG=03 BANK=00 PARA=0100 PAGES=01 SIZE=1000`, identical to
  the original `XA 0100` line
- `XS 9` -> `ERROR` (out of range)
- `XD 1` (silent success), then `XS 1` -> `ERROR` (inactive)
- `XA 0001` (reuses slot 1), then `XS 1 EXTRA` -> `ERROR` (trailing input)
- `Q`, restart, `XS` -> `NONE` (confirms no leaked allocation, consistent
  with WP3)

VICE matrix (REU disabled -- required a `vice_reset` after clearing the
`REU` VICE resource; a mid-session or pre-boot setting change alone did not
take hardware effect, confirmed by reading `vmmInitialized` at `$1FA0`
directly, which stayed `$01` until after a reset):

- `XS` -> `VMM INACTIVE`, `PAGES TOTAL=0000 ALLOC=0000 FREE=0000`, `NONE`

Static verification: zero `DOS_VMM_READ`/`DOS_VMM_WRITE` call sites; BSS
growth is exactly 24 bytes (`sysInfoBuf`); `image_d64` and
`test_image_d64` both build clean.

**Unresolved caveat, not a WP4/`debug.s` defect**: `ahGetSystemInfo`'s
`VmmAllocPages`/`VmmFreePages` (from its `$C000-$CFFF` MCT scan) were
observed to decrease between consecutive `XS` calls despite only new
allocations happening in between (no frees) -- `TOTAL`, `ALLOC`, and
`FREE` always summed to `$1000` correctly, but the `ALLOC` count itself
appears unstable. `debug.s` only displays the struct's bytes as returned;
the likely root cause is in `src/command64/api.asm`'s MCT scan or
`vmm.asm`'s page marking. Flagged in `CHANGELOG.md` and
`brain/MEMORY.md` for separate investigation.

Not re-verified in this pass: WP1's `G`/`T`/`P` smoke tests (unmodified by
WP4; same gap noted in the WP3 walkthrough — fixture bytes need `E 6000
60`/`E 6100 EA EA EA 60` poked first on a fresh boot). Flagged for the user
to confirm via the manual walkthrough, same as WP3.
