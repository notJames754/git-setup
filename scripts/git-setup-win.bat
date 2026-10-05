@echo off

powershell.exe ^
    -NoProfile ^
    -ExecutionPolicy Bypass ^
    -File "%~dp0git-setup-win.ps1"

if errorlevel 1 (
    echo.
    echo Git USB environment failed.
    pause
)