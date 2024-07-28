.PHONY: test
test: ## Run unit tests
	@# NOTICE, the test output is using for coverage analytics, did not modify the std out
	@echo "cover package: ${UT_COVER_PACKAGES}"
	@GOOS=$(GOOS) GOARCH=$(GOARCH) go test -v ${UT_COVER_PACKAGES} -race -coverprofile cover.out -tags=\!integration ./...

.PHONY: integration-test
integration-test: ## Run integration tests
	@echo "cover package: ${IT_COVER_PACKAGES}"
	@GOOS=$(GOOS) GOARCH=$(GOARCH) go test -v ${IT_COVER_PACKAGES} -coverprofile cover.out -race -tags=integration ./...

