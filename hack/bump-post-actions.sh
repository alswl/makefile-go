#!/usr/bin/env bash
# Post-actions hook for bump.sh. Sync version to external config files.
# github.com/alswl/makefile-go
#
# Author: alswl
# Version: 0.1.0

set -eo pipefail
pushd "${BUMP_PREPARE_DIR:-$(dirname "$0")/..}" > /dev/null
if [[ -n "${BUMP_PREPARE_DIR:-}" && ! -f package.json ]]; then
    printf '%s\n' 'Include package.json in BUMP_PREPARE_FILES to run this hook.' >&2
    exit 1
fi
cat package.json | jq -M --raw-output ".version=\"$(cat VERSION | head -n 1 | sed 's/^v//g')\"" | sponge package.json
popd > /dev/null
