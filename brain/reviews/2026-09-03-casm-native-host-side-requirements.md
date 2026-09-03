---
title: CASM-native apps — remaining host-side requirements and what CASM must gain to retire them
date: 2026-09-03
context: written after the CONWAY migration (4th CASM-native external app)
apps: banner, label, comp, format, conway (dash: manifest only)
---

# CASM-native apps — host-side surface

A "CASM-native" external app (`banner`, `label`, `comp`, `format`,
`conway`; `dash` for its shipping bytes) is **assembled only by the native
CASM assembler running on the C64**. But `cmake --build` still runs a set
of **host-side** steps for each one. This note enumerates that surface and,
per item, what CASM (or the surrounding toolchain) would need to gain to
delete it.

The list is ordered by how much it would take to remove — cheapest first.

---

## 1. `scripts/check_conway_layout.py` — screen-layout invariant checks (CONWAY-specific)

**Why host-side.** The retired ca65 CONWAY carried ~23 `.assert`
directives (`common.inc`, `conway_main.s`, `conway_grid.s`) of the form
`.assert 4 + (menuPreset1End - menuPreset1) <= 40`. Native CASM `.ASSERT`
(Phase 13) is **truthiness-only**: a bare expression, no `=` / `<>` / `<` /
`>` / `<=` / `>=` operators
(`reference-casm-constant-rhs-and-assert-operator-limits`). The invariants
cannot be expressed, so they were reimplemented in a host script wired as a
PRE_BUILD gate.

**What CASM must gain.** Comparison operators in `.ASSERT` (and ideally
`.IF`) — `=`, `<>`, `<`, `>`, `<=`, `>=` — evaluating to 0/1. This is
already listed as a CASM backlog item (`wiki/casm-programmers-reference.md`
"Comparison operators in `.IF` / `.ASSERT`"). With that, every
`check_conway_layout.py` line becomes an in-source `.ASSERT`, and the
script is deleted. **Small, well-scoped CASM change.**

Note this also needs `.ASSERT` to accept `labelEnd - label` sub-expressions
(it already accepts label arithmetic in `.RES`/`.FILL`/`.ALIGN` operands,
so this is mostly free).

---

## 2. `scripts/check_casm_source_bytes.py` — reject non-PETSCII host bytes

**Why host-side.** Sources are written to the `.d64` by `cc1541 -w`, which
copies host bytes verbatim with **no character-set translation**. The host
file is ASCII; CASM's lexer reads PETSCII and rejects ASCII lowercase
`$61-$7A` (a PETSCII graphics-character block) with
`CASM_DIAG_INVALID_SOURCE_BYTE`. The script enforces "all-uppercase ASCII
source, no case-colliding identifiers" before packaging so the failure
surfaces on the host, not as a confusing C64-side diagnostic.

**What would remove it** (either is sufficient):

- **cc1541 gains an ASCII→PETSCII `-w` mode** for text files (a packaging
  change, not a CASM change). Cleanest — the source could then be written
  in natural mixed case.
- **CASM's lexer accepts ASCII lowercase as letters** outside string
  literals (it already accepts them *inside* `"…"` / `'.'` literals —
  `reference-casm-lowercase-in-string-literals`). This is a host↔target
  encoding reconciliation and interacts with identifier case-sensitivity,
  so it is the larger of the two.

Even with one of these, an identifier-collision check is still worth
keeping, but it stops being load-bearing.

---

## 3. `scripts/gen_conway_menu.py` — screen-code text data (CONWAY-specific)

**Why host-side.** CONWAY's menu / status strings are written straight into
screen RAM (`$0400`), so they must be **C64 screen codes**, not PETSCII.
The retired ca65 build used `.CHARMAP` + `.MACRO` + `.REPEAT`
(`include/ca65/screencode.inc`) to remap the ASCII source. CASM has **no
`.CHARMAP` / `.ENCODING` / `.MACRO` / `.REPEAT`**, and its string literals
emit raw bytes. The generator applies the exact transform (`$20-$3F`
identity, `$61-$7A → −$60`) and emits explicit `.BYTE` lines.

**What CASM must gain.** A character-map / encoding facility —
minimally a `.CHARMAP <from>, <to>` directive with push/pop scope, so a
`screencode` block could be opened and `.BYTE "conway multiverse"` would
emit screen codes. (ca65's `.CHARMAP` + `.PUSHCHARMAP` / `.POPCHARMAP` is
the reference design.) Then `conwaymenu.s` collapses back into
`conway.s`'s data section and the generator is deleted.

This same facility would also let `gen_*_version.py` (item 4) stop
hand-hexing the shifted app-name glyph.

---

## 4. `scripts/gen_*_version.py` — version-banner source (all CASM-native apps)

**Why host-side.** Two reasons combined:

1. **String substitution.** The retired builds did
   `.byte "APP v", VERSION_MAJOR, ".", …, BUILD_NUMBER` where
   `VERSION_MAJOR` etc. were ca65 `.define` text macros fed from
   checked-in version files + a generated `build_<app>.inc`. **CASM has no
   `.define` / text substitution**, so the concatenated banner string is
   assembled on the host from `<APP>_VERSION` + `BUILD_<APP>`.
2. **Shifted-PETSCII glyph control.** The banners render the app name as an
   *uppercase* glyph (`FORMAT`, `CONWAY`) which on Command 64's mixed-case
   charset means *shifted* PETSCII `$C1-$DA`. Native CASM emits *unshifted*
   `$41-$5A`. So the generator hand-emits the app name as reviewed shifted
   hex bytes.

**What CASM must gain** (both needed to delete the generator):

- **Build-metadata / text substitution** — either a `.define`-style text
  macro, or a way to `.INCLUDE` a tiny generated equate file and build the
  string from digit constants. A minimal `.STRINGIFY(number)` +
  string-concatenation in `.BYTE` operands would do it.
- **Charmap/encoding (item 3)** — so `.BYTE "CONWAY"` in a `shifted` block
  emits `$C3 $CF …` without hand-hex.

Until both exist, a ~40-line generator per app is the pragmatic answer.
(The version *counter* management — `BUILD_<APP>` as a hand-bumped plain
file — is deliberate and stays regardless: a version bump must force a
reviewed manifest regeneration.)

---

## 5. `/O:@:NAME`, no-underscore `.INCLUDE` names, ≤255-char lines — CASM papercuts

Not host *scripts*, but host-side *workarounds* baked into the sources and
the docs:

| Workaround | CASM fix that retires it |
| --- | --- |
| Output name written `/O:@:CNW.PRG` (DOS replace prefix) so a re-run overwrites | `fileCreateOutput` should replace an existing output (or clearly diagnose), not `CASM: OUTPUT WRITE FAILED` / KERNAL-IEC-retry hang (`project-casm-filecreateoutput-no-replace`) |
| `.INCLUDE`d SEQ files must have **no `_`** (`conwaygrid.s`, not `conway_grid.s`) — `cc1541 -f` stores `_` as PETSCII `$A4`, CASM's lookup compares ASCII `$5F` | CASM's `.INCLUDE` filename match should fold `$5F`/`$A4` (and case, which it already does), or accept the PETSCII underscore |
| Generated `.BYTE` data wrapped at ≤12 bytes/line | `CasmSourceColumn` is an 8-bit counter → `CASM: SOURCE LOCATION OVERFLOW` past 255. Widen the counter (16-bit) or raise `SOURCE LINE TOO LONG` gracefully and keep parsing |
| **All named constants inline in the entry file** (never in an `.INCLUDE`) | An `.INCLUDE`d named constant is mishandled: ZP-valued → 3-byte absolute; **any** value → a spurious R6 relocation entry on every referencing operand, immediates included (`project-casm-included-constant-zp-absolute`, Taskwarrior 42). Fix constant resolution to respect the `.INCLUDE` boundary the same as inline. |

These are bug-fix scope, not feature scope.

---

## 6. `scripts/hex_manifest_to_bin.py` + `<app>.ref.hex` + `scripts/build_<app>_manifest.py` — the manifest model

**Why host-side.** This is the load-bearing one. **CASM has no host
build** — it is itself a C64 program (assembled by ca65 for now). Nothing
on the host can assemble `conway.s`, so `cmake --build` cannot produce
`conway.prg` directly. Instead the shipping bytes live in a **human-
reviewed hex manifest** that `hex_manifest_to_bin.py` (which contains no
6502 knowledge) transcribes back to a PRG, guarded by `source_sha256`
lines so a source edit without a reviewed manifest regeneration is a hard
build failure. `build_<app>_manifest.py` does the reviewed transcription
(a deliberate human act, never a build step).

**What must exist to remove it.** A **host build of CASM** — CASM compiled
and runnable as a host tool (a 6502 emulator wrapper around the same
`casm.prg`, or a genuine host port). Then `cmake` runs
`casm conway.s -o conway.prg` on the host like ca65, the manifest and its
two transcription scripts are deleted, and `command64_<app>_test_d64`
becomes an ordinary "does it still assemble on real hardware" smoke test
rather than the source of truth.

This is a significant piece of work and is **the** thing that would
collapse most of this list: with a host CASM,

- item 6 (manifest model) is gone;
- items 1–4 remain only as *conveniences* — their absence would just make
  the source uglier, not un-shippable;
- the `casm_r6_verify.py` / independent-ca65-differential checks (below)
  stay, because self-validation is still not allowed.

---

## 7. `scripts/casm_r6_verify.py` + independent ca65 `$3400` differential — the oracle

**Why host-side, and why it stays.** `conway-derivation.md`'s correctness
claim rests on (a) `casm_r6_verify.py` checking the R6 table structurally
against the image, and (b) a one-time independent ca65/ld65 build of the
same sources at `$3400` showing a 0-byte diff. These are **oracle-
independence** measures: a defect in CASM's own opcode table must not be
able to certify itself (`.agents/workflows/canonical-byte-oracles.md`).

Even a host CASM does **not** remove these — you would still want an
independent second assembler (ca65) and an independent relocation checker.
What a host CASM removes is the *manifest* as the shipping mechanism, not
the *derivation* as the correctness argument.

`scripts/casm_oracle_inventory.py` (the reconciliation check) likewise
stays as a repo-hygiene gate.

---

## Summary table

| Host-side item | Scope to remove | Blocker |
| --- | --- | --- |
| `check_conway_layout.py` | Small CASM feature | `.ASSERT` comparison operators |
| `check_casm_source_bytes.py` | Small toolchain change | cc1541 ASCII→PETSCII `-w`, or CASM lowercase letters |
| `gen_conway_menu.py` | Medium CASM feature | `.CHARMAP` / encoding scopes |
| `gen_*_version.py` | Medium CASM feature | text substitution **+** `.CHARMAP` |
| `/O:@:` + `_` + 255-char + inline-consts | CASM bug fixes | 4 enumerated defects |
| **manifest model** (`hex_manifest_to_bin.py`, `*.ref.hex`, `build_*_manifest.py`) | **Large** | **a host build of CASM** |
| `casm_r6_verify.py` + ca65 differential + `casm_oracle_inventory.py` | — | stays regardless (oracle independence) |

**Bottom line:** four small-to-medium CASM features (`.ASSERT` operators,
`.CHARMAP`, text substitution) plus four bug fixes would let a CASM-native
app be a **single hand-written `.s` file with no generators**. Getting rid
of the **manifest** — and making `cmake --build` assemble it directly —
needs a **host build of CASM**, which is the real prerequisite for
retiring ca65/ld65 as the host toolchain entirely.
