#!/usr/bin/env bash
# Source this file from a project release script.

package_die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

package_sha256() {
    if command -v sha256sum >/dev/null; then
        sha256sum < "$1" | awk '{print $1}'
    else
        shasum -a 256 < "$1" | awk '{print $1}'
    fi
}

package_build() {
    local os=$1 arch=$2 output=$3
    shift 3
    GOOS="$os" GOARCH="$arch" "${MAKEFILE_GO_MAKE:-make}" --no-print-directory build GO_BUILD_OUTPUT="$output" GO_BUILD_COPY_VARIANTS=false "$@"
}

package_release() (
    set -euo pipefail
    (($# >= 4)) || package_die 'Expected a tag, output, binary and at least one release target'
    local tag=$1 output=$2 app=$3
    shift 3
    local target os arch suffix member binary archive sha parent previous hook_status
    local tag_pattern='^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
    local -a suffixes=()
    [[ "$tag" =~ $tag_pattern ]] || package_die "Invalid release tag: $tag"
    [[ "$app" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || package_die "Invalid binary name: $app"
    for target in "$@"; do
        [[ "$target" =~ ^[a-z0-9]+:[a-z0-9]+:[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
            package_die "Invalid target: $target (expected goos:goarch:asset-suffix)"
        suffix=${target##*:}
        for previous in "${suffixes[@]+"${suffixes[@]}"}"; do
            [[ "$suffix" != "$previous" ]] || package_die "Duplicate asset suffix: $suffix"
        done
        suffixes+=("$suffix")
    done
    command -v sha256sum >/dev/null || command -v shasum >/dev/null || package_die 'Install sha256sum or shasum'
    [[ "$output" == /* ]] || output="$PWD/$output"
    mkdir -p "$(dirname "$output")" || exit 1
    parent=$(cd "$(dirname "$output")" && pwd) || exit 1
    output="$parent/$(basename "$output")"
    [[ ! -e "$output" && ! -L "$output" ]] || package_die "Output already exists: $output"
    # Bash 3 can run the EXIT trap after the function's locals have gone out of scope.
    staging=''
    lock="$output.lock"
    mkdir "$lock" || package_die "Cannot lock output: $output"
    trap 'if [[ -n "$staging" ]]; then rm -rf -- "$staging"; fi; rmdir "$lock"' EXIT
    trap 'exit 1' HUP INT TERM
    # Callers can use package_release in a conditional, where Bash ignores errexit.
    staging=$(mktemp -d "$parent/.makefile-go-package.XXXXXX") || exit 1
    mkdir "$staging/work" || exit 1
    if declare -F package_before >/dev/null; then
        package_before "$staging" "$tag"
        hook_status=$?
        ((hook_status == 0)) || package_die 'package_before failed'
    fi

    : > "$staging/checksums.txt" || exit 1
    for target in "$@"; do
        IFS=: read -r os arch suffix <<< "$target"
        member="$app-$suffix"
        binary="$staging/work/$member"
        archive="$app-$tag-$suffix.tar.gz"
        printf 'Building %s (%s/%s)\n' "$suffix" "$os" "$arch"
        package_build "$os" "$arch" "$binary" "TARGETS=$app" || package_die "Build failed for $member"
        [[ -f "$binary" && ! -L "$binary" ]] || package_die "Build did not produce $member"
        chmod 0755 "$binary" || exit 1
        if declare -F package_verify >/dev/null; then
            package_verify "$staging" "$binary" "$os" "$arch" "$suffix"
            hook_status=$?
            ((hook_status == 0)) || package_die "package_verify failed for $member"
        fi
        COPYFILE_DISABLE=1 tar --format=ustar -czf "$staging/$archive" -C "$staging/work" "$member" || exit 1
        sha=$(package_sha256 "$staging/$archive") || exit 1
        printf '%s  %s\n' "$sha" "$archive" >> "$staging/checksums.txt" || exit 1
    done
    if declare -F package_after >/dev/null; then
        package_after "$staging" "$tag"
        hook_status=$?
        ((hook_status == 0)) || package_die 'package_after failed'
    fi
    rm -rf -- "$staging/work" || exit 1
    [[ ! -e "$output" && ! -L "$output" ]] || package_die "Output appeared while building: $output"
    mv "$staging" "$output" || exit 1
    staging=''
    printf 'Prepared %s archive(s) and checksums in %s\n' "$#" "$output"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    (($# >= 5)) || package_die 'Expected HOOKS TAG OUTPUT BINARY and at least one target'
    hooks=$1
    shift
    if [[ -n "$hooks" ]]; then
        # A relative hook path must resolve within the consuming project.
        [[ "$hooks" == /* ]] || hooks="./$hooks"
        source "$hooks"
    fi
    package_release "$@"
fi
