---
feature: casm-phase5-wp17-expression-abi
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 5 WP17 Expression ABI

Plan: `brain/plans/2026-07-21-casm-phase5-wp17-expression-abi.md`

Taskwarrior: `3b09ea77-c325-4072-90fc-9812181a4e04`

## Outcome

WP17 implements only the frozen expression ABI and bounded storage surface. It
adds no evaluator behavior, parser/emitter integration, diagnostic messages,
zero-page allocation, resources, or runtime path.

## ABI

- Nine-byte private result record: value, flags, extraction, opaque symbol ID,
  and sign/magnitude addend.
- Four one-hot flags and full mask asserted.
- Full/low/high extraction and positive/negative sign ranges asserted.
- Diagnostics `$24-$27` reserved contiguously after Phase 4 `$23`; no messages
  or raise sites added.
- `exprInit` explicitly clears all nine bytes while preserving X/Y and carry.
- `exprGetResult` returns the private record pointer in X/Y with carry clear.

## Object Evidence

`od65 --dump-segments build/out_casm/expr.o`:

| Segment | Size |
|---|---:|
| CODE | 36 |
| BSS | 9 |
| RODATA | 0 |
| DATA | 0 |
| ZEROPAGE | 0 |

`od65 --dump-exports` reports only `exprInit` (30 bytes) and `exprGetResult`
(6 bytes). The record label remains private.

## Linked Measurements

| Measurement | WP16 baseline | WP17 candidate |
|---|---:|---:|
| CODE+RODATA | 8,705 | 8,741 |
| BSS | 1,127 | 1,136 |
| MAIN headroom | 408 | 363 |
| Relocations | 1,172 | 1,182 |
| R6 PRG size | 11,057 | 11,113 |
| Build | 1080 | 1081 |

Candidate SHA-256:
`20c367d17593b651e44a4a3eabc3bb094e54b01c87aab2e38d27d35374e86304`.

## Verification

- `cmake -S . -B build`: pass; `expr.s` discovered without CMake edits.
- Both `$3400` and `$3500` CASM links: pass.
- Immediate no-change build at 1081: pass.
- `image_d64`: pass; CASM remains on the release disk.
- `expr.o` segment/export inspection: pass.
- Source audit: nine explicit default stores, balanced stack, no imports,
  resources, zero page, or self-modifying code.
- `git diff --check`: pass.
- Completion dry run: stage `18` -> `19`, build 1081 -> 1082 exactly once;
  no-change rebuild preserved 1082; worktree restored to stage 18/build 1081.
- No broken C64-testing MCP or web emulator used.

## DOX Closeout

The root and `src`/`external`/`casm` DOX chain was applied. No AGENTS.md update
is required: WP17 implements the already frozen local ABI without changing
directory ownership, workflow, or child indexes.

## Completion Gate

WP17 has no runtime consumer, so no emulator/hardware matrix is required. After
explicit completion approval, apply the verified stage `18` -> `19` increment,
build to 1082, verify a no-change rebuild, close WP17, and leave WP18 pending
separate plan approval.

The user approved completion on 2026-07-21. The final `0.1.19` build 1082,
no-change rebuild, and release image all pass. WP17 is complete.
