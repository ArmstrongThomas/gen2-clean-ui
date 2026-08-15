@echo off
setlocal

rem Sync the unpacked Gen2 Clean UI mod into the LOVE launcher directory.
set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" set "POWERSHELL_EXE=powershell.exe"
set "GEN2_CLEAN_UI_SOURCE=%~dp0mods\gen2_clean_ui"
set "GEN2_CLEAN_UI_TARGET=%APPDATA%\pokemon-love2d\mods\gen2_clean_ui"
set "GEN2_CLEAN_UI_PROJECT=%~dp0"
set "GEN2_CLEAN_UI_DEV_ROOT=%~dp0..\gen1recomp-grandmas-kitchen"
set "GEN2_CLEAN_UI_DEV_TARGET=%GEN2_CLEAN_UI_DEV_ROOT%\mods\gen2_clean_ui"

if not exist "%GEN2_CLEAN_UI_SOURCE%\manifest.json" (
  echo ERROR: Could not find the mod source at:
  echo        "%GEN2_CLEAN_UI_SOURCE%"
  echo Run this script from the Gen2 Clean UI repository.
  pause
  exit /b 1
)

echo Syncing Gen2 Clean UI...
echo   From: "%GEN2_CLEAN_UI_SOURCE%"
echo   To:   "%GEN2_CLEAN_UI_TARGET%"
if exist "%GEN2_CLEAN_UI_DEV_TARGET%\.." echo   Dev:  "%GEN2_CLEAN_UI_DEV_TARGET%"

"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%GEN2_CLEAN_UI_PROJECT%scripts\sync_mod.ps1" -Source "%GEN2_CLEAN_UI_SOURCE%" -LauncherTarget "%GEN2_CLEAN_UI_TARGET%" -LauncherModsRoot "%APPDATA%\pokemon-love2d\mods" -DevTarget "%GEN2_CLEAN_UI_DEV_TARGET%" -DevRoot "%GEN2_CLEAN_UI_DEV_ROOT%"

if errorlevel 1 (
  echo.
  echo ERROR: The mod could not be synced.
  pause
  exit /b 1
)

"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%GEN2_CLEAN_UI_PROJECT%build_release.ps1"

if errorlevel 1 (
  echo.
  echo ERROR: The mod was synced, but the launcher archive could not be built.
  pause
  exit /b 1
)

echo.
echo Gen2 Clean UI synced successfully.
echo A launcher-ready ZIP was created in the project root.
echo Restart the game to reload the mod.
pause
exit /b 0
