# Task Spec: DEBUG REU/Address Syntax WP5

## Objective

Implement `XM`'s full grammar and preflight window validation (no DMA), per
`brain/plans/2026-08-06-debug-reu-address-syntax-wp5.md`.

Taskwarrior UUID: `a4809e03-ee37-4973-8fc6-2896bf2ea69c`

## Scope

- Parse `XM handle offset|page:offset address length direction`.
- `parseVmmOffset`: flat and `page:offset` forms normalize identically.
- Validate the REU-side window against the selected allocation's exact
  capacity, including the `$1000`-paragraph (65536-byte) boundary case.
- Validate the C64-side window rejects a wrap past `$FFFF`.
- No `DOS_VMM_READ`/`DOS_VMM_WRITE` call anywhere — that's WP6.
- Preserve WP1-WP4 behavior.

## Increments

- [x] Increment 1: `parseVmmOffset`, flat/page equivalence, build, and
      VICE verification.
- [x] Increment 2: full grammar (address/length/direction/`requireEnd`),
      build, and VICE verification.
- [x] Increment 3: window validation (`validateReuWindow`,
      `validateC64Window`), build, and VICE verification.
- [x] Increment 4: full regression, artifact audit, documentation, DOX,
      and user-confirmed walkthrough.

## Acceptance

- [x] Flat and `page:offset` forms normalize to byte-identical state for
      every equivalent pair.
- [x] Every malformed operand rejects with the documented selector before
      window validation runs.
- [x] `validateReuWindow`/`validateC64Window` accept/reject exactly the
      documented boundary cases.
- [x] No new VMM API call (`DOS_VMM_READ`/`DOS_VMM_WRITE`); no new private
      zero-page state; BSS growth is exactly 8 bytes.
- [x] DEBUG remains relocatable and inside its existing linker envelope.
- [x] The user confirms the walkthrough before WP5 is marked complete.

## Evidence

DEBUG build 1124: 8,033 code bytes, 959 relocation points — within the
8KB `MAIN` envelope, but headroom is now tight heading into WP6.

VICE matrix (REU enabled, `build/image.d64`, device 8; `XA 0100` = handle
0, 4KB; `XA 1000` = handle 1, 64KB):

- Flat/page equivalence (handle 1): `0000`/`0000:0000` and
  `1000`/`0001:0000`, each with `address=6000 length=0001 R` — all four
  print `XM PREFLIGHT OK`.
- Malformed `page:offset`: `0001:1000`, `0010:0000`, `0001:` — all three
  `ERROR`.
- Allocation-window boundary (handle 0, 4KB): `0000` len `1000` (exact
  fill) -> OK; `0000` len `1001` -> `ERROR`; `0FFF` len `0001` (final
  byte) -> OK; `1000` len `0001` (one past capacity) -> `ERROR`.
- Allocation-window 64KB boundary (handle 1): `000F:0FFF` len `0001`
  (ends exactly at `$10000`) -> OK; len `0002` -> `ERROR`.
- C64-window wrap (handle 0): address `FFFF` len `0002` -> `ERROR`;
  len `0001` (ends exactly at `$10000`) -> OK.
- Direction `X` -> `ERROR`; missing direction -> `ERROR`; trailing
  `EXTRA` -> `ERROR`; zero length -> `ERROR`; handle `9` (out of range)
  -> `ERROR`; `XD 0` then re-querying handle 0 -> `ERROR` (inactive).

WP1 `G`/`T`/`P`/`Q` regression, verified via the checkpoint/register
procedure in [[reference-vice-checkpoint-verification]]: `PC=$6000`
confirmed on `G =6000`; `PC=$6101` confirmed on both `T =6100` and
`P =6100`; `Q` cleaned up the one remaining active allocation and
returned cleanly to `c64[8]:>`.

Static verification: zero `DOS_VMM_READ`/`DOS_VMM_WRITE` call sites; BSS
growth is exactly 8 bytes; `image_d64` and `test_image_d64` both build
clean (`test.d64`'s directory is now down to 6 blocks free — unrelated to
DEBUG's own envelope, a test-disk-capacity note for future work).
