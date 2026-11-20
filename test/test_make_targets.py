"""Container, generator and help targets."""

from fixtures import ConsumerProject


class LegacyMakeTargetTests(ConsumerProject):
    def test_container_build_and_push_use_each_target_and_registry(self):
        self.include_modules("container", settings="""\
TARGETS := app worker
REGISTRIES := one.invalid/ two.invalid/
IMAGE_PREFIX := edge-
IMAGE_SUFFIX := -cli
VERSION := v1.2.3
COMMIT := abc123
CGO_ENABLED := 0
BUILD_DIR := build
""")
        self.tool("docker-buildx", 'printf "%s\\n" "$*" >> build.log\n')
        self.tool("docker", 'printf "%s\\n" "$*" >> push.log\n')
        self.command("make", "container", "push-container")
        builds = []
        pushes = []
        for target in ("app", "worker"):
            for registry in ("one.invalid", "two.invalid"):
                image = f"{registry}/edge-{target}-cli:v1.2.3"
                builds.append(
                    f"build --provenance=false -t {image} --platform linux/amd64 "
                    f"--build-arg COMMIT=abc123 --build-arg CGO_ENABLED=0 --progress=plain "
                    f"-f build/{target}/Dockerfile ."
                )
                pushes.append(f"push {image}")
        self.assertEqual(self.contents("build.log").splitlines(), builds)
        self.assertEqual(self.contents("push.log").splitlines(), pushes)

    def test_help_lists_included_targets_and_wire_uses_package_directory(self):
        self.include_modules("general", "gen-wire")
        output = self.command("make", "help")
        self.assertIn("Generate wire injection code", output)
        self.assertIn("generate-code-wire", output)
        self.write("pkg/first/wire.go", "package first\n")
        self.write("pkg/second/wire.go", "package second\n")
        self.write("../gopath/bin/wire", "#!/bin/sh\npwd > wire-ran\n", executable=True)
        self.env["GOPATH"] = str(self.root / "gopath")
        self.command("make", "generate-code-wire")
        for directory in ("first", "second"):
            self.assertTrue(self.contents(f"pkg/{directory}/wire-ran").endswith(f"/pkg/{directory}\n"))
