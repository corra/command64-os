# Application Manager — Design Spec

**Date:** 2026-05-13
**Phase:** 6 (depends on: Binary Relocator for Phase B, VMM swap for Phase C)
**Status:** Approved for implementation

---

## Goal

Implement a process/application management system for command64. The system tracks loaded programs by name and address, prevents unsafe loading, and enforces table membership before execution. Three incremental delivery phases allow implementation to proceed without waiting for the Relocator or full VMM swap support.

---

## Incremental Phases

| Phase | Prerequisite | Execution Model | Key Unlock |
|-------|-------------|-----------------|------------|
| A | None | LOAD + RUN always use $2000 | App table, `apps`/`ps`, `free`, safe RUN/GO |
| B | Binary Relocator | Relocator patches binary; placed at arbitrary main RAM address | Multiple apps resident in main RAM simultaneously |
| C | VMM DMA + Phase B | Apps stored in REU; DMA'd to execution window on RUN | CPU state save/restore, service bus API, cooperative swap |

Each phase extends `apptable.asm` without changing its API surface. Shell commands and the loader call the same labels across all phases.

---

## Architecture

### New Module

**`src/command64/apptable.asm`** — owns all app table logic.

Internal API (6502 labels, not service bus):

| Label | Phase | Description |
|-------|-------|-------------|
| `aptInit` | A | Allocate one VMM page; write table header |
| `aptRegister` | A | Add or update an entry; validate address range |
| `aptFind` | A | Scan by name or address; return slot index in X |
| `aptRemove` | A | Clear slot, decrement UsedSlots, optionally vmmFree |
| `aptList` | A | Print all SLOT_USED entries to screen |
| `aptSwapIn` | C | DMA app image from REU to LoadAddr in main RAM |
| `aptSwapOut` | C | DMA main RAM back to REU; save CPU state to entry |

### Modified Modules

| File | Change |
|------|--------|
| `src/command64/loader.asm` | Call `aptRegister` after successful disk read |
| `src/command64/shell.asm` | Add `APPS`/`PS`, `FREE`; modify `RUN`/`GO` to call `aptFind` first |
| `src/command64/api.asm` | Phase C: four new service bus opcodes |
| `include/command64.inc` | New constants: slot count, entry offsets, flag bits, Phase C opcodes |
| `build/command64.asm` | Import `apptable.asm`; assign segment address |

### Data Flow

**LOAD foo:**
```
shell → loader (path search + disk read → $2000) → aptRegister (write entry to VMM) → return
```

**RUN foo / RUN 2000:**
```
shell → aptFind (scan VMM table by name or address)
      → [not found: print "not loaded", return]
      → [Phase A: jsr to LoadAddr directly]
      → [Phase C: aptSwapIn (DMA REU→RAM), jsr, aptSwapOut (DMA RAM→REU, save CPU state)]
```

**APPS / PS:**
```
shell → aptList (read VMM header + each SLOT_USED entry, print table)
```

**FREE foo:**
```
shell → aptFind → [not found: "not found"]
              → [APP_RUNNING set: "app is running", refuse]
              → aptRemove (clear slot, vmmFree if REU_BACKED)
```

---

## App Table Storage

The table is allocated from the VMM at shell init via `vmmAlloc` (one 4KB page), alongside the environment block. Zero main RAM cost. All table access uses `vmmReadByte` / `vmmWriteByte`.

**Table header** (VMM offset 0–3):

| Offset | Size | Field | Notes |
|--------|------|-------|-------|
| 0 | 1 | MaxSlots | Written at `aptInit`; compile-time constant = 16 |
| 1 | 1 | UsedSlots | Incremented by `aptRegister`, decremented by `aptRemove` |
| 2 | 2 | (reserved) | Zero-padded |

**Entry N** at VMM offset `4 + N×40`:

| Offset | Size | Field | Phase | Notes |
|--------|------|-------|-------|-------|
| 0 | 1 | Flags | A | Bit 0: SLOT_USED; Bit 1: APP_RUNNING; Bit 2: REU_BACKED; Bit 3: STACK_SAVED; bits 4–7 reserved |
| 1 | 16 | Name | A | PETSCII, null-padded to 16 bytes; case-normalized on write |
| 17 | 2 | LoadAddr | A | Lo/Hi — C64 main RAM base address |
| 19 | 2 | Size | A | Lo/Hi — byte count of binary image |
| 21 | 3 | ReuAddr | C | Bank / OffLo / OffHi — REU backing store for binary image |
| 24 | 3 | StackReuAddr | C | Bank / OffLo / OffHi — REU address of saved $0100–$01FF stack image |
| 27 | 1 | SavedA | C | Accumulator at suspend |
| 28 | 1 | SavedX | C | X register at suspend |
| 29 | 1 | SavedY | C | Y register at suspend |
| 30 | 1 | SavedP | C | Processor status at suspend |
| 31 | 1 | SavedSP | C | Stack pointer at suspend |
| 32 | 2 | SavedPC | C | Lo/Hi — resume address |
| 34 | 1 | SavedDevice | C | Active device number at suspend |
| 35 | 5 | (reserved) | — | Zero-padded |

**Entry stride:** 40 bytes. **Max entries:** 16 (compile-time constant `APT_MAX_SLOTS`). Total table data: 4 + 16×40 = 644 bytes, well within the 4KB VMM page.

---

## Protected Memory Ranges

`aptRegister` rejects any load whose address range overlaps these regions. Checked before disk I/O begins.

| Range | Reason |
|-------|--------|
| `$0000–$1FFF` | OS, zero page, KERNAL vectors, shell, API segments |
| `$C000–$CFFF` | VMM MCT (4KB page byte-map) |
| `$D000–$DFFF` | C64 I/O registers (SID, VIC, CIA) |
| `$E000–$FFFF` | KERNAL ROM |

Any attempt to load into a protected range prints `protected address` and aborts without touching the disk or the table.

---

## Command Specifications

### `LOAD <name> [address]` — modified

Existing path-search and disk-read behaviour is unchanged. New behaviour added after a successful read:

1. If target address range overlaps a protected region: print `protected address`, abort before disk I/O.
2. If `UsedSlots == MaxSlots`: print `app table full`, abort before disk I/O.
3. Call `aptRegister`. If an entry with the same name already exists, overwrite it (re-load).

Error messages use the existing `errMsg` / `API_PRINT_STR` pattern.

---

### `RUN <name>` / `RUN <addr>` — modified (alias: `GO`)

Current implementation executes unconditionally. New behaviour:

1. Parse argument. If hex digits → address lookup. If alpha → name lookup.
2. Call `aptFind`. If carry set (not found): print `not loaded`, return.
3. **Phase A:** `jsr` to `LoadAddr` from found entry. On return, clear `APP_RUNNING` flag.
4. **Phase C:** Call `aptSwapIn` (DMA REU→`LoadAddr`), set `APP_RUNNING`, `jsr`, on return call `aptSwapOut` (DMA `LoadAddr`→REU, save CPU state), clear `APP_RUNNING`.

`RUN` with no argument is equivalent to `RUN 2000` — searches the table for an entry at `$2000`. Prints `not loaded` if none found. The bare `RUN` form without any argument is deprecated in favour of `RUN <name>`.

---

### `APPS` (alias: `PS`) — new internal command

Prints all entries with `SLOT_USED` set. 40-column output:

```
NAME             ADDR  SIZE
hello            2000   1A4
debug            2000   C3F
2 app(s) loaded
```

- Name: left-aligned, 16 chars
- ADDR: 4-digit hex, no prefix
- SIZE: hex bytes
- Footer: count of active entries

Calls `aptList`. If `UsedSlots == 0`: prints `no apps loaded`.

---

### `FREE <name>` — new internal command

1. Call `aptFind` by name. If not found: print `not found`, return.
2. If `APP_RUNNING` flag set: print `app is running`, refuse.
3. If `REU_BACKED` flag set: call `vmmFree` on `ReuAddr` and `StackReuAddr` (if `STACK_SAVED`).
4. Call `aptRemove`: zero the slot, decrement `UsedSlots`.
5. Does **not** zero main RAM — the binary may still be at `LoadAddr` in RAM, but the OS no longer tracks it.

---

## Phase C: Service Bus Extension

Four new opcodes added to `api.asm` in Phase C. External programs call these via `jsr $1000` with the opcode in A.

| Opcode | Constant | Behaviour |
|--------|----------|-----------|
| `$60` | `DOS_APP_REGISTER` | `aptRegister` — X/Y = name ptr, ZP = addr/size |
| `$61` | `DOS_APP_FREE` | `aptRemove` by name — X/Y = name ptr |
| `$62` | `DOS_APP_LIST` | Copy table header + all entries into caller-supplied buffer |
| `$63` | `DOS_APP_RUN` | `aptSwapIn` + `jsr` + `aptSwapOut` — X/Y = name ptr |

Calling convention follows existing service bus ABI (carry set on error, A = error code).

---

## Memory Map Impact

No new main RAM regions required. The app table VMM page is allocated dynamically at init. The `apptable.asm` segment is placed between `$1F90` (VmmData) and `$2000` (UserProgStart) — approximately 96 bytes available. If `apptable.asm` code exceeds that gap, UserProgStart shifts up and the `APT_LOAD_BASE` constant is updated in `command64.inc`.

`aptInit` is called from the shell startup sequence immediately after environment block allocation.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `src/command64/apptable.asm` | **Create** | All app table logic and internal API |
| `src/command64/shell.asm` | **Modify** | Add APPS/PS/FREE commands; modify RUN/GO |
| `src/command64/loader.asm` | **Modify** | Call aptRegister after successful LOAD |
| `src/command64/api.asm` | **Modify** (Phase C) | Four new service bus opcodes |
| `include/command64.inc` | **Modify** | APT_* constants, flag bits, Phase C opcodes |
| `build/command64.asm` | **Modify** | Import apptable.asm, assign segment |
| `brain/COMMANDS.md` | **Modify** | Add APPS, PS, FREE |
| `brain/KNOWLEDGE.md` | **Modify** | Document app table VMM allocation, protected ranges |
| `CHANGELOG.md` | **Modify** | Each task |

---

## Open Questions (deferred to implementation)

1. **Stack save size:** Phase C saves `$0100–$01FF` (256 bytes) to REU per app. If stack usage at suspend is shallow, a smaller save window could be used. Implementation can measure and decide.
2. **Segment address:** `apptable.asm` segment TBD — depends on final size of adjacent segments. Confirmed at build time.
3. **aptFind return convention:** Returns slot index in X, carry clear on success; carry set on miss. ZP scratch used for VMM pointer during scan — to be assigned from available ZP space at implementation time.
