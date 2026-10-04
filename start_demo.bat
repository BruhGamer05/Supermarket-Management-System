@echo off
title Supermarket DB - Demo Server

:: Request Admin Privileges automatically
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges to start MySQL...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Ensure we are in the project folder after Administrator elevation
cd /d "%~dp0"

echo ===================================================
echo   Supermarket Management System - Demo Starter
echo ===================================================
echo.

echo [1/4] Checking Database Status...
echo Attempting to start local MySQL service...
net start MySQL80 2>nul
if %errorlevel% neq 0 (
    echo MySQL80 is already running or failed to start.
) else (
    echo MySQL started successfully!
)

echo.
echo [2/4] Opening Web Browser (Frontend and Swagger API)...
:: Open the default browser to the app and docs
start "" "http://localhost:8000/app/index.html"
start "" "http://localhost:8000/docs"

echo.
echo [3/4] Opening MySQL Live Shell...
:: Open a separate terminal window and automatically log into MySQL
start "MySQL Live Shell" cmd /k "mysql -u root -prootpass supermarket_db"

echo.
echo [4/4] Starting FastAPI Backend Server...
echo.
echo ===================================================
echo   SERVER IS RUNNING! DO NOT CLOSE THIS WINDOW.
echo   (Press Ctrl+C to stop the server when done)
echo ===================================================
echo.

:: Start the python server using the local venv
.\venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000

pause
