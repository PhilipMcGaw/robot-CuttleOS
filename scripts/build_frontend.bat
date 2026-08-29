@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
set "FRONTEND_DIR=%PROJECT_ROOT%\frontend\cockpit"
set "STATIC_DIR=%PROJECT_ROOT%\cockpit\src\rov_cockpit\static"
set "PATH=%PROJECT_ROOT%\node-runtime;%PATH%"
echo [INFO] TypeScript frontend build
if not exist "%FRONTEND_DIR%\package.json" (
 echo [FAIL] Frontend package manifest not found: %FRONTEND_DIR%\package.json
 echo [FAIL] Why it matters: npm cannot install or build the TypeScript frontend.
 echo [FAIL] Corrective action: restore package.json to frontend/cockpit.
 exit /b 1
)
set "NPM=%PROJECT_ROOT%\node-runtime\npm.cmd"
if not exist "%NPM%" call "%SCRIPT_DIR%bootstrap_node.bat"
if errorlevel 1 exit /b 1
if not exist "%NPM%" (
 echo [WARN] Portable npm is unavailable; retaining existing compiled frontend.
 exit /b 0
)
pushd "%FRONTEND_DIR%"
call "%NPM%" install --no-audit --no-fund
if errorlevel 1 exit /b 1
call "%NPM%" run build
if errorlevel 1 exit /b 1
if exist "%FRONTEND_DIR%\node_modules\@picocss\pico\css\pico.css" copy /Y "%FRONTEND_DIR%\node_modules\@picocss\pico\css\pico.css" "%STATIC_DIR%\css\pico.css" >nul
popd
echo [PASS] TypeScript frontend compiled successfully.
exit /b 0
