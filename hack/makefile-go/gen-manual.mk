.PHONY: generate-manual
generate-manual: ## Generate develop docs
	# go install github.com/princjef/gomarkdoc/cmd/gomarkdoc@latest
	gomarkdoc --output GO_DOC.md ./...

	# TODO for loop
	rm -rf docs/toodledo/commands
	mkdir -p docs/commands
	go run ./cmd/gendocs/

