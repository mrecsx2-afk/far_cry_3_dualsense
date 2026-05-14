@echo off
title FC3 DualSense Adaptive Triggers

echo ================================================
echo  FC3 DualSense Triggers - Launcher
echo ================================================
echo.
echo Starting portable AutoHotkey...

start "" "%~dp0ahk\AutoHotkey64.exe" "%~dp0FC3_DualSense_Triggers.ahk"

echo.
echo Successfully started! Look for the green H icon in the system tray.
echo You can close this window now.
timeout /t 5 >nul
