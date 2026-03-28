#!/usr/bin/env bash
# core/xm.sh - Cross-compile manager: arch × compiler matrix
#
# lkf xm runs a kernel build (or any lkf command) across a user-defined
# matrix of target architectures and compilers, collecting results in a
# summary table.  Useful for verifying that a kernel config or patch set
# compiles cleanly on multiple targets before release.
#
# Matrix dimensions:
#   --arch   comma-separated list of target architectures
#   --cc     comma-separated list of compilers: gcc, clang, llvm
#
# Each cell in the matrix is one lkf build invocation.  Cells run
# sequentially by default; --parallel N runs up to N cells concurrently.

xm_usage() {
    cat <<EOF
lkf xm - Cross-compile manager: arch × compiler matrix

USAGE: lkf xm [options] [-- <extra lkf build args>]

OPTIONS:
  --arch <list>       Comma-separated target architectures
                      [x86_64,aarch64,arm,riscv64]
  --cc <list>         Comma-separated compilers: gcc, clang
                      [gcc]
  --version <ver>     Kernel version to build [required]
  --flavor <name>     Kernel flavor [mainline]
  --stop-after <s>    Stop each build after stage (e.g. config, build)
  --build-dir <path>  Base build directory; each cell gets a subdirectory
                      [xm-build]
  --parallel <N>      Run up to N matrix cells concurrently [1]
  --dry-run           Print matrix and commands without running
  --no-color          Disable colour in the summary table
  --help              Show this help

CROSS-TOOLCHAIN DETECTION:
  For each arch, lkf xm looks for a cross-compiler on PATH using the
  standard GNU tuple prefix (e.g. aarch64-linux-gnu-gcc).  If not found
  it skips that cell and marks it SKIP in the summary.

EXAMPLES:
  # Build x86_64 and aarch64 with gcc
  lkf xm --version 6.12 --arch x86_64,aarch64

  # Full matrix: 4 arches × 2 compilers
  lkf xm --version 6.12 --arch x86_64,aarch64,arm,riscv64 --cc gcc,clang

  # Config-only matrix (fast)
  lkf xm --version 6.12 --arch x86_64,aarch64 --stop-after config

  # Dry run to preview the matrix
  lkf xm --version 6.12 --arch x86_64,aarch64 --cc gcc,clang --dry-run

  # Parallel builds (2 at a time)
  lkf xm --version 6.12 --arch x86_64,aarch64 --parallel 2
EOF
}

# ── Arch → cross-compiler prefix mapping ─────────────────────────────────────

_xm_cross_prefix() {
    local arch="$1"
    case "${arch}" in
        x86_64)  echo "" ;;                          # native
        aarch64) echo "aarch64-linux-gnu-" ;;
        arm)     echo "arm-linux-gnueabihf-" ;;
        riscv64) echo "riscv64-linux-gnu-" ;;
        mips)    echo "mips-linux-gnu-" ;;
        mips64)  echo "mips64-linux-gnuabi64-" ;;
        ppc64le) echo "powerpc64le-linux-gnu-" ;;
        s390x)   echo "s390x-linux-gnu-" ;;
        loongarch64) echo "loongarch64-linux-gnu-" ;;
        *)       echo "" ;;
    esac
}

_xm_check_toolchain() {
    local arch="$1" cc="$2"
    local prefix
    prefix="$(_xm_cross_prefix "${arch}")"

    if [[ "${cc}" == "clang" ]]; then
        # clang uses --target= flag, no prefix needed — just check clang exists
        command -v clang &>/dev/null && return 0 || return 1
    fi

    if [[ -z "${prefix}" ]]; then
        # Native build — check gcc
        command -v gcc &>/dev/null && return 0 || return 1
    fi

    # Cross: check prefixed gcc
    command -v "${prefix}gcc" &>/dev/null && return 0 || return 1
}

# ── Colour helpers ────────────────────────────────────────────────────────────

_xm_colour() {
    [[ "${XM_NO_COLOR:-0}" == "1" ]] && { echo "$2"; return; }
    case "$1" in
        green)  echo -e "\033[0;32m$2\033[0m" ;;
        red)    echo -e "\033[0;31m$2\033[0m" ;;
        yellow) echo -e "\033[0;33m$2\033[0m" ;;
        cyan)   echo -e "\033[0;36m$2\033[0m" ;;
        bold)   echo -e "\033[1m$2\033[0m" ;;
        *)      echo "$2" ;;
    esac
}

# ── Result tracking ───────────────────────────────────────────────────────────

declare -A _XM_RESULTS=()   # [arch:cc] = PASS|FAIL|SKIP|RUNNING
declare -A _XM_TIMES=()     # [arch:cc] = elapsed seconds
declare -A _XM_LOGS=()      # [arch:cc] = log file path

_xm_set_result() { _XM_RESULTS["$1:$2"]="$3"; }
_xm_set_time()   { _XM_TIMES["$1:$2"]="$3"; }
_xm_set_log()    { _XM_LOGS["$1:$2"]="$3"; }

# ── Run one matrix cell ───────────────────────────────────────────────────────

_xm_run_cell() {
    local arch="$1" cc="$2" version="$3" flavor="$4"
    local stop_after="$5" base_build_dir="$6"
    shift 6
    local extra_args=("$@")

    local cell_dir="${base_build_dir}/${arch}-${cc}"
    local log_file="${cell_dir}/build.log"
    mkdir -p "${cell_dir}"
    _xm_set_log "${arch}" "${cc}" "${log_file}"

    # Check toolchain availability
    if ! _xm_check_toolchain "${arch}" "${cc}"; then
        _xm_set_result "${arch}" "${cc}" "SKIP"
        _xm_set_time   "${arch}" "${cc}" "0"
        echo "SKIP: ${arch} × ${cc} (toolchain not found)" >> "${log_file}"
        return 0
    fi

    local prefix
    prefix="$(_xm_cross_prefix "${arch}")"

    # Build the lkf build command
    local cmd=("${LKF_ROOT}/lkf.sh" build
        --version "${version}"
        --flavor  "${flavor}"
        --arch    "${arch}"
        --build-dir "${cell_dir}"
        --threads "$(nproc)"
    )

    if [[ "${cc}" == "clang" ]]; then
        cmd+=(--llvm)
        [[ -n "${prefix}" ]] && cmd+=(--cross "${prefix}")
    else
        [[ -n "${prefix}" ]] && cmd+=(--cross "${prefix}")
    fi

    [[ -n "${stop_after}" ]] && cmd+=(--stop-after "${stop_after}")
    cmd+=("${extra_args[@]}")

    local t_start t_end elapsed
    t_start=$(date +%s)

    if "${cmd[@]}" >"${log_file}" 2>&1; then
        t_end=$(date +%s)
        elapsed=$(( t_end - t_start ))
        _xm_set_result "${arch}" "${cc}" "PASS"
        _xm_set_time   "${arch}" "${cc}" "${elapsed}"
    else
        t_end=$(date +%s)
        elapsed=$(( t_end - t_start ))
        _xm_set_result "${arch}" "${cc}" "FAIL"
        _xm_set_time   "${arch}" "${cc}" "${elapsed}"
    fi
}

# ── Print summary table ───────────────────────────────────────────────────────

_xm_print_table() {
    local -a arches=("$@")
    # Compilers are in _XM_CC_LIST (global set by xm_main)

    local col_w=12
    local arch_w=12

    # Header row
    printf "\n"
    printf "%-${arch_w}s" "arch \\ cc"
    for cc in "${_XM_CC_LIST[@]}"; do
        printf "  %-${col_w}s" "${cc}"
    done
    printf "\n"

    # Separator
    printf "%s" "$(printf '─%.0s' $(seq 1 $(( arch_w + (col_w + 2) * ${#_XM_CC_LIST[@]} ))))"
    printf "\n"

    # Data rows
    local pass=0 fail=0 skip=0
    for arch in "${arches[@]}"; do
        printf "%-${arch_w}s" "${arch}"
        for cc in "${_XM_CC_LIST[@]}"; do
            local result="${_XM_RESULTS["${arch}:${cc}"]:-?}"
            local elapsed="${_XM_TIMES["${arch}:${cc}"]:-}"
            local cell
            case "${result}" in
                PASS) cell="$(_xm_colour green "PASS")"; pass=$(( pass + 1 )) ;;
                FAIL) cell="$(_xm_colour red   "FAIL")"; fail=$(( fail + 1 )) ;;
                SKIP) cell="$(_xm_colour yellow "SKIP")"; skip=$(( skip + 1 )) ;;
                *)    cell="?" ;;
            esac
            [[ -n "${elapsed}" && "${elapsed}" != "0" ]] && \
                cell+=" (${elapsed}s)"
            printf "  %-${col_w}s" "${cell}"
        done
        printf "\n"
    done

    printf "\n"
    printf "Summary: "
    printf "%s  " "$(_xm_colour green "${pass} passed")"
    printf "%s  " "$(_xm_colour red   "${fail} failed")"
    printf "%s\n" "$(_xm_colour yellow "${skip} skipped")"

    if [[ "${fail}" -gt 0 ]]; then
        printf "\nFailed builds — logs:\n"
        for arch in "${arches[@]}"; do
            for cc in "${_XM_CC_LIST[@]}"; do
                if [[ "${_XM_RESULTS["${arch}:${cc}"]:-}" == "FAIL" ]]; then
                    printf "  %s × %s: %s\n" \
                        "${arch}" "${cc}" "${_XM_LOGS["${arch}:${cc}"]:-}"
                fi
            done
        done
    fi
    printf "\n"

    [[ "${fail}" -eq 0 ]]
}

# ── Main ──────────────────────────────────────────────────────────────────────

# Global compiler list (needed by _xm_print_table)
declare -a _XM_CC_LIST=()

xm_main() {
    local arch_list="x86_64,aarch64,arm,riscv64"
    local cc_list="gcc"
    local version="" flavor="mainline"
    local stop_after="" base_build_dir="xm-build"
    local parallel=1 dry_run=0
    local -a extra_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --arch)       arch_list="$2"; shift 2 ;;
            --cc)         cc_list="$2"; shift 2 ;;
            --version)    version="$2"; shift 2 ;;
            --flavor)     flavor="$2"; shift 2 ;;
            --stop-after) stop_after="$2"; shift 2 ;;
            --build-dir)  base_build_dir="$2"; shift 2 ;;
            --parallel)   parallel="$2"; shift 2 ;;
            --dry-run)    dry_run=1; shift ;;
            --no-color)   XM_NO_COLOR=1; shift ;;
            --help|-h)    xm_usage; return 0 ;;
            --)           shift; extra_args=("$@"); break ;;
            *) lkf_die "Unknown option: $1" ;;
        esac
    done

    [[ -z "${version}" ]] && lkf_die "--version is required"

    IFS=',' read -ra arches  <<< "${arch_list}"
    IFS=',' read -ra _XM_CC_LIST <<< "${cc_list}"

    local total=$(( ${#arches[@]} * ${#_XM_CC_LIST[@]} ))

    lkf_step "Cross-compile matrix: ${#arches[@]} arch(es) × ${#_XM_CC_LIST[@]} compiler(s) = ${total} cell(s)"
    lkf_info "  arches   : ${arches[*]}"
    lkf_info "  compilers: ${_XM_CC_LIST[*]}"
    lkf_info "  version  : ${version} (${flavor})"
    [[ -n "${stop_after}" ]] && lkf_info "  stop-after: ${stop_after}"
    lkf_info "  build-dir: ${base_build_dir}/"
    lkf_info "  parallel : ${parallel}"

    if [[ "${dry_run}" -eq 1 ]]; then
        lkf_info "Dry run — matrix cells:"
        for arch in "${arches[@]}"; do
            for cc in "${_XM_CC_LIST[@]}"; do
                local prefix
                prefix="$(_xm_cross_prefix "${arch}")"
                local avail="✓"
                _xm_check_toolchain "${arch}" "${cc}" || avail="✗ (toolchain missing)"
                printf "  %-10s × %-6s  cross=%-28s  %s\n" \
                    "${arch}" "${cc}" "${prefix:-<native>}" "${avail}"
            done
        done
        return 0
    fi

    mkdir -p "${base_build_dir}"

    if [[ "${parallel}" -le 1 ]]; then
        # Sequential
        for arch in "${arches[@]}"; do
            for cc in "${_XM_CC_LIST[@]}"; do
                lkf_step "Building ${arch} × ${cc}"
                _xm_run_cell "${arch}" "${cc}" "${version}" "${flavor}" \
                    "${stop_after}" "${base_build_dir}" "${extra_args[@]}"
                local r="${_XM_RESULTS["${arch}:${cc}"]:-?}"
                case "${r}" in
                    PASS) lkf_info "  → $(_xm_colour green PASS)" ;;
                    FAIL) lkf_warn "  → $(_xm_colour red FAIL) (see ${_XM_LOGS["${arch}:${cc}"]})" ;;
                    SKIP) lkf_info "  → $(_xm_colour yellow SKIP) (toolchain not found)" ;;
                esac
            done
        done
    else
        # Parallel: launch up to $parallel jobs, wait for each batch
        local -a pids=()
        local -a pending_arch=()
        local -a pending_cc=()

        for arch in "${arches[@]}"; do
            for cc in "${_XM_CC_LIST[@]}"; do
                _xm_set_result "${arch}" "${cc}" "RUNNING"
                (
                    _xm_run_cell "${arch}" "${cc}" "${version}" "${flavor}" \
                        "${stop_after}" "${base_build_dir}" "${extra_args[@]}"
                    # Write result to a temp file so parent can read it
                    local r="${_XM_RESULTS["${arch}:${cc}"]:-FAIL}"
                    echo "${r}" > "${base_build_dir}/${arch}-${cc}/.result"
                ) &
                pids+=($!)
                pending_arch+=("${arch}")
                pending_cc+=("${cc}")

                # Throttle: wait when we hit the parallel limit
                if [[ ${#pids[@]} -ge "${parallel}" ]]; then
                    wait "${pids[0]}"
                    # Read result back from temp file
                    local pa="${pending_arch[0]}" pc="${pending_cc[0]}"
                    local rf="${base_build_dir}/${pa}-${pc}/.result"
                    local r
                    r=$(cat "${rf}" 2>/dev/null || echo "FAIL")
                    _xm_set_result "${pa}" "${pc}" "${r}"
                    pids=("${pids[@]:1}")
                    pending_arch=("${pending_arch[@]:1}")
                    pending_cc=("${pending_cc[@]:1}")
                fi
            done
        done

        # Wait for remaining jobs
        local i=0
        for pid in "${pids[@]}"; do
            wait "${pid}"
            local pa="${pending_arch[$i]}" pc="${pending_cc[$i]}"
            local rf="${base_build_dir}/${pa}-${pc}/.result"
            local r
            r=$(cat "${rf}" 2>/dev/null || echo "FAIL")
            _xm_set_result "${pa}" "${pc}" "${r}"
            i=$(( i + 1 ))
        done
    fi

    _xm_print_table "${arches[@]}"
}
