# DASH WP5 - Panel UI and Formatting Task

## Task Metadata
- **Feature**: `casm-dash-wp5-panel-ui-formatting`
- **Status**: Complete
- **Parent Plan**: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`
- **Plan File**: `brain/plans/2026-07-26-casm-dash-wp5-panel-ui-formatting.md`

## Objectives
1. Replace WP4 placeholders with a bounded 40x25 panel framework: exact
   1000-cell clear, bounded cursor/character/string writes, frame/tabs/
   status-bar rendering.
2. Implement active-tab highlighting driven by `CURRPAGE`.
3. Implement hex (`FORMATHEX8`/`FORMATHEX16`) and bounded 16-bit decimal
   (`FORMATDEC16`/`DIV10`) formatters into the shared `FMTBUF`.
4. Keep all of the above in the dual-assembler (native CASM / ca65) subset,
   and confirm R6 relocation is unaffected by the new fixed screen/color row
   tables.

## Sub-Tasks
- [x] Freeze geometry, screen-code charset, colors, string representation,
      and overflow policy.
- [x] Implement `CLEARSCREEN` (exactly 1000 screen/color cells, no write at
      or past cell 1000).
- [x] Implement `SCREENSETCURSOR`, `SCREENPUTCHAR`, `SCREENPUTSTRING` with
      out-of-range/row-crossing rejection.
- [x] Implement `DRAWFRAME` (borders, title, tabs, separators, status bar)
      and `HIGHLIGHTTABS`.
- [x] Implement `FORMATHEX8`, `FORMATHEX16`, `FORMATDEC16`/`DIV10`.
- [x] Build `dash_ref` (ca65 cross-check) and confirm clean relocation.

## Completion Note (2026-07-30)
Approved complete. `dash_ref` builds clean: base `$3400`, 1151 code bytes, 90
relocation points. `CLEARSCREEN` bounds, cursor/string bounds, and formatter
algorithms (bounded nibble extraction; 16-iteration binary division for
`DIV10`) verified by static inspection of `dscr.s`/`dfmt.s`.

Accepted variance: the implemented frame uses screen rows 0-23 only (row 24
is left blank) rather than the plan's frozen 0-24 table; the content area is
17 rows (4-20), which still satisfies this plan's own "17 required rows"
verification criterion for WP7's application table. See the parent plan file
for the full note.

Not independently re-verified in this pass (carried over as still-open from
WP4): the live "$3800/$5000/$9000, with/without REU" visual walkthrough, and
running the formatter test vectors (0, 9, 10, 255, 256, 4095, 4096, 65535) on
real/emulated hardware rather than by static code reading.
