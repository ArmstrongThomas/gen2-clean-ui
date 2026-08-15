[CmdletBinding()]
param(
  [switch]$AllowPending
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$lockPath = Join-Path $projectRoot "clean-ui-core.lock.json"
$vendorRoot = Join-Path $projectRoot "mods\gen2_clean_ui\vendor\clean_ui_core"

function Get-Sha256Hex([string]$Path) {
  $sha = [Security.Cryptography.SHA256]::Create()
  $stream = $null
  try {
    $stream = [IO.File]::OpenRead($Path)
    return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace("-", "")
  }
  finally {
    if ($null -ne $stream) { $stream.Dispose() }
    $sha.Dispose()
  }
}

if (-not [IO.File]::Exists($lockPath)) {
  throw "Missing core lock: $lockPath"
}
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
if ($lock.schema_version -ne 1) { throw "Unsupported core lock schema" }

if ($lock.status -eq "pending") {
  if (-not $AllowPending) {
    throw "clean-ui-core is pending; sync a tagged core before building a release"
  }
  if ([IO.Directory]::Exists($vendorRoot)) {
    throw "Pending lock must not have a vendored core directory"
  }
  Write-Host "Core lock is intentionally pending."
  exit 0
}

if ($lock.status -ne "ready") { throw "Unknown core lock status: $($lock.status)" }
if ([string]::IsNullOrWhiteSpace([string]$lock.core.tag)) {
  throw "Ready core lock is missing a tag"
}
if ([string]::IsNullOrWhiteSpace([string]$lock.core.commit)) {
  throw "Ready core lock is missing a commit"
}
if (-not [IO.Directory]::Exists($vendorRoot)) {
  throw "Vendored core directory is missing: $vendorRoot"
}

$actual = @{}
foreach ($file in (Get-ChildItem -LiteralPath $vendorRoot -File -Recurse |
    Sort-Object FullName)) {
  $relative = $file.FullName.Substring($vendorRoot.Length + 1).Replace("\", "/")
  $actual[$relative] = @{
    sha256 = (Get-Sha256Hex $file.FullName).ToLowerInvariant()
    size = $file.Length
  }
}

$expected = @($lock.files)
if ($expected.Count -ne $actual.Count) {
  throw "Core lock file count mismatch: expected $($expected.Count), found $($actual.Count)"
}
foreach ($entry in $expected) {
  $path = [string]$entry.path
  if ([string]::IsNullOrWhiteSpace($path) -or $path.Contains("\") -or
      $path.StartsWith("/") -or $path.Contains("../")) {
    throw "Unsafe core lock path: $path"
  }
  if (-not $actual.ContainsKey($path)) { throw "Missing vendored core file: $path" }
  if ($actual[$path].sha256 -ne ([string]$entry.sha256).ToLowerInvariant()) {
    throw "Core hash mismatch: $path"
  }
  if ($actual[$path].size -ne [long]$entry.size) {
    throw "Core size mismatch: $path"
  }
}

Write-Host "Verified clean-ui-core $($lock.core.tag) at $($lock.core.commit)."
