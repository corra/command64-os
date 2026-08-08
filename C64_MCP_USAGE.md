# c64 MCP Usage Guide

`c64` is the VICE-embedded MCP server: `x64sc -mcpserver`, HTTP JSON-RPC on `/mcp`, started
via `tools/vice_mcp_start.sh` (there is no MCP tool to launch or kill the emulator process
itself — see `.agents/workflows/vice-mcp-testing.md` for the full testing procedure this
guide supports).

## Command Reference

Verified directly against a live `tools/list` call (2026-08-06), not transcribed from prose —
tool names are underscored (`vice_execution_run`), not dotted. 60 tools across 12 categories,
plus 4 protocol-internal entries (`initialize`, `notifications_initialized`, `tools_list`,
`tools_call`) not listed below. If a tool ever isn't where this table says, trust a live
`tools/list` over this document and file a correction. Full upstream docs:
`tools/VICE-MCP-README.md`.

**Execution** — `vice_ping()` liveness/version check · `vice_execution_run()` ·
`vice_execution_pause()` · `vice_execution_step({count?, stepOver?})` ·
`vice_run_until({address?, cycles?})`

**Registers** — `vice_registers_get()` · `vice_registers_set({register, value})`
(`register`: `PC|A|X|Y|SP|N|V|B|D|I|Z|C`)

**Memory** — `vice_memory_read({address, size, bank?, encoding?})` ·
`vice_memory_write({address, data})` · `vice_memory_banks()` ·
`vice_memory_search({start, end, pattern, mask?, max_results?})` ·
`vice_memory_fill({start, end, pattern})` ·
`vice_memory_compare({mode: "ranges"|"snapshot", ...})`

**Checkpoints** — `vice_checkpoint_add({start, end?, stop?, load?, store?, exec?})` ·
`vice_checkpoint_delete({checkpoint_num})` · `vice_checkpoint_list()` ·
`vice_checkpoint_toggle({checkpoint_num, enabled})` ·
`vice_checkpoint_set_condition({checkpoint_num, condition})` ·
`vice_checkpoint_set_ignore_count({checkpoint_num, count})` ·
`vice_checkpoint_group_create({name, checkpoint_ids?})` ·
`vice_checkpoint_group_add({group, checkpoint_ids})` ·
`vice_checkpoint_group_toggle({group, enabled})` · `vice_checkpoint_group_list()`

**Sprites** — `vice_sprite_get({sprite?})` ·
`vice_sprite_set({sprite, x?, y?, enabled?, multicolor?, expand_x?, expand_y?, priority_foreground?, color?})` ·
`vice_sprite_inspect({sprite_number, format?})` (`format`: `ascii`|`binary`|`png_base64`)

**Chip state** — `vice_vicii_get_state()` · `vice_vicii_set_state({registers})` ·
`vice_sid_get_state()` · `vice_sid_set_state({registers})` ·
`vice_cia_get_state({cia?})` (1 or 2, omit for both) ·
`vice_cia_set_state({cia1_registers?, cia2_registers?})`

**Disk** — `vice_disk_attach({unit, path})` · `vice_disk_detach({unit})` ·
`vice_disk_list({unit})` · `vice_disk_read_sector({unit, track, sector})` (units 8-11)

**Machine** — `vice_autostart({path, program?, run?, index?})` ·
`vice_machine_reset({mode?: "soft"|"hard", run_after?})` · `vice_machine_config_get()` ·
`vice_machine_config_set({resources})`

**Display** — `vice_display_screenshot({path?, format?, return_base64?})` ·
`vice_display_get_dimensions()`

**Input** — `vice_keyboard_type({text, petscii_upper?})` ·
`vice_keyboard_petscii({data})` (exact PETSCII bytes) ·
`vice_keyboard_key_press({key, modifiers?, hold_frames?, hold_ms?})` ·
`vice_keyboard_key_release({key, modifiers?})` · `vice_keyboard_restore({pressed?})` ·
`vice_keyboard_matrix({key?, row?, col?, pressed?, hold_frames?, hold_ms?})` ·
`vice_keyboard_chord({keys, hold_frames?, hold_ms?})` ·
`vice_joystick_set({port?, direction?, fire?})` ·
`vice_joystick_tap({port?, direction?, fire?, duration_frames?, duration_ms?})`

**Debug** — `vice_disassemble({address, count?, show_symbols?})` ·
`vice_symbols_load({path, format?})` (`format`: `auto`|`kickasm`|`vice`|`simple`) ·
`vice_symbols_lookup({name?, address?})` ·
`vice_watch_add({address, size?, type?, condition?})` · `vice_backtrace({depth?})` ·
`vice_cycles_stopwatch({action: "reset"|"read"|"reset_and_read"})`

**Snapshots** — `vice_snapshot_save({name, description?, include_roms?, include_disks?})` ·
`vice_snapshot_load({name})` · `vice_snapshot_list()`

Not present in this build despite being described in `tools/VICE-MCP-README.md`'s overview table:
checkpoint auto-snapshot (`set_auto_snapshot`/`clear_auto_snapshot`), execution tracing
(`trace.start`/`trace.stop`), and interrupt logging (`interrupt.log.*`). The README's own
Project Status section marks tracing/interrupt-logging as still in progress; auto-snapshot
isn't in its detailed Tool Reference section either despite the overview table mentioning it.
Treat the overview table as aspirational and the live `tools/list` as ground truth.

## Command64 OS testing guidelines

Applications for *Command 64 OS* **MUST BE RUN FROM COMMAND 64's SHELL** — they **CANNOT** be
*LOADed from BASIC* or they will fail.

**Patience**: the emulated 6502 runs at real 1MHz. Commands and loads can take a while; give
them time before classifying a timeout as a failure. `warp mode`
(`vice_machine_config_set {"resources": {"WarpMode": 1}}`) can speed up long operations
(building `dash`, loading `casm`) but **disable it afterward** (`WarpMode: 0`) — it can skew
timing-sensitive tests, and disabling it is also a useful diagnostic step if a test seems
unstable.

**Case matters**. Command64 uses the mixed-case charset (see the workflow doc's State
verification section for the screen-code table this implies), and both shell commands and
external application commands are case-sensitive — `flush` succeeds, `FLUSH` fails and leaves
the device in an error state.

**Build artifacts** must be added to a `.d64` image and that image attached
(`vice_disk_attach`) before they're testable — rebuild the image, or add the file manually.

**State matters**: a paused emulator (explicit or as a side effect of an MCP call) must be
resumed (`vice_execution_run`) or subsequent tests will keep failing against stale state.

**Reading state**: decode screen RAM (`vice_memory_read` on `$0400`+, see the workflow doc)
over screenshots for routine text assertions — there's no dedicated screen-text tool. Use
`vice_display_screenshot` only when a decoded read can't answer the question (glyph identity,
color, layout).

**Resetting**: prefer `vice_machine_reset` over killing the process. Killing and restarting
(`tools/vice_mcp_start.sh stop` then `start`) is a last resort.

**When finished testing**, stop the instance you started (`tools/vice_mcp_start.sh stop`) and
return control to the user. Never stop an instance you did not start without asking first.

## Discoveries and lessons

Update this section with usage discoveries as they're found.

### A stub socket can outlive a failed HTTP bind — `vice_ping` is the only proof of life

VICE can log `MCP-Transport: Error - Failed to start HTTP server on port <N>` and yet the OS
still shows that PID holding a `LISTEN` socket on the port (`ss -ltnp`, `lsof -i :<N>`).
Requests against a socket in that state either hang indefinitely or return a bare
`Received HTTP/0.9 when not allowed` from curl — never a JSON-RPC response. A bound port is
not evidence of a working server. Confirm with an actual `vice_ping` round-trip
(`tools/vice_mcp_start.sh status` does this) before trusting anything else. This was caused by
a previous instance still holding the port at bind time in every case observed — check for a
competing process before assuming a given launch itself is broken.

### Reproduce documented curl examples exactly

`tools/VICE-MCP-README.md`'s `## Talk to It` examples use multi-line `--data` payloads with real
`\n` line breaks in the request text (e.g. `"text": "test_casm_passcheck\n"`). Minifying a
payload to one line is fine; changing the method name or dropping fields is not — reproduce
the exact shape before concluding a request failure is the server's fault.

### Keyboard encoding: shell commands vs filenames

`vice_keyboard_type` maps text to PETSCII with `petscii_upper` (default `true`, meaning
uppercase ASCII input displays as uppercase). Command64's shell accepts only unshifted
PETSCII for built-in commands, so:

- Type shell commands in **lowercase**: `drive 9`, `dir`.
- Filenames are more forgiving — the OS normalizes them — but typing everything lowercase
  covers both cases with one rule.

For exact bytes, `vice_keyboard_petscii` takes raw PETSCII values directly. Do not hand-derive
a byte for `_`: ASCII `$5F` is left-arrow in PETSCII, not underscore (the underscore in these
filenames is `$A4`). A wrong byte here fails silently and looks exactly like a missing file.

### Reading a result from memory beats screen-scraping it

A harness that ends by returning to a prompt can scroll or clear its own output. When the
result must be unambiguous, read the harness's own counter out of memory instead: build with
`ca65 -g` / `ld65 --dbgfile`, look the symbol up, and read it directly
(`vice_memory_read`/`vice_symbols_lookup`).

```bash
grep '"FailCount"' out.dbg     # -> val=0x3CEE
```

Break at the reporting branch (`vice_checkpoint_add`) and read that address; `00` is a pass.

### Standalone runs are a diagnostic tool, not verification

Running a harness PRG directly at its link base (load it, set `PC`, run) is a legitimate way
to isolate pure-logic behavior from the loader, relocator, and shell. It is **not** product
verification — applications must be run from Command 64's shell for that. Use a standalone
run to localize a bug, then re-verify through the shell before calling anything done.

### ca65 charmap: fixture literals must be lowercase

With ca65's C64 target charmap, a source literal `"8:FOO.S"` assembles to *shifted* PETSCII
(`$C6 $CF $CF`), while `"8:foo.s"` assembles to *unshifted* (`$46 $4F $4F`). CASM's routines
emit unshifted constants (`CASM_PETSCII_P/R/G/L/S/T`), so expected-value fixtures compared
against them must be written **lowercase** in the `.s` source — uppercase literals produce a
harness that fails against correct production code. See `reference-casm-petscii-identifier-case`.

### Pacing

Memory/register reads and other queries can pause the emulator; resume with
`vice_execution_run` before assuming a command has progressed. A read immediately after
`vice_keyboard_type` typically shows the *previous* state — resume, wait, then read. Loading a
small harness from a `.d64` under true drive emulation takes tens of seconds; do not classify
a run as failed before its deadline.
