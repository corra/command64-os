# Independent Derivation Record: DASH

**Target:** `src/external/dash/dash.ref.hex` → `DASH.PRG` (`0.2.0`)
**Base:** `$3400` · **Bytes:** 4,579 · **SHA-256:**
`3b4d0693a6413e7e7d328f18276b6beae3d5cbecccbe7578cfe9a13504121984`

> **Corrected 2026-09-02 (WP4 audit).** The original WP4 record claimed a
> full independent byte derivation it did not perform and promoted
> `dash.ref.hex` to `CANONICAL-INDEPENDENT` on that basis. This is not
> achievable for a 3,669-byte, seven-file program and the claim is
> withdrawn. What this record actually establishes, honestly:
>
> | evidence | provenance state |
> | --- | --- |
> | the 3,669 code/data bytes | **`NATIVE-OBSERVATION`** — a reviewed native CASM run, corroborated by the ca65 differential (`DIFFERENTIAL-ONLY`) |
> | the R6 relocation table + footer (451 entries) | **`CANONICAL-INDEPENDENT`** — derived below, assembler-independent, reproducible |
>
> `dash.ref.hex`'s overall provenance state is therefore **`NATIVE-OBSERVATION`**
> (per the WP1 rule that a manifest is only `CANONICAL-INDEPENDENT` when its
> *bytes* are independently derived). See the audit register.

## Sources (SHA-256, checked into `src/external/dash/`)

`dmain.s` `a8cab310…` · `dscr.s` `eb813bf4…` · `dfmt.s` `bc8925de…` ·
`dsys.s` `29992b8b…` · `dapp.s` `f5953f8d…` · `dvmm.s` `5144b367…` ·
`ddata.s` `8c7a4498…` — all recorded as `source_sha256` in the manifest;
`hex_manifest_to_bin.py` hard-fails the build if any drifts.

## 1. Code/data bytes — `NATIVE-OBSERVATION` (not independently derived)

A byte-by-byte independent derivation of DASH's 3,669 code/data bytes is
not practical (7 source files, ~50 routines, full data tables) and was not
done. The byte provenance is:

- **Reviewed native CASM run** — `CASM DMAIN.S /O:DW6.PRG` under VICE
  (CASM `0.5.2` build `1404`, 16 MB REU), `command64_casm_utils.d64`,
  2026-09-01, DASH-MOD WP6 consolidated gate. Byte count 4,579, SHA-256
  `3b4d0693…`.
- **ca65 differential (`DIFFERENTIAL-ONLY`)** — the `dash_ref` ca65 build
  reproduces `DASH.PRG` **byte-for-byte** (`3b4d0693…`), re-confirmed
  2026-09-02. ca65 and CASM share no source and derive relocation entries
  by unrelated means (`tools/reloc.py` diffs two links a page apart vs
  CASM's per-operand classification), so a defect in one is very unlikely
  to reproduce in the other. This is corroboration, not an independent
  oracle.
- **Runtime evidence** — DASH-MOD verified the running program at bases
  `$3800`, `$5000`, `$9000` (see `project-dash-modernization-complete`).
- **Stale-artifact guard** — the seven `source_sha256` entries.

**Caveat:** the native run is CASM `0.5.2` b1404; current CASM is `0.6.2`.
No CASM change since then affects assembled output (the `0.6.2` diagnostic
patch is header-comment/diagnostic-text only), but a fresh native `COMP`
under `0.6.2` on a disk with directory headroom would strengthen this.
Recommended as a WP6 consolidated-gate item.

## 2. R6 relocation table + footer — `CANONICAL-INDEPENDENT`

Derived from the Command 64 R6 format and the 4,579 manifest bytes alone —
no CASM code, no `opcodes.s`, no ca65. Reproducible by
`scripts/casm_r6_verify.py` (added with this correction) or inline:

```python
body = <manifest hex body>            # 4579 bytes
assert body[-2:] == b'R6'
count = int.from_bytes(body[-4:-2], 'little')   # 451
base  = int.from_bytes(body[-6:-4], 'little')   # 0x3400
tbl_end   = len(body) - 6
tbl_start = tbl_end - 2*count                   # file offset 3671
offs = [int.from_bytes(body[tbl_start+2*i:tbl_start+2*i+2], 'little')
        for i in range(count)]
prog = body[2:tbl_start]                        # 3669-byte program image
```

### Verified facts

| property | value | check |
| --- | --- | --- |
| footer magic | `52 36` (`"R6"`) | ✔ |
| footer base | `00 34` = `$3400` | ✔ (matches load header) |
| footer count | `C3 01` = **451** | ✔ (table is exactly `451 × 2 = 902` bytes) |
| program image | 3,669 bytes, `$3400`–`$4254` (pages `$34`–`$42`) | ✔ |
| table file offset | 3671–4572 | ✔ |
| entry offsets | min `$0005`, max `$09F1` | ✔ |
| ordering | **strictly ascending, all 451 unique** | ✔ |
| **every entry validity** | the byte at each listed offset is a page number in `$34`–`$41` — i.e. every entry points at the high byte of a 16-bit address inside the program image | ✔ **all 451** |
| distinct high-byte values touched | `$34 $35 $36 $37 $38 $39 $3A $3B $3C $3D $3E $3F $40 $41` | ✔ (spans the program's own pages, as expected for internal absolute references) |

### Eligibility model (what earns a relocation entry)

An entry is recorded for the **high byte** of any absolute 16-bit operand
whose value resolves inside the program image (`JSR`/`JMP` to an internal
routine, `LDA`/`STA`/… absolute to an internal variable or table, `#>LABEL`
immediate high-byte extraction of an internal label). Excluded (no entry):
zero-page operands (DASH private scratch `$70-$8F`, plus system ZP),
hardware/KERNAL addresses (`$D000-$DFFF`, `$FF00-$FFFF`, screen `$0400`,
color `$D800`), the `OS_API` vector `$1000`, immediate 8-bit constants and
low-byte extractions (`#<LABEL`), and relative branch displacements. The
14 distinct high-byte values touched (`$34`–`$41`) being exactly the
program's own page span, with **zero** entries pointing outside it, is
consistent with this model — an entry that pointed at `$D0`, `$FF`, `$10`,
etc. would be a defect and none exists.

### Multi-base application check

Applying a page delta to the byte at each of the 451 offsets:

| target base | delta | all 451 relocated high bytes land in | result |
| --- | --- | --- | --- |
| `$3800` | `+4` | `$38`–`$46` | ✔ |
| `$5000` | `+28` | `$50`–`$5E` | ✔ |
| `$9000` | `+92` | `$90`–`$9E` | ✔ |

Each relocated high byte = `original + delta`, contiguous with the
relocated program extent, no wrap, no stray page. Matches DASH-MOD's
observed runtime behavior at the same bases.

## 3. Disposition

- `dash.ref.hex` → audit register state **`NATIVE-OBSERVATION`**.
- The R6 relocation ledger above is `CANONICAL-INDEPENDENT` and is linked
  from the manifest.
- The `dash_ref` ca65 differential is retained as a **standing release
  verification** (see `src/external/dash/AGENTS.md` / WP5) — while DASH
  source stays in the shared subset it is the primary independent
  corroboration of the code bytes, so the release/utility-disk build
  process runs it even though it is `EXCLUDE_FROM_ALL` for ordinary
  developer builds.
- If DASH later adopts CASM-only syntax and `dash_ref` stops building,
  that WP records the loss of this corroboration explicitly and DASH's
  code bytes rest on the reviewed native run + fresh `COMP` alone.

## Reviewer

Independent relocation derivation authored 2026-09-02; frozen for user
review as the WP4 audit correction.
