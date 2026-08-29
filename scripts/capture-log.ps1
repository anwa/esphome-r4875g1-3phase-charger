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
    Write-Host "Each saved line receives the Windows receive timestamp for CAN correlation." -ForegroundColor DarkGray
    Write-Host ""

    $CurlArgs = @(
        "--no-buffer", "--silent", "--show-error", "--fail-with-body",
        "--digest", "--user", "${Username}:${PlainPassword}",
        "--header", "Accept: text/event-stream", $EventsUrl
    )

    $Writer = [System.IO.StreamWriter]::new($LogFile, $false, [System.Text.UTF8Encoding]::new($false))
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
                if ($LogLine.StartsWith(" ")) { $LogLine = $LogLine.Substring(1) }
                if (-not $KeepAnsi) { $LogLine = Remove-Ansi $LogLine }

                # Wall-clock receive time enables practical correlation with the
                # Waveshare USB-CAN autosave timestamps. Millisecond resolution is
                # sufficient; normal network/processing latency remains visible.
                $ReceiveTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                $StampedLine = "[$ReceiveTimestamp] $LogLine"

                Write-Host $StampedLine
                $Writer.WriteLine($StampedLine)
                return
            }
            if ([string]::IsNullOrEmpty($Line)) { $EventType = "" }
        }
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe ended with exit code $LASTEXITCODE. Check hostname/IP and Web UI credentials."
        }
    }
    finally {
        if ($null -ne $Writer) { $Writer.Dispose() }
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
