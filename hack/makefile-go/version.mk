.PHONY: bump
STAGE=$(DEFAULT_BUMP_STAGE)
SCOPE=$(DEFAULT_BUMP_SCOPE)
DRY_RUN=$(DEFAULT_BUMP_DRY_RUN)
bump: check-git-status ## Bump version
	(bash ./hack/bump.sh ${STAGE} ${SCOPE} ${DRY_RUN})

