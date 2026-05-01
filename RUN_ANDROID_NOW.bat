@echo off
setlocal
PowerShell -ExecutionPolicy Bypass -File "%~dp0RUN_APP_NOW.ps1"
exit /b %ERRORLEVEL%
