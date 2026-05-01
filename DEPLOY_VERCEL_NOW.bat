@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0DEPLOY_VERCEL_NOW.ps1"
exit /b %ERRORLEVEL%
