$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OssRoot = Join-Path $RepoRoot "tools\oss-cad-suite\oss-cad-suite"
$Vvp = Join-Path $OssRoot "bin\vvp.exe"

$filteredPath = ($env:PATH -split ';' | Where-Object {
    $_ -and $_ -notmatch '\\msys64\\' -and $_ -notmatch '\\mingw64\\'
}) -join ';'
$env:PATH = "$OssRoot\bin;$OssRoot\lib;$filteredPath"

& $Vvp @args
exit $LASTEXITCODE
