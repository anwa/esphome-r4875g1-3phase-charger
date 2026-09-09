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
$HmiProjectFile = "r4875g1-remote-hmi.yaml"

$VersionFile = "packages/version.yaml"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$DeploymentProjectPath = $null
$DeploymentHmiProjectPath = $null
$DeploymentBundlePath = $null

# Bound SSH commands and deployment transfers so stalled network operations
# cannot block deployment indefinitely.
$NetworkCommandTimeoutSeconds = 30
$FileTransferTimeoutSeconds = 120

$SshCommandAttempts = 3
$SshCommandRetryDelaySeconds = 2

$FileTransferAttempts = 3
$FileTransferRetryDelaySeconds = 2

$HashVerifyAttempts = 3
$HashVerifyRetryDelaySeconds = 2

function Write-Step([string]$Message) { Write-Host "[DEPLOY] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "[  OK  ] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[ WARN ] $Message" -ForegroundColor Yellow }

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function ConvertTo-ShQuotedString([string]$Value) {
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

    $sourceBaseName =
        [System.IO.Path]::GetFileNameWithoutExtension(
            $SourcePath
        )

    $tempPath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
            "$sourceBaseName-$NodeName-$Timestamp-$PID-deploy.yaml"

    Set-Content `
        -LiteralPath $tempPath `
        -Value $content `
        -Encoding utf8 `
        -NoNewline

    return $tempPath
}

function New-DeploymentBundle(
    [string]$ProjectLocalPath,
    [string]$HmiProjectLocalPath,
    [string]$NodeName,
    [string]$RemoteProjectFile,
    [string]$RemoteHmiProjectFile,
    [string[]]$ManagedFiles,
    [hashtable]$RemoteManagedFiles
) {
    $bundlePath = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        "r4875g1-deploy-$NodeName-$Timestamp-$PID"

    if (Test-Path -LiteralPath $bundlePath) {
        Remove-Item `
            -LiteralPath $bundlePath `
            -Recurse `
            -Force
    }

    New-Item `
        -ItemType Directory `
        -Path $bundlePath `
        -Force |
        Out-Null

    $script:DeploymentBundlePath = $bundlePath

    $script:DeploymentProjectPath =
        New-DeploymentProjectFile `
            $ProjectLocalPath `
            $NodeName

    $script:DeploymentHmiProjectPath =
        New-DeploymentProjectFile `
            $HmiProjectLocalPath `
            $NodeName

    # Place both rewritten root configurations directly in the bundle root.
    Copy-Item `
        -LiteralPath $script:DeploymentProjectPath `
        -Destination (Join-Path $bundlePath $RemoteProjectFile) `
        -Force

    Copy-Item `
        -LiteralPath $script:DeploymentHmiProjectPath `
        -Destination (Join-Path $bundlePath $RemoteHmiProjectFile) `
        -Force

    # Recreate the exact node-specific package namespace that will exist on
    # the Home Assistant host.
    foreach ($relativePath in $ManagedFiles) {
        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        $localRelativePath =
            $remoteRelativePath.Replace(
                '/',
                [System.IO.Path]::DirectorySeparatorChar
            )

        $destinationPath =
            Join-Path `
                $bundlePath `
                $localRelativePath

        $destinationDirectory =
            Split-Path `
                -Parent `
                $destinationPath

        New-Item `
            -ItemType Directory `
            -Path $destinationDirectory `
            -Force |
            Out-Null

        Copy-Item `
            -LiteralPath (Join-Path $RepoRoot $relativePath) `
            -Destination $destinationPath `
            -Force
    }

    return $bundlePath
}

function Remove-DeploymentProjectFiles {
    $temporaryFiles = @(
        $script:DeploymentProjectPath
        $script:DeploymentHmiProjectPath
    )

    foreach ($path in $temporaryFiles) {
        if (
            $null -ne $path -and
            (Test-Path -LiteralPath $path)
        ) {
            Remove-Item `
                -LiteralPath $path `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    if (
        $null -ne $script:DeploymentBundlePath -and
        (Test-Path -LiteralPath $script:DeploymentBundlePath)
    ) {
        Remove-Item `
            -LiteralPath $script:DeploymentBundlePath `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    $script:DeploymentProjectPath = $null
    $script:DeploymentHmiProjectPath = $null
    $script:DeploymentBundlePath = $null
}

function Get-ESPHomeNodeName([string]$ProjectFileName) {
    $projectPath = Join-Path $RepoRoot $ProjectFileName
    $lines = Get-Content -LiteralPath $projectPath

    $inESPHomeBlock = $false
    $esphomeIndent = -1
    $foundNames = @()

    foreach ($line in $lines) {
        if ($line -match '^([ ]*)esphome:\s*(?:#.*)?$') {
            if ($inESPHomeBlock) {
                throw "Multiple top-level 'esphome:' blocks found in $ProjectFileName."
            }

            $inESPHomeBlock = $true
            $esphomeIndent = $Matches[1].Length
            continue
        }

        if (-not $inESPHomeBlock) { continue }
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

        $indent = ([regex]::Match($line, '^ *')).Value.Length

        if ($indent -le $esphomeIndent) {
            break
        }

        if (
            $line -match
            '^\s*name:\s*["'']?([a-zA-Z0-9_-]+)["'']?\s*(?:#.*)?$'
        ) {
            $foundNames += $Matches[1]
        }
    }

    if (-not $inESPHomeBlock) {
        throw "No top-level 'esphome:' block found in $ProjectFileName."
    }

    if ($foundNames.Count -eq 0) {
        throw "No 'name:' entry found inside the 'esphome:' block in $ProjectFileName."
    }

    if ($foundNames.Count -gt 1) {
        throw "Multiple 'name:' entries found inside the 'esphome:' block in $ProjectFileName."
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
    $versionMatches = [regex]::Matches(
        $yaml,
        '(?m)^\s*firmware_version:\s*["'']?([0-9]+\.[0-9]+\.[0-9]+)["'']?\s*(?:#.*)?$'
    )

    if ($versionMatches.Count -eq 0) {
        throw "No valid firmware_version entry found in $VersionFile."
    }
    if ($versionMatches.Count -gt 1) {
        throw "Multiple firmware_version entries found in $VersionFile."
    }

    return $versionMatches[0].Groups[1].Value
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

function Invoke-ExternalProcess(
    [string]$FileName,
    [string[]]$Arguments,
    [int]$TimeoutSeconds
) {
    $startInfo =
        [System.Diagnostics.ProcessStartInfo]::new()

    $startInfo.FileName = $FileName
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    foreach ($argument in $Arguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process =
        [System.Diagnostics.Process]::new()

    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            throw "Could not start process '$FileName'."
        }

        # Read both streams asynchronously so a full output buffer cannot
        # deadlock the child process.
        $stdoutTask =
            $process.StandardOutput.ReadToEndAsync()

        $stderrTask =
            $process.StandardError.ReadToEndAsync()

        if (
            -not $process.WaitForExit(
                $TimeoutSeconds * 1000
            )
        ) {
            try {
                $process.Kill($true)
            } catch {
                try {
                    $process.Kill()
                } catch { }
            }

            $process.WaitForExit()

            $stderr =
                $stderrTask.GetAwaiter().GetResult().Trim()

            $detail =
                if ([string]::IsNullOrWhiteSpace($stderr)) {
                    ""
                } else {
                    " Remote error: $stderr"
                }

            throw (
                "Process '$FileName' timed out after " +
                "$TimeoutSeconds seconds.$detail"
            )
        }

        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut   = $stdoutTask.GetAwaiter().GetResult()
            StdErr   = $stderrTask.GetAwaiter().GetResult()
        }
    }
    finally {
        $process.Dispose()
    }
}

function Test-TransientSshFailure([string]$Message) {
    if ([string]::IsNullOrWhiteSpace($Message)) {
        return $false
    }

    return $Message -match (
        '(?i)' +
        'connection timed out|' +
        'connection reset|' +
        'connection closed|' +
        'connection refused|' +
        'connection aborted|' +
        'no route to host|' +
        'network is unreachable|' +
        'kex_exchange_identification|' +
        'timed out after'
    )
}

function Invoke-HaSsh([string]$Command) {
    $sshArgs = @(
        "-i", $KeyPath,
        "-p", $Port,
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=8",
        "-o", "ConnectionAttempts=1",
        "-o", "ServerAliveInterval=5",
        "-o", "ServerAliveCountMax=3",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "MACs=$MacAlgorithm",
        "$HaUser@$HaHost",
        $Command
    )

    for (
        $attempt = 1;
        $attempt -le $SshCommandAttempts;
        $attempt++
    ) {
        $failure = $null

        try {
            $result =
                Invoke-ExternalProcess `
                    -FileName "ssh" `
                    -Arguments $sshArgs `
                    -TimeoutSeconds $NetworkCommandTimeoutSeconds

            if ($result.ExitCode -eq 0) {
                return @(
                    $result.StdOut -split "\r?\n" |
                        Where-Object {
                            -not [string]::IsNullOrWhiteSpace($_)
                        }
                )
            }

            $stderr = $result.StdErr.Trim()

            $failure =
                if ([string]::IsNullOrWhiteSpace($stderr)) {
                    "ssh exited with code $($result.ExitCode)"
                } else {
                    $stderr
                }
        }
        catch {
            $failure = $_.Exception.Message
        }

        $transient =
            Test-TransientSshFailure $failure

        if (
            -not $transient -or
            $attempt -ge $SshCommandAttempts
        ) {
            throw (
                "SSH command failed after $attempt attempt(s). " +
                "Last error: $failure"
            )
        }

        Write-Warn (
            "SSH command attempt " +
            "$attempt/$SshCommandAttempts failed: " +
            "$failure"
        )

        Start-Sleep `
            -Seconds $SshCommandRetryDelaySeconds
    }
}

function Send-HaDeploymentBundle(
    [string]$BundlePath,
    [string]$RemotePath,
    [string]$RemoteProjectFile,
    [string]$RemoteHmiProjectFile
) {
    $sources = @(
        Join-Path $BundlePath $RemoteProjectFile
        Join-Path $BundlePath $RemoteHmiProjectFile
        Join-Path $BundlePath "packages"
    )

    foreach ($source in $sources) {
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Deployment bundle source is missing: $source"
        }
    }

    $scpArgs = @(
        "-i", $KeyPath,
        "-P", $Port,
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=8",
        "-o", "ConnectionAttempts=1",
        "-o", "ServerAliveInterval=5",
        "-o", "ServerAliveCountMax=3",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "MACs=$MacAlgorithm",
        "-r"
    )

    $scpArgs += $sources
    $scpArgs += "$HaUser@${HaHost}:$RemotePath/"

    for (
        $attempt = 1;
        $attempt -le $FileTransferAttempts;
        $attempt++
    ) {
        $failure = $null

        try {
            $result =
                Invoke-ExternalProcess `
                    -FileName "scp" `
                    -Arguments $scpArgs `
                    -TimeoutSeconds $FileTransferTimeoutSeconds

            if ($result.ExitCode -eq 0) {
                return
            }

            $stderr =
                $result.StdErr.Trim()

            $failure =
                if ([string]::IsNullOrWhiteSpace($stderr)) {
                    "scp exited with code $($result.ExitCode)"
                } else {
                    $stderr
                }
        }
        catch {
            $failure =
                $_.Exception.Message
        }

        $transient =
            Test-TransientSshFailure $failure

        if (
            -not $transient -or
            $attempt -ge $FileTransferAttempts
        ) {
            throw (
                "Deployment bundle upload failed after " +
                "$attempt attempt(s). " +
                "Last error: $failure"
            )
        }

        Write-Warn (
            "Deployment bundle upload attempt " +
            "$attempt/$FileTransferAttempts failed: " +
            "$failure"
        )

        Start-Sleep `
            -Seconds $FileTransferRetryDelaySeconds
    }
}

function Get-RemoteSha256Hashes(
    [string[]]$RemotePaths
) {
    if ($RemotePaths.Count -eq 0) {
        return @()
    }

    $quotedPaths = @(
        $RemotePaths |
            ForEach-Object {
                ConvertTo-ShQuotedString $_
            }
    )

    # Hash the complete file set through one SSH session instead of opening
    # one independent SSH connection for every managed file.
    $command =
        "set -eu; sha256sum " +
        ($quotedPaths -join " ")

    for (
        $attempt = 1;
        $attempt -le $HashVerifyAttempts;
        $attempt++
    ) {
        try {
            $output =
                @(Invoke-HaSsh $command)

            $hashes = @()

            foreach ($line in $output) {
                if (
                    $line -match
                    '^([0-9a-fA-F]{64})\s+'
                ) {
                    $hashes +=
                        $Matches[1].ToLowerInvariant()
                }
            }

            if (
                $hashes.Count -ne
                $RemotePaths.Count
            ) {
                throw (
                    "Remote hash output count mismatch: " +
                    "expected $($RemotePaths.Count), " +
                    "received $($hashes.Count)."
                )
            }

            return $hashes
        }
        catch {
            if ($attempt -ge $HashVerifyAttempts) {
                throw
            }

            Write-Warn (
                "Remote SHA-256 verification attempt " +
                "$attempt/$HashVerifyAttempts failed: " +
                $_.Exception.Message
            )

            Start-Sleep `
                -Seconds $HashVerifyRetryDelaySeconds
        }
    }
}

function Assert-RemoteDeploymentMatchesLocal(
    [string]$ProjectLocalPath,
    [string]$ProjectRemotePath,
    [string]$HmiProjectLocalPath,
    [string]$HmiProjectRemotePath,
    [string]$RemoteRoot,
    [string[]]$ManagedFiles,
    [hashtable]$RemoteManagedFiles,
    [string]$FailurePrefix
) {
    $entries = @(
        [pscustomobject]@{
            LocalPath   = $ProjectLocalPath
            RemotePath  = $ProjectRemotePath
            DisplayPath = $RemoteProjectFile
        }

        [pscustomobject]@{
            LocalPath   = $HmiProjectLocalPath
            RemotePath  = $HmiProjectRemotePath
            DisplayPath = $RemoteHmiProjectFile
        }
    )

    foreach ($relativePath in $ManagedFiles) {
        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        $entries +=
            [pscustomobject]@{
                LocalPath =
                    Join-Path `
                        $RepoRoot `
                        $relativePath

                RemotePath =
                    "$RemoteRoot/$remoteRelativePath"

                DisplayPath =
                    "$relativePath -> $remoteRelativePath"
            }
    }

    Write-Host (
        "  Hashing $($entries.Count) remote files " +
        "in one SSH session"
    )

    $remotePaths = @(
        $entries |
            ForEach-Object {
                $_.RemotePath
            }
    )

    $remoteHashes =
        @(Get-RemoteSha256Hashes $remotePaths)

    for (
        $index = 0;
        $index -lt $entries.Count;
        $index++
    ) {
        $localHash =
            (
                Get-FileHash `
                    -Algorithm SHA256 `
                    -LiteralPath $entries[$index].LocalPath
            ).Hash.ToLowerInvariant()

        if (
            $remoteHashes[$index] -ne
            $localHash
        ) {
            throw (
                "$FailurePrefix`: " +
                $entries[$index].DisplayPath
            )
        }
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
    $commands = @("set -eu", "mkdir -p $(ConvertTo-ShQuotedString $Root)")
    foreach ($dir in (Get-ParentDirectories $RelativePaths)) {
        $commands += "mkdir -p $(ConvertTo-ShQuotedString "$Root/$dir")"
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

$projectPath =
    Join-Path $RepoRoot $ProjectFile

$hmiProjectPath =
    Join-Path $RepoRoot $HmiProjectFile

if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
    throw "Required deployment file is missing: $ProjectFile"
}

if (-not (Test-Path -LiteralPath $hmiProjectPath -PathType Leaf)) {
    throw "Required deployment file is missing: $HmiProjectFile"
}

$ManagedFiles = Get-ManagedFiles
foreach ($relativePath in $ManagedFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $relativePath) -PathType Leaf)) {
        throw "Required deployment file is missing: $relativePath"
    }
}
Write-Ok "$($ManagedFiles.Count + 2) managed files found"

$nodeName = Get-ESPHomeNodeName $ProjectFile
$hmiNodeName = Get-ESPHomeNodeName $HmiProjectFile
$RemoteProjectFile = "$nodeName.yaml"
$RemoteHmiProjectFile = "$hmiNodeName.yaml"
# Both targets intentionally use the same deployed package snapshot.
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
Write-Host "  Charger name     : $nodeName"
Write-Host "  Remote HMI name  : $hmiNodeName"
Write-Host "  Git branch       : $($gitInfo.Branch)"
Write-Host "  Git commit       : $($gitInfo.Commit)"
Write-Host "  Working tree     : $(if ($gitInfo.Dirty) { 'DIRTY' } else { 'clean' })"
Write-Host "  Package files    : $($ManagedFiles.Count)"
Write-Host "Target:" -ForegroundColor White
Write-Host "  ESPHome directory: $RemoteDir"
Write-Host "  Charger YAML     : $RemoteProjectFile"
Write-Host "  Remote HMI YAML  : $RemoteHmiProjectFile"
Write-Host "  Package namespace: $RemotePackageRoot"
Write-Host "  SSH              : $HaUser@$HaHost`:$Port"
Write-Host "  SSH key          : $KeyPath"
Write-Host "  SSH MAC          : $MacAlgorithm"
Write-Host ""

if ($gitInfo.Dirty) {
    Write-Warn "The Git working tree contains uncommitted changes; those local files will be deployed."
}

if ($DryRun) {
    $DeploymentBundlePath =
        New-DeploymentBundle `
            -ProjectLocalPath $projectPath `
            -HmiProjectLocalPath $hmiProjectPath `
            -NodeName $nodeName `
            -RemoteProjectFile $RemoteProjectFile `
            -RemoteHmiProjectFile $RemoteHmiProjectFile `
            -ManagedFiles $ManagedFiles `
            -RemoteManagedFiles $RemoteManagedFiles

    Write-Step "Dry run - no network connection and no remote changes"

    Write-Host "  $ProjectFile -> $RemoteDir/$RemoteProjectFile"
    Write-Host "  $HmiProjectFile -> $RemoteDir/$RemoteHmiProjectFile"
    Write-Host "  Deployment bundle: $DeploymentBundlePath"

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

    Write-Host ""
    Write-Host "Generated Remote HMI YAML references:" -ForegroundColor White

    $hmiDeploymentContent =
        Get-Content `
            -Raw `
            -LiteralPath $DeploymentHmiProjectPath

    $hmiDeploymentContent -split "`r?`n" |
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

    Remove-DeploymentProjectFiles

    Write-Ok "Dry run complete"
    return
}

if (-not (Test-Path -LiteralPath $KeyPath -PathType Leaf)) {
    throw "SSH private key not found: $KeyPath`nRun .\scripts\setup-ha-ssh.ps1 first."
}

$DeploymentBundlePath =
    New-DeploymentBundle `
        -ProjectLocalPath $projectPath `
        -HmiProjectLocalPath $hmiProjectPath `
        -NodeName $nodeName `
        -RemoteProjectFile $RemoteProjectFile `
        -RemoteHmiProjectFile $RemoteHmiProjectFile `
        -ManagedFiles $ManagedFiles `
        -RemoteManagedFiles $RemoteManagedFiles

$qStaging = ConvertTo-ShQuotedString $StagingDir

try {
    Write-Step "Creating remote staging directory"

    Invoke-HaSsh (
        "set -eu; " +
        "rm -rf $qStaging; " +
        "mkdir -p $qStaging"
    ) | Out-Null

    Write-Step "Uploading deployment bundle in one SCP session"

    Write-Host (
        "  $($ManagedFiles.Count + 2) managed files " +
        "from one local deployment bundle"
    )

    Send-HaDeploymentBundle `
        -BundlePath $DeploymentBundlePath `
        -RemotePath $StagingDir `
        -RemoteProjectFile $RemoteProjectFile `
        -RemoteHmiProjectFile $RemoteHmiProjectFile

    Write-Ok "Upload complete"

    Write-Step "Verifying staged SHA-256 hashes"

    Assert-RemoteDeploymentMatchesLocal `
        -ProjectLocalPath $DeploymentProjectPath `
        -ProjectRemotePath "$StagingDir/$RemoteProjectFile" `
        -HmiProjectLocalPath $DeploymentHmiProjectPath `
        -HmiProjectRemotePath "$StagingDir/$RemoteHmiProjectFile" `
        -RemoteRoot $StagingDir `
        -ManagedFiles $ManagedFiles `
        -RemoteManagedFiles $RemoteManagedFiles `
        -FailurePrefix "Hash mismatch after upload"

    Write-Ok "Staged files match local source"

    if (-not $NoBackup) {
        Write-Step "Backing up currently managed Home Assistant files"
        New-RemoteDirectories `
            $BackupDir `
            @($RemoteManagedFiles.Values)

        $commands = @("set -eu")
        $projectSource =
            ConvertTo-ShQuotedString `
            "$RemoteDir/$RemoteProjectFile"

        $projectDest =
            ConvertTo-ShQuotedString `
            "$BackupDir/$RemoteProjectFile"

        $commands +=
            "if [ -f $projectSource ]; then cp -p $projectSource $projectDest; fi"

        $hmiProjectSource =
            ConvertTo-ShQuotedString `
            "$RemoteDir/$RemoteHmiProjectFile"

        $hmiProjectDest =
            ConvertTo-ShQuotedString `
            "$BackupDir/$RemoteHmiProjectFile"

        $commands +=
            "if [ -f $hmiProjectSource ]; then cp -p $hmiProjectSource $hmiProjectDest; fi"

        $projectSource =
            ConvertTo-ShQuotedString `
            "$RemoteDir/$RemoteProjectFile"

        foreach ($relativePath in $ManagedFiles) {
            $remoteRelativePath =
                $RemoteManagedFiles[$relativePath]

            $source =
                ConvertTo-ShQuotedString "$RemoteDir/$remoteRelativePath"

            $dest =
                ConvertTo-ShQuotedString "$BackupDir/$remoteRelativePath"

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

    $projectSource =
        ConvertTo-ShQuotedString `
        "$StagingDir/$RemoteProjectFile"

    $projectDest =
        ConvertTo-ShQuotedString `
        "$RemoteDir/$RemoteProjectFile"

    $commands +=
        "cp -p $projectSource $projectDest"

    $hmiProjectSource =
        ConvertTo-ShQuotedString `
            "$StagingDir/$RemoteHmiProjectFile"

    $hmiProjectDest =
        ConvertTo-ShQuotedString `
            "$RemoteDir/$RemoteHmiProjectFile"

    $commands +=
        "cp -p $hmiProjectSource $hmiProjectDest"

    foreach ($relativePath in $ManagedFiles) {
        $remoteRelativePath =
            $RemoteManagedFiles[$relativePath]

        $source =
            ConvertTo-ShQuotedString "$StagingDir/$remoteRelativePath"

        $dest =
            ConvertTo-ShQuotedString "$RemoteDir/$remoteRelativePath"

        $commands +=
            "cp -p $source $dest"
    }
    Invoke-HaSsh ($commands -join "; ") | Out-Null

    Write-Step "Verifying installed files"

    Assert-RemoteDeploymentMatchesLocal `
        -ProjectLocalPath $DeploymentProjectPath `
        -ProjectRemotePath "$RemoteDir/$RemoteProjectFile" `
        -HmiProjectLocalPath $DeploymentHmiProjectPath `
        -HmiProjectRemotePath "$RemoteDir/$RemoteHmiProjectFile" `
        -RemoteRoot $RemoteDir `
        -ManagedFiles $ManagedFiles `
        -RemoteManagedFiles $RemoteManagedFiles `
        -FailurePrefix "Installed file verification failed"

    Write-Ok "Installed files match local source"

}
finally {
    try { Invoke-HaSsh "rm -rf $qStaging" | Out-Null }
    catch { Write-Warn "Could not remove staging directory: $StagingDir" }
    Remove-DeploymentProjectFiles
}

Write-Host ""
Write-Host "Deployment successful" -ForegroundColor Green
Write-Host "  Firmware version : $version"
Write-Host "  Charger name     : $nodeName"
Write-Host "  Remote HMI name  : $hmiNodeName"
Write-Host "  Charger YAML     : $RemoteProjectFile"
Write-Host "  Remote HMI YAML  : $RemoteHmiProjectFile"
Write-Host "  Target           : $HaUser@$HaHost`:$RemoteDir"
Write-Host "  Git commit       : $($gitInfo.Commit)"
if (-not $NoBackup) { Write-Host "  Backup           : $BackupDir" }
Write-Host ""
Write-Host "Next: validate/install the Charger Controller or Remote HMI firmware in the ESPHome add-on." -ForegroundColor White
