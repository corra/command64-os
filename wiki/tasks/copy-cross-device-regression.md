# Cross-Device COPY Regression

## Goal

Restore reliable cross-device file copying and prevent failed transfers from
leaving apparently successful truncated destination files.

## Status

- [x] Reproduce `copy banner.s 8:banner.s` with device 9 active.
- [x] Confirm the destination is truncated with `comp banner.s 8:banner.s`.
- [x] Compare relevant OS changes on the incomplete DASH branch.
- [x] Isolate and correct the cross-device channel failure.
- [x] Report read and write failures instead of treating them as EOF.
- [x] Remove an incomplete destination after a transfer failure.
- [x] Verify a multi-block, non-64-byte-aligned file.
- [x] Build the OS and disk images with zero warnings and errors.
- [x] Verify the two-drive copy in VICE and compare extracted bytes.
- [x] Obtain user confirmation before marking this task complete.

## Acceptance Criteria

- With device 9 active, `copy banner.s 8:banner.s` returns to `c64[9]:>`.
- Extracted source and destination payloads match exactly. Cross-device
  `COMP` is tracked separately because its second `fileOpen` invalidates its
  first stream through the same LFN 15 interaction.
- The copied file retains the source file type.
- Read or write failure is reported and does not leave a truncated destination.
- Existing same-device `COPY`, `TYPE`, and file API behavior remains intact.

## Verification Evidence

- Source and destination: 11,278 bytes, closed 45-block SEQ files.
- SHA-256: `354ee8041ed5a141ba0ed396cd5b4dc865f6063400adc4f43ac05ec8c64de398`.
- VICE returned to `c64[9]:>` after `copy banner.s 8:banner.s`.
- User confirmed the copied file compares successfully after a same-device
  copy to `banner2.s` on device 8.
