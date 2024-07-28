.PHONY: generate-code-wire
generate-code-wire: ## Generate wire injection code
	# wire
	@echo generate wire
	@(cd cmd/toodledo/injector; $$GOPATH/bin/wire)

	@echo copy injector.go to itinjector.go for testing
	@mkdir -p test/suites/itinjector
	@cp cmd/toodledo/injector/injector.go test/suites/itinjector/itinjector.go
	@gsed -i 's/package injector/package itinjector/g' test/suites/itinjector/itinjector.go
	@gsed -i 's/TUISet/IntegrationTestTUISet/g' test/suites/itinjector/itinjector.go
	@(cd test/suites/itinjector; $$GOPATH/bin/wire)

