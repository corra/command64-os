---
feature: casm-phase6-wp24-windowed-transfer-and-replay
created: 2026-07-22
status: complete
---

# Walkthrough: CASM Phase 6A WP24 Windowed Transfer and Replay

Plan: `brain/plans/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md`

Taskwarrior: `228daccc-f389-48cf-bd52-9f1ac610234a`

## Outcome

WP24 implements bounded `DOS_VMM_READ`/`DOS_VMM_WRITE` windowed transfer
wrappers (`vmmWindowRead`/`vmmWindowWrite`) and a deterministic replay
routine (`vmmReplay`) over a registered VMM allocation. It resolves a real
gap the WP22 freeze left open: the mandated per-allocation bounds check had
no registry field to read a granted size from. It implements no symbol,
hash, or Pass 1/Pass 2 code and no fixture matrix (WP25 owns that).

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp24` |
| Branch point | `feature/casm-phase6-wp23` at `42968f0` |
| Plan drafted from | `a60cb89` (both open questions resolved) |
| Baseline version | `0.1.25.1097` |
| Plan approval | Approved as drafted, including both resolved open questions |

## Reconciliation Findings (from plan drafting)

- **Registry growth.** `CasmVmmRegistry`'s 3-byte record had no field for an
  allocation's granted size, which the Phase 0C.4 freeze requires WP24 to
  bounds-check transfers against. Grew `CASM_VMM_REC_SIZE` from 3 to 4 bytes,
  adding `CASM_VMM_REC_PAGES` (granted 4KB-page count, 1-16), computed in
  `vmmStoreAlloc` identically to `vmmAlloc`'s own paragraph-to-page rounding.
  `resourceRegisterVmm` gained a third input (page count, staged via
  `CasmValue1Lo`) and remains the registry's sole writer. Bonus: the
  slot-to-byte-offset computation simplified from `ASL`+`ADC` (`slot*3`) to
  two plain `ASL`s (`slot*4`) in both `resources.s` and `vmm_store.s`.
- **OS zero-page ABI.** `DOS_VMM_READ`/`DOS_VMM_WRITE` take their
  Seg/Off/Bank/count arguments through fixed OS zero-page cells
  (`VmmSegLo/Hi`, `VmmOffLo/Hi`, `VmmBank`, `HexValLo/Hi`), not registers —
  confirmed against the working precedent already in
  `src/external/edlin/buffer.s`.
- **Staging.** Reused CASM's already-reserved `$78-$7F` I/O/VMM transfer
  scratch (`CasmVmmOffLo/OffHi` for the offset input, `CasmIoLenLo/Hi` for
  the byte count, matching that group's own "I/O and VMM transfer scratch"
  documentation) — no new zero-page byte was claimed.
- **Dedicated staging buffer.** Added `CasmVmmBuffer` (32 bytes, fixed size
  decided at implementation time per the user's deferral), matching
  `CasmIoBuffer`'s precedent of a single named, owned buffer rather than an
  arbitrary caller-supplied pointer. `CasmIoBuffer` itself stays reserved for
  source input, as already documented.
- **Diagnostic reuse.** A local bounds violation and a genuine OS-level
  transfer rejection share `CASM_DIAG_VMM_TRANSFER_FAILED` ($2B), per the
  user's decision — keeping Phase 6A's diagnostic count at four.

## Implementation

- `common.inc`: `CASM_VMM_REC_SIZE` 3->4 (`CASM_VMM_REC_PAGES` added),
  `CASM_VMM_PAGE_BYTES` (4096), `CASM_VMM_BUFFER_SIZE` (32), each with a
  build-time `.assert`.
- `resources.s`: `resourceRegisterVmm` accepts and stores the page count;
  `resourceReleaseVmm`'s slot-offset math simplified to `slot*4` and now also
  clears `CASM_VMM_REC_PAGES`; `resourcesInit`'s VMM loop zeroes the new
  field too.
- `vmm_store.s`:
  - `vmmStoreAlloc` derives the granted page count from the exact paragraph
    count just requested (survives the OS call untouched) as the high byte
    of `(paragraphs + 255)`, mirroring `vmmAlloc`'s own rounding, and passes
    it to `resourceRegisterVmm`. No change to `vmmStoreAlloc`'s own external
    ABI.
  - `vmmStoreFree`'s slot-offset math simplified to `slot*4`.
  - New private `vwPrepareTransfer`: bounds-checks (in order) slot range,
    byte count against the fixed buffer size, slot ownership (a
    freed/unregistered slot is rejected, matching the `vmmfree1` fixture
    intent), `offset + count` 16-bit overflow, and the transfer's required
    page count against the slot's granted `CASM_VMM_REC_PAGES` — all before
    staging the OS's zero-page cells or touching `DOS_VMM_READ`/`WRITE`. The
    page-count comparison avoids ever representing 65536 as a 16-bit value
    (the same hazard `vmmStoreAlloc` worked around): `NeededPages = ceil((
    offset+count)/4096)` is computed as a top-nibble extraction plus a
    round-up check, never an addition that could itself overflow.
  - New `vmmWindowRead`/`vmmWindowWrite`: call `vwPrepareTransfer`, then
    `DOS_VMM_READ`/`DOS_VMM_WRITE` against `CasmVmmBuffer`.
  - New `vmmReplay`: `vmmWindowWrite`, zero-fill `CasmVmmBuffer`, then
    `vmmWindowRead` — the mechanical write/discard/read steps of Phase 6A's
    completion-gate wording. Comparison against the original pattern is left
    to the caller (WP25's fixtures).
- `CMakeLists.txt`: CASM MAIN `$2A00` -> `$2B00` (measured overflow, see
  below); updated the accumulated size-history comment on that line.

No parser, emitter, lexer, opcode, expr, state, or fixture file changed.

## MAIN Envelope Measurement

| Item | Result |
| --- | --- |
| `vmm_store.o` | 325 CODE, 32 BSS (`CasmVmmBuffer`), no RODATA/DATA/ZEROPAGE |
| `resources.o` | 423 CODE, 55 BSS (+8 bytes: 8 slots x 1 new page-count byte) |
| Total CODE+RODATA | 9,692 bytes |
| Total BSS | 1,183 bytes |
| MAIN needed | 10,875 bytes |
| Overflow at `$2A00` (10,752 bytes) | 123 bytes |
| **Approved new size** | **`$2B00`** (11,008 bytes; 133 bytes free) |
| Relocation bases | `$3400`/`$3500` both link cleanly at `$2B00` |
| Relocation points | 1,291 |

## Static Verification

- `od65 --dump-segsize vmm_store.o`: 325 CODE, 32 BSS, no RODATA/DATA/
  ZEROPAGE — the BSS is exactly the new dedicated buffer, no unauthorized
  growth.
- `od65 --dump-imports/--dump-exports vmm_store.o`: imports exactly
  `CasmVmmRegistry`, `resourceRegisterVmm`, `resourceReleaseVmm`; exports
  exactly `vmmStoreAlloc`, `vmmStoreFree`, `vmmWindowRead`, `vmmWindowWrite`,
  `vmmReplay`, `CasmVmmBuffer` (size 32). The private `vwPrepareTransfer` is
  correctly not exported.
- `od65 --dump-exports resources.o`: `CasmVmmRegistry` now size 32 (8 x 4),
  matching `CASM_VMM_REC_SIZE`'s growth exactly.
- `common.inc`'s registry-size, page-byte, and buffer-size `.assert`s pass at
  build time (a failure would abort the build).
- `CASM_ZP_SIZE` remains asserted at 32 bytes — no zero-page growth; WP24
  reused already-reserved `$78-$7F` cells only.
- `$28`-`$2B` diagnostic contiguity assert unchanged and still passes; no new
  diagnostic value was needed.
- `cmake --build build --target test_image_d64` / `image_d64`: both pass at
  the `0.1.25.1098` candidate; CASM is 49 blocks.
- Candidate PRG SHA-256: `4de408b726bc94bfca877d82985139379792f79427b59178ec8cd1f862840a00`.

### Completion Dry-Run (`0.1.25` -> `0.1.26`)

| Measurement | Candidate (`0.1.25.1098`) | Dry run (`0.1.26.1099`) |
| --- | ---: | ---: |
| `BUILD_CASM` | 1098 | 1099 |
| PRG SHA-256 | `4de408b7...840a00` | `95460c3d...677246` |

- `BUILD_CASM` incremented exactly once (1098 -> 1099) on the dry-run edit.
- Immediate no-change rebuild: stable at 1099 (no second increment).
- `cmp -l` reported exactly two changed bytes, at one-based offsets 7606 and
  7611: the version-stage digit (`'5' -> '6'`) and the build-number digit
  (`'8' -> '9'`). No functional payload, storage, or relocation count
  changed.
- `test_image_d64` / `image_d64`: both pass at the `0.1.26.1099` dry-run
  state.
- Restoration via `git checkout -- src/external/casm/casm.s` plus restoring
  `BUILD_CASM` to its candidate content: rebuild reproduced the candidate PRG
  hash exactly (`4de408b7...840a00`). Both images pass again at the restored
  candidate baseline.
- `git diff --check`: pass.
- No prohibited C64-testing MCP or web emulator used.

## DOX Closeout

Root, `src`, `src/external`, `src/external/casm`, `wiki`, and `wiki/tasks`
contracts rechecked. No `AGENTS.md` changed: WP24 introduces no new
directory boundary or durable operating rule; the registry-growth decision
and OS zero-page ABI are recorded in `brain/KNOWLEDGE.md`/the plan, which are
the correct homes for them.

## Manual Confirmation

No production call site yet reaches `vmmWindowRead`/`vmmWindowWrite`/
`vmmReplay` (WP25 owns the fixture matrix that will exercise them). As with
WP23, `resourcesCleanup`'s VMM loop runs unconditionally on every CASM exit
and now touches a 4-byte record instead of 3; the user ran CASM in the
supported local VICE environment against a trusted-reference source fixture
and confirmed it still assembles and exits cleanly, unchanged from
pre-WP24 behavior.

## Approval

The user confirmed the VICE sanity check passed, approved the MAIN size
measurement/proposal (`$2A00` -> `$2B00`), and explicitly approved WP24
completion.

## Final Increment (post-approval)

| Measurement | Value |
| --- | --- |
| Applied version | `0.1.26` |
| Build number | 1099 |
| PRG SHA-256 | `95460c3d4cc6bda82b39773d86ab9c0bf64a17c4fcc2503191ac4f8949677246` (matches the dry run exactly) |
| No-change rebuild | pass, held at 1099 across two additional rebuilds |
| `test_image_d64` | pass |
| `image_d64` | pass |

WP24 is complete. Taskwarrior (`228daccc`), `wiki/tasks/casm.md`, and
`brain/task.md` are marked done. WP25 (`544a04bd-4ccb-47c6-9013-8af57aa37353`)
is unblocked but requires its own separate plan approval before activation.
