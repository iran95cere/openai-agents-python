# Test Coverage Skill

This skill analyzes and improves test coverage for the `openai-agents-python` project. It identifies untested code paths, generates missing unit tests, and ensures coverage thresholds are maintained.

## What This Skill Does

1. **Coverage Analysis** — Runs `pytest` with `coverage.py` to measure current test coverage across all modules.
2. **Gap Identification** — Parses coverage reports to find untested functions, branches, and lines.
3. **Test Generation** — Suggests or generates new test cases for uncovered code paths.
4. **Threshold Enforcement** — Fails the check if overall coverage drops below the configured minimum (default: 80%).
5. **Report Publishing** — Produces an HTML and XML coverage report for CI consumption.

## When to Use

- After adding new features or modules to verify they are adequately tested.
- During pull-request review to catch coverage regressions.
- Periodically as a maintenance task to improve overall test health.

## Inputs

| Variable | Required | Default | Description |
|---|---|---|---|
| `MIN_COVERAGE` | No | `80` | Minimum acceptable overall coverage percentage (0-100). |
| `SOURCE_DIR` | No | `src` | Directory containing source code to measure. |
| `TEST_DIR` | No | `tests` | Directory containing test files. |
| `REPORT_DIR` | No | `coverage-reports` | Output directory for HTML/XML reports. |
| `FAIL_UNDER` | No | same as `MIN_COVERAGE` | Passed directly to `coverage report --fail-under`. |

## Outputs

- `coverage-reports/index.html` — Human-readable HTML report.
- `coverage-reports/coverage.xml` — Machine-readable XML report (compatible with Codecov, SonarQube, etc.).
- Console summary printed to stdout.

## Usage

### Bash (Linux / macOS)

```bash
export MIN_COVERAGE=85
export SOURCE_DIR=src
bash .agents/skills/test-coverage/scripts/run.sh
```

### PowerShell (Windows)

```powershell
$env:MIN_COVERAGE = "85"
$env:SOURCE_DIR = "src"
.agents/skills/test-coverage/scripts/run.ps1
```

## Requirements

- Python 3.9+
- `pytest` and `pytest-cov` installed (included in `dev` dependencies via `pyproject.toml`)
- Project virtual environment activated **or** dependencies available on `PATH`

## Notes

- Branch coverage is enabled by default (`--cov-branch`).
- The skill respects `.coveragerc` if present in the repository root.
- Omits `tests/`, `docs/`, and `examples/` directories from coverage measurement automatically.
