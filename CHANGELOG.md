# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-05-08

### Added
- Improved shell parser robustness: leading spaces are now ignored, and empty lines (or lines containing only spaces) no longer trigger "Bad command" errors.
- Enhanced `cmdCompare` to support dynamic buffer offsets, allowing for more flexible command and argument parsing.
