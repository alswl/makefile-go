"""Temporary consumer projects and local tool substitutes."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(
    os.environ.get("MAKEFILE_GO_SOURCE", Path(__file__).resolve().parents[1])
).resolve()


class ConsumerProject(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.tools = self.root / "tools"
        self.tools.mkdir()
        self.project = self.root / "project"
        self.project.mkdir()
        self.env = os.environ.copy()
        for name in tuple(self.env):
            if name.startswith("GIT_"):
                del self.env[name]
        for name in (
            "MAKEFLAGS", "MFLAGS", "GNUMAKEFLAGS", "MAKEFILES", "BUMP_MODE",
            "BUMP_PROJECT_ROOT", "BUMP_PREPARE_FILES", "SCOPE", "STAGE",
            "BUMP_SCRIPT", "BUMP_PREPARE_DIR", "POST_ACTIONS_SCRIPT",
            "DRY_RUN", "PUSH", "EXPECT_TAG", "FAIL_CLIFF", "GOOS", "GOARCH",
            "GO_BUILD_OUTPUT", "GO_BUILD_COPY_VARIANTS", "GO_BUILD_LDFLAGS",
            "GO_BUILD_VERBOSE", "GO_SOURCE_DIRS", "GO_LINT_READ_ONLY", "GO_LINT_COMMAND",
        ):
            self.env.pop(name, None)
        self.env.update(
            PATH=f"{self.tools}{os.pathsep}{self.env['PATH']}",
            GIT_CONFIG_NOSYSTEM="1",
            GIT_CONFIG_GLOBAL=os.devnull,
            GOENV="off",
            GOFLAGS="",
            GOWORK="off",
            GOTOOLCHAIN="local",
        )

    def command(self, *args, succeeds=True):
        result = subprocess.run(
            args, cwd=self.project, env=self.env, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120,
        )
        message = f"{shlex.join(args)} exited {result.returncode}\n{result.stdout}"
        if succeeds:
            self.assertEqual(result.returncode, 0, message)
        else:
            self.assertNotEqual(result.returncode, 0, message)
        return result.stdout

    def write(self, name, content, executable=False):
        path = self.project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        if executable:
            path.chmod(0o755)

    def tool(self, name, script):
        self.write(f"../tools/{name}", "#!/bin/sh\nset -eu\n" + script, executable=True)

    def include_modules(self, *names, settings=""):
        makefile = self.project / "Makefile"
        with makefile.open("a", encoding="utf-8") as stream:
            stream.write(settings)
            for name in names:
                stream.write(f"include {SOURCE}/hack/makefile-go/{name}.mk\n")

    def contents(self, file):
        return (self.project / file).read_text(encoding="utf-8")


class GoProject(ConsumerProject):
    def build_project(self, shell="/bin/bash"):
        self.write("Makefile", f"""\
SHELL := {shell}
ROOT := example.com/fixture
TARGETS := app worker
CMD_DIR := ./cmd
OUTPUT_DIR := ./bin
VERSION := v1.2.3
COMMIT := abc123
GOOS := $(shell go env GOOS)
GOARCH := $(shell go env GOARCH)
GO_BUILD_TAGS := fixture
include {SOURCE}/hack/makefile-go/build.mk
include {SOURCE}/hack/makefile-go/install.mk
""")
        self.write("go.mod", "module example.com/fixture\n\ngo 1.18\n")
        self.write("pkg/version/version.go", """\
package version

var Version = "unset"
var Commit = "unset"
var Package = "unset"
""")
        for target in ("app", "worker"):
            self.write(f"cmd/{target}/main.go", """\
//go:build fixture
// +build fixture

package main

import (
	"fmt"

	"example.com/fixture/pkg/version"
)

func main() {
	fmt.Println(version.Version, version.Commit, version.Package)
}
""")


class ReleaseProject(ConsumerProject):
    def release_project(self, submodule=False, scripts_source=SOURCE):
        scripts = self.project / ("vendor/makefile-go/hack" if submodule else "hack")
        scripts.mkdir(parents=True)
        for name in ("bump.sh", "bump-prepare.sh", "bump-sub-mod.sh", "gen-changelog.sh"):
            source = scripts_source / "hack" / name
            if source.exists():
                shutil.copy2(source, scripts / name)
        bump_script = f"BUMP_SCRIPT := ./{scripts.relative_to(self.project)}/bump.sh\n" if submodule else ""
        self.write("Makefile", f"""\
{bump_script}include {SOURCE}/hack/makefile-go/_git.mk
include {SOURCE}/hack/makefile-go/version.mk
""")
        self.write("VERSION", "v1.2.3\n")
        self.write("CHANGELOG.md", "Previous release\n")
        if submodule:
            self.write("release-info.txt", "v1.2.3\n")
            self.write(
                "hack/bump-post-actions.sh",
                'set -eu\ncp "$BUMP_PREPARE_DIR/VERSION" "$BUMP_PREPARE_DIR/release-info.txt"\n',
            )
        else:
            self.write(
                "hack/bump-post-actions.sh",
                "#!/bin/sh\nset -eu\ncp VERSION release-info.txt\n",
                executable=True,
            )
        self.tool("semtag", """\
test "$2" = -s
case "$1:$3" in
    final:patch) next=v1.2.4 ;;
    final:minor) next=v1.3.0 ;;
    beta:minor) next=v1.3.0-beta.1 ;;
    *) echo "Unexpected semtag stage and scope: $1 $3" >&2; exit 2 ;;
esac
if [ "${4:-}" = -f ] && [ "${5:-}" = -o ]; then
    printf '%s\n' "$next"
else
    test "${EXPECT_TAG:-}" = yes
    git tag "$next"
fi
""")
        self.tool("git-cliff", """\
case "$1" in -t|--tag) ;; *) exit 2 ;; esac
case "$3" in
    --latest) printf 'Release %s\n' "$2" ;;
    -o|--output) printf 'Release %s\n' "$2" > "$4" ;;
    *) exit 2 ;;
esac
test "${FAIL_CLIFF:-}" != yes
""")
        self.command("git", "init", "-q")
        self.command("git", "config", "user.name", "Test")
        self.command("git", "config", "user.email", "test@example.invalid")
        self.command("git", "add", ".")
        self.command("git", "commit", "-qm", "Fixture")
        return self.command("git", "rev-parse", "HEAD")

    def track_fixture_files(self, *paths):
        self.command("git", "add", *paths)
        self.command("git", "commit", "-qm", "Update fixture")
