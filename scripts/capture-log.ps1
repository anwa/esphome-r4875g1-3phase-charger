[CmdletBinding()]
param(
    [string]$DeviceHost = "hg-dg-technik-charger3ph.local",
    [int]$Port = 80,
    [string]$Username = "",
    [string]$OutputDirectory = "",
    [switch]$KeepAnsi
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepoRoot "logs"
}

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Remove-Ansi([string]$Text) {
    # CSI/ANSI escape sequences used by ESPHome for terminal colors/styles.
    return [regex]::Replace($Text, "`e\[[0-?]*[ -/]*[@-~]", "")
}

Write-Host ""
Write-Host "R4875G1 3-Phase Charger - ESPHome Log Capture" -ForegroundColor White
Write-Host "================================================" -ForegroundColor White
Write-Host ""

Assert-Command "curl.exe"

if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = Read-Host "ESPHome Web UI username"
}

if ([string]::IsNullOrWhiteSpace($Username)) {
    throw "A Web UI username is required because the charger uses Digest authentication."
}

$SecurePassword = Read-Host "ESPHome Web UI password" -AsSecureString
$PasswordPtr = [IntPtr]::Zero
$PlainPassword = $null

try {
    $PasswordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PasswordPtr)

    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

    $SafeHost = ($DeviceHost -replace '[^a-zA-Z0-9._-]', '_')
    $LogFile = Join-Path $OutputDirectory "charger_${SafeHost}_${Timestamp}.log"
    $EventsUrl = "http://${DeviceHost}:$Port/events"

    Write-Host "Source : $EventsUrl"
    Write-Host "Output : $LogFile"
    Write-Host ""
    Write-Host "Capturing live ESPHome log. Press Ctrl+C to stop." -ForegroundColor Cyan
    Write-Host ""

    # ESPHome's Web Server exposes the same debug-log stream used by its browser
    # UI as Server-Sent Events (SSE) on /events. curl.exe is part of current
    # Windows installations and supports the Digest authentication configured on
    # this charger, so no local ESPHome/Python installation is required.
    $CurlArgs = @(
        "--no-buffer",
        "--silent",
        "--show-error",
        "--fail-with-body",
        "--digest",
        "--user", "${Username}:${PlainPassword}",
        "--header", "Accept: text/event-stream",
        $EventsUrl
    )

    $Writer = [System.IO.StreamWriter]::new(
        $LogFile,
        $false,
        [System.Text.UTF8Encoding]::new($false)
    )
    $Writer.AutoFlush = $true

    try {
        $EventType = ""

        & curl.exe @CurlArgs | ForEach-Object {
            $Line = [string]$_

            if ($Line.StartsWith("event:")) {
                $EventType = $Line.Substring(6).Trim()
                return
            }

            if ($EventType -eq "log" -and $Line.StartsWith("data:")) {
                $LogLine = $Line.Substring(5)
                if ($LogLine.StartsWith(" ")) {
                    $LogLine = $LogLine.Substring(1)
                }

                if (-not $KeepAnsi) {
                    $LogLine = Remove-Ansi $LogLine
                }

                Write-Host $LogLine
                $Writer.WriteLine($LogLine)
                return
            }

            # Empty line terminates the current SSE event.
            if ([string]::IsNullOrEmpty($Line)) {
                $EventType = ""
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe ended with exit code $LASTEXITCODE. Check hostname/IP and Web UI credentials."
        }
    }
    finally {
        if ($null -ne $Writer) {
            $Writer.Dispose()
        }
    }
}
finally {
    if ($PasswordPtr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordPtr)
    }
    $PlainPassword = $null
}

Write-Host ""
Write-Host "Log capture finished." -ForegroundColor Green
Write-Host "Saved to: $LogFile"
