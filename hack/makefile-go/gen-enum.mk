.PHONY: generate-code-enum
generate-code-enum: ## Generate enum String for models
	# go install golang.org/x/tools/cmd/stringer
	@echo generate stringer for enums
	# TODO using ls
	@(cd pkg/models/enums/tasks/priority; go generate)
	@(cd pkg/models/enums/tasks/status; go generate)
	@(cd pkg/models/enums/tasks/subtasksview; go generate)

