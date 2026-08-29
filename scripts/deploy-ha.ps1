[CmdletBinding()]
param(
    [string]$HaHost = "10.10.80.9",
    [string]$HaUser = "root",
    [int]$Port = 22,
    [string]$RemoteDir = "/config/esphome",
    [string]$KeyPath = "$HOME/.ssh/ha_esphome_deploy",
    [string]$MacAlgorithm = "hmac-sha2-512-etm@openssh.com",
    [switch]$DryRun,
    [switch]$NoBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectFile = "r4875g1-3phase-charger.yaml"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = "$RemoteDir/.deploy-backups/r4875g1-3phase-charger/$Timestamp"
$StagingDir = "$RemoteDir/.deploy-staging/r4875g1-3phase-charger-$Timestamp"

function Write-Step([string]$Message) { Write-Host "[DEPLOY] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "[  OK  ] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[ WARN ] $Message" -ForegroundColor Yellow }

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Quote-Sh([string]$Value) {
    if ($Value.Contains("'")) {
        throw "Remote path must not contain an apostrophe: $Value"
    }
    return "'$Value'"
}

function Get-ManagedFiles {
    $packageRoot = Join-Path $RepoRoot "packages"
    if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
        throw "Required package directory is missing: packages"
    }

    return @(
        Get-ChildItem -LiteralPath $packageRoot -File -Recurse |
            Sort-Object FullName |
            ForEach-Object {
                [System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName).Replace('\', '/')
            }
    )
}

function Get-ESPHomeNodeName {
    $projectPath = Join-Path $RepoRoot $ProjectFile
    $lines = Get-Content -LiteralPath $projectPath

    $inESPHomeBlock = $false
    $esphomeIndent = -1
    $foundNames = @()

    foreach ($line in $lines) {
        if ($line -match '^([ ]*)esphome:\s*(?:#.*)?$') {
            if ($inESPHomeBlock) {
                throw "Multiple top-level 'esphome:' blocks found in $ProjectFile."
            }
            $inESPHomeBlock = $true
            $esphomeIndent = $Matches[1].Length
            continue
        }

        if (-not $inESPHomeBlock) { continue }
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

        $indent = ([regex]::Match($line, '^ *')).Value.Length
        if ($indent -le $esphomeIndent) { break }

        if ($line -match '^\s*name:\s*["'']?([a-zA-Z0-9_-]+)["'']?\s*(?:#.*)?$') {
            $foundNames += $Matches[1]
        }
    }

    if (-not $inESPHomeBlock) {
        throw "No top-level 'esphome:' block found in $ProjectFile."
    }
    if ($foundNames.Count -eq 0) {
        throw "No 'name:' entry found inside the 'esphome:' block in $ProjectFile."
    }
    if ($foundNames.Count -gt 1) {
        throw "Multiple 'name:' entries found inside the 'esphome:' block in $ProjectFile."
    }

    $nodeName = $foundNames[0]
    if ($nodeName -notmatch '^[a-z0-9][a-z0-9_-]*$') {
        throw "ESPHome node name '$nodeName' is not valid for automatic deployment filename generation."
    }

    return $nodeName
}

function Get-ProjectVersion {
    $yaml = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot $ProjectFile)
    $match = [regex]::Match(
        $yaml,
        '(?ms)^\s*project:\s*\r?\n\s*name:\s*["'']anwa\.3phase-charger["'']\s*\r?\n\s*version:\s*["'']([^"'']+)["'']'
    )
    if ($match.Success) { return $match.Groups[1].Value }
    return "unknown"
}

function Get-GitInfo {
    $info = [ordered]@{ Commit = "unknown"; Branch = "unknown"; Dirty = $false }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $info }
    try {
        $info.Commit = (& git -C $RepoRoot rev-parse --short HEAD 2>$null).Trim()
        $info.Branch = (& git -C $RepoRoot branch --show-current 2>$null).Trim()
        $info.Dirty = [bool](& git -C $RepoRoot status --porcelain 2>$null)
    } catch { }
    return $info
}

function Invoke-HaSsh([string]$Command) {
    $args = @(
        "-i", $KeyPath,
        "-p", $Port,
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=8",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "MACs=$MacAlgorithm",
        "$HaUser@$HaHost",
        $Command
    )
    $output = & ssh @args
    if ($LASTEXITCODE -ne 0) {
        throw "SSH command failed with exit code $LASTEXITCODE."
    }
    return $output
}

function Send-HaFile([string]$LocalPath, [string]$RemotePath) {
    $args = @(
        "-i", $KeyPath,
        "-P", $Port,
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=8",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "MACs=$MacAlgorithm",
        $LocalPath,
        "$HaUser@${HaHost}:$RemotePath"
    )
    & scp @args
    if ($LASTEXITCODE -ne 0) {
        throw "SCP upload failed for '$LocalPath' with exit code $LASTEXITCODE."
    }
}

function Get-ParentDirectories([string[]]$RelativePaths) {
    $dirs = New-Object System.Collections.Generic.HashSet[string]
    foreach ($relativePath in $RelativePaths) {
        $normalized = $relativePath.Replace('\', '/')
        $parent = [System.IO.Path]::GetDirectoryName($normalized)
        while (-not [string]::IsNullOrWhiteSpace($parent)) {
            $parent = $parent.Replace('\', '/')
            [void]$dirs.Add($parent)
            $parent = [System.IO.Path]::GetDirectoryName($parent)
        }
    }
    return @($dirs | Sort-Object { ($_ -split '/').Count }, $_)
}

function New-RemoteDirectories([string]$Root, [string[]]$RelativePaths) {
    $commands = @("set -eu", "mkdir -p $(Quote-Sh $Root)")
    foreach ($dir in (Get-ParentDirectories $RelativePaths)) {
        $commands += "mkdir -p $(Quote-Sh "$Root/$dir")"
    }
    Invoke-HaSsh ($commands -join "; ") | Out-Null
}

Write-Host ""
Write-Host "R4875G1 3-Phase Charger - Home Assistant Deployment" -ForegroundColor White
Write-Host "======================================================" -ForegroundColor White
Write-Host ""

Write-Step "Checking local source"
Assert-Command "ssh"
Assert-Command "scp"

$projectPath = Join-Path $RepoRoot $ProjectFile
if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
    throw "Required deployment file is missing: $ProjectFile"
}

$ManagedFiles = Get-ManagedFiles
foreach ($relativePath in $ManagedFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $relativePath) -PathType Leaf)) {
        throw "Required deployment file is missing: $relativePath"
    }
}
Write-Ok "$($ManagedFiles.Count + 1) managed files found"

$nodeName = Get-ESPHomeNodeName
$RemoteProjectFile = "$nodeName.yaml"
$version = Get-ProjectVersion
$gitInfo = Get-GitInfo

Write-Host ""
Write-Host "Source:" -ForegroundColor White
Write-Host "  Firmware version : $version"
Write-Host "  ESPHome name     : $nodeName"
Write-Host "  Git branch       : $($gitInfo.Branch)"
Write-Host "  Git commit       : $($gitInfo.Commit)"
Write-Host "  Working tree     : $(if ($gitInfo.Dirty) { 'DIRTY' } else { 'clean' })"
Write-Host "  Package files    : $($ManagedFiles.Count)"
Write-Host "Target:" -ForegroundColor White
Write-Host "  SSH              : $HaUser@$HaHost`:$Port"
Write-Host "  ESPHome directory: $RemoteDir"
Write-Host "  Main YAML remote : $RemoteProjectFile"
Write-Host "  SSH key          : $KeyPath"
Write-Host "  SSH MAC          : $MacAlgorithm"
Write-Host ""

if ($gitInfo.Dirty) {
    Write-Warn "The Git working tree contains uncommitted changes; those local files will be deployed."
}

if ($DryRun) {
    Write-Step "Dry run - no network connection and no remote changes"
    Write-Host "  $ProjectFile -> $RemoteDir/$RemoteProjectFile"
    foreach ($relativePath in $ManagedFiles) {
        Write-Host "  $relativePath -> $RemoteDir/$relativePath"
    }
    Write-Ok "Dry run complete"
    return
}

if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw "SSH private key not found: $KeyPath`nRun .\scripts\setup-ha-ssh.ps1 first."
}

Write-Step "Checking SSH connection"
Invoke-HaSsh "true" | Out-Null
Write-Ok "SSH connection established"

$qStaging = Quote-Sh $StagingDir

try {
    Write-Step "Creating remote staging directory tree"
    Invoke-HaSsh "set -eu; rm -rf $qStaging" | Out-Null
    New-RemoteDirectories $StagingDir $ManagedFiles

    Write-Step "Uploading managed ESPHome files"
    Send-HaFile $projectPath "$StagingDir/$RemoteProjectFile"
    foreach ($relativePath in $ManagedFiles) {
        Send-HaFile (Join-Path $RepoRoot $relativePath) "$StagingDir/$relativePath"
    }
    Write-Ok "Upload complete"

    Write-Step "Verifying staged SHA-256 hashes"
    $projectHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $projectPath).Hash.ToLowerInvariant()
    $qProjectStaged = Quote-Sh "$StagingDir/$RemoteProjectFile"
    $remoteProjectHash = ((Invoke-HaSsh "sha256sum $qProjectStaged | cut -d ' ' -f 1") | Out-String).Trim().ToLowerInvariant()
    if ($remoteProjectHash -ne $projectHash) {
        throw "Hash mismatch after upload: $ProjectFile -> $RemoteProjectFile"
    }

    foreach ($relativePath in $ManagedFiles) {
        $localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RepoRoot $relativePath)).Hash.ToLowerInvariant()
        $qPath = Quote-Sh "$StagingDir/$relativePath"
        $remoteHash = ((Invoke-HaSsh "sha256sum $qPath | cut -d ' ' -f 1") | Out-String).Trim().ToLowerInvariant()
        if ($remoteHash -ne $localHash) {
            throw "Hash mismatch after upload: $relativePath"
        }
    }
    Write-Ok "Staged files match local source"

    if (-not $NoBackup) {
        Write-Step "Backing up currently managed Home Assistant files"
        New-RemoteDirectories $BackupDir $ManagedFiles

        $commands = @("set -eu")
        $projectSource = Quote-Sh "$RemoteDir/$RemoteProjectFile"
        $projectDest = Quote-Sh "$BackupDir/$RemoteProjectFile"
        $commands += "if [ -f $projectSource ]; then cp -p $projectSource $projectDest; fi"
        foreach ($relativePath in $ManagedFiles) {
            $source = Quote-Sh "$RemoteDir/$relativePath"
            $dest = Quote-Sh "$BackupDir/$relativePath"
            $commands += "if [ -f $source ]; then cp -p $source $dest; fi"
        }
        Invoke-HaSsh ($commands -join "; ") | Out-Null
        Write-Ok "Backup created: $BackupDir"
    } else {
        Write-Warn "Backup disabled by -NoBackup"
    }

    Write-Step "Installing staged files"
    New-RemoteDirectories $RemoteDir $ManagedFiles

    $commands = @("set -eu")
    $projectSource = Quote-Sh "$StagingDir/$RemoteProjectFile"
    $projectDest = Quote-Sh "$RemoteDir/$RemoteProjectFile"
    $commands += "cp -p $projectSource $projectDest"
    foreach ($relativePath in $ManagedFiles) {
        $source = Quote-Sh "$StagingDir/$relativePath"
        $dest = Quote-Sh "$RemoteDir/$relativePath"
        $commands += "cp -p $source $dest"
    }
    Invoke-HaSsh ($commands -join "; ") | Out-Null

    Write-Step "Verifying installed files"
    $qProjectInstalled = Quote-Sh "$RemoteDir/$RemoteProjectFile"
    $installedProjectHash = ((Invoke-HaSsh "sha256sum $qProjectInstalled | cut -d ' ' -f 1") | Out-String).Trim().ToLowerInvariant()
    if ($installedProjectHash -ne $projectHash) {
        throw "Installed file verification failed: $RemoteProjectFile"
    }

    foreach ($relativePath in $ManagedFiles) {
        $localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RepoRoot $relativePath)).Hash.ToLowerInvariant()
        $qPath = Quote-Sh "$RemoteDir/$relativePath"
        $remoteHash = ((Invoke-HaSsh "sha256sum $qPath | cut -d ' ' -f 1") | Out-String).Trim().ToLowerInvariant()
        if ($remoteHash -ne $localHash) {
            throw "Installed file verification failed: $relativePath"
        }
    }
    Write-Ok "Installed files match local source"
}
finally {
    try { Invoke-HaSsh "rm -rf $qStaging" | Out-Null }
    catch { Write-Warn "Could not remove staging directory: $StagingDir" }
}

Write-Host ""
Write-Host "Deployment successful" -ForegroundColor Green
Write-Host "  Firmware version : $version"
Write-Host "  ESPHome name     : $nodeName"
Write-Host "  Git commit       : $($gitInfo.Commit)"
Write-Host "  Target           : $HaUser@$HaHost`:$RemoteProjectFile"
if (-not $NoBackup) { Write-Host "  Backup           : $BackupDir" }
Write-Host ""
Write-Host "Next: validate/install the charger firmware in the ESPHome add-on." -ForegroundColor White
