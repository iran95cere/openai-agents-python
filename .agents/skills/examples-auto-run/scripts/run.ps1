# Examples Auto-Run Script for Windows PowerShell
# Automatically discovers and runs all examples in the repository,
# capturing output and reporting success/failure for each.

param(
    [string]$ExamplesDir = "examples",
    [int]$TimeoutSeconds = 60,
    [switch]$StopOnFailure,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..\..\..")

# Results tracking
$Results = @{
    Passed  = @()
    Failed  = @()
    Skipped = @()
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Write-Result {
    param(
        [string]$Status,
        [string]$Example,
        [string]$Detail = ""
    )
    switch ($Status) {
        "PASS"  { Write-Host "  [PASS] $Example" -ForegroundColor Green }
        "FAIL"  { Write-Host "  [FAIL] $Example - $Detail" -ForegroundColor Red }
        "SKIP"  { Write-Host "  [SKIP] $Example - $Detail" -ForegroundColor Yellow }
    }
}

function Test-PythonAvailable {
    try {
        $null = python --version 2>&1
        return $true
    } catch {
        return $false
    }
}

function Get-ExampleFiles {
    param([string]$Directory)
    $fullPath = Join-Path $RepoRoot $Directory
    if (-not (Test-Path $fullPath)) {
        Write-Host "Examples directory not found: $fullPath" -ForegroundColor Yellow
        return @()
    }
    return Get-ChildItem -Path $fullPath -Filter "*.py" -Recurse |
        Where-Object { $_.Name -notlike "_*" } |
        Sort-Object FullName
}

function Invoke-Example {
    param(
        [System.IO.FileInfo]$File
    )
    $relativePath = $File.FullName.Substring($RepoRoot.Path.Length + 1)

    # Check for skip marker in file content
    $content = Get-Content $File.FullName -Raw
    if ($content -match "# skip-auto-run") {
        $Results.Skipped += $relativePath
        Write-Result -Status "SKIP" -Example $relativePath -Detail "marked skip-auto-run"
        return
    }

    if ($Verbose) {
        Write-Host "  Running: $relativePath" -ForegroundColor Gray
    }

    try {
        $process = Start-Process -FilePath "python" `
            -ArgumentList "`"$($File.FullName)`"" `
            -WorkingDirectory $RepoRoot `
            -PassThru `
            -NoNewWindow `
            -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) `
            -RedirectStandardError  ([System.IO.Path]::GetTempFileName())

        $finished = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $finished) {
            $process.Kill()
            $Results.Failed += $relativePath
            Write-Result -Status "FAIL" -Example $relativePath -Detail "timed out after ${TimeoutSeconds}s"
            return
        }

        if ($process.ExitCode -eq 0) {
            $Results.Passed += $relativePath
            Write-Result -Status "PASS" -Example $relativePath
        } else {
            $Results.Failed += $relativePath
            Write-Result -Status "FAIL" -Example $relativePath -Detail "exit code $($process.ExitCode)"
        }
    } catch {
        $Results.Failed += $relativePath
        Write-Result -Status "FAIL" -Example $relativePath -Detail $_.Exception.Message
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Header "Examples Auto-Run"
Write-Host "  Repo root  : $RepoRoot"
Write-Host "  Examples   : $ExamplesDir"
Write-Host "  Timeout    : ${TimeoutSeconds}s per example"

if (-not (Test-PythonAvailable)) {
    Write-Host "Python is not available on PATH. Aborting." -ForegroundColor Red
    exit 1
}

$examples = Get-ExampleFiles -Directory $ExamplesDir
if ($examples.Count -eq 0) {
    Write-Host "No example files found. Nothing to run." -ForegroundColor Yellow
    exit 0
}

Write-Host "  Found $($examples.Count) example file(s)`n"

foreach ($example in $examples) {
    Invoke-Example -File $example
    if ($StopOnFailure -and $Results.Failed.Count -gt 0) {
        Write-Host "`nStopping on first failure (--StopOnFailure)." -ForegroundColor Red
        break
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Header "Summary"
Write-Host "  Passed  : $($Results.Passed.Count)" -ForegroundColor Green
Write-Host "  Failed  : $($Results.Failed.Count)" -ForegroundColor $(if ($Results.Failed.Count -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Skipped : $($Results.Skipped.Count)" -ForegroundColor Yellow

if ($Results.Failed.Count -gt 0) {
    Write-Host "`nFailed examples:" -ForegroundColor Red
    $Results.Failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "`nAll examples passed." -ForegroundColor Green
exit 0
