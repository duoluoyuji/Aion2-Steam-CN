@echo off
chcp 65001 >nul 2>&1
setlocal
cd /d "%~dp0"
title AION 2 一键还原官方日文

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Aion2CNTool.ps1" -Restore
if %errorlevel% neq 0 (
    echo.
    echo 执行过程出现错误，代码: %errorlevel%
)
pause
