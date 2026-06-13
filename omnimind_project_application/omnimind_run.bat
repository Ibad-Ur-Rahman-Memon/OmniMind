@echo off
setlocal

REM OmniMind: start backend + flutter app with one command

set "PROJECT_DIR=c:/Users/Khalid-pc/Downloads/OmniMind_Complete_Project/omnimind_project"
set "FLUTTER_DIR=%PROJECT_DIR%/flutter_app/omnimind"
set "BACKEND_DIR=%PROJECT_DIR%/backend"

REM Optional: customize ports/environments here if needed

echo Starting backend (python)...
start "omnimind-backend" cmd /c "cd /d %BACKEND_DIR% && python -u api_server.py"

REM Give backend a moment
timeout /t 3 >nul

echo Starting Flutter app (doctor_dashboard)...
start "omnimind-flutter" cmd /c "cd /d %FLUTTER_DIR% && flutter run"

echo.
echo Done. Backend + Flutter are starting in new windows.
echo If you want only one instance, close the previous windows first.

endlocal

