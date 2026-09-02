# Walkthrough: CASM Phase 14 WP90 - /M @local Rendering + /L Non-Regression

Plan: `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`
Taskwarrior: WP90 `f7010987-a1b3-4f97-8f07-439a496504db`
Branch: `feature/casm-phase14`

## What this WP delivers (`map.s`)

### @local qualified-name rendering

- `mapPrint`'s definition-order walk now tracks the most recent global
  label seen (`CasmMapOwnerName`/`Len`) and a running global count
  (`CasmMapGlobalCountLo/Hi`). Records iterate in insert == source order,
  and a `@local` is always inserted while its scope's global is current
  with no other global between them, so the last global seen IS the
  owner.
- `mapFormatRow` renders a `@local` record's row as
  `"<owner>@<local>"` -- `CasmMapOwnerName` followed by the local's own
  stored name (which already begins with `@`). The combined name is
  capped at `CASM_MAP_NAME_MAX` (31) bytes -- truncated, not wrapped --
  so a row stays within the 40-column screen and the 40-byte
  `CasmMapRowBuf`, the same ceiling the pre-WP90 31-byte Name slot
  imposed.
- `mapPrint` cross-checks each `@local` record's stored `SCOPE` ordinal
  (`CASM_SYMBOL_REC_SCOPE_LO/HI`, WP89) against the walk: it must equal
  `CasmMapGlobalCount - 1`, and an owner must already exist. A mismatch
  means the pass driver's Pass 1 and Pass 2 scope tracking disagreed ->
  `CASM_DIAG_SYMBOL_MAP_INVALID` rather than a silently-wrong map.

### mapValidateRecord rebuilt for the real record layout

The old "reserved bytes 37-63 must all be zero" check predated WP65/76/86
and never caught up. It now validates by field:

| offsets | rule |
| --- | --- |
| 37-43  `REF_*` | zero always |
| 44-45  `DEFINED_AT` | any value for a `CONSTANT` record, zero otherwise |
| 46-47  `SCOPE` | any value for a `LOCAL` record, zero otherwise |
| 48-63  reserved | zero always |

Flags allowlist gains `DEFINED|LOCAL`.

**Folded-in latent fix (user-approved):** before this, offsets 44-45
(`DEFINED_AT_OFFSET`, WP76 -- the constant's own source position, left
populated by `casmResolveConstants`) were checked as reserved, so
**every named constant defined past file offset 0 tripped `SYMBOL MAP
INVALID` when assembled with `/M`**. `/M` was last production-tested in
Phase 10 (WP54), before constants existed, so no test caught it. WP90's
per-field check makes 44-45 valid for constants while keeping 37-43 (the
REF_* bookmark, which resolution *does* zero) strict.

## Testing

### `test_casm_map` unit harness (25 cases, was 23) -- live `CASM MAP: PASS`

- `mapreservedflags1` updated: bit `$10` (LOCAL) is no longer a reserved
  bit, skipped here and covered positively below.
- `maplocalqualified1` (new): fresh table, global `MAIN` + `@local`
  `@LOOP` scoped to ordinal 0. Verifies the row captures as
  `$C001 MAIN@LOOP`, `mapPrint` succeeds, and breaking the local's SCOPE
  ordinal makes `mapPrint` return `SYMBOL_MAP_INVALID`.
- `mapconstdefinedat1` (new): a record poked to
  `DEFINED|CONSTANT|RESOLVED` with `DEFINED_AT` = `$1A` validates
  (WP90's folded fix); adding a nonzero `REF_VMM_LO` (offset 37) on top
  still trips `SYMBOL_MAP_INVALID` (37-43 stay strict for constants).
- Harness MAIN bumped `$1400` -> `$1600` (299-byte overflow from the two
  new cases).

### Production fixtures on `casm_phase14_test.d64` -- live on `CASM V0.5.2.1403`

- `casmmaploc` (`.ORG $C000`, `MAIN:`/`@LOOP:` and `DRAW:`/`@DONE:`):
  `casm casmmaploc.s /m` -> screen:
  ```
  SYMBOL MAP
  $C000 MAIN
  $C000 MAIN@LOOP
  $C003 DRAW
  $C003 DRAW@DONE
  004 SYMBOLS
  ```
  `/M` and `/L` PRGs both `FILES COMPARE OK` against the no-options
  baseline (`/M`/`/L` are screen/`.LST` only, never touch the PRG).
- `casmmapconst` (`START:` / `FOO = 5` / `LDA #FOO` -- constant at a
  nonzero source offset): `casm casmmapconst.s /m` -> screen shows
  `$C000 START` / `$0005 FOO` / `002 SYMBOLS`, **not** `SYMBOL MAP
  INVALID`. End-to-end proof of the folded-in fix.

### /L

`casmmaploc` assembled `/L` -> PRG byte-identical to its no-options
baseline: `/L` with `@local` labels is value-only, no assembled-output
change. A dedicated no-locals `/L`-vs-Phase-13 COMP (casm_phase10's
existing `casmemit1` `/M`/`/L`/`/M /L` matrix) is left for WP92's
consolidated re-verification.

## Build evidence

```
reloc.py: .../build/casm.prg: base=0x3800, 24392 code bytes, 3997 relocation points
OK: all 90 diagnostic identifiers + 2 extras render exactly the frozen text
```

`casm.prg` +190 code bytes over WP89+hardening (24202 -> 24392); MAIN
headroom ~2055 bytes. `image_d64`, `test_image_d64`,
`casm_phase14_test_d64`, `casm_listing_test_d64`, `test_casm_map` all
rebuilt clean.

## Overlay events

Fired via curl (the `c64-overlay-api` MCP is still down this session):
`test`/`testing` + `test`/`pass` for `test_casm_map` and
`casm-phase14-wp90`.

## Sign-off requested

WP90 is source-complete and live-verified: `test_casm_map` 25/25,
`/M` renders locals qualified end to end, the folded-in constant fix
works end to end, `/M` and `/L` leave the PRG byte-identical. Requesting
approval to close WP90 and proceed to WP91 (DASH adoption of `@local`).
