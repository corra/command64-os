---
title: FORMAT → CASM-native migration — completion-gate walkthrough
date: 2026-09-02
plan: brain/plans/2026-09-02-format-casm-native-migration.md
taskwarrior: 1c11e31a-be94-49b2-bc49-d511f7bef45d (project format)
status: complete — user-approved 2026-09-02
---

# FORMAT CASM-native Migration — Walkthrough

Live evidence for the Completion Gate of
`brain/plans/2026-09-02-format-casm-native-migration.md`. Observed results
only.

## What shipped

- `src/external/format/format.s` — self-contained native CASM: constants
  inline (`command64.inc` + `common.inc` dropped), `@local` routine-internal
  labels, `.RES` storage, char-literal comparisons (`#$3A` for the illegal
  `'9'+1`, no-paren `#DEV_MAX+1` addends), all 18 messages as
  **uppercase-ASCII** `.BYTE "…"` string literals (render lowercase — see
  below), `LITNCOLON: .BYTE $3A,$4E,$3A,$00` / `LITCOMMA: .BYTE $2C,$00`.
- `src/external/format/FORMAT_VERSION` (`0.1.0`) + `scripts/gen_format_version.py`
  → build-time `formatver.s`.
- `src/external/format/format.ref.hex` + `scripts/build_format_manifest.py`
  + `src/external/format/format-derivation.md`.
- `CMakeLists.txt` — `add_ca65_app(format …)` removed; manifest-derived
  `format` target + `format_version_src` + `command64_format_test_d64`;
  `format.ref.hex` in `casm_oracle_inventory.py` `NATIVE_MANIFESTS`.
- `wiki/format-utility.md` (new, synced to `docs/`), `wiki/tasks/format.md`,
  `CHANGELOG.md`, `brain/KNOWLEDGE.md`, byte-oracle audit register,
  `brain/task.md`.

## Two Scoping-Decision corrections from live evidence

1. **Decision 2 — the shipped ca65 FORMAT is NOT broken.**
   `build/format.prg` (ca65, shifted `$CE` in `:N:`) run against a scratch
   device-9 `.d64`: reached the confirm gate, accepted `Y` + name re-type,
   sent the command, drive returned `RESULT: 00, OK,00,00`. Detached: BAM
   name `ORIGINALNAME` → `NEWVOL`, id `5A` → `42`, directory emptied. **The
   1541 (VICE) accepts the shifted `$CE`.** So `$CE`→`$4E` is a
   canonical-byte cleanup, not a fix — behaviour unchanged.
2. **Decision 1 direction — lowercase on screen comes from UPPERCASE-ASCII
   source.** KERNAL CHROUT maps PETSCII `$41-$5A` → screen `$01-$1A`
   (display lowercase) and `$61-$7A` → screen `$41-$5A` (display
   UPPERCASE). Writing the messages as literal lowercase (first attempt)
   assembled fine but rendered uppercase — no change. Fixed: messages are
   uppercase-ASCII string literals (like LABEL) → render lowercase.

## Assembly + byte identity

Native CASM **0.6.2 build 1419** under VICE 3.10 (16 MB REU),
`CASM FORMAT.S /O:FMT.PRG`:

```
P1: DONE 00615 STATEMENTS
P2: DONE 00615 STATEMENTS
DONE: P1 00615, P2 00615, 01865 BYTES
CASM: INPUT VALIDATED
```

Extracted `FMT.PRG` (repackaged as `format` for dispatch — same SHA-256).
SHA-256 `2a5bb43174fb3e3834a57b54f86dcce1ded108d972c152f2481f1ceff8affadf`.

**Independent reference:** ca65 `-t c64` build, linked at `$3400`, of a
mechanically-transformed copy of the final `format.s` (every `.BYTE "…"` →
explicit unshifted hex, `@`-prefixes stripped, `.RES`→`.res`, ca65 header
segment). `format_ref3400.prg`, 1541 B, SHA-256 `8588fc31…`. ca65 and CASM
share no code.

**Host diff, program image `$3400..$3A02` (1539 bytes): 0 differences.**
+ 324 B R6 table + `52 36` footer.

## R6 relocation

`scripts/casm_r6_verify.py` on `FMT.PRG`:

```
footer: base $3400  count 159  magic 'R6'
program image 1539 bytes  $3400..$3A02
relocation table 318 bytes at file offset 1541..1858
offsets strictly ascending and unique   range $0003..$03B9
all 159 entries point at an in-image high byte (pages $34..$3A)
relocate to $3800 / $5000 / $9000: every high byte in range
R6 VERIFY: PASS
```

Independent eligibility reconciliation: **131 three-byte absolute operands +
28 `#>label` high-byte immediates = 159, exactly CASM's count**; 0 entries
for fixed addresses (`$1000` / `$FFxx` / `$033C`) or `#<label` low bytes.

## Live COMP

`command64_format_test.d64` on device 8, `CASM FORMAT.S /O:FMT.PRG` then:

```
comp fmt.prg format.ref
FILES COMPARE OK
```

Overlay `test`/`pass` event fired.

## Functional sweep (CASM-native `format`, dispatched by name)

| Invocation | Observed |
| --- | --- |
| any run | banner `FORMAT v0.1.0.1013` (uppercase `FORMAT` glyph, lowercase `v`) |
| `FORMAT 9:X,4` (id 1 char) | `error: id must be exactly 2 chars.` — **lowercase** — clean return |
| `FORMAT` (no args) | interactive `device (8-11): ` prompt (lowercase) |
| device `99` at prompt | `invalid, try again.` reprompt |
| device `8` / name / id, then `N` at confirm | `format cancelled.` — no drive I/O |
| `FORMAT 9:REALNAME,42` → `Y` → re-type `WRONGNAME` | `name mismatch. format cancelled.` — device-9 disk (`KEEPME`) untouched, 1 file intact |
| `FORMAT 9:REFORMATTED,AB` → `Y` → re-type `REFORMATTED` | `formatting...` → `result: 00, ok,00,00`; detached device 9: BAM name `PREFORMAT` → `REFORMATTED`, id `11` → `AB`, directory emptied |
| every run | clean return to `C64[8]:>` |

All messages render lowercase; the banner keeps `FORMAT` uppercase. Not
exercised: the `sfcTransportErr` path and DEL editing inside `readLine`
(byte-identical to LABEL's proven `readLoop`) — non-critical.

## Build verification

- Fresh `rm -rf build && cmake -B build`: **no warnings or errors.**
- Full `cmake --build build`: **all targets build.** `build/format.prg`
  SHA-256 == the manifest. `image.d64` carries `FORMAT` (position 4);
  `test_image_d64` builds.
- **No-change rebuild:** `format.prg`, `image.d64`,
  `command64_format_test.d64` byte-identical.
- **Stale-source gate:** appending a comment to `format.s` → hard build
  failure (`hex_manifest_to_bin.py: source file 'format.s' has changed`);
  revert → clean.
- `scripts/casm_oracle_inventory.py`: `reconciliation: OK`, **5 native
  manifests** (dash/banner/label/comp/format), 72/72 declared sha256.
- No `add_ca65_app` / `__MAIN_START__` / `command64.inc` / `build_format.inc`
  reference to FORMAT anywhere.

## Parallel-work note

The COMP CASM-native migration (a separate effort) merged to `main`
(`877019b`) while this FORMAT work was in progress. No conflict — COMP and
FORMAT touch disjoint files apart from adjacent additive blocks in
`CMakeLists.txt` / `casm_oracle_inventory.py`. This FORMAT branch builds on
top of the COMP merge.

## Reviewer sign-off

- [x] `src/external/format/format-derivation.md` independent-reviewer line —
  user, 2026-09-02 (0-difference agreement, three enumerated design
  changes, 159-entry R6 ledger).
- [x] Completion-gate approval — user, 2026-09-02. FORMAT Taskwarrior task
  closed. Provenance state for `format.ref.hex`: **`CANONICAL-INDEPENDENT`**.
