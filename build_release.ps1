[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

$projectRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$sourceRoot = Join-Path $projectRoot "mods\gen2_clean_ui"
$manifestPath = Join-Path $sourceRoot "manifest.json"
$lockPath = Join-Path $projectRoot "clean-ui-core.lock.json"

& (Join-Path $projectRoot "scripts\verify_core_lock.ps1")
& (Join-Path $projectRoot "scripts\verify_sandbox.ps1") -RepositoryRoot $projectRoot
if (-not [IO.File]::Exists($manifestPath)) { throw "Missing manifest: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.id -ne "gen2_clean_ui") { throw "Unexpected manifest id: $($manifest.id)" }
if ([string]::IsNullOrWhiteSpace([string]$manifest.version)) {
  throw "Manifest version is missing"
}
if ($manifest.api -ne 2 -or $manifest.profile -ne "overhaul" -or
    $manifest.priority -ne 100 -or $manifest.affects_link -ne $false) {
  throw "Release manifest does not satisfy the Clean UI product contract"
}
if (@($manifest.games).Count -ne 1 -or $manifest.games[0] -ne "gen2") {
  throw "Release manifest must target only gen2"
}
if (@($manifest.conflicts) -notcontains "gen1_modern_ui") {
  throw "Release must conflict with gen1_modern_ui"
}
if ($manifest.game_version -eq "0.0.0-dev") {
  throw "Development-only game_version must be replaced before a release build"
}

$forbidden = '(?x)(\bio\.|os\.(getenv|execute|remove|rename|exit|tmpname)|' +
  'love\.(filesystem|thread|system|event)|\bdebug\b|\bpackage\b|' +
  '(?<![A-Za-z0-9_])dofile(?![A-Za-z0-9_])\s*\(|' +
  '(?<![A-Za-z0-9_])loadfile(?![A-Za-z0-9_])\s*\(|' +
  '(?<![A-Za-z0-9_])getfenv(?![A-Za-z0-9_])\s*\(|' +
  '(?<![A-Za-z0-9_])setfenv(?![A-Za-z0-9_])\s*\(|' +
  'require\s*\(\s*["''](?:io|os|debug|package|ffi|love\.))'
$sandboxHits = @()
foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Filter *.lua -File -Recurse) {
  $lineNumber = 0
  foreach ($line in Get-Content -LiteralPath $file.FullName) {
    $lineNumber++
    if ([regex]::IsMatch($line, $forbidden)) {
      $sandboxHits += "$($file.FullName):${lineNumber}:$line"
    }
  }
}
if ($sandboxHits.Count -gt 0) {
  throw "Sandbox-incompatible shipped Lua:`n$($sandboxHits -join "`n")"
}

$archiveName = "$($manifest.id)-$($manifest.version).zip"
$archivePath = [IO.Path]::GetFullPath((Join-Path $projectRoot $archiveName))
$projectPrefix = $projectRoot.TrimEnd([char[]]"\/") + [IO.Path]::DirectorySeparatorChar
if (-not $archivePath.StartsWith($projectPrefix,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to create an archive outside the product repository"
}

foreach ($old in (Get-ChildItem -LiteralPath $projectRoot -File |
    Where-Object { $_.Name -match '^gen2_clean_ui-[0-9].*\.zip$' })) {
  Remove-Item -LiteralPath $old.FullName -Force
}

$entries = New-Object System.Collections.Generic.List[object]
$seen = @{}
function Add-ArchiveFile([string]$Source, [string]$Relative) {
  if ($seen.ContainsKey($Relative)) { return }
  $entries.Add([pscustomobject]@{ Source = $Source; Relative = $Relative })
  $seen[$Relative] = $true
}

Add-ArchiveFile $manifestPath "gen2_clean_ui/manifest.json"
foreach ($relative in @("main.lua", "options.lua", "README.md",
    "THIRD_PARTY_NOTICES.md")) {
  $path = Join-Path $sourceRoot $relative
  if ([IO.File]::Exists($path)) {
    Add-ArchiveFile $path ("gen2_clean_ui/" + $relative.Replace("\", "/"))
  }
}
Add-ArchiveFile $lockPath "gen2_clean_ui/clean-ui-core.lock.json"

foreach ($file in (Get-ChildItem -LiteralPath $sourceRoot -File -Recurse |
    Sort-Object FullName)) {
  $relative = $file.FullName.Substring($sourceRoot.Length + 1).Replace("\", "/")
  if ($relative -eq ".luarc.json" -or $file.Name -eq ".gitkeep" -or
      $file.Extension -eq ".aseprite") { continue }
  Add-ArchiveFile $file.FullName ("gen2_clean_ui/" + $relative)
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$fixedTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
$stream = $null
$archive = $null
try {
  $stream = [IO.File]::Open($archivePath, [IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write, [IO.FileShare]::None)
  $archive = [IO.Compression.ZipArchive]::new(
    $stream, [IO.Compression.ZipArchiveMode]::Create, $false)
  foreach ($item in $entries) {
    $entry = $archive.CreateEntry($item.Relative,
      [IO.Compression.CompressionLevel]::Optimal)
    $entry.LastWriteTime = $fixedTime
    $input = [IO.File]::OpenRead($item.Source)
    $output = $entry.Open()
    try { $input.CopyTo($output) }
    finally { $output.Dispose(); $input.Dispose() }
  }
}
finally {
  if ($null -ne $archive) { $archive.Dispose() }
  if ($null -ne $stream) { $stream.Dispose() }
}

$check = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
  $names = @($check.Entries | ForEach-Object { $_.FullName })
  if ($names.Count -lt 3 -or $names[0] -ne "gen2_clean_ui/manifest.json") {
    throw "Archive root verification failed"
  }
  foreach ($name in $names) {
    if (-not $name.StartsWith("gen2_clean_ui/") -or $name.Contains("\")) {
      throw "Invalid archive entry: $name"
    }
  }
}
finally { $check.Dispose() }

$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
Write-Host "Created deterministic archive: $archivePath"
Write-Host "SHA-256: $hash"
