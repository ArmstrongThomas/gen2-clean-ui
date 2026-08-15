[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^(0|[1-9]\d*)\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')]
  [string]$Version,

  [string]$Tag,

  [Parameter(Mandatory = $true)]
  [string]$AssetPath,

  [string]$OutputPath = 'release-notes.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "v$Version" }

$blurbPath = Join-Path $repositoryRoot ("docs\\releases\\v{0}.md" -f $Version)
if (-not (Test-Path -LiteralPath $blurbPath -PathType Leaf)) {
  throw "Missing curated release blurb for v${Version}: $blurbPath"
}

$blurb = (Get-Content -LiteralPath $blurbPath -Raw -Encoding utf8).Trim()
if ([string]::IsNullOrWhiteSpace($blurb)) {
  throw "Curated release blurb is empty: $blurbPath"
}

$assetFullPath = if ([IO.Path]::IsPathRooted($AssetPath)) {
  [IO.Path]::GetFullPath($AssetPath)
} else {
  [IO.Path]::GetFullPath((Join-Path $repositoryRoot $AssetPath))
}
if (-not (Test-Path -LiteralPath $assetFullPath -PathType Leaf)) {
  throw "Release asset does not exist: $assetFullPath"
}

# Local smoke copies intentionally omit .git. In that case the curated blurb
# still renders and the change list falls back to a deterministic placeholder.
$changes = @()
$insideGit = $false
try {
  $probe = (& git -C $repositoryRoot rev-parse --is-inside-work-tree 2>$null)
  $insideGit = ($LASTEXITCODE -eq 0 -and [string]$probe -eq 'true')
} catch {
  $insideGit = $false
}

if ($insideGit) {
  $previous = @(
    & git -C $repositoryRoot tag --sort=-version:refname 2>$null |
      Where-Object {
        $_ -match '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$' -and
          $_ -ne $Tag
      } |
      Select-Object -First 1
  )
  if ($previous.Count -gt 0) {
    $changes = @(
      & git -C $repositoryRoot log --pretty=format:'- %s (%h)' "$($previous[0])..HEAD" 2>$null
    )
  } else {
    $changes = @(
      & git -C $repositoryRoot log -n 20 --pretty=format:'- %s (%h)' 2>$null
    )
  }
}

if ($changes.Count -eq 0) { $changes = @('- Initial release.') }

$sha256 = (Get-FileHash -LiteralPath $assetFullPath -Algorithm SHA256).Hash.ToUpperInvariant()
$notes = @(
  "# Gen2 Clean UI v$Version"
  ''
  $blurb
  ''
  '## Changes in this release'
  ''
)
$notes += @($changes)
$notes += @('', "**SHA-256:** ``$sha256``")

$outputFullPath = if ([IO.Path]::IsPathRooted($OutputPath)) {
  [IO.Path]::GetFullPath($OutputPath)
} else {
  [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath))
}
$outputParent = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
  New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
}
($notes -join "`r`n") | Set-Content -LiteralPath $outputFullPath -Encoding utf8
# A copied release-smoke tree has no .git directory; do not leak that expected
# probe status to the caller after successfully writing the notes.
$global:LASTEXITCODE = 0
Write-Host "Release notes written: $outputFullPath"
