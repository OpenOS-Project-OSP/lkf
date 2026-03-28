# Contributing to lkf

## Getting started

```sh
git clone https://github.com/Interested-Deving-1896/lkf
cd lkf
make check   # run the test suite before making changes
```

## What belongs here

lkf is a distro-agnostic, arch-agnostic shell framework for building,
patching, and packaging Linux kernels. Contributions should stay within
that scope:

- New distro support in `core/toolchain.sh` (package manager detection,
  dependency installation)
- New architecture support in `core/detect.sh` and `core/build.sh`
- New patch sets in `patches/` with fetch support in `patches/fetch.sh`
- New output formats in `core/image.sh`
- New CI providers in `ci/ci.sh`
- Bug fixes and test coverage improvements

## Code style

- Bash 4.2+ compatible (no `mapfile -d`, no `&>>`)
- 4-space indentation, no tabs
- Functions named `module_verb` (e.g. `build_stage_extract`, `config_apply`)
- Use `lkf_die`, `lkf_warn`, `lkf_info`, `lkf_step` from `core/lib.sh`
  for all user-facing output — never `echo` directly in module code
- Keep modules self-contained: source only what you need, avoid globals
  except the documented `LKF_*` variables

## Adding a new distro

1. Add detection in `core/detect.sh` → `detect_distro()`
2. Add package names in `core/toolchain.sh` → `toolchain_install_deps()`
3. Add a test case in `tests/test_detect.sh`

## Adding a new patch set

1. Add a fetch function in `patches/fetch.sh` following the existing pattern
2. Add application logic in `core/patch.sh` → `patch_apply_set()`
3. Document the source URL in `patches/README.md`

## Tests

All changes must pass `make check`. New features should include tests in
`tests/`. The test files follow the pattern in `tests/test_detect.sh`:
plain Bash with `assert_eq` / `assert_nonempty` helpers, no external
test framework required.

```sh
make check
```

## Submitting changes

1. Fork the repository
2. Create a branch: `git checkout -b my-feature`
3. Make changes and ensure `make check` passes
4. Open a pull request with a clear description of what changed and why

## Reporting bugs

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).
Include the output of `lkf --version` and the full command you ran.
