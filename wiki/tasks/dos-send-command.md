# Task Spec: DOS_SEND_COMMAND Kernel Primitive

## Description

Add a new stable API primitive, `DOS_SEND_COMMAND`, that lets user-space
applications send an arbitrary command string to a drive's command channel
(secondary address 15) and read back the drive's error-channel response.
This generalizes the open-SA15 / write-command / read-result pattern that
already exists internally inside `fileDelete` and `fileRename`, but which is
not currently reachable through the public `DOS_` dispatch table.

This is a prerequisite for `format` (see `format.md`), which needs to send
NEW commands (e.g. the literal PETSCII string `N:MYDISK,01`) to the command
channel unmodified — no wrapping/mangling of the caller's string, unlike
`DOS_OPEN_FILE`, which force-appends `,<type>,W` to whatever filename it is
given. This primitive is deliberately scoped as its own task because it
changes the stable kernel API surface rather than adding user-space
application code.

## Scope

- New function number `DOS_SEND_COMMAND = $58`, registered in
  `include/command64.inc` and `include/ca65/command64.inc`.
- Input: X/Y = pointer to a null-terminated command string (e.g.
  `"N:MYDISK,01"`); device number comes from the same `<dev>:` prefix
  convention `fileOpen`/`parsePointerDevice` already use, or defaults to 8
  if absent.
- Behavior: open the target device at secondary address 15, write the
  command string, read the drive's error-channel response, close the
  channel.
- Output: A/X/Y = drive status response (e.g. `"00, OK,00,00"` or the
  drive's actual error string) written into a caller-supplied buffer;
  Carry = transport-level success/failure (IEC communication succeeded or
  not — independent of whether the drive itself reported an error in its
  response text).
- Reuse the existing internal SA15 open/write/read-result logic from
  `fileDelete`/`fileRename` rather than duplicating it — refactor into a
  shared internal routine both the old call sites and the new
  `ahSendCommand` handler call.

## Non-Goals

- No IEC primitives beyond what's needed for the command channel (no raw
  LISTEN/TALK/SECOND/CIOUT exposed individually to user space).
- No drive-type detection or command validation — this is a thin transport
  primitive; callers (like `format`) are responsible for constructing valid
  command strings and interpreting the response.

## Sub-tasks

- [ ] Extract the shared open-SA15/write/read-result logic out of
      `fileDelete`/`fileRename` in `src/command64/file.asm` into a reusable
      internal routine.
- [ ] Add `DOS_SEND_COMMAND = $58` to `include/command64.inc` and
      `include/ca65/command64.inc`.
- [ ] Add `ahSendCommand` dispatch entry in `src/command64/api.asm`.
- [ ] Wire the internal routine's status response into a caller-supplied
      buffer, returned via the API ABI.
- [ ] Document `DOS_SEND_COMMAND` in `wiki/api-reference.md` following the
      existing per-function format.
- [ ] Verify via VICE: a test call sends a harmless command (e.g. `"I0"` /
      initialize) to a mounted drive and the response buffer contains the
      drive's actual status string.
