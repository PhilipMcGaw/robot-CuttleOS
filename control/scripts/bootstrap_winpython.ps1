[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$shared = Join-Path (Split-Path -Parent $PSScriptRoot) '..\ROV---Cockpit\scripts\bootstrap_winpython.ps1'
& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $shared -ProjectRoot $ProjectRoot
exit $LASTEXITCODE
