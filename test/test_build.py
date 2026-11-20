"""Build, installation, formatting and lint targets."""

import shutil

from fixtures import GoProject


class LegacyBuildTests(GoProject):
    def assert_default_build(self):
        platform = "-".join(self.command("go", "env", "GOOS", "GOARCH").splitlines())
        expected = {
            name
            for target in ("app", "worker")
            for name in (target, f"{target}-{platform}", f"{target}-v1.2.3",
                         f"{target}-{platform}-v1.2.3")
        }
        self.assertEqual({path.name for path in (self.project / "bin").iterdir()}, expected)
        for name in expected:
            self.assertEqual(
                self.command(f"./bin/{name}").strip(), "v1.2.3 abc123 example.com/fixture"
            )

    def test_default_build_and_install(self):
        self.build_project()
        self.command("make", "install", "INSTALL_DIR=./installed")
        self.assert_default_build()
        self.assertEqual(
            self.command("./installed/app").strip(), "v1.2.3 abc123 example.com/fixture"
        )

    def test_standalone_build_with_posix_shell(self):
        shell = shutil.which("dash") or "/bin/sh"
        self.build_project(shell=shell)
        self.command("make", "build")
        self.assert_default_build()

    def test_download_and_clean(self):
        self.build_project()
        self.command("make", "download")
        self.write("bin/artifact", "binary")
        self.command("make", "clean")
        self.assertEqual(list((self.project / "bin").iterdir()), [])
        self.assertTrue((self.project / "cmd/app/main.go").is_file())

    def test_default_format_runs_formatter_imports_and_linter(self):
        self.build_project()
        self.write("pkg/example/example.go", "package example\nfunc F( ) {}\n")
        self.tool("goimports", 'test "$*" = "-w ."\necho ran-imports\n')
        self.tool("golangci-lint", 'test "$*" = "run --fix"\necho ran-linter\n')
        output = self.command("make", "fmt")
        self.assertIn("\nran-imports\n", output)
        self.assertIn("\nran-linter\n", output)
        self.assertIn("func F() {}", self.contents("pkg/example/example.go"))

    def test_default_lint_runs_default_linter_and_tidy(self):
        self.build_project()
        self.write("go.mod", "module example.com/fixture\n\ngo      1.18\n")
        self.tool("golangci-lint", 'test "$*" = "run --timeout 5m"\necho linter-ran\n')
        self.assertIn("linter-ran", self.command("make", "lint"))
        self.assertIn("go 1.18\n", self.contents("go.mod"))

    def test_lint_rejects_malformed_integration_build_tag(self):
        self.build_project()
        self.write("pkg/version/version_integration_test.go", "package version\n")
        self.tool("golangci-lint", "echo ran-linter\n")
        output = self.command("make", "lint", succeeds=False)
        self.assertIn("# ensure integration test", output)
        self.assertNotIn("ran-linter", output)


class BuildOptionTests(GoProject):
    def test_custom_build_output_flags_and_no_variants(self):
        self.build_project()
        self.command(
            "make", "build", "TARGETS=app", "GO_BUILD_OUTPUT=custom output/app",
            "GO_BUILD_COPY_VARIANTS=false", "GO_BUILD_VERBOSE=",
            "GO_BUILD_LDFLAGS=-X example.com/fixture/pkg/version.Version=custom",
        )
        self.assertEqual(self.command("./custom output/app").strip(), "custom unset unset")
        self.assertFalse((self.project / "bin").exists())

    def test_custom_build_output_retains_default_variants(self):
        self.build_project()
        self.command("make", "build", "TARGETS=app", "GO_BUILD_OUTPUT=custom/app")
        self.assertTrue((self.project / "custom/app").is_file())
        self.assertTrue((self.project / "bin/app").is_file())
        self.assertTrue((self.project / "bin/app-v1.2.3").is_file())

    def test_custom_build_output_can_also_be_a_variant(self):
        self.build_project()
        self.command("make", "build", "TARGETS=app", "GO_BUILD_OUTPUT=./bin/app")
        self.assertTrue((self.project / "bin/app-v1.2.3").is_file())
        self.assertEqual(self.command("./bin/app").strip(), "v1.2.3 abc123 example.com/fixture")

    def test_multi_target_build_rejects_collisions_and_supports_distinct_paths(self):
        self.build_project()
        output = self.command(
            "make", "build", "GO_BUILD_OUTPUT=custom/fixed",
            "GO_BUILD_COPY_VARIANTS=false", succeeds=False,
        )
        self.assertIn("Multiple targets use GO_BUILD_OUTPUT custom/fixed", output)
        self.assertFalse((self.project / "custom").exists())
        self.command(
            "make", "build", "GO_BUILD_OUTPUT=custom/$${target}",
            "GO_BUILD_COPY_VARIANTS=false",
        )
        self.assertEqual({file.name for file in (self.project / "custom").iterdir()}, {"app", "worker"})

    def test_build_error_is_not_hidden_by_existing_artifacts(self):
        self.build_project()
        self.command("make", "build")
        self.write("cmd/app/main.go", "package main\nfunc main() { doesNotExist() }\n")
        output = self.command("make", "build", succeeds=False)
        self.assertIn("undefined: doesNotExist", output)

    def test_fmt_respects_source_dirs(self):
        self.build_project()
        unformatted = "package extra\n\nfunc F( ) {}\n"
        self.write("extra/extra.go", unformatted)
        self.write("pkg/inside/inside.go", unformatted.replace("package extra", "package inside"))
        self.tool("goimports", 'test "$*" = "-w pkg"\necho scoped-imports\n')
        self.tool("golangci-lint", "exit 91\n")
        self.assertIn("\nscoped-imports\n", self.command("make", "fmt", "GO_SOURCE_DIRS=pkg"))
        self.assertIn("func F() {}", self.contents("pkg/inside/inside.go"))
        self.assertEqual(self.contents("extra/extra.go"), unformatted)

    def test_read_only_lint_leaves_module_untouched(self):
        self.build_project()
        self.write("unused/go.mod", "module example.com/unused\n\ngo 1.18\n")
        self.write(
            "go.mod",
            self.contents("go.mod") + "\nrequire example.com/unused v0.0.0\n"
            "\nreplace example.com/unused => ./unused\n",
        )
        before = self.contents("go.mod")
        options = ("GO_LINT_READ_ONLY=true", "GO_LINT_COMMAND=echo custom-linter")
        output = self.command("make", "lint", *options, succeeds=False)
        self.assertIn("-require example.com/unused v0.0.0", output)
        self.assertEqual(self.contents("go.mod"), before)
        self.command("go", "mod", "tidy")
        output = self.command("make", "lint", *options)
        self.assertIn("\ncustom-linter\n", output)

    def test_lint_propagates_gofmt_error(self):
        self.build_project()
        output = self.command(
            "make", "lint", "GO_SOURCE_DIRS=missing", "GO_LINT_READ_ONLY=true",
            "GO_LINT_COMMAND=true", succeeds=False,
        )
        self.assertIn("missing", output)
