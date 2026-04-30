# Lint and Format Skill - PowerShell Script
# Runs linting and formatting checks for the openai-agents-python project on Windows

param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Fix = $false,
    [switch]$CheckOnly = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "[lint-and-format] $Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Status $Message "Green"
}

function Write-Failure {
    param([string]$Message)
    Write-Status $Message "Red"
}

# Verify we are in the project root
if (-not (Test-Path (Join-Path $ProjectRoot "pyproject.toml"))) {
    Write-Failure "pyproject.toml not found in '$ProjectRoot'. Please run from the project root."
    exit 1
}

Set-Location $ProjectRoot

# Check for uv or pip
$UseUv = $false
if (Get-Command "uv" -ErrorAction SilentlyContinue) {
    $UseUv = $true
    Write-Status "Using uv for package management"
} elseif (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    Write-Failure "Neither 'uv' nor 'python' found. Please install Python or uv."
    exit 1
}

function Invoke-Tool {
    param([string]$ToolName, [string[]]$Args)
    if ($UseUv) {
        $allArgs = @("run", $ToolName) + $Args
        & uv @allArgs
    } else {
        & python -m $ToolName @Args
    }
    return $LASTEXITCODE
}

$OverallSuccess = $true

# ── Ruff Linting ──────────────────────────────────────────────────────────────
Write-Status "Running ruff linter..."

$ruffArgs = @(".")
if ($Fix -and -not $CheckOnly) {
    $ruffArgs = @("check", "--fix", ".")
} else {
    $ruffArgs = @("check", ".")
}

if ($Verbose) { Write-Status "ruff $ruffArgs" }

$exitCode = Invoke-Tool "ruff" $ruffArgs
if ($exitCode -ne 0) {
    Write-Failure "Ruff linting failed (exit $exitCode)"
    $OverallSuccess = $false
} else {
    Write-Success "Ruff linting passed"
}

# ── Ruff Formatting ───────────────────────────────────────────────────────────
Write-Status "Running ruff formatter..."

if ($CheckOnly) {
    $fmtArgs = @("format", "--check", ".")
} elseif ($Fix) {
    $fmtArgs = @("format", ".")
} else {
    $fmtArgs = @("format", "--check", ".")
}

if ($Verbose) { Write-Status "ruff $fmtArgs" }

$exitCode = Invoke-Tool "ruff" $fmtArgs
if ($exitCode -ne 0) {
    Write-Failure "Ruff format check failed (exit $exitCode)"
    if (-not $Fix) {
        Write-Status "Tip: run with -Fix to auto-format" "Yellow"
    }
    $OverallSuccess = $false
} else {
    Write-Success "Ruff format check passed"
}

# ── Pyright Type Checking ─────────────────────────────────────────────────────
Write-Status "Running pyright type checker..."

if (Get-Command "pyright" -ErrorAction SilentlyContinue) {
    & pyright
    $exitCode = $LASTEXITCODE
} elseif ($UseUv) {
    & uv run pyright
    $exitCode = $LASTEXITCODE
} else {
    Write-Status "pyright not found, skipping type check" "Yellow"
    $exitCode = 0
}

if ($exitCode -ne 0) {
    Write-Failure "Pyright type checking failed (exit $exitCode)"
    $OverallSuccess = $false
} else {
    Write-Success "Pyright type checking passed"
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
if ($OverallSuccess) {
    Write-Success "All lint and format checks passed."
    exit 0
} else {
    Write-Failure "One or more lint/format checks failed."
    exit 1
}
