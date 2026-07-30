---
feature: casm-dash-wp1-api-contract-freeze
created: 2026-07-26
updated: 2026-07-27
status: complete
---

# Plan: DASH WP1 - API Contract Freeze

## Objective

Freeze the byte-exact public contracts needed by `DASH` for system snapshots and application enumeration. WP1 is a design, specification, and verification work package. It establishes the frozen public API contracts for `$5C DOS_GET_SYSTEM_INFO` and `$5D DOS_GET_APP_INFO` prior to implementation of dispatcher code, include files, unit tests, or application code in subsequent work packages.

Parent plan: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`.

---

## 1. Activation Review & Context

- **Activation Branch**: `feature/casm-dash-wp1-api-contract-freeze`
- **Activation SHA**: `661b2473f543f083ad85400a07185f52baaac274`
- **Scope**: General Public OS ABI (Command 64 OS Jump Table at `$1000`). Not DASH-private.
- **Service Reservations**:
  - `$5C`: `DOS_GET_SYSTEM_INFO`
  - `$5D`: `DOS_GET_APP_INFO`

---

## 2. Reconciled Discrepancies & Frozen Decisions

### Discrepancy 1: Service Numbers
- **Frozen**: `$5C` is assigned to `DOS_GET_SYSTEM_INFO` and `$5D` is assigned to `DOS_GET_APP_INFO`. Both are confirmed unassigned in `include/command64.inc` and `src/command64/api.asm` (highest preceding service is `$5B DOS_RELEASE_L15`).

### Discrepancy 2: Pointer Convention
- **Frozen**: Uniform `X/Y` destination pointer convention for both services:
  - `X` = Buffer pointer low byte (`addr & $FF`)
  - `Y` = Buffer pointer high byte (`addr >> 8`)
  - `DOS_GET_APP_INFO` accepts slot index (0..15) in register `A`.

### Discrepancy 3: Status & Error Codes
- **Frozen**:
  - Success: `Carry = 0`, `A = $00` (`DOS_ERR_OK`).
  - Failure / Empty: `Carry = 1`, `A` contains a non-zero error status code:
    - `$00`: `DOS_ERR_OK` (Success)
    - `$01`: `DOS_ERR_INVALID_INDEX` (App slot index >= 16)
    - `$02`: `DOS_ERR_SLOT_EMPTY` (Requested app slot is unallocated/unused)
    - `$03`: `DOS_ERR_UNAVAILABLE` (App table or VMM subsystem not initialized)
    - `$04`: `DOS_ERR_INVALID_ARG` (Null pointer `$0000` or invalid buffer boundary)

### Discrepancy 4: Failure Writes / Buffer Mutation
- **Frozen**: On any error status (`Carry = 1`), caller's buffer remains **completely unchanged**. Partial record writes, corrupt overwrites, or zeroing on failure are strictly forbidden.

### Discrepancy 5: Version Encoding
- **Frozen (superseded 2026-07-30 for `DOS_GET_SYSTEM_INFO` only, see WP6
  Amendment below)**: Fixed binary version fields in both records:
  - `StructVersion`: `$01` (Version 1 structure layout)
  - `StructSize`: `24` (`$18`, exact 24-byte record length)
  - `OsMajor`: Binary major version byte (`4`)
  - `OsMinor`: Binary minor version byte (`0`)
  - `OsStage`: Binary release stage (`0` = Release, `1` = Dev/Beta)

### Discrepancy 6: Program Limit & User Space
- **Frozen**:
  - `UserProgStart`: Reported from the `UserProgStart` constant, which CMake
    generates from `USER_PROG_START_HEX` into `build_config.inc`. It is a
    build-time value, **not** something that shifts at runtime when a
    relocatable app loads elsewhere. It is `$3800` as of 2026-07-27 and has
    risen repeatedly as resident OS segments grew ($2000 → $2200 → $2600 →
    $2C00 → $3200 → $3400 → $3800). *Corrected 2026-07-27: this line
    previously froze the value as "`$0800` default, or `$3400` when
    relocatable apps shift base". `$0800` was never correct for any shipped
    build, and `tests/src/api/api.s` asserted it verbatim; that test now
    compares against `__MAIN_START__` so it tracks the configured origin.
    Consumers must never hardcode the number.*
  - `UserProgEnd`: Reported as `$BFFF` inclusive (`$C000` exclusive). `$C000-$CFFF` is strictly reserved for MCT / VMM workspace and I/O registers; it is NEVER reported as user space. *Note: this is deliberately not the `UserProgEnd` label in `include/command64.inc`, which is `$CFFF`. The two mean different things — the label covers all remaining RAM, this field reports the last address a user program may occupy.*

### Discrepancy 7: REU Physical RAM vs VMM Logical Semantics
- **Frozen**:
  - Logical MCT allocator counts are reported: 4096 pages total (`VmmTotalPages = 4096`), `VmmAllocPages`, and `VmmFreePages`.
  - `ReuPhysicalRamKB` reports `$0000` in v1.
  - `VmmFlags` bit 0 (`$01`) indicates VMM active (`vmmInitialized != 0`).
  - `VmmFlags` bit 1 (`$02`) indicates physical REU hardware probing (`0` = unprobed/unavailable in v1).

### Discrepancy 8: App Record Name Representation
- **Frozen**: Exact 16-byte field format at offset 8:
  - Byte 0 (offset 8): `NameLen` (1-byte PETSCII string length, 0..15).
  - Bytes 1..15 (offsets 9..23): 15 raw PETSCII character bytes, padded with `$00` up to 15 bytes. Guaranteed non-terminated fixed buffer.

### Discrepancy 9: Running State Lifecycle Strategy
- **Frozen**: `APT_FLAG_RUNNING` (`$02`) in application flags.
  - Set by shell/loader when jumping into an application.
  - Cleared on normal application RTS/return, or automatically by `DOS_EXIT` handler in `api.asm`.

### Discrepancy 10: Register Preservation & Safety Contract
- **Frozen**:
  - Decimal mode (`CLD`) enforced at `apiHandler` entry.
  - `A` returns status code. `X` and `Y` low/high pointers preserved across call.
  - Caller's zero-page workspace (`$70-$8F`) strictly preserved. Internal OS scratch used only within `$61-$6F`.

---

## 3. Public API Specifications

### Service 1: `DOS_GET_SYSTEM_INFO` (`$5C`)

#### Calling Interface
```text
Input:
  A = $5C (DOS_GET_SYSTEM_INFO)
  X = Buffer Pointer Low Byte
  Y = Buffer Pointer High Byte

Output:
  Carry = 0: Success (A = $00, buffer filled with 24-byte record)
  Carry = 1: Failure (A = Error Code, buffer unchanged)
  Registers: X, Y preserved. Decimal mode clear (CLD).
```

#### System Information Record Layout (24 Bytes)

**Superseded by the WP6 Amendment below as of 2026-07-30**: `StructVersion` is
now `$02`, and offset 22 is `OsPatch`, not `Reserved0`. The table below is
kept as the original WP1 record for history; see the Amendment section for
the current layout.

| Offset | Field Name | Size (Bytes) | Type / Encoding | Description |
| ---: | :--- | :---: | :--- | :--- |
| 0 | `StructVersion` | 1 | uint8 | `$01` (Version 1) |
| 1 | `StructSize` | 1 | uint8 | `24` (`$18`, total record length) |
| 2 | `OsMajor` | 1 | uint8 | Major OS version (`4`) |
| 3 | `OsMinor` | 1 | uint8 | Minor OS version (`0`) |
| 4 | `OsStage` | 1 | uint8 | Release stage (`0`=Release, `1`=Dev) |
| 5 | `CurrentDevice` | 1 | uint8 | Active drive device number (8..11) |
| 6 | `VideoStandard` | 1 | uint8 | `0` = NTSC, `1` = PAL (read from `$02A6`) |
| 7 | `UserProgStartLo` | 1 | uint8 | User program start address, low byte |
| 8 | `UserProgStartHi` | 1 | uint8 | User program start address, high byte |
| 9 | `UserProgEndLo` | 1 | uint8 | User program end address low (`$FF`) |
| 10 | `UserProgEndHi` | 1 | uint8 | User program end address high (`$BF` -> `$BFFF`) |
| 11 | `VmmFlags` | 1 | uint8 (bitmask) | Bit 0: VMM Active (`$01`), Bit 1: REU Probed (`$02`) |
| 12 | `VmmPageSizeLo` | 1 | uint8 | VMM page size low (`$00`) |
| 13 | `VmmPageSizeHi` | 1 | uint8 | VMM page size high (`$10` -> 4096 bytes) |
| 14 | `VmmTotalPagesLo`| 1 | uint8 | Logical total pages low (`$00`) |
| 15 | `VmmTotalPagesHi`| 1 | uint8 | Logical total pages high (`$10` -> 4096 pages) |
| 16 | `VmmAllocPagesLo`| 1 | uint8 | Allocated logical pages low |
| 17 | `VmmAllocPagesHi`| 1 | uint8 | Allocated logical pages high |
| 18 | `VmmFreePagesLo` | 1 | uint8 | Free logical pages low |
| 19 | `VmmFreePagesHi` | 1 | uint8 | Free logical pages high |
| 20 | `AppMaxSlots` | 1 | uint8 | Maximum application table slots (`16`) |
| 21 | `AppUsedSlots` | 1 | uint8 | Active occupied application slots count |
| 22 | `Reserved0` | 1 | uint8 | Reserved for alignment/future (`$00`) -- reinterpreted as `OsPatch` by the WP6 Amendment |
| 23 | `Reserved1` | 1 | uint8 | Reserved for alignment/future (`$00`) |

---

### Service 2: `DOS_GET_APP_INFO` (`$5D`)

#### Calling Interface
```text
Input:
  A = $5D (DOS_GET_APP_INFO)
  X = Buffer Pointer Low Byte
  Y = Buffer Pointer High Byte
  HexValLo (ZP $66) or Register A's slot index:
    - Pass requested slot index (0..15) in Register A before calling, or in X/Y parameter block.
    - *Corrected 2026-07-30 (WP7 activation review): this line and the WP3
      implementation notes below previously said ZP `$61`. `HexValLo` is
      `$66` (`HexValHi` is `$67`) in both `include/command64.inc` and
      `include/ca65/command64.inc`; `$61` was never correct. WP3's actual
      `ahGetAppInfo` implementation and its test in `tests/src/api/api.s`
      always used the real `$66` -- only the documentation/comments were
      stale, not the frozen ABI itself.*

Output:
  Carry = 0: Success (A = $00, slot occupied, buffer filled with 24-byte record)
  Carry = 1: Failure (A = Error Code, buffer unchanged)
    - A = $01: DOS_ERR_INVALID_INDEX (Slot index >= 16)
    - A = $02: DOS_ERR_SLOT_EMPTY (Slot unallocated)
    - A = $03: DOS_ERR_UNAVAILABLE (App table uninitialized)
```

#### Application Information Record Layout (24 Bytes)
| Offset | Field Name | Size (Bytes) | Type / Encoding | Description |
| ---: | :--- | :---: | :--- | :--- |
| 0 | `StructVersion` | 1 | uint8 | `$01` (Version 1) |
| 1 | `StructSize` | 1 | uint8 | `24` (`$18`, total record length) |
| 2 | `SlotIndex` | 1 | uint8 | Application slot index (0..15) |
| 3 | `Flags` | 1 | uint8 (bitmask) | Bit 0: Used (`$01`), Bit 1: Running (`$02`), Bit 2: REU (`$04`), Bit 3: Stack (`$08`) |
| 4 | `LoadAddrLo` | 1 | uint8 | Load start address low byte |
| 5 | `LoadAddrHi` | 1 | uint8 | Load start address high byte |
| 6 | `SizeLo` | 1 | uint8 | Application binary size low byte |
| 7 | `SizeHi` | 1 | uint8 | Application binary size high byte |
| 8 | `NameLen` | 1 | uint8 | PETSCII application name length (0..15) |
| 9..23 | `NameData` | 15 | uint8[15] | Raw PETSCII name characters, padded with `$00` |

---

## 4. Technical Directives for CASM Implementations (WP4 - WP8)

When implementing `DASH` source files in CASM:
1. **No String Literals**: CASM lacks `"string"` syntax. All text strings must be declared as `.BYTE` sequences:
   ```asm
   // PETSCII string "SYSTEM"
   .byte $53, $59, $53, $54, $45, $4D
   ```
2. **No Multi-file `.INCLUDE`**: Top-level source files must be specified as explicit ordered arguments to the CASM assembler command line.
3. **No Indirect `JSR`**: Dispatch tables inside relocatable apps must use indexed tables or vector jumps (`JMP (vec)`), not `JSR (vec)`.
4. **Relocatable Symbol Boundaries**: Absolute memory addresses within `DASH` must go through CASM R6 relocation table generation. Jump table calls to OS API `$1000` are fixed absolute addresses outside the relocatable segment.

---

## 5. Downstream Work Package Dependencies

- **WP2 (System Information API)**: Implements `DOS_GET_SYSTEM_INFO` (`$5C`) in `src/command64/api.asm` & exports constants in `include/command64.inc` / `include/ca65/command64.inc`.
- **WP3 (Application Query API)**: Implements `DOS_GET_APP_INFO` (`$5D`) in `src/command64/api.asm` and maintains `APT_FLAG_RUNNING` in `apptable.asm` / `shell.asm`.
- **WP4 (Relocatable Skeleton)**: Assembles the multi-file native CASM `DASH` binary.
- **WP5 - WP8 (UI & Dashboard Pages)**: Implements the System, Applications, and VMM test pages using the frozen WP1 contract.

---

## 6. Verification Matrix

| Verification Check | Target / Criterion | Result |
| :--- | :--- | :--- |
| System Record Offset Sum | Offset 0 to 23 = exactly 24 bytes | PASS (Verified) |
| App Record Offset Sum | Offset 0 to 23 = exactly 24 bytes | PASS (Verified) |
| Unassigned Service Numbers | `$5C` and `$5D` verified free in `api.asm` & `command64.inc` | PASS (Verified) |
| Little-Endian Specification | All 16-bit fields (`UserProgStart`, `UserProgEnd`, `VmmPageSize`, `VmmTotalPages`, `VmmAllocPages`, `VmmFreePages`, `LoadAddr`, `Size`) explicitly marked little-endian | PASS (Verified) |
| Buffer Mutation on Failure | Guaranteed unchanged on `Carry = 1` | PASS (Verified) |

---

## 7. WP6 Amendment (2026-07-30): Live OS Version Fields

`DASH`'s System page (WP6) is the WP referenced by
[[project-dash-version-literal-deferred]] / Task Warrior #41: `OsMajor`,
`OsMinor`, and `OsStage` in `ahGetSystemInfo` were hardcoded immediates
(`4`, `0`, `0`), disconnected from the repository's actual `VERSION` file
(`0.4.1` as of this amendment). Fixing that is in WP6's scope, not a
follow-up, per the 2026-07-30 deferral decision. This amendment covers
`DOS_GET_SYSTEM_INFO` (`$5C`) only; `DOS_GET_APP_INFO` (`$5D`) is unaffected.

Decisions (confirmed with the user 2026-07-30):

- **`StructVersion` bumps `$01` -> `$02`.** Offset 22 (`Reserved0`) changes
  meaning to `OsPatch`, and although `StructSize` doesn't change, this is
  still treated as a structure-version bump so a caller checking
  `StructVersion` can detect the new field is defined.
- **Offset 22 is now `OsPatch`** (uint8, binary patch version byte). Offset
  23 (`Reserved1`) is untouched, still reserved.
- **`OsMajor`/`OsMinor`/`OsPatch` are now derived from the repository's
  `VERSION` file** (`MAJOR.MINOR.PATCH[-dev]`), parsed by CMake into the
  Kick-dialect `.const` values `OsVersionMajor`/`OsVersionMinor`/
  `OsVersionPatch`/`OsVersionStage` in the generated `build_config.inc`
  (see WP2's existing `UserProgStart` generation for precedent), rather than
  hardcoded immediates in `api.asm`.
- **`OsStage` is now derived from an optional `-dev` suffix on `VERSION`**
  (`0.4.1` -> Release/`$00`; `0.4.1-dev` -> Dev/`$01`), rather than staying a
  permanent `$00` literal. No prior CMake build-type concept existed for
  this; the `-dev` suffix on `VERSION` is the new source of truth.

### Amended System Information Record Layout (24 Bytes, StructVersion `$02`)

| Offset | Field Name | Size (Bytes) | Type / Encoding | Description |
| ---: | :--- | :---: | :--- | :--- |
| 0 | `StructVersion` | 1 | uint8 | `$02` (Version 2) |
| 1 | `StructSize` | 1 | uint8 | `24` (`$18`, total record length, unchanged) |
| 2 | `OsMajor` | 1 | uint8 | Major OS version, from `VERSION` |
| 3 | `OsMinor` | 1 | uint8 | Minor OS version, from `VERSION` |
| 4 | `OsStage` | 1 | uint8 | Release stage (`0`=Release, `1`=Dev), from `VERSION`'s `-dev` suffix |
| 5-21 | *(unchanged)* | | | See Section 3 table above |
| 22 | `OsPatch` | 1 | uint8 | Patch OS version, from `VERSION` (formerly `Reserved0`) |
| 23 | `Reserved1` | 1 | uint8 | Reserved for alignment/future (`$00`), unchanged |
