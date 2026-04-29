#!/bin/bash
# Dependency Update Skill
# Automatically checks for outdated dependencies and creates update PRs

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
LOG_PREFIX="[dependency-update]"

# ─── Logging Helpers ─────────────────────────────────────────────────────────
log_info()  { echo "${LOG_PREFIX} INFO:  $*"; }
log_warn()  { echo "${LOG_PREFIX} WARN:  $*" >&2; }
log_error() { echo "${LOG_PREFIX} ERROR: $*" >&2; }
log_ok()    { echo "${LOG_PREFIX} OK:    $*"; }

# ─── Dependency Check ────────────────────────────────────────────────────────
check_tools() {
    local missing=0
    for tool in python3 pip git; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Required tool not found: $tool"
            missing=1
        fi
    done
    if [[ $missing -ne 0 ]]; then
        exit 1
    fi
}

# ─── Parse pyproject.toml or requirements files ───────────────────────────────
find_dependency_files() {
    local files=()
    [[ -f "${PROJECT_ROOT}/pyproject.toml" ]]       && files+=("${PROJECT_ROOT}/pyproject.toml")
    [[ -f "${PROJECT_ROOT}/requirements.txt" ]]     && files+=("${PROJECT_ROOT}/requirements.txt")
    [[ -f "${PROJECT_ROOT}/requirements-dev.txt" ]] && files+=("${PROJECT_ROOT}/requirements-dev.txt")
    echo "${files[@]:-}"
}

# ─── Check for outdated packages via pip ─────────────────────────────────────
get_outdated_packages() {
    log_info "Checking for outdated packages..."
    python3 -m pip list --outdated --format=json 2>/dev/null || echo "[]"
}

# ─── Run pip-audit for known vulnerabilities ─────────────────────────────────
run_security_audit() {
    if python3 -m pip show pip-audit &>/dev/null 2>&1; then
        log_info "Running security audit with pip-audit..."
        python3 -m pip_audit --format=json 2>/dev/null || true
    else
        log_warn "pip-audit not installed; skipping security audit."
        log_warn "Install with: pip install pip-audit"
    fi
}

# ─── Summarise results ───────────────────────────────────────────────────────
print_summary() {
    local outdated_json="$1"
    local count
    count=$(echo "$outdated_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(len(data))
" 2>/dev/null || echo "0")

    if [[ "$count" -eq 0 ]]; then
        log_ok "All dependencies are up to date."
        return 0
    fi

    log_warn "$count outdated package(s) found:"
    echo "$outdated_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for pkg in data:
    print(f"  - {pkg['name']}: {pkg['version']} -> {pkg['latest_version']}")
" 2>/dev/null || true
    return 1
}

# ─── Optional: bump versions in pyproject.toml ───────────────────────────────
bump_versions() {
    local outdated_json="$1"
    local dry_run="${2:-true}"

    if [[ "$dry_run" == "true" ]]; then
        log_info "Dry-run mode: no files will be modified."
        return 0
    fi

    log_info "Bumping versions in pyproject.toml (if present)..."
    echo "$outdated_json" | python3 - <<'PYEOF'
import json, re, sys
from pathlib import Path

data = json.load(sys.stdin)
updates = {pkg["name"].lower(): pkg["latest_version"] for pkg in data}

pyproject = Path("pyproject.toml")
if not pyproject.exists():
    print("pyproject.toml not found; skipping bump.")
    sys.exit(0)

content = pyproject.read_text()
for name, version in updates.items():
    # Match patterns like: package = ">=1.0", package = "^1.0", package = "1.0"
    pattern = re.compile(
        r'(?P<pkg>' + re.escape(name) + r')[\s]*=[\s]*"[^"]*"',
        re.IGNORECASE,
    )
    content = pattern.sub(lambda m: f'{m.group("pkg")} = ">={version}"', content)

pyproject.write_text(content)
print(f"Updated {len(updates)} package reference(s) in pyproject.toml")
PYEOF
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    local dry_run="true"
    local audit="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --apply)   dry_run="false" ;;
            --audit)   audit="true" ;;
            --help|-h)
                echo "Usage: $0 [--apply] [--audit]"
                echo "  --apply   Write version bumps to pyproject.toml"
                echo "  --audit   Run pip-audit for CVE scanning"
                exit 0
                ;;
            *) log_warn "Unknown option: $1" ;;
        esac
        shift
    done

    log_info "Starting dependency update check in: ${PROJECT_ROOT}"
    cd "${PROJECT_ROOT}"

    check_tools

    local dep_files
    dep_files=$(find_dependency_files)
    if [[ -z "$dep_files" ]]; then
        log_warn "No dependency files found. Nothing to check."
        exit 0
    fi
    log_info "Dependency files: $dep_files"

    local outdated_json
    outdated_json=$(get_outdated_packages)

    if [[ "$audit" == "true" ]]; then
        run_security_audit
    fi

    if print_summary "$outdated_json"; then
        exit 0
    fi

    bump_versions "$outdated_json" "$dry_run"

    if [[ "$dry_run" == "false" ]]; then
        log_ok "Version bumps applied. Review changes with: git diff"
    else
        log_info "Re-run with --apply to write changes."
    fi
}

main "$@"
