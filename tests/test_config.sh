#!/usr/bin/env bash
# tests/test_config.sh - Tests for core/config.sh
#
# Covers:
#   1.  config_main no args exits 0
#   2.  config_main --help exits 0
#   3.  config_main unknown subcommand exits non-zero
#   4.  config_set_option: updates existing option
#   5.  config_set_option: adds new option
#   6.  config_set_option: enables commented-out option
#   7.  config_set_option: idempotent (no duplicate lines)
#   8.  config_cmd_set: --file --option --value round-trip
#   9.  config_cmd_set: missing --file exits non-zero
#  10.  config_cmd_set: missing --option exits non-zero
#  11.  config_cmd_merge: appends fragment to base
#  12.  config_cmd_merge: base lines preserved after merge
#  13.  config_cmd_merge: missing --base exits non-zero
#  14.  config_cmd_merge: missing --fragment exits non-zero
#  15.  config_cmd_merge: base file not found exits non-zero
#  16.  config_cmd_merge: fragment file not found exits non-zero
#  17.  config_cmd_validate: passes when all required options present
#  18.  config_cmd_validate: fails when option missing
#  19.  config_cmd_validate: fails when option is commented out
#  20.  config_cmd_validate: missing --file exits non-zero
#  21.  config_cmd_validate: file not found exits non-zero
#  22.  config_cmd_show: security category filters correctly
#  23.  config_cmd_show: security excludes unrelated options
#  24.  config_cmd_show: net category filters correctly
#  25.  config_cmd_show: fs category filters correctly
#  26.  config_cmd_show: all category returns all CONFIG_ lines
#  27.  config_cmd_show: cpu category filters correctly
#  28.  config_cmd_show: missing --file exits non-zero
#  29.  config_cmd_convert: json opens/closes with braces
#  30.  config_cmd_convert: json contains expected key
#  31.  config_cmd_convert: toml key = "value" format
#  32.  config_cmd_convert: yaml key: "value" format
#  33.  config_cmd_convert: unknown format exits non-zero
#  34.  config_cmd_convert: missing --file exits non-zero
#  35.  config_cmd_diff: no output when files identical
#  36.  config_cmd_diff: shows added option
#  37.  config_cmd_diff: shows removed option
#  38.  config_cmd_diff: missing --a exits non-zero
#  39.  config_apply_lto: thin sets CONFIG_LTO_CLANG_THIN=y
#  40.  config_apply_lto: full sets CONFIG_LTO_CLANG_FULL=y
#  41.  config_apply_lto: none is a no-op
#  42.  config_apply_lto: warns when llvm=0

set -euo pipefail

LKF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/lib.sh"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/detect.sh"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/config.sh"

pass=0; fail=0
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_TEST}"' EXIT

echo "=== test_config.sh ==="

ok()        { echo "  PASS: $1"; pass=$(( pass + 1 )); }
fail_test() { echo "  FAIL: $1"; fail=$(( fail + 1 )); }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then ok "${desc}"
    else fail_test "${desc} — expected '${expected}', got '${actual}'"; fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then ok "${desc}"
    else fail_test "${desc} — '${needle}' not found"; fi
}

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "${haystack}" != *"${needle}"* ]]; then ok "${desc}"
    else fail_test "${desc} — '${needle}' unexpectedly found"; fi
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

# Helper: write a standard test .config
make_config() {
    cat > "$1" <<'EOF'
CONFIG_HZ_1000=y
CONFIG_PREEMPT=y
CONFIG_KVM=m
# CONFIG_SOUND is not set
CONFIG_BTRFS_FS=m
CONFIG_SECURITY=y
CONFIG_RANDOMIZE_BASE=y
CONFIG_NET=y
CONFIG_NETFILTER=y
CONFIG_EXT4_FS=y
CONFIG_PREEMPT_DYNAMIC=y
EOF
}

# ── 1-3: dispatch ─────────────────────────────────────────────────────────────
echo ""
echo "-- config_main dispatch --"

assert_exits_zero    "config_main no args exits 0"  config_main
assert_exits_zero    "config_main --help exits 0"   config_main --help
assert_exits_nonzero "config_main unknown subcmd exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; config_main bogus"

# ── 4-7: config_set_option ────────────────────────────────────────────────────
echo ""
echo "-- config_set_option --"

CFG="${TMPDIR_TEST}/set_option.config"
make_config "${CFG}"

config_set_option "${CFG}" "CONFIG_HZ_1000" "n"
assert_eq "set_option: updates existing" "n" \
    "$(grep "^CONFIG_HZ_1000=" "${CFG}" | cut -d= -f2)"

config_set_option "${CFG}" "CONFIG_NEW_OPTION" "y"
assert_eq "set_option: adds new option" "y" \
    "$(grep "^CONFIG_NEW_OPTION=" "${CFG}" | cut -d= -f2)"

config_set_option "${CFG}" "CONFIG_SOUND" "m"
assert_eq "set_option: enables commented-out option" "m" \
    "$(grep "^CONFIG_SOUND=" "${CFG}" | cut -d= -f2)"

config_set_option "${CFG}" "CONFIG_NEW_OPTION" "y"
count=$(grep -c "^CONFIG_NEW_OPTION=" "${CFG}")
assert_eq "set_option: idempotent (no duplicate lines)" "1" "${count}"

# ── 8-10: config_cmd_set ─────────────────────────────────────────────────────
echo ""
echo "-- config_cmd_set --"

CFG2="${TMPDIR_TEST}/cmd_set.config"
make_config "${CFG2}"

config_cmd_set --file "${CFG2}" --option "CONFIG_PREEMPT" --value "n" 2>/dev/null
assert_eq "cmd_set: round-trip value" "n" \
    "$(grep "^CONFIG_PREEMPT=" "${CFG2}" | cut -d= -f2)"

assert_exits_nonzero "cmd_set: missing --file exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_set --option CONFIG_X --value y"

assert_exits_nonzero "cmd_set: missing --option exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_set --file '${CFG2}' --value y"

# ── 11-16: config_cmd_merge ───────────────────────────────────────────────────
echo ""
echo "-- config_cmd_merge --"

MERGE_BASE="${TMPDIR_TEST}/merge_base.config"
MERGE_FRAG="${TMPDIR_TEST}/merge_frag.config"
make_config "${MERGE_BASE}"
cat > "${MERGE_FRAG}" <<'EOF'
CONFIG_KASAN=y
CONFIG_UBSAN=y
CONFIG_DEBUG_KERNEL=y
EOF

config_cmd_merge --base "${MERGE_BASE}" --fragment "${MERGE_FRAG}" 2>/dev/null
merged=$(cat "${MERGE_BASE}")
assert_contains "merge: fragment appended"          "CONFIG_KASAN=y"        "${merged}"
assert_contains "merge: all fragment lines present" "CONFIG_DEBUG_KERNEL=y" "${merged}"
assert_contains "merge: base lines preserved"       "CONFIG_PREEMPT=y"      "${merged}"

assert_exits_nonzero "merge: missing --base exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_merge --fragment '${MERGE_FRAG}'"

assert_exits_nonzero "merge: missing --fragment exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_merge --base '${MERGE_BASE}'"

assert_exits_nonzero "merge: base file not found exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_merge --base /nonexistent.config --fragment '${MERGE_FRAG}'"

assert_exits_nonzero "merge: fragment file not found exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_merge --base '${MERGE_BASE}' --fragment /nonexistent.config"

# ── 17-21: config_cmd_validate ───────────────────────────────────────────────
echo ""
echo "-- config_cmd_validate --"

VAL_CFG="${TMPDIR_TEST}/validate.config"
make_config "${VAL_CFG}"

assert_exits_zero "validate: passes when all required options present" \
    config_cmd_validate --file "${VAL_CFG}" --require "CONFIG_PREEMPT,CONFIG_KVM"

assert_exits_nonzero "validate: fails when option missing" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_validate --file '${VAL_CFG}' --require CONFIG_MISSING_XYZ"

assert_exits_nonzero "validate: fails when option is commented out" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_validate --file '${VAL_CFG}' --require CONFIG_SOUND"

assert_exits_nonzero "validate: missing --file exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_validate --require CONFIG_PREEMPT"

assert_exits_nonzero "validate: file not found exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_validate --file /nonexistent.config --require CONFIG_PREEMPT"

# ── 22-28: config_cmd_show ────────────────────────────────────────────────────
echo ""
echo "-- config_cmd_show --"

SHOW_CFG="${TMPDIR_TEST}/show.config"
make_config "${SHOW_CFG}"

sec=$(config_cmd_show --file "${SHOW_CFG}" --category security 2>/dev/null)
assert_contains     "show security: CONFIG_SECURITY present"       "CONFIG_SECURITY"       "${sec}"
assert_contains     "show security: CONFIG_RANDOMIZE_BASE present" "CONFIG_RANDOMIZE_BASE" "${sec}"
assert_not_contains "show security: CONFIG_NET excluded"           "CONFIG_NET="           "${sec}"

net=$(config_cmd_show --file "${SHOW_CFG}" --category net 2>/dev/null)
assert_contains     "show net: CONFIG_NET present"       "CONFIG_NET"       "${net}"
assert_contains     "show net: CONFIG_NETFILTER present" "CONFIG_NETFILTER" "${net}"
assert_not_contains "show net: CONFIG_BTRFS excluded"    "CONFIG_BTRFS"     "${net}"

fs=$(config_cmd_show --file "${SHOW_CFG}" --category fs 2>/dev/null)
assert_contains "show fs: CONFIG_EXT4_FS present"  "CONFIG_EXT4_FS"  "${fs}"
assert_contains "show fs: CONFIG_BTRFS_FS present" "CONFIG_BTRFS_FS" "${fs}"

all=$(config_cmd_show --file "${SHOW_CFG}" --category all 2>/dev/null)
assert_contains "show all: CONFIG_PREEMPT present" "CONFIG_PREEMPT" "${all}"
assert_contains "show all: CONFIG_NET present"     "CONFIG_NET"     "${all}"
assert_contains "show all: CONFIG_BTRFS present"   "CONFIG_BTRFS"   "${all}"

cpu=$(config_cmd_show --file "${SHOW_CFG}" --category cpu 2>/dev/null)
assert_contains "show cpu: CONFIG_HZ_1000 present"         "CONFIG_HZ_1000"         "${cpu}"
assert_contains "show cpu: CONFIG_PREEMPT_DYNAMIC present" "CONFIG_PREEMPT_DYNAMIC" "${cpu}"

assert_exits_nonzero "show: missing --file exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; config_cmd_show --category all"

# ── 29-34: config_cmd_convert ────────────────────────────────────────────────
echo ""
echo "-- config_cmd_convert --"

CONV_CFG="${TMPDIR_TEST}/convert.config"
make_config "${CONV_CFG}"

json=$(config_cmd_convert --file "${CONV_CFG}" --format json 2>/dev/null)
assert_contains "convert json: opens with {"          "{"                "${json}"
assert_contains "convert json: CONFIG_PREEMPT key"    '"CONFIG_PREEMPT"' "${json}"

toml=$(config_cmd_convert --file "${CONV_CFG}" --format toml 2>/dev/null)
assert_contains "convert toml: CONFIG_PREEMPT present" "CONFIG_PREEMPT" "${toml}"
assert_contains "convert toml: key = \"value\" format" '= "'            "${toml}"

yaml=$(config_cmd_convert --file "${CONV_CFG}" --format yaml 2>/dev/null)
assert_contains "convert yaml: CONFIG_PREEMPT present" "CONFIG_PREEMPT" "${yaml}"
assert_contains "convert yaml: key: \"value\" format"  ': "'            "${yaml}"

assert_exits_nonzero "convert: unknown format exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_convert --file '${CONV_CFG}' --format xml"

assert_exits_nonzero "convert: missing --file exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; config_cmd_convert --format json"

# ── 35-38: config_cmd_diff ───────────────────────────────────────────────────
echo ""
echo "-- config_cmd_diff --"

DIFF_A="${TMPDIR_TEST}/diff_a.config"
DIFF_B="${TMPDIR_TEST}/diff_b.config"
make_config "${DIFF_A}"
make_config "${DIFF_B}"

diff_same=$(config_cmd_diff --a "${DIFF_A}" --b "${DIFF_B}" 2>/dev/null)
assert_eq "diff: no output when files identical" "" "${diff_same}"

echo "CONFIG_ADDED_OPTION=y" >> "${DIFF_B}"
diff_added=$(config_cmd_diff --a "${DIFF_A}" --b "${DIFF_B}" 2>/dev/null)
assert_contains "diff: shows added option" "CONFIG_ADDED_OPTION" "${diff_added}"

echo "CONFIG_ONLY_IN_A=y" >> "${DIFF_A}"
diff_removed=$(config_cmd_diff --a "${DIFF_A}" --b "${DIFF_B}" 2>/dev/null)
assert_contains "diff: shows removed option" "CONFIG_ONLY_IN_A" "${diff_removed}"

assert_exits_nonzero "diff: missing --a exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/config.sh'; \
             config_cmd_diff --b '${DIFF_B}'"

# ── 39-42: config_apply_lto ───────────────────────────────────────────────────
echo ""
echo "-- config_apply_lto --"

# Stub make to avoid needing a real kernel tree
make() { return 0; }

LTO_DIR="${TMPDIR_TEST}/lto-src"
mkdir -p "${LTO_DIR}"

make_config "${LTO_DIR}/.config"
config_apply_lto "${LTO_DIR}" "thin" "1" 2>/dev/null
assert_eq "lto thin: CONFIG_LTO_CLANG_THIN=y" "y" \
    "$(grep "^CONFIG_LTO_CLANG_THIN=" "${LTO_DIR}/.config" | cut -d= -f2)"
assert_eq "lto thin: CONFIG_LTO_CLANG_FULL=n" "n" \
    "$(grep "^CONFIG_LTO_CLANG_FULL=" "${LTO_DIR}/.config" | cut -d= -f2)"

make_config "${LTO_DIR}/.config"
config_apply_lto "${LTO_DIR}" "full" "1" 2>/dev/null
assert_eq "lto full: CONFIG_LTO_CLANG_FULL=y" "y" \
    "$(grep "^CONFIG_LTO_CLANG_FULL=" "${LTO_DIR}/.config" | cut -d= -f2)"
assert_eq "lto full: CONFIG_LTO_CLANG_THIN=n" "n" \
    "$(grep "^CONFIG_LTO_CLANG_THIN=" "${LTO_DIR}/.config" | cut -d= -f2)"

make_config "${LTO_DIR}/.config"
before=$(cat "${LTO_DIR}/.config")
config_apply_lto "${LTO_DIR}" "none" "1" 2>/dev/null
after=$(cat "${LTO_DIR}/.config")
assert_eq "lto none: config unchanged" "${before}" "${after}"

lto_warn=$(config_apply_lto "${LTO_DIR}" "thin" "0" 2>&1 || true)
assert_contains "lto: warns when llvm=0" "LTO requires LLVM" "${lto_warn}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${pass} passed, ${fail} failed"
[[ "${fail}" -eq 0 ]]
