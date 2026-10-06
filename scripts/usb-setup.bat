@echo off

powershell.exe ^
    -NoProfile ^
    -ExecutionPolicy Bypass ^
    -File "%~dp0usb-setup.ps1"

if errorlevel 1 (
    echo.
    echo Setting up USB failed.
    pause
)