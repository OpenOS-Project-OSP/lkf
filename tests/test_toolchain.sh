#!/usr/bin/env bash
# tests/test_toolchain.sh - Tests for lkf toolchain (core/toolchain.sh)
#
# Covers:
#   1.  _DEPS_APT map contains expected core packages
#   2.  _DEPS_PACMAN map contains expected core packages
#   3.  _DEPS_DNF map contains expected core packages
#   4.  _DEPS_APK map contains expected core packages
#   5.  _DEPS_ZYPPER map contains expected core packages
#   6.  _DEPS_EMERGE map contains expected core packages
#   7.  _DEPS_XBPS map contains expected core packages
#   8.  _DEPS_EOPKG map contains expected core packages
#   9.  _DEPS_LLVM_APT map contains clang, llvm, lld
#  10.  _DEPS_LLVM_PACMAN map contains clang, llvm, lld
#  11.  _DEPS_LLVM_ZYPPER map contains clang, llvm, lld
#  12.  _DEPS_LLVM_EMERGE map contains clang, llvm, lld atoms
#  13.  _DEPS_LLVM_XBPS map contains clang, llvm, lld
#  14.  _DEPS_LLVM_EOPKG map contains clang, llvm, lld
#  15.  _DEPS_DEBUG_APT map contains qemu and gdb entries
#  16.  toolchain_install_deps: nix path prints guidance when not in nix-shell
#  17.  toolchain_install_deps: nix path detects IN_NIX_SHELL and skips install
#  18.  toolchain_install_deps: unknown pm warns and exits 0
#  19.  toolchain_install_deps: xbps path emits xbps-install
#  20.  toolchain_install_deps: eopkg path emits eopkg
#  21.  toolchain_install_cross: apt/aarch64 emits correct package name
#  22.  toolchain_install_cross: apt/arm emits correct package name
#  23.  toolchain_install_cross: apt/riscv64 emits correct package name
#  24.  toolchain_install_cross: pacman/aarch64 emits correct package name
#  25.  toolchain_install_cross: pacman/riscv64 emits correct package name
#  26.  toolchain_install_cross: dnf/aarch64 emits correct package name
#  27.  toolchain_install_cross: zypper/aarch64 emits correct package name
#  28.  toolchain_install_cross: xbps/aarch64 emits correct package name
#  29.  toolchain_install_cross: emerge/aarch64 emits correct atom
#  30.  toolchain_install_cross: unknown arch warns
#  31.  toolchain_install_llvm: zypper path emits zypper
#  32.  toolchain_install_llvm: xbps path emits xbps-install
#  33.  toolchain_install_llvm: eopkg path emits eopkg
#  34.  toolchain_install_llvm: unknown pm warns

set -euo pipefail

LKF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/lib.sh"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/detect.sh"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/toolchain.sh"

pass=0; fail=0
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_TEST}"' EXIT

echo "=== test_toolchain.sh ==="

ok()        { echo "  PASS: $1"; pass=$(( pass + 1 )); }
fail_test() { echo "  FAIL: $1"; fail=$(( fail + 1 )); }

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then ok "${desc}"
    else fail_test "${desc} — '${needle}' not found"; fi
}

assert_exits_zero() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "${desc}"
    else fail_test "${desc} — expected zero exit"; fi
}

# ── 1-8: dependency maps ──────────────────────────────────────────────────────
echo ""
echo "-- dependency maps --"

apt_vals="${_DEPS_APT[*]}"
assert_contains "_DEPS_APT: gcc"           "gcc"           "${apt_vals}"
assert_contains "_DEPS_APT: make"          "make"          "${apt_vals}"
assert_contains "_DEPS_APT: bison"         "bison"         "${apt_vals}"
assert_contains "_DEPS_APT: libssl-dev"    "libssl-dev"    "${apt_vals}"
assert_contains "_DEPS_APT: python3"       "python3"       "${apt_vals}"

pacman_vals="${_DEPS_PACMAN[*]}"
assert_contains "_DEPS_PACMAN: gcc"        "gcc"           "${pacman_vals}"
assert_contains "_DEPS_PACMAN: base-devel" "base-devel"    "${pacman_vals}"

dnf_vals="${_DEPS_DNF[*]}"
assert_contains "_DEPS_DNF: gcc"           "gcc"           "${dnf_vals}"
assert_contains "_DEPS_DNF: bison"         "bison"         "${dnf_vals}"

apk_vals="${_DEPS_APK[*]}"
assert_contains "_DEPS_APK: build-base"    "build-base"    "${apk_vals}"
assert_contains "_DEPS_APK: gcc"           "gcc"           "${apk_vals}"

zypper_vals="${_DEPS_ZYPPER[*]}"
assert_contains "_DEPS_ZYPPER: gcc"        "gcc"           "${zypper_vals}"
assert_contains "_DEPS_ZYPPER: bison"      "bison"         "${zypper_vals}"
assert_contains "_DEPS_ZYPPER: ncurses-devel" "ncurses-devel" "${zypper_vals}"

emerge_vals="${_DEPS_EMERGE[*]}"
assert_contains "_DEPS_EMERGE: sys-devel/gcc"  "sys-devel/gcc"  "${emerge_vals}"
assert_contains "_DEPS_EMERGE: dev-vcs/git"    "dev-vcs/git"    "${emerge_vals}"
assert_contains "_DEPS_EMERGE: dev-libs/openssl" "dev-libs/openssl" "${emerge_vals}"

xbps_vals="${_DEPS_XBPS[*]}"
assert_contains "_DEPS_XBPS: gcc"         "gcc"           "${xbps_vals}"
assert_contains "_DEPS_XBPS: base-devel"  "base-devel"    "${xbps_vals}"
assert_contains "_DEPS_XBPS: openssl-devel" "openssl-devel" "${xbps_vals}"

eopkg_vals="${_DEPS_EOPKG[*]}"
assert_contains "_DEPS_EOPKG: system.devel" "system.devel" "${eopkg_vals}"
assert_contains "_DEPS_EOPKG: gcc"          "gcc"          "${eopkg_vals}"

# ── 9-14: LLVM dep maps ───────────────────────────────────────────────────────
echo ""
echo "-- LLVM dep maps --"

llvm_apt_vals="${_DEPS_LLVM_APT[*]}"
assert_contains "_DEPS_LLVM_APT: clang"    "clang"  "${llvm_apt_vals}"
assert_contains "_DEPS_LLVM_APT: llvm"     "llvm"   "${llvm_apt_vals}"
assert_contains "_DEPS_LLVM_APT: lld"      "lld"    "${llvm_apt_vals}"

llvm_pacman_vals="${_DEPS_LLVM_PACMAN[*]}"
assert_contains "_DEPS_LLVM_PACMAN: clang" "clang"  "${llvm_pacman_vals}"
assert_contains "_DEPS_LLVM_PACMAN: lld"   "lld"    "${llvm_pacman_vals}"

llvm_zypper_vals="${_DEPS_LLVM_ZYPPER[*]}"
assert_contains "_DEPS_LLVM_ZYPPER: clang" "clang"  "${llvm_zypper_vals}"
assert_contains "_DEPS_LLVM_ZYPPER: lld"   "lld"    "${llvm_zypper_vals}"

llvm_emerge_vals="${_DEPS_LLVM_EMERGE[*]}"
assert_contains "_DEPS_LLVM_EMERGE: sys-devel/clang" "sys-devel/clang" "${llvm_emerge_vals}"
assert_contains "_DEPS_LLVM_EMERGE: sys-devel/lld"   "sys-devel/lld"   "${llvm_emerge_vals}"

llvm_xbps_vals="${_DEPS_LLVM_XBPS[*]}"
assert_contains "_DEPS_LLVM_XBPS: clang"   "clang"  "${llvm_xbps_vals}"
assert_contains "_DEPS_LLVM_XBPS: lld"     "lld"    "${llvm_xbps_vals}"

llvm_eopkg_vals="${_DEPS_LLVM_EOPKG[*]}"
assert_contains "_DEPS_LLVM_EOPKG: clang"  "clang"  "${llvm_eopkg_vals}"
assert_contains "_DEPS_LLVM_EOPKG: lld"    "lld"    "${llvm_eopkg_vals}"

# ── 15: debug dep maps ────────────────────────────────────────────────────────
echo ""
echo "-- debug dep maps --"

debug_apt_vals="${_DEPS_DEBUG_APT[*]}"
assert_contains "_DEPS_DEBUG_APT: qemu"    "qemu"   "${debug_apt_vals}"
assert_contains "_DEPS_DEBUG_APT: gdb"     "gdb"    "${debug_apt_vals}"

# ── 16-20: toolchain_install_deps special paths ───────────────────────────────
echo ""
echo "-- toolchain_install_deps special paths --"

# Stub sudo to capture invocations without running real commands
sudo() { echo "sudo $*"; }

detect_pkg_manager() { echo "nix"; }
unset IN_NIX_SHELL
nix_out=$(toolchain_install_deps 2>&1)
assert_contains "nix: guidance when not in nix-shell" "nix" "${nix_out}"

# shellcheck disable=SC2034
IN_NIX_SHELL=1
nix_shell_out=$(toolchain_install_deps 2>&1)
assert_contains "nix: detects IN_NIX_SHELL" "available" "${nix_shell_out}"
unset IN_NIX_SHELL

detect_pkg_manager() { echo "unknown-pm-xyz"; }
assert_exits_zero "unknown pm: exits 0 with warning" toolchain_install_deps

INSTALL_LOG="${TMPDIR_TEST}/install.log"

detect_pkg_manager() { echo "xbps"; }
sudo() { echo "sudo $*" >> "${INSTALL_LOG}"; }
true > "${INSTALL_LOG}"
toolchain_install_deps 2>/dev/null || true
assert_contains "xbps: xbps-install invoked" "xbps-install" "$(cat "${INSTALL_LOG}")"

detect_pkg_manager() { echo "eopkg"; }
true > "${INSTALL_LOG}"
toolchain_install_deps 2>/dev/null || true
assert_contains "eopkg: eopkg invoked" "eopkg" "$(cat "${INSTALL_LOG}")"

# ── 21-30: toolchain_install_cross ───────────────────────────────────────────
echo ""
echo "-- toolchain_install_cross --"

# Stubs must be defined at the top level (not inside helpers) so they are
# visible to toolchain_install_cross when it calls sudo.
CROSS_LOG="${TMPDIR_TEST}/cross.log"
sudo() { echo "sudo $*" >> "${CROSS_LOG}"; }

detect_pkg_manager() { echo "apt"; }
true > "${CROSS_LOG}"
toolchain_install_cross "aarch64" 2>/dev/null || true
assert_contains "apt/aarch64: gcc-aarch64-linux-gnu" \
    "gcc-aarch64-linux-gnu" "$(cat "${CROSS_LOG}")"

true > "${CROSS_LOG}"
toolchain_install_cross "arm" 2>/dev/null || true
assert_contains "apt/arm: gcc-arm-linux-gnueabihf" \
    "gcc-arm-linux-gnueabihf" "$(cat "${CROSS_LOG}")"

true > "${CROSS_LOG}"
toolchain_install_cross "riscv64" 2>/dev/null || true
assert_contains "apt/riscv64: gcc-riscv64-linux-gnu" \
    "gcc-riscv64-linux-gnu" "$(cat "${CROSS_LOG}")"

detect_pkg_manager() { echo "pacman"; }
true > "${CROSS_LOG}"
toolchain_install_cross "aarch64" 2>/dev/null || true
assert_contains "pacman/aarch64: aarch64-linux-gnu-gcc" \
    "aarch64-linux-gnu-gcc" "$(cat "${CROSS_LOG}")"

true > "${CROSS_LOG}"
toolchain_install_cross "riscv64" 2>/dev/null || true
assert_contains "pacman/riscv64: riscv64-linux-gnu-gcc" \
    "riscv64-linux-gnu-gcc" "$(cat "${CROSS_LOG}")"

detect_pkg_manager() { echo "dnf"; }
true > "${CROSS_LOG}"
toolchain_install_cross "aarch64" 2>/dev/null || true
assert_contains "dnf/aarch64: gcc-aarch64-linux-gnu" \
    "gcc-aarch64-linux-gnu" "$(cat "${CROSS_LOG}")"

detect_pkg_manager() { echo "zypper"; }
true > "${CROSS_LOG}"
toolchain_install_cross "aarch64" 2>/dev/null || true
assert_contains "zypper/aarch64: cross-aarch64-gcc" \
    "cross-aarch64-gcc" "$(cat "${CROSS_LOG}")"

detect_pkg_manager() { echo "xbps"; }
true > "${CROSS_LOG}"
toolchain_install_cross "aarch64" 2>/dev/null || true
assert_contains "xbps/aarch64: cross-aarch64-linux-gnu" \
    "cross-aarch64-linux-gnu" "$(cat "${CROSS_LOG}")"

detect_pkg_manager() { echo "emerge"; }
true > "${CROSS_LOG}"
toolchain_install_cross "aarch64" 2>/dev/null || true
assert_contains "emerge/aarch64: cross atom" \
    "cross-aarch64-unknown-linux-gnu/gcc" "$(cat "${CROSS_LOG}")"

detect_pkg_manager() { echo "apt"; }
sudo() { :; }
assert_exits_zero "cross unknown arch: exits 0 with warning" \
    toolchain_install_cross "sparc"

# ── 31-34: toolchain_install_llvm ────────────────────────────────────────────
echo ""
echo "-- toolchain_install_llvm --"

LLVM_LOG="${TMPDIR_TEST}/llvm.log"
sudo() { echo "sudo $*" >> "${LLVM_LOG}"; }

detect_pkg_manager() { echo "zypper"; }
true > "${LLVM_LOG}"
toolchain_install_llvm 2>/dev/null || true
assert_contains "llvm/zypper: zypper invoked" "zypper" "$(cat "${LLVM_LOG}")"

detect_pkg_manager() { echo "xbps"; }
true > "${LLVM_LOG}"
toolchain_install_llvm 2>/dev/null || true
assert_contains "llvm/xbps: xbps-install invoked" "xbps-install" "$(cat "${LLVM_LOG}")"

detect_pkg_manager() { echo "eopkg"; }
true > "${LLVM_LOG}"
toolchain_install_llvm 2>/dev/null || true
assert_contains "llvm/eopkg: eopkg invoked" "eopkg" "$(cat "${LLVM_LOG}")"

detect_pkg_manager() { echo "unknown-pm-xyz"; }
sudo() { :; }
assert_exits_zero "install_llvm: unknown pm exits 0 with warning" \
    toolchain_install_llvm

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${pass} passed, ${fail} failed"
[[ "${fail}" -eq 0 ]]
