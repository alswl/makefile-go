# STAGE: final, alpha, beta, candidate. SCOPE: major, minor, patch.
DEFAULT_BUMP_STAGE = beta
DEFAULT_BUMP_SCOPE = minor
DEFAULT_BUMP_DRY_RUN = true

STAGE = $(DEFAULT_BUMP_STAGE)
SCOPE = $(DEFAULT_BUMP_SCOPE)
DRY_RUN = $(DEFAULT_BUMP_DRY_RUN)
PUSH ?= false
BUMP_MODE ?= release
BUMP_SCRIPT ?= ./hack/bump.sh
BUMP_PREPARE_FILES ?=
ifneq ($(BUMP_MODE),prepare)
BUMP_PREREQUISITES = check-git-status
endif
# Older bump.sh versions reject --mode, preventing prepare from falling back to release.
BUMP_COMMAND = set --; \
	if [ "$(BUMP_MODE)" != release ]; then set -- --mode "$(BUMP_MODE)"; fi; \
	BUMP_PROJECT_ROOT="$(CURDIR)" BUMP_MODE="$(BUMP_MODE)" BUMP_PREPARE_FILES="$(BUMP_PREPARE_FILES)" bash "$(BUMP_SCRIPT)" "$$@"

# Post-actions script run after VERSION is written (e.g. sync to pyproject.toml / package.json).
# Auto-detected from hack/bump-post-actions.sh; override POST_ACTIONS_SCRIPT to customize.
POST_ACTIONS_SCRIPT ?= ./hack/bump-post-actions.sh
BUMP_POST_ACTIONS := $(if $(wildcard $(POST_ACTIONS_SCRIPT)),--post-actions-script "$(POST_ACTIONS_SCRIPT)",)

.PHONY: bump-patch
bump-patch: $(BUMP_PREREQUISITES) ## Bump patch version (final)
	($(BUMP_COMMAND) --stage final --scope patch --dry-run "$(DRY_RUN)" --push "$(PUSH)" ${BUMP_POST_ACTIONS})

.PHONY: bump-minor
bump-minor: $(BUMP_PREREQUISITES) ## Bump minor version (final)
	($(BUMP_COMMAND) --stage final --scope minor --dry-run "$(DRY_RUN)" --push "$(PUSH)" ${BUMP_POST_ACTIONS})

.PHONY: bump-major
bump-major: $(BUMP_PREREQUISITES) ## Bump major version (final)
	($(BUMP_COMMAND) --stage final --scope major --dry-run "$(DRY_RUN)" --push "$(PUSH)" ${BUMP_POST_ACTIONS})

.PHONY: bump-beta
bump-beta: $(BUMP_PREREQUISITES) ## Bump beta pre-release (minor)
	($(BUMP_COMMAND) --stage beta --scope "$(SCOPE)" --dry-run "$(DRY_RUN)" --push "$(PUSH)" ${BUMP_POST_ACTIONS})

.PHONY: bump-alpha
bump-alpha: $(BUMP_PREREQUISITES) ## Bump alpha pre-release (minor)
	($(BUMP_COMMAND) --stage alpha --scope "$(SCOPE)" --dry-run "$(DRY_RUN)" --push "$(PUSH)" ${BUMP_POST_ACTIONS})

.PHONY: bump
bump: $(BUMP_PREREQUISITES) ## Bump version (uses STAGE and SCOPE variables)
	($(BUMP_COMMAND) --stage "$(STAGE)" --scope "$(SCOPE)" --dry-run "$(DRY_RUN)" --push "$(PUSH)" ${BUMP_POST_ACTIONS})

ifneq ($(BUMP_MODE),prepare)
SUB ?=
.PHONY: bump-sub
bump-sub: $(BUMP_PREREQUISITES) ## Bump sub-module version
	@test -n "$(SUB)" || (echo "SUB is required. Usage: make bump-sub SUB=<dir> [SCOPE=patch]" && exit 1)
	(bash ./hack/bump-sub-mod.sh $(SUB) "$(SCOPE)" "$(DRY_RUN)" "$(PUSH)")

endif

.PHONY: version
version: ## Show current version
	@cat VERSION

ifneq ($(BUMP_MODE),prepare)
.PHONY: gen-changelog-patch
gen-changelog-patch: ## Generate changelog for next patch version
	(bash ./hack/gen-changelog.sh --stage final --scope patch)

.PHONY: gen-changelog-minor
gen-changelog-minor: ## Generate changelog for next minor version
	(bash ./hack/gen-changelog.sh --stage final --scope minor)

.PHONY: gen-changelog-major
gen-changelog-major: ## Generate changelog for next major version
	(bash ./hack/gen-changelog.sh --stage final --scope major)

.PHONY: gen-changelog-beta
gen-changelog-beta: ## Generate changelog for next beta version
	(bash ./hack/gen-changelog.sh --stage beta --scope "$(SCOPE)")

.PHONY: gen-changelog-alpha
gen-changelog-alpha: ## Generate changelog for next alpha version
	(bash ./hack/gen-changelog.sh --stage alpha --scope "$(SCOPE)")

.PHONY: gen-changelog
gen-changelog: ## Generate changelog (uses STAGE and SCOPE variables)
	(bash ./hack/gen-changelog.sh --stage "$(STAGE)" --scope "$(SCOPE)")
endif
