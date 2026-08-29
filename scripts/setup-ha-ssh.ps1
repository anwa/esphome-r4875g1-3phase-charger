[CmdletBinding()]
param(
    [string]$HaHost = "10.10.80.9",
    [string]$HaUser = "root",
    [int]$Port = 22,
    [string]$KeyPath = "$HOME/.ssh/ha_esphome_deploy",
    [string]$MacAlgorithm = "hmac-sha2-512-etm@openssh.com"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

Assert-Command "ssh"
Assert-Command "ssh-keygen"

$keyDir = Split-Path -Parent $KeyPath
if (-not (Test-Path -LiteralPath $keyDir)) {
    New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    Write-Host "Creating dedicated Ed25519 deployment key:" -ForegroundColor Cyan
    Write-Host "  $KeyPath"
    & ssh-keygen -t ed25519 -f $KeyPath -C "ha-esphome-deploy" -N ""
    if ($LASTEXITCODE -ne 0) {
        throw "ssh-keygen failed with exit code $LASTEXITCODE."
    }
} else {
    Write-Host "Existing deployment key found:" -ForegroundColor Green
    Write-Host "  $KeyPath"
}

$publicKeyPath = "$KeyPath.pub"
if (-not (Test-Path -LiteralPath $publicKeyPath -PathType Leaf)) {
    throw "Public key file not found: $publicKeyPath"
}

$publicKey = (Get-Content -Raw -LiteralPath $publicKeyPath).Trim()

Write-Host ""
Write-Host "Public key" -ForegroundColor White
Write-Host "==========" -ForegroundColor White
Write-Host $publicKey -ForegroundColor Yellow
Write-Host ""
Write-Host "Add this public key to the authorized_keys setting/file used by your" -ForegroundColor White
Write-Host "Home Assistant SSH add-on. The exact location depends on the SSH add-on." -ForegroundColor White
Write-Host "Do not copy the private key to Home Assistant." -ForegroundColor White
Write-Host ""

$answer = Read-Host "Press Enter after the key has been installed on Home Assistant, or type 'skip' to finish without testing"
if ($answer -eq "skip") {
    Write-Host "SSH connection test skipped." -ForegroundColor Yellow
    exit 0
}

Write-Host "Testing key-based SSH connection to $HaUser@$HaHost`:$Port ..." -ForegroundColor Cyan
$args = @(
    "-i", $KeyPath,
    "-p", $Port,
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=8",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "MACs=$MacAlgorithm",
    "$HaUser@$HaHost",
    "printf 'SSH key authentication OK\\n'"
)

& ssh @args
if ($LASTEXITCODE -ne 0) {
    throw "Key-based SSH test failed. Check the SSH add-on configuration, username, port and authorized key."
}

Write-Host ""
Write-Host "SSH deployment key is ready." -ForegroundColor Green
Write-Host "You can now run:" -ForegroundColor White
Write-Host "  .\scripts\deploy-ha.ps1" -ForegroundColor Cyan
