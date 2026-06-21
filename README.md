# makefile-go

A batteries-included Makefile toolkit for Go projects.
Covers build, test, code generation, versioning, containerization.

## Features

- **Modular** — each `.mk` is self-contained, include only what you need
- **Multi-target** — build multiple binaries from a single project
- **Cross-platform** — darwin/linux, amd64/arm64
- **Docker Buildx** — modern multi-platform container builds
- **Version bump** — semtag integration with optional changelog (git-cliff)
- **Auto-detect** — install directory, VERSION, platform
- **Template-driven** — copy `sample.mk`, replace placeholders, ready to go

## Quick Start

```shell
mkdir -p your-project/hack
cp -r hack/makefile-go your-project/hack/
cp sample.mk your-project/Makefile
# edit Makefile, replace your- placeholders
```

## Files

| File                                   | Purpose                                    |
|----------------------------------------|--------------------------------------------|
| `sample.mk`                            | Makefile template                          |
| `hack/makefile-go/`                    | Core modules (do not edit)                 |
| `hack/bump.sh`                         | Version bump (semtag)                      |
| `hack/bump-sub-mod.sh`                 | Sub-module version bump                    |
| `hack/gen-changelog.sh`                | CHANGELOG generation (git-cliff)           |
| `hack/install.template.sh`             | CLI install script for GitHub Releases     |

Run `make help` to see all available targets.
