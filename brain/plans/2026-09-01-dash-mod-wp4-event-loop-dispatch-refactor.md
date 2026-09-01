---
feature: dash-mod-wp4-event-loop-dispatch-refactor
created: 2026-09-01
status: approved -- in progress
taskwarrior: task 53 (child of 94ec17b3)
depends-on: DASH-MOD WP3 (computed constants + .assert invariants, done + user-approved 2026-09-01 -- brain/walkthroughs/2026-09-01-dash-mod-wp3-computed-constants-assert-invariants.md)
---

# Plan: DASH-MOD WP4 - Event loop / key dispatch / page dispatch refactor

## Status

**Proposed, not yet approved.** Fourth WP of the DASH Modernization
increment. Parent: `brain/plans/2026-09-01-dash-modernization.md`. WP1-3
done + approved. Branch: `feature/casm-phase14`.

**This is the first WP that changes DASH's shipped bytes.** Prior WPs
(WP2 `@local` rename, WP3 constant adoption) were byte-preserving against
the frozen manifest `3238b786...`. WP4's output legitimately differs; the
verification bar shifts from "byte-identical to the old manifest" to
"byte-identical **ca65 <-> native CASM**, behaviourally identical at
runtime, and re-baselined once at WP4 close" (parent plan, "Output-delta
discipline").

## Objective

Remove the duplication in `dmain.s`'s event loop, key ladder, and
page-select blocks, keeping DASH's **observable behaviour exactly the
same**: identical key bindings, identical page navigation, identical
redraw semantics, identical exit, identical relocation contract.

**Delivered:**
- The 10-branch key ladder (`CPX #k / BEQ ...`, with `T`/`R`/`Q` each
  tested in two charset-case forms) becomes: an F-key **range check**
  that computes the page index directly (`page = key - KEY_F1`), then a
  single **case-fold** (`AND #KEY_CASE_MASK`) feeding a 3-entry ladder
  for `T`/`R`/`Q`.
- `SELECTSYS` / `SELECTAPP` / `SELECTVMM` (three near-identical
  `LDA #n / STA CURRPAGE / LDA #1 / STA NEEDREDRAW / JMP EVENTLOOP`
  blocks) collapse into one parametrised path fed by the computed page
  index.
- A shared `MARKREDRAW` helper (`LDA #1 / STA NEEDREDRAW / RTS`) replaces
  the four inline `LDA #1 / STA NEEDREDRAW` copies (`START`, the page
  select, `TRYRUNVMMTEST`, `SETREDRAW`).
- `DISPATCHPAGE`: the trampoline mechanism is unchanged (sound,
  `AGENTS.md`-documented); the `ASL A` index step is documented against a
  new `PAGE_ROUTINE_ENTRY_SIZE = 2` constant, `.assert`-guarded in
  `dash_wrapper.s`.
- `dmain.s` new constants: `KERNAL_GETIN = $FFE4`, `KEY_F1 = $85`,
  `KEY_CASE_MASK = $DF`, `KEY_T = $54`, `KEY_R = $52`, `KEY_Q = $51`,
  `PAGE_ROUTINE_ENTRY_SIZE = 2` (the WP3-deferred key-code literals).

**Excluded (deferred, by design):**
- Any change to which keys do what, to page order, to the redraw model,
  or to the `$3400`/R6 relocation contract.
- `DVMMRUNTEST`'s own internal structure (`dvmm.s`) -- untouched.
- The frame / per-page renderer helpers (`DRAWFRAME`'s 7 row loops,
  `DAPPPRINTFLAGS`) -- WP5.
- A key->action jump table (user decision 2026-09-01: computed, no
  table -- smaller, idiomatic, avoids a second trampoline mechanism
  alongside `DISPATCHPAGE`'s).
- Anonymous labels (`:+`/`:-`) -- no CASM equivalent.
- `KERNAL_GETIN` is the only new `$FFxx` name; other fixed vectors stay
  literal.

## Scoping Decisions (user-confirmed 2026-09-01)

1. **Dispatch design: computed, no table.** F1/F3/F5 (`$85`-`$87`,
   consecutive) map to pages 0-2 by subtraction; `T`/`R`/`Q` are
   case-folded with `AND #$DF` (the shifted/lowercase-charset variant
   differs only in bit 5) then matched against 3 constants. No `.byte`
   key/handler tables.
2. **Runtime verification at WP4 close: agent VICE pass + recorded
   evidence.** Agent boots DASH at `$3400` and at one relocated base,
   exercises every binding (F1/F3/F5 nav, `R` redraw, `T` VMM test with
   REU present, `Q` exit), verifies via screen-RAM reads / screenshots,
   records it in the walkthrough. The exhaustive **user** hardware
   runtime matrix stays at WP6's consolidated gate (parent plan
   verification contract item 3).
3. **Also tidy `DISPATCHPAGE`:** add `PAGE_ROUTINE_ENTRY_SIZE` for the
   index step and `.assert` it; route `START`'s redraw through
   `MARKREDRAW`. The trampoline itself is not restructured.

## Behaviour-preservation analysis (the load-bearing part)

Every current input must produce the identical effect. Enumerated:

| Input (X from `GETIN`) | Current | After WP4 | Same? |
| --- | --- | --- | --- |
| `$85`/`$86`/`$87` (F1/F3/F5) | `BEQ SELECTSYS/APP/VMM` -> page 0/1/2 + redraw | in `[$85,$88)` -> `page = X-$85` -> select + redraw | yes -- 0/1/2 identical |
| `$54` (`T`) / `$74` (`t`) | `BEQ TRYRUNVMMTEST` (both) | not an F-key; `AND #$DF` -> `$54` == `KEY_T` -> `TRYRUNVMMTEST` | yes |
| `$52`/`$72` (`R`) | `BEQ SETREDRAW` | fold -> `$52` == `KEY_R` -> `SETREDRAW` | yes |
| `$51`/`$71` (`Q`) | `BEQ EXITAPP` | fold -> `$51` == `KEY_Q` -> `EXITAPP` | yes |
| `$00` (no key) | `BEQ EVENTLOOP` | unchanged | yes |
| `$88` (F7), `$84` (shift-F7), any other | falls to `JMP EVENTLOOP` (ignored) | F-key range fails; fold; no `T/R/Q` match; `JMP EVENTLOOP` | yes |
| `$D4` (shift-`T`), `$D2`, `$D1` | not matched -> ignored | `$D4 & $DF = $D4` != `$54` -> ignored | yes -- shift-letter never handled, before or after |

**Fold uniqueness proof:** `b AND $DF == $54` iff `b in {$54,$74}`;
likewise `$52 -> {$52,$72}`, `$51 -> {$51,$71}`. No third byte folds onto
a handled code, so no key gains a spurious action. (`$DF = ~$20`; bit 5
is the only case bit in play, matching the existing `$54`/`$74` pair.)

**Order independence:** a byte cannot be both in `[$85,$88)` and fold to
`$54`/`$52`/`$51`, so checking F-keys before letters (as now) vs. the new
split is immaterial.

**F-key range math:** after `CPX #KEY_F1` (BCC out) and
`CPX #(KEY_F1 + PAGECOUNT)` (BCS out), carry is **clear** and
`$85 <= X <= $87`; `SEC / SBC #KEY_F1` -> `A in {0,1,2}` = the exact page
index the three `LDA #n` blocks used. `PAGECOUNT` (3) is reused as the
range width -- if a 4th page is ever added to `PAGEROUTINETABLE`,
`PAGECOUNT` grows and F1..F7 extend automatically, and the
`dash_wrapper.s` `.assert (PAGEROUTINETABLE_END - PAGEROUTINETABLE) / 2 =
PAGECOUNT` still holds.

## Target shape (`dmain.s`, indicative)

```
START:
    CLD
    LDA #PAGE_SYS
    STA CURRPAGE
    JSR MARKREDRAW
    ; fall into EVENTLOOP

EVENTLOOP:
    LDA NEEDREDRAW
    BEQ POLLINPUT
    LDA #0
    STA NEEDREDRAW
    JSR DISPATCHPAGE

POLLINPUT:
    JSR KERNAL_GETIN
    TAX
    BEQ EVENTLOOP

    CPX #KEY_F1                    ; F1/F3/F5 = $85/$86/$87 -> PAGE 0/1/2
    BCC @NOTPAGEKEY
    CPX #(KEY_F1 + PAGECOUNT)
    BCS @NOTPAGEKEY
    TXA
    SEC
    SBC #KEY_F1
    STA CURRPAGE
    JSR MARKREDRAW
    JMP EVENTLOOP
@NOTPAGEKEY:
    TXA
    AND #KEY_CASE_MASK            ; FOLD SHIFTED/LOWERCASE-CHARSET LETTER VARIANT
    TAX
    CPX #KEY_T
    BEQ TRYRUNVMMTEST
    CPX #KEY_R
    BEQ SETREDRAW
    CPX #KEY_Q
    BEQ EXITAPP
    JMP EVENTLOOP

MARKREDRAW:
    LDA #1
    STA NEEDREDRAW
    RTS

TRYRUNVMMTEST:
    LDA CURRPAGE
    CMP #PAGE_VMM
    BNE @IGNORE
    JSR DVMMRUNTEST
    JSR MARKREDRAW
@IGNORE:
    JMP EVENTLOOP

SETREDRAW:
    JSR MARKREDRAW
    JMP EVENTLOOP

EXITAPP:
    LDA #DOS_EXIT
    JSR OS_API
    RTS

DISPATCHPAGE:
    LDA CURRPAGE
    CMP #PAGECOUNT
    BCC @PAGEVALID
    LDA #PAGE_SYS
    STA CURRPAGE
@PAGEVALID:
    LDA CURRPAGE
    ASL A                         ; INDEX *= PAGE_ROUTINE_ENTRY_SIZE (2)
    TAY
    ... (trampoline body unchanged) ...
```

Whether a tiny `SELECTPAGE` (`STA CURRPAGE` then fall into `MARKREDRAW`)
is worth its one caller is the implementer's call at inc 2 -- default is
inline as shown.

## `dash_wrapper.s` -- new `.assert`s (ca65-only)

Appended to the WP3 invariant block:
```
.assert PAGE_ROUTINE_ENTRY_SIZE = 2, error, "ASL A assumes entry size 2"
.assert KEY_F1 + PAGECOUNT <= $88, error, "F-key page range overruns F7"
.assert (KEY_T & KEY_CASE_MASK) = KEY_T, error, "KEY_T not case-folded form"
.assert (KEY_R & KEY_CASE_MASK) = KEY_R, error, "KEY_R"
.assert (KEY_Q & KEY_CASE_MASK) = KEY_Q, error, "KEY_Q"
```

## Atomic Increments

1. **Constants only.** Add `KERNAL_GETIN`, `KEY_F1`, `KEY_CASE_MASK`,
   `KEY_T/R/Q`, `PAGE_ROUTINE_ENTRY_SIZE` to `dmain.s`'s prologue; add
   the 5 `.assert`s to `dash_wrapper.s`. No code change.
   `check_casm_source_bytes` clean; `cmake --build build --target
   dash_ref` byte-identical to the **post-WP3** manifest (`3238b786...`),
   every `.assert` passes.
2. **`MARKREDRAW` + `START`/`SETREDRAW`/`TRYRUNVMMTEST` routed through
   it; `SELECT*` collapsed; `DISPATCHPAGE` `ASL A` comment.** Keep the
   F-key ladder explicit for now (three `CPX #$85/#$86/#$87` -> one
   computed select). **Bytes change.** `dash_ref` (ca65) builds;
   `reloc.py` clean; record the new size + relocation-entry count.
3. **Key ladder fold.** F-key range check + `AND #KEY_CASE_MASK` for
   `T`/`R`/`Q`. **Bytes change.** `dash_ref` builds; `reloc.py` clean.
4. **Native CASM byte-identity + re-baseline.** `rm
   build/command64_casm_utils.d64`, rebuild it, `CASM DMAIN.S /O:DW3.PRG`
   under VICE -> `INPUT VALIDATED`; `COMP DW3.PRG DASH.REF` -> `FILES
   COMPARE OK`. Extract `DW3.PRG`; `cmp` against `build/dash_ref.prg` ->
   **byte-identical** (they will NOT match the old `3238b786` manifest --
   that is expected and is the whole point of this WP).
   `build_dash_manifest.py <native DW3.PRG> --cross-check
   build/dash_ref.prg` -> **new bytes, new sha256**, `cross-check
   MATCHES`, fresh source hashes, **no `--allow-host-bytes`**. `dash` +
   full `cmake --build build` + `image_d64` clean.
5. **Agent runtime pass (both bases).** Boot Command64 (`image.d64` u8),
   run `dash` from the shell at its `$3400` base; then repeat with DASH
   relocated to one alternate base (per `AGENTS.md`'s relocation test,
   e.g. `$5000`). For each: System / Applications / VMM Test pages all
   render (screen-RAM row decode), F1/F3/F5 switch pages, `R` triggers a
   redraw, `T` on the VMM page runs the test to a terminal state (REU
   present), `Q` returns to the `c64[...]:>` prompt. Record every check
   in the walkthrough. Fire `c64-overlay-api` `test` events.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/dash/dmain.s` | Modify -- constants + event-loop/key/select refactor |
| `src/external/dash/dash_wrapper.s` | Modify -- 5 new ca65-only `.assert`s |
| `src/external/dash/dash.ref.hex` | **Re-baseline** -- new byte payload + new sha256 + fresh source hashes |
| `src/external/dash/BUILD_DASH_REF` | Auto |
| `src/external/dash/AGENTS.md` | Modify -- 1-2 lines: key dispatch is now computed (F-key range + case fold), `MARKREDRAW`. Full rewrite still WP6. |
| `brain/walkthroughs/2026-09-0X-dash-mod-wp4-event-loop-dispatch-refactor.md` | Create |
| `brain/plans/2026-09-01-dash-modernization.md` | Append Progress |
| `wiki/tasks/dash-modernization.md` | Tick WP4 |

## Stop Conditions

- ca65 `dash_ref.prg` and native CASM `DASH.PRG` are not byte-identical
  to **each other** after any increment.
- `tools/reloc.py` fails, or the ca65-derived and CASM-derived relocation
  entry sets diverge (the non-circular cross-check -- `AGENTS.md`
  Verification section).
- Any observable behaviour change in the runtime pass: a key binding
  stops working or does the wrong thing, a page fails to render or
  renders the wrong page, `R` does not redraw, `T` does not launch the
  VMM test on the VMM page (or launches it off it), `Q` does not exit.
- The output **grew** without a clear, stated reason (a duplication
  collapse should shrink or hold size).
- `build_dash_manifest.py` would need `--allow-host-bytes`.
- `check_casm_source_bytes.py` rejects `dmain.s`.
- A construct outside the dual-assembler subset is needed (none expected;
  `AND #imm`, `SBC #imm`, `CPX #imm` and `#(a + b)` operand arithmetic
  are all already proven).
- A genuinely new defect outside WP4's scope is found -> disclose and
  defer as a separate follow-up (do not fix inline), unless the user
  directs otherwise in the moment.

## Documentation, Task, and Tracker Updates

- **At approval:** Taskwarrior WP4 (child of `94ec17b3`).
- **At completion:** walkthrough (behaviour table + runtime evidence at
  both bases + before/after size and relocation-entry count); parent plan
  Progress; `wiki/tasks/dash-modernization.md` tick; 1-2 line `AGENTS.md`
  update. `CHANGELOG` / DASH version bump remain at WP6.

## Completion Gate

- `dmain.s` event loop / key dispatch / page select refactored; every
  deferred item (renderer helpers, jump table, anonymous labels)
  explicitly listed as deferred.
- **Behaviourally identical:** the agent runtime pass at `$3400` **and**
  at one relocated base shows all three pages rendering, F1/F3/F5
  navigation, `R` redraw, `T` VMM test (REU present), `Q` exit -- with
  screen-RAM / screenshot evidence in the walkthrough. (The exhaustive
  user hardware runtime matrix is WP6.)
- ca65 `dash_ref` == native CASM `DASH.PRG`, byte-for-byte; `reloc.py`
  clean; relocation-entry count recorded (old: 465).
- `dash.ref.hex` re-baselined: **new** bytes + **new** sha256, updated
  `source_sha256`, `--cross-check MATCHES`, no `--allow-host-bytes`. The
  walkthrough states the old and new sha256 and byte size explicitly.
- `dash_wrapper.s` `.assert` block (WP3's 16 + WP4's 5) all pass.
- `dash` + `dash_ref` + `command64_casm_utils_d64` + `image_d64` + full
  `cmake --build build` clean.
- Walkthrough with live evidence; trackers synced; explicit user
  approval.

## Progress

- 2026-09-01: Drafted for review. Scoping decisions 1-3 captured
  (computed dispatch no table; agent runtime pass at WP4 + user matrix at
  WP6; tidy `DISPATCHPAGE`). Full behaviour-preservation table built from
  the current `dmain.s`.
- 2026-09-01: **Approved.** Taskwarrior task 53. Pre-WP4 bytes snapshot
  (`3238b786...`, 4766 bytes) taken.
- 2026-09-01: **Increment 1 complete.** `dmain.s` prologue +7 constants
  (`PAGE_ROUTINE_ENTRY_SIZE`, `KERNAL_GETIN`, `KEY_F1`, `KEY_CASE_MASK`,
  `KEY_T/R/Q`). `dash_wrapper.s` +5 `.assert`s. ca65 `dash_ref`
  byte-identical to the post-WP3 manifest (constants unused), all 21
  asserts pass, 465 relocation points unchanged.
- 2026-09-01: **Increments 2+3 done together (one coherent rewrite).**
  Splitting the event-loop region into a partial intermediate then a full
  rewrite would have written it twice for no extra verification (both
  only get a ca65 check; native is inc 4). One diff is easier to review
  against the behaviour table. `dmain.s` `START`..`DISPATCHPAGE`:
  `MARKREDRAW` helper (5 call sites: START, F-key select, `TRYRUNVMMTEST`,
  `SETREDRAW`); `SELECTSYS/APP/VMM` deleted -> F-key range check
  (`CPX #KEY_F1` / `CPX #(KEY_F1 + PAGECOUNT)`) + `SBC #KEY_F1` computes
  the page; `T/R/Q` double-compares -> `AND #KEY_CASE_MASK` fold + 3
  compares; `JSR $FFE4` -> `JSR KERNAL_GETIN`; `TRYRUNVMMTEST` `CMP #2`
  -> `CMP #PAGE_VMM` with a `@IGNORE` local; `DISPATCHPAGE` `ASL A`
  comment. ca65 `dash_ref` builds clean, **all 21 `.assert`s pass**,
  `reloc.py` clean. Size 3828 -> **3787 code bytes** (-41), relocation
  points 465 -> **459** (-6) -- the expected shrink from the collapse.
  `check_casm_source_bytes` clean.
