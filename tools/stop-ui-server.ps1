$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PidFile = Join-Path $RepoRoot "tmp\ui\ui_server.pid"

if (-not (Test-Path $PidFile)) {
    Write-Output "No UI server PID file found."
    exit 0
}

$ServerPid = Get-Content $PidFile -ErrorAction SilentlyContinue
if (-not $ServerPid) {
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    Write-Output "Empty UI server PID file removed."
    exit 0
}

$Process = Get-Process -Id $ServerPid -ErrorAction SilentlyContinue
if ($Process) {
    Stop-Process -Id $ServerPid -Force
    Write-Output "Stopped UI server (PID $ServerPid)"
} else {
    Write-Output "UI server PID $ServerPid was not running."
}

Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
