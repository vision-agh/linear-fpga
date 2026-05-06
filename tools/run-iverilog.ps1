$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OssRoot = Join-Path $RepoRoot "tools\oss-cad-suite\oss-cad-suite"
$Iverilog = Join-Path $OssRoot "bin\iverilog.exe"

# Strip common conflicting MinGW/MSYS runtimes so Windows resolves the
# matching OSS CAD Suite DLLs instead of unrelated system installs.
$filteredPath = ($env:PATH -split ';' | Where-Object {
    $_ -and $_ -notmatch '\\msys64\\' -and $_ -notmatch '\\mingw64\\'
}) -join ';'
$env:PATH = "$OssRoot\bin;$OssRoot\lib;$filteredPath"

& $Iverilog @args
exit $LASTEXITCODE
