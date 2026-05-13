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
ABSBUILD := $(abspath $(BUILD))

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
	$(JAVA) -jar $(KICKASS) $(CMD64_ENTRY) -odir $(ABSBUILD)

# debug utility
$(BUILD)/debug.prg: $(DEBUG_SRCS) | $(BUILD)
	$(JAVA) -jar $(KICKASS) $(DEBUG_ENTRY) -odir $(ABSBUILD)

# test PRGs — pattern rule, one per tests/src/*.asm
$(BUILD)/tests/%.prg: tests/src/%.asm $(wildcard include/*.inc) | $(BUILD)/tests
	$(JAVA) -jar $(KICKASS) $< -odir $(ABSBUILD)/tests

# Oscar64 C sources — pattern rule, inert until a .c file exists
$(BUILD)/%.prg: src/%.c | $(BUILD)
	$(OSCAR64) -o $@ $<

# ---------------------------------------------------------------------------
# Disk images
# ---------------------------------------------------------------------------

# Release image — rm -f ensures cc1541 starts fresh, not appending to stale image
$(BUILD)/image.d64: $(IMAGE_PRGS)
	rm -f $@
	$(CC1541) -n "$(DISK_NAME)" -i "$(DISK_ID)" \
	    $(foreach prg,$^,-f "$(notdir $(basename $(prg)))" -w $(prg)) $@

# Test image
$(BUILD)/test.d64: $(TEST_IMAGE_PRGS)
	rm -f $@
	$(CC1541) -n "$(DISK_NAME)" -i "$(DISK_ID)" \
	    $(foreach prg,$^,-f "$(notdir $(basename $(prg)))" -w $(prg)) $@

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
