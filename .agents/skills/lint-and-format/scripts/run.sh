#!/usr/bin/env bash
# Lint and Format Skill - run.sh
# Runs linting and formatting checks (and optionally auto-fixes) on the repository.
# Usage: ./run.sh [--fix] [--check-only] [--path <path>]

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
FIX=false
CHECK_ONLY=false
TARGET_PATH="."

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)
      FIX=true
      shift
      ;;
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    --path)
      TARGET_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[lint-and-format] $*"; }
fail() { echo "[lint-and-format] ERROR: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" &>/dev/null || fail "Required tool '$1' not found. Install it and retry."
}

# ---------------------------------------------------------------------------
# Environment setup
# ---------------------------------------------------------------------------
log "Target path: $TARGET_PATH"
log "Fix mode   : $FIX"
log "Check only : $CHECK_ONLY"

require_tool python3

# Ensure we are inside a virtual-env or uv environment when available.
if command -v uv &>/dev/null; then
  log "Using uv to run tools."
  RUNNER="uv run"
else
  RUNNER=""
fi

# ---------------------------------------------------------------------------
# Install / verify linting dependencies
# ---------------------------------------------------------------------------
if [[ -z "$RUNNER" ]]; then
  python3 -m pip install --quiet ruff pyright 2>&1 | tail -5
fi

# ---------------------------------------------------------------------------
# ruff — linting
# ---------------------------------------------------------------------------
log "Running ruff linter ..."
RUFF_LINT_ARGS=("ruff" "check" "$TARGET_PATH")
if $FIX && ! $CHECK_ONLY; then
  RUFF_LINT_ARGS+=("--fix")
fi

if ! $RUNNER "${RUFF_LINT_ARGS[@]}"; then
  if $CHECK_ONLY; then
    fail "ruff lint check failed. Run with --fix to auto-fix issues."
  else
    fail "ruff lint failed."
  fi
fi
log "ruff lint passed."

# ---------------------------------------------------------------------------
# ruff — formatting
# ---------------------------------------------------------------------------
log "Running ruff formatter ..."
RUFF_FMT_ARGS=("ruff" "format")
if $CHECK_ONLY || ! $FIX; then
  RUFF_FMT_ARGS+=("--check")
fi
RUFF_FMT_ARGS+=("$TARGET_PATH")

if ! $RUNNER "${RUFF_FMT_ARGS[@]}"; then
  if $CHECK_ONLY || ! $FIX; then
    fail "ruff format check failed. Run with --fix to auto-format."
  else
    fail "ruff format failed."
  fi
fi
log "ruff format passed."

# ---------------------------------------------------------------------------
# pyright — type checking (always check-only; no auto-fix possible)
# ---------------------------------------------------------------------------
log "Running pyright type checker ..."
if ! $RUNNER pyright "$TARGET_PATH"; then
  fail "pyright type-check failed. Fix the reported type errors and retry."
fi
log "pyright passed."

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "All lint and format checks passed successfully."
