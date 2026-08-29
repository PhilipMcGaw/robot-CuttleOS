@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "PYTHON=%PROJECT_ROOT%\runtime\python.exe"
if "%SCRIPT_DIR:~0,2%"=="\\" (
 echo This installer cannot run from a UNC network path. Copy the repository locally or map a drive letter.
 pause
 exit /b 1
)
if not exist "%PYTHON%" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%bootstrap_winpython.ps1" -ProjectRoot "%PROJECT_ROOT%"
if not exist "%PYTHON%" exit /b 1
"%PYTHON%" -m ensurepip --upgrade || exit /b %errorlevel%
"%PYTHON%" -m pip install --upgrade pip || exit /b %errorlevel%
"%PYTHON%" -m pip install --no-warn-script-location -r "%PROJECT_ROOT%\requirements.txt" || exit /b %errorlevel%
echo Control dependencies installed. Run scripts\2_start_app.bat next.
