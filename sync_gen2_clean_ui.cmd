@echo off
setlocal

rem Sync the unpacked Gen2 Clean UI mod into the LOVE launcher directory.
set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" set "POWERSHELL_EXE=powershell.exe"
set "GEN2_CLEAN_UI_SOURCE=%~dp0mods\gen2_clean_ui"
set "GEN2_CLEAN_UI_TARGET=%APPDATA%\pokemon-love2d\mods\gen2_clean_ui"
set "GEN2_CLEAN_UI_PROJECT=%~dp0"
set "GEN2_CLEAN_UI_CORE_SOURCE=%GEN2_CLEAN_UI_PROJECT%..\clean-ui-core"
set "GEN2_CLEAN_UI_CORE_TAG=0.1.0-alpha.13-local"

if not exist "%GEN2_CLEAN_UI_SOURCE%\manifest.json" (
  echo ERROR: Could not find the mod source at:
  echo        "%GEN2_CLEAN_UI_SOURCE%"
  echo Run this script from the Gen2 Clean UI repository.
  pause
  exit /b 1
)

if not exist "%GEN2_CLEAN_UI_CORE_SOURCE%\src\clean_ui\bootstrap.lua" (
  echo ERROR: Could not find the shared clean-ui-core checkout at:
  echo        "%GEN2_CLEAN_UI_CORE_SOURCE%"
  echo Refresh or clone the sibling clean-ui-core repository before syncing.
  pause
  exit /b 1
)

echo Refreshing shared Clean UI core...
echo   Core: "%GEN2_CLEAN_UI_CORE_SOURCE%"

"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%GEN2_CLEAN_UI_PROJECT%scripts\sync_core.ps1" -Source "%GEN2_CLEAN_UI_CORE_SOURCE%" -Tag "%GEN2_CLEAN_UI_CORE_TAG%"

if errorlevel 1 (
  echo.
  echo ERROR: The shared Clean UI core could not be refreshed.
  pause
  exit /b 1
)

echo Syncing Gen2 Clean UI...
echo   From: "%GEN2_CLEAN_UI_SOURCE%"
echo   To:   "%GEN2_CLEAN_UI_TARGET%"

"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%GEN2_CLEAN_UI_PROJECT%scripts\sync_mod.ps1" -Source "%GEN2_CLEAN_UI_SOURCE%" -LauncherTarget "%GEN2_CLEAN_UI_TARGET%" -LauncherModsRoot "%APPDATA%\pokemon-love2d\mods"

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
echo The shared Clean UI core was refreshed before the mod sync.
echo A launcher-ready ZIP was created in the project root.
echo Restart the game to reload the mod.
pause
exit /b 0
