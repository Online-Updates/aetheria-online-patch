@echo off
setlocal
cd /d "%~dp0"
title Aetheria Manual Patch Builder

set VERSION=%~1
if "%VERSION%"=="" set VERSION=1.0.0

echo ==========================================
echo Aetheria Manual Patch Builder
echo Version: %VERSION%
echo Source: %~dp0files\
echo Deletes: %~dp0delete_folder\
echo ==========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0GenerateManualPatchManifest.ps1" -Version "%VERSION%"

echo.
echo Manual patch manifest finished. Review the summary above.
pause
