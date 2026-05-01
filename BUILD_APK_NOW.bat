@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0BUILD_APK_NOW.ps1" -Mode debug
exit /b %ERRORLEVEL%
