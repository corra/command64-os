# DEBUG REU and Address Syntax WP1 Detailed Plan

**Status:** Draft for approval

**Created:** 2026-08-03

**Parent plan:** `brain/plans/2026-08-03-debug-reu-and-address-syntax.md`

**Work package:** WP1, Parser Foundation and Permissive `=`

**Implementation target:** `src/external/debug/debug.s`

**Planning branch:** `feature/debug-reu-address-wp1-plan`

## 1. Purpose

Implement the parser foundation required by the parent plan and add optional
MS-DOS-style `=` execution-address syntax to `G`, `T`, and `P` without changing
their established bare-address or no-argument behavior.

WP1 is intentionally independent of REU dispatch, allocation, and transfer
work. It introduces only the parser helpers that later work packages reuse and
the approved execution-command syntax.

## 2. Baseline Findings

The current source has these relevant behaviors:

1. `dispatch` leaves `Y` immediately after the command character.
2. `skipSpaces` advances `Y` over ASCII/PETSCII space and returns with `A`
   containing the first non-space byte or null terminator.
3. `parseHexArg` accepts one through four hexadecimal digits, returns the value
   in `HexValLo/HexValHi`, leaves `Y` at the first non-hex byte, and returns
   carry clear on success.
4. `parseHexArg` returns carry set for an empty operand or a fifth hexadecimal
   digit. It deliberately does not classify or consume delimiters.
5. `cmdGo` accepts a bare address or defaults to `currentAddr`, but does not
   reject trailing input after a parsed address.
6. `cmdTraceProceedCommon` accepts a bare address or defaults to the existing
   `regPC` and rejects trailing input.
7. `cmdTraceProceedCommon` currently writes `regPC` before checking trailing
   input. A command such as `T 4000 EXTRA` therefore reports an error after
   changing target state.
8. `cmdGo` executes through `cgIndirect`, while `T` and `P` continue through
   `launchProgram`. WP1 must not redesign either execution path.
9. DEBUG's private zero-page range `$70-$7F` is fully assigned. WP1 does not
   add or repurpose zero-page storage.

## 3. Scope

### 3.1 Included

- Add `requireEnd` as a reusable parser helper.
- Add `parseOptionalEquals` for execution commands.
- Accept `G`, `T`, and `P` addresses with or without `=`.
- Accept spaces before and after `=`.
- Preserve no-argument behavior when no `=` is present.
- Reject a missing address after `=`.
- Reject malformed, oversized, page-qualified, or trailing operands.
- Prevent invalid `T` and `P` commands from changing `regPC`.
- Prevent invalid `G` commands from executing a target.
- Build DEBUG through CMake and run focused compatibility verification.

### 3.2 Excluded

- `X` command dispatch or any REU command.
- Generic `=` support in `parseHexArg` or other commands.
- `G` breakpoint lists.
- `T` or `P` repeat counts.
- Changes to breakpoint decoding, ROM safeguards, `launchProgram`, or the BRK
  handler.
- New error-message text or public error codes.
- New persistent BSS or zero-page state.
- DEBUG minor-version changes; the parent plan reserves the combined feature
  version bump for the integrated release.
- Broad parser cleanup outside the modified commands.

## 4. Command Contract

The accepted grammar is:

```text
G [address|=address]
T [address|=address]
P [address|=address]
```

`address` is exactly the existing one-to-four-digit hexadecimal component.
Letters retain the case handling already implemented by `parseHexArg`.

These forms are equivalent:

```text
G4000
G 4000
G=4000
G =4000
G= 4000
G = 4000
```

The equivalent spacing forms also apply to `T` and `P`.

No-argument behavior remains:

- `G` executes at `currentAddr`.
- `T` traces from the current `regPC`.
- `P` proceeds from the current `regPC`.

An `=` changes the grammar state: once consumed, an address is mandatory.
Therefore `G =`, `T =`, and `P =` are errors rather than no-argument forms.

After an address, only spaces and the null terminator are valid. Unsupported
breakpoint lists, counts, colon syntax, and other trailing input are errors.

## 5. Helper Contracts

### 5.1 `requireEnd`

Place `requireEnd` with the existing parser helpers near `skipSpaces` and
`parseHexArg`.

Input:

- `Y`: current index in `inputBuf`.

Output:

- Carry clear when the remainder contains only spaces followed by null.
- Carry set when a non-space byte remains.
- `Y` points to the null terminator on success.
- `Y` points to the first trailing non-space byte on failure.
- `A` contains the byte at `inputBuf,Y` on return.

Preservation and clobbers:

- `A` and processor flags are clobbered.
- `Y` may advance as documented.
- `X`, `HexValLo`, and `HexValHi` are preserved.

Implementation shape:

1. Call `skipSpaces`.
2. Load `inputBuf,Y` explicitly rather than relying on undocumented accumulator
   state from `skipSpaces`.
3. Return carry clear for null.
4. Return carry set otherwise.

The explicit reload keeps `requireEnd` correct if `skipSpaces` is later
refactored while preserving its documented `Y` behavior.

### 5.2 `parseOptionalEquals`

Place `parseOptionalEquals` beside `requireEnd`. It is a cursor-normalization
helper, not an address parser.

Input:

- `Y`: index immediately after the `G`, `T`, or `P` command character.

Output:

- Skip leading spaces.
- If the next byte is `=`, consume it and all following spaces.
- Return with `Y` at the first address byte or null terminator.
- Do not consume any non-space byte other than one optional `=`.
- Return carry set if `=` was consumed and carry clear otherwise.

Preservation and clobbers:

- `A` and processor flags are clobbered.
- `Y` advances as documented.
- `X`, `HexValLo`, and `HexValHi` are preserved.
- Carry reports whether `=` was consumed.

The carry result is required even though both address forms select the same
target: it distinguishes a valid no-argument command from a missing address
after a consumed `=`.

The helper must be called only by `cmdGo` and
`cmdTraceProceedCommon` in WP1. `parseHexArg` remains unchanged so `=`, `:`,
and other punctuation do not become globally accepted delimiters.

## 6. Handler Design

### 6.1 `cmdGo`

Required control flow:

1. Call `parseOptionalEquals`.
2. Retain carry as the `=`-consumed result and inspect `inputBuf,Y` without
   changing carry.
3. If null with carry clear, retain the existing no-argument path that copies
   `currentAddr` to `val1`; if null with carry set, report a missing address.
4. Otherwise call `parseHexArg`.
5. On parse failure, branch to the existing command error path.
6. Call `requireEnd` before changing `val1` or executing anything.
7. On trailing-input failure, branch to the existing command error path.
8. Copy `HexValLo/HexValHi` to `val1` only after complete validation.
9. Continue through the existing `cgIndirect` path.

`G =` reaches step 3 with carry set and must not fall back to `currentAddr`. A
command with no `=` reaches step 3 with carry clear and preserves the existing
default.

Although `val1` is scratch state, delaying its update until after `requireEnd`
makes the parse transaction explicit and guarantees that no invalid command
changes the selected execution target.

### 6.2 `cmdTraceProceedCommon`

Required control flow:

1. Preserve the existing `traceMode` setup in `cmdTrace` and `cmdProceed`.
2. Call `parseOptionalEquals`.
3. Retain carry as the `=`-consumed result and inspect `inputBuf,Y` without
   changing carry.
4. If null with carry clear, retain the current `regPC` and continue to
   `launchProgram`; if null with carry set, report a missing address.
5. Otherwise call `parseHexArg`.
6. On parse failure, branch to `ctpcErr`.
7. Call `requireEnd` while the candidate address remains in
   `HexValLo/HexValHi`.
8. On trailing-input failure, branch to `ctpcErr` without writing `regPC`.
9. Commit `HexValLo/HexValHi` to `regPC` only after complete validation.
10. Continue through the existing `launchProgram` path.

`HexValLo/HexValHi` are sufficient transaction scratch for WP1 because
`requireEnd` preserves them. No new BSS or zero-page field is needed.

The handlers may share labels only where branch range, readability, and ca65
layout permit. Avoid a new common routine unless measurement shows it reduces
code without obscuring the distinct `G` and `T`/`P` launch semantics.

## 7. Error and State Invariants

Every invalid modified command must use the existing DEBUG error path and
return to the prompt.

Before the error path:

- Invalid `G` must not call `cgIndirect` or execute user code.
- Invalid `T` or `P` must not call `launchProgram`.
- Invalid `T` or `P` must leave both bytes of `regPC` unchanged.
- Invalid commands must not install breakpoints, alter the BRK vector, or write
  breakpoint opcodes.
- `currentAddr`, virtual registers other than intentionally executed-command
  effects, and DEBUG's private zero-page ownership remain unchanged.

The parser must reject:

- A missing address after `=`.
- A second `=`.
- Non-hex first characters.
- A fifth hexadecimal digit.
- Colon-qualified addresses.
- Unsupported second operands.
- Any trailing non-space byte.

## 8. Implementation Increments

### Increment 1: Parser Helpers

1. Add `requireEnd` with its register, flag, and cursor contract in comments.
2. Add `parseOptionalEquals` with its scope and clobber contract in comments.
3. Confirm neither helper changes `parseHexArg`, zero-page symbols, BSS, or
   dispatch.
4. Build the `debug` target.

Exit criterion: both helpers assemble and their contracts can be verified from
the generated source/listing context without handler behavior changes.

### Increment 2: `G` Integration

1. Replace the initial `skipSpaces` call with `parseOptionalEquals`.
2. Add `requireEnd` after successful address parsing.
3. Delay the `val1` commit until validation succeeds.
4. Preserve the no-argument `currentAddr` fallback.
5. Build the `debug` target.
6. Run focused valid, invalid, and no-execution checks for `G`.

Exit criterion: every valid bare and `=` form reaches the same target, while
every invalid form returns an error without target execution.

### Increment 3: Shared `T`/`P` Integration

1. Replace the initial `skipSpaces` call with `parseOptionalEquals`.
2. Replace open-coded trailing-space validation with `requireEnd`.
3. Move the `regPC` stores after successful end validation.
4. Preserve no-argument execution from the current `regPC`.
5. Build the `debug` target.
6. Run the same parser matrix for both trace modes.

Exit criterion: valid `T` and `P` forms commit identical PCs; invalid forms
leave `regPC` and breakpoint state unchanged.

### Increment 4: Focused Regression and Review

1. Run all WP1 syntax cases.
2. Re-run established bare-address and no-argument `G`, `T`, and `P` cases.
3. Re-run ROM-target safeguards for `T` and `P`.
4. Inspect linker and relocation output for unintended growth or relocation
   changes.
5. Review the diff for helper scope, carry handling, branch ranges, and state
   commit ordering.

Exit criterion: WP1 acceptance criteria pass with no behavior change outside
the approved syntax and stricter trailing-input rejection.

## 9. Build Verification

Use only the project build system. Do not invoke ca65 or ld65 directly.

1. Configure through the existing CMake build directory when configuration is
   absent or stale.
2. Build the focused `debug` target after each implementation increment.
3. Build `image_d64` before VICE integration.
4. Build `test_image_d64` if an existing DEBUG harness on that image is used.
5. Require zero assembler, linker, and CMake warnings or errors attributable
   to WP1.
6. Confirm `debug.prg` remains inside its configured `$2000` `MAIN` envelope.
7. Confirm relocation generation still succeeds.
8. Confirm no new zero-page, BSS, or OS parameter-cell ownership.
9. Let CMake update `BUILD_DEBUG`; do not edit generated build includes.

## 10. Verification Matrix

### 10.1 Accepted Address Forms

Run each form for `G`, `T`, and `P` against controlled safe routines:

```text
COMMAND4000
COMMAND 4000
COMMAND=4000
COMMAND =4000
COMMAND= 4000
COMMAND = 4000
COMMAND  =  4000
```

Pass criteria:

- All spacing forms parse the same `$4000` target.
- Lowercase and shifted command input remain consistent with dispatch.
- Address hex-letter case remains consistent with existing `parseHexArg`.

### 10.2 No-Argument Forms

```text
G
G <spaces>
T
T <spaces>
P
P <spaces>
```

Pass criteria:

- `G` uses the pre-established `currentAddr`.
- `T` and `P` use the pre-established `regPC`.
- Trailing spaces do not turn a no-argument command into an error.

### 10.3 Rejected Forms

Run each case for `G`, `T`, and `P` where applicable:

```text
COMMAND =
COMMAND = <spaces>
COMMAND ==
COMMAND ==4000
COMMAND =G000
COMMAND =10000
COMMAND =0001:0000
COMMAND =4000 EXTRA
COMMAND =4000 4500
COMMAND 4000 EXTRA
COMMAND 4000 02
COMMAND 4000,
```

Also verify punctuation directly after the command:

```text
G:4000
T$4000
P+4000
```

Pass criteria:

- Every case reports the existing error indication.
- Invalid `G` never executes the target.
- Invalid `T` and `P` retain the exact pre-command `regPC`.
- No invalid case installs or leaves a breakpoint.

### 10.4 Boundary Forms

```text
COMMAND =0
COMMAND =0000
COMMAND =FFFF
COMMAND =00000
COMMAND =FFFFF
```

Parser pass criteria:

- One and four digits parse successfully.
- Five digits fail before execution or target-state commit.

Execution safety is separate from parser acceptance. Tests for `$0000` and
`$FFFF` should prove parsing through controlled instrumentation or breakpoints;
they must not blindly launch unsafe targets.

### 10.5 Existing Behavior Regression

At minimum verify:

- Existing bare-address `G`, `T`, and `P` behavior.
- Existing no-argument behavior.
- Safe-RAM trace and proceed behavior.
- `T` and `P` ROM-target rejection.
- `G` return through an `RTS`-terminated test routine.
- Normal `Q` return to the Command64 shell after the focused session.

The only approved compatibility tightening is rejection of trailing input that
was previously ignored or rejected after a premature `regPC` update.

## 11. VICE Test Design

All emulator work must follow `.agents/workflows/vice-mcp-testing.md`.

1. Build the selected D64 through CMake.
2. Start a fresh MCP-owned VICE instance with the image attached.
3. Boot Command64 first and prove the first line begins
   `Command 64-DOS Version`.
4. Launch `debug` by name from the Command64 shell; never Autostart DEBUG.
5. Establish safe test routines in the documented DEBUG scratch range, using
   existing DEBUG commands or a CMake-built harness.
6. Use routines with deterministic effects:
   - An `RTS`-terminated routine with a memory sentinel for `G`.
   - A short safe-RAM instruction sequence with known next PCs for `T`.
   - A `JSR` sequence with known step-over PC for `P`.
7. Capture pre-command `regPC` and breakpoint/vector state for negative
   `T`/`P` tests where deterministic memory inspection is available.
8. Use a sentinel or checkpoint to prove invalid `G` never reaches the target.
9. Bound observations and classify setup, harness, product, and inconclusive
   failures according to the workflow.
10. Quit DEBUG and prove the shell prompt `c64[<device>]:>`.
11. Delete checkpoints and terminate the MCP-owned instance.

Screenshots support the report but do not replace deterministic memory,
register, PC, or checkpoint evidence.

## 12. Review Checklist

### Parser Correctness

- `parseOptionalEquals` consumes at most one `=`.
- Bare and `=` forms enter the same existing hex parser.
- A consumed `=` cannot fall through to no-argument behavior.
- `requireEnd` accepts only spaces followed by null.
- `parseHexArg` remains unchanged and globally strict.
- `Y` contracts are documented and honored at every call site.

### 6502 Correctness

- Carry is tested immediately after helpers that define it.
- No intervening instruction accidentally replaces required carry state.
- `A`, `X`, and `Y` clobbers match comments and caller assumptions.
- Candidate low and high bytes survive `requireEnd`.
- `regPC` is committed low/high only after complete validation.
- Branch distances remain legal after helper and handler growth.
- Jumps to common error paths do not introduce stack imbalance.

### State and Memory Safety

- Invalid `G` cannot reach `cgIndirect`.
- Invalid `T`/`P` cannot reach `launchProgram`.
- Invalid `T`/`P` leave `regPC` unchanged.
- No new private zero-page or persistent BSS is introduced.
- Existing `$70-$7F` aliases retain their meanings.
- No OS parameter cell is treated as persistent state.

### Scope Control

- No REU command code is introduced.
- No breakpoint/count syntax is accepted.
- No unrelated DEBUG command is modified.
- No direct assembler or linker invocation is used.
- Existing user changes in the worktree are not reverted or rewritten.

## 13. Documentation and Tracking

WP1 implementation should update only records required for the delivered
increment:

1. Update the approved `wiki/tasks/` specification and Taskwarrior status when
   WP1 implementation begins and as increments complete.
2. Update `brain/task.md` consistently with project task policy.
3. Add a dated changelog entry when behavior lands.
4. Defer broad DEBUG user-guide and mirrored test-plan rewrites to WP7 unless
   the project requires interim documentation for shipped partial behavior.
5. Do not update `brain/MEMORY.md` unless implementation unexpectedly changes
   memory ownership; WP1 is designed not to do so.
6. Perform the mandatory DOX closeout. The applicable source chain is root
   `AGENTS.md`, `src/AGENTS.md`, and `src/external/AGENTS.md`; test changes also
   require `tests/AGENTS.md`.
7. Leave AGENTS files unchanged when the implementation does not alter durable
   purpose, ownership, workflow, structure, or contracts, and report that
   decision explicitly.

## 14. Completion Evidence

WP1 is ready for user confirmation only when the implementation report
contains:

- Source diff summary with helper and handler labels.
- Successful CMake target and image build commands.
- Linker-envelope and relocation evidence.
- Positive, negative, no-argument, and boundary test results.
- Proof that invalid `G` does not execute.
- Proof that invalid `T` and `P` do not change `regPC` or breakpoint state.
- Existing bare/no-argument and ROM-safety regression results.
- VICE environment, image, Command64 banner, DEBUG launch, assertion, and
  shell-return evidence.
- DOX closeout result and explanation of any intentionally unchanged docs.
- A manual walkthrough that the user can repeat.

Do not mark WP1 done until the user confirms the walkthrough.

## 15. Exit Criteria

WP1 is implementation-complete when all of the following are true:

1. `requireEnd` and `parseOptionalEquals` satisfy their documented contracts.
2. `G`, `T`, and `P` accept bare and optional-`=` addresses with approved
   whitespace.
3. No-argument behavior is unchanged.
4. Missing, malformed, oversized, page-qualified, and trailing operands fail.
5. Invalid `G` commands execute no target code.
6. Invalid `T` and `P` commands leave `regPC` and breakpoint state unchanged.
7. Valid forms continue through the existing execution and trace/proceed
   machinery.
8. DEBUG builds without warnings or errors, remains relocatable, and stays
   inside its linker envelope.
9. Focused VICE verification and existing execution-command regressions pass.
10. Tracking, changelog, DOX closeout, and walkthrough evidence are complete.
11. The user explicitly confirms the walkthrough before the task is marked
    done.
