# CASM Byte-Oracle Audit Register

> [!NOTE]
> **WP3 complete (user-approved 2026-09-02).** All **67 / 67**
> `tests/fixtures/casm/*.ref.hex` are now `CANONICAL-INDEPENDENT`: each
> carries `# sha256:`, `# source_sha256:` for every source `.seq`/`.dat`,
> an annotated byte derivation, and a user reviewer sign-off line. **Zero
> `UNCLEAR`** — `casmexprn` re-derived (Batch 2). Every `.ref` binary is
> byte-identical to its pre-WP3 form (only `#` header lines were added /
> rewritten). Sections below retain the WP2 classification text where it is
> still the record of how a state was reached; the WP3 batch records are:
> `brain/reviews/2026-09-02-casm-byte-oracle-wp3-batch{1a,1bcde,2,3,4,5}-*.md`.
>
> **WP6 (consolidated verification) COMPLETE 2026-09-02.** All oracle
> classes + both native apps live-`COMP`-verified under CASM 0.6.2.1419
> (`FILES COMPARE OK`), incl. a fresh native DASH (4579 B) and BANNER
> (1011 B) assembly. `casm_r6_verify.py` PASS on all 7 R6 fixtures + both
> manifests. Determinism: every build artifact byte-identical across two
> builds. `casm_oracle_inventory --check` green (69/69). New
> `casm_oracle_test.d64` (test.d64 was directory-full). The transition is
> closed pending user sign-off. Walkthrough:
> `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp6-consolidated-verification-completion-gate.md`.
>
> **WP4 (native-app records) — completed then audit-corrected 2026-09-02.**
> `banner.ref.hex` → `CANONICAL-INDEPENDENT` (full address ledger + 20-entry
> relocation table verified against the body). `dash.ref.hex` → bytes
> **`NATIVE-OBSERVATION`** (reviewed native run + ca65 `DIFFERENTIAL-ONLY`;
> a full byte derivation of 3,669 bytes across 7 files is not practical and
> the original WP4 claim was withdrawn) with a `CANONICAL-INDEPENDENT`
> 451-entry R6 relocation ledger. New tool: `scripts/casm_r6_verify.py`.
> The ca65 `dash_ref` differential is kept as a standing release check
> (WP5). Records:
> `brain/reviews/2026-09-02-casm-byte-oracle-wp4-{dash,banner}-derivation.md`.

Governing plan: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`
Workflow: `.agents/workflows/canonical-byte-oracles.md`
WP1 sub-plan: `brain/plans/2026-09-02-casm-byte-oracle-wp1-contract-workflow-schema.md`
WP2 sub-plan: `brain/plans/2026-09-02-casm-byte-oracle-wp2-fixture-inventory-provenance-audit.md`

Baseline commit for the WP2 inventory: `b3193853` on branch
`feature/casm-byte-oracle-wp2` (worktree clean in every oracle-relevant
path; includes Phase 15 closure, CASM 0.6.2, and Byte-Oracle WP1).

## Reconciliation (`scripts/casm_oracle_inventory.py --check`)

- `CASM_REF_NAMES` = **67** = on-disk `*.ref.hex` = **67** = git-tracked =
  **67**. Zero orphans in either direction.
- Every `.ref.hex`'s declared `bytes:` and `sha256:` **match its own hex
  body** — 0 mismatches across all 67 + 2 manifests.
- Every reference has at least one packaging step (the generic
  `CASM_REF_NAMES` loop and/or a per-phase `POST_BUILD` append).
- 37/67 declare a `sha256:`; 30 declare only `bytes:`.
- 66/67 headers explicitly claim independent derivation
  ("hand-derived" / "NOT produced by CASM" / "independently ..."). The one
  exception is `casmexprn` (see Ledger A).
- 244 generated `.seq` fixture sources exist (build-time only, none
  checked in); 61 pair 1:1 with a ref by name, 6 refs are multi-root /
  multi-file (`casmmf1/2/3`, `casmpgrt`→`casmpgrta/b`, `casmpginc`→chain,
  `casmbig1`→`casmbiga/casmbigb`).

The `casm_oracle_inventory` CMake target (non-gating) re-runs this check;
`--markdown` emits the mechanical field data (declared vs actual bytes/hash,
generated-`.seq` hash, packaging trace) that backs Ledger A row-by-row.

## Provenance states

| State | Meaning | Authoritative? |
| --- | --- | --- |
| `CANONICAL-INDEPENDENT` | Independent derivation + peer review per the workflow | **Yes** — only this |
| `DIFFERENTIAL-ONLY` | ca65 / other-assembler output | No |
| `NATIVE-OBSERVATION` | CASM-produced evidence or shipped bytes | No (reproducibility only) |
| `UNCLEAR` | Provenance not establishable from repo evidence | No — **blocks completion** |
| `NOT-APPLICABLE` | Failure / structural / determinism case; fixed bytes not the assertion | n/a |

## Register schema

Each row records:

| # | Field | Notes |
| --- | --- | --- |
| 1 | Reference path | `tests/fixtures/casm/<name>.ref.hex` or `src/external/<app>/<app>.ref.hex` |
| 2 | Source fixture(s) | complete set incl. multi-root, `.INCLUDE`, `.INCBIN` payload deps |
| 3 | Feature / output class | Static PRG / R6 PRG / Repetitive / Diagnostic rejection / Listing-map / Determinism-only / Native-app manifest |
| 4 | Byte count + artifact SHA-256 | as of the baseline commit |
| 5 | Source SHA-256 | per source file; "absent" if the reference declares none |
| 6 | Git state | tracked / untracked / modified |
| 7 | Active-WP owner | which WP (if any) currently mutates it |
| 8 | `CASM_REF_NAMES` membership + build output path | yes/no; `${CASM_REF_DIR}/<name>.ref` |
| 9 | Packaging image(s) | every `.d64` it is written to |
| 10 | Generic packaging-loop exclusion reason | if not in the `CASM_REF_NAMES` foreach |
| 11 | Claimed provenance + citation | from the `.ref.hex` header text |
| 12 | Actual producer path | CMake target / script that emits it |
| 13 | Generator identity + generated-`.seq` byte hash | for generated fixtures |
| 14 | D64 target + native invocation / `COMP` command | |
| 15 | Provenance state | one of the five |
| 16 | Missing derivation / review evidence | gap list |
| 17 | Remediation disposition | re-derive / quarantine / keep / N-A |
| 18 | Reviewer record | reviewer + date (filled in WP3/WP4) |
| 19 | Historical evidence paths | prior review docs |
| 20 | Re-audit trigger | what change forces re-classification |

## Ledger A — fixed-byte artifacts (67 refs + 2 manifests)

Every row: full mechanical field data (declared vs actual bytes/SHA-256,
generated-`.seq` hash, `CASM_REF_NAMES` membership, packaging trace) is
produced live by `python3 scripts/casm_oracle_inventory.py --markdown` and
is not duplicated here. This table is the classification layer: oracle
class (WP2 hint, WP3 confirms), provenance state, and the WP3 gap list.

| ref | class (hint) | provenance state | missing evidence |
| --- | --- | --- | --- |
| `brback1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `brfwd1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmalign1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmarith2` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmarith3` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmarithfwd` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmassert1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmbig1` | Repetitive/large (6002 B) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmcase1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmchain1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmchar1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmelif` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmemit1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmexprn` | Static (`<`/`>` operators) | `CANONICAL-INDEPENDENT` | WP3 batch 2 -- header re-derived, source_sha256 + reviewer added; body byte-identical |
| `casmfa2p` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmfill1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmfwdstale1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmhello` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmif0` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmif1` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifL1` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifM1` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifdef0` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifdef1` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifdeffwd` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifdefguard` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifelse` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifndef1` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifnest` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifp1p2` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmifskip` | Static (conditional) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmincbin1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmloc1` | Static (@local) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmloc2` | Static (@local) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmloc3` | Static (@local) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmloc7` | Static (@local) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmmaxid1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmmf1` | Static (multi-root) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmmf2` | Static (multi-root) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmmf3` | Static (multi-root) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmmodes` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmnoorg1` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmnum2` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmopall` | Static (151-tuple opcode ledger) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmordhaz1` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmorg1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmorgexpl1` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpg128` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpg63` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpg64` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpg65` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpgblank` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpgfill` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpginc` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpgincbin` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpgr6` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmpgrt` | Static/R6 (progress-path) | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmrelacc` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmreloc1` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmrelop1` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmrelop2` | R6 PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmres1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmstring1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `casmzpconst1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `p1back1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `p1fwd1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `p1size1` | Static PRG | `CANONICAL-INDEPENDENT` | WP3 batch 1 -- source_sha256 + sha256 + reviewer added; body byte-identical |
| `banner.ref.hex` | Native Manifest (R6 PRG) | `CANONICAL-INDEPENDENT` | WP4 -- full address ledger + 20-entry relocation table verified vs body (`casm_r6_verify.py` PASS) + multi-base + reviewer |
| `dash.ref.hex` | Native Manifest (R6 PRG) | **`NATIVE-OBSERVATION`** (bytes) + `CANONICAL-INDEPENDENT` R6 relocation ledger | WP4 audit-corrected 2026-09-02 -- 3669 code bytes are reviewed native run + ca65 `DIFFERENTIAL-ONLY`; 451-entry R6 table independently derived (`casm_r6_verify.py` PASS) |

### Ledger A notes

- **67 / 67 CASM fixtures → `CANONICAL-INDEPENDENT`.** All 67 `.ref.hex` fixture
  headers document independent hand-derivation from the 6502/6510 encoding and
  fixture source directives, carry source SHA-256 and artifact SHA-256 hashes,
  and named reviewer sign-offs. `casmexprn` promoted in WP3 (zero `UNCLEAR`).
- **BANNER manifest → `CANONICAL-INDEPENDENT`.**
  `src/external/banner/banner.ref.hex` (1011 B, 20 relocations) — a full
  independent address ledger and a 20-entry relocation table verified
  entry-for-entry against the manifest body (`scripts/casm_r6_verify.py` →
  `R6 VERIFY: PASS`); source SHA-256; reviewer sign-off.
  `brain/reviews/2026-09-02-casm-byte-oracle-wp4-banner-derivation.md`.
- **DASH manifest → `NATIVE-OBSERVATION` (bytes), `CANONICAL-INDEPENDENT`
  R6 relocation ledger.** A byte-by-byte independent derivation of DASH's
  3,669 code/data bytes (7 files, ~50 routines) is not practical and was
  not done — the original WP4 claim to the contrary was withdrawn
  2026-09-02. DASH's byte provenance is a **reviewed native CASM run**
  (`CASM 0.5.2` b1404) corroborated by the **ca65 `dash_ref` differential**
  (`DIFFERENTIAL-ONLY`, byte-identical `3b4d0693…`, re-confirmed
  2026-09-02) plus the `source_sha256` stale-artifact guard and DASH-MOD
  runtime evidence at `$3800`/`$5000`/`$9000`. The **451-entry R6
  relocation table + footer** ARE independently derived and verified
  (`scripts/casm_r6_verify.py src/external/dash/dash.ref.hex` →
  `R6 VERIFY: PASS`: every entry in-image, strictly ascending, unique;
  multi-base application consistent).
  `brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md`.
  Because `dash.ref.hex` is not fully `CANONICAL-INDEPENDENT`, the ca65
  `dash_ref` differential is retained as a **standing release-verification
  check** while DASH source stays in the shared subset (WP5).

## Ledgers B and C — generated fixtures with no `.ref.hex` (183)

All 183 generated `.seq` fixtures that are **not** in `CASM_REF_NAMES`.
Every one is `NOT-APPLICABLE` for a fixed-byte oracle. The sub-tag
(reject / structural / stream-boundary / support-file) is a WP2 hint
derived from the generator + packaging comments; WP6's coverage check
confirmed the reject cases assert an exact diagnostic identity and the
structural cases assert PC/count/determinism. **None is or claims to be
a byte oracle** (confirmed: none has a `.ref.hex`; the `comm -23` of the
244 generated names against the 67 ref names is exactly this set).

- **Ledger C — reject / diagnostic-only (~56 + name-inferred):** assert a
  diagnostic id + location, no committed output. Includes the
  `casmnumerr{d,h,b}`, `casmerr1-5`, `casmorg{2,3,4,5}`, `casmbadb`,
  `casm{div,align}zero`, `casm{end,else}no*`, `casmchar{inval,unterm,bare}`,
  `casmakwbad{,2}`, `casmassertfwd`, `casmstr{inval,unterm}`,
  `casmincbin{badname,miss}`, `casmloc{dup,undef,noscope,constl,constr}`,
  `casm{if,id,mf}` reject families, `p1{dup,undef}1`, etc.
- **Ledger B — accepted, structural assertion (~93):** a native run whose
  success is asserted by PC / symbol count / determinism / listing shape,
  with no frozen `.ref`. Includes the stream-boundary set (`casm256`,
  `casmshort`, `casmmulti`, `casmsplit`, `casmvmm65/128`, `casmln255/256`,
  `casmclip`), whitespace/comment set (`casmblank`, `casmcmnt`,
  `casmcr/crlf`, `casmctrl`), `casmconst1/3`, `casmcuraddr1/2`,
  `casmparen1`, `casmassert{fail,msg}`, `casmakw3/4`, `casmlc0*`,
  `casmmaploc`, `casmwp11`, `p1label1`, etc.
- **Support-files (~34):** child `.INCLUDE` payloads / multi-root
  companions not independently dispatched (`casmfrc1-3`, `casmfrp1-4`,
  `casmidc1/2`, `casmic1-4`, `casmip1-4`, `casmiddc1/2`, `casmiduc1/2`,
  `casmcat1-5`, `casmmfa-g`, `casmbiga/b`, `casmpgrta/b`,
  `casmpginc{b,c}`, `casmareloc*`, `casmlc7{c,g}`, `casmsrc1`). Their
  disposition follows their parent harness scenario.

> The reject/structural boundary is fuzzy for a handful of the ~93
> structural entries (some `casmakw*`, `casmconst*`, `casmlc0*` could be
> reclassified reject). This does not affect any provenance state — all
> are `NOT-APPLICABLE` — and WP6's feature-matrix pass resolves it where
> it matters for coverage. The full name list is reproducible from
> `comm -23 <(all generated .seq) <(CASM_REF_NAMES)`.

## Harness map — 32 `tests/src/casm_*` (all structural / `NOT-APPLICABLE`)

None of the 32 produces a PRG that is `COMP`'d against a `.ref`; each is
an in-memory unit / structural harness that links CASM modules and
asserts `PASS`/`FAIL` on internal behavior. No fabricated PRG oracle is
assigned to any of them.

| harness | evidence kind |
| --- | --- |
| casm_opcodes | structural — 151-tuple matcher table (pairs with `casmopall` in Ledger A) |
| casm_bounds / casm_expr / casm_directives | structural — operand range, expression eval, directive parse |
| casm_cond / casm_scope | structural — conditional nesting state machine; `@local` scope filter |
| casm_pass1 / casm_passcheck / casm_spanread / casm_spancommit | structural — Pass 1 / two-pass agreement / span read head |
| casm_reloc / casm_freloc | structural — relocation classification; reloc fault injection |
| casm_include / casm_catalog / casm_frame / casm_finc | structural — include catalog, frame stack, traceback |
| casm_listing / casm_listcap / casm_listwrite / casm_flist / casm_flmeta | structural — listing contract, capacity, write, metadata |
| casm_map | structural — symbol map record layout |
| casm_symbols / casm_faultsymbols | structural — symbol table; symbol fault injection |
| casm_vmm / casm_faultvmm | structural — VMM store; VMM fault injection |
| casm_faultinject / casm_faultsource / casm_cliderive / casm_lexer / casm_progress / casm_event | structural — OS_API fault vector, source-state faults, CLI derivation, lexer, progress line, overlay events |


## Feature-to-evidence matrix (WP2)

Every documented feature axis, its covering Ledger-A fixture(s) and/or
structural harness, and whether a `CANONICAL-INDEPENDENT` byte oracle
backs it. "pending" = the covering ref is `CANONICAL-INDEPENDENT (pending
metadata)` (i.e. the axis is covered but the ref needs WP3 metadata).

| feature axis | byte oracle (Ledger A) | structural harness | gap |
| --- | --- | --- | --- |
| 151 opcode / addressing-mode tuples | `casmopall` (pending) | `casm_opcodes` | — |
| branch displacement fwd/back/range | `brfwd1`,`brback1`; range: `casmbrn*`/`casmbrp*` (Ledger C) | `casm_bounds` | range boundary has no byte oracle (reject-only) — acceptable, no output |
| named constants + expressions (ops, parens, `*`, width) | `casmnum2`,`casmarith2/3`,`casmarithfwd`,`casmchain1`,`casmzpconst1`,`casmrelacc` (pending) | `casm_expr` | — |
| `.ORG` / explicit / absent | `casmorg1`,`casmorgexpl1`,`casmnoorg1` (pending) | `casm_directives` | — |
| `.BYTE` / `.WORD` | `casmemit1`,`casmhello`,`casmmodes` (pending) | `casm_directives` | — |
| `.RES` / `.FILL` / `.ALIGN` | `casmres1`,`casmfill1`,`casmalign1` (pending) | `casm_directives` | — |
| `.INCBIN` | `casmincbin1` (pending) | `casm_directives` | — |
| `.ASSERT` | `casmassert1` (pending) | — | assert emits no bytes; structural only — acceptable |
| character / string literals | `casmchar1`,`casmstring1` (pending) | `casm_lexer` | — |
| conditional: taken / skipped(0 bytes) / `.IFDEF` / `.IFNDEF` / nesting / P1==P2 | `casmif0/1`,`casmifelse`,`casmelif`,`casmifnest`,`casmifskip`,`casmifdef0/1`,`casmifndef1`,`casmifdeffwd`,`casmifdefguard`,`casmifp1p2` (pending) | `casm_cond` | — |
| conditional `/L` blank-address / `/M` non-leak | `casmifL1`,`casmifM1` (pending) | `casm_listing`,`casm_map` | — |
| `@name` local-label scope | `casmloc1/2/3/7` (pending) | `casm_scope` | — |
| multi-file (2/3 CLI roots) | `casmmf1/2/3` (pending) | `casm_include` | — |
| `.INCLUDE` nested / re-inclusion / traceback | `casmpginc`,`casmfwdstale1` (pending) | `casm_frame`,`casm_catalog`,`casm_finc` | traceback text: structural + the CASM 0.6.2 diag change; no byte oracle needed |
| static PRG framing | `casmhello`,`casmemit1`,`casmcase1`,`casmmaxid1`,`p1*` (pending) | `casm_passcheck` | — |
| R6 output (table, footer) | `casmreloc1`,`casmrelop1/2`,`casmordhaz1`,`casmfa2p`,`casmpgr6` (pending) | `casm_reloc` | **multi-base relocation-application evidence not linked** → WP3 |
| R6 large / repetitive | `casmbig1` (pending) | — | seed+formula not recorded as a reviewed repetition rule → WP3 |
| listing `/L` output | `casmifL1` (pending); `casmpg*` (pending) | `casm_listing`,`casm_listcap`,`casm_listwrite`,`casm_flist`,`casm_flmeta` | listing text is contractual — WP3 confirms a canonical layout row exists |
| symbol map `/M` output | `casmifM1` (pending) | `casm_map`,`casm_flmeta` | map text is contractual — WP3 confirms canonical layout |
| diagnostics — located ids | — | `casm_bounds`,`casm_directives`,`casm_expr`,`casm_frame`,`casm_finc`,`casm_faultsource` + Ledger C | `NOT-APPLICABLE` by design (no output); WP6 confirmed via the diagnostic sample + the user's harness matrix |
| diagnostics — non-located ids | — | `casm_faultinject`,`casm_faultsymbols`,`casm_faultvmm` | `NOT-APPLICABLE` |
| deterministic replay | — | `casm_reloc` determinism cases; `project-casm-phase11-wp61` | determinism-only, correctly non-oracle |
| progress indication (byte-identical output) | `casmpg63/64/65/128`,`casmpgblank`,`casmpgfill`,`casmpgincbin`,`casmpgrt`,`casmpgr6` (pending) | `casm_progress` | — |
| overlay events | — | `casm_event` | `NOT-APPLICABLE` |
| **DASH** native app | `dash.ref.hex` — bytes `NATIVE-OBSERVATION` (reviewed native run + ca65 `DIFFERENTIAL-ONLY`); R6 relocation ledger `CANONICAL-INDEPENDENT` | runtime `$3800`/`$5000`/`$9000` (DASH-MOD) | WP4 (audit-corrected 2026-09-02): full byte derivation not practical; ca65 differential retained as standing release check (WP5) |
| **BANNER** native app | `banner.ref.hex` `CANONICAL-INDEPENDENT` | multi-base `casm_r6_verify.py` PASS | WP4 — full address ledger + 20-entry table verified vs body |

**No axis is uncovered.** Every axis has at least a structural harness;
every axis that *should* have a byte oracle has one at
`CANONICAL-INDEPENDENT` or better, except the two
native-app axes (WP4) and `casmexprn`'s expression-adapter contribution
(`UNCLEAR` → WP3). The gaps column is the input to the WP3 worklist below.

## WP3 remediation worklist — **DONE (user-approved 2026-09-02)**

Outcome per batch:

1. **Metadata completion (56 refs, batches 1a–1e)** — ✅ `# sha256:` +
   `# source_sha256:` + reviewer line on all; every `.ref` byte-identical;
   `casm_oracle_inventory --check` verifies `source_sha256` against the
   live `.seq`/`.dat`.
2. **`casmexprn` (batch 2)** — ✅ re-derived (`<`/`>` operators), promoted
   `UNCLEAR` → `CANONICAL-INDEPENDENT`; body byte-identical. Coverage kept.
3. **R6 class (batch 3)** — ✅ 7 R6 refs got a re-checked eligibility
   ledger + a multi-base application check (assembler-independent
   relocator reproduces the `+1`-page bytes); `casmfa2p` / `casmorgexpl1`
   reclassified **static** (no footer).
4. **`casmbig1` (batch 4)** — ✅ repetition rule `00 C0 + EA×6000`
   (6002 B, `7288e489…`) reproduced by a 2-line independent expansion +
   boundary spot-checks.
5. **Listing / map (batch 5)** — ✅ no new reference; `/L` `/M` output is
   pinned field-by-field by `test_casm_flist` (+ WP59 contract matrix),
   `test_casm_flmeta`, `test_casm_map` + a determinism witness.
6. **Native-app records → WP4 (done, audit-corrected).** BANNER
   `CANONICAL-INDEPENDENT`; DASH bytes `NATIVE-OBSERVATION` +
   `CANONICAL-INDEPENDENT` R6 ledger; ca65 differential a standing check.

Original worklist as approved at the WP2 gate (batched by oracle class):

1. **Metadata completion — all 66 `CANONICAL-INDEPENDENT (pending
   metadata)` refs.** Add: source SHA-256(s), a deterministic hash of the
   exact generated `.seq` bytes (via `casm_oracle_inventory`), and a named
   reviewer sign-off line. Add artifact SHA-256 to the 30 that lack it.
   Mechanical + review; no byte changes. Sub-batches: static · expressions/
   directives · conditionals · `@local` · progress-path.
2. **`casmexprn` (`UNCLEAR`).** Reconstruct the byte derivation from the
   6502 encoding + the fixture source; add the full derivation statement +
   metadata; or, if it duplicates `casmnum2`/`casmarith*` coverage,
   quarantine it from authoritative packaging with a note.
3. **R6 class — multi-base relocation-application evidence.** For each R6
   ref, record a reviewed relocation-eligibility ledger and a live
   verification of the applied relocations at ≥2 load bases; link it.
4. **`casmbig1` — reviewed repetition rule.** Record the seed bytes +
   count/range formula and an assembler-independent expansion; boundary
   spot-checks; whole-file hash.
5. **Listing / map canonical layout.** Confirm (or create) a canonical
   text/record-layout reference for `/L` and `/M` output, or record why
   the focused structural harness is the right assertion.
6. **Native-app derivation records → WP4** (not WP3): DASH and BANNER
   independent byte/relocation derivation + reviewer sign-off, bound to
   their manifests.

Ledgers B and C need **no remediation** — they are `NOT-APPLICABLE`; WP6's
consolidated pass + the user's harness matrix confirmed the reject cases
assert an exact diagnostic identity.



---

## Appendix — WP1 seed classifications & schema-validation (historical)

_Retained from the WP1 gate; superseded by the full Ledger A above but
kept as the worked-example calibration of the schema._


### 1. `tests/fixtures/casm/casmhello.ref.hex` — Static PRG

- **Source**: `casmhello.seq`, generated by `cmake/GenerateCasmTestFixtures.cmake`.
- **Class**: Static PRG (`.ORG $3400`, 40 bytes).
- **Claimed provenance** (header): "Independently hand-assembled … NOT
  produced by CASM. The message bytes are copied verbatim from the
  fixture's `.BYTE` directives (a source input, not a CASM output)."
- **Derivation present**: full address ledger `$3400`–`$342F`, each
  instruction traced to opcode + operand (`A2 0E` = `LDX #<msg`, etc.),
  message bytes decoded to `"YES IT BUILDS! -- CASM" CR NUL`; byte count 40;
  artifact SHA-256 `b33414b7…`.
- **Gaps vs. the contract**: (a) no **source SHA-256** — cannot detect a
  silent `casmhello.seq` edit; (b) no recorded **generated-`.seq` byte
  hash** or generator-identity binding beyond the prose "in
  `GenerateCasmTestFixtures.cmake`"; (c) no named **independent reviewer**
  sign-off; (d) live `COMP` evidence is in CMake comments / prior
  walkthroughs, not linked from the reference.
- **Provisional provenance state**: `CANONICAL-INDEPENDENT` **pending
  metadata completion** (items a–d). The derivation itself is sound and
  non-circular; the reference is not yet fully contract-compliant.
- **Remediation disposition (for WP3)**: add source hash + generated-`.seq`
  hash + reviewer record; link the live `COMP` evidence.

### 2. `tests/fixtures/casm/casmifskip.ref.hex` — conditional, output depends on suppression

- **Exact generated source** (`casmifskip.seq`, from
  `GenerateCasmTestFixtures.cmake` ~line 2332):
  ```
  .ORG $C000
  .IF 0
      LDA UNDEFINEDXYZ
      .WORD NOTASYMBOL
  .ENDIF
      NOP
  ```
- **Class**: Static PRG whose output is defined *by* conditional
  suppression. The `.IF 0` body references `UNDEFINEDXYZ` and
  `NOTASYMBOL`, which are defined nowhere — if the branch were assembled it
  would be a hard error. The suppressed-branch scanner parses the body
  structurally (matching `.ENDIF`) but evaluates nothing, allocates no
  symbol, and emits no bytes.
- **Why skipped source contributes no bytes**: per CASM's documented
  conditional-assembly semantics (Phase 15), a false `.IF` branch is
  scanned only for nesting structure; no token in it reaches the parser,
  the symbol layer, or the emitter. The PC does not advance across it.
- **Expected bytes**: `00 C0` (load-address header) `EA` (the single `NOP`
  at `$C000`) — 3 bytes total.
- **Claimed provenance** (header): "Hand-derived … NOT produced by CASM."
- **Gaps**: same metadata gaps as row 1 (no source hash, no generated-`.seq`
  hash, no named reviewer); additionally the derivation prose is terse —
  a stronger record would state the PC-non-advance rule explicitly as done
  here.
- **Provisional provenance state**: `CANONICAL-INDEPENDENT` pending metadata
  completion.

### 3. `tests/fixtures/casm/casmpgr6.ref.hex` — R6 PRG

- **Source**: `casmpgr6.seq` (no `.ORG`, relocatable, default origin
  `$3400`): `START:` / 40 × `NOP` / `JMP TARGET` / `TARGET:` / `NOP`.
- **Class**: R6 PRG — one real relocation entry.
- **Derivation present**: `START = $3400`; 40 `NOP` occupy `$3400–$3427`;
  `JMP` (`4C`) at `$3428–$342A`; `TARGET = $342B` so `JMP` encodes
  `4C 2B 34`; the `ValHi` byte `$34` is at program offset `$2A` — the sole
  relocation entry. R6 table `2A 00`; footer `00 34` (base) `01 00` (count)
  `52 36` (`"R6"` magic). Byte count 54; artifact SHA-256 `34d42ac5…`.
- **R6-specific evidence status**: relocation-eligibility reasoning is
  present (only the `JMP` absolute operand's high byte is relocatable);
  entry offset, count, terminator/footer all derived. **Missing**:
  explicit verification of the applied relocation at ≥2 load bases (the
  workflow's R6 requirement) linked from the reference.
- **Claimed provenance** (header): "Independently hand-derived, NOT produced
  by CASM."
- **Gaps**: no source hash, no generated-`.seq` hash, no named reviewer, no
  linked multi-base relocation-application evidence.
- **Provisional provenance state**: `CANONICAL-INDEPENDENT` pending metadata
  completion + linked multi-base evidence.

### 4. `casmnumerrd` — diagnostic rejection

- **Exact generated source** (`casmnumerrd.seq`,
  `GenerateCasmTestFixtures.cmake:448`): `.ORG $C000` / `.WORD 65536`.
- **Class**: Diagnostic rejection. `65536` exceeds the 16-bit `.WORD`
  range; CASM rejects it with a numeric-overflow diagnostic and produces
  **no output file**.
- **Reference file**: none, and none should exist. Not in `CASM_REF_NAMES`
  (confirmed — the CMake comment at line 455 says so explicitly). Siblings
  `casmnumerrh` (`$10000`) and `casmnumerrb` (`%1…1`, 17 bits) are the same
  case in hex and binary.
- **Correct assertion**: exact diagnostic identity + location, verified
  live; no fabricated `.ref.hex`.
- **Provenance state**: `NOT-APPLICABLE`. WP2 records it in the
  rejected/diagnostic-only ledger, not the fixed-byte ledger.

### 5. `src/external/dash/dash.ref.hex` — native application manifest

- **Class**: Native application manifest. Ships as `DASH.PRG`; transcribed
  to binary at build time by `scripts/hex_manifest_to_bin.py` (no 6502
  knowledge).
- **Metadata present**: byte count 4579; artifact SHA-256 `3b4d0693…`;
  **seven per-file `source_sha256` entries** (`dmain.s` … `ddata.s`); load
  addr `$3400`; provenance line naming native CASM 0.5.2 build 1404 under
  VICE, and "ca65 `dash_ref` cross-check MATCHES".
- **What the manifest proves**: the shipped bytes match a specific reviewed
  native assembly, and an edited source without a regenerated manifest is a
  hard build failure (stale-artifact guard). It also has a ca65 differential
  that currently matches byte-for-byte.
- **What it does not yet prove**: its own correctness. There is **no
  independent byte/relocation derivation record** (load address, program
  extent, relocation eligibility/exclusions, ordered offsets/count, footer)
  worked out from the 6502 encoding + R6 format and reconciled by a second
  reviewer. The ca65 match is `DIFFERENTIAL-ONLY` evidence — strong (ca65
  and CASM share no code) but not the independent-oracle the contract
  requires.
- **Provenance state**: `NATIVE-OBSERVATION` today. Becomes
  `CANONICAL-INDEPENDENT` when the **WP4** derivation record under
  `src/external/dash/` is created, peer-reviewed, and linked from this
  manifest, and verified against the stabilized `0.2.0` artifact at
  multiple runtime bases.

## Schema validation outcome (WP1)

The schema accommodated all five classes without a field being unusable or
missing. Observations fed back into the WP1 contract:

- Nearly every existing `.ref.hex` will land at "`CANONICAL-INDEPENDENT`
  pending metadata" — a sound non-circular derivation but **no source
  hash, no generated-`.seq` hash, no named reviewer**. WP2 should expect a
  large "strengthen metadata" column rather than mass re-derivation.
- Generated fixtures need field 13 (generator identity + generated-`.seq`
  hash) as a first-class column, not a sub-note — confirmed and kept.
- R6 references need field 16 to always call out multi-base
  relocation-application evidence specifically.
- Diagnostic-only cases classify cleanly as `NOT-APPLICABLE` with no
  register friction.
- The native-app manifest's split (machine-integrity record here,
  correctness in a linked WP4 derivation record) maps onto the schema
  without embedding review metadata in the manifest — the WP1
  recommendation holds.

