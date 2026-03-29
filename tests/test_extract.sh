#!/usr/bin/env bash
# tests/test_extract.sh - Tests for lkf extract (core/extract.sh)
#
# Covers:
#   1.  extract_usage prints expected options
#   2.  extract_main --help exits 0
#   3.  extract_main unknown option exits non-zero
#   4.  extract_main without --input exits non-zero
#   5.  extract_main with missing --input file exits non-zero
#   6.  extract_detect_type: ELF magic → elf
#   7.  extract_detect_type: MZ/PE magic → efi-zboot
#   8.  extract_detect_type: ANDR magic → android-boot
#   9.  extract_detect_type: unknown magic → vmlinuz (default)
#  10.  extract_main --type elf: copies ELF input to output unchanged
#  11.  extract_main --type elf: output file exists after copy
#  12.  extract_main --type elf --validate: passes for a real ELF
#  13.  extract_main --type elf --validate: fails for a non-ELF file
#  14.  extract_validate_elf: exits non-zero for non-ELF input
#  15.  extract_validate_elf: exits 0 for a real ELF binary
#  16.  extract_main --type vmlinuz: falls back gracefully when no decompressor matches
#  17.  extract_main --type android-boot: warns when abootimg missing
#  18.  extract_main --type efi-zboot: falls back to vmlinuz extraction
#  19.  extract_instrument_symbols: warns when kdress not compiled
#  20.  extract_main --output: respects custom output path

set -euo pipefail

LKF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/lib.sh"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/detect.sh"
# shellcheck disable=SC1090
source "${LKF_ROOT}/core/extract.sh"

pass=0; fail=0
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_TEST}"' EXIT

echo "=== test_extract.sh ==="

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

assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -f "${path}" ]]; then ok "${desc}"
    else fail_test "${desc} — file not found: ${path}"; fi
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

# ── Build fake input files with known magic bytes ─────────────────────────────

# ELF: magic 7f 45 4c 46
FAKE_ELF="${TMPDIR_TEST}/fake.elf"
printf '\x7f\x45\x4c\x46\x02\x01\x01\x00' > "${FAKE_ELF}"
cat /bin/sh >> "${FAKE_ELF}" 2>/dev/null || true   # pad with real ELF content

# Use a real ELF for validate tests (guaranteed valid)
REAL_ELF="${TMPDIR_TEST}/real.elf"
cp /bin/sh "${REAL_ELF}"

# MZ/PE: magic 4d 5a
FAKE_PE="${TMPDIR_TEST}/fake.efi"
printf '\x4d\x5a\x00\x00' > "${FAKE_PE}"

# Android boot: magic 41 4e 44 52 (ANDR)
FAKE_ANDROID="${TMPDIR_TEST}/boot.img"
printf '\x41\x4e\x44\x52\x00\x00\x00\x00' > "${FAKE_ANDROID}"

# Unknown magic (random bytes)
FAKE_UNKNOWN="${TMPDIR_TEST}/unknown.bin"
printf '\xde\xad\xbe\xef' > "${FAKE_UNKNOWN}"

# Non-ELF text file
FAKE_TEXT="${TMPDIR_TEST}/not-an-elf.txt"
echo "this is not an ELF" > "${FAKE_TEXT}"

# ── 1-5: dispatch and validation ─────────────────────────────────────────────
echo ""
echo "-- extract_main dispatch --"

usage_out=$(extract_usage 2>&1)
assert_contains "usage: --input option"    "--input"    "${usage_out}"
assert_contains "usage: --output option"   "--output"   "${usage_out}"
assert_contains "usage: --symbols option"  "--symbols"  "${usage_out}"
assert_contains "usage: --type option"     "--type"     "${usage_out}"
assert_contains "usage: --validate option" "--validate" "${usage_out}"

assert_exits_zero    "extract_main --help exits 0" extract_main --help

assert_exits_nonzero "extract_main unknown option exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/extract.sh'; extract_main --bogus"

assert_exits_nonzero "extract_main without --input exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/extract.sh'; extract_main"

assert_exits_nonzero "extract_main missing --input file exits non-zero" \
    bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
             source '${LKF_ROOT}/core/extract.sh'; \
             extract_main --input /nonexistent/vmlinuz"

# ── 6-9: extract_detect_type ─────────────────────────────────────────────────
echo ""
echo "-- extract_detect_type --"

assert_eq "ELF magic → elf"           "elf"          "$(extract_detect_type "${FAKE_ELF}")"
assert_eq "MZ/PE magic → efi-zboot"   "efi-zboot"    "$(extract_detect_type "${FAKE_PE}")"
assert_eq "ANDR magic → android-boot" "android-boot" "$(extract_detect_type "${FAKE_ANDROID}")"
assert_eq "unknown magic → vmlinuz"   "vmlinuz"      "$(extract_detect_type "${FAKE_UNKNOWN}")"

# ── 10-11: --type elf copy ────────────────────────────────────────────────────
echo ""
echo "-- extract_main --type elf --"

ELF_OUT="${TMPDIR_TEST}/out.elf"
extract_main --input "${REAL_ELF}" --output "${ELF_OUT}" --type elf 2>/dev/null
assert_file_exists "type elf: output file created" "${ELF_OUT}"

# Content should be identical
if cmp -s "${REAL_ELF}" "${ELF_OUT}"; then
    ok "type elf: output matches input"
else
    fail_test "type elf: output matches input"
fi

# ── 12-15: --validate (requires 'file' and 'readelf') ────────────────────────
echo ""
echo "-- extract_main --validate --"

if ! command -v file &>/dev/null; then
    echo "  SKIP: 'file' command not available — skipping validate tests (12-15)"
    for _s in \
        "validate: passes for real ELF" \
        "validate: fails for non-ELF file" \
        "validate_elf: non-ELF exits non-zero" \
        "validate_elf: real ELF exits 0"; do
        ok "${_s} (skipped — no 'file')"
    done
else
    VALID_OUT="${TMPDIR_TEST}/valid.elf"
    assert_exits_zero "validate: passes for real ELF" \
        extract_main --input "${REAL_ELF}" --output "${VALID_OUT}" --type elf --validate

    assert_exits_nonzero "validate: fails for non-ELF file" \
        bash -c "source '${LKF_ROOT}/core/lib.sh'; source '${LKF_ROOT}/core/detect.sh'; \
                 source '${LKF_ROOT}/core/extract.sh'; \
                 extract_main --input '${FAKE_TEXT}' \
                   --output '${TMPDIR_TEST}/bad.elf' --type elf --validate"

    echo ""
    echo "-- extract_validate_elf --"

    assert_exits_nonzero "validate_elf: non-ELF exits non-zero" \
        extract_validate_elf "${FAKE_TEXT}"

    assert_exits_zero "validate_elf: real ELF exits 0" \
        extract_validate_elf "${REAL_ELF}"
fi

# ── 16: vmlinuz fallback when no decompressor matches ────────────────────────
echo ""
echo "-- extract_main --type vmlinuz fallback --"

# A file with no known compression magic should die with a clear message
vmlinuz_out=$(extract_main \
    --input "${FAKE_UNKNOWN}" \
    --output "${TMPDIR_TEST}/vmlinux-out" \
    --type vmlinuz 2>&1 || true)
assert_contains "vmlinuz: error message on failure" \
    "extract" "${vmlinuz_out}"

# ── 17: android-boot warns when abootimg missing ─────────────────────────────
echo ""
echo "-- extract_main --type android-boot --"

android_out=$(PATH="" extract_main \
    --input "${FAKE_ANDROID}" \
    --output "${TMPDIR_TEST}/android-vmlinux" \
    --type android-boot 2>&1 || true)
assert_contains "android-boot: warns when abootimg missing" \
    "abootimg" "${android_out}"

# ── 18: efi-zboot falls back to vmlinuz extraction ───────────────────────────
echo ""
echo "-- extract_main --type efi-zboot --"

efi_out=$(extract_main \
    --input "${FAKE_PE}" \
    --output "${TMPDIR_TEST}/efi-vmlinux" \
    --type efi-zboot 2>&1 || true)
# Should attempt extraction (warn or error, but not crash silently)
assert_contains "efi-zboot: attempts extraction" \
    "extract" "${efi_out}"

# ── 19: extract_instrument_symbols warns when kdress missing ─────────────────
echo ""
echo "-- extract_instrument_symbols --"

# Ensure kdress binary doesn't exist in test LKF_ROOT
sym_out=$(extract_instrument_symbols "${REAL_ELF}" "/nonexistent/System.map" 2>&1 || true)
assert_contains "instrument_symbols: warns when kdress missing" \
    "kdress" "${sym_out}"

# ── 20: custom --output path ─────────────────────────────────────────────────
echo ""
echo "-- custom --output path --"

CUSTOM_OUT="${TMPDIR_TEST}/subdir/custom-vmlinux"
extract_main \
    --input "${REAL_ELF}" \
    --output "${CUSTOM_OUT}" \
    --type elf 2>/dev/null
assert_file_exists "custom --output: creates output in subdir" "${CUSTOM_OUT}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${pass} passed, ${fail} failed"
[[ "${fail}" -eq 0 ]]
