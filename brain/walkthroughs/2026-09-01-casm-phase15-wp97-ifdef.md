# Walkthrough: CASM Phase 15 WP97 — `.ifdef` / `.ifndef`

Plan: `brain/plans/2026-09-01-casm-phase15-wp97-ifdef.md`
Taskwarrior: WP97 `56f9cd17`
Branch: `feature/casm-phase15`

`.ifdef NAME` / `.ifndef NAME` — the symbol-existence conditionals. Only
`casm.s` changed; the lexer keywords (WP94), parser routing (WP96),
`cond.s` stack (WP95), and the suppressed-branch scanner (WP96) were
already in place.

## Change

`src/external/casm/casm.s`: `crpCondIfdef` / `crpCondIfndef` replace the
two `CASM_DIAG_NOT_IMPLEMENTED` arms in `crpDir`. Shared body:

- `lexerNext` → the operand must be an `IDENTIFIER`; a leading `@` or a
  non-identifier → `CASM_DIAG_IFDEF_EXPECTS_NAME`.
- `symbolsLookup(name)` (bare global name; scope published from
  `CasmCurrentScope`, filter inert). `defined` = `CASM_RESOLVE_FLAGS &
  RESOLVED`.
- `decision = defined XOR wantAbsent` (`.ifndef` sets `wantAbsent`).
- `lexerNext` → `crpCondRequireTerminator`.
- `crpCondSiteDecision(decision)` → the WP95 Pass-1-record / Pass-2-replay
  bitmap gives the *effective* decision, then `condOpenIf`.

Placed after the shared `crpCondFail` tails so its own near branches stay
in 6502 range (a `beq crpCondIfdefBody` out-of-range on the first build
attempt — fixed by relocating the block, not by trampolines in the
callers).

**Key simplification vs. the phase plan:** no `DEFINED_AT_OFFSET`
"defined so far" comparison. Pass 1 computes a naive found/not-found
decision and records the bit; Pass 2 recomputes (a forward `NAME` is now
in the table) but `condSiteDecision` returns Pass 1's recorded bit. So a
forward `.ifdef` reads as *not defined* in both passes — consistently,
for free. (Matches ca65's traversal-order `.ifdef`.)

New BSS: `condWantAbsent` (1 B), `condIfdefView` (`CASM_RESOLVE_SIZE`).
`.import CasmTokenText`. 6 fixtures + 5 `.ref.hex` (scaffolded by a
subagent) on `casm_phase15_test.d64`.

## Live verification (VICE 3.10, `CASM V0.6.0.1415`)

| Fixture | Result |
| --- | --- |
| `casmifdef1` | `FOO = 1` above, `.ifdef FOO` body taken → `00 C0 EA EA` → `FILES COMPARE OK` |
| **`casmifdeffwd`** | `.ifdef LATER` (LATER defined *below*) → body skipped **in both passes**; a second `.ifdef LATER` after the definition → taken. **P1 DONE 7, P2 DONE 7, 4 BYTES** — no `PASS 1/PASS 2` mismatch. `FILES COMPARE OK`. The sharp bitmap-replay test. |
| **`casmifdefguard`** | `.ifndef GUARD` / `GUARD = 1` / body / `.endif` twice — first block taken (defines GUARD), second skipped, **in both passes**. P1 DONE 6, P2 DONE 6, 3 BYTES. `FILES COMPARE OK`. (Pass 2's naive eval would skip the first block too; the bitmap replays Pass 1's "taken".) |
| `casmifndef1` | `.ifndef BAZ` (undefined → taken) + `.ifndef FOO` (defined → skipped) → `00 C0 EA` → `FILES COMPARE OK` |
| `casmifdefname` | `.ifdef 5` → `CASM: .IFDEF/.IFNDEF EXPECTS A NAME` AT LINE 2, COL 1 (caret at `.ifdef 5`) |
| `casmifdef0` | `.ifdef BAR` (never defined) → body skipped. Not re-run live — identical mechanism to `casmifndef1`'s verified second branch; trusted by construction. |
| `test_casm_cond` | `CASM COND: PASS` (regression — WP97 doesn't touch `cond.s`) |

Overlay `test/pass` event fired.

## Build + envelope

- Full `cmake --build build` clean; all 32 `test_casm_*` targets build.
- `ld65 -m`: casm CODE `$57BE` → `$5840` (+130 B, the two handlers),
  BSS +9 B. **MAIN headroom under `$7400`: 499 → 360 bytes.**
  **No envelope grow needed** — it fits `$7400`. WP98 (verification,
  minimal code) and WP99 (version bump, no code) should not threaten it,
  but 360 B is thin — re-check at WP98.
- `BUILD_CASM` → 1415.

## Status

WP97 source-complete, build- and live-VICE-verified (5/6 fixtures COMP
OK — `casmifdef0` trusted by construction — + the diagnostic + the two
Pass 1 == Pass 2 sharp tests + `test_casm_cond`). Nothing committed at
time of writing. Requesting sign-off to close WP97 and start WP98 (`/M`
`/L` interaction + the consolidated no-conditionals regression + DASH
survey).
