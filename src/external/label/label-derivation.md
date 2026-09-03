---
title: LABEL — independent byte + R6 relocation derivation record
date: 2026-09-02
status: reviewed and approved (user, 2026-09-02)
oracle-class: Native application manifest (+ R6 PRG)
manifest: src/external/label/label.ref.hex
plan: brain/plans/2026-09-02-label-casm-native-migration.md
---

# LABEL — Canonical Byte / R6 Derivation

Per `.agents/workflows/canonical-byte-oracles.md`. This record is the
correctness oracle for `src/external/label/label.ref.hex`; the manifest
itself is only the shipped artifact + stale-source guard.

## Artifact under derivation

- Native CASM output `LBL.PRG`, **956 bytes**, load `$3400`.
- SHA-256 `d02469304f224788dad4c9c7ccb20f98f076a86fc6cec0007e88027a1cf174cf`.
- Produced by native CASM `0.6.2` build `1419` running on Command 64 under
  VICE 3.10 (16 MB REU), `CASM LABEL.S /O:LBL.PRG` from the SEQ sources on
  the dedicated assembly disk; extracted with `cc1541 -X`.
- `P1 DONE 00382`, `P2 DONE 00382`, `00956 BYTES`, `CASM: INPUT VALIDATED`;
  reproduced byte-identically across three independent native runs
  (pre-inline-constants, inlined-constants, DEBUG-format banner).

## Source identity (all under `src/external/label/`)

| File | Role | SHA-256 |
| --- | --- | --- |
| `label.s` | assembled source (constants inline) | `ba961b209fa48e453958eff3849f65c565fbf744e68a17038b8b4bf36e074f14` |
| `LABEL_VERSION` | app version `0.4.0` → generated `labelver.s` | `40b8eb4000a913a7791090535f291d3d369874162a89ef3c9e3d4e887a1b9e79` |
| `BUILD_LABEL` | build counter `1047` → generated `labelver.s` | `059df89c549121dcce31659a1cab11da37c1558d5e8591e660ebeb04e39bf8a7` |
| `labelver.s` (generated, not checked in) | `LABELVERMSG` data | `40d55ed8b7b7612080708126959c109c2acb55a7c933460b3d72ec8ffacf0447` |

`labelver.s` is produced by `scripts/gen_label_version.py` from
`LABEL_VERSION` + `BUILD_LABEL`; its content is fully determined by those
two files plus the (version-controlled, separately reviewed) generator.

## Independent code/data byte derivation

The full opcode/operand byte stream is derived independently of CASM by an
**independent ca65/ld65 assembly of the pre-migration `label.s` linked at
the same `$3400` base** (`ca65 -t c64` + `ld65` with a `$3400`-patched copy
of `build/build_label_cfg/label_3800.cfg`). ca65 and CASM share no code and
select opcodes / addressing modes / branch displacements by entirely
different means, so an agreement on the byte stream is genuine independent
corroboration, not circularity. Baseline artifact:
`label_base3400.prg`, 846 bytes, SHA-256
`83161418a8f2a31976b158241be311e826af4542b2d4b3ed85d4f3cec5173c33`
(program image `$3400..$374B`, no R6 footer — ld65 does not emit one).

**Result of the byte comparison (program image, `$3400..$374B`, 844
bytes):**

- **843 of 844 bytes identical** to the independent ca65 `$3400` build.
- **1 byte differs — `$3706`: ca65 `$D6`, CASM `$56`.** This is the
  intentional, user-approved banner change (Scoping Decision 2 / user
  decision 2026-09-02): the old ca65 build rendered the app name's `V`
  through `-t c64`'s charmap as *shifted* PETSCII `$D6` (uppercase glyph);
  the CASM-native `LABELVERMSG` emits unshifted `$56` (lowercase `v`
  glyph), matching DEBUG's `DEBUG v0.5.0.1128` banner format. The app name
  letters `$3700-$3704` are explicit shifted bytes `CC C1 C2 C5 CC` in
  both. Every other message in LABEL has always used unshifted letter
  bytes and already renders lowercase.

All addresses in the ca65 map (`start $3400`, `openChannels $34D8`,
`openErr $362C`, `printErrCode $363B`, `labelExit $365A`, `cmdInit $3670`,
`cmdU1 $3673`, `cmdBP $3680`, `cmdU2 $368B`, `okMsg $3698`, `lenMsg $36A7`,
`reqMsg $36C0`, `promptMsg $36D5`, `devMsg $36F3`, `verMsg/LABELVERMSG
$3700`, `statusBuf $3713`, `labelBuf $373B`, `LastErrCode $374B`) match the
CASM layout exactly — the migration is length-preserving.

## R6 relocation ledger (independent)

R6 footer parsed assembler-independently by `scripts/casm_r6_verify.py`
(reads only the bytes + the documented R6 format):

```
footer: base $3400  count 52  magic 'R6'
program image 844 bytes  $3400..$374B
relocation table 104 bytes (52 entries × 2-byte LE offset) at file offset 846..949
offsets strictly ascending and unique
offset range min $0003  max $023D  (< program length $034C)
all 52 entries point at an in-image high byte (pages $34..$37)
relocate to $3800 / $5000 / $9000: every high byte lands in range
R6 VERIFY: PASS
```

**Independent eligibility reconciliation.** Disassembling the 844-byte
image and classifying every operand against the R6 rules (relocate the
high byte of any operand that names an in-image address; never a fixed
address; never a `#<label` low byte):

- **45 three-byte absolute operands** target in-image addresses — every
  target matches a symbol in the independent ca65 map above (`JMP`/`JSR`
  to `label.s`'s own routines; `LDA`/`STA` absolute-indexed against
  `cmdInit`/`cmdU1`/`cmdBP`/`cmdU2`/`labelBuf`/`statusBuf`; `LDA`/`STA`
  absolute against `statusBuf`/`statusBuf+1`/`LastErrCode`).
- **7 `#>label` high-byte immediates** (`LDY #>LABELVERMSG`,
  `LDY #>PROMPTMSG`, `LDY #>OKMSG`, `LDY #>REQMSG`, `LDY #>LENMSG`,
  `LDY #>DEVMSG`, and the `$37xx` `LABELVERMSG` pair) — high byte in an
  in-image page, so relocation-eligible.
- **= 52 entries — exactly CASM's count.**
- **Zero** entries for fixed addresses: `OS_API` (`$1000`), `KERNAL*`
  (`$FFxx`), `CURRENTDEVICE` (`$039E`), `COMMANDBUFFER` (`$033C`).
- **Zero** entries for `#<label` low-byte immediates (`LDX #<…` — CASM
  clears `RELOCATABLE` for `<`, matching `banner.ref.hex`).

Matches the BANNER/DASH R6 precedent exactly.

## Live native comparison

See `brain/walkthroughs/2026-09-02-label-casm-native-migration.md` for the
`COMP LABEL.PRG,LABEL.REF` run, its disk/device, `CASM` version/build, the
R6 multi-base runtime evidence, and the functional path sweep.

## Provenance state

`CANONICAL-INDEPENDENT` for both the code/data byte stream (independent
ca65 differential corroboration of 843/844 bytes + one documented
intentional byte) and the R6 relocation ledger (assembler-independent
structural verification + independent eligibility reconciliation to the
exact 52-entry count).

## Independent reviewer sign-off

- Reviewer: the user (independent reviewer, per the WP60 precedent recorded
  in `brain/KNOWLEDGE.md`).
- Date: 2026-09-02.
- Reconciled: load address `$3400`, 956-byte count, artifact SHA-256
  `d0246930…`, the 843/844 byte agreement with the independent ca65
  `$3400` build, the single `$3706` intentional difference (`$D6`→`$56`,
  banner `V`→`v`), and the 52-entry R6 relocation ledger (45 absolute
  operands + 7 `#>` high-byte immediates; `casm_r6_verify.py` PASS at
  `$3800`/`$5000`/`$9000`). Approved together with the migration's
  completion gate.
