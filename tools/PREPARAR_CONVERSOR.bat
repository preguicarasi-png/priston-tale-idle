@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PREPARAR_CONVERSOR.ps1"
if errorlevel 1 (
  echo.
  echo ERRO ao preparar conversor.
  pause
)
