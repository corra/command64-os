---
feature: casm-phase6-wp23-vmm-allocation-core
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 6A WP23 VMM Allocation Core

Plan: `brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`

Taskwarrior: `8782e75d-d935-4e15-bf3c-d0488a1533a8`

## Outcome

WP23 creates `vmm_store.s` (`vmmStoreAlloc`/`vmmStoreFree`), wires real
`DOS_ALLOC_MEM`/`DOS_FREE_MEM` calls behind the existing central resource
registry, and replaces `cleanupVmmStub`'s no-op-on-REU behavior with a real
free that retries on failure. It implements no windowed transfer (WP24) and
no runtime fixture (WP25), matching the plan's scope.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp23` |
| Branch point | `feature/casm-phase6-wp22` at `d0878d6` |
| Baseline version | `0.1.24.1095` |
| Plan approval | User approved the WP23 plan as drafted; the fixture question was resolved as static verification only (no runtime fixtures in WP23) |

## ABI Decisions Finalized During Implementation

The plan left exact register/flag/scratch contracts and the byte-count-to-
paragraph conversion for implementation time. Two points needed resolving
before writing code, both confirmed with the user:

- **No separate "too large" rejection.** `vmmStoreAlloc`'s requested size
  arrives as a 16-bit `X`/`Y` byte count (max 65,535). Converting to
  `DOS_ALLOC_MEM` paragraphs via `ceil(byteCount / 16)` never exceeds 4,096
  paragraphs (= 65,536 bytes = the addressing cap) for any 16-bit input, so
  the cap can never actually be exceeded by a legal request. The real hazard
  was different: the naive "add 15, then shift right 4" rounding trick
  overflows 16-bit arithmetic for byte counts 65,521-65,535, which would
  otherwise wrap to a wrong, near-zero paragraph count. `vmmStoreAlloc`
  checks the carry out of that add and, when set, uses the proven-exact
  result (4,096 paragraphs) directly instead of the wrapped value. No request
  is ever rejected as "too large"; `CASM_DIAG_VMM_ALLOC_TOO_LARGE`, named in
  the plan's proposed ABI, was dropped as unreachable.
- **Zero-size requests are rejected locally**, before any OS call, mapped to
  `CASM_DIAG_VMM_ALLOC_FAILED`. This is what lets a later `VMM_ERR_INVALID`
  from `DOS_ALLOC_MEM` be trusted to mean "no REU / not initialized" rather
  than "zero-paragraph request" — the ambiguity WP22 identified.

Two register-clobber bugs were found and fixed while writing `vmm_store.s`
against these decisions, before any build was attempted:

- `vmmStoreFree` originally reused `CasmValue0Lo` for both the input slot
  number and the SegHi staging value, destroying the slot before the final
  `resourceReleaseVmm` call. Fixed by staging SegHi/Bank in the dedicated
  `CasmVmmSegHi`/`CasmVmmBank` zero-page pair (reserved for exactly this by
  WP22) and keeping `CasmValue0Lo` dedicated to the slot number throughout.
- `resources.s`'s `resourcesCleanup` VMM loop relied on `X` surviving across
  `jsr vmmStoreFree`, but `vmmStoreFree`'s own contract documents `X` as
  clobbered. Fixed using the same `CasmCleanupOffset` scratch-preservation
  pattern the file-registry loop already uses across `cleanupFileRecord`.

## Implementation

- `common.inc`: added `CASM_VMM_ALLOC_MAX_BYTES = 65536` and diagnostics
  `$28`-`$2B` (`CASM_DIAG_VMM_UNAVAILABLE`/`_ALLOC_FAILED`/`_FREE_FAILED`/
  `_TRANSFER_FAILED`, the last reserved for WP24), each with a
  contiguous-range `.assert` following the existing per-phase pattern.
- `vmm_store.s` (new): `vmmStoreAlloc` wires `DOS_ALLOC_MEM` ($48) and
  registers the result through `resourceRegisterVmm`; if registration fails
  (registry full) after a successful OS grant, it frees the just-granted
  memory again rather than leak it, then reports `CASM_DIAG_VMM_ALLOC_FAILED`.
  `vmmStoreFree` wires `DOS_FREE_MEM` ($49) using a registry slot's stored
  SegHi/Bank (read via the now-exported `CasmVmmRegistry`), is idempotent on
  an already-free slot, and leaves an owned slot untouched on a rejected
  `DOS_FREE_MEM` so a later cleanup pass can retry it.
- `resources.s`: exported `CasmVmmRegistry` (read-only from `vmm_store.s`'s
  side; all writes still go through `resourceRegisterVmm`/`resourceReleaseVmm`
  ). Replaced `cleanupVmmStub` with a real `vmmStoreFree` call per registry
  slot in `resourcesCleanup`, and removed the unconditional `CasmVmmCount`
  reset that followed it — `CasmVmmCount` is now maintained incrementally
  (via `resourceReleaseVmm`'s own decrement), matching `CasmFileCount`'s
  existing pattern, so a failed free is reflected accurately for retry.

No parser, emitter, lexer, opcode, expr, state, or fixture file changed.

## MAIN Envelope Measurement

The plan predicted overflow past the $2A00 envelope's 243-byte pre-WP23
headroom (matching the WP13/WP19 precedent of measuring rather than
estimating). The measured result was the opposite:

| Item | Result |
| --- | --- |
| `vmm_store.o` | 144 CODE, 0 BSS/RODATA/DATA/ZEROPAGE |
| `resources.o` | 416 CODE, 47 BSS (unchanged registry size) |
| Total CODE+RODATA | 9,504 bytes |
| Total BSS | 1,143 bytes (unchanged from the WP19/WP22 baseline) |
| MAIN envelope | 10,647 / 10,752 bytes; **105 bytes free** |
| Relocation bases | `$3400`/`$3500` both link without warning/error |
| Relocation points | 1,276 |

**Proposed MAIN size: no change.** $2A00 already covers WP23 with headroom
to spare. The user confirmed proceeding on this basis without a
`CMakeLists.txt` edit.

Disclosed side effect: `tests/src/casm_expr/BUILD_TEST_CASM_EXPR` incremented
(1005->1006) because that test harness hash-gates on `common.inc`, which
WP23 changed. No logic in that harness changed.

## Static Verification

- `od65 --dump-segsize vmm_store.o`: CODE only (144 bytes); no unauthorized
  RODATA/DATA/ZEROPAGE/BSS.
- `od65 --dump-imports/--dump-exports vmm_store.o resources.o`: `vmm_store.o`
  imports exactly `CasmVmmRegistry`, `resourceRegisterVmm`,
  `resourceReleaseVmm`, and exports exactly `vmmStoreAlloc`/`vmmStoreFree`;
  `resources.o`'s new export (`CasmVmmRegistry`, size 24 = unchanged
  `CASM_VMM_REGISTRY_BYTES`) and new import (`vmmStoreFree`) are the only
  additions. No accidental symbol/pass/relocation code.
- `common.inc`'s `$28`-`$2B` contiguous-range and single-allocation-cap
  `.assert`s pass at build time (a failure would abort the build).
- `CASM_ZP_SIZE` remains asserted at 32 bytes; WP23 claims no new zero-page
  byte (only stages through the already-reserved `CasmVmmSegHi`/`CasmVmmBank`
  ).
- The CASM-level zero-size rejection is reachable code (verified by reading
  the object, since WP23 has no runtime fixture): it precedes the
  `DOS_ALLOC_MEM` call unconditionally.

## Automated Verification

- `cmake -S . -B build`: pass.
- `cmake --build build --target casm`: pass at both bases; `BUILD_CASM`
  1095 -> 1096 (real content change).
- `cmake --build build --target test_image_d64` / `image_d64`: both pass at
  the `0.1.24.1096` candidate; CASM is 48 blocks.
- Candidate PRG SHA-256: `635676ef68122dc8a1fcedfef3bb87fb74830570e0fbfa4ca936ab76881e056a`.

### Completion Dry-Run (`0.1.24` -> `0.1.25`)

| Measurement | Candidate (`0.1.24.1096`) | Dry run (`0.1.25.1097`) |
| --- | ---: | ---: |
| `BUILD_CASM` | 1096 | 1097 |
| PRG SHA-256 | `635676ef...056a` | `0d26b2d2...2af6` |

- `BUILD_CASM` incremented exactly once (1096 -> 1097) on the dry-run edit.
- Immediate no-change rebuild: stable at 1097 (no second increment).
- `cmp -l` reported exactly two changed bytes, at one-based offsets 7418 and
  7423: the version-stage digit (`'4' -> '5'`) and the build-number digit
  (`'6' -> '7'`). No functional payload, storage, or relocation count
  changed.
- `test_image_d64` / `image_d64`: both pass at the `0.1.25.1097` dry-run
  state.
- Restoration via `git checkout -- src/external/casm/casm.s` plus restoring
  `BUILD_CASM` to its candidate content: rebuild reproduced the candidate PRG
  hash exactly (`635676ef...056a`), confirmed twice. Both images pass again
  at the restored candidate baseline.
- `git diff --check`: pass.
- No prohibited C64-testing MCP or web emulator used.

## DOX Closeout

Root, `src`, `src/external`, `src/external/casm`, `wiki`, and `wiki/tasks`
contracts rechecked. No `AGENTS.md` changed: WP23 introduces no new directory
boundary or durable operating rule beyond what the WP22-frozen Phase 0C.4
contract in `brain/KNOWLEDGE.md` already covers.

## Manual Confirmation

WP23 implements no allocation call site and no new command-line behavior —
CASM's observable behavior (banner aside) is unchanged, since nothing in the
shipped build yet calls `vmmStoreAlloc`. One path does run unconditionally on
every CASM exit today, though: `resourcesCleanup`'s VMM loop, rewired from
the old no-op `cleanupVmmStub` to call the real `vmmStoreFree` per registry
slot. Since no allocation ever exists yet, every slot hits the idempotent
already-free path with no OS call — provable by inspection, but not
previously exercised on real hardware/VICE. The user ran CASM in the
supported local VICE environment against a trusted-reference source fixture
(matching the `CASM CASMEXPRN`/`CASM CASMHELLO` invocation pattern from the
WP20/WP21 precedent) and confirmed it still assembles and exits cleanly,
unchanged from pre-WP23 behavior. WP25 owns the full runtime fixture matrix
that will exercise real allocation/free/exhaustion behavior.

## Approval

The user confirmed the VICE sanity check passed and explicitly approved WP23
completion.

## Final Increment (post-approval)

| Measurement | Value |
| --- | --- |
| Applied version | `0.1.25` |
| Build number | 1097 |
| PRG SHA-256 | `0d26b2d2218242a94354d425dc2a9ad3f8bfee9726a3f99ff999245fc9e42af6` (matches the dry run exactly) |
| No-change rebuild | pass, held at 1097 across two additional rebuilds |
| `test_image_d64` | pass |
| `image_d64` | pass |

WP23 is complete. Taskwarrior (`8782e75d`), `wiki/tasks/casm.md`, and
`brain/task.md` are marked done. WP24 (`228daccc-f389-48cf-bd52-9f1ac610234a`)
is unblocked but requires its own separate plan approval before activation.
