@echo off
chcp 65001 >nul
title 鸣潮 XXMI + ReShade + DLSS5 一键卸载
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
echo.
pause
