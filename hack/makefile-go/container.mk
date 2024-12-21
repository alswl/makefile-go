.PHONY: container
container: ## Build containers
	# COMMIT pass to container, because no git repo in container
	@for target in $(TARGETS); do                                \
	  for registry in $(REGISTRIES); do                          \
	    image=$(IMAGE_PREFIX)$${target}$(IMAGE_SUFFIX);          \
	    docker build -t $${registry}$${image}:$(VERSION)         \
	      --build-arg COMMIT=$(COMMIT)                   \
	      --progress=plain                                       \
	      -f $(BUILD_DIR)/$${target}/Dockerfile .;               \
	  done                                                       \
	done

.PHONY: container-push
container-push: ## Push containers images to reigstry
	@for target in $(TARGETS); do                       \
	  for registry in $(REGISTRIES); do                 \
	    image=$(IMAGE_PREFIX)$${target}$(IMAGE_SUFFIX); \
	    docker push $${registry}$${image}:$(VERSION);   \
	  done                                              \
	done

.PHONY: container-build-env
newBuildEnvVersion=$(GO_MOD_VERSION)-$(shell tar cf - build/$(PROJECT) | sha256sum | cut -c1-6)
container-build-env: #check-git-status ## Build container build env
	@for registry in $(REGISTRIES); do                                                          \
	  image=$(IMAGE_PREFIX)$(PROJECT)$(IMAGE_SUFFIX);                                           \
	    DOCKER_BUILDKIT=1 docker build -t $${registry}$${image}-build-env:$(newBuildEnvVersion) \
	      --build-arg ROOT=$(ROOT) --build-arg TARGET=$${target}                                \
	      --build-arg CMD_DIR=$(CMD_DIR)                                                        \
	      --build-arg VERSION=$(GO_MOD_VERSION)                                                 \
	      --build-arg COMMIT=$(COMMIT)                                                          \
	    --progress=plain                                                                        \
	    -f $(BUILD_DIR)/$(PROJECT)/Dockerfile .;                                                \
	done


.PHONY: push-container-build-env
newBuildEnvVersion=$(GO_MOD_VERSION)-$(shell tar cf - build/$(PROJECT) | sha256sum | cut -c1-6)
push-container-build-env: ## Push containers build env images to reigstry
	@for registry in $(REGISTRIES); do                                     \
	  image=$(IMAGE_PREFIX)$(PROJECT)$(IMAGE_SUFFIX);                      \
	    docker push $${registry}$${image}-build-env:$(newBuildEnvVersion); \
	done

.PHONY: bump-build-env-container
currentBuildEnvVersion=$(shell head -n 1 build/$(PROJECT)/VERSION)
newBuildEnvVersion=$(GO_MOD_VERSION)-$(shell tar cf - build/$(PROJECT) | sha256sum | cut -c1-6)
bump-build-env-container: ## Bump build env container for all containers and aci
	echo "$(newBuildEnvVersion)" > build/$(PROJECT)/VERSION
	gsed -i "s/build-env:$(currentBuildEnvVersion)/build-env:$(newBuildEnvVersion)/g" .aci.yml
	find build -name "Dockerfile" -exec gsed -i "s/build-env:$(currentBuildEnvVersion)/build-env:$(newBuildEnvVersion)/g" {} \;
	@echo "# PLEASE using 'git commit -a' to commit image version changes"
