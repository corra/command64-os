---
title: FORMAT — independent byte + R6 relocation derivation record
date: 2026-09-02
status: reviewed and approved (user, 2026-09-02)
oracle-class: Native application manifest (+ R6 PRG)
manifest: src/external/format/format.ref.hex
plan: brain/plans/2026-09-02-format-casm-native-migration.md
---

# FORMAT — Canonical Byte / R6 Derivation

Per `.agents/workflows/canonical-byte-oracles.md`. This record is the
correctness oracle for `src/external/format/format.ref.hex`; the manifest
itself is only the shipped artifact + stale-source guard.

## Artifact under derivation

- Native CASM output `FMT.PRG`, **1865 bytes**, load `$3400`.
- SHA-256 `2a5bb43174fb3e3834a57b54f86dcce1ded108d972c152f2481f1ceff8affadf`.
- Produced by native CASM `0.6.2` build `1419` on Command 64 under VICE
  3.10 (16 MB REU), `CASM FORMAT.S /O:FMT.PRG` from the SEQ sources on the
  dedicated assembly disk; extracted with `cc1541 -X`.
- `P1 DONE 00615`, `P2 DONE 00615`, `01865 BYTES`, `CASM: INPUT VALIDATED`.
  Program image `$3400..$3A02` (1539 bytes) + 318-byte R6 table + footer.

## Source identity (all under `src/external/format/`)

| File | Role | SHA-256 |
| --- | --- | --- |
| `format.s` | assembled source (constants inline) | `d8fe3f72f699d90e77f03de52336463f39797fdede66ec580481c36c420dbf49` |
| `FORMAT_VERSION` | app version `0.1.0` → generated `formatver.s` | `e9dd8507f4bf0c6f42458e41aea833ad0bd3f6127272335eee9bf4d58541ed67` |
| `BUILD_FORMAT` | build counter `1013` → generated `formatver.s` | `8baa1b3bd0832f4996421c7bfe10bc49f6e1560923bf15fb4b1ab6c13fdeda94` |
| `formatver.s` (generated, not checked in) | `FORMATVERMSG` data | `18dad7930e6e29bddcd62088cc7fc6281ff9fd5decf06a00b2c8312ab3204d5a` |

## Independent code/data byte derivation

The full opcode/operand byte stream is derived independently of CASM by an
**independent ca65/ld65 assembly of a mechanically-transformed copy of the
final `format.s`, linked at the same `$3400` base**. The transform (a
scriptable, line-by-line-reviewable pass):

- every `.BYTE "…"` string literal → explicit unshifted hex `.byte $xx,…`
  (`ord(c)` — the identity map for the `$20-$5A` characters FORMAT's
  messages use; this makes the reference emit the same unshifted bytes
  native CASM does, instead of ca65 `-t c64`'s shifted `$C1-$DA`);
- `@`-prefixes stripped from every local label (CASM `@local` is
  documented byte-identical to a plain label);
- `.RES` → `.res`; ca65 `HEADER`/`CODE` segment scaffolding + `.import
  __MAIN_START__` prepended.

ca65 and CASM share no code and select opcodes / addressing modes / branch
displacements by entirely different means, so an agreement on the resulting
byte stream is genuine independent corroboration. Reference artifact:
`format_ref3400.prg`, 1541 bytes, SHA-256
`8588fc3121168b5f29c60847c4b0c719d1cef26f8de5c4a886252de3f117ea6a`
(program image `$3400..$3A02`, no R6 footer — ld65 does not emit one).

**Result of the byte comparison (program image, `$3400..$3A02`, 1539
bytes): 0 differences.** The CASM-native image is byte-identical to the
independent ca65 build.

### Enumerated intentional changes from the retired ca65 `format.prg`

Both are *design changes*, not defects, and both are already baked into the
transformed reference above (so they do not appear in the 0-diff result):

1. **Message on-screen case: uppercase → lowercase.** The old build wrote
   the message text as `.byte "FORMAT DRIVE"` which ca65 `-t c64` remapped
   to *shifted* PETSCII (`$C6 …`), rendering UPPERCASE. The CASM-native
   build's `.BYTE "FORMAT DRIVE"` emits *unshifted* PETSCII (`$46 …`);
   KERNAL CHROUT maps `$41-$5A` → screen `$01-$1A`, which display
   lowercase. Scoping Decision 1; verified live.
2. **`:N:` command literal: `$CE` → `$4E`.** `litNColon: .byte ":N:"`
   assembled under ca65 to `$3A $CE $3A` (shifted `N`). `LITNCOLON` is
   `.BYTE $3A,$4E,$3A,$00` (the canonical NEW-command byte). **This does
   not change behaviour** — VICE's 1541 accepts the shifted `$CE` and the
   old build formats disks correctly (verified live). It is a
   canonical-byte cleanup per the canonical-byte-oracle guidance for
   protocol payloads. Scoping Decision 2 (wording corrected 2026-09-02).

3. **Version banner.** `.byte "FORMAT V", VERSION_MAJOR, …` → generated
   `FORMATVERMSG`: `.BYTE $C6,$CF,$D2,$CD,$C1,$D4,$20,$56` (shifted
   `FORMAT` so the app name keeps an uppercase glyph) + `.BYTE
   "0.1.0.1013", $0D, $00`. Renders `FORMAT v0.1.0.1013` (DEBUG format,
   lowercase `v`). The `$D6`→`$56` `V`→`v` is the LABEL-style banner
   change.

## R6 relocation ledger (independent)

`scripts/casm_r6_verify.py` on `FMT.PRG` (reads only the bytes + the
documented R6 format):

```
footer: base $3400  count 159  magic 'R6'
program image 1539 bytes  $3400..$3A02
relocation table 318 bytes (159 entries × 2-byte LE offset) at file offset 1541..1858
offsets strictly ascending and unique   range $0003..$03B9
all 159 entries point at an in-image high byte (pages $34..$3A)
relocate to $3800 / $5000 / $9000: every high byte lands in range
R6 VERIFY: PASS
```

**Independent eligibility reconciliation.** Disassembling the 1539-byte
image and classifying every operand against the R6 rules:

- **131 three-byte absolute operands** target in-image addresses
  (`JMP`/`JSR` to FORMAT's own routines, `LDA`/`STA` absolute and
  absolute-indexed against the message table / `CMDBUF` / `NAMEBUF` /
  `IDBUF` / `DEVDIGITS` / `RESPBUF` and the small `.RES` scalars).
- **28 `#>label` high-byte immediates** (`LDY #>MSG…`, `LDY #>FORMATVERMSG`,
  `LDY #>DEVDIGITS`, `LDY #>LINEBUF`/`NAMEBUF`/`IDBUF`/`CONFIRMBUF`/
  `CMDBUF`/`RESPBUF`/`LITNCOLON`/`LITCOMMA`) — high byte in an in-image
  page, so relocation-eligible.
- **= 159 entries — exactly CASM's count.** 0 unclassified.
- **Zero** entries for fixed addresses: `OS_API` (`$1000`), `KERNAL*`
  (`$FFxx`), `COMMANDBUFFER` (`$033C`), and every `#immediate` numeric
  literal / `#<label` low byte (CASM clears `RELOCATABLE` for `<`).

Matches the BANNER/DASH/LABEL R6 precedent.

## Live native comparison

See `brain/walkthroughs/2026-09-02-format-casm-native-migration.md` for the
`COMP FMT.PRG FORMAT.REF` run, the old-build baseline, the end-to-end
scratch-disk format, the functional path sweep, `CASM` version/build, and
the R6 multi-base runtime evidence.

## Provenance state

`CANONICAL-INDEPENDENT` for both the code/data byte stream (independent ca65
differential corroboration of **all 1539 image bytes**, with the three
design changes enumerated and pre-applied to the reference) and the R6
relocation ledger (assembler-independent structural verification +
independent eligibility reconciliation to the exact 159-entry count).

## Independent reviewer sign-off

- Reviewer: the user (independent reviewer, per the WP60 precedent recorded
  in `brain/KNOWLEDGE.md`).
- Date: 2026-09-02.
- Reconciled: load address `$3400`, 1865-byte count, artifact SHA-256
  `2a5bb431…`, the 0-difference agreement with the independent ca65 `$3400`
  build, the three enumerated design changes (message case, `:N:`
  `$CE`→`$4E`, banner `V`→`v`), and the 159-entry R6 relocation ledger
  (131 absolute operands + 28 `#>` high-byte immediates; `casm_r6_verify.py`
  PASS at `$3800`/`$5000`/`$9000`). Approved together with the migration's
  completion gate.
