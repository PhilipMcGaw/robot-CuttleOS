[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot); $NodeRoot=Join-Path $ProjectRoot 'node-runtime'; $NodeExe=Join-Path $NodeRoot 'node.exe'; $NpmCmd=Join-Path $NodeRoot 'npm.cmd'; $Version='v22.14.0'; $Stage=Join-Path $ProjectRoot '_bootstrap_node'
Write-Host '[INFO] Portable Node.js/npm bootstrap'; Write-Host "[INFO] Project directory: $ProjectRoot"; Write-Host "[INFO] Runtime location: $NodeRoot"; Write-Host '[INFO] Operating mode: project-local; no administrator rights requested'
if($ProjectRoot.StartsWith('\')){throw "[FAIL] Direct UNC execution is unsupported: $ProjectRoot. Corrective action: copy the project locally or map the share to a drive letter."}
if((Test-Path $NodeExe) -and (Test-Path $NpmCmd)){Write-Host "[PASS] Portable Node.js/npm already exists: $NodeRoot"; exit 0}
if(Test-Path $NodeRoot){throw "[FAIL] Node runtime folder exists but is incomplete: $NodeRoot. Corrective action: preserve diagnostics, then rename or remove it and retry."}
New-Item -ItemType Directory -Path $Stage -Force | Out-Null
$archive=Join-Path $Stage "node-$Version-win-x64.zip"; $checks=Join-Path $Stage 'SHASUMS256.txt'; $base="https://nodejs.org/dist/$Version"
Invoke-WebRequest -Uri "$base/SHASUMS256.txt" -OutFile $checks; $line=Get-Content $checks | Where-Object {$_ -match "node-$Version-win-x64\.zip$"} | Select-Object -First 1
if(-not $line){throw '[FAIL] The pinned Node.js archive was not present in the trusted checksum manifest.'}; $expected=($line -split '\s+')[0]
Invoke-WebRequest -Uri "$base/node-$Version-win-x64.zip" -OutFile $archive
if((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected.ToLowerInvariant()){throw '[FAIL] Node.js SHA-256 verification failed.'}
Expand-Archive $archive $Stage -Force; Move-Item (Join-Path $Stage "node-$Version-win-x64") $NodeRoot
if(!(Test-Path $NodeExe) -or !(Test-Path $NpmCmd)){throw '[FAIL] Node.js/npm were not found after extraction.'}; & $NodeExe --version; & $NpmCmd --version
Remove-Item $Stage -Recurse -Force; Write-Host "[PASS] Portable Node.js/npm is ready: $NodeRoot"
