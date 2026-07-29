# Cross-Device COMP Regression

## Goal

Make `COMP` reliably compare files opened on different IEC devices.

## Status

- [x] Reproduce `8:comp banner.s 8:banner.s` with device 9 active.
- [x] Confirm the compared disk payloads are byte-identical externally.
- [x] Identify LFN 15 switching during the second `fileOpen` as the stream
  invalidation mechanism.
- [ ] Design a public multi-file open contract that performs command-channel
  validation before opening final data channels.
- [ ] Update `COMP` to use that contract.
- [ ] Verify equal, different-content, and different-size files across devices.
- [ ] Obtain user confirmation before marking this task complete.

## Current Behavior

`COMP` reports `FILES ARE DIFFERENT SIZES` for byte-identical cross-device
files because opening its second file invalidates the first device's stream.
Same-device comparison succeeds.
