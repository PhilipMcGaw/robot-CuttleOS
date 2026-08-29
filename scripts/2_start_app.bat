@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
set "PYTHON=%PROJECT_ROOT%\runtime\python.exe"
set "COCKPIT_DIR=%PROJECT_ROOT%\cockpit\src"
echo [INFO] ROV Cockpit launcher
echo [INFO] Project version: unversioned; see MASTER_CONTEXT.md
echo [INFO] Project directory: %PROJECT_ROOT%
echo [INFO] Interpreter/runtime: %PYTHON%
echo [INFO] Operating mode: local Windows Cockpit with server-side NATS Core connection
echo [INFO] Important paths: package=%COCKPIT_DIR%\rov_cockpit, configuration=%PROJECT_ROOT%\configs
echo [INFO] Optional components: NATS Server must be available for live telemetry; Raspberry Pi hardware is not required for UI development
if "%SCRIPT_DIR:~0,2%"=="\\" (
 echo [FAIL] Direct UNC execution is unsupported: %SCRIPT_DIR%
 echo [FAIL] Corrective action: copy the project locally or map the share to a drive letter.
 exit /b 1
)
if not exist "%PYTHON%" (
 echo [FAIL] Project interpreter not found: %PYTHON%
 echo [FAIL] Why it matters: the application must use the portable project runtime.
 echo [FAIL] Corrective action: run scripts\1_install_dependencies.bat.
 exit /b 1
)
if not exist "%COCKPIT_DIR%\rov_cockpit\app.py" (
 echo [FAIL] Cockpit entry point not found: %COCKPIT_DIR%\rov_cockpit\app.py
 echo [FAIL] Corrective action: restore the Cockpit source tree.
 exit /b 1
)
call "%SCRIPT_DIR%build_frontend.bat"
if errorlevel 1 exit /b 1
echo [INFO] Starting Uvicorn on http://127.0.0.1:8080; no system settings will be changed.
echo [INFO] NATS connectivity will be attempted at the configured NATS_URL, defaulting to nats://127.0.0.1:4222.
start "ROV Cockpit" http://127.0.0.1:8080
cd /d "%COCKPIT_DIR%"
"%PYTHON%" -m uvicorn rov_cockpit.app:app --host 127.0.0.1 --port 8080
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" echo [FAIL] Cockpit stopped with exit code %EXIT_CODE%. Check NATS availability and the preceding diagnostics.
if "%EXIT_CODE%"=="0" echo [PASS] Cockpit stopped normally.
exit /b %EXIT_CODE%
