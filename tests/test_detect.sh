#!/usr/bin/env bash
# tests/test_detect.sh - Unit tests for core/detect.sh

set -euo pipefail
LKF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/lib.sh"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/detect.sh"

pass=0; fail=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  PASS: ${desc}"
        pass=$((pass + 1))
    else
        echo "  FAIL: ${desc} — expected '${expected}', got '${actual}'"
        fail=$((fail + 1))
    fi
}

assert_nonempty() {
    local desc="$1" val="$2"
    if [[ -n "${val}" ]]; then
        echo "  PASS: ${desc} (got '${val}')"
        pass=$((pass + 1))
    else
        echo "  FAIL: ${desc} — got empty string"
        fail=$((fail + 1))
    fi
}

# Stub detect_distro so we can test detect_pkg_manager mapping in isolation
_pm_for() {
    local id="$1"
    detect_distro() { echo "${id}"; }
    detect_pkg_manager
}

echo "=== test_detect.sh ==="

# ── arch_to_kernel_arch ───────────────────────────────────────────────────────
echo ""
echo "-- arch_to_kernel_arch --"
assert_eq "x86_64 -> x86_64"      "x86_64"    "$(arch_to_kernel_arch x86_64)"
assert_eq "aarch64 -> arm64"      "arm64"     "$(arch_to_kernel_arch aarch64)"
assert_eq "arm -> arm"            "arm"       "$(arch_to_kernel_arch arm)"
assert_eq "riscv64 -> riscv"      "riscv"     "$(arch_to_kernel_arch riscv64)"
assert_eq "loongarch64 -> loongarch" "loongarch" "$(arch_to_kernel_arch loongarch64)"
assert_eq "powerpc -> powerpc"    "powerpc"   "$(arch_to_kernel_arch powerpc)"
assert_eq "s390 -> s390"          "s390"      "$(arch_to_kernel_arch s390)"

# ── detect_host_arch / detect_distro / detect_pkg_manager (live) ─────────────
echo ""
echo "-- live detection --"
assert_nonempty "detect_host_arch"    "$(detect_host_arch)"
assert_nonempty "detect_distro"       "$(detect_distro)"
assert_nonempty "detect_pkg_manager"  "$(detect_pkg_manager)"

# ── detect_pkg_manager: apt family ───────────────────────────────────────────
echo ""
echo "-- detect_pkg_manager: apt family --"
for id in ubuntu debian linuxmint pop elementary kali raspbian raspios \
           mxlinux zorin deepin parrot tails bodhi peppermint antix \
           devuan sparky q4os emmabuntus trisquel pureos endless feren \
           nitrux lite lubuntu xubuntu kubuntu vanillaos vanilla \
           linuxfx voyager kodachi dragonos bunsenlabs pika biglinux \
           rhino funos anduinos tuxedo neon proxmox blendos; do
    assert_eq "apt: ${id}" "apt" "$(_pm_for "${id}")"
done

# ── detect_pkg_manager: pacman family ────────────────────────────────────────
echo ""
echo "-- detect_pkg_manager: pacman family --"
for id in arch manjaro endeavouros garuda artix blackarch parabola \
           hyperbola crystal rebornos archcraft archbang bluestar cachyos mabox; do
    assert_eq "pacman: ${id}" "pacman" "$(_pm_for "${id}")"
done

# ── detect_pkg_manager: dnf family ───────────────────────────────────────────
echo ""
echo "-- detect_pkg_manager: dnf family --"
for id in fedora rhel centos rocky almalinux ol amzn mageia \
           openmandriva nobara ultramarine qubes bazzite; do
    assert_eq "dnf: ${id}" "dnf" "$(_pm_for "${id}")"
done

# ── detect_pkg_manager: zypper family ────────────────────────────────────────
echo ""
echo "-- detect_pkg_manager: zypper family --"
for id in opensuse opensuse-leap opensuse-tumbleweed sles suse; do
    assert_eq "zypper: ${id}" "zypper" "$(_pm_for "${id}")"
done

# ── detect_pkg_manager: single-distro package managers ───────────────────────
echo ""
echo "-- detect_pkg_manager: single-distro --"
assert_eq "apk: alpine"    "apk"    "$(_pm_for alpine)"
assert_eq "apk: postmarketos" "apk" "$(_pm_for postmarketos)"
assert_eq "apk: adelie"    "apk"    "$(_pm_for adelie)"
assert_eq "xbps: void"     "xbps"   "$(_pm_for void)"
assert_eq "emerge: gentoo" "emerge" "$(_pm_for gentoo)"
assert_eq "emerge: funtoo" "emerge" "$(_pm_for funtoo)"
assert_eq "emerge: calculate" "emerge" "$(_pm_for calculate)"
assert_eq "eopkg: solus"   "eopkg"  "$(_pm_for solus)"
assert_eq "nix: nixos"     "nix"    "$(_pm_for nixos)"
assert_eq "pkgtool: slackware" "pkgtool" "$(_pm_for slackware)"

# ── detect_pkg_manager: unknown fallback ─────────────────────────────────────
echo ""
echo "-- detect_pkg_manager: unknown fallback --"
# An unrecognised distro ID with no package managers on PATH → "unknown"
# We can't easily remove all PMs from PATH, so just verify the function
# returns a non-empty string for an unknown ID (it will probe PATH).
result=$(_pm_for "totally-unknown-distro-xyz-123")
assert_nonempty "unknown distro: returns non-empty" "${result}"

# ── lkf_normalize_version ────────────────────────────────────────────────────
echo ""
echo "-- lkf_normalize_version --"
assert_eq "strip v prefix"  "6.12.3" "$(lkf_normalize_version v6.12.3)"
assert_eq "no prefix"       "6.12"   "$(lkf_normalize_version 6.12)"
assert_eq "rc suffix kept"  "6.13-rc1" "$(lkf_normalize_version v6.13-rc1)"

# ── lkf_nproc ────────────────────────────────────────────────────────────────
echo ""
echo "-- lkf_nproc --"
nproc_val=$(lkf_nproc)
if [[ "${nproc_val}" =~ ^[0-9]+$ ]]; then
    echo "  PASS: lkf_nproc returns integer (${nproc_val})"
    pass=$((pass + 1))
else
    echo "  FAIL: lkf_nproc returned '${nproc_val}'"
    fail=$((fail + 1))
fi

# ── detect_default_output_format ─────────────────────────────────────────────
echo ""
echo "-- detect_default_output_format --"
detect_distro() { echo "ubuntu"; }
assert_eq "apt -> deb"    "deb"         "$(detect_default_output_format)"
detect_distro() { echo "arch"; }
assert_eq "pacman -> pkg.tar.zst" "pkg.tar.zst" "$(detect_default_output_format)"
detect_distro() { echo "fedora"; }
assert_eq "dnf -> rpm"    "rpm"         "$(detect_default_output_format)"
detect_distro() { echo "opensuse"; }
assert_eq "zypper -> rpm" "rpm"         "$(detect_default_output_format)"
detect_distro() { echo "void"; }
assert_eq "xbps -> tar.gz" "tar.gz"    "$(detect_default_output_format)"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[[ "${fail}" -eq 0 ]]
