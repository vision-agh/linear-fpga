$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Python = Join-Path $RepoRoot ".venv\Scripts\python.exe"
$LogDir = Join-Path $RepoRoot "tmp\ui"
$PidFile = Join-Path $LogDir "ui_server.pid"
$StdoutLog = Join-Path $LogDir "stdout.log"
$StderrLog = Join-Path $LogDir "stderr.log"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (Test-Path $PidFile) {
    $ExistingPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($ExistingPid) {
        $ExistingProcess = Get-Process -Id $ExistingPid -ErrorAction SilentlyContinue
        if ($ExistingProcess) {
            Write-Output "UI server already running (PID $ExistingPid)"
            exit 0
        }
    }
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
}

$Proc = Start-Process `
    -WindowStyle Hidden `
    -FilePath $Python `
    -ArgumentList @("-u", "tools\ui_server.py") `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $StdoutLog `
    -RedirectStandardError $StderrLog `
    -PassThru

$Proc.Id | Set-Content -Path $PidFile -Encoding ascii
Write-Output "Started UI server (PID $($Proc.Id))"
