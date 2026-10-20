@echo off
setlocal
set "GODOT_EXE=%~dp0..\work\sacrifice-godot\Godot.exe"
if defined GODOT_BIN set "GODOT_EXE=%GODOT_BIN%"
if not exist "%GODOT_EXE%" (
  echo Godot was not found. Import project.godot using Godot 4.3 or newer.
  echo Or set GODOT_BIN to the full path of your Godot executable.
  pause
  exit /b 1
)
if not exist "%~dp0local-data" mkdir "%~dp0local-data"
if not exist "%~dp0.godot\imported\icon.svg-*.ctex" (
  "%GODOT_EXE%" --headless --editor --import --quit --path "%~dp0." --log-file "%~dp0local-data\import.log"
)
start "Sacrifice" "%GODOT_EXE%" --path "%~dp0." --log-file "%~dp0local-data\game.log" %*
