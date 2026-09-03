---
application: COMP
oracle-class: Native application manifest / R6 PRG
provenance: CANONICAL-INDEPENDENT
source: src/external/comp/comp.s
source-sha256: 597b6237d9a6cbeac07216f598d60f00380aa02fc3193fde5585c922cacf6ed7
source-sha256-at-review: 34727919bc81020fffd5e428a153c70f97cacf58c0d8cec942ca8b72d6ced588
derived: 2026-09-02
reviewer: user, 2026-09-02
native-observation: 1a0bfbf7be31a9c2844ea3ae2bfe56084f9f90571631bbe7ff212d89eec528e8 (native CASM 0.6.2 build 1419, 2026-09-02)
native-observation-status: byte-exact match to this derivation (1228/1228 bytes)
---

# COMP Independent Byte and R6 Derivation

## Post-Review Source Corrections (Increment 3, 2026-09-02)

Native assembly under CASM 0.6.2 rejected the review-gate source
(`34727919...`) twice. Both were Increment 2 conversion errors, not oracle
errors: each corrected form assembles to the exact bytes already derived
below, so this derivation's byte and R6 ledgers are unchanged. The reviewed
source hash is retained in the front matter as `source-sha256-at-review`;
`source-sha256` now tracks the corrected source (`597b6237...`).

1. **Bare accumulator shifts.** `PRINTHEX8` used `LSR` (x4) with no operand.
   CASM requires the explicit `LSR A` accumulator form (`CASM: INVALID
   ADDRESSING MODE` otherwise). Opcode is `$4A` either way; the derivation
   already shows `48 4A 4A 4A 4A`.
2. **`@local` labels crossing a global-label scope boundary.** CASM resets
   the `@name` namespace at every global label. `COMPAREFILES` referenced
   `@READERROR` / `@DONE`, but `@READERROR:` sits after the global
   `CMPDONE:` label (new scope) and `@DONE:` was the retired ca65
   `closeFiles` shared-`RTS` trick. Fixes: `@READERROR` -> global
   `CFREADERROR` (same address `$35A5`); `BNE @DONE` -> `BNE CMPDONE` (same
   `RTS` target `$35A4`, displacement `$1E`, exactly as derived).

## Authority and Isolation

This record derives COMP's expected bytes from the documented NMOS 6502
instruction encoding, CASM language semantics, PRG framing, and Command64 R6
format. The derivation did not use CASM output, CASM's opcode tables, a prior
manifest, or ca65/ld65 output as the answer.

After the independent derivation was complete, the frozen ca65 relocation
structure was used only as differential evidence. It exposed one omitted
source-site entry (`JMP @PTLOOP`, offset `$00B3`); the source was re-enumerated
by instruction class and the corrected ledger below was independently
reconciled. No code or data byte is taken from ca65.

## Source Identity and Rules

- Source SHA-256:
  `34727919bc81020fffd5e428a153c70f97cacf58c0d8cec942ca8b72d6ced588`.
- No `.ORG`: CASM's implicit base and PRG load address are `$3400`.
- Label-derived operands are absolute-width; fixed zero-page constants select
  zero-page modes.
- Branch displacement is `target - address-after-branch` and is not relocated.
- A full internal 16-bit operand relocates at its high byte.
- `#>LABEL` relocates its operand; `#<LABEL` does not.
- Fixed OS/KERNAL/global constants are not image-relative and do not relocate.
- `.BYTE` strings emit the listed source bytes; terminators are explicit.
- `.RES count,$00` emits exactly `count` zero bytes.

## Address Ledger

| Label/range | Start | End | Bytes |
| --- | ---: | ---: | ---: |
| `START` | `$3400` | `$3437` | 56 |
| `PARSEARGS` | `$3438` | `$3491` | 90 |
| `PARSETOKEN` | `$3492` | `$34CA` | 57 |
| `SKIPSPACES` | `$34CB` | `$34D6` | 12 |
| `PRINTPARSEERROR` | `$34D7` | `$3506` | 48 |
| `PRINTUSAGE` | `$3507` | `$3510` | 10 |
| `OPENFILES` | `$3511` | `$353E` | 46 |
| `CLOSEFILES` | `$353F` | `$3561` | 35 |
| `PRINTOPENERROR` | `$3562` | `$356B` | 10 |
| `COMPAREFILES` incl. error path | `$356C` | `$35B2` | 71 |
| `READFILE1` | `$35B3` | `$35C0` | 14 |
| `READFILE2` | `$35C1` | `$35CE` | 14 |
| `READCHUNK` | `$35CF` | `$35EF` | 33 |
| `SETCOMPARECOUNT` | `$35F0` | `$35FA` | 11 |
| `COMPAREOVERLAP` | `$35FB` | `$3622` | 40 |
| `INCOFFSET24` | `$3623` | `$362D` | 11 |
| `REPORTMISMATCH` | `$362E` | `$367C` | 79 |
| `PRINTSUMMARY` | `$367D` | `$3692` | 22 |
| `PRINTHEX8` | `$3693` | `$36AA` | 24 |
| Code subtotal | `$3400` | `$36AA` | 683 |
| Messages | `$36AB` | `$3779` | 207 |
| `FILE1BUF` | `$377A` | `$37A1` | 40 zeroes |
| `FILE2BUF` | `$37A2` | `$37C9` | 40 zeroes |
| `BUF1` | `$37CA` | `$3809` | 64 zeroes |
| `BUF2` | `$380A` | `$3849` | 64 zeroes |
| Program image | `$3400` | `$3849` | 1,098 (`$044A`) |

## Instruction-Byte Ledger

Each row is a contiguous address range. Operands are little-endian. These rows
plus the data/storage ledger reconstruct every program-image byte.

### `START`, `$3400-$3437`

```text
A9 FF 85 70 85 71 A9 00 85 73 85 74 85 75 85 76
85 7D 85 7E 20 38 34 90 06 20 D7 34 4C 33 34 20
11 35 90 03 4C 30 34 20 6C 35 20 7D 36 4C 30 34
20 3F 35 A9 4C 20 00 10
```

### `PARSEARGS`, `$3438-$3491`

```text
A4 63 B9 3C 03 F0 46 C9 20 F0 04 C8 4C 3A 34 20
CB 34 B9 3C 03 F0 36 C9 2F F0 3A A2 7A 86 FB A2
37 86 FC 20 92 34 B0 31 20 CB 34 B9 3C 03 F0 1D
C9 2F F0 21 A2 A2 86 FB A2 37 86 FC 20 92 34 B0
18 20 CB 34 B9 3C 03 D0 08 18 A9 00 60 38 A9 01
60 38 A9 02 60 38 A9 03 60 60
```

### `PARSETOKEN`, `$3492-$34CA`

```text
84 72 A9 00 85 7F A4 72 B9 3C 03 F0 15 C9 20 F0
11 A6 7F E0 27 B0 1E A4 7F 91 FB E6 7F E6 72 4C
98 34 A5 7F F0 0B A8 A9 00 91 FB A4 72 18 A9 00
60 38 A9 01 60 38 A9 04 60
```

### `SKIPSPACES`, `$34CB-$34D6`

```text
B9 3C 03 C9 20 D0 04 C8 4C CB 34 60
```

### Parse-error output, `$34D7-$3510`

```text
C9 03 F0 0B C9 02 F0 13 C9 04 F0 1B 4C 07 35 A2
C4 A0 36 A9 09 20 00 10 4C 07 35 A2 D4 A0 36 A9
09 20 00 10 4C 07 35 A2 E8 A0 36 A9 09 20 00 10
A2 AB A0 36 A9 09 20 00 10 60
```

### File open/close/error, `$3511-$356B`

```text
A9 00 85 66 A2 7A A0 37 A9 3D 20 00 10 90 05 20
62 35 38 60 85 70 A9 00 85 66 A2 A2 A0 37 A9 3D
20 00 10 90 05 20 62 35 38 60 85 71 18 60 A5 71
C9 FF F0 0B 85 6D A9 3E 20 00 10 A9 FF 85 71 A5
70 C9 FF F0 0B 85 6D A9 3E 20 00 10 A9 FF 85 70
60 A2 FC A0 36 A9 09 20 00 10 60
```

### Compare orchestration, `$356C-$35B2`

```text
20 B3 35 90 03 4C A5 35 20 C1 35 90 03 4C A5 35
20 F0 35 20 FB 35 A5 7D D0 1E A5 77 C5 78 F0 10
A9 01 85 7E A2 4D A0 37 A9 09 20 00 10 4C A4 35
A5 77 F0 04 C9 40 F0 C8 60 A2 0D A0 37 A9 09 20
00 10 A9 01 85 7D 60
```

### Read helpers, `$35B3-$35EF`

```text
A5 70 85 6D A2 CA A0 37 20 CF 35 85 77 60 A5 71
85 6D A2 0A A0 38 20 CF 35 85 78 60 A9 40 85 66
A9 00 85 67 A9 3F 20 00 10 90 0E A5 66 05 67 F0
04 38 A5 66 60 18 A9 00 60 A5 66 18 60
```

### Compare core, `$35F0-$362D`

```text
A5 77 C5 78 90 02 A5 78 85 79 60 A2 00 E4 79 F0
21 BD CA 37 DD 0A 38 F0 12 85 7B BD 0A 38 85 7C
86 7A 20 2E 36 A6 7A A5 7D D0 07 20 23 36 E8
4C FD 35 60 E6 73 D0 06 E6 74 D0 02 E6 75 60
```

### Mismatch report, `$362E-$367C`

```text
A2 19 A0 37 A9 09 20 00 10 A5 75 20 93 36 A5 74
20 93 36 A5 73 20 93 36 A2 2C A0 37 A9 09 20 00
10 A5 7B 20 93 36 A2 30 A0 37 A9 09 20 00 10 A5
7C 20 93 36 A9 0D 20 D2 FF E6 76 A5 76 C9 0A 90
0D A9 01 85 7D A2 33 A0 37 A9 09 20 00 10 60
```

### Summary and hexadecimal output, `$367D-$36AA`

```text
A5 7D D0 11 A5 76 D0 0D A5 7E D0 09 A2 68 A0 37
A9 09 20 00 10 60 48 4A 4A 4A 4A 20 9E 36 68 29
0F C9 0A 90 03 18 69 07 69 30 20 D2 FF 60
```

## Data-Byte Ledger

```text
36AB MSGUSAGE:
55 53 41 47 45 3A 20 43 4F 4D 50 20 46 49 4C 45
31 20 46 49 4C 45 32 0D 00

36C4 MSGUNKNOWNOPTION:
55 4E 4B 4E 4F 57 4E 20 4F 50 54 49 4F 4E 0D 00

36D4 MSGTOOMANYARGS:
54 4F 4F 20 4D 41 4E 59 20 41 52 47 55 4D 45 4E
54 53 0D 00

36E8 MSGNAMETOOLONG:
46 49 4C 45 20 4E 41 4D 45 20 54 4F 4F 20 4C 4F
4E 47 0D 00

36FC MSGOPENERROR:
46 49 4C 45 20 4F 50 45 4E 20 45 52 52 4F 52 0D 00

370D MSGREADERROR:
52 45 41 44 20 45 52 52 4F 52 0D 00

3719 MSGCOMPAREAT:
43 4F 4D 50 41 52 45 20 45 52 52 4F 52 20 41 54 20 24 00

372C MSGCOLONDOLLAR: 3A 20 24 00
3730 MSGSPACEDOLLAR: 20 24 00

3733 MSGSTOP:
31 30 20 4D 49 53 4D 41 54 43 48 45 53 20 2D 20
53 54 4F 50 50 49 4E 47 0D 00

374D MSGSIZEDIFF:
46 49 4C 45 53 20 41 52 45 20 44 49 46 46 45 52
45 4E 54 20 53 49 5A 45 53 0D 00

3768 MSGOK:
46 49 4C 45 53 20 43 4F 4D 50 41 52 45 20 4F 4B 0D 00

377A-37A1 FILE1BUF: 40 * 00
37A2-37C9 FILE2BUF: 40 * 00
37CA-3809 BUF1:     64 * 00
380A-3849 BUF2:     64 * 00
```

Code is 683 bytes; messages and storage are 415 bytes; total image is
1,098 bytes.

## R6 Relocation Ledger

The 61 entries comprise 40 full internal `JSR/JMP` high bytes, 18
`#>label` operands, and 3 absolute-indexed label high bytes.

```text
0016 001B 001E 0021 0026 0029 002C 002F 0032 0046 0049 0058 005D 0062 0071 0076
007B 00B3 00D5 00E5 00E9 00F1 00F5 00FD 0101 010A 0118 0122 012E 0138 0165 016E
0173 0176 017B 017E 0181 0193 019B 01A8 01BA 01BD 01C8 01CB 0203 0206 020D 0214
021D 0221 0231 023B 0240 0245 0249 0253 0257 0261 0276 028C 029A
```

Serialized little-endian table bytes:

```text
16 00 1B 00 1E 00 21 00 26 00 29 00 2C 00 2F 00
32 00 46 00 49 00 58 00 5D 00 62 00 71 00 76 00
7B 00 B3 00 D5 00 E5 00 E9 00 F1 00 F5 00 FD 00
01 01 0A 01 18 01 22 01 2E 01 38 01 65 01 6E 01
73 01 76 01 7B 01 7E 01 81 01 93 01 9B 01 A8 01
BA 01 BD 01 C8 01 CB 01 03 02 06 02 0D 02 14 02
1D 02 21 02 31 02 3B 02 40 02 45 02 49 02 53 02
57 02 61 02 76 02 8C 02 9A 02
```

Excluded: all relative branches, `#<label`, fixed `$1000`/`$FFD2`/`$033C`
operands, zero-page constants, strings, reserves, and R6 metadata.

## Framing

```text
PRG header:       00 34
Program image:    1098 bytes ($044A)
Relocation table: 122 bytes  ($007A)
R6 footer:        00 34 3D 00 52 36
Total:            1228 bytes ($04CC)
```

The footer fields are base `$3400` little-endian, count 61 (`$003D`)
little-endian, then ASCII `R6`.

## Reviewer Gate

- [x] Recalculate routine addresses and contiguous byte-row lengths.
- [x] Spot-check every opcode/addressing mode and every branch displacement.
- [x] Recount 40 full-address + 18 high-extract + 3 indexed relocations.
- [x] Confirm all 61 serialized offsets and footer arithmetic.
- [x] Record reviewer name/date before any native CASM output is consulted.

Approved by the user on 2026-09-02 before native CASM output was consulted.
