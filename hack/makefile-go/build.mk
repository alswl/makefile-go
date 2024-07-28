.PHONY: download
download: ## Run go mod download
	go mod download

.PHONY: fmt
fmt: ## Run format code
	gofmt -w ./pkg/ ./test/ ./cmd/
	go fmt ./pkg/... ./cmd/...
	go vet ./pkg/... ./cmd/...
	goimports -w ./pkg/ ./test/ ./cmd/
	golangci-lint run --fix

.PHONY: lint
lint: ## Run lint
	@echo "# gofmt"
	@test $$(gofmt -l . | wc -l) -eq 0

	@echo "# ensure integration test with // +build integration"
	@test $$(find test -name '*_test.go' | wc -l) -eq $$(cat $$(find test -name '*_test.go') | grep -E '// ?go:build integration' | wc -l)

	go mod tidy
	golangci-lint run --timeout 5m
	gofmt -w .

.PHONY: build
MINIMAL_BUILD = 0
build: ## Build
	@for target in $(TARGETS); do                                                             \
	  GOOS=$(GOOS) GOARCH=$(GOARCH) go build -v -o $(OUTPUT_DIR)/$${target}-$(GOOS)-$(GOARCH) \
	    -ldflags "-s -w -X $(ROOT)/pkg/version.Version=$(VERSION)                             \
	    -X $(ROOT)/pkg/version.Commit=$(COMMIT)                                               \
	    -X $(ROOT)/pkg/version.Package=$(ROOT)"                                               \
	    $(CMD_DIR)/$${target};                                                                \
	  if [ $(MINIMAL_BUILD) -eq 1 ]; then                                                                                  \
	    upx $(OUTPUT_DIR)/$${target}-$(GOOS)-$(GOARCH);                                                                    \
	  fi;                                                                                                                  \
	  cp $(OUTPUT_DIR)/$${target}-$(GOOS)-$(GOARCH) $(OUTPUT_DIR)/$${target}-$(VERSION)-$(GOOS)-$(GOARCH);                 \
	  cp $(OUTPUT_DIR)/$${target}-$(GOOS)-$(GOARCH) $(OUTPUT_DIR)/$${target}-$(VERSION);                                   \
	  cp $(OUTPUT_DIR)/$${target}-$(GOOS)-$(GOARCH) $(OUTPUT_DIR)/$${target};                                              \
	done
