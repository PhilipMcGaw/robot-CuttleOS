@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
set "PYTHON=%PROJECT_ROOT%\runtime\python.exe"
set "COCKPIT_DIR=%PROJECT_ROOT%\cockpit\src"

echo.
echo ======================================================================
echo   CuttleOS - Start Cockpit
echo ======================================================================
echo.

echo ----------------------------------------------------------------------
echo   System Checks
echo ----------------------------------------------------------------------
echo.
echo [INFO] Project directory: %PROJECT_ROOT%
echo [INFO] Runtime: %PYTHON%
echo [INFO] Operating mode: local Windows Cockpit with server-side NATS Core connection

if "%SCRIPT_DIR:~0,2%"=="\\" (
 echo [FAIL] Direct UNC execution is unsupported: %SCRIPT_DIR%
 echo [FAIL] Corrective action: copy the project locally or map the share to a drive letter.
 pause
 exit /b 1
)
if not exist "%PYTHON%" (
 echo [FAIL] Project interpreter not found: %PYTHON%
 echo [FAIL] Corrective action: run scripts\1_install_dependencies.bat.
 pause
 exit /b 1
)
if not exist "%COCKPIT_DIR%\rov_cockpit\app.py" (
 echo [FAIL] Cockpit entry point not found: %COCKPIT_DIR%\rov_cockpit\app.py
 echo [FAIL] Corrective action: restore the Cockpit source tree.
 pause
 exit /b 1
)

echo.
echo ----------------------------------------------------------------------
echo   Frontend Build
echo ----------------------------------------------------------------------
echo.
call "%SCRIPT_DIR%build_frontend.bat"
if errorlevel 1 (
 echo [FAIL] Frontend build failed.
 pause
 exit /b 1
)
echo [PASS] Frontend build completed.

echo.
echo ----------------------------------------------------------------------
echo   Cockpit Server
echo ----------------------------------------------------------------------
echo.
echo [INFO] Starting Uvicorn on http://127.0.0.1:8080.
echo [INFO] NATS connectivity will be attempted at the configured NATS_URL, defaulting to nats://127.0.0.1:4222.
start "ROV Cockpit" http://127.0.0.1:8080
cd /d "%COCKPIT_DIR%"
"%PYTHON%" -m uvicorn rov_cockpit.app:app --host 127.0.0.1 --port 8080
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" echo [FAIL] Cockpit stopped with exit code %EXIT_CODE%. Check NATS availability and the preceding diagnostics.
if "%EXIT_CODE%"=="0" echo [PASS] Cockpit stopped normally.
if not "%EXIT_CODE%"=="0" pause
exit /b %EXIT_CODE%
