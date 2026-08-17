[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$LauncherTarget,
  [Parameter(Mandatory = $true)][string]$LauncherModsRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$source = [IO.Path]::GetFullPath($Source)
$launcherTarget = [IO.Path]::GetFullPath($LauncherTarget)
$launcherModsRoot = [IO.Path]::GetFullPath($LauncherModsRoot)

if (-not [IO.Directory]::Exists($source)) { throw "Source directory is missing: $source" }
if (-not [IO.File]::Exists((Join-Path $source "manifest.json"))) {
  throw "Source manifest is missing: $(Join-Path $source 'manifest.json')"
}
if ([IO.Path]::GetDirectoryName($launcherTarget) -ne $launcherModsRoot) {
  throw "Refusing unexpected launcher mod target: $launcherTarget"
}

function IsReparsePoint([IO.FileSystemInfo]$Item) {
  return ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function CopyExactTree([string]$Destination) {
  if (Test-Path -LiteralPath $Destination) {
    $existing = Get-Item -LiteralPath $Destination -Force
    if (IsReparsePoint $existing) {
      throw "Refusing to overwrite reparse-point target: $Destination"
    }
    Get-ChildItem -LiteralPath $Destination -Force |
      Remove-Item -Recurse -Force
  } else {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  }
  Get-ChildItem -LiteralPath $source -Force |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force }
}

CopyExactTree $launcherTarget
Write-Host "Synced launcher target: $launcherTarget"
