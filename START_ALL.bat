@echo off
title Sanlam Chronic Care - Launcher
color 0A
echo.
echo  =====================================================
echo   SANLAM CHRONIC CARE - Starting All Services...
echo  =====================================================
echo.

cd /d "%~dp0"

echo [1/3] Starting Backend (Node.js)...
start "Backend - Node.js" cmd /k "cd /d %~dp0backend && npm run dev"
timeout /t 3 /nobreak >nul

echo [2/3] Starting Portal (Vite)...
start "Portal - Vite" cmd /k "cd /d %~dp0portal && npm run dev"
timeout /t 3 /nobreak >nul

echo [3/3] Starting Flutter App in Chrome...
start "Flutter App - Chrome" cmd /k "cd /d %~dp0app && flutter run -d chrome"

echo.
echo  =====================================================
echo   All services launched in separate windows!
echo   - Backend  : http://localhost:3000
echo   - Portal   : http://localhost:5173
echo   - Flutter  : Opens in Chrome automatically
echo  =====================================================
echo.
pause
