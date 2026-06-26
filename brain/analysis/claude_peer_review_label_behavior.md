# Peer Review: LABEL Command Behavior Analyses

Comparative review of:
1. [claude_label_com_behavior.md](claude_label_com_behavior.md)
2. [gemini_label_com_behavior.md](gemini_label_com_behavior.md)

---

## Section 1 — Root Cause of "31,syntax error"

**Verdict: Both agree, both correct.**

Both documents independently identify the same two bugs:

1. `petscii_mixed` encodes uppercase letter literals as shifted PETSCII ($C1–$DA) instead of the unshifted range ($41–$5A) that the 1541 command parser expects.
2. Raw binary values are sent for drive/track/sector parameters instead of ASCII digit characters.

The Gemini document is more readable on bug 1 (table of affected bytes per command). The Claude document cross-references `normalizeName` in `utils.asm` as corroborating evidence, which is a useful architectural connection.

---

## Section 2 — Disk Name BAM Offset

**Verdict: The two documents contradict each other. This section requires empirical verification before implementation.**

This is the most consequential disagreement and the one most critical to get right — an offset error is a silent data-corruption bug.

### Gemini's claim

> BAM starts at offset 4, covers 35 × 4 = 140 bytes (offsets 4–143). Disk name immediately follows at offset **144**.

### Claude's claim

> Disk name is at offset **4** ($04–$13). BAM begins at $1B (27). Offset 144 falls inside the track-30 BAM entry.

### The layout each document asserts

**Gemini's layout:**
```
$00–$03   Header (track link, sector link, DOS version, unused)
$04–$8F   BAM bitmap (35 tracks × 4 bytes = 140 bytes)
$90–$9F   Disk name (16 bytes)          ← offset 144
```

**Claude's layout:**
```
$00–$03   Header
$04–$13   Disk name (16 bytes)          ← offset 4
$14–$1A   Disk ID, DOS type, padding
$1B–…     BAM entries
```

### Why this must be verified

Both documents present confident, internally consistent math. However:

- If Gemini is correct, writing to offset 4 corrupts the BAM for tracks 1–2.
- If Claude is correct, writing to offset 144 corrupts the BAM for tracks 30–33.

Either mistake leaves the disk unreadable. The correct procedure is to fix the encoding and parameter bugs first (both documents agree on those), then run an empirical test:

1. Read Track 18 Sector 0 into a buffer via `U1`.
2. Print a hex dump of the full 256 bytes.
3. Locate the `$A0`-padded 16-byte region that matches the current disk name — that offset is the ground truth.

Do not write the label until the read path is confirmed working and the hex dump is inspected.

---

## Section 3 — MS-DOS 4.0 `LABEL.COM` Behavior

**Verdict: Both agree, both accurate.**

Both documents correctly describe the three execution flows:
- Non-interactive: `LABEL <name>` → set immediately.
- Interactive no-arg: display current label, prompt for new one.
- Interactive empty input: confirm delete (`Y/N`).

The Gemini document includes the exact prompt strings ("Volume label (11 characters, ENTER for none)?") and the C64 16-character equivalent. Claude's document is more concise but omits those details. Neither document conflicts with the other.

---

## Section 4 — Internal vs. External Command

**Verdict: Both agree on tradeoffs. No conflict.**

Both identify the same factors: memory footprint, MS-DOS 4.0 parity (LABEL.COM was external), debugging ease, interactive prompt complexity, and unconditional availability. Both lean toward external for non-trivial reasons. The Gemini comparison matrix is cleaner at a glance; the Claude document makes the more important architectural point that the encoding bugs must be fixed regardless of which path is chosen.

---

## Overall Verdict

| Section | Gemini | Claude |
|---------|--------|--------|
| Encoding bug | Correct | Correct |
| Binary/ASCII parameter bug | Correct | Correct |
| **BAM offset / disk name location** | **Offset 144 — requires verification** | **Offset 4 — requires verification** |
| MS-DOS behavior | Correct, more detailed | Correct, more concise |
| Internal vs. external tradeoffs | Correct | Correct |

**Do not implement the label write path until the offset question is resolved empirically.** Fix the encoding and parameter bugs first, add a hex-dump read, and inspect the actual sector layout before committing to either offset.