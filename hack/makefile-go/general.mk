.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: install-dev-tools
install-dev-tools: ## Install dev tools
# 	go install github.com/princjef/gomarkdoc/cmd/gomarkdoc@latest
# 	go get -u github.com/princjef/gomarkdoc/cmd/gomarkdoc@latest
	go install golang.org/x/tools/cmd/stringer@latest
	bash ./hack/install-dev-tools.sh


.PHONY: clean
clean: ## Clean temp files
	@rm -vrf ./${OUTPUT_DIR}/*
