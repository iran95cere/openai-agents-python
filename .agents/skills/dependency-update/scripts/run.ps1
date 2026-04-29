# Dependency Update Skill - PowerShell Script
# Updates project dependencies and creates a summary of changes

param(
    [string]$WorkingDir = $PWD,
    [string]$OutputFile = "dependency-update-report.md",
    [switch]$DryRun = $false,
    [switch]$SkipTests = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Helper: Write colored output
function Write-Status {
    param([string]$Message, [string]$Color = "White")
    Write-Host "[dependency-update] $Message" -ForegroundColor $Color
}

function Write-Success { param([string]$Message) Write-Status $Message "Green" }
function Write-Warning { param([string]$Message) Write-Status $Message "Yellow" }
function Write-Failure { param([string]$Message) Write-Status $Message "Red" }

# Verify we are in the right directory
if (-not (Test-Path (Join-Path $WorkingDir "pyproject.toml"))) {
    Write-Failure "pyproject.toml not found in $WorkingDir. Aborting."
    exit 1
}

Set-Location $WorkingDir
Write-Status "Working directory: $WorkingDir"

# Capture original dependency state
Write-Status "Capturing current dependency state..."
$beforeLock = ""
if (Test-Path "uv.lock") {
    $beforeLock = Get-Content "uv.lock" -Raw
}

# Run dependency update
Write-Status "Running dependency update via uv..."
try {
    if ($DryRun) {
        Write-Warning "DRY RUN: would execute 'uv lock --upgrade'"
    } else {
        $result = & uv lock --upgrade 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Failure "uv lock --upgrade failed:"
            Write-Failure $result
            exit 1
        }
        Write-Success "Dependency lock updated successfully."
    }
} catch {
    Write-Failure "Failed to run uv: $_"
    exit 1
}

# Sync updated dependencies
Write-Status "Syncing updated dependencies..."
try {
    if (-not $DryRun) {
        $syncResult = & uv sync --all-extras 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Failure "uv sync failed:"
            Write-Failure $syncResult
            exit 1
        }
        Write-Success "Dependencies synced."
    }
} catch {
    Write-Failure "Failed to sync dependencies: $_"
    exit 1
}

# Detect changes
$changedPackages = @()
if (-not $DryRun -and (Test-Path "uv.lock")) {
    $afterLock = Get-Content "uv.lock" -Raw
    if ($beforeLock -ne $afterLock) {
        Write-Status "Detecting changed packages..."
        # Parse changed package names from lock diff (simple heuristic)
        $beforeLines = $beforeLock -split "`n" | Where-Object { $_ -match '^name = ' }
        $afterLines  = $afterLock  -split "`n" | Where-Object { $_ -match '^name = ' }
        $changedPackages = Compare-Object $beforeLines $afterLines | ForEach-Object { $_.InputObject }
    }
}

# Run tests unless skipped
$testsPassed = $true
if (-not $SkipTests -and -not $DryRun) {
    Write-Status "Running test suite to verify updates..."
    try {
        $testResult = & uv run pytest tests/ --tb=short -q 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Tests failed after dependency update!"
            Write-Warning $testResult
            $testsPassed = $false
        } else {
            Write-Success "All tests passed."
        }
    } catch {
        Write-Warning "Could not run tests: $_"
        $testsPassed = $false
    }
}

# Generate report
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$reportLines = @(
    "# Dependency Update Report",
    "",
    "**Generated:** $timestamp",
    "**Dry Run:** $DryRun",
    "**Tests Skipped:** $SkipTests",
    "**Tests Passed:** $testsPassed",
    "",
    "## Changed Packages",
    ""
)

if ($changedPackages.Count -gt 0) {
    foreach ($pkg in $changedPackages) {
        $reportLines += "- $pkg"
    }
} elseif ($DryRun) {
    $reportLines += "_Dry run — no changes applied._"
} else {
    $reportLines += "_No package versions changed._"
}

$reportLines += ""
$reportLines += "## Status"
$reportLines += ""
if ($testsPassed) {
    $reportLines += "✅ Dependency update completed successfully."
} else {
    $reportLines += "⚠️ Dependency update completed but tests failed. Review before merging."
}

$report = $reportLines -join "`n"
Set-Content -Path $OutputFile -Value $report -Encoding UTF8
Write-Success "Report written to $OutputFile"

# Exit with appropriate code
if (-not $testsPassed) { exit 2 }
exit 0
