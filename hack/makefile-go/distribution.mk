# Optional release archive and standalone installer targets.
MAKEFILE_GO_DISTRIBUTION_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

PACKAGE_TAG ?= $(shell cat VERSION)
PACKAGE_OUT ?= release/$(PACKAGE_TAG)
PACKAGE_BINARY ?= $(firstword $(TARGETS))
PACKAGE_TARGETS ?=
PACKAGE_HOOKS ?=

INSTALLER_PROJECT ?= hack/install-project.sh
INSTALLER_OUTPUT ?= hack/install.sh
INSTALLER_RENDER = sh "$(MAKEFILE_GO_DISTRIBUTION_DIR)/render-install.sh" "$(INSTALLER_PROJECT)"

.PHONY: package generate-installer check-installer
package: ## Build and verify release archives.
	+@MAKEFILE_GO_MAKE="$(MAKE)" bash "$(MAKEFILE_GO_DISTRIBUTION_DIR)/package-release.sh" "$(PACKAGE_HOOKS)" "$(PACKAGE_TAG)" "$(PACKAGE_OUT)" "$(PACKAGE_BINARY)" $(foreach target,$(PACKAGE_TARGETS),"$(target)")

generate-installer: ## Generate a standalone installer from project configuration.
	@set -e; output="$(INSTALLER_OUTPUT)"; mkdir -p "$$(dirname "$$output")"; \
	  tmp=$$(mktemp "$$output.XXXXXX"); trap 'rm -f "$$tmp"' EXIT; \
	  $(INSTALLER_RENDER) > "$$tmp"; chmod +x "$$tmp"; mv "$$tmp" "$$output"

check-installer: ## Check that the committed installer matches its template.
	@set -e; tmp=$$(mktemp); trap 'rm -f "$$tmp"' EXIT; \
	  $(INSTALLER_RENDER) > "$$tmp"; diff -u "$(INSTALLER_OUTPUT)" "$$tmp"
