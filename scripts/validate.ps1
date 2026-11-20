[CmdletBinding()]
param(
    [ValidateSet("all", "charger", "hmi")]
    [string]$Target = "all",
    [switch]$ConfigOnly,
    [switch]$Setup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvDir = Join-Path $RepoRoot ".venv"
$VenvPython = Join-Path $VenvDir "Scripts/python.exe"
$Requirements = Join-Path $RepoRoot "requirements-dev.txt"
$SecretsFile = Join-Path $RepoRoot "secrets.yaml"
$SecretsExample = Join-Path $RepoRoot "secrets.example.yaml"

$Targets = [ordered]@{
    charger = "r4875g1-3phase-charger.yaml"
    hmi     = "r4875g1-remote-hmi.yaml"
}

# Interpreter versions with prebuilt wheels for all ESPHome dependencies.
# Newer Python releases may require a local C++ build toolchain.
$PythonCandidates = @("3.13", "3.12", "3.11")

function Write-Step([string]$Message) { Write-Host "[ STEP ] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "[  OK  ] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[ WARN ] $Message" -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host "[ FAIL ] $Message" -ForegroundColor Red }

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Find-PythonVersion {
    Assert-Command "py"
    foreach ($candidate in $PythonCandidates) {
        & py "-$candidate" -c "import sys" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }
    throw "No suitable Python interpreter found through the 'py' launcher. Install Python 3.13 (for example with 'py install 3.13') and run -Setup again."
}

function Initialize-Venv {
    if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
        $version = Find-PythonVersion
        Write-Step "Creating virtual environment with Python $version"
        & py "-$version" -m venv $VenvDir
        if ($LASTEXITCODE -ne 0) {
            throw "Creating the virtual environment failed with exit code $LASTEXITCODE."
        }
    } else {
        Write-Ok "Virtual environment found: $VenvDir"
    }

    Write-Step "Installing development requirements"
    & $VenvPython -m pip install --upgrade pip --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "Upgrading pip failed with exit code $LASTEXITCODE."
    }
    & $VenvPython -m pip install -r $Requirements --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "Installing $Requirements failed with exit code $LASTEXITCODE."
    }
    Write-Ok "Development requirements installed"
}

function Initialize-Secrets {
    if (Test-Path -LiteralPath $SecretsFile -PathType Leaf) {
        return
    }
    Copy-Item -LiteralPath $SecretsExample -Destination $SecretsFile
    Write-Warn "secrets.yaml was missing and has been created from secrets.example.yaml."
    Write-Warn "It contains dummy values for local validation only."
}

Write-Host ""
Write-Host "R4875G1 3-Phase Charger - Local ESPHome Validation" -ForegroundColor White
Write-Host "==================================================" -ForegroundColor White
Write-Host ""

if ($Setup) {
    Initialize-Venv
}

if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
    throw "Virtual environment not found. Run 'scripts/validate.ps1 -Setup' first."
}

Initialize-Secrets

$selected = if ($Target -eq "all") { @($Targets.Keys) } else { @($Target) }
$failures = @()

Push-Location $RepoRoot
try {
    foreach ($name in $selected) {
        $file = $Targets[$name]

        Write-Step "Validating configuration: $file"
        & $VenvPython -m esphome config $file | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Configuration validation failed: $file"
            # Repeat with output so the validation error is visible.
            & $VenvPython -m esphome config $file
            $failures += "$name (config)"
            continue
        }
        Write-Ok "Configuration valid: $file"

        if ($ConfigOnly) {
            continue
        }

        Write-Step "Compiling: $file"
        & $VenvPython -m esphome compile $file
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Compilation failed: $file"
            $failures += "$name (compile)"
            continue
        }
        Write-Ok "Compilation succeeded: $file"
    }
} finally {
    Pop-Location
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Fail "Validation failed for: $($failures -join ', ')"
    exit 1
}

Write-Ok "All selected targets passed."
exit 0
