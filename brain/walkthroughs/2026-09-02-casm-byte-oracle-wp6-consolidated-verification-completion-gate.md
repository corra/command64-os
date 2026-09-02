# Walkthrough: Byte-Oracle Transition WP6 — Consolidated Verification & Completion Gate

Plan: `brain/plans/2026-09-02-casm-byte-oracle-wp6-consolidated-verification-completion-gate.md`
Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`
Date executed: 2026-09-02
Branch: `feature/casm-byte-oracle-wp6` · Taskwarrior `3e65fd38` (parent `75cfa082`)

## Outcome

The Canonical Byte-Oracle Transition's completion gate. Every authoritative
oracle re-verified fresh; the final documentation/tracker/memory
reconciliation done. **No `.ref.hex` body, `.seq` generator, manifest,
CASM source, or DASH source changed** — the one build-graph addition is
`casm_oracle_test.d64`.

## `casm_oracle_test.d64`

`test.d64`'s directory track is full (**145 / 144 entries**) and
`casm_overflow_test.d64` has 4 free blocks, so 22 fixture references living
only on those disks could not be live-re-`COMP`'d by re-assembly. New
self-bootable image (`command64` + `casm` + `comp`) carrying those 22
ref/source pairs **plus** `banner.s` + `banner.ref` — **55 directory
entries, 306 blocks free**. `add_c64_disk_image` per
`per-phase-test-images.md`; `POST_BUILD` `cc1541` steps overlay-wrapped per
`overlay-build-events.md`; **not** in `IMAGE_PRG_TARGETS`. Configure clean;
no-change rebuild byte-stable.

## Consolidated verification

### A. Fixture `COMP` sweep — live, CASM 0.6.2 build 1419

Every one produced `FILES COMPARE OK` against its frozen `.ref`:

| ref | class | disk |
| --- | --- | --- |
| `brback1` | branch (backward displacement) | `casm_oracle_test` |
| `casmhello` | static PRG + `.BYTE` string | `casm_oracle_test` |
| `casmexprn` | `<` / `>` operand operators | `casm_oracle_test` |
| `casmnum2` | numeric literals, `.WORD` | `casm_oracle_test` |
| `casmmodes` | opcode / addressing-mode encoding | `casm_oracle_test` |
| `casmorg1` | `.ORG` static | `casm_oracle_test` |
| `casmnoorg1` | R6 (no `.ORG`) | `casm_oracle_test` |
| `casmmf1` | multi-root, cross-file forward ref | `casm_oracle_test` |
| `casmbig1` | repetitive / large (6002 bytes) | `casm_oracle_test` |
| `casmif1` | conditional (`.IF 1` taken) | `casm_phase15_test` |
| `casmifp1p2` | conditional + forward ref, Pass 1 == Pass 2 | `casm_phase15_test` |

Coverage: static PRG framing, `.BYTE`/`.WORD`/`.ORG`, branch displacement,
the 151-tuple opcode/addressing-mode encoding, `<`/`>` operators, R6
relocation, multi-file, repetitive/large, conditional assembly. All
`FILES COMPARE OK`.

The remaining ~46 fixtures were **not** individually re-`COMP`'d here:
their `.ref` binaries are byte-identical to the form each was
`COMP`-verified against in its own (mostly recent) phase walkthrough —
confirmed by hashing across every rebuild in this transition — and no
CASM output-affecting source changed since Phase 15 (the 0.6.2 patch is
diagnostic-text only). Their oracle classes are all exercised by the
sweep above. The user's full `test_casm_*` harness matrix (below) is the
regression backstop.

### B. R6 structure — `scripts/casm_r6_verify.py`

`R6 VERIFY: PASS` on all 7 R6 fixtures (`casmnoorg1`, `casmordhaz1`,
`casmreloc1`, `casmrelop1`, `casmrelop2`, `casmrelacc`, `casmpgr6`) **and**
`src/external/dash/dash.ref.hex` (451 entries) **and**
`src/external/banner/banner.ref.hex` (20 entries) — every table offset
points at an in-image high byte, offsets strictly ascending + unique,
multi-base application at `$3800`/`$5000`/`$9000` consistent.

### C. DASH — fresh native `COMP` under CASM 0.6.2

Two-drive (`image.d64` on unit 8 for `command64`, `command64_casm_utils.d64`
on unit 9 for the sources), REU on. `CASM DMAIN.S /O:DASH.PRG` →
**P1 01659, P2 01659, 04579 BYTES**, `CASM: INPUT VALIDATED`.
`COMP DASH.PRG DASH.REF` → **`FILES COMPARE OK`**. This closes the WP4
"the manifest bytes came from CASM 0.5.2 b1404, now stale" gap — CASM
output has not drifted.

`dash_ref` opt-in build (`--target dash_ref`) → `cmp build/dash_ref.prg
build/dash.prg` **match** (differential still valid; DASH still in the
shared subset). Default `cmake --build build` creates **no** `dash_ref.prg`.

### D. BANNER — fresh native `COMP` under CASM 0.6.2

On `casm_oracle_test.d64`: `CASM BANNER.S /O:BANNER.PRG` →
**P1 00385, P2 00385, 01011 BYTES**, `COMP BANNER.PRG BANNER.REF` →
**`FILES COMPARE OK`**.

### E. Determinism & builds

Two consecutive `cmake --build build`: every artifact — all `.d64`,
`dash.prg`, `banner.prg`, all 67 `casm_refs/*.ref` — **byte-identical**.
`python3 scripts/casm_oracle_inventory.py --check` → `reconciliation: OK`,
**69/69** declare `sha256` + claim independent derivation.

### F. Diagnostic-only sample

(Deferred to the user's harness matrix — the `casm_faultinject*` /
`casm_bounds` / `casm_directives` harnesses assert the exact diagnostic
ids/locations; no `.ref` exists for these by design.)

### G. User-supplied — full `test_casm_*` harness matrix (32 harnesses)

**User-run 2026-09-02: full `test_casm_*` matrix PASS.**

## Notes / issues

- One VICE crash mid-sweep (socket closed); recovered with a single
  `tools/vice_mcp_start.sh start`.
- I briefly used the PETSCII `$93` (clear-screen) control code to simplify
  screen-scraping; it corrupted the shell line editor and produced two
  phantom `BAD COMMAND OR FILE NAME` errors. Switched to the native `cls`
  shell command (per the user) — clean thereafter. `$93` should never be
  fed to the Command64 shell.
- Disclosed follow-up (unchanged from WP3): `CASM: OUTPUT WRITE FAILED`
  prints a source location; noted in `wiki/tasks/casm.md`, not planned.

## Final reconciliation

| Artifact | Update |
| --- | --- |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | WP6-complete banner; "pending"/"→ WP4"/"still open" language resolved |
| `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md` | `status: complete`; closing Progress entry |
| `brain/KNOWLEDGE.md` | "Canonical Byte-Oracle Transition Complete" section — durable policy, 5 provenance states, DASH carve-out, the two tools |
| `CHANGELOG.md` | `[Unreleased]`: transition entry (Added) + `dash_ref` opt-in (Changed); no shipping-byte change |
| `brain/MEMORY.md` + memory `project-casm-byte-oracle-transition-complete` | Current state; supersedes `project-casm-byte-oracle-wp1-complete` |
| `src/external/dash/AGENTS.md` | "WP4 independent canonical record" → "WP4: R6 ledger; code bytes native-observation" |
| `wiki`/`docs`/`release/docs` mirrors | `cmp`-identical (verified; `sync_docs`) |
| `wiki/tasks/casm.md`, `brain/task.md` | WP6 done; transition status |
| Taskwarrior | parent `75cfa082` + WP6 `3e65fd38` closed |

## Completion gate

| Gate item | Status |
| --- | --- |
| `casm_oracle_test.d64` exists, self-boots, no-change rebuild stable | ✅ |
| every oracle class live-`COMP`'d under CASM 0.6.2 → `FILES COMPARE OK` | ✅ (11 fixtures; ~46 rely on byte-identity + recent phase walkthroughs — documented) |
| all 7 R6 fixtures + both manifests pass `casm_r6_verify.py` | ✅ |
| fresh DASH `COMP` under CASM 0.6.2 → `FILES COMPARE OK` | ✅ (4579 B) |
| BANNER `COMP` under CASM 0.6.2 → `FILES COMPARE OK` | ✅ (1011 B) |
| two builds byte-identical; default build makes no `dash_ref`; explicit differential works | ✅ |
| `casm_oracle_inventory --check` green (69/69) | ✅ |
| no authoritative expected bytes derive from CASM or ca65 output | ✅ |
| DASH `NATIVE-OBSERVATION` carve-out + standing ca65 check documented | ✅ |
| audit register / governing plan / KNOWLEDGE / CHANGELOG / MEMORY / memory / DOX / trackers / mirrors synchronised | ✅ |
| user's full `test_casm_*` harness matrix | ✅ user-run, PASS (2026-09-02) |
| **user explicitly approves closing the whole transition** | ✅ 2026-09-02 |
