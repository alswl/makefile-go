GO_BUILD_VERBOSE ?= -v
GO_SOURCE_DIRS ?= .
GO_LINT_READ_ONLY ?= false
GO_LINT_COMMAND ?= golangci-lint run --timeout 5m
GO_BUILD_LDFLAGS ?= -s -w -X $(ROOT)/pkg/version.Version=$(VERSION) -X $(ROOT)/pkg/version.Commit=$(COMMIT) -X $(ROOT)/pkg/version.Package=$(ROOT) -X $(ROOT)/internal/version.Version=$(VERSION) -X $(ROOT)/internal/version.Commit=$(COMMIT) -X $(ROOT)/internal/version.Package=$(ROOT)
GO_BUILD_OUTPUT ?= $(OUTPUT_DIR)/$${target}-$(GOOS)-$(GOARCH)
GO_BUILD_COPY_VARIANTS ?= true

.PHONY: download
download: ## Run go mod download
	go mod download


.PHONY: fmt
fmt: ## Run format code
	gofmt -w $(GO_SOURCE_DIRS)
	$(if $(filter .,$(GO_SOURCE_DIRS)),go fmt ./...)
	# vet is run by golangci-lint
	# https://golangci-lint.run/usage/linters/
	# go vet ./...
	goimports -w $(GO_SOURCE_DIRS)
	$(if $(filter .,$(GO_SOURCE_DIRS)),golangci-lint run --fix)


.PHONY: lint
lint: ## Run lint
	@echo "# gofmt"
	@unformatted=$$(gofmt -l $(GO_SOURCE_DIRS)) && test -z "$$unformatted"

	@echo "# ensure integration test with // +build integration"
	@if [ -n "$$(find . -name '*_integration_test.go')" ]; then                                                                                                  \
		test $$(find . -name '*_integration_test.go' | wc -l) -eq $$(cat $$(find . -name '*_integration_test.go') | grep -E '// ?\+build integration' | wc -l);  \
	fi

ifeq ($(GO_LINT_READ_ONLY),true)
	go mod tidy -diff
else
	go mod tidy
	gofmt -w $(GO_SOURCE_DIRS)
endif
	$(GO_LINT_COMMAND)

	# (cd examples && go mod tidy && golangci-lint run --timeout 5m && gofmt -w $(GO_SOURCE_DIRS))


.PHONY: clean
clean: ## Clean temp files
	@rm -vrf ${OUTPUT_DIR}/*


.PHONY: build
build: ## Build
	@set --; \
	for target in $(TARGETS); do \
	  output="$(GO_BUILD_OUTPUT)"; \
	  for previous; do \
	    if [ "$$previous" = "$$output" ]; then \
	      printf 'Multiple targets use GO_BUILD_OUTPUT %s\n' "$$output" >&2; exit 1; \
	    fi; \
	  done; \
	  set -- "$$@" "$$output"; \
	done; \
	for target in $(TARGETS); do \
	  output="$$1"; shift; \
	  mkdir -p "$$(dirname "$$output")" || exit; \
	  GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(GO_BUILD_VERBOSE) -o "$$output" \
	    $(if $(GO_BUILD_TAGS),-tags=$(GO_BUILD_TAGS),) \
	    -ldflags "$(GO_BUILD_LDFLAGS)" $(CMD_DIR)/$${target} || exit; \
	  if [ "$(GO_BUILD_COPY_VARIANTS)" = true ]; then \
	    mkdir -p "$(OUTPUT_DIR)" || exit; \
	    for variant in "$(OUTPUT_DIR)/$${target}" \
	      "$(OUTPUT_DIR)/$${target}-$(GOOS)-$(GOARCH)-$(VERSION)" "$(OUTPUT_DIR)/$${target}-$(VERSION)"; do \
	      if ! [ "$$output" -ef "$$variant" ]; then cp "$$output" "$$variant" || exit; fi; \
	    done; \
	  fi; \
	done


.PHONY: compress
compress: ## Compress by upx
	@# move out of loop to avoid syntax error
	@# upx not works in debian for security reason
	@# upx $(OUTPUT_DIR)/$${target};
	@for target in $(TARGETS); do                                                                      \
	    echo "";                                                                                       \
	done
