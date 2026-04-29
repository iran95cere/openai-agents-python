# Test Coverage Script for Windows (PowerShell)
# Runs tests with coverage reporting and enforces minimum thresholds

param(
    [string]$MinCoverage = "80",
    [string]$OutputDir = "coverage_report",
    [switch]$OpenReport = $false,
    [switch]$FailUnderThreshold = $true
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-Failure { param([string]$msg) Write-Host "[FAILURE] $msg" -ForegroundColor Red }

Write-Info "Starting test coverage run..."
Write-Info "Minimum coverage threshold: $MinCoverage%"

# Verify we are in the project root
if (-not (Test-Path "pyproject.toml")) {
    Write-Failure "pyproject.toml not found. Please run this script from the project root."
    exit 1
}

# Check for required tools
$tools = @("python", "pytest", "coverage")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Failure "Required tool '$tool' not found in PATH."
        exit 1
    }
}

# Clean previous coverage data
Write-Info "Cleaning previous coverage data..."
if (Test-Path ".coverage") { Remove-Item ".coverage" -Force }
if (Test-Path $OutputDir) { Remove-Item $OutputDir -Recurse -Force }

# Run tests with coverage
Write-Info "Running tests with coverage collection..."
try {
    $coverageArgs = @(
        "run",
        "--source=src",
        "--branch",
        "-m", "pytest",
        "tests/",
        "-v",
        "--tb=short"
    )
    & coverage @coverageArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Failure "Tests failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} catch {
    Write-Failure "Error running tests: $_"
    exit 1
}

Write-Success "All tests passed."

# Generate coverage reports
Write-Info "Generating coverage reports..."

# Terminal report
Write-Info "Coverage summary:"
& coverage report --show-missing

# HTML report
Write-Info "Generating HTML report in '$OutputDir'..."
& coverage html -d $OutputDir

# XML report (for CI integration)
Write-Info "Generating XML report..."
& coverage xml -o "$OutputDir/coverage.xml"

# Extract total coverage percentage
$coverageOutput = & coverage report --format=total 2>&1
$totalCoverage = [int]($coverageOutput -replace '[^0-9]', '')

Write-Info "Total coverage: $totalCoverage%"

# Check threshold
if ($FailUnderThreshold) {
    if ($totalCoverage -lt [int]$MinCoverage) {
        Write-Failure "Coverage $totalCoverage% is below minimum threshold of $MinCoverage%"
        exit 1
    } else {
        Write-Success "Coverage $totalCoverage% meets the minimum threshold of $MinCoverage%"
    }
}

# Optionally open HTML report
if ($OpenReport) {
    $reportPath = Join-Path $OutputDir "index.html"
    if (Test-Path $reportPath) {
        Write-Info "Opening coverage report in browser..."
        Start-Process $reportPath
    }
}

Write-Success "Test coverage run complete. Report available at: $OutputDir/index.html"
exit 0
