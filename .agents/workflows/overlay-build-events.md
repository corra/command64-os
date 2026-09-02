---
description: How stream-overlay build/test events fire today, what CMake automates, and what stays a manual MCP call
---

# Overlay Build Events Workflow

The `c64-overlay-api` MCP (HTTP bridge at `http://127.0.0.1:8000`, see
`CLAUDE.md`) is one of two front doors onto the same backend: a websocket
overlay server at `ws://127.0.0.1:8765`. The other front door is already
wired into the CMake build itself, automatically, via the `C64_THEME_DIR`
cache variable. This workflow describes what's automatic, what still
requires a manual MCP call, and the contract that keeps new CMake targets
from silently falling outside the automation.

## When to Run

- Read the "What's automatic" section before assuming a build step needs a
  manual overlay-event call — most don't.
- Follow the "Sync contract" whenever adding a new `cmake/*.cmake` helper
  function or a new `add_custom_command`/`add_custom_target` in
  `CMakeLists.txt` that invokes an external build tool.
- Follow the "Stays manual" table whenever running a build-system component
  directly (outside `cmake --build`), or driving a test through VICE.

## What's Automatic

When `C64_THEME_DIR` is set (a CMake cache var, e.g.
`-DC64_THEME_DIR=/path/to/c64_theme`) and that directory has
`scripts/notify_obs.py`, every one of the following helper functions wraps
its external-tool invocation(s) in `scripts/build_event_wrapper.py
--theme-dir ... --target <name> --building/--success/--error -- <command>`,
which fires `building` before the command runs and `success`/`error` after,
with `type: build` on the wire:

| Helper | File | Steps wrapped |
|---|---|---|
| `add_kickass_target` | `cmake/KickAssembler.cmake` | single KickAss invocation |
| `add_external_app` | `cmake/KickAssembler.cmake` | base/next/reloc three-step build (`building` on first step only, `success` on reloc only, `error` on every step) |
| `add_ca65_app` | `cmake/Ca65.cmake` | per-source `ca65` assembly (`building` on first source), two `ld65` links, `tools/reloc.py` diff (`success`/`error` on terminal step) |
| `add_c64_disk_image` | `cmake/cc1541.cmake` | single `cc1541` invocation (initial disk creation) |
| `add_oscar64_target` | `cmake/Oscar64.cmake` | single compile+link `oscar64` invocation |
| `release` target | `CMakeLists.txt` (wraps `cmake/PackRelease.cmake`) | whole `cmake -P PackRelease.cmake` invocation |
| Direct `TARGET <image> POST_BUILD`/`PRE_BUILD` `cc1541` appends | `CMakeLists.txt` (image_d64, test_image_d64, command64_casm_utils_d64, and every `casm_*_test_d64`) | each append fires `--error` only (`WRAPPER_CC1541`, set fresh before each `add_custom_command`) — the disk's own `building`/`success` already came from its `add_c64_disk_image` call, these are error-only so a failed append surfaces without spamming repeat `success` events per fixture |

If `C64_THEME_DIR` is unset (the default), every `WRAPPER_CMD`/equivalent
resolves to empty and the wrapped commands run exactly as before — no
behavior change, no dependency on the overlay server being reachable.

`CMakeLists.txt` (~line 13) self-heals this cache var after a `build/` wipe:
if it's empty *and* `/home/morgan/streaming/c64_theme/scripts/notify_obs.py`
exists on disk, it defaults `C64_THEME_DIR` to that path, so the plain
`cmake -B build` from `CLAUDE.md` keeps overlay events wired without anyone
having to remember `-DC64_THEME_DIR=...`. An explicit `-D`/env override
always wins and is never overwritten back to the default. This is a
machine-specific hardcoded path (Morgan's local `c64_theme` checkout) —
intentional, since this whole feature is inherently personal
streaming-setup config, not something other clones/forks need.

`hex_manifest_to_bin.py` (the `dash` target's manifest-transcription step,
`CMakeLists.txt` ~line 1145, and the `casm_reference_fixtures` target's
per-name loop) is deliberately **not** wrapped: it's not a compiler/linker
invocation — it transcribes an already-reviewed hex manifest to a binary.
DASH's shipped `dash.prg` comes from that transcription of the reviewed
native manifest, not from ca65; the `dash_ref` ca65 target is an optional
differential check (non-authoritative — see
`.agents/workflows/canonical-byte-oracles.md`), and while it still builds
it is where the DASH-source `add_ca65_app` compile/link overlay events
fire. The byte-oracle transition makes `dash_ref` opt-in and non-gating
(WP5); if it stops building after intentional CASM-only syntax adoption,
no DASH build events are lost that belong to the shipped artifact. Same
"not a build tool" reasoning covers
`cmake/IncrementBuildNumber.cmake`, `cmake/GenerateCasmTestFixtures.cmake`,
the `sync_docs` target (`cmake -E copy`), `pacman_autotile` (a pure Python
maze generator), and `check_casm_source_bytes.py`'s `PRE_BUILD` verification
gate on `command64_casm_utils_d64` — none invoke an external build tool, so
none get a wrapper.

**Full audit confirmed 2026-08-13**: every `add_custom_command`/
`add_custom_target` in `CMakeLists.txt` and `cmake/*.cmake` was enumerated
and checked. The only gap found beyond the two closed above was 22 direct
`"${CC1541_EXECUTABLE}"` `POST_BUILD`/`PRE_BUILD` append blocks in
`CMakeLists.txt` (test-fixture/reference-PRG appends onto already-built disk
images) — now wrapped per the row above. No KickAss, ca65, or ld65
invocation exists outside the already-wrapped helper functions.

## The Sync Contract

Any new `cmake/*.cmake` helper function that invokes an external build tool
(assembler, compiler, linker, disk-image packer, or any future toolchain
addition) via `add_custom_command`/`add_custom_target` **must** add the same
wrapper pattern. This is not optional cleanup — a new CMake file that shells
out to a build tool without this wrapper is a bug in that CMake file, the
same way a missing `DEPENDS` would be.

- **Single-step invocation** (one command does the whole job): copy
  `cmake/cc1541.cmake`'s or the post-fix `cmake/Oscar64.cmake`'s pattern —
  one `WRAPPER_CMD` with `--building --success --error`, placed before
  `COMMAND` in one `add_custom_command`/`add_custom_target`.
- **Multi-step invocation** (compile → link → post-process): copy
  `cmake/Ca65.cmake`'s `add_ca65_app` — `--building` fires only on the
  first step, `--success` only on the terminal step, `--error` on every
  step, using separate `WRAPPER_*` variables per step so a failure at any
  stage is reported.
- Always gate on `if(C64_THEME_DIR)`, always set the unwrapped var to `""`
  outside that guard, and always place `${WRAPPER_CMD}` (or equivalent) as
  the first token(s) of `COMMAND`.

**Checklist when adding a new CMake target:**
1. Does it call an external build tool via `add_custom_command`/
   `add_custom_target`? If no (pure `file()`/`execute_process(cmake -E ...)`),
   no wrapper needed — leave a one-line comment saying why, matching
   `IncrementBuildNumber.cmake`/`GenerateCasmTestFixtures.cmake`.
2. If yes: single-step or multi-step? Copy the matching pattern above.
3. Is `--building` on exactly one step (the first), `--success` on exactly
   one step (the last), and `--error` on every step?
4. Does the wrapper resolve to `""` when `C64_THEME_DIR` is unset, so the
   build behaves identically without it?

## Stays Manual

CMake automation only covers `cmake --build`. These remain the agent's own
responsibility, fired by hand via `mcp__c64-overlay-api__trigger-event-event-pst`:

| Action | `type` | `state` sequence | `program` |
|---|---|---|---|
| Direct `ca65`/`ld65`/`KickAss.jar`/`cc1541`/`oscar64` invocation, bypassing `cmake --build` | `build` | `building` → `success`/`error` | the app/target name |
| Any live action performed by `casm.prg` itself under VICE | `test` | `testing` → `pass`/`fail` | the fixture/test name |
| Any real test execution (VICE MCP driven, per `.agents/workflows/vice-mcp-testing.md`) | `test` | `testing` → `pass`/`fail` | the test/harness name |

CMake only ever *builds* test fixtures (`.prg`/`.d64` outputs); it never
*executes* them, so `type: test` events have no CMake hook to piggyback on
by design — there is no `enable_testing()`/`ctest` in this project.

### CASM's dual role — current policy (interim, 2026-08-13)

CASM appears in two distinct places, and they are **not** classified the
same way:

- **Building `casm.prg` itself** (the `add_ca65_app(casm ...)` CMake
  target) is an ordinary compiler invocation — always `type: build`,
  already covered automatically by the Sync Contract above. Nothing about
  this section changes that.
- **Any live action CASM performs once it's running under VICE** — being
  the subject under test, or acting as a build tool by natively assembling
  a source file on-device inside a test session — is classified `type:
  test`, never `build`, even when that on-device action also produces a
  build artifact (e.g. natively assembling DASH as part of proving native
  assembly works). The action happens *inside* a VICE test session, so it
  inherits that session's `test` classification regardless of what it
  produces.

This is a deliberate, explicit choice by the user, not a default inferred
from the schema — the user may revisit it later for specific conditions
where the build-event framing should take priority instead (e.g. treating
an on-device CASM assembly as a `build` event when the point of the
exercise is the artifact, not the test). Until that reconsideration
happens, treat every CASM-under-VICE action uniformly as `test`.

### Known limitation — pass/fail vs. 4-way result classification (deferred, 2026-08-13)

The `c64-overlay-api` MCP's `EventPayload` schema only supports a binary
`testing → pass|fail` outcome for `type: test`. But
`.agents/workflows/vice-mcp-testing.md`'s Result classification is
four-way: **Product failure**, **Harness failure**, **Setup failure**,
**Inconclusive** — only "Product failure" and "assertion held" map cleanly
onto `fail`/`pass`. Firing `fail` for a harness/setup/inconclusive result
would broadcast a false product-failure signal, since the workflow doc is
explicit that those three are not a verdict on the thing being tested.

**Left as-is deliberately.** The user decided (2026-08-13) not to resolve
this now, because a proper fix requires changing the MCP itself (the
`c64-overlay-api` bridge's `EventPayload` schema needs a richer state
model, not just an agent-side policy choice) — a separate, larger piece of
work. Two workaround options were discussed and neither was chosen: (a)
suppress the overlay event entirely for harness/setup/inconclusive results,
leaving the overlay on `testing` until a real product-level result lands,
or (b) still fire `fail` but with a `message` caveat distinguishing "the
product failed" from "the harness never got a clean read." Do not build
test-event automation or a testing skill on the current binary schema as if
this were solved — treat it as blocked on the MCP-side schema update.
