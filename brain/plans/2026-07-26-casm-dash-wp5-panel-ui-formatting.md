---
feature: casm-dash-wp5-panel-ui-formatting
created: 2026-07-26
updated: 2026-07-30
status: complete
---

# Plan: DASH WP5 - Panel UI and Formatting

## Objective

Replace WP4 placeholders with a bounded 40x25 panel framework, active tabs,
status bar, direct screen/color rendering, hexadecimal formatting, and bounded
16-bit decimal formatting. WP5 provides page-neutral services for WP6-WP8.

Prerequisite: WP4 explicitly approved complete.

## Mandatory Activation Review

Re-read WP4 source/ABI, actual screen mode/charset, command size, CASM syntax,
memory map, and page requirements. Any material discrepancy affecting screen
geometry, encoding, routine contracts, memory writes, formatting, relocation,
or downstream capacity stops work, requires a plan amendment, and requires
renewed approval.

## Geometry to Freeze

Recommended rows:

| Rows | Purpose |
| --- | --- |
| 0 | Top frame |
| 1 | Title |
| 2 | Tabs |
| 3 | Header separator |
| 4-21 | 18-row content area |
| 22 | Content separator |
| 23 | Status/controls |
| 24 | Bottom frame |

This preserves one table header plus 16 application rows. Freeze exact border
characters, charset, active/inactive colors, content columns, and overflow
policy before coding.

## Expected Files

- `src/external/dash/dscr.s`
- `src/external/dash/dfmt.s`
- `src/external/dash/ddata.s`
- `src/external/dash/dmain.s`
- DASH-local DOX only if routine/encoding contracts change

## Rendering Contract

- Directly write screen RAM `$0400-$07E7` and color RAM `$D800-$DBE7`.
- Never write cells 1000 or greater.
- Store direct-display literals as explicit screen-code bytes with readable
  comments; do not confuse PETSCII with screen code.
- Use fixed numeric row-address tables; they are hardware addresses and must
  not become relocation entries.
- Full redraw occurs only on page change, `R`, or a completed VMM state change.

Planned primitives:

```text
screenClear       fill exactly 1000 screen/color cells
screenSetCursor   validate column 0-39 and row 0-24
screenPutChar     bounded one-cell write and advance
screenPutString   bounded row write under frozen length/terminator policy
drawFrame         static panel, tabs, separators, and controls
```

Every public DASH routine documents inputs, outputs, C/Z behavior,
preservation, scratch, and clobbers.

## Formatting Contract

```text
formatHex8   -> exactly two uppercase screen-code digits
formatHex16  -> exactly four uppercase screen-code digits
formatDec16  -> right-aligned 1-5 digit unsigned field
```

- Use a five-byte application-RAM formatting buffer.
- `formatDec16` uses bounded 16-bit division by 10, not unbounded subtraction.
- Freeze narrow-field behavior: recommended C set and caller-rendered `N/A` or
  `####`, never silent high-digit loss.
- Test 0, 9, 10, 255, 256, 4095, 4096, and 65535.

## Failure Handling

- Invalid coordinate performs no write and returns C set.
- Overlong text follows one frozen reject/truncate policy and cannot cross a
  row.
- Formatting overflow returns a visible bounded marker.
- Corrupt page state resets to System.
- Rendering failures preserve navigation and clean exit.

## Atomic Increments

1. Freeze geometry, charset, colors, string representation, and overflow
   behavior.
2. Implement exact 1000-cell clear and bounded cursor.
3. Implement character/string writes with boundary tests.
4. Draw frame, title, tabs, separators, and controls.
5. Implement active-tab highlighting.
6. Implement and verify hex formatters.
7. Implement and verify decimal formatter.
8. Integrate input-driven redraw and run relocation regression.

## Verification

- Static calculation proves all row widths `<=40` and content widths fit the
  interior.
- Clear loops write exactly `$0400-$07E7` and `$D800-$DBE7`.
- Invalid coordinate/length guards prevent any adjacent-memory write.
- Formatting vectors match expected screen text.
- Applications page retains 17 required rows.
- R6 growth is explained by local pointers only; fixed screen/color rows do
  not appear in relocation records.
- At `$3800/$5000/$9000`, user confirms frame alignment, active tabs, bounded
  placeholder content, refresh behavior, and clean Q exit.
- Behavior matches with and without REU.

## Stop Conditions

- Geometry cannot fit 16 app rows.
- Charset or PETSCII/screen-code policy is ambiguous.
- A write can reach `$07E8+` or `$DBE8+`.
- Formatting needs unsupported CASM syntax.
- UI changes break WP4 dispatch/stack behavior.
- Fixed row addresses gain relocation entries.
- Runtime differs by load address.

## Completion Gate

Present geometry, encoding, formatter vectors, boundary proof, R6 delta, and
user visual results at all three addresses. Ask whether WP5 is complete before
WP6 activation.

## Completion Note (2026-07-30)

Approved complete. `dash_ref` (ca65 cross-check) builds clean: base `$3400`,
1151 code bytes, 90 relocation points, linked one page apart for the reloc
diff. `CLEARSCREEN` writes exactly 1000 cells; cursor/string primitives
reject/clamp out-of-range coordinates and row-crossing writes; hex/decimal
formatters use bounded nibble extraction and 16-iteration binary division.

Accepted variance from the Geometry table above: the implementation draws
rows 0-23 only (top/title/tabs/header-separator, middle frame 4-20, a second
border@21, status@22, bottom border@23); physical row 24 is never written and
stays blank. This is one row short of the frozen "4-21 content / 22 separator
/ 23 status / 24 bottom" table, but the content area is still exactly 17 rows
(4-20), which satisfies this plan's own Verification requirement ("Applications
page retains 17 required rows" for 1 header + 16 app rows). Left as-is rather
than reworked to consume all 25 rows.
