@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_core.ps1" %*
exit /b %errorlevel%

