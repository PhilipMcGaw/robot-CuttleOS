@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
set "FRONTEND_DIR=%PROJECT_ROOT%\frontend\cockpit"
set "STATIC_DIR=%PROJECT_ROOT%\cockpit\src\rov_cockpit\static"
set "PATH=%PROJECT_ROOT%\node-runtime;%PATH%"

echo.
echo ======================================================================
echo   CuttleOS - Build Frontend
echo ======================================================================
echo.

echo ----------------------------------------------------------------------
echo   Frontend Source
echo ----------------------------------------------------------------------
echo.
if not exist "%FRONTEND_DIR%\package.json" (
 echo [FAIL] Frontend package manifest not found: %FRONTEND_DIR%\package.json
 echo [FAIL] Corrective action: restore package.json to frontend\cockpit.
 exit /b 1
)
echo [INFO] Frontend: %FRONTEND_DIR%
echo [INFO] Static output: %STATIC_DIR%

echo.
echo ----------------------------------------------------------------------
echo   Node.js / npm
echo ----------------------------------------------------------------------
echo.
set "NPM=%PROJECT_ROOT%\node-runtime\npm.cmd"
if not exist "%NPM%" call "%SCRIPT_DIR%bootstrap_node.bat"
if errorlevel 1 exit /b 1
if not exist "%NPM%" (
 echo [WARN] Portable npm is unavailable; retaining the existing compiled frontend.
 echo.
 echo ======================================================================
 echo   Frontend Build Skipped
echo ======================================================================
 exit /b 0
)
echo [INFO] Using npm: %NPM%

echo.
echo ----------------------------------------------------------------------
echo   Frontend Dependencies
echo ----------------------------------------------------------------------
echo.
pushd "%FRONTEND_DIR%"
call "%NPM%" install --no-audit --no-fund
if errorlevel 1 (
 popd
 echo [FAIL] Frontend dependency installation failed.
 exit /b 1
)
echo [PASS] Frontend dependencies installed.

echo.
echo ----------------------------------------------------------------------
echo   TypeScript Build
echo ----------------------------------------------------------------------
echo.
call "%NPM%" run build
if errorlevel 1 (
 popd
 echo [FAIL] TypeScript frontend build failed.
 exit /b 1
)
echo [PASS] TypeScript frontend compiled successfully.

echo.
echo ----------------------------------------------------------------------
echo   Runtime Assets
echo ----------------------------------------------------------------------
echo.
if exist "%FRONTEND_DIR%\node_modules\@picocss\pico\css\pico.css" copy /Y "%FRONTEND_DIR%\node_modules\@picocss\pico\css\pico.css" "%STATIC_DIR%\css\pico.css" >nul
if exist "%STATIC_DIR%\dist\vendor" goto :vendor_ready
mkdir "%STATIC_DIR%\dist\vendor"
:vendor_ready
if exist "%FRONTEND_DIR%\node_modules\vue\dist\vue.runtime.esm-browser.prod.js" copy /Y "%FRONTEND_DIR%\node_modules\vue\dist\vue.runtime.esm-browser.prod.js" "%STATIC_DIR%\dist\vendor\vue.runtime.esm-browser.prod.js" >nul
popd
echo [PASS] Runtime assets updated.

echo.
echo ======================================================================
echo   Frontend Build Complete
echo ======================================================================
echo.
exit /b 0
