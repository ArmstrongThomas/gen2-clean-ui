[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = Join-Path $tempBase ("gen2-clean-ui-release-smoke-" +
  [Guid]::NewGuid().ToString("N"))
$copyRoot = Join-Path $tempRoot "product"

function IsInsideTemp([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path)
  return $full.StartsWith($tempBase + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)
}

try {
  New-Item -ItemType Directory -Path $copyRoot -Force | Out-Null
  Get-ChildItem -LiteralPath $sourceRoot -Force |
    Where-Object { $_.Name -ne ".git" } |
    ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $copyRoot -Recurse -Force
    }

  $manifestPath = Join-Path $copyRoot "mods\gen2_clean_ui\manifest.json"
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $version = [string]$manifest.version
  $blurbPath = Join-Path $copyRoot ("docs\releases\v{0}.md" -f $version)
  if (-not (Test-Path -LiteralPath $blurbPath -PathType Leaf)) {
    throw "Release smoke is missing the manifest-matched blurb: $blurbPath"
  }
  $curatedBlurb = (Get-Content -LiteralPath $blurbPath -Raw -Encoding utf8).Trim()
  if ([string]::IsNullOrWhiteSpace($curatedBlurb)) {
    throw "Manifest-matched release blurb is empty: $blurbPath"
  }
  $zipPath = Join-Path $copyRoot ("gen2_clean_ui-{0}.zip" -f $version)

  & (Join-Path $copyRoot "build_release.ps1")
  $first = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
  & (Join-Path $copyRoot "build_release.ps1")
  $second = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
  if ($first -ne $second) { throw "Release ZIP is not deterministic" }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName })
    if ($names.Count -eq 0) { throw "Release ZIP is empty" }
    if ($names[0] -ne "gen2_clean_ui/manifest.json") {
      throw "manifest.json must be the first archive entry"
    }
    foreach ($name in $names) {
      if (-not $name.StartsWith("gen2_clean_ui/",
          [StringComparison]::Ordinal) -or $name.Contains('\')) {
        throw "Archive entry escaped the mod root: $name"
      }
    }
    foreach ($required in @(
        "gen2_clean_ui/manifest.json",
        "gen2_clean_ui/main.lua",
        "gen2_clean_ui/vendor/clean_ui_core/bootstrap.lua",
        "gen2_clean_ui/clean-ui-core.lock.json")) {
      if ($names -notcontains $required) {
        throw "Archive is missing $required"
      }
    }
    $archiveManifest = $zip.GetEntry("gen2_clean_ui/manifest.json")
    $reader = [IO.StreamReader]::new($archiveManifest.Open())
    try { $packed = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
    if ([string]$packed.version -ne [string]$manifest.version) {
      throw "Archive manifest version does not match the source manifest"
    }
  } finally { $zip.Dispose() }

  $notesPath = Join-Path $copyRoot 'release-notes-smoke.md'
  & (Join-Path $copyRoot 'scripts\\write_release_notes.ps1') `
    -Version $version `
    -Tag ("v{0}" -f $version) `
    -AssetPath $zipPath `
    -OutputPath $notesPath
  $notes = Get-Content -LiteralPath $notesPath -Raw
  $normalizedNotes = $notes -replace "`r`n", "`n" -replace "`r", "`n"
  $normalizedBlurb = $curatedBlurb -replace "`r`n", "`n" -replace "`r", "`n"
  if (-not $normalizedNotes.Contains($normalizedBlurb)) {
    throw "Release notes did not include the manifest-matched blurb for v$version"
  }
  if (-not $notes.Contains("# Gen2 Clean UI v$version")) {
    throw "Release notes title did not use the manifest version $version"
  }
  if (-not $notes.Contains('## Changes in this release')) {
    throw 'Release notes did not include the generated change section'
  }
  if ($notes.Contains('System.Object[]')) {
    throw 'Release notes flattened an array as System.Object[]'
  }
  if (-not $notes.Contains($first.ToUpperInvariant())) {
    throw 'Release notes did not include the archive SHA-256'
  }

  Write-Host "Release tooling smoke test passed: $first"
} finally {
  if ((Test-Path -LiteralPath $tempRoot) -and (IsInsideTemp $tempRoot)) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
