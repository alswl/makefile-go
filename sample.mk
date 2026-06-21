# https://github.com/alswl/makefile-go
# @alswl
# The old school Makefile, following are required targets. The Makefile is written
# to allow building multiple binaries. You are free to add more targets or change
# existing implementations, as long as the semantics are preserved.
#
#   make              - default to 'build' target
#   make test         - run unit test
#   make build        - build local binary targets
#   make install      - install binaries to PATH
#   make container    - build containers
#   make push         - push containers
#   make clean        - clean up targets

# The makefile is also responsible to populate project version information.

# Tweak the variables based on your project.
SHELL := /bin/bash
NOW_SHORT := $(shell date +%Y%m%d%H%M)

PROJECT := your-project
# Target binaries. You can build multiple binaries for a single project.
TARGETS := your-server your-worker your-cli

# Container registries.
REGISTRIES ?= "your-registry.example.com/your/"

# Container image prefix and suffix added to targets.
# The final built images are:
#   $[REGISTRY]$[IMAGE_PREFIX]$[TARGET]$[IMAGE_SUFFIX]:$[VERSION]
# $[REGISTRY] is an item from $[REGISTRIES], $[TARGET] is an item from $[TARGETS].
IMAGE_PREFIX ?= $(strip )
IMAGE_SUFFIX ?= $(strip )

# This repo's root import path (under GOPATH).
ROOT := your-host.com/your/your-server

# Project main package location (can be multiple ones).
CMD_DIR := ./cmd

# Project output directory.
OUTPUT_DIR := ./bin

# Build directory.
BUILD_DIR := ./build

PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))

# Git commit sha.
COMMIT := $(strip $(shell git rev-parse --short HEAD 2>/dev/null))
COMMIT := $(COMMIT)$(shell [[ -z $$(git status -s) ]] || echo '-dirty')
COMMIT := $(if $(COMMIT),$(COMMIT), $${COMMIT})
COMMIT := $(if $(COMMIT),$(COMMIT),"Unknown")

# Current version of the project.
VERSION_IN_FILE = $(shell cat VERSION)
BUILD_VERSION = $(COMMIT)
GO_MOD_VERSION = $(shell cat go.mod | sha256sum | cut -c-6)
GOOS = $(shell go env GOOS)
GOARCH = $(shell go env GOARCH)
GOPATH = $(shell go env GOPATH)
CGO_ENABLED = $(shell go env CGO_ENABLED)
VERSION ?= $(VERSION_IN_FILE)-$(BUILD_VERSION)

UT_COVER_PACKAGES := $(shell go list ./pkg/... | grep -Ev 'pkg/models|pkg/version|pkg/injector')
IT_COVER_PACKAGES := $(shell go list ./test/suites/... 2>/dev/null || echo '')
COVERAGE_PACKAGES := $(shell go list ./pkg/... | awk '{printf "%s%s", sep, $$0; sep=","} END{print ""}')
COVERAGE_PROFILING_DIR := $(PROJECT_DIR)/.cover

.PHONY: all
all: fmt test build

include hack/makefile-go/_git.mk
include hack/makefile-go/build.mk
include hack/makefile-go/install.mk
include hack/makefile-go/test.mk
include hack/makefile-go/gen.mk
include hack/makefile-go/gen-wire.mk
include hack/makefile-go/gen-nirvana.mk
include hack/makefile-go/gen-huma.mk
include hack/makefile-go/container.mk
include hack/makefile-go/container-build-env.mk
include hack/makefile-go/version.mk

##@ Self defined
.PHONY: install-dev-tools
install-dev-tools: ## Install dev tools
	echo ""

##@ Override
