@echo off
set "PATH=%SystemRoot%\system32;%SystemRoot%;%SystemRoot%\System32\Wbem;%SystemRoot%\System32\WindowsPowerShell\v1.0\;%PATH%"
chcp 65001 >nul 2>&1
title AION 2 一键还原官方英文

if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "%~dp0Aion2CNTool.ps1" -Restore
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0Aion2CNTool.ps1" -Restore
)

pause
