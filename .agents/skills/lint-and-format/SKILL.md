# Lint and Format Skill

This skill automatically checks and enforces code style, formatting, and linting rules across the `openai-agents-python` repository.

## What It Does

1. **Runs Ruff** for fast Python linting and import sorting
2. **Runs Black** for consistent Python code formatting
3. **Runs Pyright** for static type checking
4. **Reports violations** with file, line, and rule details
5. **Optionally auto-fixes** safe linting and formatting issues

## When to Use

- Before submitting a pull request
- After merging upstream changes
- As part of CI validation
- When onboarding new contributors to enforce style consistency

## Inputs

| Variable | Description | Default |
|---|---|---|
| `TARGET_PATH` | Path or glob to lint/format (relative to repo root) | `.` |
| `AUTO_FIX` | Whether to apply safe auto-fixes (`true`/`false`) | `false` |
| `FAIL_ON_ERROR` | Exit non-zero if any violations found | `true` |
| `SKIP_TYPE_CHECK` | Skip Pyright type checking step | `false` |

## Outputs

- Console report of all violations grouped by tool
- Exit code `0` if clean, `1` if violations found (when `FAIL_ON_ERROR=true`)
- If `AUTO_FIX=true`, modified files are left staged for review

## Tools Required

- Python 3.11+
- `ruff` (installed via `pip install ruff` or project dev dependencies)
- `black` (installed via `pip install black` or project dev dependencies)
- `pyright` (installed via `npm install -g pyright` or `pip install pyright`)

All tools are available after running:
```bash
pip install -e '.[dev]'
```

## Example Usage

```bash
# Check only (no fixes)
TARGET_PATH=src/agents AUTO_FIX=false bash .agents/skills/lint-and-format/scripts/run.sh

# Auto-fix formatting and safe lint issues
TARGET_PATH=. AUTO_FIX=true bash .agents/skills/lint-and-format/scripts/run.sh

# Skip type checking for a quick pass
SKIP_TYPE_CHECK=true bash .agents/skills/lint-and-format/scripts/run.sh
```

## Notes

- Auto-fix only applies **safe** transformations (formatting, import sorting). It will not suppress or silence lint errors.
- Type checking errors are reported but do **not** trigger auto-fix.
- The skill respects `pyproject.toml` and `.ruff.toml` configuration files at the repo root.
