.PHONY: generate-code-enum
generate-code-enum: ## Generate enum String for models
	# go install golang.org/x/tools/cmd/stringer
	@echo generate stringer for enums
	# TODO using ls
	@(cd pkg/models/enums/tasks/priority; go generate)
	@(cd pkg/models/enums/tasks/status; go generate)
	@(cd pkg/models/enums/tasks/subtasksview; go generate)

.PHONY: generate-manual
generate-manual: ## Generate develop docs
	# go install github.com/princjef/gomarkdoc/cmd/gomarkdoc@latest
	gomarkdoc --output GO_DOC.md ./...

	# TODO for loop
	rm -rf docs/toodledo/commands
	mkdir -p docs/commands
	go run ./cmd/gendocs/

.PHONY: generate-code-mockery
generate-code-mockery: ## Run generate generated unit test code
	# 如果遇到问题
	# Unexpected package creation during export data loading
	# https://github.com/vektra/mockery/pull/435#issuecomment-1134329306
	@echo "# generate mock of interfaces for testing"
	@rm -rf test/mock
	@mkdir -p test/mock
	#@(cd pkg && mockery --all --keeptree --case=underscore --packageprefix=mock --output=../test/mock)
	#@(cd cmd && mockery --all --keeptree --case=underscore --packageprefix=mock --output=../test/mock)
	@(cd . && mockery --all --keeptree --case=underscore --packageprefix=mock --output=./test/mock/)
	# mockery not support 1.18 generic now, temporarily drop zero size golang file
	# https://github.com/vektra/mockery/pull/456
	find test/mock -size 0 -exec rm {} \;

.PHONY: generate-code-swagger
generate-code-swagger: ## generate code from swagger
	@echo generate swagger
	@(cd pkg; rm client0/zz_generated_*.go;rm client0/*/zz_generated_*.go; rm models/zz_generated_*.go; swagger generate client -c client0 -f ../api/swagger.yaml -A toodledo --template-dir ../api/templates --allow-template-override -C ../api/config.yaml)

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

