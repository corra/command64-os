---
description: Run Command64 OS and application tests safely through the VICE MCP
---

# VICE MCP Testing Workflow

This workflow is mandatory whenever an agent uses a VICE MCP to test Command64. It adds
the Command64 boot and shell contract to the MCP's generic lifecycle contract. Tool-server
aliases such as `c64-testing` are configuration details; discover and use the `vice_*`
capabilities rather than depending on an alias.

## Non-negotiable invariants

- Boot Command64 before launching any Command64 application or test harness.
- Prove Command64 startup by reading `Command 64-DOS Version` on the first screen line.
- Launch an application by entering its application name at the Command64 shell.
- Never use `vice_load_program`/VICE Autostart for an application after Command64 is
  resident. Autostart may reset to BASIC and destroy the OS session.
- Treat a BASIC `READY.` screen as proof that the Command64 prerequisite is absent.
- Prove a normal application exit by observing the shell prompt `c64[<device>]:>`, where
  `<device>` is one or more decimal digits and may change during a session.
- A timeout is not an application failure. Classify it using the failure rules below.

## Disk selection

Choose the image before starting VICE. Do not assume every harness is on `test.d64`.

| Image | Use |
|---|---|
| `build/image.d64` | Clean OS image for normal Command64 applications; no test harnesses |
| `build/test.d64` | Existing test harnesses and fixtures; its directory is full, so do not create or add files |
| `build/casm_overflow_test.d64` | Newer harnesses and fixtures that do not fit on `test.d64`; the historical name does not make it CASM-exclusive |
| Other dedicated D64 | Use when the test's build target or documentation explicitly requires it |

Confirm the selected image exists and contains the required application or harness before
starting an emulator test. C64 directory entries are physically limited to 16 characters,
but that truncation does not replace the documented user-facing Command64 application
name. A missing, wrong, or guessed application name is a setup failure.

## Session state

Track connection, ownership, execution state, selected media, current machine context,
checkpoints, last operation, and recovery count. Machine context is one of:

- `basic`
- `command64_booting`
- `command64_ready`
- `application_running`
- `unknown`

Never promote a context based only on a successful tool response.

## Procedure

1. Build the required CMake disk-image target before emulator testing.
2. Select the D64 and define the application's start, assertion, and exit evidence.
3. Start a fresh MCP-owned VICE instance in `launch` mode with the D64 attached to the
   intended device through `vice_start.extra_args`.
4. Use `vice_load_program` to Autostart the selected D64 at the directory index verified
   for `command64`. Autostart is permitted for this initial OS boot because establishing a
   fresh OS session is the intended reset/load/run action. Do not assume an unverified
   `file_index` when `command64` is not the image's first program.
5. Observe the screen no more than twice while waiting for startup. Require the first line
   to begin `Command 64-DOS Version`; otherwise machine context remains `unknown` or
   `basic`.
6. At the Command64 shell, use `vice_feed_keyboard` with `encoding: "ascii"` to send the
   verified D64 application name followed by newline (`\n`), which the MCP converts to
   PETSCII Return (`$0D`). Do not issue a BASIC `LOAD` or `RUN`, and do not call
   `vice_load_program` for the application.
7. Wait for application-start evidence using, in preference order, a temporary checkpoint,
   memory sentinel, stable expected screen text, or combined PC and screen/memory evidence.
8. Perform assertions. Use screenshots as supporting evidence, not the sole assertion when
   deterministic evidence exists.
9. For an application expected to exit, require the shell prompt matching
   `c64[<device>]:>` before reporting successful return. The device number is variable.
10. Delete test-created checkpoints and stop the MCP session.

## Timing and pause discipline

- Do not pause during reset, disk loading, Command64 boot, keyboard command processing,
  application loading, or application startup unless a planned checkpoint is the expected
  synchronization event.
- Use temporary stopping checkpoints where possible.
- Record why execution is stopped before inspecting it, then resume exactly once when the
  inspection is complete.
- Do not use repeated `vice_run`, screen reads, register reads, or identical tool calls as
  a substitute for a missing wait primitive.
- Make at most two observations for one transition; the second must be independent or
  stronger where possible.
- Declare a workload-specific deadline before launch. Disk size, true-drive emulation, and
  application initialization may require substantially more than a generic two- or
  five-second delay. Do not classify an application before its declared deadline.

## Recovery

One clean restart is allowed per test:

1. Stop/disconnect the MCP session and kill the MCP-launched VICE process if needed.
2. Discard all assumed emulator, OS, application, and checkpoint state.
3. Start a new VICE instance and repeat from disk selection and Command64 boot.
4. If the same stage fails again, stop calling tools and preserve the evidence.

Do not repeat a timed-out state-changing call against an uncertain session.

## Result classification

- **Product failure:** MCP and VICE remain responsive, the correct disk and Command64
  banner are proven, application start is proven, and observed behavior contradicts the
  assertion.
- **Harness failure:** MCP transport, VICE lifecycle, monitor state, pause timing, or
  synchronization failed.
- **Setup failure:** The build, image, application, fixture, path, device, or prerequisite
  is absent or wrong.
- **Inconclusive:** The machine state cannot be established safely.

Returning to BASIC after application Autostart is a harness/workflow failure, not evidence
that the application failed. Failure to observe `c64[<device>]:>` proves only that shell
return was not established; use independent evidence before assigning a product failure.

## Test report

Record the build target and D64, application name, VICE version and monitor address when
available, Command64 banner evidence, application-start evidence, assertion evidence,
shell-return evidence, checkpoint IDs, recovery attempt, and final classification.

When the MCP is unavailable, do not use a web emulator. Ask the user to perform the same
workflow in a supported local VICE instance and report the evidence.

## Controlled canary

Use this exact canary when validating an agent or MCP configuration.

1. Build `test_image_d64` through CMake and confirm `build/test.d64` exists.
2. Start a fresh MCP-owned `x64sc` with `build/test.d64` attached to device 8.
3. Autostart file index 0 from `build/test.d64`; this boots `command64`.
4. Allow a bounded two-second OS boot window, then capture one screenshot.
5. Require `Command 64-DOS Version` and a prompt matching `c64[<device>]:>`.
6. Send the full documented application name through converted ASCII input:

```json
{"encoding":"ascii","text":"TEST_CASM_PASSCHECK\n"}
```

7. Resume emulation once if the prior inspection left it stopped.
8. The harness is 63 blocks. Allow up to 60 seconds under true-drive emulation before the
   first assertion observation; do not poll during that window.
9. Capture screen text or one screenshot. Require `CASM PASSCHECK: PASS` followed by a
   prompt matching `c64[<device>]:>`.
10. Stop the MCP-owned VICE process.

If converted ASCII input is under diagnosis, the equivalent exact PETSCII input is:

```json
{"encoding":"petscii_hex","data_hex":"d4c5d3d4a4c3c1d3cda4d0c1d3d3c3c8c5c3cb0d"}
```

Do not substitute the physical 16-character directory rendering
`test.casm.passch` for the documented application name. Short two- and five-second
application windows produced misleading `loading...` observations during the original
trial; the harness subsequently completed with `CASM PASSCHECK: PASS`.

See `brain/walkthroughs/2026-07-26-vice-mcp-controlled-trial.md` for the recorded evidence
and failure-analysis history.
