# Dependency Update Skill

This skill automates the process of checking for outdated dependencies, updating them to their latest compatible versions, and verifying that the project still builds and tests pass after the updates.

## Overview

The skill performs the following steps:
1. Checks for outdated Python dependencies using `pip list --outdated`
2. Reviews `pyproject.toml` or `requirements.txt` for version constraints
3. Updates dependencies to the latest compatible versions
4. Runs the test suite to verify nothing is broken
5. Generates a summary report of what was updated

## Usage

This skill is triggered automatically or can be run manually via the provided scripts.

### Linux/macOS

```bash
bash .agents/skills/dependency-update/scripts/run.sh
```

### Windows (PowerShell)

```powershell
.agents/skills/dependency-update/scripts/run.ps1
```

## Configuration

The skill reads configuration from the following environment variables:

| Variable | Description | Default |
|---|---|---|
| `UPDATE_STRATEGY` | `patch`, `minor`, or `major` | `minor` |
| `DRY_RUN` | If `true`, only report changes without applying them | `false` |
| `SKIP_PACKAGES` | Comma-separated list of packages to skip | `` |
| `TEST_COMMAND` | Command to run tests after update | `pytest` |

## Output

The skill produces:
- A list of updated packages with old and new versions
- Test results after the update
- A `dependency-update-report.md` file summarizing all changes

## Safety

- The skill will **not** apply updates if tests fail after updating
- It creates a backup of the original dependency files before making changes
- Major version updates require explicit opt-in via `UPDATE_STRATEGY=major`

## Requirements

- Python 3.8+
- `pip` package manager
- `pip-tools` (optional, for `requirements.txt` pinning)
- Project must have a `pyproject.toml` or `requirements.txt`
