$ErrorActionPreference = "Continue"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "      Scrap Mechanic AI Assistant - Quick Launch      " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$bridgeScript = Join-Path $scriptDir "bridge\openrouter_bridge.js"

# 1. Resolve Node.js executable
$nodeExe = $null
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeExe = (Get-Command node).Source
} elseif (Test-Path "$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe") {
    $nodeExe = "$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
} elseif (Test-Path "C:\Program Files\nodejs\node.exe") {
    $nodeExe = "C:\Program Files\nodejs\node.exe"
}

if (-not $nodeExe) {
    Write-Host "[ERROR] Node.js executable was not found!" -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit 1
}

Write-Host "[OK] Node runtime: $nodeExe" -ForegroundColor Green

# 2. Check if bridge is running
$bridgeProc = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { 
    $_.CommandLine -and $_.CommandLine.Contains("openrouter_bridge.js") 
} | Select-Object -First 1

if ($bridgeProc) {
    Write-Host "[OK] AI Bridge is already running (PID: $($bridgeProc.ProcessId))." -ForegroundColor Green
} else {
    Write-Host "[..] Starting AI Bridge in background..." -ForegroundColor Yellow
    Start-Process -FilePath $nodeExe -ArgumentList "`"$bridgeScript`"" -WindowStyle Hidden
    Start-Sleep -Seconds 2
    Write-Host "[OK] AI Bridge started successfully!" -ForegroundColor Green
}

# 3. Launch Scrap Mechanic
Write-Host ""
Write-Host "[..] Launching Scrap Mechanic via Steam..." -ForegroundColor Yellow

$steamExe = "C:\Program Files (x86)\Steam\steam.exe"
if (Test-Path $steamExe) {
    Start-Process -FilePath $steamExe -ArgumentList "-applaunch 387990"
} else {
    Start-Process "steam://run/387990"
}

Write-Host "[OK] Scrap Mechanic launched!" -ForegroundColor Green
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  AI Assistant is active!" -ForegroundColor Green
Write-Host "  - In game, type /aiask to chat with MooMoo"
Write-Host "  - Type /aisettings or press E on MooMoo for Settings"
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Start-Sleep -Seconds 3
