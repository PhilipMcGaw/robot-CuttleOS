@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
set "PYTHON=%PROJECT_ROOT%\runtime\python.exe"
set "REQUIREMENTS=%PROJECT_ROOT%\cockpit\requirements.txt"
set "BOOTSTRAP=%SCRIPT_DIR%bootstrap_winpython.ps1"

echo.
echo ======================================================================
echo   CuttleOS - Install Dependencies
echo ======================================================================
echo.

echo ----------------------------------------------------------------------
echo   System Checks
echo ----------------------------------------------------------------------
echo.
echo [INFO] Project directory: %PROJECT_ROOT%
echo [INFO] Runtime: project-local WinPython at %PYTHON%
echo [INFO] Operating mode: portable Windows installation; no administrator rights requested
echo.

if "%SCRIPT_DIR:~0,2%"=="\\" (
 echo [FAIL] Direct UNC execution is unsupported: %SCRIPT_DIR%
 echo [FAIL] Corrective action: copy the project locally or map the share to a drive letter.
 pause
 exit /b 1
)
if not exist "%REQUIREMENTS%" (
 echo [FAIL] Requirements file not found: %REQUIREMENTS%
 echo [FAIL] Corrective action: restore cockpit\requirements.txt from the repository.
 pause
 exit /b 1
)

if not exist "%PYTHON%" (
 echo.
 echo ----------------------------------------------------------------------
 echo   Portable Python
echo ----------------------------------------------------------------------
echo.
 echo [INFO] Portable Python is not installed; invoking the verified WinPython bootstrap.
 powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%BOOTSTRAP%" -ProjectRoot "%PROJECT_ROOT%"
 if errorlevel 1 (
  echo [FAIL] WinPython bootstrap failed: %BOOTSTRAP%
  echo [FAIL] Corrective action: review the bootstrap diagnostics and network access, then rerun.
  pause
  exit /b 1
 )
) else echo [PASS] Project-local Python detected: %PYTHON%

if not exist "%PYTHON%" (
 echo [FAIL] Python executable is still missing: %PYTHON%
 echo [FAIL] Corrective action: rerun after resolving the bootstrap failure.
 pause
 exit /b 1
)

echo.
echo ----------------------------------------------------------------------
echo   Python Environment
echo ----------------------------------------------------------------------
echo.
echo [INFO] Checking the interpreter architecture and version.
"%PYTHON%" -c "import platform,sys; print('Python:',sys.version.split()[0]); print('Architecture:',platform.architecture()[0]); print('Executable:',sys.executable)"
if errorlevel 1 (
 echo [FAIL] Interpreter validation failed.
 pause
 exit /b 1
)
echo [PASS] Project-local Python runtime validated.

echo.
echo ----------------------------------------------------------------------
echo   Package Tooling
echo ----------------------------------------------------------------------
echo.
echo [INFO] Installing package tooling into the project runtime; no PATH or registry changes will be made.
"%PYTHON%" -m ensurepip --upgrade || (echo [FAIL] Could not install package tooling. & pause & exit /b 1)
"%PYTHON%" -m pip install --upgrade pip || (echo [FAIL] Could not upgrade pip. & pause & exit /b 1)
echo [PASS] Package tooling is ready.

echo.
echo ----------------------------------------------------------------------
echo   Python Dependencies
echo ----------------------------------------------------------------------
echo.
echo [INFO] Installing requirements from: %REQUIREMENTS%
"%PYTHON%" -m pip install --no-warn-script-location -r "%REQUIREMENTS%" || (echo [FAIL] Requirements installation failed. & pause & exit /b 1)
echo [PASS] Cockpit dependencies are installed in the project runtime.

echo.
echo ======================================================================
echo   Installation Complete
echo ======================================================================
echo.
echo [PASS] Runtime: installed
echo [PASS] Requirements: installed
echo [PASS] PATH: unchanged
echo [PASS] Registry: unchanged
echo [PASS] Administrator rights: not requested
