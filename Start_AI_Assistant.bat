@echo off
setlocal
title Scrap Mechanic AI Assistant Launcher

cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Launcher encountered an error.
    pause
)
