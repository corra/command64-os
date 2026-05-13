# Unified Build System Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:writing-plans to implement this spec task-by-task.

**Goal:** Replace the current manual `java -jar` invocations and ad-hoc bash scripts with a single GNU Make build system that compiles all targets, packages disk images, and produces versioned release archives — with full dependency tracking so only dirty targets rebuild.

**Architecture:** A flat single `Makefile` at the repo root drives the entire pipeline. KickAssembler (Java) assembles all `.asm` sources; Oscar64 compiles any future `.c` sources; cc1541 packages D64 disk images. All intermediate and final artifacts land under `build/` (gitignored). A separate `release/` directory (git-tracked) holds intentional release snapshots.

**Tech Stack:** GNU Make, KickAssembler v5.25 (Java JAR), Oscar64 (C compiler), cc1541 (D64 tool), zip, tar

---

## 1. Repository Restructure

The restructure must be committed separately from the Makefile addition so that `git log --follow` and `git blame` remain reliable on every moved file.

### 1.1 File Moves (use `git mv` — history preserved)

| From | To |
|---|---|
| `build/command64.asm` | `src/command64.asm` |

`src/command64.asm` is the KickAssembler entry point / segment manifest for the OS. It does not belong in `build/` which becomes an artifact-only directory.

### 1.2 Import Paths Updated in `src/command64.asm`

After the move the relative paths to imported files change:

| Old path | New path |
|---|---|
| `../include/command64.inc` | `../include/command64.inc` (unchanged) |
| `../src/command64/petsci.asm` | `command64/petsci.asm` |
| `../src/command64/api.asm` | `command64/api.asm` |
| `../src/command64/utils.asm` | `command64/utils.asm` |
| `../src/command64/loader.asm` | `command64/loader.asm` |
| `../src/command64/path.asm` | `command64/path.asm` |
| `../src/command64/vmm.asm` | `command64/vmm.asm` |
| `../src/command64/file.asm` | `command64/file.asm` |
| `../src/command64/shell.asm` | `command64/shell.asm` |

### 1.3 Files Removed from Git Tracking

These become build artifacts. Remove with `git rm --cached` and add to `.gitignore`.
Run `git ls-files tests/bin/ src/external/debug/build/` first to confirm which are actually tracked before issuing `git rm --cached`:

| Path | Reason |
|---|---|
| `build/command64.prg` | artifact — produced by Make |
| `tests/image.d64` | artifact — produced by `make testimage` |
| `tests/testcmds.d64` | artifact — produced by Make |
| `tests/bin/*.prg` | artifacts — produced by `make test` (verify tracked status first) |
| `src/external/debug/build/` | artifact dir — produced by Make (verify tracked status first) |

### 1.4 Files Deleted (superseded)

| Path | Replaced by |
|---|---|
| `tests/build_tests.sh` | `make test` |
| `tools/create_d64.py` | cc1541 invocation in Makefile |

### 1.5 `.gitignore` Additions

```gitignore
# Build artifacts
build/
tests/bin/
tests/*.d64
image.d64
src/external/debug/build/

# Release directory is intentionally tracked — do NOT add release/ here
```

### 1.6 Commit Strategy

Two commits, in order:

1. `refactor: restructure repository layout for unified build system`
   — `git mv`, `git rm --cached`, `.gitignore` update, import path fixes. No logic changes.

2. `feat: add GNU Make unified build system`
   — `Makefile` and `VERSION` file only.

---

## 2. Directory Layout (post-restructure)

```
/
├── Makefile                        ← NEW: unified build system
├── VERSION                         ← NEW: project-level version (e.g. "0.2.21")
├── include/
│   ├── command64.inc
│   └── vmm.inc
├── src/
│   ├── command64.asm               ← MOVED from build/command64.asm
│   ├── command64/
│   │   ├── api.asm
│   │   ├── file.asm
│   │   ├── loader.asm
│   │   ├── path.asm
│   │   ├── petsci.asm
│   │   ├── shell.asm
│   │   ├── utils.asm
│   │   └── vmm.asm
│   └── external/
│       └── debug/
│           └── debug.asm
├── tests/
│   └── src/
│       ├── hello.asm
│       ├── color.asm
│       ├── apitest.asm
│       ├── vmmtest.asm
│       ├── filetest.asm
│       └── extcls.asm
├── tools/
│   ├── KickAss.jar
│   ├── cc1541
│   ├── oscar64/
│   └── python3_env/
├── build/                          ← gitignored, all intermediate artifacts
│   ├── command64.prg
│   ├── debug.prg
│   ├── tests/
│   │   ├── hello.prg
│   │   ├── color.prg
│   │   └── ...
│   ├── image.d64
│   └── test.d64
└── release/                        ← git-tracked, intentional releases only
    ├── command64.prg
    ├── debug.prg
    ├── image.d64
    ├── test.d64
    ├── ms-dos-c64-0.2.21.zip
    └── ms-dos-c64-0.2.21.tar.gz
```

---

## 3. Makefile Design

### 3.1 User Interface

| Command | What it does |
|---|---|
| `make` / `make all` | Build release image + test image (full pipeline) |
| `make image` | Release image only (`build/image.d64`) |
| `make testimage` | Test image (`build/test.d64`) — includes test PRGs |
| `make test` | Compile test PRGs only (no image) |
| `make release` | Build both images, copy to `release/`, create archives |
| `make clean` | `rm -rf build/` — complete artifact reset |
| `make build/command64.prg` | Assemble OS only |
| `make build/debug.prg` | Assemble debug utility only |
| `make build/tests/hello.prg` | Assemble a single test PRG |

`make release` is **not** a dependency of `make all` — it must be invoked explicitly.

### 3.2 Dependency Graph

```
build/image.d64
  ├── build/command64.prg
  │     ├── src/command64.asm          (entry/segment manifest)
  │     ├── src/command64/*.asm        (all OS modules)
  │     └── include/*.inc
  ├── build/debug.prg
  │     ├── src/external/debug/debug.asm
  │     └── include/*.inc
  └── build/%.prg  [Oscar64, inert until .c files exist]
        └── src/%.c

build/test.d64
  ├── (everything in build/image.d64)
  └── build/tests/*.prg
        └── tests/src/*.asm
```

Key rebuild behaviours:
- Touch `src/command64/shell.asm` → `command64.prg` rebuilds, then both images
- Touch `debug.asm` → `debug.prg` rebuilds, then both images
- Touch `include/command64.inc` → both `command64.prg` and `debug.prg` rebuild
- Add `src/foo.c` → `build/foo.prg` appears automatically, is added to release image

### 3.3 Full Makefile

```makefile
# MS-DOS C64 Port — Unified Build System
# Usage:
#   make            — build release image + test image
#   make image      — release image only (build/image.d64)
#   make testimage  — test image with test PRGs (build/test.d64)
#   make test       — compile test PRGs only
#   make release    — package versioned release artifacts (intentional only)
#   make clean      — remove all build artifacts

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------
JAVA    := java
KICKASS := tools/KickAss.jar
OSCAR64 := tools/oscar64/bin/oscar64
CC1541  := tools/cc1541
BUILD   := build

# ---------------------------------------------------------------------------
# Disk image metadata
# ---------------------------------------------------------------------------
DISK_NAME := ms-dos 64
DISK_ID   := 2a

# ---------------------------------------------------------------------------
# Source discovery
# ---------------------------------------------------------------------------

# command64 OS — entry point passed to KickAssembler; sources tracked for deps
CMD64_ENTRY := src/command64.asm
CMD64_SRCS  := $(wildcard src/command64/*.asm) $(wildcard include/*.inc)

# debug utility
DEBUG_ENTRY := src/external/debug/debug.asm
DEBUG_SRCS  := $(DEBUG_ENTRY) $(wildcard include/*.inc)

# Test PRGs — one per .asm file
TEST_SRCS := $(wildcard tests/src/*.asm)
TEST_PRGS := $(TEST_SRCS:tests/src/%.asm=$(BUILD)/tests/%.prg)

# Oscar64 C sources — auto-discovered, inert until a .c file exists
C_SRCS := $(wildcard src/*.c src/**/*.c)
C_PRGS := $(patsubst src/%.c,$(BUILD)/%.prg,$(C_SRCS))

# PRGs that go on the release disk image (OS + utilities, no tests)
IMAGE_PRGS := $(BUILD)/command64.prg $(BUILD)/debug.prg $(C_PRGS)

# PRGs that go on the test disk image (everything)
TEST_IMAGE_PRGS := $(IMAGE_PRGS) $(TEST_PRGS)

# ---------------------------------------------------------------------------
# Release
# ---------------------------------------------------------------------------
VERSION      := $(shell cat VERSION)
RELEASE_DIR  := release
RELEASE_NAME := ms-dos-c64-$(VERSION)

# ---------------------------------------------------------------------------
# Phony targets
# ---------------------------------------------------------------------------
.PHONY: all image testimage test release clean

all: image testimage

image: $(BUILD)/image.d64

testimage: $(TEST_PRGS) $(BUILD)/test.d64

test: $(TEST_PRGS)

clean:
	rm -rf $(BUILD)

# ---------------------------------------------------------------------------
# Directory creation (order-only prerequisites)
# ---------------------------------------------------------------------------
$(BUILD) $(BUILD)/tests:
	mkdir -p $@

# ---------------------------------------------------------------------------
# Build rules
# ---------------------------------------------------------------------------

# command64 OS
$(BUILD)/command64.prg: $(CMD64_ENTRY) $(CMD64_SRCS) | $(BUILD)
	$(JAVA) -jar $(KICKASS) $(CMD64_ENTRY) -odir $(BUILD)

# debug utility
$(BUILD)/debug.prg: $(DEBUG_SRCS) | $(BUILD)
	$(JAVA) -jar $(KICKASS) $(DEBUG_ENTRY) -odir $(BUILD)

# test PRGs — pattern rule
$(BUILD)/tests/%.prg: tests/src/%.asm $(wildcard include/*.inc) | $(BUILD)/tests
	$(JAVA) -jar $(KICKASS) $< -odir $(BUILD)/tests

# Oscar64 C sources — pattern rule, inert until a .c file exists
$(BUILD)/%.prg: src/%.c | $(BUILD)
	$(OSCAR64) -o $@ $<

# ---------------------------------------------------------------------------
# Disk images
# ---------------------------------------------------------------------------

# Release image (OS + utilities)
# rm -f $@ ensures cc1541 creates a fresh image rather than appending to a stale one
$(BUILD)/image.d64: $(IMAGE_PRGS)
	rm -f $@
	$(CC1541) -n "$(DISK_NAME)" -i "$(DISK_ID)" $@ \
	    $(foreach prg,$^,-f "$(notdir $(basename $(prg)))" -w $(prg))

# Test image (OS + utilities + test PRGs)
$(BUILD)/test.d64: $(TEST_IMAGE_PRGS)
	rm -f $@
	$(CC1541) -n "$(DISK_NAME)" -i "$(DISK_ID)" $@ \
	    $(foreach prg,$^,-f "$(notdir $(basename $(prg)))" -w $(prg))

# ---------------------------------------------------------------------------
# Release (intentional only — not part of `make all`)
# ---------------------------------------------------------------------------
release: $(BUILD)/image.d64 $(BUILD)/test.d64
	mkdir -p $(RELEASE_DIR)
	cp $(IMAGE_PRGS) $(RELEASE_DIR)/
	cp $(BUILD)/image.d64 $(BUILD)/test.d64 $(RELEASE_DIR)/
	cd $(RELEASE_DIR) && zip -r $(RELEASE_NAME).zip \
	    $(notdir $(IMAGE_PRGS)) image.d64 test.d64
	cd $(RELEASE_DIR) && tar -czf $(RELEASE_NAME).tar.gz \
	    $(notdir $(IMAGE_PRGS)) image.d64 test.d64
	@echo "Release $(VERSION) ready in $(RELEASE_DIR)/"
```

---

## 4. External Application Versioning Convention

Every program under `src/external/` must define four constants at the top of its entry `.asm` file:

```asm
.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "1"
.const BUILD_NUMBER  = "1000"
```

Rules:
- **Required** for all external applications, regardless of whether the version is user-visible
- **User-visibility** is the application's choice — `debug` prints it at startup; a background utility may not expose it at all
- **Independent numbering** — each application's version is tracked separately from the OS and from other applications
- **Test programs** under `tests/src/` are exempt — they are QA utilities, not shipped applications
- **Increment `BUILD_NUMBER`** before any build that includes code changes (existing project convention)

The project-level `VERSION` file tracks the OS release version and names release archives. It is separate from all application version constants.

---

## 5. `VERSION` File

A plain text file at the repo root containing the current project version:

```
0.2.21
```

Updated manually before running `make release`. Committed as part of the release commit.

---

## 6. Release Workflow

The intended workflow for cutting a release:

```bash
# 1. Ensure everything is clean and committed
git status

# 2. Update VERSION file
echo "0.2.22" > VERSION
git add VERSION && git commit -m "chore: bump version to 0.2.22"

# 3. Build and package
make release

# 4. Commit release artifacts
git add release/
git commit -m "release: v0.2.22"
```

`make release` is never run as part of `make all` — it requires deliberate invocation. Old release archives accumulate in `release/` and are all tracked in git, providing a full release history.
