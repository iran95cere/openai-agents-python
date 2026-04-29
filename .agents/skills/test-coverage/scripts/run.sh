#!/usr/bin/env bash
# Test Coverage Skill - Run Script
# Analyzes test coverage for the openai-agents-python project,
# identifies gaps, and generates a coverage report with recommendations.

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
MIN_COVERAGE_THRESHOLD=${MIN_COVERAGE_THRESHOLD:-80}
COVERAGE_REPORT_DIR="coverage_reports"
COVERAGE_XML="${COVERAGE_REPORT_DIR}/coverage.xml"
COVERAGE_HTML="${COVERAGE_REPORT_DIR}/html"
GAPS_REPORT="${COVERAGE_REPORT_DIR}/gaps.md"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[test-coverage] $*"; }
err()  { echo "[test-coverage] ERROR: $*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

# ─── Pre-flight checks ────────────────────────────────────────────────────────
require_cmd python
require_cmd pip

log "Installing/verifying test dependencies..."
pip install --quiet pytest pytest-cov coverage[toml] 2>&1 | tail -5

mkdir -p "${COVERAGE_REPORT_DIR}"

# ─── Run tests with coverage ──────────────────────────────────────────────────
log "Running test suite with coverage tracking (threshold: ${MIN_COVERAGE_THRESHOLD}%)..."

set +e
python -m pytest \
  --cov=src \
  --cov-report=xml:"${COVERAGE_XML}" \
  --cov-report=html:"${COVERAGE_HTML}" \
  --cov-report=term-missing \
  --cov-fail-under="${MIN_COVERAGE_THRESHOLD}" \
  -q \
  tests/ 2>&1 | tee "${COVERAGE_REPORT_DIR}/pytest_output.txt"
PYTEST_EXIT=$?
set -e

# ─── Parse coverage XML for gap analysis ──────────────────────────────────────
log "Analyzing coverage gaps..."

python - <<'PYEOF'
import xml.etree.ElementTree as ET
import os
import sys

xml_path = os.environ.get("COVERAGE_XML", "coverage_reports/coverage.xml")
gaps_path = os.environ.get("GAPS_REPORT",  "coverage_reports/gaps.md")
threshold  = int(os.environ.get("MIN_COVERAGE_THRESHOLD", "80"))

if not os.path.exists(xml_path):
    print(f"Coverage XML not found at {xml_path}, skipping gap analysis.")
    sys.exit(0)

tree = ET.parse(xml_path)
root = tree.getroot()

low_coverage_files = []
for pkg in root.iter("package"):
    for cls in pkg.iter("class"):
        filename  = cls.attrib.get("filename", "unknown")
        line_rate = float(cls.attrib.get("line-rate", "1"))
        pct       = round(line_rate * 100, 1)
        if pct < threshold:
            missing_lines = [
                line.attrib["number"]
                for line in cls.iter("line")
                if line.attrib.get("hits", "1") == "0"
            ]
            low_coverage_files.append((filename, pct, missing_lines))

low_coverage_files.sort(key=lambda x: x[1])  # worst first

with open(gaps_path, "w") as f:
    f.write("# Test Coverage Gaps Report\n\n")
    f.write(f"Threshold: **{threshold}%**\n\n")
    if not low_coverage_files:
        f.write("✅ All files meet the coverage threshold.\n")
    else:
        f.write(f"## Files Below {threshold}% Coverage\n\n")
        f.write("| File | Coverage | Missing Lines |\n")
        f.write("|------|----------|---------------|\n")
        for fname, pct, missing in low_coverage_files:
            missing_str = ", ".join(missing[:15])
            if len(missing) > 15:
                missing_str += f" … (+{len(missing)-15} more)"
            f.write(f"| `{fname}` | {pct}% | {missing_str} |\n")
        f.write(f"\n**{len(low_coverage_files)} file(s) need additional tests.**\n")

print(f"Gap analysis written to {gaps_path}")
PYEOF

export COVERAGE_XML GAPS_REPORT MIN_COVERAGE_THRESHOLD

# ─── Summary ──────────────────────────────────────────────────────────────────
log "Coverage reports saved to: ${COVERAGE_REPORT_DIR}/"
log "  XML  : ${COVERAGE_XML}"
log "  HTML : ${COVERAGE_HTML}/index.html"
log "  Gaps : ${GAPS_REPORT}"

if [[ ${PYTEST_EXIT} -ne 0 ]]; then
  err "Tests failed or coverage is below ${MIN_COVERAGE_THRESHOLD}% threshold (exit ${PYTEST_EXIT})."
  err "Review ${GAPS_REPORT} for files that need additional test coverage."
  exit "${PYTEST_EXIT}"
fi

log "✅ All tests passed and coverage meets the ${MIN_COVERAGE_THRESHOLD}% threshold."
