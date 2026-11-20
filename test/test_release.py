"""Version targets, legacy release workflows and PR preparation."""

import os
from pathlib import Path
import shlex
import shutil
import unittest

from fixtures import ReleaseProject, SOURCE


LEGACY_SOURCE = os.environ.get("MAKEFILE_GO_LEGACY_SOURCE")


class LegacyReleaseTests(ReleaseProject):
    def test_default_bump_previews_beta_minor_without_changes(self):
        head = self.release_project()
        output = self.command("make", "bump")
        self.assertIn("Next version    : v1.3.0-beta.1", output)
        self.assertEqual(self.command("git", "rev-parse", "HEAD"), head)
        self.assertEqual(self.command("git", "status", "--porcelain"), "")
        self.assertEqual(self.command("git", "tag"), "")

    def test_legacy_default_bump_overrides_on_command_line(self):
        self.release_project()
        output = self.command(
            "make", "bump", "DEFAULT_BUMP_STAGE=final", "DEFAULT_BUMP_SCOPE=patch",
        )
        self.assertIn("Next version    : v1.2.4\n", output)

    def test_environment_dry_run_does_not_execute_legacy_release(self):
        head = self.release_project()
        self.env.update(DRY_RUN="false", EXPECT_TAG="yes")
        output = self.command("make", "bump-patch")
        self.assertIn("Version Bump Preview", output)
        self.assertEqual(self.command("git", "rev-parse", "HEAD"), head)
        self.assertEqual(self.command("git", "tag"), "")

    def test_default_release_requires_clean_git_status(self):
        self.release_project()
        self.write("untracked.txt", "local edits\n")
        self.assertIn("Git status is not clean", self.command("make", "bump-patch", succeeds=False))

    def test_default_release_writes_versions_commits_tag_and_changelog(self):
        head = self.release_project()
        self.env["EXPECT_TAG"] = "yes"
        self.command("make", "bump-patch", "DEFAULT_BUMP_DRY_RUN=false")
        self.assertEqual(self.command("git", "rev-list", "--count", f"{head.strip()}..HEAD"), "2\n")
        self.assertEqual(self.command("git", "show", "v1.2.4:VERSION"), "v1.2.4\n")
        self.assertEqual(self.command("git", "show", "v1.2.4:release-info.txt"), "v1.2.4\n")
        self.assertEqual(self.contents("VERSION"), "v1.2.4-dev\n")
        self.assertEqual(self.contents("release-info.txt"), "v1.2.4-dev\n")
        self.assertEqual(self.contents("CHANGELOG.md"), "Release v1.2.4\n")
        self.assertEqual(self.command("git", "status", "--porcelain"), "")

    def test_version_and_standalone_changelog(self):
        head = self.release_project()
        self.assertEqual(self.command("make", "version"), "v1.2.3\n")
        self.command("make", "gen-changelog-patch")
        self.assertEqual(self.contents("CHANGELOG.md"), "Release v1.2.4\n")
        self.assertEqual(self.command("git", "status", "--porcelain"), " M CHANGELOG.md\n")
        self.assertEqual(self.command("git", "rev-parse", "HEAD"), head)
        self.assertEqual(self.command("git", "tag"), "")

    def test_submodule_bump_previews_then_tags_only_submodule_version(self):
        self.release_project()
        self.write("worker/VERSION", "v1.2.9-dev\n")
        self.track_fixture_files("worker/VERSION")
        self.command("git", "tag", "worker/v1.2.9")
        self.command("git", "tag", "worker/v1.2.8")
        self.assertIn("Next version    : v1.2.10", self.command(
            "make", "bump-sub", "SUB=worker", "SCOPE=patch",
        ))
        self.assertEqual(self.command("git", "status", "--porcelain"), "")
        self.command("make", "bump-sub", "SUB=worker", "SCOPE=patch", "DRY_RUN=false")
        self.assertEqual(self.command("git", "show", "worker/v1.2.10:worker/VERSION"), "v1.2.10\n")
        self.assertEqual(self.contents("worker/VERSION"), "v1.2.10-dev\n")
        self.assertEqual(self.contents("VERSION"), "v1.2.3\n")
        self.assertEqual(self.command("git", "status", "--porcelain"), "")


class PrepareReleaseTests(ReleaseProject):
    def test_prepare_preview_and_write_from_external_script(self):
        head = self.release_project(submodule=True)
        self.write("untracked.txt", "local edits\n")
        options = ("BUMP_MODE=prepare", "BUMP_PREPARE_FILES=release-info.txt")
        self.assertIn("v1.2.3 -> v1.2.4", self.command("make", "bump-patch", *options))
        self.assertEqual(self.command("git", "status", "--porcelain"), "?? untracked.txt\n")
        self.command("make", "bump-patch", "DRY_RUN=false", *options)
        self.assertEqual(self.contents("VERSION"), "v1.2.4\n")
        self.assertEqual(self.contents("CHANGELOG.md"), "Release v1.2.4\n")
        self.assertEqual(self.contents("release-info.txt"), "v1.2.4\n")
        self.assertEqual(self.command("git", "rev-parse", "HEAD"), head)
        self.assertEqual(self.command("git", "tag"), "")
        self.assertEqual(self.command("git", "diff", "--cached", "--name-only"), "")
        self.assertEqual(self.contents("untracked.txt"), "local edits\n")
        self.assertEqual(list(self.project.glob(".makefile-go-bump.*")), [])

    def test_prepare_changelog_failure_leaves_release_files_untouched(self):
        head = self.release_project(submodule=True)
        self.env["FAIL_CLIFF"] = "yes"
        self.command(
            "make", "bump-patch", "BUMP_MODE=prepare", "DRY_RUN=false",
            "BUMP_PREPARE_FILES=release-info.txt", succeeds=False,
        )
        self.assertEqual(self.command("git", "rev-parse", "HEAD"), head)
        self.assertEqual(self.command("git", "status", "--porcelain"), "")
        self.assertEqual(self.command("git", "tag"), "")

    def test_prepare_duplicate_release_file_does_not_partially_write(self):
        self.release_project(submodule=True)
        output = self.command(
            "make", "bump-patch", "BUMP_MODE=prepare", "DRY_RUN=false",
            "BUMP_PREPARE_FILES=release-info.txt release-info.txt", succeeds=False,
        )
        self.assertIn("Duplicate release file: release-info.txt", output)
        self.assertEqual(self.command("git", "status", "--porcelain"), "", output)

    def test_prepare_rejects_push_and_keeps_dirty_release_file(self):
        head = self.release_project(submodule=True)
        options = ("BUMP_MODE=prepare", "DRY_RUN=false", "BUMP_PREPARE_FILES=release-info.txt")
        self.assertIn("Push the release tag separately", self.command(
            "make", "bump-patch", *options, "PUSH=true", succeeds=False,
        ))
        self.write("VERSION", "local changes\n")
        self.assertIn("Commit or stash changes", self.command(
            "make", "bump-patch", *options, succeeds=False,
        ))
        self.assertEqual(self.contents("VERSION"), "local changes\n")
        self.assertEqual(self.contents("CHANGELOG.md"), "Previous release\n")
        self.assertEqual(self.command("git", "rev-parse", "HEAD"), head)
        self.assertEqual(self.command("git", "tag"), "")

    def test_prepare_rolls_back_if_copy_back_fails(self):
        self.release_project(submodule=True)
        real_mv = shutil.which("mv")
        self.tool("mv", 'case "$1" in */prepared/release-info.txt) exit 91 ;; esac\n'
                  f'exec {shlex.quote(real_mv)} "$@"\n')
        output = self.command(
            "make", "bump-patch", "BUMP_MODE=prepare", "DRY_RUN=false",
            "BUMP_PREPARE_FILES=release-info.txt", succeeds=False,
        )
        self.assertIn("Could not replace release file: release-info.txt", output)
        self.assertEqual(self.command("git", "status", "--porcelain"), "")
        self.assertEqual(list(self.project.glob(".makefile-go-bump.*")), [])

    def test_prepare_runs_executable_hook_with_its_shebang(self):
        self.release_project(submodule=True)
        self.write(
            "hack/bump-post-actions.sh",
            "#!/usr/bin/env python3\n"
            "import os\nfrom pathlib import Path\n"
            'root = Path(os.environ["BUMP_PREPARE_DIR"])\n'
            '(root / "release-info.txt").write_text((root / "VERSION").read_text())\n',
            executable=True,
        )
        self.track_fixture_files("hack/bump-post-actions.sh")
        self.command(
            "make", "bump-patch", "BUMP_MODE=prepare", "DRY_RUN=false",
            "BUMP_PREPARE_FILES=release-info.txt",
        )
        self.assertEqual(self.contents("release-info.txt"), "v1.2.4\n")

    def test_bundled_prepare_hook_changes_package_json_only_after_success(self):
        self.release_project(submodule=True)
        shutil.copy2(SOURCE / "hack/bump-post-actions.sh", self.project / "hack/bump-post-actions.sh")
        self.write("package.json", '{"version":"1.2.3"}\n')
        self.track_fixture_files("hack/bump-post-actions.sh", "package.json")
        self.tool("jq", """\
test "$3" = '.version="1.2.4"'
test "$(cat)" = '{"version":"1.2.3"}'
printf '%s\\n' '{"version":"1.2.4"}'
""")
        self.tool("sponge", 'cat > "$1"\n')
        options = ("BUMP_MODE=prepare", "DRY_RUN=false")
        output = self.command("make", "bump-patch", *options, succeeds=False)
        self.assertIn("Include package.json in BUMP_PREPARE_FILES", output)
        self.env["FAIL_CLIFF"] = "yes"
        self.command("make", "bump-patch", *options, "BUMP_PREPARE_FILES=package.json", succeeds=False)
        self.assertEqual(self.command("git", "status", "--porcelain"), "")
        del self.env["FAIL_CLIFF"]
        self.command("make", "bump-patch", *options, "BUMP_PREPARE_FILES=package.json")
        self.assertEqual(self.contents("package.json"), '{"version":"1.2.4"}\n')

    @unittest.skipUnless(LEGACY_SOURCE, "set MAKEFILE_GO_LEGACY_SOURCE to test mixed versions")
    def test_prepare_with_legacy_bump_script_cannot_release(self):
        head = self.release_project(scripts_source=Path(LEGACY_SOURCE))
        self.env["EXPECT_TAG"] = "yes"
        self.write("local.txt", "unrelated changes\n")
        output = self.command(
            "make", "bump-patch", "BUMP_MODE=prepare", "DRY_RUN=false",
            succeeds=False,
        )
        self.assertEqual(self.command("git", "rev-parse", "HEAD"), head, output)
        self.assertEqual(self.command("git", "tag"), "", output)
        self.assertEqual(self.command("git", "status", "--porcelain"), "?? local.txt\n", output)
