import hashlib
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

from fixtures import GoProject

HACK = Path(__file__).resolve().parents[1] / "hack"


class ArchiveInstallTests(unittest.TestCase):
    def test_standalone_install_preserves_existing_binary_on_rejection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            dest = root / "install dir"
            dest.mkdir()
            installed = dest / "demo"
            installed.write_text("existing binary\n")
            stubs = root / "stubs"
            stubs.mkdir()
            curl = stubs / "curl"
            curl.write_text(
                "#!/bin/sh\nset -eu\n"
                "while [ \"$#\" -gt 0 ]; do case \"$1\" in\n"
                "  https://*) asset=${1##*/} ;; -o) out=$2; shift ;;\n"
                "  --retry|--retry-delay) shift ;; esac; shift; done\n"
                'cp "$FIXTURES/$asset" "$out"\n'
            )
            curl.chmod(0o755)
            config = root / "project.sh"
            config.write_text(
                "repo=example/demo\nbinary_name=demo\nrequested_version=v1.2.3\n"
                'install_dir="$DEST"\nasset_suffix() { echo fixture; }\n'
                'validate_candidate() { [ "$("$1")" = "$2" ]; }\n'
            )
            (root / "Makefile").write_text(
                f"include {HACK / 'makefile-go/distribution.mk'}\n"
                "INSTALLER_PROJECT := project.sh\nINSTALLER_OUTPUT := install.sh\n"
            )
            subprocess.run(["make", "generate-installer", "check-installer"], cwd=root, check=True)
            script = (root / "install.sh").read_bytes()
            asset = root / "demo-v1.2.3-fixture.tar.gz"
            checksums = root / "checksums.txt"
            env = dict(os.environ, PATH=f"{stubs}:{os.environ['PATH']}", DEST=str(dest), FIXTURES=str(root))

            def prepare(version, *, symlink=False):
                binary = f"#!/bin/sh\necho {version}\n".encode()
                with tarfile.open(asset, "w:gz") as archive:
                    member = tarfile.TarInfo("demo-fixture")
                    if symlink:
                        member.type = tarfile.SYMTYPE
                        member.linkname = "/bin/sh"
                        archive.addfile(member)
                    else:
                        member.size = len(binary)
                        archive.addfile(member, io.BytesIO(binary))
                digest = hashlib.sha256(asset.read_bytes()).hexdigest()
                checksums.write_text(f"{digest}  {asset.name}\n")
                return binary

            for fault, message in [
                ("checksum", b"Checksum mismatch"),
                ("version", b"Candidate validation failed"),
                ("symlink", b"not a unique regular file"),
            ]:
                with self.subTest(fault=fault):
                    prepare("v9.0.0" if fault == "version" else "v1.2.3", symlink=fault == "symlink")
                    if fault == "checksum":
                        checksums.write_text(f"{'0' * 64}  {asset.name}\n")
                    run = subprocess.run(["sh"], input=script, cwd=root, env=env, capture_output=True)
                    self.assertNotEqual(run.returncode, 0)
                    self.assertIn(message, run.stderr)
                    self.assertEqual(installed.read_text(), "existing binary\n")
                    self.assertEqual(list(dest.iterdir()), [installed])
            binary = prepare("v1.2.3")
            subprocess.run(["sh"], input=script, cwd=root, env=env, capture_output=True, check=True)
            self.assertEqual(installed.read_bytes(), binary)


class ArchivePackageTests(unittest.TestCase):
    def test_late_validation_failure_leaves_no_partial_archives(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "VERSION").write_text("v1.2.3\n")
            (root / "Makefile").write_text(
                'build:\n\t@printf "%s/%s\\n" "$$GOOS" "$$GOARCH" > "$(GO_BUILD_OUTPUT)"\n'
                f"include {HACK / 'makefile-go/distribution.mk'}\n"
                "TARGETS := demo\n"
                "PACKAGE_TARGETS := linux:amd64:first darwin:arm64:second\n"
                "PACKAGE_HOOKS := release.sh\n"
            )
            hooks = root / "release.sh"
            hooks.write_text('package_verify() { [[ "$5" != second ]]; }\n')
            run = subprocess.run(["make", "package", "PACKAGE_OUT=archives"], cwd=root, capture_output=True)
            self.assertNotEqual(run.returncode, 0)
            self.assertIn(b"Building second", run.stdout)
            self.assertCountEqual(root.iterdir(), [root / "Makefile", root / "VERSION", hooks])

            guarded = subprocess.run(
                [
                    "bash", "-c",
                    'source "$1"; source ./release.sh; '
                    'if package_release v1.2.3 archives demo linux:amd64:first darwin:arm64:second; '
                    'then exit 0; else exit 1; fi',
                    "test-package", str(HACK / "package-release.sh"),
                ],
                cwd=root, capture_output=True,
            )
            self.assertEqual(guarded.returncode, 1)
            self.assertIn(b"package_verify failed for demo-second", guarded.stderr)
            self.assertCountEqual(root.iterdir(), [root / "Makefile", root / "VERSION", hooks])

            hooks.write_text('package_verify() { [[ -s "$2" ]]; }\n')
            subprocess.run(["make", "package", "PACKAGE_OUT=archives"], cwd=root, capture_output=True, check=True)
            self.assertEqual(
                sorted(p.name for p in (root / "archives").iterdir()),
                ["checksums.txt", "demo-v1.2.3-first.tar.gz", "demo-v1.2.3-second.tar.gz"],
            )


class DistributionBuildTests(GoProject):
    def test_package_builds_only_the_selected_binary_and_requires_an_installable_tag(self):
        self.build_project()
        self.write("cmd/worker/main.go", 'package main\nimport "fmt"\nfunc main() { fmt.Println("worker") }\n')
        self.include_modules("distribution")
        os_name = self.command("go", "env", "GOOS").strip()
        arch = self.command("go", "env", "GOARCH").strip()
        suffix = f"{os_name}-{arch}"
        args = ("make", "package", "PACKAGE_BINARY=worker", f"PACKAGE_TARGETS={os_name}:{arch}:{suffix}")

        output = self.command(*args, "PACKAGE_TAG=nightly", succeeds=False)
        self.assertIn("Invalid release tag: nightly", output)
        self.assertFalse((self.project / "release").exists())

        tag = "v1.2.3-rc.1+build.2"
        self.command(*args, f"PACKAGE_TAG={tag}")
        asset = self.project / f"release/{tag}/worker-{tag}-{suffix}.tar.gz"
        with tarfile.open(asset) as archive:
            member = f"worker-{suffix}"
            self.assertEqual(archive.getnames(), [member])
            binary = self.project / member
            binary.write_bytes(archive.extractfile(member).read())
            binary.chmod(0o755)
        self.assertEqual(self.command(str(binary)).strip(), "worker")
