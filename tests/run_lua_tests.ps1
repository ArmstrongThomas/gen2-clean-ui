[CmdletBinding()]
param([string]$Love = "C:\Program Files\LOVE\lovec.exe")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (-not (Test-Path -LiteralPath $Love -PathType Leaf)) {
  throw "LÖVE executable not found: $Love"
}

$previous = $env:GEN2_CLEAN_UI_ROOT
try {
  $env:GEN2_CLEAN_UI_ROOT = $root
  & $Love (Join-Path $PSScriptRoot "love_runner")
  if ($LASTEXITCODE -ne 0) {
    throw "Gen2 Lua tests failed with exit $LASTEXITCODE"
  }
} finally {
  if ($null -eq $previous) {
    Remove-Item Env:GEN2_CLEAN_UI_ROOT -ErrorAction SilentlyContinue
  } else {
    $env:GEN2_CLEAN_UI_ROOT = $previous
  }
}
