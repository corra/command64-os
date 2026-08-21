---
description: Run Command64 OS and application tests safely through the VICE MCP
---

# VICE MCP Testing Workflow

**This workflow is mandatory whenever an agent uses the VICE MCP to test Command64**. It adds
the Command64 boot and shell contract to the MCP's generic lifecycle contract. The `c64`
server alias is a configuration detail; discover and use the `vice_*` capabilities rather than
depending on it. For the full tool list and parameters, see `C64_MCP_USAGE.md`'s Command
Reference.

The MCP server is embedded directly in VICE (`x64sc -mcpserver`, HTTP JSON-RPC on `/mcp`) —
there is no separate MCP process to install or configure.

## Non-negotiable invariants

- **Prove you own the emulator** before anything else. This MCP has no tool that launches or
  kills the emulator process — `x64sc -mcpserver` must already be running before any MCP call
  can succeed. Use `tools/vice_mcp_start.sh status --port <N>` to confirm a live, *answering*
  instance, not just a bound port — VICE can log `Failed to start HTTP server` and still leave
  a stub socket listening that never answers a single request. `vice_ping` returning
  `{"status":"ok",...}` is the only real proof.
- **Re-attach a rebuilt image.** Rebuilding a `.d64` on the host does **not** change what an
  already-attached drive serves. Use `vice_disk_detach` + `vice_disk_attach` on the affected
  unit to make a running instance see a rebuilt image — a full restart is not required for
  this (see Recovery).
- **Boot Command64** before launching any Command64 application or test harness.
- **Prove Command64 startup** by reading the first screen row (see State verification) and
  requiring `Command 64-DOS Version` (case as decoded — see the screen-code note below).
- Launch an application by entering its application name at the **Command64 shell**.
- **NEVER** call `vice_autostart` for an application **AFTER** Command64 is resident. It
  issues a `LOAD"*",8,1`/reset-to-BASIC sequence and will destroy the OS session.
- **Treat a BASIC `READY.` screen** as proof that the **Command64 prerequisite is absent**.
- Prove a normal application exit by observing the shell prompt `c64[<device>]:>`, where
  `<device>` is one or more decimal digits and may change during a session.
- A **timeout is not an application failure**. Classify it using the failure rules below.

## Starting the emulator

There is no MCP tool for this step — it is a shell prerequisite:

```bash
tools/vice_mcp_start.sh start
tools/vice_mcp_start.sh status
tools/vice_mcp_start.sh stop
```

The script refuses to start a second instance on a port something already holds, and does
not return success until `vice_ping` actually answers — it does not trust a bound port alone.
If it reports a PID holding the port that never answers, that PID is not MCP-owned by this
script; **killing a VICE process you did not just start is the user's call — ask first**.

## Disk selection and attachment

Choose the image(s) **before** attaching. Do not assume every harness is on `test.d64`.

| Image | Use |
|---|---|
| `build/image.d64` | Clean OS image for normal Command64 applications; no test harnesses |
| `build/test.d64` | Existing test harnesses and fixtures; its directory is full, so do not create or add files |
| `build/casm_overflow_test.d64` | Newer harnesses and fixtures that do not fit on `test.d64`; the historical name does not make it CASM-exclusive |
| Other dedicated D64 | Use when the test's build target or documentation explicitly requires it |

Confirm the selected image exists (`ls -la build/*.d64`) before attaching. Attach explicitly
with `vice_disk_attach {unit, path}` — units 8-11 are all independently attachable on a
running instance, so a harness that needs both the OS and its own fixtures does not have to
be self-bootable on one disk, though keeping it that way is still simplest.

C64 directory entries are physically limited to 16 characters, but that truncation does not
replace the documented user-facing Command64 application name. A missing, wrong, or guessed
application name is a setup failure.

## Session state

Track connection, ownership, execution state, attached media per unit, current machine
context, checkpoints, last operation, and recovery count. Machine context is one of:

- `basic`
- `command64_booting`
- `command64_ready`
- `application_running`
- `unknown`

Never promote a context based only on a successful tool response.

## State verification

There is no screen-text tool. Read screen state directly out of screen RAM instead:

```json
{"name": "vice_memory_read", "arguments": {"address": "$0400", "size": 40, "encoding": "hex"}}
```

Each row is 40 bytes starting at `$0400 + 40*row` (rows 0-24). The bytes are **C64 screen
codes**, not ASCII/PETSCII — they need a table, not a straight hex-to-char cast. Command64
runs the character ROM's lowercase/uppercase charset (mixed-case display), where:

- Screen code `$01`-`$1A` → lowercase `a`-`z`
- Screen code `$41`-`$5A` → uppercase `A`-`Z`
- Screen code `$20` → space
- Screen code `$30`-`$39` → digits `0`-`9`
- Screen code `$00` → `@`

This is the same `vice_memory_read` tool the upstream README uses to read the BASIC ROM entry
point, applied to screen RAM instead. **Verify the table against a `vice_display_screenshot`
the first time you rely on it in a session**; do not carry forward an unverified decode
across a whole test run. Color RAM (`$D800`-`$DBE7`, mapped low nibble only) is available the
same way if a check ever needs it, but text content almost never requires it.

Prefer this over screenshots for routine text assertions — it does not require image
inspection and is cheaper to parse programmatically. Use `vice_display_screenshot` when
glyph identity, color, or layout (not just character content) is what's being verified.

## Procedure

1. Build the required CMake disk-image target before emulator testing. If VICE is already
   running with that image attached, the rebuild **has not reached it** — detach and
   re-attach the affected unit (see Disk selection) before re-testing.
2. Select the D64(s) and define the application's start, assertion, and exit evidence.
3. Confirm a live MCP-answering instance with `tools/vice_mcp_start.sh status`, starting one
   if needed.
4. Attach the selected image(s) with `vice_disk_attach`, explicit per unit.
5. Use `vice_autostart` to boot the selected D64 at the directory index verified for
   `command64`. Autostart is permitted for this initial OS boot because establishing a fresh
   OS session is the intended reset/load/run action. Do not assume an unverified `index` when
   `command64` is not the image's first program.
6. Observe screen state (see State verification) no more than twice while waiting for
   startup. Require the first row to decode to `Command 64-DOS Version`; otherwise machine
   context remains `unknown` or `basic`.
7. At the Command64 shell, prefer `vice_keyboard_petscii` with explicit bytes and Return
   (`$0D`) for nearly every command. **Do not hand-derive these bytes.** Run
   `tools/vice_type_command.py "<text>"` and pass its printed `data` array straight to
   `vice_keyboard_petscii` — it encodes both traps below correctly every time, which
   hand-derivation has repeatedly gotten wrong across sessions. If it rejects a character,
   verify the byte against `C64_MCP_USAGE.md` and extend the script deliberately rather than
   typing around it. The traps it encodes: underscore is PETSCII `$A4`, while ASCII `$5F` is
   left-arrow. **Letter case is inverted**: shell commands are lowercase-only case-sensitive
   (see the State verification section's own screen-code table), but PETSCII's own letter
   encoding is the mirror image of ASCII's — send the byte for the *uppercase* ASCII letter
   (`$41`-`$5A`, e.g. `$46` for the glyph `f`) to get a *lowercase* screen glyph, and vice
   versa. Confirmed empirically 2026-08-20: raw byte `$66` (ASCII/PETSCII lowercase `f`)
   rendered as uppercase `F` (screen code `$46`) and was rejected by the shell; byte `$46`
   (ASCII uppercase `F`) rendered as lowercase `f` (screen code `$06`) and was accepted —
   verified via direct screen-RAM memory reads, not just visual inspection. Use
   `vice_keyboard_type` only as a fallback when exact PETSCII is unavailable — it does this
   ASCII-to-PETSCII conversion for you, so plain lowercase input text works there without
   inverting anything yourself, but it cannot type a real underscore at all (observed
   rendering `_` as `+`), so any command/filename containing `_` must go through
   `vice_keyboard_petscii` via the script above. Do not issue a
   BASIC `LOAD` or `RUN`, and do not call `vice_autostart` for the application.
   If the shell responds `BAD COMMAND OR FILE NAME` (a mistyped/garbled dispatch attempt,
   not a real missing-file condition), send `flush\n` (optionally `flush <device>\n` for a
   non-default unit) before retyping the command. `FLUSH` manually reads and clears the
   drive's command/error channel (LFN 15) — most commands drain it themselves right after
   their own error, but a shell-level parse-miss does not, and a stale channel status left
   behind by one has been observed to make the *next* unrelated command fail too (e.g.
   `DEVICE NOT PRESENT`), which looks like drive/session corruption but is really just an
   unflushed error channel from the previous miss.
8. Wait for application-start evidence using, in preference order, a temporary checkpoint,
   memory sentinel, stable decoded screen text, or combined PC and memory evidence.
9. Perform assertions. Use `vice_display_screenshot` as supporting evidence, not the sole
   assertion when deterministic evidence exists.
10. For an application expected to exit, require the shell prompt matching `c64[<device>]:>`
    before reporting successful return. The device number is variable.
11. Delete test-created checkpoints (`vice_checkpoint_delete`) and leave a healthy VICE
    instance running. The emulator is part of the user's Twitch and YouTube stream layout;
    stop it only for problem recovery or when the user explicitly asks.

## Timing and pause discipline

- **Do not pause** during reset, disk loading, Command64 boot, keyboard command processing,
  application loading, or application startup unless a planned checkpoint is the expected
  synchronization event.
- Use temporary stopping checkpoints (`vice_checkpoint_add` with `stop: true`, deleted after)
  **ONLY** where possible.
- **Record why execution is stopped** before inspecting it, then resume exactly once
  (`vice_execution_run`) when the inspection is complete.
- **Do not use repeated** `vice_execution_run`, memory reads, register reads, or identical
  tool calls as a substitute for a missing wait primitive.
- **Make at most two observations** for one transition; **the second must be independent or
  stronger** where possible.
- Declare a workload-specific deadline **before launch**. Disk size, true-drive emulation, and
  application initialization may require substantially more than a generic two- or
  five-second delay. Do not classify an application before its declared deadline.

## Recovery

`vice_machine_reset` takes a `mode`: `soft` (default — CPU reset, images stay attached) or
`hard` (power cycle). There is no per-drive reset. To fix a stuck drive or refresh a rebuilt
image, detach and re-attach that unit with `vice_disk_detach` / `vice_disk_attach` instead.

| Fault | Correct action |
| --- | --- |
| Shell replied `BAD COMMAND OR FILE NAME` | `flush\n` (clears the drive's command/error channel), then retype the command |
| A later, unrelated command fails (e.g. `DEVICE NOT PRESENT`) right after a `BAD COMMAND OR FILE NAME` | Same fix — `flush\n` — before assuming drive/session corruption |
| Machine/OS state is wrong | `vice_machine_reset {mode: "soft"}`, then re-boot Command64 |
| A drive is wedged, or a `.d64` was rebuilt on the host | `vice_disk_detach` then `vice_disk_attach` on that unit |
| Nothing else works | `vice_machine_reset {mode: "hard"}`, then autostart again |

Consider `vice_snapshot_save` before a risky operation in a long session — restoring with
`vice_snapshot_load` can be cheaper than a full reboot-and-reattach cycle when the fault is
localized and reproducible.

One clean restart is allowed per test:

1. Stop the instance with `tools/vice_mcp_start.sh stop` for machine-state faults that
   `vice_machine_reset` didn't fix. Killing a VICE process this workflow did not start is
   **the user's call — ask**.
2. Discard all assumed emulator, OS, application, and checkpoint state.
3. Start a new instance and repeat from disk selection and Command64 boot.
4. If the same stage fails again, stop calling tools and preserve the evidence.

**Do not repeat** a timed-out state-changing call against an uncertain session.

## Result classification

- **Product failure:** MCP and VICE remain responsive, the correct disk and Command64
  banner are proven, application start is proven, and observed behavior contradicts the
  assertion.
- **Harness failure:** MCP transport, VICE lifecycle, decode-table mismatch, pause timing, or
  synchronization failed.
- **Setup failure:** The build, image, application, fixture, path, device, or prerequisite
  is absent or wrong. Check `ls -la build/*.d64` before touching emulator state — a missing
  image makes its `vice_disk_attach` call fail explicitly, which is useful: an attach error
  is a setup failure, not a harness fault.
- **Inconclusive:** The machine state cannot be established safely.

Returning to BASIC after application Autostart is a harness/workflow failure, not evidence
that the application failed. Failure to observe `c64[<device>]:>` proves only that shell
return was not established; use independent evidence before assigning a product failure.

**A rebuilt artifact that keeps producing a byte-identical old result is a harness failure
until proven otherwise.** Do not theorize a product bug — relocation, device, or OS — while
the emulator's provenance is unproven. Check instance liveness (`vice_ping`) and image
freshness (re-attach) **first**. The decisive cheap test: `vice_memory_search` for a
distinctive byte sequence known to be new. **If RAM holds bytes that exist in no file on
disk, you are driving something stale**, and every observation made through it is void.

## Test report

Record the build target and D64(s), application name, VICE version (`vice_ping`), attached
units, Command64 banner evidence, application-start evidence, assertion evidence,
shell-return evidence, checkpoint IDs, recovery attempts, and final classification.

When the MCP is unavailable, do not use a web emulator. Ask the user to perform the same
workflow in a supported local VICE instance and report the evidence.

## Controlled canary

Use this exact canary when validating an agent or MCP configuration change. It has not yet
been run end-to-end against this server — treat the first run as verification of the workflow
itself, not just the harness under test, and update this section with the recorded evidence
once it has.

1. Build `test_image_d64` through CMake and confirm `build/test.d64` exists.
2. `tools/vice_mcp_start.sh start`, then confirm with `status`.
3. `vice_disk_attach {unit: 8, path: ".../build/test.d64"}`.
4. `vice_autostart` file index 0 from `build/test.d64`; this boots `command64`.
5. Allow a bounded two-second OS boot window, then decode screen row 0 (see State
   verification).
6. Require `Command 64-DOS Version` and a prompt matching `c64[<device>]:>` **at boot time**.
7. Send the full documented application name via `vice_keyboard_type`:

   ```json
   {"name": "vice_keyboard_type", "arguments": {"text": "test_casm_passcheck\n"}}
   ```

8. Resume emulation once (`vice_execution_run`) if the prior inspection left it stopped.
9. The harness is 63 blocks. Allow up to 60 seconds under true-drive emulation before the
   first assertion observation; do not poll during that window.
10. Decode screen text or capture one screenshot. Require `CASM PASSCHECK: PASS` followed by
    a prompt matching `c64[<device>]:>`.
11. Leave the healthy VICE instance running after recording the result.

Do not substitute the physical 16-character directory rendering `test.casm.passch` for the
documented application name.

See `C64_MCP_USAGE.md` for the full command reference and additional findings. Update
`C64_MCP_USAGE.md` as required.
