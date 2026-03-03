@echo off
setlocal EnableExtensions

rem One-click start test stack:
rem 1) Backend: go run ./cmd/server (new terminal window)
rem 2) Frontend: flutter run (current terminal, args passthrough)

set "ROOT_DIR=%~dp0"
for %%I in ("%ROOT_DIR%") do set "ROOT_DIR=%%~fI"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "FLUTTER_DIR=%ROOT_DIR%\apps\flutter_client"

where go >nul 2>nul
if errorlevel 1 (
  echo [ERROR] go not found in PATH.
  exit /b 1
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter not found in PATH.
  exit /b 1
)

if not exist "%FLUTTER_DIR%" (
  echo [ERROR] Flutter client directory not found: "%FLUTTER_DIR%"
  exit /b 1
)

echo [INFO] Starting backend in a new window...
start "Self-Study Backend (TEST)" cmd /k "cd /d ""%ROOT_DIR%"" && set APP_ENV=test && go run ./cmd/server"
if errorlevel 1 (
  echo [ERROR] Failed to start backend window.
  exit /b 1
)

timeout /t 2 /nobreak >nul

echo [INFO] Starting frontend (flutter run)...
cd /d "%FLUTTER_DIR%" || exit /b 1
set "HAS_DEVICE_ARG=0"
for %%A in (%*) do (
  if /I "%%~A"=="-d" set "HAS_DEVICE_ARG=1"
  if /I "%%~A"=="--device-id" set "HAS_DEVICE_ARG=1"
  echo %%~A | findstr /B /I "--device-id=" >nul && set "HAS_DEVICE_ARG=1"
)

if "%HAS_DEVICE_ARG%"=="1" (
  flutter run %*
) else (
  flutter run -d windows %*
)
exit /b %errorlevel%
