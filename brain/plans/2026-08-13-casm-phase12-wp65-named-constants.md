---
feature: casm-phase12-wp65-named-constants
created: 2026-08-13
status: approved
taskwarrior: e32c08c8-1435-43b2-a075-a2bb2f6e0c8f
depends-on: c307441c-74ab-47a8-bb4c-e997d38bcf99 (WP64, complete)
---

# Plan: CASM Phase 12 WP65 — Named Constant Definitions

## Status

**Approved 2026-08-13.** Implementation of the Atomic Increments below is
now authorized.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`.
Prerequisite: WP64 (contract freeze), complete and user-approved
2026-08-13 —
`brain/plans/2026-08-13-casm-phase12-wp64-contract-freeze.md`,
`brain/walkthroughs/2026-08-13-casm-phase12-wp64-contract-freeze.md`.

## Objective

Add named-constant definitions to CASM: `identifier = expression` as a new
top-level statement, sharing the existing 512-entry symbol table via a new
`CASM_SYMBOL_FLAG_CONSTANT` bit (frozen by WP64), plus the
`CASM_DIAG_EXPR_CIRCULAR` diagnostic for genuine circular definitions.
Constants may forward-reference other constants *and* labels defined
later in the source (per user direction 2026-08-13, superseding the
narrower define-before-use option). Does **not** deliver: any new
operator (`*`,`/`,`<<`, etc. — WP68), parentheses (WP67), the
current-address symbol (WP66), or character literals (WP69). A
constant's own defining expression is limited to today's existing
grammar: `['<'|'>'] (NUMBER|IDENTIFIER) [('+'|'-') NUMBER]`.

## Scoping Decisions (user-confirmed 2026-08-13)

1. **Syntax**: `identifier '=' expr` (ca65-style), a third top-level
   statement form alongside `IDENTIFIER ':'` (label) and
   `(MNEMONIC|DIRECTIVE) operandSeq`, distinguished from a label purely by
   the token following the identifier (`=` vs `:`). Not a dot-directive.
2. **Forward references**: full support, including genuine transitive
   cycles (`a = b` / `b = a`), resolved lazily with cycle detection —
   **not** restricted to define-before-use. This is materially larger
   than WP64's own contract anticipated (which left the mechanism
   unspecified); see Technical Design below for how it's made tractable
   without re-scanning source text or storing duplicate name copies.
3. **Constants may reference labels** (not just other constants) — this
   follows directly from WP64's own frozen representability rule
   ("...a single symbol reference (label, relocatable named constant, or
   the current-address symbol)..." — `brain/KNOWLEDGE.md`, Phase 12 WP64
   section, point 1), which already anticipates a relocatable constant
   like `bufptr = mylabel`. A design that only allowed constant-to-
   constant references would contradict that.

## Technical Design

**Why a label-forward-reference-capable design is tractable**: CASM's
existing two-pass architecture already solves "forward reference to a
not-yet-assigned address" for labels used directly in operands — Pass 1
(MEASURE) doesn't need actual values, only PC advancement; Pass 2 (EMIT)
re-resolves every operand once every label's final address is known. The
same trick applies to constants: **defer constant value resolution to the
Pass 1 → Pass 2 boundary**, after every label and every constant *name*
is already in the symbol table, rather than resolving inline as each
`identifier = expr` statement is parsed.

1. **Pass 1 (unchanged in spirit)**: when `crpConstant` (new, sibling to
   `casm.s:395-421`'s `crpLabel`) reaches an `identifier = expr`
   statement, it inserts the symbol immediately (`CASM_SYMBOL_FLAG_
   DEFINED | CASM_SYMBOL_FLAG_CONSTANT`) but does **not** evaluate a
   symbol-referencing RHS yet:
   - RHS is a bare `NUMBER [('+' |'-') NUMBER]`: resolvable immediately,
     no dependency — compute now, store `VAL_LO/HI`, set a new
     `CASM_SYMBOL_FLAG_RESOLVED` bit immediately.
   - RHS is `IDENTIFIER [('+'|'-') NUMBER]`: the referenced symbol may
     not exist yet (forward reference). Store a **source-position
     bookmark** to the RHS identifier token (`CasmSourceOffsetLo/Hi`-style
     16-bit VMM offset, matching the existing bookmark convention used
     elsewhere in `source.s`) plus its length and the addend/sign, in the
     symbol record's spare padding (see Storage below). Leave `RESOLVED`
     clear.
2. **New resolution sweep**, inserted at the existing Pass 1 → Pass 2
   seam (`casm.s:206`→`casm.s:265`, where `CASM_PASS_MODE_MEASURE`
   switches to `CASM_PASS_MODE_EMIT`): walk the symbol table once; for
   every `CONSTANT` entry still missing `RESOLVED`, resolve it:
   - Re-read the few bytes at its stored VMM bookmark (a single small VMM
     read, not a full source re-scan) to recover the referenced name.
   - `symbolsLookup` it. If found and already `RESOLVED` (label — Pass 1
     already assigned its final address; or an already-resolved
     constant): apply the stored addend, cache `VAL_LO/HI`, set
     `RESOLVED`.
   - If found but itself an unresolved constant: resolve it first
     (iteratively, not via 6502-stack recursion — see Cycle Detection),
     then apply as above.
   - If not found at all: existing "unresolved symbol" diagnostic (no new
     code needed — this is the same case as an operand referencing a
     name that was never defined anywhere).
3. **Pass 2 (EMIT)**: unchanged — every constant now has a valid
   `VAL_LO/HI`, read exactly like a label's. Relocatable classification
   (`CASM_EXPR_FLAG_RELOCATABLE`) for a constant defined as `= label` or
   `= label+N` reuses `expr.s`'s existing identifier-classification path
   (relocatable iff the *resolved* underlying reference is a label and
   the assembly is running in relocatable mode) — no new classification
   logic, just extending the existing check to look through a resolved
   constant to what it ultimately names.

**Cycle detection**: a transient in-RAM "currently resolving" marker
(bounded small bitmap or a scratch byte per in-progress ID, since the
resolution sweep's own working set is small — at most one open chain at a
time for a depth-first walk) is set on a symbol's ID when its resolution
begins and cleared when it completes. If the walk reaches a symbol whose
marker is already set, that is a genuine cycle:
`CASM_DIAG_EXPR_CIRCULAR` ($43). The walk is iterative (explicit loop
bounded by `CASM_SYMBOL_MAX` = 512 steps as a hard backstop), not
recursive, to avoid 6502 stack depth risk.

**Symbol record storage** (64-byte record, `common.inc:1006-1023`; 27
bytes currently reserved/zero-filled padding at offsets 37-63): repurpose
up to 7 of those bytes for the deferred-reference bookmark — exact field
layout (`CASM_SYMBOL_REC_REF_VMM_LO/HI`, `..._REF_LEN`,
`..._REF_ADDEND_LO/HI`, `..._REF_SIGN`) pinned with `.assert`s in
Increment 1, following the project's existing contiguity-assertion style.
Record size stays 64 bytes — no VMM allocation/capacity change, no
envelope cost from storage.

**New flags** (`common.inc:1015`, currently only bit 0 `DEFINED`):
- `CASM_SYMBOL_FLAG_CONSTANT = %00000010` (frozen by WP64).
- `CASM_SYMBOL_FLAG_RESOLVED = %00000100` (new; WP64 didn't anticipate
  needing this, but it's required to distinguish "constant, value known"
  from "constant, still deferred" across the resolution sweep — a label
  is always implicitly resolved the moment `crpLabel` inserts it, so this
  bit is meaningful only for constants; it is *not* set for labels,
  matching WP64's `map.s` flags-allowlist update below).

**`symbolsInsert` ABI extension**: no flags parameter exists today
(`symbols.s:266`, hardcodes `CASM_SYMBOL_FLAG_DEFINED` at line 319).
Extend it to read a new caller-set scratch byte (`CasmSymbolInsertFlags`)
instead of hardcoding — `crpLabel` is updated to explicitly set
`DEFINED` before its `JSR symbolsInsert` (formalizing today's implicit
behavior, not silently defaulting); `crpConstant` sets
`DEFINED|CONSTANT[|RESOLVED]` as appropriate. `symbolsLookup` is extended
to surface the Flags byte in its `CASM_RESOLVE_*` view (today it does
not, per research) so callers — the new resolution sweep and `expr.s`'s
relocatable classification — can branch on constant/resolved state.

**`map.s` flags check**: `mapValidateRecord` (`map.s:121-145`, load-
bearing check at `map.s:130-132`) currently rejects any flags byte other
than exactly `CASM_SYMBOL_FLAG_DEFINED`. Extend to an explicit allowlist:
`DEFINED`, `DEFINED|CONSTANT|RESOLVED` (a fully-resolved constant is the
only valid persisted state by the time Pass 2/map output runs — an
unresolved constant surviving to this point is itself a bug, not a valid
row, and should trip the existing corruption diagnostic). No `/M` output
*format* change — constants list alongside labels using the existing
`$HHHH NAME` row format (explicitly excluded from this WP: a
kind-distinguishing column, if wanted, is a separate follow-up).

**New diagnostic**: `CASM_DIAG_EXPR_CIRCULAR = $43`, following
`CASM_DIAG_PHASE10_WP52_LAST = $42` (confirmed current last code,
`common.inc:718,769`), same `PriorLast + 1` + final-pin `.assert` style
as every prior phase. `CASM_DIAG_PHASE12_WP65_LAST = $43` (WP66-69 extend
from `$44`).

**Envelope**: bump `PRG_SIZE_HEX` from `5500` to `6000`
(`CMakeLists.txt:320`, `add_ca65_app(casm ... 1000 "5500")`) as WP64
recommended. A firmer byte estimate is deferred to Increment 8's actual
measured build (the new resolution sweep, extra flag/lookup plumbing,
and `crpConstant` handler are the main cost; rough order-of-magnitude
matches WP64's original 1,550-2,600 byte estimate for the *whole* Phase
12, of which WP65 is one slice).

## Scope

**Included:**
- `=` token (lexer), `identifier = expr` grammar (parser), `crpConstant`
  driver logic (casm.s), symbol-table flag/ABI extension, the Pass1→Pass2
  resolution sweep with cycle detection, `CASM_DIAG_EXPR_CIRCULAR`,
  `map.s` flags-allowlist update, `PRG_SIZE_HEX` bump, new test harness.
- Constants referencing: a numeric literal (+addend), another constant
  (forward or backward, cycle-detected), or a label (forward or
  backward — labels are always fully known by the resolution sweep,
  which runs after Pass 1 completes).
- Duplicate-name rejection across kinds (constant redefining a label's
  name or vice versa) — reuses existing `CASM_DIAG_DUPLICATE_SYMBOL`
  (confirm in Increment 2 that `symbolsInsert`'s existing name-match
  check is kind-agnostic, which research indicates it already is).

**Excluded:**
- Any new operator, parentheses, current-address symbol, character
  literals (later WPs).
- A `/M` symbol-map column distinguishing constants from labels.
- Constants referencing an expression that itself needs WP67/68's
  richer grammar (structurally impossible right now — `exprEvaluate`
  only understands today's flat grammar regardless of caller).

## Atomic Increments

1. **Symbol record + flags**: add `CASM_SYMBOL_FLAG_CONSTANT`,
   `CASM_SYMBOL_FLAG_RESOLVED`, and the `REF_*` bookmark fields to
   `common.inc` with `.assert`-pinned offsets inside the existing 64-byte
   record. No behavior change yet — verify existing symbol fixtures
   (`tests/src/casm_symbols/`) still pass unmodified (padding-only
   change).
2. **`symbolsInsert`/`symbolsLookup` ABI extension**: add
   `CasmSymbolInsertFlags` scratch-byte input to `symbolsInsert`; update
   `crpLabel` to set it explicitly to `DEFINED`. Extend `symbolsLookup`'s
   `CASM_RESOLVE_*` view to surface Flags. Verify: existing label
   fixtures/harnesses unaffected (this is a pure ABI formalization for
   the label path).
3. **Lexer**: `CASM_TOKEN_EQUALS = $10` (bump `CASM_TOKEN_COUNT` +
   assert), punctuation-table entry (`lexer.s:1080-1088`). New harness
   coverage: `=` tokenizes correctly, doesn't collide with any existing
   token.
4. **Parser grammar**: split `parser.s:96-119`'s identifier dispatch into
   `ppsIdentifierStatement`, branching on the token after the identifier
   (`COLON` → existing `ppsLabel` body, `EQUALS` → new `ppsConstant`,
   else `CASM_DIAG_SYNTAX_ERROR`). `ppsConstant` parses the RHS via the
   existing expression-operand path, captures the VMM bookmark for an
   identifier-RHS (or the resolved value for a numeric-RHS), and reports
   the statement type to the driver.
5. **`crpConstant` driver + immediate resolution**: `casm.s` handler,
   Pass 1 only (mirrors `crpLabel`'s `CASM_PASS_MODE_MEASURE` gate),
   inserting the symbol with the correct flags per RHS kind (numeric =
   resolved now; identifier = deferred). Duplicate-name collision
   verified to already route through `CASM_DIAG_DUPLICATE_SYMBOL`
   unchanged.
6. **Resolution sweep + cycle detection**: new routine at the Pass1→Pass2
   seam (`casm.s:206`/`265`) walking all `CONSTANT`-flagged, unresolved
   entries; iterative resolution with the in-progress marker;
   `CASM_DIAG_EXPR_CIRCULAR` on a detected cycle; existing not-found
   diagnostic when a reference never resolves to any symbol. New
   diagnostic added to `common.inc` per the contiguity style.
7. **`map.s` flags-allowlist update**: accept `DEFINED|CONSTANT|RESOLVED`
   alongside plain `DEFINED`; confirm `/M` output for a resolved constant
   renders correctly (existing `$HHHH NAME` row format, no format
   change).
8. **`expr.s` relocatable classification for constants**: extend the
   existing label-relocatable check so an operand naming a *resolved*
   constant classifies `RELOCATABLE` iff the constant's own underlying
   reference chain bottoms out at a label (and the assembly is running
   relocatable) — otherwise static.
9. **Envelope bump + build verification**: `CMakeLists.txt:320`
   `"5500"` → `"6000"`; full `casm` target rebuild; measure actual bytes
   used vs. the new cap; confirm no regression across every existing
   CASM harness/disk image.
10. **New test harness**: `tests/src/casm_const/` (naming TBD at
    implementation time), covering: numeric constant; constant-
    referencing-constant (forward and backward); constant-referencing-
    label (forward and backward); direct self-reference (`a = a`);
    genuine transitive cycle (`a = b` / `b = a`); duplicate name vs. an
    existing label; `/M` output for a resolved constant; fault-injection
    coverage following `tests/src/casm_faultinject_symbols/`'s existing
    pattern for the new resolution-sweep code path.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Modify (flags, `REF_*` fields, `CASM_TOKEN_EQUALS`, `CASM_DIAG_EXPR_CIRCULAR`, all with `.assert`s) |
| `src/external/casm/lexer.s` | Modify (punctuation table) |
| `src/external/casm/parser.s` | Modify (`ppsIdentifierStatement`/`ppsConstant`) |
| `src/external/casm/casm.s` | Modify (`crpConstant`, resolution sweep) |
| `src/external/casm/symbols.s` | Modify (`symbolsInsert`/`symbolsLookup` ABI) |
| `src/external/casm/map.s` | Modify (flags allowlist) |
| `src/external/casm/expr.s` | Modify (relocatable classification through a resolved constant) |
| `CMakeLists.txt` | Modify (`PRG_SIZE_HEX` `5500`→`6000`) |
| `tests/src/casm_const/*` | Create (new harness) |
| `brain/KNOWLEDGE.md`, `brain/task.md`, `wiki/tasks/casm.md` | Modify (activation now, completion summary at close) |
| `docs/casm-utility.md`, `wiki/casm-utility.md`, `wiki/casm-programmers-reference.md` | Modify at completion (user-facing: named constants become real, usable syntax — unlike WP64, this WP *does* ship usable behavior) |

## Stop Conditions

- Any existing harness/fixture fails unexpectedly after the symbol-record
  or ABI changes (Increments 1-2 are meant to be behavior-preserving for
  labels — any drift there is a real regression, not an acceptable
  side effect).
- The resolution sweep's iterative walk needs more than
  `CASM_SYMBOL_MAX` steps to either resolve or detect a cycle for any
  legitimate (non-cyclic) chain — would indicate the bound is wrong, not
  that the chain is actually cyclic; stop and re-derive the correct
  bound rather than silently raising it.
- A no-change rebuild changes any artifact.
- The `$6000` envelope estimate proves insufficient once Increment 9's
  real build is measured — flag rather than silently bump again.
- A genuinely new defect outside this WP's own scope is found — disclose
  and defer as a separate follow-up (default), unless the user directs
  an inline fix in the moment.

## Documentation, Task, and DOX Updates

- Taskwarrior: new task under Phase 12 parent (43), depends-on WP64 (44).
- `brain/task.md`, `wiki/tasks/casm.md`: activation entry now; completion
  summary at close.
- `brain/KNOWLEDGE.md`: new WP65 section at close, documenting the final
  symbol-record layout, ABI, and resolution-sweep design as actually
  implemented (this plan's Technical Design is the proposal; the
  KNOWLEDGE.md entry at close is the as-built record).
- User-facing docs (`docs/casm-utility.md`, `wiki/casm-utility.md`,
  `wiki/casm-programmers-reference.md`): updated at completion, since
  unlike WP64 this WP ships real, usable syntax — `identifier = expr`
  needs a "Named Constants" section with examples, plus the lowercase-
  PETSCII convention note per WP64's contract item 8.
- `CHANGELOG.md`: entry at close.

## Completion Gate

WP65 completes only when: all 10 increments are implemented and verified
(existing harnesses green, new `casm_const` harness green under live
VICE, per this project's testing convention); the envelope bump is
confirmed sufficient by a real build; a completion-gate walkthrough
exists in `brain/walkthroughs/` with live evidence (harness runs, a
worked forward-reference example, a worked cycle-detection example); all
trackers (Taskwarrior, `brain/task.md`, `wiki/tasks/casm.md`,
`brain/KNOWLEDGE.md`, `CHANGELOG.md`, user-facing docs) are synchronized;
and the user explicitly approves closing WP65.

## Progress

- 2026-08-13: Drafted for review. Prerequisite WP64 confirmed complete
  and user-approved. Sub-agent research (Explore) grounded the technical
  design against live source: `parser.s:96-119,207-243` (label dispatch
  point), `casm.s:395-421` (`crpLabel`, Pass 1 only), `symbols.s:246-265,
  400-429` (`symbolsInsert`/`symbolsLookup`, confirmed no flags parameter
  and no flags surfaced to callers today), `common.inc:1006-1034`
  (64-byte record, 27 spare padding bytes, `CASM_SYMBOL_MAX = 512`),
  `map.s:121-145` (exact-flags corruption check), `common.inc:718,769`
  (`$42` last diagnostic code, contiguity-assert style),
  `CMakeLists.txt:320` (`PRG_SIZE_HEX` literal location),
  `tests/src/casm_symbols/casm_symbols.s` (existing fixture pattern to
  extend). Asked and got user direction on two scoping forks: constant
  syntax (`identifier = expr`, not a dot-directive) and forward-reference
  scope (full forward-reference + lazy cycle detection, not restricted to
  define-before-use — a materially larger design than WP64's contract
  text alone specified). Discovered during design that WP64's own
  representability rule (a constant may be `= label`) requires constants
  to be resolvable against labels too, not just other constants — solved
  by deferring constant resolution to the existing Pass1→Pass2 seam
  (where every label's address is already final) rather than resolving
  inline during Pass 1, avoiding a name-storage/re-scan problem via a
  compact VMM source-position bookmark instead of copying referenced
  names.
- 2026-08-13: **User approved this plan as drafted, no changes.**
  Taskwarrior task 45 (`e32c08c8-1435-43b2-a075-a2bb2f6e0c8f`) created,
  depends on WP64 (task 44), started. Implementation of Increment 1
  begins next.
