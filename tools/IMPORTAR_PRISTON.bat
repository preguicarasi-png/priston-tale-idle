@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0IMPORTAR_PRISTON.ps1"
if errorlevel 1 pause
