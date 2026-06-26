# Analysis: LABEL Command — Why "31,syntax error,0,0" Persists

## TL;DR

Two distinct bugs are causing the "31,syntax error":

1. **Encoding bug** (root cause): `petscii_mixed` encodes uppercase letter literals as shifted PETSCII ($C1–$DA). The 1541 command parser expects unshifted PETSCII ($41–$5A). Every alphabetic character in every command string sent to the drive is wrong.

2. **Binary-vs-ASCII bug** (also present in refactored code): The `labelSendBlockCmd` and `labelSendBPCmd` routines send raw binary values for drive number, track, and sector instead of ASCII digit characters. The 1541 command channel is a text interface.

These bugs exist in both the internal command and would exist in any external command that copies the same code without fixing them.

---

## Bug 1 — `petscii_mixed` Encoding

### What the encoding does

In KickAssembler with `.encoding "petscii_mixed"`, uppercase source letters map to the **shifted PETSCII** range:

| Source | Byte produced | What 1541 receives | 1541 expects |
|--------|---------------|--------------------|--------------|
| `'I'`  | `$C9`         | shifted 'I'        | `$49` ('I')  |
| `'U'`  | `$D5`         | shifted 'U'        | `$55` ('U')  |
| `'B'`  | `$C2`         | shifted 'B'        | `$42` ('B')  |
| `'P'`  | `$D0`         | shifted 'P'        | `$50` ('P')  |

This is confirmed by `normalizeName` in `utils.asm`, which explicitly converts the $C1–$DA range (shifted) to the $41–$5A range (unshifted) before sending filenames to the drive. The LABEL command strings bypass `normalizeName` entirely.

### Affected code locations

| Location | Broken value | Correct value |
|---|---|---|
| `cmdInitStr: .text "I"` | `$C9` ($0D, $00) | `$49, $0D, $00` |
| `lda #'U'` in `labelSendBlockCmd` | `$D5` | `$55` |
| `lda #'B'` in `labelSendBPCmd` | `$C2` | `$42` |
| `lda #'P'` in `labelSendBPCmd` | `$D0` | `$50` |

**The very first command sent (`I`, encoded as `$C9`) causes "31,syntax error" immediately.** The drive never sees U1, B-P, or U2.

### The fix

Use explicit byte literals for all alphabetic command characters:
- `lda #$55` instead of `lda #'U'`
- `lda #$42` instead of `lda #'B'`
- `lda #$50` instead of `lda #'P'`
- `cmdInitStr: .byte $49, $0D, 0` instead of `.text "I"`

Alternatively, lowercase source letters in `petscii_mixed` produce the unshifted ($41–$5A) range, so `.text "i"` → `$49`. But explicit byte values are unambiguous.

---

## Bug 2 — Binary Parameters Instead of ASCII Text

The 1541 command channel is a **text protocol**. Commands must be sent as ASCII/PETSCII digit strings, not binary values.

### What `labelSendBlockCmd` currently sends for `U1:2,0,18,0`

| Intended | Currently sent | Correct byte |
|---|---|---|
| 'U' | `$D5` (wrong encoding) | `$55` |
| '1' or '2' | `$31` or `$32` ✓ | `$31`/`$32` |
| ':' | `$3A` ✓ | `$3A` |
| '2' (SA as digit) | binary `$02` | `$32` (SA + `$30`) |
| ',' | `$2C` ✓ | `$2C` |
| '0' (drive) | binary `$00` | `$30` |
| ',' | `$2C` ✓ | `$2C` |
| '1' (track tens) | **missing** | `$31` |
| '8' (track units) | binary `$12` (raw 18) | `$38` |
| ',' | `$2C` ✓ | `$2C` |
| '0' (sector) | binary `$00` | `$30` |
| CR | `$0D` ✓ | `$0D` |

### What `labelSendBPCmd` currently sends for `B-P:2,144`

| Intended | Currently sent | Correct byte |
|---|---|---|
| 'B' | `$C2` (wrong encoding) | `$42` |
| '-' | `$2D` ✓ | `$2D` |
| 'P' | `$D0` (wrong encoding) | `$50` |
| ':' | `$3A` ✓ | `$3A` |
| '2' (SA as digit) | binary `$02` | `$32` (SA + `$30`) |
| ',' | missing | `$2C` |
| '1' | binary `$90` (raw 144) | `$31` |
| '4' | **missing** | `$34` |
| '4' | **missing** | `$34` |
| CR | `$0D` ✓ | `$0D` |

---

## Open Question — Disk Name Offset

There is a conflict between the project's research document and the 1541 hardware specification.

### Research document says: offset 144
[volume_name_asm.md](../research/volume_name_asm.md) states the disk name is at "byte offsets 144 through 159" and gives example `"B-P 2 144"`.

### 1541 BAM sector spec says: offset 4
Standard Commodore 1541 Track 18, Sector 0 layout:

```
$00–$01  Link to first directory block (18, 1)
$02      DOS version ('A' = $41)
$03      Unused ($00)
$04–$13  Disk name (16 bytes, $A0-padded)   ← offset 4
$14–$15  Disk ID (2 bytes)
$16      $A0
$17–$18  DOS type ("2A")
$19–$1A  $A0, $A0
$1B–…    BAM entries, 4 bytes per track (tracks 1–35)
           Track 30 entry starts at: 27 + 29×4 = 143
           → Offset 144 = byte 1 of track-30 BAM entry
```

Offset 144 lands in the track-30 BAM entry, not the disk name. Writing a label there would corrupt the BAM for tracks 30–33 and leave the visible disk name unchanged.

### Verification method
Fix the syntax error first. Then:
- Run `LABEL TESTDISK` with `B-P` using offset 4
- Run `VOL` — if it shows "TESTDISK", offset 4 is correct
- If VOL shows the old name but the disk is now unreadable, the write went to the wrong sector (rule out logic errors)

---

## Relationship to Internal vs. External Command

Making LABEL an external command does **not** fix either bug. The same encoding rules apply to all `.asm` files imported with `.encoding "petscii_mixed"`. The bugs must be fixed in whichever implementation we use.

### Arguments for external command

- Recompile without rebuilding the full OS binary
- Can add verbose debug output without bloating the OS
- Matches MS-DOS 4.0 architecture (LABEL.COM was external)
- Supports interactive mode (show current label, prompt) more cleanly
- Can be reloaded on disk without reflashing

### Arguments to stay internal

- Always available regardless of disk content or PATH
- Simpler build — no new CMakeLists target needed
- VOL is internal; LABEL is its natural complement

### MS-DOS 4.0 behavior difference (from `label_com_behavior.md`)

Current implementation: non-interactive only (`LABEL <name>` → set immediately).

MS-DOS 4.0 behavior:
- `LABEL <name>` → set immediately (matches current)
- `LABEL` (no arg) → display current name, prompt for new one (not implemented)
- `LABEL` + empty input → confirm delete (not implemented)

If moving to external, the interactive path (`LABEL` with no arg) should call the same VOL display logic, then prompt via the shell's existing input routine.
