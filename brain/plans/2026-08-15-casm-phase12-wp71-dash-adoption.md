---
feature: casm-phase12-wp71-dash-adoption
created: 2026-08-15
status: approved
taskwarrior: e126dbb8-fc8e-4b94-a93a-ec6121a19fb8
depends-on: WP65-70, all complete
---

# Plan: CASM Phase 12 WP71 — DASH Adoption of Phase 12 Syntax

## Status

**Approved 2026-08-15.** The user approved this plan, directing that
`tools/vice_mcp_start.sh` be updated to attach a 16MB REU by default
first (done — see that script's own commit) rather than requiring manual
REU attachment as Scoping Decision 1 originally proposed. Implementation
of the Atomic Steps below is authorized. Taskwarrior task 46
(`e126dbb8-fc8e-4b94-a93a-ec6121a19fb8`) created, depends on WP70.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`
(WP71 inserted 2026-08-14, user-directed). Prerequisite: WP65-70, all
complete and user-approved.

## Objective

The parent plan describes WP71 as: "Update `src/external/dash/`'s real
CASM source to use named constants, the current-address symbol, and
whichever parenthesized/operator/character-literal forms WP67-69 shipped,
where they genuinely improve on what's there today (magic numbers,
hand-computed offsets)... Uses this as the trigger to close DASH's own
interim-provenance gap: a real native-CASM regen of `dash.ref.hex`
replacing the `dash_ref` ca65 cross-check's `--allow-host-bytes`
placeholder."

Two genuinely separate pieces of work, bundled because the second needs
the first to have already landed and passed the ca65 cross-check before
committing hardware time to it:

1. Adopt Phase 12 syntax into DASH's real source, narrowly, where it
   removes a real magic number or clarifies a real intent — not a
   sweeping rewrite.
2. Regenerate `dash.ref.hex` from a genuine native-CASM-on-hardware run
   (VICE with a real REU attached), closing the interim provenance gap
   WP9 explicitly deferred, not resolved.

## Research Findings (before drafting scope below)

1. **`AGENTS.md`'s "Dual-Assembler Subset" contract restricted CASM's
   *own* pre-Phase-12 limits, not ca65's.** ca65 already supports
   equates, `*`, parentheses, multiplicative arithmetic, and character
   literals — the contract's "No equates... No parenthesised or
   multiplicative arithmetic" existed only because native CASM couldn't
   do any of it yet. Now that WP65-69 add exactly those features, the
   dual-assembler intersection widens to match — this is not a decision
   to abandon the cross-check, just to update `AGENTS.md`'s own
   documented boundary of what the shared subset now includes.
2. **The "UPPERCASE ONLY (load-bearing)" rule is a hard constraint on
   character-literal adoption, confirmed by reading, not assumed.**
   `AGENTS.md`: "Every byte of these files — mnemonics, labels, hex
   digits, and comment text — must be uppercase ASCII... ASCII lowercase
   `a`-`z` are not letters in PETSCII; CASM rejects them." A WP69
   character literal's content byte is taken **verbatim, no case
   folding** (WP69's own design) — a lowercase-source character literal
   would need a lowercase ASCII byte in the file, which the existing rule
   forbids outright (and which would risk diverging from ca65's own
   charmap treatment of lowercase source, the exact hazard the blanket
   uppercase rule exists to avoid entirely rather than verify case-by-
   case). **Consequence**: only uppercase-letter keypress comparisons
   (`'T'`, `'R'`, `'Q'`) are safe character-literal candidates; DASH's
   existing *lowercase-key-variant* comparisons (`CPX #$74` / `#$72` /
   `#$71`, handling the C64's dual-charset keyboard ambiguity) must stay
   raw hex literals — converting them would require a lowercase source
   byte the file's own contract forbids.
3. **`dscr.s`'s `ROW*40` computation (comment: "ROW*40 IS BUILT AS
   ROW*8 + ROW*32") is runtime arithmetic on a variable, not a compile-
   time constant expression** — confirmed by reading: `ROW` is a runtime
   register value, and WP68's `*` operator only folds compile-time
   literal/label expressions; CASM has no code-generation path for a
   runtime multiply. **Not a WP71 candidate** — flagged here so it isn't
   mistakenly "improved" into something that changes behavior.
4. **A concrete, safe, mechanical candidate found by reading**: DASH's
   own `AGENTS.md` already documents seven private zero-page registers
   (`$70`-`$7F`) by name, but the source uses raw hex (`$70`, `$72`,
   etc.) at every call site — confirmed present at every use via direct
   grep, not sampled. Named constants (WP65) replacing each raw ZP
   address with its already-documented name is a direct, unambiguous
   magic-number removal with zero behavior risk (same value, same byte
   width, same addressing mode).
5. **DASH's own hand-bumped `DASHVERSTR` mechanism is unaffected.** Its
   own comment explains it can't use CASM's `.define`-based
   `VERSION_MAJOR`/`MINOR`/`STAGE` interpolation (a ca65 *preprocessor*
   feature CASM has never had and WP65's named constants don't add —
   constants are static values, not text macros). No change here.

## Scoping Decisions (user-confirmed 2026-08-15)

1. **Native provenance regen is in scope for this WP**, not deferred.
   The current VICE instance had no REU attached and the `vice_machine_
   config_set` MCP tool malfunctioned when an attempt was made to attach
   one live (rejected its own documented example payload with a generic
   format error). Resolved permanently rather than worked around once:
   `tools/vice_mcp_start.sh` now attaches a 16MB REU by default
   (`-reu -reusize 16384`), committed separately
   (`a0037d0`), and the running instance was restarted through the
   updated script. Smoke-tested (a narrow `casm` invocation completed
   normally post-restart) before proceeding.

## Scope

**Included:**

- Named constants for DASH's seven documented ZP registers
  (`$70`-`$7F`), replacing raw hex at every call site across all seven
  source files.
- Character literals for the three **uppercase** keypress comparisons in
  `dmain.s` (`'T'`, `'R'`, `'Q'`) replacing `$54`/`$52`/`$51`. The
  lowercase-variant comparisons stay raw hex (Research Finding 2).
- An audit (Atomic Step 1) for any further genuine, low-risk candidate
  the preliminary research above didn't surface — current-address-symbol
  or parenthesized-expression opportunities specifically, since neither
  was found in the research above but a full pass hasn't been done file-
  by-file yet.
- `AGENTS.md` updated: the "Dual-Assembler Subset" section revised to
  reflect the widened shared syntax (equates, character literals now
  permitted, still uppercase-only); the "Artifact Provenance" section's
  provenance line updated once the native regen lands.
- A ca65 cross-check rebuild proving the updated source still assembles
  correctly and produces the same runtime behavior, **before** any
  hardware time is spent on the native run.
- The native CASM regen itself: boot Command64 under VICE with a real
  REU attached, assemble `DMAIN.S` with native `casm.prg`, `COMP` against
  the ca65 cross-check reference, extract the reviewed PRG, and run
  `build_dash_manifest.py` with true native provenance (no
  `--allow-host-bytes`).
- Full regression: DASH still runs correctly at multiple load addresses
  (matching `AGENTS.md`'s own existing verification bar), `image_d64`
  builds clean, no-change rebuild proof.

**Excluded:**

- Any change to DASH's runtime logic, screen layout, or behavior — this
  WP is syntax substitution plus a provenance regen, not a feature or
  refactor pass.
- The `ROW*40` runtime computation (Research Finding 3) — not a valid
  target for any Phase 12 compile-time feature.
- The lowercase-key-variant keypress checks (Research Finding 2) —
  staying raw hex, not converted.
- `DASHVERSTR`'s hand-bumped version string mechanism (Research
  Finding 5) — unaffected by anything WP65-69 added.
- Any change to `dash_wrapper.s` (the ca65-only segment wrapper) beyond
  what's needed to keep it assembling the updated sources.

## Atomic Steps

1. **Full-file audit.** Read all seven DASH source files end-to-end
   (not sampled) for any further named-constant/current-address/
   parenthesized-expression/character-literal opportunity the
   preliminary research above didn't surface. Confirm the ZP-register
   and keypress-literal candidates' exact byte-for-byte equivalence
   (same value, same addressing mode, same width) before writing any
   substitution. Stop and report if the audit finds a candidate outside
   this plan's Scope, or finds any of the Research Findings above wrong.
2. **ZP register named constants.** Add `DISPATCHVECTOR = $70`, etc. (one
   per `AGENTS.md`'s own documented register) to `ddata.s`; replace every
   raw-hex call site across all seven files. Narrow ca65 build (`dash_ref`
   target) to confirm no regression before touching anything else.
3. **Keypress character literals.** Replace `CPX #$54`/`#$52`/`#$51` with
   `CPX #'T'`/`#'R'`/`#'Q'` in `dmain.s`; leave the lowercase-variant
   checks untouched. Narrow ca65 build to confirm.
4. **`AGENTS.md` update.** Revise "Dual-Assembler Subset" to document the
   widened shared syntax; note the still-load-bearing uppercase-only
   rule now also governs character-literal content, not just identifiers.
5. **Native CASM regen** (stops and waits for the user's confirmation
   that a real REU is attached before proceeding): boot Command64 under
   VICE, `CASM DMAIN.S /O:DASH.PRG`, `COMP DASH.PRG` against the
   already-passing ca65 cross-check reference, confirm byte-exact.
   Extract the reviewed PRG; run `build_dash_manifest.py` with
   `--provenance` describing the real native run (no
   `--allow-host-bytes`); update `dash.ref.hex`.
6. **Full regression and close-out.** `image_d64` build, no-change
   rebuild proof, live verification that DASH still runs correctly at
   its documented multiple load addresses. Documentation (`brain/
   KNOWLEDGE.md`, `CHANGELOG.md`, `AGENTS.md`'s provenance line), CASM/
   DASH version notes, walkthrough, tracker sync.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/dash/ddata.s` | Add ZP register named constants |
| `src/external/dash/dmain.s`, `dscr.s`, `dfmt.s`, `dsys.s`, `dapp.s`, `dvmm.s` | Replace raw ZP hex with named constants; `dmain.s` also gets the three keypress character literals |
| `src/external/dash/AGENTS.md` | Update Dual-Assembler Subset and Artifact Provenance sections |
| `src/external/dash/dash.ref.hex` | Replace with genuine native-CASM-on-hardware bytes, true provenance recorded |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md`, `brain/task.md`, `wiki/tasks/casm.md` | As-built/completion entries |

No `src/external/casm/*.s` change is anticipated — this WP consumes
Phase 12 syntax, it doesn't add to it.

## Stop Conditions

- Atomic Step 1's audit finds a candidate outside this plan's Scope, or
  finds any Research Finding above wrong — stop and report before
  implementing against a false premise.
- Any ca65 cross-check build after a substitution produces different
  bytes than before that substitution (a real behavior change, not
  expected from a pure magic-number rename).
- The native CASM run's `COMP` against the ca65 reference fails —
  disclose and root-cause before any workaround; this would be a
  genuinely new, in-scope defect (either in the updated DASH source or,
  more seriously, in CASM's own native/ca65 cross-check equivalence).
- DASH fails to run correctly at any of its documented load addresses
  after the native regen.
- A no-change rebuild changes any artifact or build counter.
- The user is not able to attach a real REU to the VICE instance —
  report back and ask whether to proceed with source adoption only,
  deferring the native regen (the plan's Scoping Decision 1 alternative).

## Documentation, Task, and DOX Updates

- Create/activate a Taskwarrior task for WP71 under Phase 12, depending
  on WP65-70, once this plan is approved.
- At completion: `brain/KNOWLEDGE.md` as-built section, `CHANGELOG.md`
  entry, `AGENTS.md` provenance/subset updates, `brain/walkthroughs/`
  completion-gate doc, `brain/task.md`/`wiki/tasks/casm.md` sync. No
  `docs`/`wiki` `casm-utility.md` change (no new CASM syntax or
  semantics — DASH is a consumer, not a source, of this phase's
  features).

## Completion Gate

WP71 completes only when: every planned substitution is confirmed
byte-for-byte equivalent to what it replaced (via the ca65 cross-check,
before any hardware time is spent); the native CASM regen produces a PRG
byte-identical to the ca65 cross-check reference; `dash.ref.hex` records
true native provenance, not `--allow-host-bytes`; DASH runs correctly at
every documented load address; full affected-target build and no-change
rebuild proof pass; documentation is updated; and the user explicitly
approves closing WP71.

## Progress

- 2026-08-17: **WP72 (named-constant zero-page width selection fix)
  complete and user-approved.** See `brain/plans/2026-08-17-casm-
  phase12-wp72-constant-zeropage-width.md` and its walkthrough for full
  detail. `src/external/casm/expr.s` fixed; full regression clean;
  `dash_ref` confirmed byte-identical (unaffected); a new end-to-end
  fixture mirroring this WP's own real DASH source (`STA
  DISPATCHVECTOR` / `STA DISPATCHVECTOR+1`) proved byte-exact against a
  hand-derived reference under native CASM. Resuming this WP's own
  blocked Atomic Step 5 (native `dash.prg` regen) now that the fix is
  in place — expect `COMP DASH.PRG DASH.REF` to now pass byte-for-byte.
- 2026-08-17: **Root cause of Atomic Step 5's COMP mismatch found — a real
  CASM defect, not a DASH-source or ca65-cross-check problem.** Extracted
  the leftover native `dash.prg` (4835 bytes, 20 blocks) and the ca65
  `dash.ref` (4766 bytes, 19 blocks) directly from the still-attached
  `command64_casm_utils.d64` build artifact (the prior session's live VICE
  write survived on disk; no new hardware run was needed to reproduce
  this). A raw byte diff (`cmp -l`, confirmed with `xxd`) shows native
  CASM encodes `STA DISPATCHVECTOR` in `dmain.s`'s `DISPATCHPAGE` routine
  as `8D 70 00` (absolute, 3 bytes) where ca65 correctly encodes it as
  `85 70` (zero-page, 2 bytes) — and the same for the very next
  instruction, `STA DISPATCHVECTOR+1` (`8D 71 00` vs `85 71`).
  `DISPATCHVECTOR` is declared `= $70` at the top of `dmain.s`, before
  first use, exactly as WP65/the earlier Atomic-Step-2 correction
  requires — so this is not a forward-reference problem (that class of
  bug was already fixed once, on the ca65 side, during Atomic Step 2).

  **Root cause**: native CASM's operand-width selector appears to only
  auto-select zero-page addressing when an operand is a literal numeric
  token (e.g. `STA $70`); when the operand is a named-constant (equate)
  symbol whose resolved value is `$00`-`$FF`, it falls back to absolute
  (16-bit) addressing regardless. This is a defect in Phase 12's own
  named-constants feature (WP65), surfaced for the first time by WP71
  because this is the first real multi-file application to reference
  equates from executable instruction operands at scale. A full-file
  symbol grep across the seven DASH sources finds ~139 raw occurrences of
  the eleven ZP-equate names; accounting for the ones in `(PTR),Y`
  indirect-indexed form (whose encoding has no absolute variant to
  mistakenly choose, so they're unaffected) leaves a count consistent
  with the ~50 single-byte insertions a full hex diff finds scattered
  through the file, each adding exactly one extra address byte and
  cascading — via ordinary two-pass forward-reference resolution — into
  the 69-byte total size difference and the wrong addresses `COMP`
  reported starting at file offset `$000006` (the very first
  forward-referenced `DDATA.S` label, `CURRPAGE`, whose final position
  depends on all the extra bytes emitted before it).

  This is squarely a CASM defect, not a DASH-source or cross-check-
  equivalence problem, and per this plan's own Scope ("No
  `src/external/casm/*.s` change is anticipated — this WP consumes Phase
  12 syntax, it doesn't add to it") is out of WP71's authorized scope to
  fix. Per the Stop Conditions, halting Atomic Step 5 here and reporting
  to the user rather than working around it. WP71 cannot complete its
  native-provenance regen until this is fixed in CASM itself (a new,
  separate defect task/WP under Phase 12) — Atomic Steps 1-4 (source
  adoption) remain complete and unaffected; only Step 5 (native regen)
  and Step 6 (close-out) are blocked.
- 2026-08-15: **Atomic Step 4 complete; Atomic Step 5 in progress.** Updated
  DASH's local dual-assembler contract to permit equates only before first
  use, prohibit character literals because ca65 remaps them, and permit
  Phase 12 expressions only where both assemblers produce identical values.
  Rebuilt `command64_casm_utils_d64`; its uppercase-source check passed and
  the disk contains the seven current DASH sources plus the byte-matching
  ca65 `dash.ref` reference.

  The initially running VICE instance had no REU despite predating the
  updated launcher. With user approval it was restarted through
  `tools/vice_mcp_start.sh`; launcher output and the VICE log both prove a
  16,384 KiB REU (`-reu -reusize 16384`). Attached `image.d64` on unit 8
  and the rebuilt utility disk on unit 9, then proved Command64 boot from
  screen RAM (`Command 64-DOS Version 0.4.1.2663`). Native
  `CASM DMAIN.S /O:DASH.PRG` loaded CASM V0.2.5.1312 but did not produce a
  completion message or diagnostic within the declared 120-second active
  window. Two bounded observations were identical, so the result is
  recorded as inconclusive rather than a product failure; VICE was resumed
  and left healthy rather than polled repeatedly.

  The user later confirmed CASM had completed. Screen RAM then proved
  `CASM: INPUT VALIDATED` and normal return to `c64[9]:>`; unit 9 contained
  the new `dash.prg` (20 blocks). `COMP DASH.PRG DASH.REF` produced ten
  immediate mismatches, beginning at file offset `$000006`, then stopped
  and returned to the shell; the ca65 reference remains 19 blocks. This is
  the plan's explicit native-equivalence stop condition: preserved as a
  product failure with no workaround or manifest regeneration attempted.
- 2026-08-15: **Atomic Step 2 complete; Atomic Step 3 removed by two
  user-approved corrections.** The first narrow `dash_ref` build exposed
  that equates declared in last-included `ddata.s` are forward references
  at every use. ca65 consequently selected absolute rather than zero-page
  addressing and emitted 11 warnings. The user approved moving the
  declarations to the top of `dmain.s`, before their first use; the next
  build restored zero-page instruction widths with zero warnings.

  Exact comparison against the existing reviewed manifest then exposed a
  second false premise: ca65's character mapping encodes source literals
  `'T'`/`'R'`/`'Q'` as `$D4`/`$D2`/`$D1`, not the keyboard values
  `$54`/`$52`/`$51`. The PRGs had equal length but differed at exactly
  those three operands. The user approved retaining all six keyboard
  comparisons as raw hex and excluding character literals from DASH's
  dual-assembler subset. After that correction, `dash_ref` built with zero
  warnings at 3,828 code bytes and 465 relocation points, and `cmp` against
  the existing 4,766-byte reviewed manifest PRG passed byte-for-byte
  (`sha256 3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`).
- 2026-08-15: **Atomic Step 1 (full-file audit) complete.** Read all
  seven source files end-to-end. Confirmed the ZP-register and
  uppercase-keypress-literal candidates hold exactly as researched, and
  found no current-address-symbol or parenthesized-expression
  opportunity anywhere (every arithmetic pattern in the source is either
  a plain label reference or genuine runtime computation, never a
  compile-time address-relative offset).

  One real hazard found that the plan's own research didn't specifically
  call out: `dapp.s`'s `DAPPPRINTFLAGS` pokes raw **screen codes**
  directly to screen RAM for the U/R/V/S flag letters (`$15`/`$12`/
  `$16`/`$13`) — screen code, not PETSCII (screen code 'U' = `$15`;
  PETSCII/ASCII 'U' = `$55`). A character literal there would silently
  poke the wrong byte. **Not converted** — stays raw hex, exactly like
  the already-excluded lowercase keypress variants.

  Also found, beyond this plan's approved Scope, several DOS API
  function-code/fixed-address candidates already well-commented at every
  site (`$1000` `OS_API`, `$FFE4` `KERNALGETIN`, and `$48`/`$49`/`$4C`/
  `$59`/`$5A`/`$5C`/`$5D` `DOS_*` function codes across `dsys.s`/
  `dapp.s`/`dvmm.s`). **Not included** — outside this plan's approved
  Scope; disclosed here rather than silently expanding it. `dvmm.s`'s
  `$66`-`$6C` VMM API parameter-block ZP registers are a similarly
  real but out-of-scope candidate: not part of `AGENTS.md`'s documented
  `$70`-`$8F` DASH-private range this plan's Scope covers, and inventing
  names for a public OS ABI this plan doesn't own is a separate
  decision.

  Proceeding to Atomic Step 2 with the approved scope unchanged: ZP
  registers `$70`-`$7F` and the three uppercase keypress literals only.
- 2026-08-15: Drafted this plan after WP70's closure and commit
  (`7e9bd29`). Confirmed via `vice_machine_config_get` that the running
  VICE instance has standard (no REU) expansion, and that `AGENTS.md`
  requires an REU for native CASM assembly. Attempted to attach one via
  `vice_machine_config_set`; the tool rejected its own documented
  example payload with a generic format error — a genuine tool
  malfunction in this session, not a parameter mistake. User confirmed:
  include the native regen in this WP's scope, with the user attaching
  a real REU directly before Atomic Step 5 begins. Traced DASH's own
  source for genuine substitution candidates before drafting scope,
  finding a real hazard (lowercase character literals would violate the
  file's own load-bearing uppercase-only rule) that narrows the
  keypress-literal candidate to the three uppercase checks only, and
  confirming the `ROW*40` runtime computation is not a valid target for
  any Phase 12 compile-time feature. Awaiting user approval before
  implementation begins.
