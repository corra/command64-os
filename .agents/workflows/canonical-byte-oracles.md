---
description: How expected bytes for CASM output and CASM-native applications are independently derived, peer-reviewed, and classified — so no test's "correct answer" is ever taken from CASM's own output, CASM's opcode tables, or a second assembler
---

# Canonical Byte Oracles

## Why this exists

CASM's tests prove CASM assembles source to the right bytes. That proof is
only worth something if the *expected* bytes were worked out **independently
of CASM** — from the published NMOS 6502/6510 encoding, CASM's documented
language semantics, PRG framing, and the Command 64 R6 relocation format —
and then reviewed by a second person. A `.ref.hex` transcribed from a CASM
run, or computed from `src/external/casm/opcodes.s`, proves only that CASM
agrees with itself.

Many CASM fixtures already do this well: `tests/fixtures/casm/*.ref.hex`
headers commonly document hand derivation and are compared to native CASM
output with `COMP` under Command64. `casmopall.ref.hex` +
`brain/reviews/2026-08-12-casm-phase11-wp60-increment1-opcode-oracle.md`
are the reference example of a full independent opcode ledger. This
workflow makes that practice the rule, names its evidence levels, and
gives every reference an explicit provenance state.

ca65/ld65 stays the host build toolchain for `casm` itself, `debug`, and
every non-CASM-native application — that is not changing. What this
workflow governs is which bytes are **authoritative**: independently
derived canonical bytes, never a second assembler's output.

## Authority hierarchy

When two sources disagree about what bytes are correct, the higher one wins:

1. **Normative specification** — documented NMOS 6502/6510 encoding, CASM's
   documented language semantics, PRG framing, Command 64 R6 format.
2. **Canonical oracle** — independently derived expected bytes + structural
   metadata, reviewed without consulting CASM output or CASM production
   tables as the derivation source.
3. **Native observation** — CASM running under Command64 (VICE or hardware),
   output compared byte-for-byte against the canonical oracle with `COMP`.
4. **Optional differential evidence** — ca65 or another assembler, only where
   the exact source semantics overlap. A mismatch is investigated and
   classified; it does **not** automatically make CASM wrong.
5. **Determinism evidence** — repeated native CASM runs compare identically.
   Detects instability; never a substitute for an independent oracle.

## Oracle classes and required evidence

| Class | Required evidence |
| --- | --- |
| **Static PRG** | Load address, address ledger, opcode/operand or directive-byte derivation, byte count, SHA-256, source SHA-256, reviewer sign-off, live `COMP` |
| **R6 PRG** | Static evidence **plus** relocation eligibility ledger, sorted entry offsets, count/terminator/footer derivation, relocation applied and verified at multiple load bases |
| **Repetitive / large output** | Reviewed seed bytes + count/range formula, expanded by generic assembler-independent tooling, total length/hash, boundary spot-checks, live `COMP`. Do not hand-type long repetitive streams. |
| **Diagnostic rejection** | Exact diagnostic identity + location, and proof that no committed output file exists. **No fabricated `.ref.hex`.** |
| **Listing / map** | Canonical text/record layout where the output is contractual; otherwise a focused structural harness + written rationale. Never infer listing/map correctness from PRG identity alone. |
| **Determinism-only** | Explicitly labelled non-oracle evidence, paired with an applicable canonical or structural test elsewhere. |
| **Native application manifest** | Reviewed native artifact, source + artifact hashes, independent byte/relocation derivation record, reviewer sign-off, runtime evidence. Any ca65 differential note is clearly marked non-authoritative. |

## Provenance states

Every reference in the audit register
(`brain/reviews/2026-09-01-casm-byte-oracle-audit.md`) carries **exactly
one**:

- **`CANONICAL-INDEPENDENT`** — derivation + review satisfy this workflow.
  Only this state may be packaged as an authoritative `.ref` for native
  `COMP`.
- **`DIFFERENTIAL-ONLY`** — useful ca65/other-assembler output; never the
  authoritative expected bytes.
- **`NATIVE-OBSERVATION`** — CASM-produced evidence or shipped bytes; useful
  for reproducibility, circular as a correctness oracle.
- **`UNCLEAR`** — provenance cannot be established from repository evidence.
  **Blocks completion** until re-derived or removed from authoritative use.
- **`NOT-APPLICABLE`** — failure / structural / determinism case where fixed
  bytes are not the correct assertion.

## Prohibited derivation sources (circular)

An expected-byte derivation must **never** take its answer from:

- CASM output (any run, any version);
- `src/external/casm/opcodes.s` or any other CASM production table;
- a previous `.ref.hex` that was itself CASM-derived;
- a shipping manifest whose bytes came from a CASM run;
- a ca65/ld65 binary used *as the answer* rather than as post-derivation
  comparison evidence.

Reading any of these **after** an independent derivation, to compare, is
expected and encouraged — that is native observation / differential
evidence. Reading them *to obtain* the expected bytes is the circularity
this workflow exists to stop. See
`project-casm-trusted-reference-rule` in memory.

## Acceptable independent sources

- Documented NMOS 6502/6510 opcode + addressing-mode encoding.
- CASM's documented language semantics (operator set, width rules,
  relocation classification, directive behavior) from
  `wiki/casm-programmers-reference.md`.
- PRG framing (2-byte little-endian load address header) and the
  Command 64 R6 relocation format.
- Hand arithmetic for addresses, offsets, branch displacements, lengths.
- Generic deterministic expansion tooling for repetitive output (a Python
  loop that emits the seed pattern N times is fine; it must not consult a
  6502 opcode table it shares with CASM).

## Mandatory metadata + peer review

Each `CANONICAL-INDEPENDENT` reference (or its linked derivation record —
see "Native-app manifest model" below) records:

1. **Annotated byte derivation** — every byte or byte range traced to a
   spec rule or an arithmetic step a reviewer can redo.
2. **Source identity + SHA-256** — the exact fixture source bytes CASM
   consumes (for generated fixtures, the generator identity *and* a
   deterministic hash of the generated `.seq` bytes — a hash of
   `GenerateCasmTestFixtures.cmake` alone is insufficient).
3. **Independent reviewer sign-off** — a second person reconciles
   addresses, encodings, lengths, hashes, and R6 entries against the
   derivation, and records reviewer + date.
4. **Observed native comparison** — a live `COMP` (or structural harness)
   result against native CASM under Command64, per
   `.agents/workflows/vice-mcp-testing.md`.

### Evidence to capture from the live run

- The exact `COMP` invocation and the disk/device it ran against.
- `FILES COMPARE OK`, or the first differing offset + surrounding bytes.
- CASM version + build number.
- For R6: the relocation entry count, footer bytes, and a second run at a
  different load base showing the applied relocations.
- Overlay `test` events fired (per `feedback-fire-overlay-events-for-tests`).

## Generated repetition without writing an assembler

For a large/repetitive fixture: review the **seed bytes** and the
**count/range formula** by hand, expand them with generic tooling, then
spot-check the boundaries (first pattern, last pattern, any wrap/rollover
point) and hash the whole. The reviewer checks the seed + formula + spot
checks, not every expanded byte.

## Mismatch classification and stop conditions

- **Native CASM ≠ a newly approved canonical oracle.** Stop. Report the
  first differing offset and structural context. Classify *before* editing
  either side: oracle arithmetic error / oracle spec-reading error / CASM
  defect / source-semantic ambiguity. Do not "fix" CASM or the oracle to
  make them agree until the cause is known.
- **ca65 ≠ CASM on shared syntax.** Determine which of: CASM defect, ca65
  behavior, source-semantic divergence, oracle defect. **Never** auto-rewrite
  CASM to match ca65.
- **A manifest source hash changed** without an intentional, reviewed native
  regeneration. Stop — the artifact and its recorded provenance have
  drifted apart.
- **A reviewer cannot reproduce** an address, byte count, hash, or
  relocation ledger from the recorded derivation. The reference is not
  `CANONICAL-INDEPENDENT` yet.
- **A derivation consults a prohibited source** for its answer. Discard and
  redo from an acceptable source.

## Native-application manifest model

The checked-in shipping manifest (`src/external/<app>/<app>.ref.hex`) stays
a **machine-integrity record**: byte count, artifact SHA-256, source
SHA-256(s), R6 ledger. It links *by path* to a separate peer-reviewed
**derivation record** under `src/external/<app>/` that carries the
annotated byte/relocation derivation and reviewer sign-off. Review
metadata is not embedded in the manifest, and the manifest build scripts
(`scripts/build_dash_manifest.py`, `scripts/build_banner_manifest.py`,
`scripts/hex_manifest_to_bin.py`) are not changed to enforce it.

- The manifest is the **shipped artifact and stale-artifact guard**, not
  proof of its own correctness.
- A ca65 comparison is recorded as optional `DIFFERENTIAL-ONLY` evidence.
- Any source change requires regenerated native bytes, refreshed source
  hashes, derivation reconciliation, peer review, live comparison, and
  runtime/relocation verification.

## Worked example rows (one per class)

These show the audit-register row shape. WP2 copies this format for every
reference.

**Static PRG —**
`tests/fixtures/casm/casmhello.ref.hex`; source `casmhello.seq` (generated,
generator `GenerateCasmTestFixtures.cmake` + `.seq` hash `<h>`); class
Static PRG; provenance `CANONICAL-INDEPENDENT`; producer
`CMakeLists.txt` `CASM_REF_NAMES` loop → `casmhello.ref`; packaged on
`test.d64`; live cmd `COMP CASMHELLO.PRG,CASMHELLO.REF`; derivation:
header `01 08`, then per-line opcode from the 6502 table + operand; byte
count `<n>`, SHA-256 `<h>`; reviewer `<name/date>`.

**R6 PRG —**
`tests/fixtures/casm/casmpgr6.ref.hex`; class R6 PRG; provenance
`CANONICAL-INDEPENDENT`; extra evidence: relocation-eligible operand
offsets `[...]`, entry count `<n>`, footer `<bytes>`, verified applied at
base `$3800` and `$9000`.

**Repetitive/large —**
`tests/fixtures/casm/casmbig1.ref.hex`; class Repetitive; provenance
`CANONICAL-INDEPENDENT`; seed pattern `<bytes>`, repeat formula `<expr>`,
expanded by `<script>`, boundary checks at offsets `0`, `<mid>`, `<end>`,
whole-file SHA-256 `<h>`.

**Diagnostic rejection —**
`tests/fixtures/casm/<casmnumerr*>`; class Diagnostic rejection;
provenance `NOT-APPLICABLE`; asserts diagnostic id `<code>` at
line/col `<pos>`; no `.ref.hex` exists and none should.

**Native application manifest —**
`src/external/dash/dash.ref.hex`; class Native application manifest;
provenance today `NATIVE-OBSERVATION` (shipped native bytes) — becomes
`CANONICAL-INDEPENDENT` when the WP4 derivation record under
`src/external/dash/` is linked and signed off; artifact SHA-256
`3b4d0693...`, 451 relocation entries, runtime verified `$3800`/`$5000`/`$9000`.

## Inventory reconciliation

`scripts/casm_oracle_inventory.py` (CMake target `casm_oracle_inventory`,
non-gating) enumerates every `*.ref.hex`, cross-checks each manifest's
declared byte count / SHA-256 against its own hex body, hashes the exact
generated `.seq` source bytes, traces packaging, and asserts
`CASM_REF_NAMES` == on-disk == git-tracked with a packaging step for every
reference. It inspects metadata, hashes, and relationships **only** — it
never reads `opcodes.s`, disassembles a `.ref`, or decides a byte is
correct. Run it (or wire it into CI) as a drift check whenever fixtures or
packaging change; it assigns no provenance state.

## Lifecycle

- A WP that adds or changes expected bytes scopes its oracle impact in its
  `brain/plans/` sub-plan and names the resulting provenance state (per
  `.agents/workflows/phased-implementation-planning.md`).
- Derivation records and the audit register are tracked artifacts (per
  `.agents/workflows/artifact-tracking.md`).
- User-facing provenance documentation is mirrored byte-identically across
  `wiki/`, `docs/`, and `release/docs/` in the same WP that changes the
  behavior (per `.agents/workflows/documentation-maintenance.md`).
- A Phase/WP that touches oracles is not complete without a
  `brain/walkthroughs/` doc holding the live `COMP`/structural evidence and
  explicit user sign-off.

## The Claude skill

`.claude/skills/canonical-byte-oracles/SKILL.md` is a thin trigger +
checklist adapter for this workflow — it contains no unique policy. Agents
without skill support follow this document directly; the behavior is
mandatory either way. The trigger fires when adding or changing:
`*.ref.hex`, a native-CASM manifest, expected PRG bytes, an R6 relocation
oracle, or a ca65 differential comparison.
