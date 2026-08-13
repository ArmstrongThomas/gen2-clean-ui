[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$modRoot = Join-Path $root "mods\gen2_clean_ui"
$manifest = Get-Content -LiteralPath (Join-Path $modRoot "manifest.json") -Raw |
  ConvertFrom-Json

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

Assert-True ($manifest.id -eq "gen2_clean_ui") "manifest id"
Assert-True ($manifest.api -eq 2) "manifest api"
Assert-True ($manifest.profile -eq "overhaul") "manifest profile"
Assert-True ($manifest.priority -eq 100) "manifest priority"
Assert-True ($manifest.affects_link -eq $false) "manifest affects_link"
Assert-True (@($manifest.games).Count -eq 1 -and $manifest.games[0] -eq "gen2") `
  "manifest must be Gen2-only"
Assert-True (@($manifest.conflicts) -contains "gen1_modern_ui") `
  "legacy conflict"
Assert-True ($manifest.options_schema -eq "options.lua") "options schema path"
Assert-True ($manifest.github -eq "ArmstrongThomas/gen2-clean-ui") `
  "updater repository"

$mainLines = @(Get-Content -LiteralPath (Join-Path $modRoot "main.lua"))
Assert-True ($mainLines.Count -le 80) "main.lua exceeds 80 lines"
Assert-True (-not (($mainLines -join "`n") -match "mod\.hooks")) `
  "main.lua must remain bootstrap-only"

$requiredModules = @(
  "src\bootstrap.lua",
  "src\product.lua",
  "src\contracts\catalog.lua",
  "src\contracts\families\foundation.lua",
  "src\contracts\families\gameplay.lua",
  "src\contracts\families\services.lua",
  "src\contracts\families\native.lua",
  "src\provider\init.lua",
  "src\provider\identity.lua",
  "src\provider\stack_policy.lua",
  "src\provider\live_stack.lua",
  "src\provider\source_input.lua",
  "src\adapters\data.lua",
  "src\adapters\actions.lua",
  "src\adapters\main_menu.lua",
  "src\adapters\start_menu.lua",
  "src\adapters\options_menu.lua",
  "src\adapters\shared_textbox.lua",
  "src\adapters\shared_choicebox.lua",
  "src\presenters\foundation_models.lua",
  "src\presenters\foundation_presenters.lua",
  "src\presenters\shared_models.lua",
  "src\presenters\shared_presenters.lua"
)
foreach ($relative in $requiredModules) {
  Assert-True ([IO.File]::Exists((Join-Path $modRoot $relative))) `
    "missing module: $relative"
}

$catalogPath = Join-Path $modRoot "src\contracts\catalog.lua"
$catalogText = Get-Content -LiteralPath $catalogPath -Raw
$matches = [regex]::Matches($catalogText,
  '(?m)^    "(Gen2[^"\r\n]+)",\r?$')
$ids = @($matches | ForEach-Object { $_.Groups[1].Value })
Assert-True ($ids.Count -eq 51) "catalog must enumerate exactly 51 official IDs"
Assert-True (@($ids | Select-Object -Unique).Count -eq 51) "catalog IDs must be unique"

$optionsText = Get-Content -LiteralPath (Join-Path $modRoot "options.lua") -Raw
$optionKeys = [regex]::Matches($optionsText,
  '(?m)^    key = "([^"]+)",\r?$')
Assert-True ($optionKeys.Count -eq 12) "clean settings schema must have 12 rows"

$lock = Get-Content -LiteralPath (Join-Path $root "clean-ui-core.lock.json") -Raw |
  ConvertFrom-Json
Assert-True ($lock.status -eq "ready") "core lock must be ready"
Assert-True ([IO.Directory]::Exists(
  (Join-Path $modRoot "vendor\clean_ui_core"))) `
  "ready core payload must be vendored"
& (Join-Path $root "scripts\verify_core_lock.ps1")
& (Join-Path $root "scripts\verify_sandbox.ps1") -RepositoryRoot $root

foreach ($script in @("build_release.ps1", "scripts\sync_core.ps1",
    "scripts\verify_core_lock.ps1")) {
  $scriptText = Get-Content -LiteralPath (Join-Path $root $script) -Raw
  [void][scriptblock]::Create($scriptText)
}

$archives = @(Get-ChildItem -LiteralPath $root -File -Filter "gen2_clean_ui-*.zip")
Assert-True ($archives.Count -eq 0) "development tree must not contain a stale release ZIP"

& (Join-Path $PSScriptRoot "run_lua_tests.ps1")

Write-Host "Gen2 Clean UI scaffold verification passed."
