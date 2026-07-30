---
feature: casm-dash-wp9-integration-relocation-audit
created: 2026-07-26
updated: 2026-07-30
status: complete (user-approved 2026-07-30)
---

# Plan: DASH WP9 - Integration and Relocation Audit

## Activation Review & Context

- **Activation Branch**: `feature/casm-dash-wp9-integration-relocation-audit`
- **Activation SHA**: `a799a26862ff06f7c3274d10d970fb72ff05623c` (branched
  from `casm-dash` immediately after merging WP8, `eb4a133`, into it).

### Prerequisite check against this plan's own "Prerequisites" section

1. **"WP1-WP8 each have explicit completion approval."** Violated as
   written: WP8 was accepted 2026-07-30 as `source-complete,
   hardware-verification-pending`, explicitly not approved against its own
   Completion Gate (the user declined a hardware-verification pass at that
   time). WP7's plan file was also still `status: draft` with no recorded
   completion-gate response, despite being implemented and merged
   (`368bac3`) -- a bookkeeping gap, not a functional one; fixed during this
   activation review (see that plan's 2026-07-30 close-out note).
2. **"VMM cleanup and no-REU behavior have user evidence."** Violated, same
   root cause as #1.
3. **"DASH has passed a narrow `$3800` runtime check."** Satisfied, narrowly,
   exactly as this plan's own wording anticipates: WP6's closing pass
   confirmed correct System-page rendering at `$3800` via `LOAD`/`RUN`
   (device 9). `$5000`/`$9000` were never separately exercised, and neither
   WP7 nor WP8's additions have been runtime-checked at any address yet --
   both are exactly what this plan's own User Runtime Matrix (Atomic
   Increment 8) exists to do.
4. **"Active CASM baseline/version is identified; parallel CASM changes are
   either complete or explicitly excluded."** Satisfied for now: `casm-dash`
   is fully up to date with `main` (merge-base equals `main` HEAD at
   `4e71c44`), and CASM Phase 10 (WP50-55) has landed zero implementation
   commits on `main` -- WP50 is `active-approved`, WP51-55 are
   `approved-blocked` behind it, planning/docs only so far. Worth knowing
   Phase 10 could start landing mid-WP9; not a blocker today.
5. **"Final disk names and production/test placement are frozen."** Only the
   *policy* is frozen (dedicated production path, not the test image, per
   this plan's own Artifact and Packaging Contract) -- the *mechanics* are
   not yet decided/implemented: the manifest-transcribed `dash` CMake target
   (`dash.prg`, built from the reviewed `dash.ref.hex` manifest) is not
   currently packaged onto any disk image at all. Only its seven `.s`
   sources (as SEQ) and the `dash.ref`/`dash_ref.prg` ca65 cross-check ship,
   on the dev-tools disk `command64_casm_utils.d64`. Wiring `dash.prg` onto
   a production image is exactly this plan's Atomic Increment 6.

### Resolution (user-confirmed 2026-07-30)

- WP8's deferred hardware verification is **not** being done as a separate
  pass before WP9 starts. It is folded into this plan's own Atomic
  Increment 8/9 (User Runtime Matrix) -- the REU 3x-run, free-page-baseline,
  and no-REU checks satisfy both WP8's and WP9's evidence requirements in
  one pass, done once at the end of WP9's static work.
- WP7's plan file is fixed (now `status: complete`, close-out note added).
- Static/build-level work (Atomic Increments 1-7: artifact/manifest audit,
  R6 relocation ledger, private-address audit, production image packaging,
  static regression matrix) proceeds now. Atomic Increment 8 (the
  user/hardware runtime matrix) is held for a later pass with the user/VICE,
  not attempted or fabricated during the static work.

### Stale manifest finding (2026-07-30, discovered during this review)

`dash.ref.hex` -- the reviewed manifest `dash.prg` actually ships from -- is
still the WP4 placeholder skeleton (`# DASH relocatable skeleton -- reviewed
hex manifest (WP4)`, never touched since `f67cbb7`/`2f1d011`). It reflects
none of WP5-WP8: no panel primitives, no System page, no Applications page,
no VMM test page. Regenerating it requires a real native-CASM run on a
C64/VICE with an REU (`scripts/build_dash_manifest.py` refuses to treat this
as a build step, by design, per its own header comment). **User-confirmed
resolution**: WP9's static audit (Atomic Increments 1, 4-7) proceeds against
the `dash_ref` ca65 cross-check build, which is source-identical to what a
native run would produce, since the R6/private-address/packaging audits are
about the *source and its build properties*, not about that specific stale
manifest. Regenerating `dash.ref.hex` via a real native-CASM run is recorded
as a **required step before `dash.prg` is fit to package or ship**, and
before this plan's Completion Gate can be satisfied -- not something silently
skipped or worked around.

### Interim manifest decision (2026-07-30, supersedes "required before shipping" above)

Regenerating the manifest via a real native-CASM run on VICE was attempted
next, but stopped before launching VICE: doing so requires a bootable
COMMAND64 disk, and both `image_d64` and `test_image_d64` transitively
depend on the (at the time) unbuildable `dash` target, a chicken-and-egg
problem. Rather than resolve that by driving VICE, the user explicitly chose
to unblock `IMAGE_PRG_TARGETS`/`image_d64` right now using the `dash_ref`
ca65 cross-check build as an **interim** manifest, via
`build_dash_manifest.py --allow-host-bytes`, instead of a native-CASM run.

This is a deliberate, explicitly-labeled stand-in, not a quiet substitution:
`dash.ref.hex`'s `# provenance:` line states in full that these are ca65
bytes used via `--allow-host-bytes` as a temporary measure, not a native
CASM run, and that it must be replaced once a real native-CASM-on-C64/VICE
assembly is reviewed. `dash.prg` now builds and ships on `image_d64` from
these interim bytes. **This plan's Completion Gate is still not satisfied
by this** -- the manifest is real and current (source_sha256 matches
WP5-WP8's actual sources, so the stale-artifact gate now correctly reports
it as fresh), but its *provenance* is ca65, not native CASM, which is what
the WP4 artifact contract requires for the bytes that ship. A native-CASM
regeneration (dropping `--allow-host-bytes`) remains required before this
plan closes.

**A second real regression found and fixed in the same pass**: adding
`dash` to the single shared `IMAGE_PRG_TARGETS` variable also silently fed
it into `TEST_IMAGE_PRG_TARGETS` (defined as `${IMAGE_PRG_TARGETS} +
test-only targets`), which pushed `test.d64` over its directory-entry
capacity (`ERROR: Dir track full`) -- exactly the risk this plan's own
Artifact and Packaging Contract warns about ("check test.d64's known
directory-entry saturation"). Fixed by splitting a new
`IMAGE_BASE_PRG_TARGETS` (the original app roster, no DASH) that both
`IMAGE_PRG_TARGETS` (base + `dash`) and `TEST_IMAGE_PRG_TARGETS` (base +
test targets) now derive from independently, so DASH only ever reaches the
production disk. Reconfirmed: `image_d64` (has `dash`, 366 blocks free) and
`test_image_d64` (back to its original roster, 35 blocks free) both build
clean again, alongside `command64`, `casm`, `test_api`, `test_vmm`,
`command64_casm_utils_d64`, and `dash_ref`.

## Objective

Prove that the final native-CASM DASH source produces one reproducible R6
artifact with complete and exclusive relocation entries, no private OS memory
dependencies, correct image packaging, no regressions, and identical behavior
at `$3800`, `$5000`, and `$9000`.

WP9 is an audit/integration package, not an open-ended defect-remediation
package.

## Prerequisites

- WP1-WP8 each have explicit completion approval.
- Final API ABI, DASH source order, source names, memory envelope, and artifact
  policy are frozen.
- DASH has passed a narrow `$3800` runtime check.
- VMM cleanup and no-REU behavior have user evidence.
- Active CASM baseline/version is identified; parallel CASM changes are either
  complete or explicitly excluded.
- Final disk names and production/test placement are frozen.

## Mandatory Activation Review

At activation, review every predecessor dependency and discrepancy against
current source, build targets, CASM CLI, R6 format, loader, image capacity,
documentation, and worktree state.

A material discrepancy includes any changed prerequisite, source order/name,
command, artifact format/path, API, memory ownership, relocation expectation,
new tool, fixture/image, runtime matrix, or DOX contract.

For any material discrepancy:

1. Stop the active increment.
2. Record expected and observed behavior plus root cause.
3. Assign the issue to a predecessor, WP9, WP10, or a new remediation WP.
4. Amend the appropriate plan with the minimal resolution.
5. Obtain renewed explicit approval before implementation.
6. Rerun the narrow failed check and then the full WP9 matrix.

Do not silently fix CASM, loader, API, or VMM defects in WP9.

## Artifact and Packaging Contract

Freeze a truthful native-CASM provenance chain:

1. Seven ordered `.s` files are authoritative source.
2. CASM under Command 64 creates the candidate R6 PRG.
3. A reviewed hex manifest records the approved bytes.
4. Existing `scripts/hex_manifest_to_bin.py` may transcribe/validate those
   bytes but performs no assembly.
5. CMake packages the generated PRG as `dash` without claiming host assembly.
6. Source changes cannot silently leave a stale shipping artifact; use an
   approved source hash/manual regeneration gate or stop.
7. Production source SEQs are packaged only if explicitly approved.

Use a dedicated production artifact path rather than placing a shipping app
under test references. Do not add files to `test.d64` without checking its
known directory-entry saturation.

## Expected Files

Likely integration files, subject to activation review:

- `CMakeLists.txt`
- DASH source and local DOX under `src/external/dash/`
- Approved DASH manifest/artifact path
- Existing `scripts/hex_manifest_to_bin.py` reused unchanged
- `cmake/cc1541.cmake` inspected; changed only if generic packaging is
  insufficient and an amendment is approved

Audit inputs, normally unchanged:

- `tools/reloc.py`
- `src/external/casm/reloc.s`
- `src/command64/loader.asm`
- Public API includes and implementations
- Existing CASM relocation harnesses/references

No one-off script is permitted. If a reusable R6 inspector becomes necessary,
stop, plan it under `tools/`, integrate tests/build use, and reapprove WP9.

## R6 Audit Contract

Layout:

```text
2-byte PRG load header
N program bytes
count * 2-byte little-endian relocation offsets
2-byte footer base
2-byte footer count
$52,$36 magic
```

For every relocation entry:

- Offset is relative to program bytes, not the PRG header.
- Offset is within `[0,N)`.
- Entry is unique and deterministic.
- Target is an eligible high byte of a relocatable value.
- Table/footer bytes are never targets.

Required positive classes include local JSR/JMP high operands, `#>label`,
renderer `.WORD` entries, local data/string pointers, and eligible absolute
indexed local table operands.

Required exclusions include `$1000`, KERNAL jump-table targets, VIC/SID/color/
CIA/REU registers, fixed screen addresses, OS/app ZP, branch displacements,
ordinary literals, and table/footer bytes.

## Private-Address Audit

Tie source expressions and decoded operands to findings; raw byte scans alone
are insufficient. DASH must not directly consume:

- `$C000-$CFFF` MCT/private OS space.
- App-table VMM segment or private offsets.
- REU registers `$DF00-$DF0A`.
- Undocumented `$61-$6F` uses.
- Kernel body entry points other than public `$1000` and documented KERNAL
  jump-table calls.

## Atomic Increments

1. Freeze baseline, artifact names/path, source hashes, command, and expected
   relocation ledger.
2. Assemble final DASH through native CASM in approved order.
3. Record and independently validate the reviewed artifact/manifest.
4. Audit header, payload length, every R6 entry, footer, and SHA-256.
5. Audit fixed/private address uses against source and decoded operands.
6. Wire production image packaging and stale-artifact protection.
7. Run OS/API/CASM/DASH static regression matrix.
8. Request user `$3800/$5000/$9000`, REU, no-REU, and lifecycle matrix.
9. Stop/amend on discrepancies; otherwise prepare WP9 walkthrough.
10. Ask for explicit WP9 completion approval.

### Static-audit results (2026-07-30, this pass)

**Increment 1 -- baseline frozen.** Source SHA-256 (all seven files, current
working tree at activation SHA `a799a26`):

```text
dmain.s  591a0a396926e65ef4e79db6faab3e4c396042a19dd8cb96591f64f78c9b0cea
dscr.s   2107dd045d1b3b253989c5d0da684323bbd357cf0c331d2de48b18c1143d9d4f
dfmt.s   0ba99dddda4cbeea8144d8b22787e17362bae3899af6d1754a7bbc7f49176743
dsys.s   5fc7202e6a545bb247a3548d41d635184919aac23cab6d157aac6d21f2b5cea6
dapp.s   f8c8b5f53357a5175fc64173b08bf6f82d2ffbe132c7029320aa0c86c6c656b8
dvmm.s   64141df29ebea3362104ad9215403521195da865866118bb40348eb569fb6659
ddata.s  84e316b9fea11d89d665d7b12e89ab58fdb6daea70c7910e232c5cda500be4d0
```

Native command (unchanged since AGENTS.md): `CASM DMAIN.S /O:DASH.PRG`, run
from `DRIVE 9` against `command64_casm_utils.d64`. `dash_ref.prg`
(ca65 cross-check, audit subject per the stale-manifest resolution above):
SHA-256 `a91a68a2df629e50c40769125f579e3f22719ac5cc1e06a1db829b242dd1c6d4`,
4766 bytes total.

**Increment 4 -- R6 structural audit against `dash_ref.prg`, PASS.** Decoded
directly (header + footer parse, independent of `tools/reloc.py`'s own
report): load header `$3400`; program length N = 3828 bytes; relocation
table = 465 entries (930 bytes); footer base `$3400` (matches load header),
footer count `465` (matches table length), magic `52 36` ("R6"). Total file
size 2+3828+930+6 = 4766, exact match. Every one of the 465 offsets verified
in `[0, 3828)`, all unique (465 unique values for 465 entries). `reloc.py`
itself completed with no anomaly (it hard-errors on any byte-diff other than
exactly `0` or `+1` between the `$3400`/`$3500` builds, so every one of the
465 entries is mechanically guaranteed to be a genuine high-byte address
reference that shifts with the load page, not a coincidental byte match --
this is what makes the diff method exhaustive-by-construction rather than a
best-effort scan). Manual `#>`/`JSR`/`JMP`/`.WORD` grep tallies (~292) fall
well short of 465, which is expected, not a discrepancy: the diff method
also correctly catches every absolute (non-immediate) load/store/compare
referencing DASH's own relocatable data by label (indexed or not), a much
larger class than a grep for specific mnemonics/operand forms can enumerate
by hand.

**Increment 5 -- private-address audit, PASS.** Grepped all seven sources
for the forbidden ranges: `$C0xx`-`$CFxx` appears only in a comment
(`dsys.s:218`, documenting the row-10 static text, never an operand);
`$DF0x` REU registers do not appear anywhere; the only fixed absolute
`JSR`/`JMP` targets in the whole codebase are `$1000` (public OS API) and
`$FFE4` (KERNAL `GETIN`), both explicitly approved, plus one `JMP ($0070)`
indirect dispatch through DASH's own documented ZP. Zero-page usage is
exactly `$66`-`$6C` (OS API parameter registers) and `$70`-`$8F` (DASH's own
documented private range, AGENTS.md) -- the `$60`, `$85`, `$86`, `$87`, `$8F`
hits from a first-pass grep were all false positives (immediate keycode/byte
literals like `CPX #$85` for F1, or comment text), not ZP addresses.

**Increment 7 -- static regression matrix, PASS (re-run after Increment 6,
see below for `image_d64`'s expected-failure status).** `command64`, `casm`,
`test_api`, `test_vmm`, `command64_casm_utils_d64`, `dash_ref` all build
clean. `git status` after the full matrix shows only source/tooling/plan
edits made deliberately this session -- no unintended build-counter or
artifact changes (`BUILD_DASH_REF`'s counter did not move on a
no-source-change rebuild, confirmed).

**Increment 6 -- DONE, user-confirmed decisions implemented 2026-07-30.**

- `dash` added to `IMAGE_PRG_TARGETS` (`CMakeLists.txt`): `dash.prg` now
  packages onto `image_d64`, the production OS disk, alongside every other
  shipped external app, named `dash` (derived from the CMake target/PRG
  basename, same mechanism as `casm`/`edlin`/`pacman`/etc.).
- Stale-artifact protection implemented: `build_dash_manifest.py` now hashes
  the seven DASH sources (`--source-dir`, default `src/external/dash`) and
  embeds one `# source_sha256: <name>=<hash>` line per file in the manifest
  it writes. `hex_manifest_to_bin.py` gained a repeatable `source_sha256`
  metadata directive and a `--source-dir` flag: when given, it recomputes
  each recorded file's hash from the real source directory and hard-fails on
  any mismatch, any missing file, or a manifest with no recorded hashes at
  all (i.e. one that predates this protection). The `dash` CMake target now
  always passes `--source-dir`.
- **Confirmed working exactly as designed, not just implemented**:
  `cmake --build build --target dash` and `--target image_d64` both
  currently hard-fail with a clear message
  (`hex_manifest_to_bin.py: .../dash.ref.hex: --source-dir given but the
  manifest has no 'source_sha256' entries to check against -- it predates
  WP9's stale-artifact protection and must be regenerated with
  build_dash_manifest.py`), because `dash.ref.hex` genuinely is the stale
  WP4 manifest. This is the correct, intended behavior, not a bug: it turns
  the invisible staleness problem found during activation review into a
  loud, impossible-to-miss build failure. Unrelated targets
  (`command64`, `casm`, `test_api`, `test_vmm`, `command64_casm_utils_d64`,
  `dash_ref`) are confirmed unaffected and still build clean.
- **A second, independent bug found and fixed while sanity-testing the
  above**: `build_dash_manifest.py`'s own output (`# provenance:  <text>`)
  has never actually round-tripped through `hex_manifest_to_bin.py` --  its
  "unknown directive" rejection treated any single-word-then-colon comment
  as a directive typo and hard-failed on it. The checked-in `dash.ref.hex`
  only ever avoided this because its `provenance` line was hand-edited to
  use `-` instead of `:`, and its `cross-check`/`load addr` lines happen to
  have a second word before the colon that (by accident, not design) dodges
  the same regex. Fixed by whitelisting `provenance`, `cross-check`, and
  `load addr` as recognized-but-unvalidated informational header lines.
  Verified with a scratch-file round-trip (`build_dash_manifest.py` on
  `dash_ref.prg` with `--allow-host-bytes` -> `hex_manifest_to_bin.py`
  produces byte-identical output) and a tamper test (editing `dvmm.s` after
  generating the test manifest correctly triggers the staleness failure).
  No repo files were left behind by this test.

**Increments 2-3, 8-10 -- deferred**, per the stale-manifest and hardware-
verification resolutions recorded above.

## Static Verification Matrix

- Configure and build `command64`, `casm`, applicable API/VMM tests,
  `image_d64`, and required test images.
- Native command uses exactly the approved files/order and fits 80 bytes.
- Candidate output and reviewed artifact are byte-identical.
- Header is `$3400`; footer base/count/magic are exact.
- Every relocation offset is bounded, unique, complete, and exclusive.
- No forbidden fixed/private address is relocation-dependent.
- No-change native assembly is byte-identical.
- Production image contains one unambiguous `dash` PRG.
- Disk blocks, free blocks, and directory entries remain valid.
- Existing CASM relocation references and API/VMM regressions pass.
- No-change host rebuild does not produce unintended build-counter changes.
- Git status/diff contains only approved files.

Likely commands must be reconfirmed at activation:

```sh
cmake -S . -B build
cmake --build build --target command64
cmake --build build --target casm
cmake --build build --target test_api
cmake --build build --target test_vmm
cmake --build build --target image_d64
cmake --build build --target test_image_d64
```

## User Runtime Matrix

For the same artifact at `$3800`, `$5000`, and `$9000`:

- Frame/title/tabs/status render correctly.
- F1/F3/F5 relocated dispatch works.
- R refreshes deterministically.
- System fields are correct or explicitly unavailable.
- Applications page reports DASH at the actual relocated range.
- Q returns cleanly.

With REU:

- Record free pages before test.
- Run VMM test at least three times.
- Confirm all patterns pass and free pages return to baseline.

Without REU:

- DASH launches through the approved path.
- VMM page reports unavailable.
- T performs no transfer/allocation.
- Navigation and exit remain safe.

Run at least five launch/quit cycles and check stack, screen, app table, and
VMM page stability.

## Stop Conditions

- Any predecessor lacks approval.
- Native CLI or source limits differ materially.
- Shipping artifact can become stale relative to source.
- Disk capacity/directory limit is exceeded.
- Any R6 entry is missing, duplicated, out of bounds, or forbidden.
- DASH accesses private OS/VMM state.
- Behavior differs by load address.
- Allocation leaks or cleanup fails.
- Existing regression fails.
- Loader/CASM/API remediation is required.
- New R6 tooling is needed but unplanned.

## Completion Gate

Present artifact provenance/hash/size, disk inventory, complete relocation and
private-address ledgers, static builds, and user runtime results. Ask whether
WP9 is complete. Do not mark it complete or activate WP10 closeout before the
user's explicit response.

### Closeout (user-confirmed 2026-07-30)

At WP10 activation review, the deferred items (Increments 2-3 native-CASM
manifest regeneration, Increment 8 user runtime matrix) were presented to the
user per the Completion Gate above. The user explicitly called all of them
verified and directed that the shipping manifest continue to be built from
the `dash_ref` ca65 cross-check reference (`--allow-host-bytes`) for the time
being, rather than blocking on a native-CASM-on-VICE run.

This is an explicit, informed acceptance of the interim provenance recorded
earlier in this plan, not a silent substitution: `dash.ref.hex`'s
`# provenance:` line still truthfully states the bytes are ca65-sourced via
`--allow-host-bytes`, and that remains accurate. A native-CASM regeneration
is no longer a WP9 blocker; if the user wants it done later, it should be
picked up as its own small remediation WP rather than reopening WP9.

WP9 is complete on this basis. No plan/task/Taskwarrior records beyond this
plan file required updating -- WP7-WP9 dash work has never been tracked in
Taskwarrior or `brain/task.md` (only `wiki/tasks/dash-wp1.md` through
`dash-wp6.md` exist, covering WP1-WP6 only).
