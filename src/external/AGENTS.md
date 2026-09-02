# Purpose

The purpose of the `src/external` directory is to contain external user space applications and utilities for the command64 operating system (e.g., `debug`, `label`).

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- All external applications must run in user space (currently starts at `$3800`; use `UserProgStart` rather than hardcoding an address).
- Every external application target must enforce build-time versioning through the unified CMake app helpers: `add_external_app` for KickAssembler apps or `add_ca65_app` for ca65/ld65 apps.
- A persistent build number file `BUILD_<APPNAME_UPPER>` containing the current build number must be maintained in the application's own `src/external/<appname>/` directory.
- App-private zero-page scratch allocations may use `$70-$8F`. Collisions between separately loaded apps are acceptable only because external apps are not concurrently resident; document any new allocation in the app source and avoid clobbering OS-owned zero-page locations.
- ca65 multi-file apps that share zero-page symbols across object-file boundaries must use `.exportzp` and `.importzp`; plain `.export`/`.import` treats the symbol as absolute and can emit incorrect three-byte absolute instructions.
- For a CASM-native app, the checked-in `<app>.ref.hex` manifest is a machine-integrity record; correctness is proven by an independent, peer-reviewed byte/relocation derivation record under `src/external/<app>/`, per `.agents/workflows/canonical-byte-oracles.md`. A ca65 differential check is optional and non-authoritative. ca65/ld65 stays required for `casm` itself, `debug`, and every non-CASM-native app.

# Work Guidance

## Workflow for Adding New KickAssembler External Applications

1. **Directory Setup**: Create a subdirectory `src/external/<appname>/`. Place all source assembly files inside it (e.g., `<appname>.asm`).
2. **Build File**: Create a persistent file `BUILD_<APPNAME_UPPER>` in the app directory. Initialize it with a starting build number (typically `1000\n`).
3. **Assembly Versioning Integration**:
   - Define version constants (`VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_STAGE`) in the entry assembly file.
   - Import the generated build file: `#import "build_<appname>.inc"`.
   - Incorporate the `BUILD_NUMBER` constant in the printed version header (e.g., `.text "NAME v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER`).
4. **CMake Target**:
   - Discover source files and entry point in `CMakeLists.txt`.
   - Add the target using: `add_external_app(<appname> "${<APPNAME_UPPER>_ENTRY}" <APPNAME_UPPER>_SRCS <DEFAULT_BUILD>)`.
   - Add the target to the disk image list `IMAGE_PRG_TARGETS`.

## Workflow for Adding New ca65/ld65 External Applications

1. **Directory Setup**: Create a subdirectory `src/external/<appname>/`. Place the entry source and any app-local `.s`/`.inc` files inside it.
2. **Build File**: Create a persistent file `BUILD_<APPNAME_UPPER>` in the app directory. Initialize it with a starting build number (typically `1000\n`).
3. **Assembly Versioning Integration**:
   - Define version constants (`VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_STAGE`) using preprocessor text macros (`.define`) in the entry assembly file (e.g. `.define VERSION_STAGE "0"`).
   - Include the shared app API with `.include "command64.inc"`; `add_ca65_app` already passes `-I include/ca65`.
   - Include the generated build file when a printed version banner needs `BUILD_NUMBER`; `add_ca65_app` emits ca65 syntax (`.define BUILD_NUMBER "<n>"`).
4. **CMake Target**:
   - Discover the app entry file and glob the app's `.s`/`.inc` files along with shared `include/ca65/*.inc` dependencies.
   - Add the target using: `add_ca65_app(<target> "${ENTRY}" <SOURCES_VAR> <DEFAULT_VERSION> <PRG_SIZE_HEX> [CODE_ALIGN])`.
   - Use `PRG_SIZE_HEX` for the link-time `MAIN` memory size and optional `CODE_ALIGN` only when the app embeds data that must stay page-aligned.
   - Add the target to the disk image list `IMAGE_PRG_TARGETS`.

## Workflow for a CASM-Native External Application (No Host Assembler)

Proven twice now — BANNER (`brain/plans/2026-08-20-banner-casm-native-migration.md`)
and DASH's own further Phase 12 syntax pass — for an app that is assembled
only by the real native CASM assembler, never by a host toolchain:

1. **Source Setup**: Write the app in documented CASM syntax — a
   CASM-native app is **not** restricted to a ca65 intersection. (A ca65
   cross-check is optional differential evidence only; if an app keeps one,
   `src/external/dash/AGENTS.md`'s "Dual-Assembler Subset" lists the extra
   rules that shared source then obeys.) All uppercase ASCII —
   `scripts/check_casm_source_bytes.py` enforces this at packaging time,
   including inside comments and character/string literals, because
   `cc1541 -w` copies host bytes verbatim with no PETSCII translation.
2. **Dedicated Test Disk**: Package a CASM-only `.d64` (not `test.d64` —
   see `.agents/workflows/per-phase-test-images.md`) with `command64`,
   `casm`, and the app's source as SEQ file(s).
3. **Live Assembly**: Boot the disk in VICE, dispatch
   `CASM <ENTRY>.S /O:<NAME>`, per `.agents/workflows/vice-mcp-testing.md`.
   Confirm `CASM: INPUT VALIDATED` and functionally exercise the app.
4. **Derive and Review**: Detach the disk cleanly (flushes VICE's
   write-behind cache), extract the assembled PRG with `cc1541 -X`. The
   correctness oracle is an **independent byte/relocation derivation** —
   load address, program extent, relocation eligibility and exclusions,
   ordered relocation offsets/count, footer, byte count, hashes — worked
   out from the 6502/6510 encoding, CASM semantics, and the R6 format, and
   reconciled by a second reviewer against the extracted PRG. Record it
   under `src/external/<app>/` per
   `.agents/workflows/canonical-byte-oracles.md`. A ca65 cross-check, if
   the app keeps one, and a same-base prior assembly are supporting
   evidence, not the derivation source.
5. **Capture the Manifest**: Transcribe the reviewed PRG into a checked-in
   hex manifest via a `scripts/build_<app>_manifest.py` script (a small
   twin of `scripts/build_dash_manifest.py` — drop its `--cross-check`
   machinery if the app has no ca65 check, as
   `scripts/build_banner_manifest.py` does; `--allow-host-bytes` is not an
   acceptable normal provenance path). The manifest is a machine-integrity
   record (byte count, artifact hash, source hash) bound to the separate
   derivation record from step 4 — it is the shipped artifact and
   stale-artifact guard, not proof of its own correctness. Regenerating it
   is always a deliberate, reviewed act, never a build step.
6. **CMake Target**: Add an `add_custom_command`/`add_custom_target` pair
   that runs `scripts/hex_manifest_to_bin.py` against the manifest at
   build time (mirroring the `dash`/`banner` targets in `CMakeLists.txt`)
   — this is what gives the app a `C64_PRG_PATH` property so
   `add_c64_disk_image`'s `PRGS` list can package it like any other
   compiled target. `--source-dir` on that call gives free stale-artifact
   protection: an edited source without a regenerated manifest is a hard
   build failure, not a silent stale ship.
7. **Release Packaging**: Add the target to the appropriate disk image's
   `PRGS` list (`IMAGE_PRG_TARGETS` for production, or a dedicated
   dev-utility disk).

# Verification

- CMake configuration must succeed with no warnings/errors.
- The build number in `BUILD_<APPNAME_UPPER>` must increment upon source modification and compile.
- The compiled `.prg` output must print the correct version major.minor.stage.build during execution.
- ca65/ld65 apps must build through `add_ca65_app` as part of `cmake --build build --target image_d64` or `cmake --build build --target test_image_d64`, depending on whether the app ships or is test-only.

# Child DOX Index

- [casm/AGENTS.md](casm/AGENTS.md)
- [debug/AGENTS.md](debug/AGENTS.md)
- [dash/AGENTS.md](dash/AGENTS.md)
- [pacman/AGENTS.md](pacman/AGENTS.md)
