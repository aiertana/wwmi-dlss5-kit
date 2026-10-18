@echo off
chcp 65001 >nul
title 鸣潮 XXMI + ReShade + DLSS5 一键部署
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
