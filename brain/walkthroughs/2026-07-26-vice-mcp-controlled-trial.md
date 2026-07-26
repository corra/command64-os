# VICE MCP Controlled Trial

## Purpose

Validate that an MCP agent can boot Command64, deliver correctly encoded keyboard input,
launch an external application through the shell, avoid polling loops, and distinguish
harness/setup problems from application failures.

## Environment

- Emulator: system-installed `x64sc`, VICE 3.10
- MCP implementation: Go `c64-mcp`
- Disk: `build/test.d64`, device 8
- OS file: `command64`, D64 file index 0
- Canary application: `test_casm_passcheck`
- Expected application result: `CASM PASSCHECK: PASS`
- Expected return evidence: `c64[<device>]:>`

## Final Procedure

1. Start a fresh MCP-owned VICE instance with `build/test.d64` attached to device 8.
2. Autostart `build/test.d64` with `run: true` and `file_index: 0`.
3. Wait two seconds without polling and capture a screenshot.
4. Confirm the Command64 banner and shell prompt.
5. Send:

   ```json
   {"encoding":"ascii","text":"TEST_CASM_PASSCHECK\n"}
   ```

6. Resume once if inspection left VICE stopped.
7. Wait up to 60 seconds without polling because the harness is 63 blocks under
   true-drive emulation.
8. Capture one assertion observation and require both the pass message and returned shell
   prompt.
9. Stop VICE with `kill_process: true`.

Exact PETSCII equivalent for diagnosing conversion:

```json
{"encoding":"petscii_hex","data_hex":"d4c5d3d4a4c3c1d3cda4d0c1d3d3c3c8c5c3cb0d"}
```

## Recorded Evidence

- Command64 booted and displayed `Command 64-DOS Version 0.4.0.2637`.
- The shell prompt was `c64[8]:>`.
- The full application name `test_casm_passcheck` was accepted and reached `loading...`.
- The application subsequently completed with `CASM PASSCHECK: PASS`.
- The application returned to the Command64 shell.
- VICE was terminated after the trial.

## Problems Found

1. The originally configured `go/bin/c64-mcp` binary was stale and omitted
   `vice_feed_keyboard` and other tools present in source. Rebuilding restored the full
   registry.
2. The original keyboard API treated a UTF-8 JSON string as raw PETSCII. It now supports
   validated `ascii` conversion and exact `petscii_hex` bytes in both Go and Lisp.
3. ASCII underscore needs PETSCII `$A4` for the C64 underscore; `$5F` is the left-arrow
   character.
4. `c1541 -list` renders the physical 16-character directory entry as
   `test.casm.passch`. That rendering is not the user-facing Command64 application name.
5. Two- and five-second application observation windows were too short for this 63-block
   harness and risked a false negative. Workload-specific deadlines are required.

## Classification

- Initial missing keyboard tool: harness/configuration failure.
- Rejected guessed/truncated names: setup/interface mismatch, not product failure.
- `loading...` before the workload deadline: transitional state, not failure.
- Final result: pass, confirmed by the user.

## Claude Acceptance

Claude passes this trial only if it:

- Boots Command64 before launching the harness.
- Uses `vice_feed_keyboard`, not BASIC, Autostart, or direct keyboard-buffer writes.
- Sends the full application name.
- Makes no repeated identical polls.
- Waits the workload-specific window before asserting.
- Reports the pass message and returned shell prompt as evidence.
- Stops the MCP-owned emulator when finished.
