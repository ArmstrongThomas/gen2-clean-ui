[CmdletBinding(DefaultParameterSetName = "Local")]
param(
  [Parameter(ParameterSetName = "Local")]
  [string]$Source,

  [Parameter(Mandatory = $true, ParameterSetName = "Archive")]
  [string]$Archive,

  [Parameter(Mandatory = $true)]
  [string]$Tag,

  [Parameter(Mandatory = $true, ParameterSetName = "Archive")]
  [ValidatePattern("^[0-9a-fA-F]{40}$")]
  [string]$Commit
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$projectPrefix = $projectRoot.TrimEnd([char[]]"\/") + [IO.Path]::DirectorySeparatorChar
$targetRoot = [IO.Path]::GetFullPath(
  (Join-Path $projectRoot "mods\gen2_clean_ui\vendor\clean_ui_core"))
$lockPath = Join-Path $projectRoot "clean-ui-core.lock.json"
$stagingParent = [IO.Path]::GetFullPath((Join-Path $projectRoot ".core-sync-staging"))

if (-not $targetRoot.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to write a vendor directory outside the product repository"
}
if (-not $stagingParent.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to stage outside the product repository"
}

$stagingRoot = Join-Path $stagingParent ([Guid]::NewGuid().ToString("N"))
$sourceRuntime = $null
try {
  New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
  if ($PSCmdlet.ParameterSetName -eq "Archive") {
    $archivePath = [IO.Path]::GetFullPath($Archive)
    if (-not [IO.File]::Exists($archivePath)) { throw "Core archive not found: $archivePath" }
    $expanded = Join-Path $stagingRoot "archive"
    Expand-Archive -LiteralPath $archivePath -DestinationPath $expanded
    $candidates = @(Get-ChildItem -LiteralPath $expanded -Directory -Recurse |
      Where-Object { $_.FullName.Replace("/", "\").EndsWith("\src\clean_ui") })
    if ($candidates.Count -ne 1) {
      throw "Tagged core archive must contain exactly one src/clean_ui directory"
    }
    $sourceRuntime = $candidates[0].FullName
  }
  else {
    if ([string]::IsNullOrWhiteSpace($Source)) {
      $Source = Join-Path $projectRoot "..\clean-ui-core"
    }
    $coreRoot = [IO.Path]::GetFullPath($Source)
    $sourceRuntime = Join-Path $coreRoot "src\clean_ui"
    if (-not [IO.Directory]::Exists($sourceRuntime)) {
      throw "Local core runtime not found: $sourceRuntime"
    }
    $resolvedCommit = (& git -C $coreRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolvedCommit)) {
      throw "Local core source is not a readable Git checkout"
    }
    $resolvedCommit = $resolvedCommit.Trim()
    if ($Commit -and $Commit.ToLowerInvariant() -ne $resolvedCommit.ToLowerInvariant()) {
      throw "Requested commit does not match local checkout HEAD"
    }
    $Commit = $resolvedCommit
  }

  $stagedVendor = Join-Path $stagingRoot "vendor"
  New-Item -ItemType Directory -Force -Path $stagedVendor | Out-Null
  foreach ($file in (Get-ChildItem -LiteralPath $sourceRuntime -File -Recurse |
      Sort-Object FullName)) {
    if ($file.LinkType) { throw "Core snapshot may not contain links: $($file.FullName)" }
    $relative = $file.FullName.Substring($sourceRuntime.Length + 1)
    $destination = Join-Path $stagedVendor $relative
    $parent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
  }

  $files = @()
  foreach ($file in (Get-ChildItem -LiteralPath $stagedVendor -File -Recurse |
      Sort-Object FullName)) {
    $relative = $file.FullName.Substring($stagedVendor.Length + 1).Replace("\", "/")
    $files += [ordered]@{
      path = $relative
      sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      size = $file.Length
    }
  }
  if ($files.Count -eq 0) { throw "Core runtime snapshot is empty" }
  if (-not ($files | Where-Object { $_.path -eq "bootstrap.lua" })) {
    throw "Core runtime snapshot must contain bootstrap.lua"
  }

  if ([IO.Directory]::Exists($targetRoot)) {
    if ($targetRoot -ne [IO.Path]::GetFullPath(
        (Join-Path $projectRoot "mods\gen2_clean_ui\vendor\clean_ui_core"))) {
      throw "Refusing to replace an unexpected vendor target"
    }
    Remove-Item -LiteralPath $targetRoot -Force -Recurse
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetRoot) | Out-Null
  Move-Item -LiteralPath $stagedVendor -Destination $targetRoot

  $lock = [ordered]@{
    schema_version = 1
    status = "ready"
    core = [ordered]@{
      tag = $Tag
      commit = $Commit.ToLowerInvariant()
    }
    files = $files
  }
  $json = $lock | ConvertTo-Json -Depth 8
  $json = $json.Replace("`r`n", "`n")
  [IO.File]::WriteAllText($lockPath, $json + "`n",
    [Text.UTF8Encoding]::new($false))
}
finally {
  if ([IO.Directory]::Exists($stagingRoot)) {
    if (-not $stagingRoot.StartsWith($projectPrefix,
        [StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to clean an unexpected staging directory"
    }
    Remove-Item -LiteralPath $stagingRoot -Force -Recurse
  }
  if ([IO.Directory]::Exists($stagingParent) -and
      @(Get-ChildItem -LiteralPath $stagingParent -Force).Count -eq 0) {
    Remove-Item -LiteralPath $stagingParent -Force
  }
}

& (Join-Path $PSScriptRoot "verify_core_lock.ps1")
