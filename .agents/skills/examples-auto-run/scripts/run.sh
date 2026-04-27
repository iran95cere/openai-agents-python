#!/usr/bin/env bash
# examples-auto-run skill: Automatically discovers and runs all examples in the
# repository, capturing output and reporting pass/fail status.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
EXAMPLES_DIR="${REPO_ROOT}/examples"
RESULTS_DIR="${REPO_ROOT}/.agents/results/examples-auto-run"
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-60}
PYTHON=${PYTHON:-python3}

# Colour helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_dependencies() {
    local missing=0
    for cmd in "${PYTHON}" timeout; do
        if ! command -v "${cmd}" &>/dev/null; then
            log_error "Required command not found: ${cmd}"
            missing=1
        fi
    done
    [[ ${missing} -eq 0 ]] || exit 1
}

prepare_results_dir() {
    mkdir -p "${RESULTS_DIR}"
    # Clear previous run artefacts
    rm -f "${RESULTS_DIR}"/*.log "${RESULTS_DIR}/summary.json"
}

# ---------------------------------------------------------------------------
# Example discovery
# ---------------------------------------------------------------------------
discover_examples() {
    # Returns a newline-separated list of Python example files.
    # Skips files that start with an underscore (helpers / __init__.py, etc.)
    if [[ ! -d "${EXAMPLES_DIR}" ]]; then
        log_warn "Examples directory not found: ${EXAMPLES_DIR}"
        return
    fi
    find "${EXAMPLES_DIR}" -type f -name '*.py' \
        ! -name '_*' \
        ! -name '__*' \
        | sort
}

# ---------------------------------------------------------------------------
# Run a single example
# ---------------------------------------------------------------------------
run_example() {
    local example_file="$1"
    local relative_path="${example_file#${REPO_ROOT}/}"
    local safe_name
    safe_name="$(echo "${relative_path}" | tr '/' '_' | tr ' ' '_')"
    local log_file="${RESULTS_DIR}/${safe_name}.log"

    log_info "Running: ${relative_path}"

    local exit_code=0
    timeout "${TIMEOUT_SECONDS}" \
        "${PYTHON}" "${example_file}" \
        > "${log_file}" 2>&1 || exit_code=$?

    if [[ ${exit_code} -eq 124 ]]; then
        log_warn "  TIMEOUT after ${TIMEOUT_SECONDS}s — ${relative_path}"
        echo "TIMEOUT" >> "${log_file}"
        echo "timeout"
    elif [[ ${exit_code} -ne 0 ]]; then
        log_error "  FAILED (exit ${exit_code}) — ${relative_path}"
        echo "FAILED"
    else
        log_info "  PASSED — ${relative_path}"
        echo "passed"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    log_info "examples-auto-run starting"
    log_info "Repo root : ${REPO_ROOT}"
    log_info "Examples  : ${EXAMPLES_DIR}"
    log_info "Timeout   : ${TIMEOUT_SECONDS}s per example"

    check_dependencies
    prepare_results_dir

    local total=0 passed=0 failed=0 timed_out=0
    local failed_list=()

    while IFS= read -r example; do
        [[ -z "${example}" ]] && continue
        total=$((total + 1))
        result="$(run_example "${example}")"
        case "${result}" in
            passed)  passed=$((passed + 1)) ;;
            timeout) timed_out=$((timed_out + 1)); failed_list+=("${example}") ;;
            *)       failed=$((failed + 1));  failed_list+=("${example}") ;;
        esac
    done < <(discover_examples)

    # ------------------------------------------------------------------
    # Write JSON summary
    # ------------------------------------------------------------------
    local summary_file="${RESULTS_DIR}/summary.json"
    {
        echo "{"
        echo "  \"total\": ${total},"
        echo "  \"passed\": ${passed},"
        echo "  \"failed\": ${failed},"
        echo "  \"timed_out\": ${timed_out},"
        echo "  \"failures\": ["
        local first=1
        for f in "${failed_list[@]:-}"; do
            [[ -z "${f}" ]] && continue
            [[ ${first} -eq 0 ]] && echo ","
            printf '    "%s"' "${f#${REPO_ROOT}/}"
            first=0
        done
        echo ""
        echo "  ]"
        echo "}"
    } > "${summary_file}"

    # ------------------------------------------------------------------
    # Final report
    # ------------------------------------------------------------------
    echo ""
    log_info "========================================"
    log_info " Examples auto-run complete"
    log_info "  Total    : ${total}"
    log_info "  Passed   : ${passed}"
    log_info "  Failed   : ${failed}"
    log_info "  Timed out: ${timed_out}"
    log_info "  Summary  : ${summary_file}"
    log_info "========================================"

    if [[ $((failed + timed_out)) -gt 0 ]]; then
        log_error "One or more examples did not pass."
        exit 1
    fi
}

main "$@"
