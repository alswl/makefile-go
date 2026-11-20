# makefile-go tests

Run the Python standard-library suite from the repository root.

```sh
python3 -B -m unittest discover -s test -v
```

Use Python 3.8+, GNU Make, Bash, Git, and Go 1.23+ with race-detector
support. Dash is used for the POSIX shell case when it is available. The
tests create temporary consumer projects. They use the real Go toolchain
and local Git operations, with substitutes for deployment and release tools.

The suite is split by target.

- `test_build.py` covers build, install, download, clean, formatting and lint.
- `test_go_targets.py` covers Go unit, integration and E2E targets and coverage reports.
- `test_release.py` covers version, changelog, submodule bump, release and PR preparation.
- `test_make_targets.py` covers container commands, code generation and help.
- `fixtures.py` provides temporary consumer projects and tool substitutes.

Run one file with `python3 -B -m unittest discover -s test -p test_build.py -v`.

To compare with the pre-prepare commit, extract its tree and run the
original behavior tests first. Then run the full suite with that same
snapshot as the source of the legacy release helper.

```sh
baseline=$(mktemp -d)
git archive 79641c2 | tar -xf - -C "$baseline"
MAKEFILE_GO_SOURCE="$baseline" \
  python3 -B -m unittest discover -s test -k Legacy -v
MAKEFILE_GO_LEGACY_SOURCE="$baseline" \
  python3 -B -m unittest discover -s test -v
```
