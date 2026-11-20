"""Go test targets and coverage reporting."""

from fixtures import GoProject


class LegacyGoTargetTests(GoProject):
    def test_unit_integration_and_e2e_go_targets(self):
        self.build_project()
        self.include_modules("test")
        self.write(
            "pkg/version/version_test.go",
            'package version\nimport "testing"\n'
            'func TestFixtureUnit(t *testing.T) { if Version != "unset" { t.Fatal(Version) } }\n',
        )
        for directory, tag, test in (
            ("suites", "integration", "TestFixtureIntegration"),
            ("e2e", "e2e", "TestFixtureE2E"),
        ):
            self.write(
                f"test/{directory}/{tag}_test.go",
                f'//go:build {tag}\n// +build {tag}\n\npackage {directory}\n'
                f'import "testing"\nfunc {test}(t *testing.T) {{ t.Log("fixture") }}\n',
            )
        for target in ("test", "test-raw"):
            with self.subTest(target=target):
                output = self.command("make", target)
                self.assertIn("PASS: TestFixtureUnit", output)
                self.assertNotIn("TestFixtureIntegration", output)
                self.assertNotIn("TestFixtureE2E", output)
        self.assertTrue(self.contents("cover.out").startswith("mode: atomic"))
        self.assertIn("PASS: TestFixtureIntegration", self.command("make", "integration-test"))
        self.assertIn("/test/e2e", self.command("make", "e2e-test"))

    def test_integration_and_e2e_targets_allow_absent_suites(self):
        self.include_modules("test")
        self.tool("go", "echo unexpected-go-call >&2\nexit 91\n")
        output = self.command("make", "integration-test", "e2e-test")
        self.assertNotIn("unexpected-go-call", output)
        self.assertFalse((self.project / "cover.out").exists())

    def test_show_coverage_runs_both_suites_and_can_reuse_results(self):
        self.build_project()
        self.include_modules("test", settings="""\
COVERAGE_PACKAGES := example.com/fixture/pkg/version
COVERAGE_PROFILING_DIR := $(CURDIR)/.coverage
UT_COVER_PACKAGES := ./pkg/version
IT_COVER_PACKAGES := ./test/suites/...
""")
        self.write("pkg/version/version.go", """\
package version

func release(ok bool) int {
	if ok {
		return 1
	}
	return 2
}

func Release() int { return release(false) }
""")
        self.write("pkg/version/version_test.go", """\
package version
import "testing"
func TestUnit(t *testing.T) { if release(true) != 1 { t.Fatal("unit path") } }
""")
        self.write("test/suites/coverage_test.go", """\
//go:build integration
// +build integration

package suites
import (
	"testing"
	"example.com/fixture/pkg/version"
)
func TestIntegration(t *testing.T) { if version.Release() != 2 { t.Fatal("integration path") } }
""")
        output = self.command("make", "show-coverage")
        self.assertRegex(output.splitlines()[-1], r"^total:?\s+\(statements\)\s+100\.0%$")
        samples = list((self.project / ".coverage").glob("covcounters.*"))
        self.assertGreaterEqual(len(samples), 2)
        self.assertEqual(self.command("make", "show-coverage", "skip=true").strip(),
                         output.splitlines()[-1])
        self.assertEqual(sorted((self.project / ".coverage").glob("covcounters.*")), sorted(samples))
