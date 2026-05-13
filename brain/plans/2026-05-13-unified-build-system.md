# Unified Build System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace manual `java -jar` build invocations with a GNU Make pipeline that compiles all targets, packages dual D64 disk images, and produces versioned release archives with documentation.

**Architecture:** A repository restructure (Task 1–2) moves the KickAssembler entry-point manifest out of `build/` and cleans up tracked artifacts, committed separately to preserve `git log --follow`. The Makefile (Task 3–4) is then layered on top. Each task is independently verifiable — do not skip ahead.

**Tech Stack:** GNU Make, KickAssembler v5.25 (`tools/KickAss.jar`), cc1541 v4.2 (`tools/cc1541`), Oscar64 (`tools/oscar64/bin/oscar64`, future), zip, tar

---

## File Map

| Action | Path |
|---|---|
| Modify | `.gitignore` |
| Move (git mv) | `build/command64.asm` → `src/command64.asm` |
| Modify (paths) | `src/command64.asm` |
| Delete (git rm) | `tests/build_tests.sh` |
| Delete (git rm) | `tools/create_d64.py` |
| Untrack (git rm --cached) | `build/command64.prg` |
| Untrack (git rm --cached) | `tests/image.d64` |
| Untrack (git rm --cached) | `tests/testcmds.d64` |
| Create | `VERSION` |
| Create | `Makefile` |

---

## Task 1: Fix `.gitignore` and Untrack Build Artifacts

**Files:**
- Modify: `.gitignore`

The current `.gitignore` has `*.prg` (no leading slash) which matches anywhere in the tree — it would silently ignore `release/command64.prg` once the release directory is added. Fix it to use root-anchored patterns, then untrack the three build artifacts that are currently committed.

- [ ] **Step 1: Verify what is currently tracked**

Run:
```bash
git ls-files build/command64.prg tests/image.d64 tests/testcmds.d64
```
Expected output (all three lines):
```
build/command64.prg
tests/image.d64
tests/testcmds.d64
```

- [ ] **Step 2: Replace `.gitignore` contents**

Write `.gitignore`:
```gitignore
# Build artifacts (managed by Make)
build/
tests/bin/
tests/*.d64
src/external/debug/build/

# Stray root-level artifacts only (leading / anchors to repo root)
/image.d64
/*.prg
/*.sym

# Tools
tools/cc1541-git/

# OS-specific
.DS_Store
```

The leading `/` on `/*.prg` and `/*.sym` means only root-level `.prg`/`.sym` files are ignored — `release/command64.prg` and `build/command64.prg` are covered by `build/` and `release/` is unaffected.

- [ ] **Step 3: Untrack the three committed artifacts**

```bash
git rm --cached build/command64.prg tests/image.d64 tests/testcmds.d64
```
Expected:
```
rm 'build/command64.prg'
rm 'tests/image.d64'
rm 'tests/testcmds.d64'
```

- [ ] **Step 4: Verify git status**

```bash
git status
```
Expected: `.gitignore` shows as modified, the three files show as deleted (from index). They must NOT appear as untracked — the new `.gitignore` patterns must be suppressing them. If any appear as untracked, the `.gitignore` pattern is wrong.

- [ ] **Step 5: Commit**

```bash
git add .gitignore
git commit -m "chore: fix .gitignore and untrack build artifacts"
```

---

## Task 2: Move Entry Point and Remove Dead Files

**Files:**
- Move: `build/command64.asm` → `src/command64.asm`
- Modify import paths: `src/command64.asm`
- Delete: `tests/build_tests.sh`, `tools/create_d64.py`

`build/command64.asm` is the KickAssembler segment manifest / entry point for the OS. It does not belong in `build/` which becomes an artifact-only directory. `tests/build_tests.sh` and `tools/create_d64.py` are superseded by the Makefile.

**Background on KickAssembler imports:** KA resolves `#import` paths relative to the file containing the directive. `build/command64.asm` uses `../src/command64/` to reach the source modules. After the move to `src/command64.asm`, the same modules are now in the subdirectory `command64/` (no `../src/` prefix needed). The `../include/` path is unchanged — both `build/` and `src/` are one level below the repo root.

- [ ] **Step 1: Move the file with git mv**

```bash
git mv build/command64.asm src/command64.asm
```

- [ ] **Step 2: Update import paths in `src/command64.asm`**

Replace the file header comment and all `#import` lines. The complete updated file:

```asm
// src/command64.asm
// KickAssembler v5.25 - MS-DOS 4.0 shell for C64
//
// Segment layout:
//   Main          $0801  BASIC SYS launcher (BasicUpstart2)
//   Utils         $0C00  Hex parsing and string utilities
//   ApiStub       $1000  Stable OS Entry Point (Jump Table)
//   Petsci        $1040  PETSCII print routines
//   CommandTable  $1100  Fixed-width command dispatch table
//   CommandShell  $1200  Command loop, dispatcher, built-ins
//   Api           $1880  INT 21h Service Bus (Jump Table)
//   Loader        $1A00  KERNAL binary loader wrapper
//   Path          $1A80  Directory search and path logic
//   Vmm           $1B80  Virtual Memory Manager (REU mapping)
//   File          $1D80  Handle-based File I/O
//   VmmData       $1F90  VMM temporary storage

.file [name="command64.prg", segments="Main,ApiStub,Petsci,CommandTable,CommandShell,Api,Utils,Loader,Path,Vmm,File,VmmData"]

.segmentdef Main [start=$0801]
.segmentdef VmmData [start=$1F90]

// Petsci, CommandTable, CommandShell, Api, Utils, Loader, Path, Vmm, File, and VmmData are defined by the imported source files.

#import "../include/command64.inc"
#import "command64/petsci.asm"
#import "command64/api.asm"
#import "command64/utils.asm"
#import "command64/loader.asm"
#import "command64/path.asm"
#import "command64/vmm.asm"
#import "command64/file.asm"
#import "command64/shell.asm"


// BASIC SYS launcher: injects a BASIC line at $0801 that does SYS $1200
// 'start' is the entry-point label defined in shell.asm (CommandShell segment).
.segment Main
BasicUpstart2(start)
```

- [ ] **Step 3: Verify the entry point still assembles**

```bash
java -jar tools/KickAss.jar src/command64.asm -odir build/
```
Expected (last line):
```
Writing prg file: command64.prg
```
If KickAssembler reports any import errors, the path update in Step 2 is wrong — re-check that `command64/petsci.asm` resolves from `src/`.

- [ ] **Step 4: Remove dead files**

```bash
git rm tests/build_tests.sh tools/create_d64.py
```
Expected:
```
rm 'tests/build_tests.sh'
rm 'tools/create_d64.py'
```

- [ ] **Step 5: Commit**

```bash
git add src/command64.asm
git commit -m "refactor: restructure repository layout for unified build system"
```
This commit must contain only: the `git mv`, the import path fix, and the two deleted files. No Makefile yet.

---

## Task 3: Write the Makefile and VERSION File

**Files:**
- Create: `Makefile`
- Create: `VERSION`

This is the complete Makefile — all variables, rules, and targets written in one step. Verification follows rule-by-rule.

**Background on the Makefile mechanics:**
- `$(wildcard ...)` expands glob patterns at parse time — used for dependency tracking
- `| $(BUILD)` is an order-only prerequisite: the directory must exist before the recipe runs, but a newer directory timestamp does not trigger a rebuild
- `$(foreach prg,$^,...)` iterates over all prerequisites expanding the cc1541 `-f`/`-w` pair for each PRG
- `$(notdir $(basename $(prg)))` strips directory and extension: `build/command64.prg` → `command64`
- `rm -f $@` before cc1541 ensures a fresh D64 — cc1541 appends to existing images

- [ ] **Step 1: Create `VERSION`**

```bash
echo "0.2.21" > VERSION
```

- [ ] **Step 2: Create `Makefile`**

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

# PRGs on the release disk image (OS + utilities, no tests)
IMAGE_PRGS := $(BUILD)/command64.prg $(BUILD)/debug.prg $(C_PRGS)

# PRGs on the test disk image (everything)
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

# test PRGs — pattern rule, one per tests/src/*.asm
$(BUILD)/tests/%.prg: tests/src/%.asm $(wildcard include/*.inc) | $(BUILD)/tests
	$(JAVA) -jar $(KICKASS) $< -odir $(BUILD)/tests

# Oscar64 C sources — pattern rule, inert until a .c file exists
$(BUILD)/%.prg: src/%.c | $(BUILD)
	$(OSCAR64) -o $@ $<

# ---------------------------------------------------------------------------
# Disk images
# ---------------------------------------------------------------------------

# Release image — rm -f ensures cc1541 starts fresh, not appending to stale image
$(BUILD)/image.d64: $(IMAGE_PRGS)
	rm -f $@
	$(CC1541) -n "$(DISK_NAME)" -i "$(DISK_ID)" $@ \
	    $(foreach prg,$^,-f "$(notdir $(basename $(prg)))" -w $(prg))

# Test image
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
	cp -r docs/ $(RELEASE_DIR)/docs/
	rm -rf $(RELEASE_DIR)/docs/superpowers
	cd $(RELEASE_DIR) && zip -r $(RELEASE_NAME).zip \
	    $(notdir $(IMAGE_PRGS)) image.d64 test.d64 docs/
	cd $(RELEASE_DIR) && tar -czf $(RELEASE_NAME).tar.gz \
	    $(notdir $(IMAGE_PRGS)) image.d64 test.d64 docs/
	@echo "Release $(VERSION) ready in $(RELEASE_DIR)/"
```

**Important:** Makefile recipes must be indented with a real TAB character, not spaces. If copying this text, ensure your editor hasn't converted tabs to spaces.

- [ ] **Step 3: Verify `make build/command64.prg`**

```bash
make build/command64.prg
```
Expected (last line):
```
Writing prg file: command64.prg
```

- [ ] **Step 4: Verify `make build/debug.prg`**

```bash
make build/debug.prg
```
Expected (last line):
```
Writing prg file: debug.prg
```

- [ ] **Step 5: Verify `make test`**

```bash
make test
```
Expected: KickAssembler runs once per `tests/src/*.asm` file. Final output contains one `Writing prg file:` line per test source. Check `build/tests/` contains the PRGs:
```bash
ls build/tests/
```
Expected:
```
apitest.prg  color.prg  extcls.prg  filetest.prg  hello.prg  vmmtest.prg
```

- [ ] **Step 6: Verify `make image`**

```bash
make image
```
Expected: cc1541 runs and `build/image.d64` exists:
```bash
ls -lh build/image.d64
```
Expected: a file of approximately 170KB (174848 bytes).

- [ ] **Step 7: Verify `make testimage`**

```bash
make testimage
```
Expected: `build/test.d64` exists and is larger than (or equal to) `build/image.d64` — it contains the test PRGs in addition to the OS and debug utility.
```bash
ls -lh build/test.d64
```

- [ ] **Step 8: Verify dependency tracking**

Touch a source file and confirm only the affected target rebuilds:
```bash
touch src/command64/shell.asm
make image
```
Expected: Only `command64.prg` reassembles, then `image.d64` is rebuilt. `debug.prg` must NOT reassemble (no KickAssembler output for it).

- [ ] **Step 9: Verify `make clean`**

```bash
make clean
ls build/ 2>&1
```
Expected:
```
ls: cannot access 'build/': No such file or directory
```

- [ ] **Step 10: Verify full rebuild from clean**

```bash
make
```
Expected: All targets build in dependency order — `command64.prg`, `debug.prg`, test PRGs, `image.d64`, `test.d64`. No errors.

- [ ] **Step 11: Commit**

```bash
git add Makefile VERSION
git commit -m "feat: add GNU Make unified build system"
```

---

## Task 4: Verify and Commit the Release Target

**Files:**
- No new files — testing `make release` and committing its output

The release target is intentionally excluded from `make all`. This task verifies it end-to-end and produces the first committed release snapshot.

- [ ] **Step 1: Run `make release`**

```bash
make release
```
Expected final line:
```
Release 0.2.21 ready in release/
```

- [ ] **Step 2: Verify release directory contents**

```bash
ls release/
```
Expected:
```
command64.prg  debug.prg  docs/  image.d64  ms-dos-c64-0.2.21.tar.gz  ms-dos-c64-0.2.21.zip  test.d64
```

```bash
ls release/docs/
```
Expected (superpowers/ must NOT be present):
```
api-reference.md  apps/  pet-sci-api.md  programmers-reference.md  vmm-api.md
```

- [ ] **Step 3: Verify archive contents**

```bash
unzip -l release/ms-dos-c64-0.2.21.zip
```
Expected: lists `command64.prg`, `debug.prg`, `image.d64`, `test.d64`, and `docs/` tree. No `docs/superpowers/` entries.

- [ ] **Step 4: Commit the release artifacts**

```bash
git add VERSION release/
git commit -m "release: v0.2.21 — initial unified build system release"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Repo restructure: git mv, git rm --cached, .gitignore fix — Task 1–2
- [x] `make`, `make image`, `make testimage`, `make test`, `make clean` — Task 3
- [x] Dependency tracking verification — Task 3 Step 8
- [x] `make release` with archives and docs — Task 4
- [x] Oscar64 pattern rule — Task 3 Step 2 (Makefile)
- [x] External app versioning convention — documented in design spec; no Makefile change needed
- [x] cc1541 replaces create_d64.py — Task 2 Step 4 (deleted), Task 3 (cc1541 recipes)
- [x] `build/` consolidates all artifacts — Task 3
- [x] `release/` is git-tracked — Task 4

**Placeholder scan:** None found.

**Consistency:** `CMD64_ENTRY`, `DEBUG_ENTRY`, `IMAGE_PRGS`, `TEST_IMAGE_PRGS`, `RELEASE_DIR`, `RELEASE_NAME` — all defined in Task 3 Step 2 and used consistently throughout.
