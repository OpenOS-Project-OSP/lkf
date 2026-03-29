#!/usr/bin/env bash
# tests/test_lkf.sh - Tests for lkf.sh top-level dispatcher
#
# Covers:
#   1.  lkf.sh no args prints usage and exits 0
#   2.  lkf.sh --help exits 0
#   3.  lkf.sh help exits 0
#   4.  lkf.sh -h exits 0
#   5.  lkf.sh unknown command exits non-zero
#   6.  lkf.sh usage mentions all 15 commands
#   7.  lkf.sh usage shows version string
#   8.  LKF_VERSION is set and non-empty
#   9.  cmd_build lazy-loads core/build.sh
#  10.  cmd_remix lazy-loads core/remix.sh
#  11.  cmd_kbuild lazy-loads core/kbuild.sh
#  12.  cmd_xm lazy-loads core/xm.sh
#  13.  cmd_config lazy-loads core/config.sh
#  14.  cmd_patch lazy-loads core/patch.sh
#  15.  cmd_ci lazy-loads ci/ci.sh
#  16.  _lkf_nixos_check: silent on non-NixOS
#  17.  _lkf_nixos_check: warns on NixOS outside nix-shell
#  18.  _lkf_nixos_check: silent when IN_NIX_SHELL=1
#  19.  _lkf_nixos_check: silent when LKF_NIX_SHELL=1
#  20.  lkf.sh info command exits 0

set -euo pipefail

LKF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LKF_SH="${LKF_ROOT}/lkf.sh"

pass=0; fail=0
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_TEST}"' EXIT

echo "=== test_lkf.sh ==="

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

assert_exits_nonzero() {
    local desc="$1"; shift
    if ! "$@" >/dev/null 2>&1; then ok "${desc}"
    else fail_test "${desc} — expected non-zero exit"; fi
}

# ── 1-4: help / no-args ───────────────────────────────────────────────────────
echo ""
echo "-- lkf.sh help and no-args --"

assert_exits_zero "no args exits 0"   bash "${LKF_SH}"
assert_exits_zero "--help exits 0"    bash "${LKF_SH}" --help
assert_exits_zero "help exits 0"      bash "${LKF_SH}" help
assert_exits_zero "-h exits 0"        bash "${LKF_SH}" -h

# ── 5: unknown command ────────────────────────────────────────────────────────
echo ""
echo "-- lkf.sh unknown command --"

assert_exits_nonzero "unknown command exits non-zero" \
    bash "${LKF_SH}" totally-bogus-command-xyz

# ── 6-7: usage content ────────────────────────────────────────────────────────
echo ""
echo "-- lkf.sh usage content --"

usage_out=$(bash "${LKF_SH}" --help 2>&1)
for cmd in build remix config patch initrd image install debug extract dkms profile ci kbuild xm info; do
    assert_contains "usage: '${cmd}' listed" "${cmd}" "${usage_out}"
done
assert_contains "usage: version string present" "lkf" "${usage_out}"

# ── 8: LKF_VERSION ───────────────────────────────────────────────────────────
echo ""
echo "-- LKF_VERSION --"

# Source just enough of lkf.sh to get LKF_VERSION without running main()
lkf_version=$(bash -c "
    source '${LKF_ROOT}/core/lib.sh'
    source '${LKF_ROOT}/core/detect.sh'
    source '${LKF_ROOT}/core/toolchain.sh'
    # Extract LKF_VERSION line without executing main
    grep '^LKF_VERSION=' '${LKF_SH}' | head -1 | cut -d= -f2 | tr -d '\"'
" 2>/dev/null)
if [[ -n "${lkf_version}" ]]; then
    ok "LKF_VERSION is set and non-empty (${lkf_version})"
else
    fail_test "LKF_VERSION is set and non-empty"
fi

# ── 9-15: lazy-load routing ───────────────────────────────────────────────────
echo ""
echo "-- lazy-load routing --"

# Each cmd_* function in lkf.sh sources a specific file then calls *_main.
# Verify the source path is correct by grepping lkf.sh — no need to execute.
check_lazy_load() {
    local desc="$1" expected_source="$3"
    shift 2  # consume desc and func (func unused; grep checks the file directly)
    if grep -q "source.*${expected_source}" "${LKF_SH}"; then
        ok "${desc}"
    else
        fail_test "${desc} — '${expected_source}' not found in lkf.sh"
    fi
}

check_lazy_load "cmd_build sources core/build.sh"   "cmd_build"   "core/build.sh"
check_lazy_load "cmd_remix sources core/remix.sh"   "cmd_remix"   "core/remix.sh"
check_lazy_load "cmd_kbuild sources core/kbuild.sh" "cmd_kbuild"  "core/kbuild.sh"
check_lazy_load "cmd_xm sources core/xm.sh"         "cmd_xm"      "core/xm.sh"
check_lazy_load "cmd_config sources core/config.sh" "cmd_config"  "core/config.sh"
check_lazy_load "cmd_patch sources core/patch.sh"   "cmd_patch"   "core/patch.sh"
check_lazy_load "cmd_ci sources ci/ci.sh"           "cmd_ci"      "ci/ci.sh"

# ── 16-19: _lkf_nixos_check ──────────────────────────────────────────────────
echo ""
echo "-- _lkf_nixos_check --"

# Source lkf.sh internals without running main()
# We need lib.sh, detect.sh, toolchain.sh, then the guard function
_source_guard() {
    # shellcheck disable=SC1090
    source "${LKF_ROOT}/core/lib.sh"
    # shellcheck disable=SC1090
    source "${LKF_ROOT}/core/detect.sh"
    # shellcheck disable=SC1090
    source "${LKF_ROOT}/core/toolchain.sh"
    # Extract and eval just the _lkf_nixos_check function from lkf.sh
    eval "$(grep -A20 '^_lkf_nixos_check()' "${LKF_SH}" | \
        awk '/^_lkf_nixos_check\(\)/{p=1} p{print} /^}$/{p=0}')"
}
_source_guard 2>/dev/null

# Stub detect_distro for each scenario
detect_distro() { echo "ubuntu"; }
unset IN_NIX_SHELL LKF_NIX_SHELL
nixos_out=$(_lkf_nixos_check 2>&1)
if [[ -z "${nixos_out}" ]]; then
    ok "_lkf_nixos_check: silent on non-NixOS"
else
    fail_test "_lkf_nixos_check: silent on non-NixOS — got: ${nixos_out}"
fi

detect_distro() { echo "nixos"; }
unset IN_NIX_SHELL LKF_NIX_SHELL
nixos_warn=$(_lkf_nixos_check 2>&1)
if [[ "${nixos_warn}" == *"nix-shell"* ]]; then
    ok "_lkf_nixos_check: warns on NixOS outside nix-shell"
else
    fail_test "_lkf_nixos_check: warns on NixOS outside nix-shell"
fi

detect_distro() { echo "nixos"; }
# shellcheck disable=SC2034  # read by _lkf_nixos_check
IN_NIX_SHELL=1
nixos_in_shell=$(_lkf_nixos_check 2>&1)
if [[ -z "${nixos_in_shell}" ]]; then
    ok "_lkf_nixos_check: silent when IN_NIX_SHELL=1"
else
    fail_test "_lkf_nixos_check: silent when IN_NIX_SHELL=1 — got: ${nixos_in_shell}"
fi
unset IN_NIX_SHELL

detect_distro() { echo "nixos"; }
# shellcheck disable=SC2034  # read by _lkf_nixos_check
LKF_NIX_SHELL=1
nixos_lkf_shell=$(_lkf_nixos_check 2>&1)
if [[ -z "${nixos_lkf_shell}" ]]; then
    ok "_lkf_nixos_check: silent when LKF_NIX_SHELL=1"
else
    fail_test "_lkf_nixos_check: silent when LKF_NIX_SHELL=1 — got: ${nixos_lkf_shell}"
fi
unset LKF_NIX_SHELL

# ── 20: lkf info ─────────────────────────────────────────────────────────────
echo ""
echo "-- lkf info --"

assert_exits_zero "lkf info exits 0" bash "${LKF_SH}" info

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${pass} passed, ${fail} failed"
[[ "${fail}" -eq 0 ]]
