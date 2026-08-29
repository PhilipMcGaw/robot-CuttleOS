[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ProjectRoot)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$PythonRoot = Join-Path $ProjectRoot "runtime"
$PythonExe = Join-Path $PythonRoot "python.exe"
Write-Host "[INFO] ROV Cockpit portable-runtime bootstrap"
Write-Host "[INFO] Project version: unversioned; see MASTER_CONTEXT.md"
Write-Host "[INFO] Project directory: $ProjectRoot"
Write-Host "[INFO] Interpreter/runtime: WinPython will be installed at $PythonExe"
Write-Host "[INFO] Operating mode: project-local Windows runtime; no administrator rights requested"
Write-Host "[INFO] Important paths: temporary bootstrap data will be stored below $(Join-Path $ProjectRoot '_bootstrap_winpython')"
Write-Host "[INFO] Optional components: vendor DLLs and hardware SDKs are not installed or assumed"
if ($ProjectRoot.StartsWith('\\')) { throw "[FAIL] Direct UNC execution is unsupported: $ProjectRoot. Why it matters: local path semantics are required. Corrective action: copy the project locally or map the share to a drive letter." }
if (Test-Path -LiteralPath $PythonExe) { Write-Host "[PASS] Portable Python already exists: $PythonExe"; exit 0 }
if (Test-Path -LiteralPath $PythonRoot) { if (@(Get-ChildItem -LiteralPath $PythonRoot -Force).Count -gt 0) { throw "The runtime folder exists but is incomplete. Rename or remove it, then retry." } }
$bootstrapRoot = Join-Path $ProjectRoot "_bootstrap_winpython"
$archive = Join-Path $bootstrapRoot "winpython.zip"
$extract = Join-Path $bootstrapRoot "extracted"
New-Item -ItemType Directory -Path $extract -Force | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$manifest = Join-Path $bootstrapRoot "winpython-checksums.txt"
Invoke-WebRequest -Uri "https://winpython.github.io/md5_sha1.txt" -UseBasicParsing -OutFile $manifest
$selectedName=$null; $expectedSha256=$null
foreach($series in @("3.13","3.12")){ foreach($line in Get-Content $manifest){ if($line -match "^\s*[0-9a-fA-F]{32}\s*\|\s*[0-9a-fA-F]{40}\s*\|\s*([0-9a-fA-F]{64})\s*\|\s*(WinPython64-" + [regex]::Escape($series) + "\.[0-9.]+dot\.zip)\s*\|"){ $expectedSha256=$Matches[1].ToUpperInvariant();$selectedName=$Matches[2];break } };if($selectedName){break} }
if(-not $selectedName){throw "No stable 64-bit WinPython release was found."}
$candidates=@("https://winpython.github.io/" + $selectedName)
try{[xml]$feed=(Invoke-WebRequest -Uri "https://github.com/winpython/winpython/releases.atom" -UseBasicParsing).Content;foreach($entry in $feed.feed.entry){if($entry.link.href -match '/releases/tag/([^/?#]+)'){ $candidates += "https://github.com/winpython/winpython/releases/download/$([Uri]::EscapeDataString($Matches[1]))/$selectedName" }}}catch{Write-Host "[INFO] Release feed lookup failed; using the official download page."}
$downloaded=$false;foreach($candidate in $candidates){try{Invoke-WebRequest -Uri $candidate -UseBasicParsing -MaximumRedirection 10 -OutFile $archive;if((Get-Item $archive).Length -ge 1000000){$downloaded=$true;break}}catch{Remove-Item $archive -Force -ErrorAction SilentlyContinue}}
if(-not $downloaded){throw "The WinPython archive could not be downloaded from official locations."}
if((Get-FileHash $archive -Algorithm SHA256).Hash.ToUpperInvariant() -ne $expectedSha256){throw "WinPython SHA-256 verification failed."}
Expand-Archive $archive $extract -Force
$found=@(Get-ChildItem $extract -Filter python.exe -File -Recurse | Where-Object {(Test-Path (Join-Path $_.Directory.FullName 'Lib\os.py')) -and (Test-Path (Join-Path $_.Directory.FullName 'DLLs'))})
if($found.Count -ne 1){throw "Expected one usable WinPython runtime, found $($found.Count)."}
Move-Item $found[0].Directory.FullName $PythonRoot
if(-not(Test-Path $PythonExe)){throw "python.exe was not found after extraction."}
& $PythonExe -c "import sys; print(sys.executable); print(sys.version)"
if($LASTEXITCODE -ne 0){throw "The portable Python runtime could not start."}
Remove-Item $bootstrapRoot -Recurse -Force
Write-Host "[PASS] Portable Python is ready: $PythonExe"
