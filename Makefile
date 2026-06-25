# Makefile — Proxy to CMake Build System
#
# This file forwards standard targets to the new CMake build system in build/.

BUILD_DIR := build

.PHONY: all image testimage test release clean $(BUILD_DIR)

all: $(BUILD_DIR)
	cmake --build $(BUILD_DIR)

image: $(BUILD_DIR)
	cmake --build $(BUILD_DIR) --target image_d64

testimage: $(BUILD_DIR)
	cmake --build $(BUILD_DIR) --target test_image_d64

test: $(BUILD_DIR)
	cmake --build $(BUILD_DIR) --target test_image_d64

release: $(BUILD_DIR)
	cmake --build $(BUILD_DIR) --target release

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR):
	@if [ ! -d $(BUILD_DIR) ]; then \
		cmake -B $(BUILD_DIR); \
	fi
