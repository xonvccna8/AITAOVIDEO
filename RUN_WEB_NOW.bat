@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0RUN_WEB_NOW.ps1" -OpenBrowser
exit /b %ERRORLEVEL%
