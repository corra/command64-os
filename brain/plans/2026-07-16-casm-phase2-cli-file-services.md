---
feature: casm-native-assembler
phase: 2
created: 2026-07-16
status: completed
depends-on: casm-phase-1-native-application-scaffold
prerequisite-gate: casm-phase-0b-cli-file-contract-freeze
---

# CASM Phase 2 Implementation Plan: CLI and Native File-Service Foundation

Completed 2026-07-16 after build 1014 passed the full walkthrough and the user
explicitly approved closing Phase 2.

## Objective

Extend the completed Phase 1 scaffold into a bounded native front end that
parses one source filename and the initial option vocabulary, streams the source
through managed Command 64 file services, and survives parse, open, read, close,
and cleanup failures without leaking handles.

Phase 2 establishes interfaces consumed by the Phase 3 source stream and the
Phase 5 numeric static-output path. It does not tokenize, parse assembly
statements, create an assembler output, or claim runtime verification of output
write/delete behavior that has no production caller yet.

## Dependency Correction and Prerequisite Gate

The master plan's original Phase 0 combined contracts needed by many later
phases. Phase 1 approved only the scaffold subset. Before Phase 2 source work,
the user must approve this Phase 0B subset:

- the single-input Phase 2 command grammar and token rules;
- filename capacity and accepted filename bytes;
- the bounded input-buffer size;
- EOF and partial-read interpretation for `DOS_READ_FILE`;
- the managed file-record ABI and compensating-close rule; and
- the division between Phase 2 input runtime behavior and Phase 5 output
  runtime behavior.

Language, lexer, expression, symbol, VMM-store, emission-event, and R6 contracts
belong to a later Phase 0C gate and are not prerequisites for Phase 2.

## Proposed Phase 0B Values

### Command Grammar

```text
CASM source.asm [/O:output.prg] [/S] [/M] [/L]
```

- Exactly one positional source filename is required in Phase 2.
- Options may appear before or after the source and are case-insensitive.
- Source and output filename bytes retain their original case.
- `/O:<file>`, `/S`, `/M`, and `/L` may each appear at most once.
- `/O:` requires a non-empty filename in the same token.
- Unknown options, duplicate options, malformed `/O`, and a second positional
  filename are fatal parse errors.
- Tokens are separated by one or more spaces.
- Quoted filenames and embedded spaces are deferred.
- Multiple top-level inputs remain deferred to the VMM-backed source phase,
  which must extend this parser without changing the single-input behavior.
- Parsing reads but does not modify `CommandBuffer`.

### Bounds

- `CASM_FILENAME_MAX = 63`, excluding the null terminator.
- `CASM_IO_BUFFER_SIZE = 256` bytes.
- Parser traversal is additionally bounded by the 80-byte `CommandBuffer`.
- Every cursor increment, pointer addition, count update, and terminator write
  is checked before it is committed.

### Option Behavior

- `/O` is parsed, validated, and stored for the later output phase.
- `/S`, `/M`, and `/L` are parsed successfully, then produce the stable
  `CASM_DIAG_NOT_IMPLEMENTED` diagnostic before any file is opened.
- A plain invocation consumes the input stream, prints a Phase 2 validation
  message, and exits through central cleanup.
- Phase 2 does not create a placeholder or empty output file.

The user approved these values on 2026-07-16 before Phase 2 implementation.

## Scope

### Included

- synchronized Phase 2 task records and approved plan;
- bounded, non-destructive parsing from `CommandBuffer` and `ParsePos`;
- one source filename and the `/O`, `/S`, `/M`, `/L` option vocabulary;
- deterministic output-name derivation for later use;
- managed input open, buffered read, explicit close, and fatal cleanup;
- generic managed output wrapper ABI without an artificial runtime caller;
- real central cleanup for registered file handles;
- allocation-free CLI and file-service diagnostics;
- build, artifact, disk-image, static fault-path, and user runtime checks; and
- required task, brain, changelog, walkthrough, and DOX closeout updates.

### Excluded

- multiple top-level source files;
- quoted filenames or filenames containing spaces;
- source newline normalization, rewind, and provenance;
- lexer, statement parser, expressions, opcodes, symbols, and assembly passes;
- VMM allocation or VMM-backed storage;
- production output creation, serialization, and incomplete-output deletion;
- `.org`, `.byte`, `.word`, `.include`, `.static`, and `.reloc` behavior;
- R6 relocation records; and
- operational `/S`, `/M`, or `/L` features.

## Planned Files

| Path | Action | Phase 2 responsibility |
|---|---|---|
| `wiki/tasks/casm.md` | Modify | Phase 2 prerequisite, subtasks, and acceptance tracker |
| `brain/task.md` | Modify | Synchronize Task Warrior Phase 2 state |
| `src/external/casm/common.inc` | Modify | CLI, file, stream, state, and diagnostic constants |
| `src/external/casm/casm.s` | Modify | Phase 2 orchestration |
| `src/external/casm/cli.s` | Create | Bounded command-line parser and name derivation |
| `src/external/casm/fileio.s` | Create | Managed file wrappers and bounded input reader |
| `src/external/casm/resources.s` | Modify | Replace file cleanup stub with real close logic |
| `src/external/casm/diagnostics.s` | Modify | CLI and file-service diagnostics |
| `src/external/casm/AGENTS.md` | Review/Modify if needed | Record durable Phase 2 contracts only if changed |
| `brain/KNOWLEDGE.md` | Modify | Record approved CLI and file-service decisions |
| `brain/MEMORY.md` | Modify | Record measured BSS and linked-size use |
| `CHANGELOG.md` or dated changelog | Modify/Create | Record observable Phase 2 behavior |
| `brain/walkthroughs/2026-07-16-casm-phase2-cli-file-services.md` | Create | Build and user confirmation evidence |

The current `$1000` `MAIN` envelope remains in force. If measured Phase 2 code
does not fit, implementation stops for approval of a measured size change.

## Work Package 1: Tasks and Phase 0B Approval

1. Add Phase 2 and one measurable subtask per work package to
   `wiki/tasks/casm.md`.
2. Create matching Task Warrior records and synchronize their UUIDs in
   `brain/task.md`.
3. Record the Phase 0B values above as awaiting approval.
4. Obtain explicit user approval before editing Phase 2 source files.
5. Keep the Phase 2 milestone open until the final walkthrough is approved.

Gate: the three task representations agree and the Phase 0B values are
explicitly approved.

## Work Package 2: Shared ABI and Bounded State

Extend `common.inc` with:

- filename and I/O-buffer capacities;
- CLI option bits and parser-result identifiers;
- Phase 2 phase/state identifiers;
- read/write access modes and output file type;
- invalid handle and invalid registry-slot sentinels;
- input-stream states; and
- stable diagnostics for missing or extra source, malformed `/O`, duplicate or
  unknown option, filename overflow, unavailable feature, input open/read/close
  failure, output create/write/close/delete failure, short write, cleanup
  failure, and invalid internal stream state.

Add only bounded BSS:

- source and output filename buffers;
- option flags and filename lengths;
- one 256-byte I/O buffer;
- input/output handle and registry-slot state;
- 16-bit requested and completed transfer counts; and
- output-created/output-valid flags reserved for the Phase 5 consumer.

Use `$80-$83` only for narrowly documented CLI parser scratch. File transfers
use the existing `$78-$7B` I/O fields. Later expression, pass, and emission
scratch remains reserved.

Gate: a static memory audit confirms all storage is bounded and no OS-owned or
later-phase zero-page field is consumed.

## Work Package 3: Bounded CLI Parser

Create `cli.s` with these public routines:

```text
cliInit
cliParse
cliDeriveOutputName
```

`cliInit` clears all parser state and initializes handles and registry slots to
invalid sentinels.

`cliParse`:

1. Starts at `ParsePos` and advances safely to the argument region.
2. Stops at a null byte or the 80-byte command-buffer bound.
3. Skips repeated spaces.
4. Classifies slash-prefixed tokens as options and other tokens as filenames.
5. Folds case only while matching option letters.
6. Copies filename bytes into bounded local buffers without modifying the
   command buffer.
7. Rejects missing, duplicate, malformed, unknown, overlong, or excess input.
8. Returns carry clear with stable parsed state, or carry set with a
   `CASM_DIAG_*` value.

`cliDeriveOutputName` preserves an explicit `/O` value. Otherwise it copies the
source name, replaces the final extension with `.PRG`, or appends `.PRG` when no
extension exists. Device prefixes are preserved and overflow is rejected. The
routine does not create a file.

Every public routine documents inputs, outputs, carry and zero semantics,
preserved registers, clobbers, and shared scratch.

Gate: table-driven static cases cover every accepted and rejected token shape,
including both filename boundaries.

## Work Package 4: Managed File Wrappers

Create `fileio.s` with:

```text
fileOpenInput
fileCreateOutput
fileRead
fileWrite
fileClose
fileDelete
inputStreamOpen
inputStreamRead
inputStreamClose
outputAbort
```

### Open Transaction

After `DOS_OPEN_FILE` succeeds, the wrapper immediately registers the returned
handle. If registration fails, it preserves registry exhaustion as the primary
error and directly closes the unregistered handle as a compensating action.
No successful open may return without either a registry slot or a confirmed
compensating close.

### Read Contract

- `fileRead` sets the managed handle, destination pointer, and bounded 16-bit
  request count before calling `DOS_READ_FILE`.
- It returns the actual 16-bit byte count.
- A successful nonzero read is data.
- A successful zero-byte read is EOF.
- The existing carry-set/zero-count read-past-EOF compatibility result is also
  normalized to EOF.
- Any other carry-set result is a read failure.
- Stream position and cumulative count advance only after a successful read.

### Close Contract

`fileClose` releases the registry slot only after `DOS_CLOSE_FILE` succeeds. A
failed close retains ownership so central cleanup can retry it. Closing an
already-closed local record is harmless.

### Output ABI Boundary

Output wrappers receive static review and build coverage in Phase 2, but have no
artificial production caller. Phase 5 must activate runtime create/write/close,
short-write detection, output-valid state, and `outputAbort` deletion when the
numeric assembler has real bytes to serialize.

Gate: all open/registration/close transitions have a single documented owner,
and every failure preserves the primary diagnostic.

## Work Package 5: Real Central File Cleanup

Replace the Phase 1 file invalidation stub with bounded close logic:

1. Visit each owned file record once.
2. Load its handle into `FileHandle` and call `DOS_CLOSE_FILE`.
3. Clear the record and decrement `CasmFileCount` only after success.
4. Retain a failed record and continue closing other records.
5. Return `CASM_DIAG_CLEANUP_FAILED` if any close failed.

Cleanup remains repeat-safe and recursion-guarded. VMM cleanup remains a stub
until the separately gated VMM-storage phase. `exitFatal` preserves its primary
diagnostic if cleanup fails; `exitSuccess` must not silently discard a cleanup
failure.

Gate: empty, partially populated, fully populated, repeat, and close-failure
registry cases are statically traced and bounded.

## Work Package 6: Diagnostics

Extend `diagnostics.s` with stable, allocation-free messages for all Phase 2
parse and input-service failures. Output diagnostics are reserved now so the
Phase 5 output consumer does not renumber the diagnostic ABI.

Diagnostics do not open files, allocate memory, or require filename provenance.
Filename/line formatting begins with the Phase 3 source-location contract.

Gate: every Phase 2 failure has one stable diagnostic and unknown internal
errors retain a final fallback.

## Work Package 7: Entry-Point Orchestration

Update `casm.s` to:

1. initialize central resources and CLI state;
2. print the version banner;
3. parse the command line;
4. reject successfully parsed `/S`, `/M`, or `/L` as unavailable before I/O;
5. derive and retain the future output name;
6. open the input stream;
7. read 256-byte blocks until normalized EOF;
8. update a checked cumulative byte count;
9. explicitly close the source;
10. print a stable Phase 2 validation message; and
11. exit through `exitSuccess`.

All errors transfer the primary diagnostic in `A` to `exitFatal`. No Phase 2
module invokes `DOS_EXIT` directly.

Gate: one normal orchestration path owns explicit closure and the central fatal
path owns all incomplete-operation cleanup.

## Work Package 8: Verification

### Static Review

Confirm:

- parser traversal is bounded by both the null terminator and buffer capacity;
- every filename terminator is within its allocation;
- option case folding never changes filename bytes;
- every open is registered immediately or compensating-closed;
- a failed close retains ownership;
- cleanup attempts all owned records and preserves the primary error;
- output runtime behavior is not claimed before Phase 5;
- VMM cleanup remains unchanged; and
- no Phase 3+ lexer, parser, expression, symbol, emission, or relocation logic
  entered Phase 2.

### Build and Artifact Inspection

```text
cmake -S . -B build
cmake --build build --target casm
cmake --build build --target casm
cmake --build build --target image_d64
```

Record zero warnings/errors, both comparison links, PRG header, R6 footer,
linked size, BSS size, relocation count, source manifest, stable no-change build
number, and release-disk contents. A successful exit code alone is insufficient.

### User Runtime Matrix

The user verifies in the supported local emulator or on hardware:

- missing source;
- valid empty, short, exact-256-byte, and multi-block sources;
- missing file, unavailable device, and reproducible read failure;
- extra source, unknown option, duplicate options, malformed `/O`;
- both filename length boundaries;
- option ordering, case variants, and repeated spaces;
- `/S`, `/M`, and `/L` stable unavailable-feature behavior;
- safe shell return followed by `DIR` and an existing external application;
- a second CASM launch after successful and failed input operations; and
- no progressive handle, channel, stack, keyboard, or screen corruption.

Do not use the broken `c64-testing` MCP or a web emulator. Output create/write,
disk-full, short-write, delete, and incomplete-output runtime tests are explicit
Phase 5 dependencies, not Phase 2 acceptance criteria.

## Atomic Implementation Order

1. Create synchronized Phase 2 task records.
2. Obtain approval of the Phase 0B values.
3. Add shared ABI constants and bounded state.
4. Implement and review `cli.s`.
5. Implement input wrappers and stream normalization.
6. Replace the central file cleanup stub.
7. Build and inspect the narrow CASM target.
8. Add the inactive generic output wrapper ABI.
9. Extend diagnostics and entry-point orchestration.
10. Rebuild and inspect CASM and the release disk.
11. Update brain, task, changelog, and applicable DOX records.
12. Create the walkthrough and ask the user to run the manual matrix.
13. Ask the user whether Phase 2 may be marked done.

Execute one approved increment at a time. On failure, stop for root-cause
analysis before altering the design.

## Downstream Dependency Contract

- Phase 3 consumes the managed input wrapper and adds rewind, newline
  normalization, filename identity, line provenance, and lexer behavior.
- The statement parser and constant-expression phase consumes Phase 3; neither
  is implicitly implemented here.
- Phase 5 is the first production consumer of output create/write/close/delete
  and must verify short writes and incomplete-output deletion at runtime.
- VMM storage must be implemented before any VMM-backed symbol table or
  VMM-backed source phase.
- Structured emission events must exist before the listing consumer.

## Completion Gate

Phase 2 is ready for user completion approval only when:

- the Phase 0B contracts are approved and recorded;
- CLI parsing passes every bounded acceptance case;
- input streaming handles empty, exact-block, short-final-block, and multi-block
  files;
- every open handle is tracked or compensating-closed;
- explicit close and fatal cleanup leave no confirmed handle leak;
- primary diagnostics survive secondary cleanup failures;
- CASM remains within an approved measured memory envelope;
- the release disk remains intact;
- task, brain, changelog, walkthrough, and applicable DOX records agree; and
- the user completes the runtime walkthrough and explicitly approves marking
  Phase 2 done.

Output serialization and incomplete-output runtime cleanup are not Phase 2
completion criteria; they remain explicit gates for the numeric static-output
phase.

## Progress

- Detailed plan created from the dependency review.
- Phase 0B values approved by the user on 2026-07-16.
- Task Warrior, `wiki/tasks/casm.md`, and `brain/task.md` Phase 2 records
  synchronized.
- Shared Phase 2 CLI/file ABI declared in `common.inc`; `casm` builds as
  `0.1.0.1001`, remains 687 bytes with 547 code bytes and 66 relocation points,
  and a no-change rebuild preserves build 1001.
- Bounded `cli.s` implemented with non-destructive single-source parsing,
  case-insensitive `/O`, `/S`, `/M`, and `/L`, duplicate/malformed/overflow
  rejection, and deterministic `.PRG` derivation. Build 1002 uses 1,010 linked
  code/data bytes, 176 BSS bytes, 110 relocations, and a 1,238-byte R6 artifact.
- Managed `fileio.s` implemented with immediate registration, compensating
  close, normalized EOF, checked 16-bit input totals, explicit close/release,
  short-write detection, and inactive output-abort support. Build 1003 uses
  1,634 linked code/data bytes, 446 BSS bytes, 195 relocations, and a 2,032-byte
  R6 artifact; a no-change rebuild preserves build 1003.
- The user reported all Work Package 4 tests passing on 2026-07-16.
- Central file cleanup now performs real bounded close attempts, retains failed
  records, continues after individual failures, and reports cleanup failure
  without replacing a primary fatal diagnostic. Build 1004 uses 1,703 linked
  code/data bytes, 448 BSS bytes, 208 relocations, and a 2,127-byte R6 artifact;
  a no-change rebuild preserves build 1004.
- Allocation-free diagnostics now cover every stable Phase 2 code through
  bounded parallel pointer tables, retain the unknown fallback, and expose the
  fixed successful-validation message for orchestration. Build 1005 uses 2,189
  linked code/data bytes, 448 BSS bytes, 226 relocations, and a 2,649-byte R6
  artifact; a no-change rebuild preserves build 1005.
- Entry-point orchestration now initializes Phase 2 state, parses the CLI,
  rejects unavailable features before I/O, derives the future output name,
  consumes input to normalized EOF, closes explicitly, reports validation, and
  uses central fatal cleanup for every error. Build 1006 uses 2,251 linked
  code/data bytes, 448 BSS bytes, 238 relocations, and a 2,735-byte R6 artifact;
  a no-change rebuild preserves build 1006.
- Runtime verification of build 1006 exposed a stale resource record after an
  otherwise successful input close. Root cause: `fileClose` retained the
  registry slot in transient shared zero page across `DOS_CLOSE_FILE`, whose OS
  service contract does not preserve that scratch value. Build 1007 stores the
  slot in CASM-owned bounded BSS until the close succeeds, then releases the
  saved record. It uses 2,254 linked code/data bytes, 449 BSS bytes, 241
  relocations, and a 2,744-byte R6 artifact; a no-change rebuild preserves build
  1007. Runtime confirmation showed the cleanup failure still occurs, so the
  saved-slot hypothesis was insufficient. Build 1008 adds bounded `O`pen,
  `R`elease, and `C`leanup registry snapshots (`S`lot, `H`andle, `F`lag, and
  file `C`ount) without changing ownership decisions. It uses 2,436 linked
  code/data bytes, 454 BSS bytes, 272 relocations, and a 2,988-byte R6 artifact;
  the release disk and no-change rebuild pass. Runtime snapshot capture remains
  open before the final remediation is selected.
- Build 1008 runtime output showed `O` followed by `C` with no `R`: registration
  succeeded, explicit close never reached resource release, and cleanup found
  slot 0 unchanged. Build 1009 adds `B`efore/`A`fter-close snapshots and the
  resident kernel handle-table status (`Kxx`), while reloading the saved handle
  after diagnostic output. It uses 2,492 linked code/data bytes, 456 BSS bytes,
  284 relocations, and a 3,068-byte R6 artifact; the release disk and no-change
  rebuild pass. Runtime capture remains open.
- Build 1009 runtime again showed only `O` and `C`, both with kernel status
  `K01`; neither before-close nor after-close instrumentation ran. Build 1010
  adds `D` at the orchestration close gate, `E` with the input state on wrapper
  entry, and `F` with any earlier fatal diagnostic. It uses 2,564 linked
  code/data bytes, 457 BSS bytes, 300 relocations, and a 3,172-byte R6 artifact;
  the release disk and no-change rebuild pass. Runtime capture remains open.
- Build 1010 reported fatal value `$03` before the close gate. Root cause:
  `inputStreamRead` compared `A` with `CASM_STREAM_EOF` and returned directly on
  equality, leaking `CMP`'s set carry to its caller. Orchestration interpreted
  normal EOF `$03` as fatal diagnostic `$03`, whose message is resource cleanup
  failure, and therefore entered fatal cleanup before explicit close. Build
  1011 explicitly clears carry on the EOF return, removes all temporary RCA
  instrumentation, and retains BSS preservation of the registry slot across
  `DOS_CLOSE_FILE`. It uses 2,256 linked code/data bytes, 449 BSS bytes, 241
  relocations, and a 2,746-byte R6 artifact; the release disk and no-change
  rebuild pass. The user verified build 1011 accepts a text input, prints
  `CASM: INPUT VALIDATED`, returns without a cleanup diagnostic, and approved
  completing the EOF/cleanup remediation subtask.
- Phase 2.8 now generates deterministic stream fixtures through the CMake build:
  `casmempty` (0 bytes), `casmshort` (17 bytes), `casm256` (256 bytes), and
  `casmmulti` (513 bytes). `test_image_d64` adds all four as SEQ entries; the
  empty entry uses cc1541's directory-only mode because cc1541 rejects a
  zero-byte host input. Configure, fixture-size checks, and the complete test
  image build pass with all prior test programs and fixtures retained.
- Runtime verification passed for `casmshort`, `casm256`, and `casmmulti` with
  `CASM: INPUT VALIDATED`. The directory-only zero-block `casmempty` entry
  returns `CANNOT OPEN INPUT`; the user identified and accepted this as a
  Commodore DOS/device limitation rather than a CASM stream failure.
- An in-progress Phase 2 walkthrough now records automated evidence, confirmed
  runtime results, and the exact pending CLI command/diagnostic matrix.
- Runtime CLI verification showed every slash option returning unknown-option
  while plain `CASM CASMSHORT` remained correct. Temporary build 1012 prints
  the raw and `$5F`-normalized option-letter bytes as `CASM OPT Rxx Nxx`, while
  preserving the parser cursor. It uses 2,355 linked code/data bytes, 453 BSS
  bytes, 257 relocations, and a 2,877-byte R6 artifact; no-change CASM and full
  test-image builds pass. Runtime byte capture remains open.
- Build 1012 reported raw `$53`, normalized `$53` for `/S`, proving the option
  byte and normalization are correct. Temporary build 1013 additionally prints
  the matched branch, option-letter index, and trailing byte as
  `CASM BR <option> Ixx Txx`. It uses 2,465 linked code/data bytes, 453 BSS
  bytes, 275 relocations, and a 3,023-byte R6 artifact; no-change CASM and full
  test-image builds pass. Runtime branch/cursor capture remains open.
- Build 1013 printed the normalized `$53` line but never reached the `/S`
  branch, proving the ca65 character literal did not encode as unshifted
  PETSCII `$53`. Build 1014 replaces every CLI grammar comparison and derived
  `.PRG` byte with explicit PETSCII constants and removes all temporary option
  diagnostics. It returns to 2,256 linked code/data bytes, 449 BSS bytes, 241
  relocations, and a 2,746-byte R6 artifact; no-change CASM and full test-image
  builds pass. Runtime CLI matrix confirmation remains open.
- The user confirmed build 1014 reports feature-not-implemented for `/S` and
  accepts `/O:OUT.PRG` while validating the input and creating no output file.
- The user confirmed build 1014 passes the extra-source, unknown-option,
  duplicate-option, malformed-`/O`, malformed-flag, `/M`, and `/L` runtime
  cases with their expected diagnostics.
- The user confirmed the 63-byte source boundary is accepted through open, the
  64-byte source is rejected as too long, and a final post-error
  `CASM CASMSHORT` succeeds. All Phase 2 runtime matrix cases are now complete;
  only explicit milestone completion approval remains open.

### Work Package 3 Static Audit

| Case | Expected result | Audited path |
|---|---|---|
| Missing source or only options | `CASM_DIAG_SOURCE_REQUIRED` | `cpFinish` |
| Second positional token | `CASM_DIAG_EXTRA_SOURCE` | `ccsExtra` |
| 63-byte filename | accepted and terminated at byte 63 | `ccsLoop` / `cpoOutputLoop` |
| 64-byte filename | `CASM_DIAG_FILENAME_TOO_LONG` before write | `ccsTooLong` / `cpoOutputTooLong` |
| Duplicate recognized option | `CASM_DIAG_DUPLICATE_OPTION` | `cpoDuplicate` |
| `/O`, `/O:`, or `/O value` | `CASM_DIAG_MALFORMED_OUTPUT_OPTION` | `cpoMalformedOutput` |
| Unknown or extended flag token | `CASM_DIAG_UNKNOWN_OPTION` | `cpoUnknown` |
| PETSCII/ASCII case variants | same option bit | `$5F` comparison mask |
| Explicit output | preserved byte-for-byte | `cliDeriveOutputName` explicit path |
| Source with extension | last post-prefix extension replaced by `.PRG` | `cdonCopied` |
| Source without extension | `.PRG` appended if bounded | `cdonAppendExtension` |
| Derived-name overflow | `CASM_DIAG_FILENAME_TOO_LONG` before write | `cdonTooLong` |
| Buffer reaches byte 80 without terminator | bounded failure | all token loops |

### Work Package 4 Static Audit

| Transition | Required result | Audited implementation |
|---|---|---|
| OS open fails | stable input/output open diagnostic | `foiOpenFailed` / `fcoCreateFailed` |
| Open succeeds, registration succeeds | handle and slot committed together | `fileOpenInput` / `fileCreateOutput` |
| Open succeeds, registration fails | unregistered handle compensating-closed; primary preserved | registration-failure paths |
| Read returns bytes | actual 16-bit count and `CASM_STREAM_DATA` | `fileRead` |
| Read returns zero, including carry-set compatibility | normalized `CASM_STREAM_EOF` | `frEof` |
| Read fails with partial count | count preserved; stream becomes error | `fileRead` error path |
| 16-bit consumed total wraps | fatal stream-state diagnostic | `isrOverflow` |
| Full write | requested and actual counts match | `fileWrite` |
| Short or failed write | output invalidated with stable diagnostic | write-failure paths |
| Close succeeds | registry released only after OS close | `fileClose` |
| Close fails | slot remains owned for central cleanup | `inputStreamClose` / `outputAbort` |
| Output abort has a primary error | close/delete secondary errors cannot replace it | `oaRecordSecondary` |

Output create/write/delete routines are compiled and statically audited but
remain outside Phase 2 runtime acceptance until the numeric static-output phase
provides a production caller.

### Work Package 5 Static Audit

| Registry state | Required result | Audited path |
|---|---|---|
| Empty slot | no OS call; success | `cfrSuccess` |
| Owned slot, close succeeds | clear flag/handle and decrement count once | `cleanupFileRecord` success |
| Owned slot, close fails | retain record/count and report failure | `cfrFailed` |
| One close fails | remaining slots are still visited | `rcFileLoop` |
| Repeated cleanup after success | cleared records are harmless | `cfrSuccess` |
| Repeated cleanup after failure | retained record is attempted again | `cleanupFileRecord` |
| Fatal exit cleanup fails | original `CasmLastDiag` remains primary | `exitFatal` |
| Success exit cleanup fails | cleanup diagnostic is printed before exit | `exitSuccess` |
| Recursive cleanup entry | guard returns without a second traversal | `rcAlreadyActive` |

### Work Package 6 Static Audit

| Diagnostic input | Required result | Evidence |
|---|---|---|
| `$01-$13` | exact stable message | contiguous low/high tables |
| `$00` | internal-error fallback | lower-bound branch |
| `$14-$FE` | internal-error fallback | upper-bound branch |
| `$FF` | internal-error fallback | upper-bound branch |
| Table size changes | assembly failure unless both tables still cover 19 codes | two `.assert` checks |
| Cleanup-time diagnostic | no allocation or file/VMM acquisition | `diagPrintString` only |
| Successful input validation | fixed nonfatal message | `diagPrintPhase2Ready` |

### Work Package 7 Static Trace

| Stage | Success transition | Failure transition |
|---|---|---|
| Resource initialization | CLI initialization | `exitFatal` |
| CLI initialization | file-state initialization | `exitFatal` |
| File-state initialization | banner and parse | `exitFatal` |
| CLI parse | option gate | `exitFatal` with parser diagnostic |
| `/S`, `/M`, or `/L` present | none | not-implemented fatal before open |
| Output-name derivation | input open | `exitFatal` |
| Input open | bounded read loop | `exitFatal`; registered handle remains owned |
| Input data | next read | `exitFatal` on read/size failure |
| Normalized EOF | explicit close | none |
| Explicit close | validation message | `exitFatal`; failed record remains owned |
| Validation message | `exitSuccess` cleanup | none |

No Phase 2 orchestration path calls `DOS_EXIT` directly or creates an output
file.
