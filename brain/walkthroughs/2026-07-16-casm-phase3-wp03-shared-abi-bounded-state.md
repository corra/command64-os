---
feature: casm-phase3-wp03-shared-abi-bounded-state
completed: 2026-07-16
status: completed
---

# Walkthrough: CASM Phase 3 WP3 Shared ABI and Bounded State

## Summary

WP3 freezes the shared Phase 3 source/lexer ABI and adds bounded persistent
state without activating source or lexer behavior. `common.inc` now declares
source results/states, token types and subtypes, token-record offsets, explicit
PETSCII bytes, diagnostic reservations, and `$80-$83` scratch aliases.
Storage-only `state.s` owns exactly 63 BSS bytes and emits no code.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/common.inc` | Shared ABI | Constants, offsets, diagnostics, assertions |
| `src/external/casm/state.s` | Bounded BSS | 16-byte source plus 47-byte lexer subrecords |
| `src/external/casm/AGENTS.md` | Local DOX | Durable state and single-buffer ownership |
| `brain/plans/2026-07-16-casm-phase3-source-stream-lexer.md` | Parent plan | Records WP3 `state.s` ownership |
| `brain/plans/2026-07-16-casm-phase3-wp03-shared-abi-bounded-state.md` | Detailed plan | Approved implementation and dependency gates |
| `wiki/tasks/casm.md` | Task state | WP3 remains in progress pending completion |
| `brain/task.md` | Task mirror | Matches Taskwarrior and wiki state |
| `brain/KNOWLEDGE.md` | Decision | Frozen ABI and buffer ownership |
| `brain/MEMORY.md` | Measurement | Build 1017 size and headroom |
| `CHANGELOG.md` | Change record | WP3 bounded state, no runtime activation |

## ABI and Static Verification

- Existing Phase 1/2 diagnostic and state values remain unchanged.
- Source results are distinct and nonzero.
- Token types occupy exactly `$00-$0F`.
- Mnemonic subtype range is exactly 0-55.
- Token record is exactly 39 bytes: seven-byte header plus 32-byte text.
- Source state is exactly 16 bytes.
- Lexer/lookahead/token state is exactly 47 bytes.
- Combined `state.s` BSS is exactly 63 bytes.
- New scratch aliases occupy only `$80-$83`; `$84-$8F` remains reserved.
- `state.s` has zero CODE, RODATA, DATA, and ZP bytes and no executable path.
- No second 256-byte buffer exists.
- `git diff --check` passes.

## Build and Artifact Results

- `cmake -S . -B build`: passed.
- `cmake --build build --target casm`: passed as build 1017.
- No-change CASM rebuild preserved build 1017.
- Linked code/data: 2,256 bytes.
- Total BSS: 512 bytes, exactly 63 bytes above the Phase 2 baseline.
- Combined `$1000` envelope headroom: 1,328 bytes.
- Relocation points: 241.
- Base/next PRGs: 2,258 bytes each.
- Final R6 PRG: 2,746 bytes, load address `$3400`.
- R6 footer: `00 34 F1 00 52 36`.
- `state.s` appears once in each link manifest.
- `cmake --build build --target image_d64`: passed.
- Release disk contains all nine shipping files and CASM remains an 11-block
  PRG.

## Version-Bump Verification

- User approved the completion candidate on 2026-07-16.
- CASM advanced from `0.1.4` to `0.1.5`.
- Final build is 1018; a no-change rebuild preserved 1018.
- Linked code/data remains 2,256 bytes with 512 total BSS bytes.
- `state.o` remains 63 BSS bytes with zero CODE, RODATA, DATA, and ZP.
- Final PRG remains 2,746 bytes at `$3400` with 241 relocations and footer
  `00 34 F1 00 52 36`.
- Rebuilt `image_d64` contains all nine shipping applications and CASM remains
  an 11-block PRG.

## Manual Confirmation Before Version Bump

Review:

1. `common.inc` source/token constants and compile-time assertions.
2. `state.s` exports and the exact 16/47/63-byte boundaries.
3. The absence of executable segments or runtime initialization in `state.s`.
4. The measured 1,328-byte remaining envelope headroom.
5. WP4/WP7 ownership of future `source.s` and `lexer.s`.

The user approved the WP3 completion candidate on 2026-07-16. CASM then
advanced from `0.1.4` to `0.1.5`. The final runtime gate is confirmation of the
`0.1.5` banner and safe return to an intact shell in a supported local emulator
or on hardware.

## Completion Status

The user confirmed the final runtime matrix on 2026-07-16: banner
`CASM V0.1.5.1018`, expected `SOURCE REQUIRED` diagnostic, safe shell return,
working `DIR`, and a second safe CASM launch. Implementation, automated
verification, completion-candidate approval, version bump, and runtime
verification are complete. The user explicitly authorized marking WP3 complete
on 2026-07-16.
