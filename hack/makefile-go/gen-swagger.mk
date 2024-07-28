.PHONY: generate-code-swagger
generate-code-swagger: ## generate code from swagger
	@echo generate swagger
	@(cd pkg; rm client0/zz_generated_*.go;rm client0/*/zz_generated_*.go; rm models/zz_generated_*.go; swagger generate client -c client0 -f ../api/swagger.yaml -A toodledo --template-dir ../api/templates --allow-template-override -C ../api/config.yaml)

