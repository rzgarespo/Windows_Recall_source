@echo off
SET "taskName=RunScriptAtStartup"
SET "taskPath=C:\ProgramData\sshd\run.bat"

REM Check if the scheduled task already exists
schtasks /query /TN "%taskName%" >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo Task "%taskName%" already exists. Exiting.
    exit /B 1
)

REM Create a scheduled task to run run.bat at startup
schtasks /create /tn "%taskName%" /tr "%taskPath%" /sc onlogon /rl highest /f >nul 2>&1

IF %ERRORLEVEL% EQU 0 (
    echo Task "%taskName%" created successfully.
) ELSE (
    echo Failed to create task "%taskName%".
)
