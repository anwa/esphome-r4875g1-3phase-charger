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
$VersionFile = "packages/version.yaml"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$DeploymentProjectPath = $null

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

    $managedFiles = @()

    # Home Assistant needs the ESPHome YAML package tree.
    $managedFiles += @(
        Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Filter "*.yaml" |
            Sort-Object FullName |
            ForEach-Object {
                [System.IO.Path]::GetRelativePath(
                    $RepoRoot,
                    $_.FullName
                ).Replace('\', '/')
            }
    )

    # Additional ESPHome source/include files required by the main YAML.
    $extraFiles = @(
        "trend_helpers.h"
    )

    foreach ($relativePath in $extraFiles) {
        $fullPath = Join-Path $RepoRoot $relativePath

        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Required deployment file is missing: $relativePath"
        }

        $managedFiles += $relativePath
    }

    return @(
        $managedFiles |
            Sort-Object -Unique
    )
}

function Get-RemoteManagedPath([string]$RelativePath, [string]$NodeName) {
    $normalized = $RelativePath.Replace('\', '/')

    # Repository package files:
    #
    #   packages/version.yaml
    #       ->
    #   packages/<node-name>/version.yaml
    #
    if ($normalized.StartsWith("packages/")) {
        $packageRelativePath =
            $normalized.Substring("packages/".Length)

        return "packages/$NodeName/$packageRelativePath"
    }

    # Repository root include files:
    #
    #   trend_helpers.h
    #       ->
    #   packages/<node-name>/trend_helpers.h
    #
    return "packages/$NodeName/$normalized"
}

function New-DeploymentProjectFile(
    [string]$SourcePath,
    [string]$NodeName
) {
    $content = Get-Content -Raw -LiteralPath $SourcePath

    # Rewrite root package includes only in the temporary deployment copy:
    #
    #   !include packages/version.yaml
    #       ->
    #   !include packages/<node-name>/version.yaml
    #
    # This also covers parameterized package includes such as:
    #
    #   file: packages/rectifier-unit.yaml
    #
    # because the repository source remains unchanged and only the generated
    # Home Assistant copy receives the node-specific package namespace.
    $content = [regex]::Replace(
        $content,
        '(?m)(!include\s+)packages/',
        "`$1packages/$NodeName/"
    )

    $content = [regex]::Replace(
        $content,
        '(?m)(file:\s*)packages/',
        "`$1packages/$NodeName/"
    )

    # Root-level ESPHome include files are deployed into the same node-specific
    # package namespace.
    #
    #   - trend_helpers.h
    #       ->
    #   - packages/<node-name>/trend_helpers.h
    #
    $content = [regex]::Replace(
        $content,
        '(?m)^(\s*-\s*)trend_helpers\.h(\s*(?:#.*)?)$',
        "`${1}packages/$NodeName/trend_helpers.h`${2}"
    )

    $tempPath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        "$NodeName-$Timestamp-deploy.yaml"

    Set-Content `
        -LiteralPath $tempPath `
        -Value $content `
        -Encoding utf8 `
        -NoNewline

    return $tempPath
}

function Remove-DeploymentProjectFile {
    if (
        $null -ne $script:DeploymentProjectPath -and
        (Test-Path -LiteralPath $script:DeploymentProjectPath)
    ) {
        Remove-Item `
            -LiteralPath $script:DeploymentProjectPath `
            -Force `
            -ErrorAction SilentlyContinue

        $script:DeploymentProjectPath = $null
    }
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
    $versionPath = Join-Path $RepoRoot $VersionFile
    if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
        throw "Central firmware version file is missing: $VersionFile"
    }

    $yaml = Get-Content -Raw -LiteralPath $versionPath
    $matches = [regex]::Matches(
        $yaml,
        '(?m)^\s*firmware_version:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+)["'']?\s*(?:#.*)?$'
    )

    if ($matches.Count -eq 0) {
        throw "No valid firmware_version entry found in $VersionFile."
    }
    if ($matches.Count -gt 1) {
        throw "Multiple firmware_version entries found in $VersionFile."
    }

    return $matches[0].Groups[1].Value
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

    $sortProperties = @(
        @{ Expression = { ($_ -split '/').Count }; Ascending = $true }
        @{ Expression = { $_ }; Ascending = $true }
    )

    return @($dirs | Sort-Object -Property $sortProperties)
}

function New-RemoteDirectories([string]$Root, [string[]]$RelativePaths) {
    $commands = @("set -eu", "mkdir -p $(Quote-Sh $Root)")
    foreach ($dir in (Get-ParentDirectories $RelativePaths)) {
        $commands += "mkdir -p $(Quote-Sh "$Root/$dir")"
    }
    Invoke-HaSsh ($commands -join "; ") | Out-Null
}

Write-Host ""
Write-Host "ESPHome - Home Assistant Deployment" -ForegroundColor White
Write-Host "===================================" -ForegroundColor White
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
$RemotePackageRoot = "packages/$nodeName"
$RemoteManagedFiles = @{}
foreach ($relativePath in $ManagedFiles) {
    $RemoteManagedFiles[$relativePath] =
        Get-RemoteManagedPath $relativePath $nodeName
}
$version = Get-ProjectVersion
$BackupDir =
    "$RemoteDir/.deploy-backups/$nodeName/$Timestamp"
$StagingDir =
    "$RemoteDir/.deploy-staging/$nodeName-$Timestamp"
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
Write-Host "  ESPHome directory: $RemoteDir"
Write-Host "  Main YAML remote : $RemoteProjectFile"
Write-Host "  Package namespace: $RemotePackageRoot"
Write-Host "  SSH              : $HaUser@$HaHost`:$Port"
Write-Host "  SSH key          : $KeyPath"
Write-Host "  SSH MAC          : $MacAlgorithm"
Write-Host ""

if ($gitInfo.Dirty) {
    Write-Warn "The Git working tree contains uncommitted changes; those local files will be deployed."
}

if ($DryRun) {
    $DeploymentProjectPath =
        New-DeploymentProjectFile $projectPath $nodeName

    Write-Step "Dry run - no network connection and no remote changes"

    Write-Host "  $ProjectFile -> $RemoteDir/$RemoteProjectFile"

    foreach ($relativePath in $ManagedFiles) {
        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        Write-Host "  $relativePath -> $RemoteDir/$remoteRelativePath"
    }

    Write-Host ""
    Write-Host "Generated main YAML references:" -ForegroundColor White

    $deploymentContent =
        Get-Content -Raw -LiteralPath $DeploymentProjectPath

    $deploymentContent -split "`r?`n" |
        Where-Object {
            $_ -match 'packages/' -and
            (
                $_ -match '!include' -or
                $_ -match 'file:' -or
                $_ -match 'trend_helpers'
            )
        } |
        ForEach-Object {
            Write-Host "  $($_.Trim())"
        }

    Remove-DeploymentProjectFile

    Write-Ok "Dry run complete"
    return
}

if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw "SSH private key not found: $KeyPath`nRun .\scripts\setup-ha-ssh.ps1 first."
}

$DeploymentProjectPath =
    New-DeploymentProjectFile $projectPath $nodeName

Write-Step "Checking SSH connection"
Invoke-HaSsh "true" | Out-Null
Write-Ok "SSH connection established"

$qStaging = Quote-Sh $StagingDir

try {
    Write-Step "Creating remote staging directory tree"
    Invoke-HaSsh "set -eu; rm -rf $qStaging" | Out-Null
    New-RemoteDirectories `
        $StagingDir `
        @($RemoteManagedFiles.Values)
    Write-Host "  $ProjectFile -> $RemoteProjectFile"

    foreach ($relativePath in $ManagedFiles) {
        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        Write-Host "  $relativePath -> $remoteRelativePath"
    }
    Write-Step "Uploading managed ESPHome files"
    Send-HaFile `
        $DeploymentProjectPath `
        "$StagingDir/$RemoteProjectFile"
    foreach ($relativePath in $ManagedFiles) {
        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        Send-HaFile `
            (Join-Path $RepoRoot $relativePath) `
            "$StagingDir/$remoteRelativePath"
    }
    Write-Ok "Upload complete"

    Write-Step "Verifying staged SHA-256 hashes"
    $projectHash =
        (
            Get-FileHash `
                -Algorithm SHA256 `
                -LiteralPath $DeploymentProjectPath
        ).Hash.ToLowerInvariant()
    $qProjectStaged = Quote-Sh "$StagingDir/$RemoteProjectFile"
    $remoteProjectHash = ((Invoke-HaSsh "sha256sum $qProjectStaged | cut -d ' ' -f 1") | Out-String).Trim().ToLowerInvariant()
    if ($remoteProjectHash -ne $projectHash) {
        throw "Hash mismatch after upload: $ProjectFile -> $RemoteProjectFile"
    }

    foreach ($relativePath in $ManagedFiles) {
        $localHash =
            (
                Get-FileHash `
                    -Algorithm SHA256 `
                    -LiteralPath (Join-Path $RepoRoot $relativePath)
            ).Hash.ToLowerInvariant()

        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        $qPath =
            Quote-Sh "$StagingDir/$remoteRelativePath"

        $remoteHash =
            (
                (
                    Invoke-HaSsh `
                        "sha256sum $qPath | cut -d ' ' -f 1"
                ) |
                Out-String
            ).Trim().ToLowerInvariant()

        if ($remoteHash -ne $localHash) {
            throw "Hash mismatch after upload: $relativePath -> $remoteRelativePath"
        }
    }
    Write-Ok "Staged files match local source"

    if (-not $NoBackup) {
        Write-Step "Backing up currently managed Home Assistant files"
        New-RemoteDirectories `
            $BackupDir `
            @($RemoteManagedFiles.Values)

        $commands = @("set -eu")
        $projectSource = Quote-Sh "$RemoteDir/$RemoteProjectFile"
        $projectDest = Quote-Sh "$BackupDir/$RemoteProjectFile"
        $commands += "if [ -f $projectSource ]; then cp -p $projectSource $projectDest; fi"
        foreach ($relativePath in $ManagedFiles) {
            $remoteRelativePath =
                $RemoteManagedFiles[$relativePath]

            $source =
                Quote-Sh "$RemoteDir/$remoteRelativePath"

            $dest =
                Quote-Sh "$BackupDir/$remoteRelativePath"

            $commands +=
                "if [ -f $source ]; then cp -p $source $dest; fi"
        }
        Invoke-HaSsh ($commands -join "; ") | Out-Null
        Write-Ok "Backup created: $BackupDir"
    } else {
        Write-Warn "Backup disabled by -NoBackup"
    }

    Write-Step "Installing staged files"
    New-RemoteDirectories `
        $RemoteDir `
        @($RemoteManagedFiles.Values)

    $commands = @("set -eu")
    $projectSource = Quote-Sh "$StagingDir/$RemoteProjectFile"
    $projectDest = Quote-Sh "$RemoteDir/$RemoteProjectFile"
    $commands += "cp -p $projectSource $projectDest"
    foreach ($relativePath in $ManagedFiles) {
        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        $source =
            Quote-Sh "$StagingDir/$remoteRelativePath"

        $dest =
            Quote-Sh "$RemoteDir/$remoteRelativePath"

        $commands +=
            "cp -p $source $dest"
    }
    Invoke-HaSsh ($commands -join "; ") | Out-Null

    Write-Step "Verifying installed files"
    $qProjectInstalled = Quote-Sh "$RemoteDir/$RemoteProjectFile"
    $installedProjectHash = ((Invoke-HaSsh "sha256sum $qProjectInstalled | cut -d ' ' -f 1") | Out-String).Trim().ToLowerInvariant()
    if ($installedProjectHash -ne $projectHash) {
        throw "Installed file verification failed: $RemoteProjectFile"
    }
    foreach ($relativePath in $ManagedFiles) {
        $localHash =
            (
                Get-FileHash `
                    -Algorithm SHA256 `
                    -LiteralPath (Join-Path $RepoRoot $relativePath)
            ).Hash.ToLowerInvariant()

        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        $qPath =
            Quote-Sh "$RemoteDir/$remoteRelativePath"

        $remoteHash =
            (
                (
                    Invoke-HaSsh `
                        "sha256sum $qPath | cut -d ' ' -f 1"
                ) |
                Out-String
            ).Trim().ToLowerInvariant()

        if ($remoteHash -ne $localHash) {
            throw "Installed file verification failed: $relativePath -> $remoteRelativePath"
        }
    }
    Write-Ok "Installed files match local source"
}
finally {
    try { Invoke-HaSsh "rm -rf $qStaging" | Out-Null }
    catch { Write-Warn "Could not remove staging directory: $StagingDir" }
    Remove-DeploymentProjectFile
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
