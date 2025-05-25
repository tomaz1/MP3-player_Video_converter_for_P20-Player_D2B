@echo off
setlocal enabledelayedexpansion

:: Privzete vrednosti
set "INPUT="
set "CROPADJUST=0"
set "SPLITMIN=0"
set "SOUNDGAIN=0"

:: Stabilno preverjanje za pomoc (Preveri prvih 9 argumentov - ne bi rabil toliko, ampak naj ostane za naprej.)
if "%~1"=="--help" goto showHelp
if "%~1"=="-help" goto showHelp
if "%~1"=="-?" goto showHelp
if "%~2"=="--help" goto showHelp
if "%~2"=="-help" goto showHelp
if "%~2"=="-?" goto showHelp
if "%~3"=="--help" goto showHelp
if "%~3"=="-help" goto showHelp
if "%~3"=="-?" goto showHelp
if "%~4"=="--help" goto showHelp
if "%~4"=="-help" goto showHelp
if "%~4"=="-?" goto showHelp
if "%~5"=="--help" goto showHelp
if "%~5"=="-help" goto showHelp
if "%~5"=="-?" goto showHelp
if "%~6"=="--help" goto showHelp
if "%~6"=="-help" goto showHelp
if "%~6"=="-?" goto showHelp
if "%~7"=="--help" goto showHelp
if "%~7"=="-help" goto showHelp
if "%~7"=="-?" goto showHelp
if "%~8"=="--help" goto showHelp
if "%~8"=="-help" goto showHelp
if "%~8"=="-?" goto showHelp
if "%~9"=="--help" goto showHelp
if "%~9"=="-help" goto showHelp
if "%~9"=="-?" goto showHelp

:: Parsiranje argumentov
:parseArgs
if "%~1"=="" goto runScript

if "%~1"=="-cropadjust" (
    set "CROPADJUST=%~2"
    shift
    shift
    goto parseArgs
)

if "%~1"=="-splitmin" (
    set "SPLITMIN=%~2"
    shift
    shift
    goto parseArgs
)

if "%~1"=="-soundgain" (
    set "SOUNDGAIN=%~2"
    shift
    shift
    goto parseArgs
)

if defined INPUT (
    echo [NAPAKA] Neznan parameter oz. nepravilna uporaba: %~1
    goto showHelp
) else (
    set "INPUT=%~1"
    shift
    goto parseArgs
)

:runScript
if not defined INPUT (
    echo [NAPAKA] Manjka vhodna datoteka.
    goto showHelp
)

:: Klici PowerShell skripto z vsemi argumenti
powershell -ExecutionPolicy Bypass -File "split-video.ps1" ^
    -InputFile "%INPUT%" ^
    -CropAdjustPercent %CROPADJUST% ^
    -SplitMinutes %SPLITMIN% ^
    -SoundGain %SOUNDGAIN%
goto :eof

:showHelp
powershell -ExecutionPolicy Bypass -File "split-video.ps1" -ShowHelp
exit /b 0
