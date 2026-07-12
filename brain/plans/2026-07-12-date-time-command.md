---
feature: date-time-command
created: 2026-07-12
status: phase-1-complete
---

# Plan: DATE / TIME Built-in Commands

## Goal & Rationale

`brain/analysis/2026-07-12-ms-dos-4.0-parity-comparison.md` §4.1 flagged
`DATE`/`TIME` as a high-feasibility, cheap-win gap versus MS-DOS 4.0's
`COMMAND.COM` internals. This plan locks in the design decisions from user
interview and lays out a phased build: a self-contained Phase 1 with no
hardware-RTC dependency, followed by staged hardware-clock integrations that
are explicitly *out of scope* for Phase 1 but shape Phase 1's internal
interfaces so they don't need to be reworked later.

## Decisions Locked In (from interview)

| Decision | Choice | Why |
|---|---|---|
| Clock source | CIA #1 TOD registers (`$DC08-$DC0B`), not KERNAL jiffy (`TI`) | Dedicated hardware clock inside CIA1, isolated from BASIC's `TI$`/`TI` and immune to a loaded app resetting it. (User noted BASIC contention is moot anyway since ROM is banked out, but CIA TOD is still the cleaner foundation for layering RTC detection on top later.) |
| Persistence | None in Phase 1. Resets to default every cold boot / `RUN`. Real persistence deferred to hardware-RTC phases. | Matches actual C64 hardware (no battery-backed clock) until an RTC is detected. |
| Boot behavior | Silent default — no boot-time prompt. | Keeps boot sequence unchanged; user sets date/time on demand. |
| Command shape | Two built-in commands, `DATE` and `TIME`, added to `shell.asm`'s `tableCmd` (same tier as `VER`/`VOL`/`SET`) | Matches real `COMMAND.COM` (DATE/TIME are internals, not `.COM` files). |
| Format | ISO-ish: `YYYY-MM-DD` for date, 24-hour `HH:MM:SS` for time. No weekday field. | User's explicit choice — unambiguous, no Zeller's-congruence day-of-week code needed. |
| Default epoch | `1980-01-01` | Matches real MS-DOS's own floor date, used whenever no date has been set yet. |
| Date rollover | Detected lazily: compare newly-read TOD hour against the last-seen hour each time `TIME`/`DATE` is queried or displayed; a wrap (hour decreases) increments the stored date by one day, with month/leap-year carry. | Avoids installing a new IRQ hook in Phase 1; documented limitation below. |
| RTC hardware staging | Phase 1: none. Phase 2: Ultimate 64 / 1541 Ultimate-II+ Command Interface RTC. Phase 3 (low priority, untestable by user currently): userport bit-banged RTC cartridges (DS1307/DS3231-class). | User's explicit staging and testability constraint. |

## Phase 1 — Core CIA-TOD-backed DATE/TIME (no persistence, no RTC)

See [Detailed Implementation Plan (Phase 1)](2026-07-12-date-time-command-phase1-plan.md) for granular subroutine, memory, and register design.

**Status 2026-07-12:** Complete. User verified direct and interactive `DATE`/`TIME`
setting, display round-trips, midnight rollover, and month rollover.

### Scope

- `DATE` — bare: prints `Current date: YYYY-MM-DD`, then an interactive
  sub-prompt `Enter new date (YYYY-MM-DD), or RETURN to keep: ` (blank input
  leaves it unchanged). `DATE YYYY-MM-DD` — sets directly, no sub-prompt,
  validated (month 1-12, day valid for month, leap-year-aware Feb 29 check).
- `TIME` — same interaction shape, `HH:MM:SS`, validated (0-23 / 0-59 / 0-59).
- Internal CIA #1 TOD read/write routines with correct register-ordering
  (6526 quirk: reading `$DC0B` HR latches MIN/SEC/10THS for a torn-free
  read — must read HR first, then MIN, SEC, 10THS last to unlatch; writing
  HR *stops* the clock until 10THS is written, allowing an atomic set — must
  write HR first, 10THS last). AM/PM bit (`$DC0B` bit 7) is not used since
  we're storing/displaying 24-hour internally — convert on read/write.
- Boot-time CIA1 TOD init: set the TOD input-frequency bit in CIA1 Control
  Register A (`$DC0E` bit 7 — 0=60Hz/NTSC, 1=50Hz/PAL) to match the machine's
  actual video standard, and explicitly write `00:00:00.0` + the default date
  (`1980-01-01`) to the clock at boot — TOD registers are not guaranteed
  clear after `RUN`, so relying on power-on hardware state is unsafe.
- New date-state storage (year offset from 1980 / month / day / last-seen
  hour) — cassette-buffer workspace ($033C-$03FB) is already full per
  `include/ca65/command64.inc`, so extend `VmmData` (`src/command64/vmm.asm`)
  past the existing `fileScratch` fill, mirroring how `vmmInitialized`/
  `vmmTempByte` already live there. 4 new bytes: `SysDateYear`,
  `SysDateMonth`, `SysDateDay`, `SysDateLastHour`.
- Leap-year check: standard Gregorian rule (`year % 4 == 0 && (year % 100 != 0
  || year % 400 == 0)`) — needed for both date-entry validation and month
  rollover.

### Files to Create/Modify

| File | Action | Notes |
|---|---|---|
| `src/command64/shell.asm` | Modify | Add `cmdDate`/`cmdTime` handlers + two `tableCmd` entries (mirrors `cmdSet`/`cmdVol` pattern for bare-vs-argument dispatch and the sub-prompt read loop). |
| `src/command64/vmm.asm` | Modify | Extend `VmmData` segment with `SysDateYear/Month/Day/LastHour` bytes. |
| `src/command64/utils.asm` (or a new `clock.asm` if the CIA routines are non-trivial in size) | Create/Modify | CIA1 TOD read/write primitives, date math (leap-year check, days-in-month table, day/month/year rollover), decimal parse/format helpers for `YYYY-MM-DD`/`HH:MM:SS`. |
| `include/command64.inc` / `include/ca65/command64.inc` | Modify | CIA1 TOD register equates (`$DC08-$DC0B`, `$DC0E`), new `VmmData` byte offsets if not auto-derived. |
| `docs/user-manual.md` | Modify | New `### DATE` / `### TIME` entries in §4 Internal Command Reference. |
| `brain/COMMANDS.md` | Modify | Move `DATE`/`TIME` from Backlog to Implemented once shipped (this doc is already stale per the parity comparison's §6 corrections — worth a general refresh while touching it). |
| `CHANGELOG.md` | Modify | Mandatory per `AGENTS.md`/project convention, at implementation time. |

### Known Limitation (document in user-manual)

Date rollover is detected only when `DATE`/`TIME` is actively queried —
if the OS sits idle straddling midnight with no `DATE`/`TIME` call, the
stored date won't advance until the next query, at which point a
single-day rollover is applied correctly (hour-decrease detection only
needs to catch one wrap, since a C64 session realistically won't idle
across multiple midnights unattended). Not a defect worth an IRQ hook in
Phase 1 — flagged as a candidate enhancement (CIA TOD alarm-compare IRQ
at `00:00:00`) if it ever matters in practice.

### Open Question for Implementation Time

`command64.inc`'s zero-page/workspace budget is already tight (see its
own comments re: `$70-$8F` app-private collisions and the full cassette
buffer). Confirm the CIA TOD routines can work entirely out of registers
`A`/`X`/`Y` plus the existing `TempLo`/`TempHi`/`HexValLo`/`HexValHi`
scratch pairs rather than claiming new zero-page bytes — should be
sufficient since date/time parsing is very similar in shape to the
existing hex-parsing (`parseHex`) and `SET`'s VAR/VAL scanning.

### Verification

Per project convention (`feedback-vice-testing` memory): test in real VICE
execution via the `mcp__c64` tools, not synthetic register/memory pokes —
set date/time via the command, verify via CIA TOD register readback and
`DATE`/`TIME` display round-trip, and specifically exercise the midnight
rollover path by setting time to `23:59:58` and letting it tick across.

## Phase 2 — Ultimate 64 / 1541 Ultimate-II+ Command Interface RTC

### Scope

- **Research spike first** (separate task before any coding): pin down the
  Ultimate Command Interface's documented RTC read/set protocol precisely —
  I have general awareness that the Ultimate product line exposes a
  battery-backed/network-synced RTC through its Command Interface register
  window, but not verified register-level command codes, and this codebase's
  existing REU emulation already lives in the adjacent `$DF00-$DF0A` I/O
  window (`include/ca65/vmm.inc`), which is a strong signal this project
  already targets Ultimate/Ultimate64 hardware as a first-class citizen — so
  getting the RTC protocol details right (rather than guessing) matters.
- Detection: probe for Ultimate Command Interface presence at boot
  (non-destructively — must not misbehave on real 1541/REU-less hardware or
  emulators without the Ultimate extension) before attempting any RTC read.
- If detected: seed `SysDateYear/Month/Day` and the CIA TOD registers from
  the Ultimate RTC at boot (replacing the Phase 1 `1980-01-01`/`00:00:00`
  hardcoded default), and optionally write back to the Ultimate RTC when the
  user sets `DATE`/`TIME` (needs a decision at spike time on whether
  set-writes-through is wanted or read-only sync is safer).
- Design Phase 1's date-storage/rollover code so this slots in as an
  alternate *seed source* for the same `SysDateYear/Month/Day` state and CIA
  TOD registers, not a parallel clock — avoids a rework.

### Files (provisional, confirm at spike time)

| File | Action |
|---|---|
| `brain/analysis/YYYY-MM-DD-ultimate-command-interface-rtc-research.md` | Create — spike findings before implementation |
| `src/command64/clock.asm` (or wherever Phase 1 lands the CIA routines) | Modify — add Ultimate-detect + RTC-read/write paths |

## Phase 3 — Userport RTC cartridges (DS1307/DS3231-class) — Backlog

Explicitly low priority: no test hardware available. Scope only once a
specific target device is identified and testable; don't build speculatively
against a family of loosely-compatible third-party carts.

## Summary of Sequencing

1. Phase 1 ships a fully self-contained `DATE`/`TIME` with no external
   dependency — usable and complete on its own.
2. Phase 2 is additive (RTC becomes an optional seed/sync source) — Phase 1
   must not need to change shape to accommodate it, only gain a new caller
   into the same date-state.
3. Phase 3 stays backlog until testable.
