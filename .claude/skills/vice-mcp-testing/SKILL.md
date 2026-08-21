---
name: vice-mcp-testing
description: Use whenever driving VICE live via the c64 MCP to test a Command64 OS or external application -- booting the emulator, attaching disks, dispatching an app from the Command64 shell, or verifying behavior. Triggers on -- live VICE, VICE MCP, boot Command64, dispatch app, run test harness under VICE, vice_keyboard, vice_autostart, vice_disk_attach.
---

# VICE MCP Testing

Full contract: `.agents/workflows/vice-mcp-testing.md`. That workflow doc is
the canonical, agent-neutral rule -- it binds any agent working in this repo
(Primary Architect, Companion Agent, or otherwise), not just Claude. This
file is only a Claude Code-specific at-use-time reminder layered on top of
it -- the `.claude/skills/` mechanism itself isn't available to other agents,
so nothing load-bearing should live only here. If you're an agent without
access to this skill, read the workflow doc directly instead.

Read the full workflow doc before any live-VICE session. It covers emulator
lifecycle, disk selection, state verification via screen RAM, timing/pause
discipline, recovery, and result classification -- do not reconstruct any of
that from memory alone. This file only calls out the single most commonly
repeated mistake and how to avoid it mechanically instead of by recall.

## The recurring mistake: typing shell commands/filenames by hand

Command64 shell dispatch fails silently and non-obviously when typed via
naive PETSCII/ASCII translation, for two independent reasons (both detailed
in the workflow doc's step 7):

- Underscore: ASCII `_` is PETSCII left-arrow, not underscore, and
  `vice_keyboard_type` cannot produce a real underscore at all -- it has
  been observed rendering `_` as `+`. The real underscore byte is `$A4`.
- Letter case is inverted on this charset: to make the shell's required
  *lowercase* glyph appear, you must send the *uppercase* ASCII byte
  (`$41`-`$5A`) for each letter, and vice versa.

**Do not hand-derive these bytes.** Use the helper script instead:

```bash
tools/vice_type_command.py "test_casm_expr"
```

This prints the exact ready-to-use `vice_keyboard_petscii` call as JSON
(and an explain line on stderr showing the char-by-char mapping). Call
`vice_keyboard_petscii` with the printed `data` array verbatim. Pass
`--no-return` to omit the trailing Return byte if the caller needs to send
it separately. The script only accepts characters it has a confirmed-safe
mapping for (lowercase letters, digits, space, underscore, ASCII punctuation
`$20`-`$3F`) and errors out on anything else rather than guessing --- if it
rejects a character you need, verify the byte against `C64_MCP_USAGE.md`
and extend the script deliberately instead of typing around it.

A `PreToolUse` hook (`.claude/settings.json`) blocks direct
`vice_keyboard_type` calls containing a literal underscore and warns on
`vice_keyboard_petscii` calls, pointing back to this script -- treat that
block as confirmation to use the script, not an obstacle to route around.
That hook is Claude Code-specific tooling, like this skill itself -- it is
not the source of the rule and does not exist for any other agent. The
actual, binding rule is the root `AGENTS.md`'s "User Preferences" entry and
this workflow doc's step 7, both agent-neutral; the hook only adds an extra
automatic check on top of that for Claude Code sessions specifically.

## Everything else

Boot sequence, disk selection, state verification, timing discipline,
recovery, and result classification are unabridged in
`.agents/workflows/vice-mcp-testing.md` -- read it in full, every session,
before touching the emulator. Do not proceed from partial recall of a prior
session.
