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
DISK_NAME := Command 64
DISK_ID   := 2a

# ---------------------------------------------------------------------------
# Source discovery
# ---------------------------------------------------------------------------

# command64 OS — entry point passed to KickAssembler; sources tracked for deps
CMD64_ENTRY := src/command64.asm
CMD64_SRCS  := $(CMD64_ENTRY) $(wildcard src/command64/*.asm) $(wildcard include/*.inc)

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
VERSION      := $(shell cat VERSION 2>/dev/null)
RELEASE_DIR  := release
RELEASE_NAME := command64-os-$(VERSION)

# Build number automation
BUILD_OS_FILE := BUILD_OS
BUILD_DEBUG_FILE := BUILD_DEBUG
BUILD_OS_INC := $(BUILD)/build_os.inc
BUILD_DEBUG_INC := $(BUILD)/build_debug.inc

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

# Dynamic build number generation
# We only increment the persistent file if sources are newer than it.
$(BUILD_OS_FILE): $(CMD64_SRCS)
	@OLD=$$(cat $@ 2>/dev/null || echo 2417); \
	NEW=$$(($$OLD + 1)); \
	echo $$NEW > $@; \
	echo "Incrementing OS Build to $$NEW"

$(BUILD_DEBUG_FILE): $(DEBUG_SRCS)
	@OLD=$$(cat $@ 2>/dev/null || echo 1012); \
	NEW=$$(($$OLD + 1)); \
	echo $$NEW > $@; \
	echo "Incrementing DEBUG Build to $$NEW"

$(BUILD_OS_INC): $(BUILD_OS_FILE) | $(BUILD)
	@echo ".const BUILD_NUMBER = \"$$(cat $<)\"" > $@

$(BUILD_DEBUG_INC): $(BUILD_DEBUG_FILE) | $(BUILD)
	@echo ".const BUILD_NUMBER = \"$$(cat $<)\"" > $@

# command64 OS
$(BUILD)/command64.prg: $(CMD64_SRCS) $(BUILD_OS_INC) | $(BUILD)
	$(JAVA) -jar $(KICKASS) $(CMD64_ENTRY) -odir $(ABSBUILD)

# debug utility
$(BUILD)/debug.prg: $(DEBUG_SRCS) $(BUILD_DEBUG_INC) | $(BUILD)
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
	@test -n "$(VERSION)" || { echo "ERROR: VERSION file is missing or empty"; exit 1; }
	mkdir -p $(RELEASE_DIR)
	cp $(IMAGE_PRGS) $(RELEASE_DIR)/
	cp $(BUILD)/image.d64 $(BUILD)/test.d64 $(RELEASE_DIR)/
	rm -rf $(RELEASE_DIR)/docs
	cp -r docs $(RELEASE_DIR)/docs
	rm -rf $(RELEASE_DIR)/docs/superpowers
	cd $(RELEASE_DIR) && zip -r $(RELEASE_NAME).zip \
	    $(notdir $(IMAGE_PRGS)) image.d64 test.d64 docs/
	cd $(RELEASE_DIR) && tar -czf $(RELEASE_NAME).tar.gz \
	    $(notdir $(IMAGE_PRGS)) image.d64 test.d64 docs/
	@echo "Release $(VERSION) ready in $(RELEASE_DIR)/"
