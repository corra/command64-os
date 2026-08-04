# DEBUG REU/Address Syntax WP5 Walkthrough

**Status:** Confirmed by user 2026-08-06

**Build:** DEBUG 0.4.0 build 1124

**Branch:** `feature/debug-reu-address-wp5`

## Automated Evidence

- `cmake --build build --target debug image_d64 test_image_d64` passed
  with no warnings or errors attributable to WP5.
- DEBUG rebuilt clean at 8,033 code bytes and 959 relocation points,
  within the existing 8KB `MAIN` envelope (up from WP4's merged baseline
  of 7,615 bytes / 893 relocations) — **headroom is now tight**: roughly
  160 bytes of code budget remain before the combined `CODE+RODATA+DATA+
  BSS` footprint reaches the 8192-byte ceiling, and WP6 still needs to add
  chunked-transfer logic and state on top.
- BSS growth is exactly 8 bytes (`reuMoveHandle`, `reuMoveOffLo/Hi`,
  `reuMoveAddrLo/Hi`, `reuMoveLenLo/Hi`, `reuMoveDir`) beyond WP4's state;
  no new private zero-page state (`validateReuWindow`'s capacity scratch
  reuses the existing general-purpose `val1`/`val1+1` cells, the same
  ones `G`'s indirect jump already uses transiently).
- Static grep of `src/external/debug/debug.s` found zero references to
  `DOS_VMM_READ` or `DOS_VMM_WRITE`.
- VICE 3.10 booted `build/image.d64`, displayed the Command64 0.4.1
  banner, and launched DEBUG 0.4.0 build 1124 by name from the shell.
- VICE matrix results (REU enabled; `XA 0100` = handle 0, 4KB; `XA 1000` =
  handle 1, 64KB):
  - Flat/page equivalence (handle 1): `XM 1 0000 6000 0001 R`,
    `XM 1 0000:0000 6000 0001 R`, `XM 1 1000 6000 0001 R`, and
    `XM 1 0001:0000 6000 0001 R` all print `XM PREFLIGHT OK`.
  - Malformed `page:offset`: `0001:1000`, `0010:0000`, `0001:` (bare
    colon with nothing after) all print `ERROR`.
  - Allocation-window boundary (handle 0, 4KB): offset `0000` length
    `1000` (exact fill) -> OK; length `1001` -> `ERROR`; offset `0FFF`
    length `0001` (final valid byte) -> OK; offset `1000` length `0001`
    (one byte past capacity) -> `ERROR`.
  - Allocation-window 64KB boundary (handle 1): `000F:0FFF` length
    `0001` (ends exactly at `$10000`) -> OK; length `0002` -> `ERROR`.
  - C64-window wrap (handle 0): address `FFFF` length `0002` -> `ERROR`;
    length `0001` (ends exactly at `$10000`) -> OK.
  - Direction `X` -> `ERROR`; missing direction -> `ERROR`; trailing
    `EXTRA` after a valid direction -> `ERROR`; zero length -> `ERROR`;
    handle `9` (out of range) -> `ERROR`; `XD 0` then re-querying handle
    0 -> `ERROR` (inactive, rejected before any window check).
- WP1 `G`/`T`/`P`/`Q` regression, verified via the checkpoint/register
  procedure documented in `brain/walkthroughs/2026-08-05-debug-reu-
  address-syntax-wp3.md` (non-temporary `exec` checkpoints, asserted via
  `vice_read_registers`, not screen text): `PC=$6000` confirmed on
  `G =6000`; `PC=$6101` confirmed on both `T =6100` and `P =6100`; `Q`
  released the one remaining active allocation and returned cleanly to
  `c64[8]:>`.

## Envelope Headroom Warning

DEBUG's `MAIN` segment is a fixed 8192-byte (`$2000`) window covering
`CODE+RODATA+DATA+BSS` together. WP5's build (8,033 code bytes) plus its
BSS (registry, WP3/WP4/WP5 scratch, `sysInfoBuf`, `inputBuf`, register-
save state — on the order of 220 bytes total) leaves on the rough order
of *tens* of bytes of slack, not hundreds. WP6 (chunked `DOS_VMM_READ`/
`DOS_VMM_WRITE` transfers, progress tracking, restaging logic) is the
next work package and will need real code. Recommend measuring available
headroom precisely (a proper `ld65` map/label export, not just the
`reloc.py` code-byte count) before or very early into WP6, and treating a
possible envelope expansion or size-reduction pass as an explicit
decision point rather than discovering an overflow mid-implementation.

## Flat/Page Equivalence Confirmation

Run:

```text
XA 1000
XM 1 0000 6000 0001 R
XM 1 0000:0000 6000 0001 R
XM 1 1000 6000 0001 R
XM 1 0001:0000 6000 0001 R
```

Expected: all four print `XM PREFLIGHT OK`.

## Malformed `page:offset` Confirmation

Run:

```text
XM 1 0001:1000 6000 0001 R
XM 1 0010:0000 6000 0001 R
XM 1 0001: 6000 0001 R
```

Expected: all three print `ERROR`.

## Allocation-Window Boundary Confirmation

Run:

```text
XA 0100
XM 0 0000 6000 1000 R
XM 0 0000 6000 1001 R
XM 0 0FFF 6000 0001 R
XM 0 1000 6000 0001 R
```

Expected: first and third print `XM PREFLIGHT OK`; second and fourth
print `ERROR`.

## 64KB Allocation Boundary Confirmation

Run (against the 64KB handle from the equivalence test above):

```text
XM 1 000F:0FFF 6000 0001 R
XM 1 000F:0FFF 6000 0002 R
```

Expected: first prints `XM PREFLIGHT OK` (ends exactly at `$10000`);
second prints `ERROR`.

## C64-Window Wrap Confirmation

Run:

```text
XM 0 0000 FFFF 0002 R
XM 0 0000 FFFF 0001 R
```

Expected: first prints `ERROR` (would wrap past `$FFFF`); second prints
`XM PREFLIGHT OK` (ends exactly at `$10000`).

## Direction, Trailing Input, and Handle Confirmation

Run:

```text
XM 0 0000 6000 0001 X
XM 0 0000 6000 0001
XM 0 0000 6000 0001 R EXTRA
XM 0 0000 6000 0000 R
XM 9 0000 6000 0001 R
XD 0
XM 0 0000 6000 0001 R
```

Expected: every line prints `ERROR`.

## WP1 `G`/`T`/`P`/`Q` Regression Confirmation

Run:

```text
E 6000 60
E 6100 EA EA EA 60
G =6000
T =6100
P =6100
Q
```

Expected: `G =6000` executes the installed `RTS` and returns to the `-`
prompt without printing an error; `T =6100` traces to `PC=$6101` and
disassembles `NOP`; `P =6100` proceeds to `PC=$6101` and disassembles
`NOP`; `Q` returns to a shell prompt matching `c64[<device>]:>`.

## Confirmation Gate

The user confirmed this walkthrough on 2026-08-06, including the envelope
headroom warning above as a planning input for WP6, not a WP5 blocker.
WP5 is marked complete in the wiki task, `brain/task.md`, and Taskwarrior
UUID `a4809e03-ee37-4973-8fc6-2896bf2ea69c`.
