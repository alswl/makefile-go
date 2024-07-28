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

