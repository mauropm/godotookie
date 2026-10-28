# Fortune Cookie: A Little Luck — developer commands
#
# Common workflows:
#   make run                 Launch the game from source
#   make build               Validate + build a local debug executable
#   make release             Validate, test, export, verify, and package a release
#   make clean               Remove build outputs and the Godot import cache
#
# Override Godot with: make GODOT=/path/to/godot ...
# Override launch arguments with: make run ARGS="--position 40,40"

SHELL := /bin/bash
.DEFAULT_GOAL := help
.SHELLFLAGS := -eu -o pipefail -c

APP_NAME := FortuneCookie
VERSION := $(shell sed -n 's/^config\/version="\([^"]*\)"/\1/p' project.godot | head -n 1)
ifeq ($(strip $(VERSION)),)
VERSION := 1.0.0
endif
DIST_NAME := $(APP_NAME)-$(VERSION)-linux-x86_64

LINUX_DIR := builds/linux
DEBUG_DIR := builds/linux-debug
RELEASE_DIR := builds/release
LINUX_BIN := $(LINUX_DIR)/$(APP_NAME).x86_64
DEBUG_BIN := $(DEBUG_DIR)/$(APP_NAME).x86_64

PYTHON ?= python3
GODOT ?= $(shell command -v godot 2>/dev/null || command -v godot4 2>/dev/null || true)
ifeq ($(strip $(GODOT)),)
GODOT := $(HOME)/.local/share/godot-editor/4.7.2/Godot_v4.7.2-stable_linux.x86_64
endif

.PHONY: help check-godot env import validate test build run run-debug run-release \
        export release clean

help: ## Show available commands
	@printf '%s\n' \
		'Fortune Cookie: A Little Luck' \
		'' \
		'Usage: make <target> [GODOT=/path/to/godot] [ARGS="..."]' \
		'' \
		'Targets:' \
		'  help          Show this help' \
		'  env           Run the Ubuntu development environment check' \
		'  import        Import resources with the Godot editor (headless)' \
		'  validate      Validate all 30 fortune libraries and UI catalogues' \
		'  test          Validate + run the headless Godot integration suite' \
		'  build         Validate + build a debug Linux executable' \
		'  run           Launch the game from source (ARGS supported)' \
		'  run-debug     Launch the debug build (ARGS supported)' \
		'  run-release   Launch the release binary (ARGS supported)' \
		'  export        Export the Linux release binary and PCK' \
		'  release       Test, export, verify, and package the Linux release ZIP' \
		'  clean         remove .godot/, builds/, and Python caches' \
		'' \
		'Current Godot: $(GODOT)' \
		'App/version:   $(APP_NAME) $(VERSION)'

check-godot:
	@if [ ! -x "$(GODOT)" ]; then \
		printf '%s\n' "Godot executable not found or not executable: $(GODOT)" \
			"Set GODOT=/path/to/godot or run ./scripts/check-dev-env.sh."; \
		exit 1; \
	fi

env:
	@./scripts/check-dev-env.sh

import: check-godot
	@printf 'Importing project resources...\n'
	@$(GODOT) --headless --path . --editor --quit

validate:
	@printf 'Validating fortune libraries and interface catalogues...\n'
	@$(PYTHON) tools/validate_fortunes.py

test: check-godot
	@GODOT_BIN="$(GODOT)" ./scripts/test.sh

build: check-godot validate import
	@mkdir -p "$(DEBUG_DIR)"
	@printf 'Building debug Linux executable...\n'
	@$(GODOT) --headless --path . --export-debug "Linux" "$(DEBUG_BIN)"
	@chmod +x "$(DEBUG_BIN)"
	@printf 'Debug build: %s\n' "$(DEBUG_BIN)"

run: check-godot
	@$(GODOT) --path . $(ARGS)

run-debug: check-godot
	@test -x "$(DEBUG_BIN)" || { printf 'Debug build missing. Run make build first.\n'; exit 1; }
	@"$(DEBUG_BIN)" $(ARGS)

run-release: check-godot
	@test -x "$(LINUX_BIN)" || { printf 'Release build missing. Run make release first.\n'; exit 1; }
	@"$(LINUX_BIN)" $(ARGS)

export: check-godot
	@mkdir -p "$(LINUX_DIR)"
	@printf 'Exporting Linux release...\n'
	@$(GODOT) --headless --path . --export-release "Linux" "$(LINUX_BIN)"
	@chmod +x "$(LINUX_BIN)"
	@printf 'Exported: %s\n' "$(LINUX_BIN)"

release: test
	@command -v zip >/dev/null || { printf 'zip is required to build the release archive.\n'; exit 1; }
	@mkdir -p "$(LINUX_DIR)"
	@rm -rf "$(RELEASE_DIR)"
	@mkdir -p "$(RELEASE_DIR)"
	@printf 'Exporting release build...\n'
	@$(GODOT) --headless --path . --export-release "Linux" "$(LINUX_BIN)"
	@chmod +x "$(LINUX_BIN)"
	@printf 'Verifying packaged content...\n'
	@"$(LINUX_BIN)" --headless --verify-content
	@cp "$(LINUX_BIN)" "$(LINUX_DIR)/$(APP_NAME).pck" README.md LICENSE "$(RELEASE_DIR)/"
	@cp -r docs "$(RELEASE_DIR)/"
	@cd "$(RELEASE_DIR)" && zip -qr9 "$(DIST_NAME).zip" \
		"$(APP_NAME).x86_64" "$(APP_NAME).pck" README.md LICENSE docs
	@cd "$(RELEASE_DIR)" && sha256sum \
		"$(APP_NAME).x86_64" "$(APP_NAME).pck" "$(DIST_NAME).zip" > SHA256SUMS.txt
	@printf '\nRelease ready: %s/%s.zip\n' "$(RELEASE_DIR)" "$(DIST_NAME)"
	@cat "$(RELEASE_DIR)/SHA256SUMS.txt"

clean:
	@printf 'Removing build outputs, Godot cache, and Python caches...\n'
	@rm -rf .godot builds
	@find . -type d -name __pycache__ -prune -exec rm -rf {} +
	@find . -type f -name '*.tmp' -not -path './.git/*' -delete
	@mkdir -p builds
	@touch builds/.gitkeep
	@printf 'Clean complete.\n'
