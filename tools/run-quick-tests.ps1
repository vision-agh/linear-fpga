$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Python = Join-Path $RepoRoot ".venv\Scripts\python.exe"

& $Python (Join-Path $RepoRoot "HW\quick_tests\run_quick_tests.py")
exit $LASTEXITCODE
