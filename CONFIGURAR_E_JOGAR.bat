@echo off
setlocal
title Priston Tale Idle 3D - Configuracao
echo ==========================================
echo       PRISTON TALE IDLE 3D - SETUP
echo ==========================================
echo.
echo ETAPA 1 - Preparando conversor...
call "%~dp0tools\PREPARAR_CONVERSOR.bat"
if errorlevel 1 goto erro
echo.
echo ETAPA 2 - Importando seus arquivos do Priston...
call "%~dp0tools\IMPORTAR_PRISTON.bat"
if errorlevel 1 goto erro
echo.
echo ETAPA 3 - Abrindo o projeto no Godot...
start "" "%~dp0project.godot"
exit /b 0

:erro
echo.
echo Ocorreu um erro. Veja as mensagens acima.
pause
exit /b 1
