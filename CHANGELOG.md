# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4] - 2026-05-08

### Fixed
- Fixed critical shell crashes and garbage output by relocating Zero Page variables to a safe, non-clobbered range ($22-$2D).
- Fixed unreliable file discovery by replacing the KERNAL `VERIFY` check with a robust `OPEN/CLOSE` pattern.
- Fixed potential buffer overlaps by further isolating segment and I/O buffer locations.
