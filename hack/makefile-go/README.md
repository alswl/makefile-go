# makefile-go

A batteries-included Makefile toolkit for Go projects.
Covers build, test, code generation, versioning, containerization.

Do NOT edit any files in this directory.

Synced from https://github.com/alswl/makefile-go.

## Usage

1. Copy this directory into your project's `hack/`
2. Copy `sample.mk` from the repo root as your `Makefile`
3. Replace the `your-` placeholders

Run `make help` to see all available targets.

## Install Target

`make install` installs binaries to PATH. When `INSTALL_DIR` is unset, auto-detects
the first writable directory:

1. `/opt/homebrew/bin` (Apple Silicon Mac)
2. `$HOME/.local/bin`
3. `/usr/local/bin`
4. `$GOPATH/bin`
5. `$HOME/go/bin`

```shell
make install                              # auto-detect
make install INSTALL_DIR=/usr/local/bin   # explicit
```

## CLI Install Script

`hack/install.template.sh` — copy and replace `__GITHUB_REPO__` and `__BINARY_NAME__`.

```shell
curl -sSL https://raw.githubusercontent.com/<user>/<repo>/main/hack/install.sh | sh
```

## Bump Scripts

| Script                      | Purpose                                    |
|-----------------------------|--------------------------------------------|
| `hack/bump.sh`              | Project version bump (`semtag` + `git-cliff`) |
| `hack/bump-sub-mod.sh`     | Sub-module version bump                    |
| `hack/gen-changelog.sh`     | Standalone CHANGELOG generation            |

### Build configuration

`GO_BUILD_OUTPUT` sets the binary path. Set `GO_BUILD_COPY_VARIANTS=false`
when the build should only write that path. For multiple targets, include
`$${target}` in the Make value, for example `GO_BUILD_OUTPUT = dist/$${target}`.
`GO_BUILD_LDFLAGS` and
`GO_BUILD_VERBOSE` override the default linker flags and verbosity.
`GO_SOURCE_DIRS` scopes `gofmt` and `goimports`. The project-wide
`go fmt ./...` and `golangci-lint run --fix` steps run with the default
scope of `.`. Set `GO_LINT_READ_ONLY=true` to
check module tidiness without rewriting sources or module files, and
set `GO_LINT_COMMAND` to use a project-specific linter.

### Preparing a release for a pull request

Set `BUMP_MODE=prepare` in the project Makefile. `make bump-patch` previews
the next version. With `DRY_RUN=false`, it uses git-cliff to update the
existing `VERSION` and `CHANGELOG.md`, without staging, committing, tagging,
or pushing. The default `release` mode retains the original bump behavior.

List any additional existing files the post-action updates in
`BUMP_PREPARE_FILES` as space-separated repository-relative paths. In
prepare mode, the post-action must read and write these files relative to
`BUMP_PREPARE_DIR`. The bundled post-action requires `package.json` in that list.
Changes are copied back after the post-action and
changelog generation succeed. Projects including these modules through a
submodule can set `BUMP_SCRIPT` to its `hack/bump.sh`; the Make target passes
the consuming project's root. When copying the scripts into a project,
update `hack/bump.sh` and copy `hack/bump-prepare.sh` alongside it.

### Installing a release archive

The existing `install.template.sh` still installs bare release binaries.
For checksum-verified archives, generate a standalone POSIX installer with
`sh hack/render-install.sh PROJECT_CONFIG > install.sh`. The project
configuration sets `repo` (owner/repository) and `binary_name`. It can also
set `requested_version`, `version_variable` (for diagnostics) and
`install_dir` from the project's existing environment variables.

The archive convention is `NAME-TAG-SUFFIX.tar.gz`, containing the regular
file `NAME-SUFFIX`, with SHA-256 listed in `checksums.txt`. An optional
`asset_suffix GOOS GOARCH` function supplies a custom suffix. An optional
`validate_candidate PATH EXPECTED_VERSION` hook can reject the staged
executable before replacement. An optional `install_source ROOT [ARGS...]`
hook handles checkout installs and may call `install_verified`.

### Packaging release archives

Source `hack/package-release.sh` from a Bash project script and call
`package_release TAG OUTPUT BINARY GOOS:GOARCH:SUFFIX [...]`. The script
runs the project's Make build with `TARGETS=BINARY` for each platform. It
packages one binary per archive and publishes the output directory after
every build and hook succeeds. Use a `vMAJOR.MINOR.PATCH` tag, with optional
prerelease and build metadata, as expected by the archive installer.

Projects may define `package_before STAGING TAG`,
`package_verify STAGING BINARY GOOS GOARCH SUFFIX`, and
`package_after STAGING TAG` to record or check project metadata. Hooks run
inside the release subshell and can share state. Return a nonzero status
from a hook to abort packaging. `package_build GOOS GOARCH PATH`
also works for an optional native probe. `package_sha256 FILE` prints its SHA-256.

### Distribution Make targets

Include `distribution.mk` to expose `make package`, `make generate-installer`
and `make check-installer`. It discovers the helper scripts alongside the
included modules, including when the modules live in a Git submodule.

Set `PACKAGE_TARGETS` to the space-separated `GOOS:GOARCH:SUFFIX` matrix.
`PACKAGE_BINARY` defaults to the first `TARGETS` entry. `PACKAGE_TAG` defaults
to `VERSION`, and `PACKAGE_OUT` to `release/<tag>`. Point `PACKAGE_HOOKS` at
a project shell file defining the optional verification hooks.

`make generate-installer` renders `INSTALLER_PROJECT` (default
`hack/install-project.sh`) to `INSTALLER_OUTPUT` (default `hack/install.sh`).
Include `check-installer` in the project check target to detect a stale
generated installer.
