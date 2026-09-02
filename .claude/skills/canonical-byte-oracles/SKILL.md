---
name: canonical-byte-oracles
description: Use when adding or changing a CASM test reference or a CASM-native application's shipping manifest -- any *.ref.hex, expected PRG bytes, an R6 relocation oracle, or a ca65 differential comparison. Triggers on -- ref.hex, trusted reference, expected bytes, byte oracle, canonical oracle, hand-derived reference, dash.ref, banner.ref, R6 relocation oracle, COMP fixture, provenance state, audit register.
---

# Canonical Byte Oracles

Full contract: `.agents/workflows/canonical-byte-oracles.md`. That workflow
doc is the canonical, agent-neutral rule and binds any agent in this repo.
This file is only a Claude Code at-use-time reminder — nothing load-bearing
lives only here. If you are an agent without this skill, read the workflow
doc directly.

Read the full workflow before deriving or classifying any reference. It
covers the authority hierarchy, the seven oracle classes and their required
evidence, the five provenance states, prohibited circular sources,
mandatory peer-review metadata, generated-repetition handling, and mismatch
stop conditions.

## The one rule that is always violated first

**Never take the expected bytes from CASM.** Not from a CASM run, not from
`src/external/casm/opcodes.s`, not from a prior `.ref.hex` that was itself
CASM-derived, not from a shipping manifest built out of CASM output, not
from a ca65 binary used as the answer. Derive from the published 6502/6510
encoding + CASM's documented semantics + PRG/R6 framing + hand arithmetic,
**then** compare against native CASM. Reading CASM output to compare after
an independent derivation is fine and expected; reading it to obtain the
answer is the circularity this skill exists to stop.

## Checklist

1. Identify the **oracle class** (Static PRG / R6 PRG / Repetitive /
   Diagnostic rejection / Listing-map / Determinism-only / Native-app
   manifest) and pull its required-evidence row from the workflow.
2. Derive every byte or byte range from an **acceptable independent
   source**; annotate each to a spec rule or arithmetic step.
3. Record **source identity + SHA-256** (for generated fixtures: generator
   identity *and* a hash of the exact generated `.seq` bytes).
4. Get an **independent reviewer** to reproduce the addresses, encodings,
   lengths, hashes, and R6 entries from your derivation. Record reviewer +
   date.
5. Run a **live `COMP`** (or structural harness) against native CASM under
   Command64 per `.agents/workflows/vice-mcp-testing.md`; capture the
   invocation, the result, CASM version/build, and R6 multi-base evidence.
   Fire overlay `test` events.
6. Assign **exactly one provenance state** in the audit register
   (`brain/reviews/2026-09-01-casm-byte-oracle-audit.md`). Only
   `CANONICAL-INDEPENDENT` may be packaged as an authoritative `.ref`.
7. On **any mismatch** (native ≠ oracle, or ca65 ≠ CASM): stop, report the
   first differing offset + context, classify the cause before editing
   either side. Never rewrite CASM to match ca65.

## For native-app manifests (DASH, BANNER, future)

The `.ref.hex` manifest stays a machine-integrity record (byte count,
artifact hash, source hash(es), R6 ledger) and links by path to a separate
peer-reviewed derivation record under `src/external/<app>/`. The manifest
is the shipped artifact and stale-artifact guard, **not** proof of its own
correctness. A ca65 comparison is `DIFFERENTIAL-ONLY`.
