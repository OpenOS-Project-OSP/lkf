# Changelog

All notable changes to lkf are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.1.0] — 2026-03-29

Initial release.

### Added

**Core modules**
- `lkf build` — fetch → extract → patch → configure → compile pipeline;
  `--stop-after` stages, GPG verification, DKMS integration
- `lkf config` — `.config` management: generate, merge, validate, convert, diff
- `lkf patch` — patch set application; `lkf patch fetch` downloads upstream sets
- `lkf remix` — declarative kernel builds from `remix.toml`; TOML parsed via
  `python3 tomllib` / `tomli` with a pure-Bash fallback
- `lkf kbuild` — Kbuild/Kconfig standalone interface: `module`, `config`,
  `defconfig`, `validate`, `symbols`, `info` subcommands
- `lkf xm` — arch × compiler matrix runner with parallel execution and
  summary table; `--dry-run` and `--parallel` flags
- `lkf initrd` — initramfs builder (cpio, debootstrap), symlink management,
  archive inspection
- `lkf image` — EFI unified image, Android boot.img, firmware archive, tarball
- `lkf install` — kernel installation, versioned `/boot` copy, bootloader update
- `lkf debug` — QEMU + GDB debug environment; `--dry-run`, `--gdb-init`,
  `--no-kvm`, custom cmdline and port flags
- `lkf extract` — vmlinux extraction from vmlinuz, EFI, and Android boot.img
- `lkf dkms` — DKMS module install, uninstall, sign
- `lkf profile` — named build profiles; `list`, `show`, `create`, `use`
- `lkf ci` — CI workflow generator for GitHub Actions, GitLab CI, Forgejo Actions

**linux-tkg integration**
- `lkf patch fetch --set tkg` downloads the Frogging-Family/linux-tkg patch stack
- `--flavor tkg` in `lkf build` applies the option-aware tkg patch stack
- Scheduler selection: `bore`, `eevdf`, `cfs`, `bmq`, `pds`; `muqss` falls
  back to `eevdf` with a warning for kernels ≥ 6.0
- `[tkg]` section in `remix.toml` for reproducible tkg builds
- Built-in profiles: `tkg-gaming` (bore + ntsync + llvm), `tkg-bore`,
  `tkg-server`
- Config fragment: `config/profiles/tkg-gaming.config`
  (`CONFIG_NTSYNC`, `HZ_1000`, `PREEMPT`, BBR)

**Patch sets** (via `lkf patch fetch`)
- `aufs` — AUFS union filesystem (Puppy Linux)
- `rt` — PREEMPT_RT real-time patch
- `xanmod` — XanMod performance patches
- `cachyos` — CachyOS scheduler and performance patches
- `tkg` — linux-tkg patch stack (Frogging-Family)

**Profiles** (built-in)
- `desktop`, `server`, `android`, `debug`, `embedded`, `xanmod-desktop`,
  `puppy`, `tkg-gaming`, `tkg-bore`, `tkg-server`

**NixOS support**
- `nix/shell.nix` and `nix/flake.nix` for nix-shell / `nix develop` environments
- `IN_NIX_SHELL` detection in `lkf toolchain install-deps`
- Early NixOS guard in `lkf.sh` with actionable guidance

**CI**
- GitHub Actions workflow (`make check`, ShellCheck, remix dry-run,
  tkg patch fetch validation with `GITHUB_TOKEN` auth)
- `patches/fetch.sh`: `_curl_auth()` helper injects `Authorization` header
  when `GITHUB_TOKEN` is set, raising rate limit from 60 to 5000 req/hour

**Test suite**
- 14 suites, 324 tests (`make check`):
  detect, config, integration, tkg, kbuild, xm, debug, dkms, image,
  initrd, install, toolchain, profile, ci
- `test_initrd.sh` skips cpio-dependent tests gracefully when `cpio` is absent

**Tooling**
- `make check` — run all test suites
- `make lint` — ShellCheck at warning severity across all `.sh` files
- `make lint-install` — install ShellCheck via the official binary release
- `.clang-format` — BasedOnStyle: LLVM with Linux kernel overrides
- `CONTRIBUTING.md` and GitHub issue templates (bug report, feature request)
- `examples/gaming.toml`, `examples/server.toml` — annotated remix descriptors
- `patches/README.md` — patch set documentation including tkg option mapping

**Supported distros**
Debian/Ubuntu, Arch Linux, Fedora/RHEL, Alpine, openSUSE, Gentoo, NixOS

**Supported architectures**
x86_64, aarch64, arm, riscv64

---

[0.1.0]: https://github.com/Interested-Deving-1896/lkf/releases/tag/v0.1.0
