# Sourced by bump.sh after parsing its options.

set -euo pipefail
die() { printf '%s\n' "$*" >&2; exit 1; }

case "$bump_stage" in final|alpha|beta|candidate) ;; *) die "Invalid stage: $bump_stage" ;; esac
case "$bump_scope" in major|minor|patch) ;; *) die "Invalid scope: $bump_scope" ;; esac
case "$bump_dry_run" in true|false) ;; *) die "Invalid dry-run value: $bump_dry_run" ;; esac
[[ "$bump_push" == false ]] || die 'Push the release tag separately after merging the PR.'

command -v semtag >/dev/null || die 'Install semtag to calculate the next version.'
# The tagging mode of semtag can push to every remote.
next=$(semtag "$bump_stage" -s "$bump_scope" -f -o)
[[ "$next" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]] || die "Invalid version from semtag: $next"
current=$(cat VERSION)
[[ "$next" != "$current" ]] || die "VERSION already declares $next."
printf '%s -> %s\n' "$current" "$next"
if [[ "$bump_dry_run" == true ]]; then
    printf 'Run with DRY_RUN=false to prepare the release files.\n'
    exit 0
fi

command -v git-cliff >/dev/null || die 'Install git-cliff to generate CHANGELOG.md.'
files=(VERSION CHANGELOG.md)
read -r -a extra_files <<< "${BUMP_PREPARE_FILES:-}"
if [[ -n "${extra_files[0]:-}" ]]; then
    for file in "${extra_files[@]}"; do
        for existing in "${files[@]}"; do
            [[ "$file" != "$existing" ]] || die "Duplicate release file: $file"
        done
        files+=("$file")
    done
fi
for file in "${files[@]}"; do
    [[ "$file" != /* && "$file" != -* && "$file" != *//* && "/$file/" != */../* && "/$file/" != */./* && -f "$file" && ! -L "$file" ]] ||
        die "Expected a regular project file: $file"
    git --literal-pathspecs ls-files --error-unmatch -- "$file" >/dev/null || die "Expected a tracked file: $file"
    [[ -w "$(dirname "$file")" ]] || die "Cannot replace release file: $file"
done
status=$(git --literal-pathspecs status --porcelain -- "${files[@]}")
[[ -z "$status" ]] ||
    die 'Commit or stash changes to the release files first.'

staging=$(mktemp -d "$PWD/.makefile-go-bump.XXXXXX")
trap 'rm -rf -- "$staging"' EXIT
prepared="$staging/prepared"
original="$staging/original"
for file in "${files[@]}"; do
    parent=$(dirname "$file")
    mkdir -p "$prepared/$parent" "$original/$parent"
    cp -p "$file" "$original/$file"
    cp -p "$original/$file" "$prepared/$file"
done
printf '%s\n' "$next" > "$prepared/VERSION"
if [[ -n "$post_actions_script" ]]; then
    case "$post_actions_script" in /*) ;; *) post_actions_script="./$post_actions_script" ;; esac
    if [[ -x "$post_actions_script" ]]; then
        BUMP_PREPARE_DIR="$prepared" "$post_actions_script"
    else
        BUMP_PREPARE_DIR="$prepared" bash "$post_actions_script"
    fi
fi
git cliff --tag "$next" --output "$prepared/CHANGELOG.md"
[[ -s "$prepared/CHANGELOG.md" ]] || die 'git-cliff produced an empty changelog.'
status=$(git --literal-pathspecs status --porcelain -- "${files[@]}")
[[ -z "$status" ]] ||
    die 'Release files changed during preparation.'
for file in "${files[@]}"; do
    [[ -f "$prepared/$file" && ! -L "$prepared/$file" ]] || die "Missing prepared file: $file"
done
installed=0
for file in "${files[@]}"; do
    if ! mv "$prepared/$file" "$file"; then
        rollback_failed=false
        for ((index=installed-1; index>=0; index--)); do
            restored="${files[index]}"
            mv "$original/$restored" "$restored" || rollback_failed=true
        done
        if [[ "$rollback_failed" == true ]]; then
            trap - EXIT
            die "Could not restore every release file. Backups are in $original."
        fi
        die "Could not replace release file: $file"
    fi
    ((installed+=1))
done
printf 'Prepared %s for PR review.\n' "$next"
