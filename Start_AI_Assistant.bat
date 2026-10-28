@echo off
setlocal enabledelayedexpansion
title Scrap Mechanic AI Assistant Launcher

echo ======================================================
echo       Scrap Mechanic AI Assistant - Quick Launch
echo ======================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "BRIDGE_SCRIPT=%SCRIPT_DIR%bridge\openrouter_bridge.js"
set "NODE_EXE="

:: 1. Check node in PATH
where node >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set "NODE_EXE=node"
)

:: 2. Check cached node runtime if PATH node not found
if "%NODE_EXE%"=="" (
    if exist "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" (
        set "NODE_EXE=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
    ) else if exist "C:\Program Files\nodejs\node.exe" (
        set "NODE_EXE=C:\Program Files\nodejs\node.exe"
    )
)

if "%NODE_EXE%"=="" (
    echo [ERROR] Node.js was not found!
    echo Please install Node.js from https://nodejs.org or put node in PATH.
    pause
    exit /b 1
)

echo [OK] Using Node.js: %NODE_EXE%

:: 3. Check if bridge is already running
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*openrouter_bridge.js*' } | Select-Object -First 1 ProcessId" > "%TEMP%\sm_bridge_pid.txt" 2>nul
set /p BRIDGE_PID=<"%TEMP%\sm_bridge_pid.txt"
del "%TEMP%\sm_bridge_pid.txt" >nul 2>&1

if not "%BRIDGE_PID%"=="" (
    echo [OK] AI Bridge is already running (PID: %BRIDGE_PID%).
) else (
    echo [..] Starting AI Bridge in background...
    powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath '%NODE_EXE%' -ArgumentList '\"%BRIDGE_SCRIPT%\"' -WindowStyle Hidden"
    timeout /t 2 /nobreak >nul
    echo [OK] AI Bridge started successfully!
)

:: 4. Launch Scrap Mechanic
echo.
echo [..] Launching Scrap Mechanic via Steam...
start steam://run/387990

echo.
echo ======================================================
echo   AI Assistant is active!
echo   - In game, type /aiask to chat with MooMoo
echo   - Type /aisettings or press E on MooMoo for Settings
echo ======================================================
timeout /t 5
