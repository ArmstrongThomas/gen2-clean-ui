[CmdletBinding()]
param([string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$modRoot = Join-Path $root "mods\gen2_clean_ui"
$rules = @(
  [pscustomobject]@{ Code="raw_io"; Pattern='(?<![A-Za-z0-9_])io(?![A-Za-z0-9_])'; Message="io is unavailable; use mod:read or mod.storage" },
  [pscustomobject]@{ Code="unsafe_os"; Pattern='(?<![A-Za-z0-9_])os(?![A-Za-z0-9_])(?!(?:\s*\.\s*(?:time|date|clock)(?![A-Za-z0-9_])))'; Message="only os.time, os.date, and os.clock are available" },
  [pscustomobject]@{ Code="blocked_love_namespace"; Pattern='(?<![A-Za-z0-9_])love\s*(?:\.\s*(?:filesystem|thread|system|event)(?![A-Za-z0-9_])|\[\s*["''](?:filesystem|thread|system|event)["'']\s*\])'; Message="blocked love namespace; use mod APIs" },
  [pscustomobject]@{ Code="blocked_global"; Pattern='(?<![A-Za-z0-9_])(?:debug|package|ffi)(?![A-Za-z0-9_])'; Message="debug, package, and ffi are unavailable" },
  [pscustomobject]@{ Code="blocked_loader"; Pattern='(?<![A-Za-z0-9_])(?:dofile|loadfile|getfenv|setfenv)(?![A-Za-z0-9_])'; Message="blocked loader/environment API; use mod:read plus sandboxed load" },
  [pscustomobject]@{ Code="blocked_require"; Pattern='(?<![A-Za-z0-9_])require\s*(?:\(\s*)?["''](?:io|os|debug|package|ffi|love(?:\.|["'']))'; Message="blocked module require; use the provided love table or supported engine modules" },
  [pscustomobject]@{ Code="private_global"; Pattern='(?<![A-Za-z0-9_])_G(?![A-Za-z0-9_])'; Message="do not use private _G for integration; use mod.exports and mod.find" }
)
$literalPathPatterns = @(
  '(?x)(?<![A-Za-z0-9_])mod\s*:\s*read\s*\(\s*(?<quote>["''])(?<path>[^"'']*)\k<quote>',
  '(?x)(?<![A-Za-z0-9_])mod\s*\.\s*assets\s*:\s*(?:path|image)\s*\(\s*(?<quote>["''])(?<path>[^"'']*)\k<quote>'
)
$nativeExtensions = @(".a", ".dll", ".dylib", ".exe", ".lib", ".luac", ".so", ".wasm")

function Test-ModRelativePath([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
  if ($Value.IndexOf([char]0) -ge 0 -or $Value.Contains('\')) { return $false }
  if ($Value.StartsWith('/') -or $Value -match '^[A-Za-z]:' -or
      $Value -match '^[A-Za-z][A-Za-z0-9+.-]*:') { return $false }
  foreach ($segment in $Value.Split('/')) {
    if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or
        $segment -eq '..') { return $false }
  }
  return $true
}

function Get-ForbiddenBinaryKind([byte[]]$Bytes) {
  if ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0x1B -and
      $Bytes[1] -eq 0x4C -and $Bytes[2] -eq 0x75 -and
      $Bytes[3] -eq 0x61) { return "Lua bytecode" }
  if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0x1B -and
      $Bytes[1] -eq 0x4C -and $Bytes[2] -eq 0x4A) { return "LuaJIT bytecode" }
  if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0x4D -and $Bytes[1] -eq 0x5A) { return "PE executable" }
  if ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0x7F -and $Bytes[1] -eq 0x45 -and $Bytes[2] -eq 0x4C -and $Bytes[3] -eq 0x46) { return "ELF executable" }
  if ($Bytes.Length -ge 4) {
    $magic = '{0:X2}{1:X2}{2:X2}{3:X2}' -f $Bytes[0],$Bytes[1],$Bytes[2],$Bytes[3]
    if ($magic -in @("FEEDFACE","FEEDFACF","CEFAEDFE","CFFAEDFE","CAFEBABE","BEBAFECA")) { return "Mach-O executable" }
    if ($magic -eq "0061736D") { return "WebAssembly bytecode" }
  }
  return $null
}

function Get-LineNumber([string]$Text, [int]$Index) {
  if ($Index -le 0) { return 1 }
  return 1 + ([regex]::Matches($Text.Substring(0, $Index), "`n")).Count
}

function Get-SandboxViolations([string]$Source) {
  $violations = @()
  foreach ($rule in $rules) {
    foreach ($match in [regex]::Matches($Source, $rule.Pattern)) {
      $violations += [pscustomobject]@{ Code=$rule.Code; Line=(Get-LineNumber $Source $match.Index); Message=$rule.Message; Match=$match.Value }
    }
  }
  return $violations
}

function Get-LiteralModPaths([string]$Source) {
  $paths = @()
  foreach ($pattern in $literalPathPatterns) {
    foreach ($match in [regex]::Matches($Source, $pattern)) {
      $paths += [pscustomobject]@{ Path=$match.Groups["path"].Value; Line=(Get-LineNumber $Source $match.Index) }
    }
  }
  return $paths
}

foreach ($safe in @("main.lua", "src/bootstrap.lua", "assets/icon.png")) {
  if (-not (Test-ModRelativePath $safe)) {
    throw "Sandbox path self-test rejected safe path: $safe"
  }
}
foreach ($unsafe in @("", "../main.lua", "src/../main.lua", "/main.lua",
    "C:/main.lua", "file://main.lua", "src//main.lua", "./main.lua",
    "src\main.lua")) {
  if (Test-ModRelativePath $unsafe) {
    throw "Sandbox path self-test accepted unsafe path: $unsafe"
  }
}
if ((Get-ForbiddenBinaryKind ([byte[]](0x1B,0x4C,0x75,0x61))) -ne "Lua bytecode" -or
    (Get-ForbiddenBinaryKind ([byte[]](0x1B,0x4C,0x4A))) -ne "LuaJIT bytecode" -or
    (Get-ForbiddenBinaryKind ([byte[]](0x4D,0x5A))) -ne "PE executable" -or
    (Get-ForbiddenBinaryKind ([byte[]](0x7F,0x45,0x4C,0x46))) -ne "ELF executable" -or
    (Get-ForbiddenBinaryKind ([byte[]](0x00,0x61,0x73,0x6D))) -ne "WebAssembly bytecode") {
  throw "Sandbox bytecode self-test failed"
}
$blockedSamples = @('return require "io"', 'return love ["filesystem"]', 'local loader = loadfile', 'return _G.shared')
foreach ($sample in $blockedSamples) {
  if (@(Get-SandboxViolations $sample).Count -eq 0) { throw "Sandbox API self-test accepted blocked source: $sample" }
}
$allowedSamples = @('return os.time()', 'return love.graphics', 'mod.exports.api = {}', 'return mod.find("other")', 'return mod.storage:read(game, "key")')
foreach ($sample in $allowedSamples) {
  if (@(Get-SandboxViolations $sample).Count -ne 0) { throw "Sandbox API self-test rejected allowed source: $sample" }
}
$literalUnsafe = @(Get-LiteralModPaths 'return mod.assets:path("../escape")')
if ($literalUnsafe.Count -ne 1 -or (Test-ModRelativePath $literalUnsafe[0].Path)) { throw "Sandbox literal-path self-test failed" }

$hits = @()
$luaCount = 0
foreach ($item in Get-ChildItem -LiteralPath $modRoot -Recurse -Force -ErrorAction SilentlyContinue) {
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    $hits += "$($item.FullName): reparse points/symlinks may not ship"
  }
}
foreach ($file in Get-ChildItem -LiteralPath $modRoot -File -Recurse) {
  $bytes = [IO.File]::ReadAllBytes($file.FullName)
  $kind = Get-ForbiddenBinaryKind $bytes
  $extension = $file.Extension.ToLowerInvariant()
  if ($extension -in $nativeExtensions) {
    $hits += "$($file.FullName): native/compiled extension may not ship"
  } elseif ($null -ne $kind) {
    $hits += "$($file.FullName): $kind may not ship"
  }
  if ($extension -ne ".lua") { continue }
  $luaCount++
  if ($null -ne $kind) {
    continue
  }
  try {
    $source = ([Text.UTF8Encoding]::new($false, $true)).GetString($bytes)
  } catch {
    $hits += "$($file.FullName): Lua source must be valid UTF-8"
    continue
  }
  foreach ($violation in Get-SandboxViolations $source) {
    $hits += "$($file.FullName):$($violation.Line): $($violation.Code): $($violation.Message) [$($violation.Match)]"
  }
  foreach ($literal in Get-LiteralModPaths $source) {
    if (-not (Test-ModRelativePath $literal.Path)) {
      $hits += "$($file.FullName):$($literal.Line): unsafe literal mod path [$($literal.Path)]"
    }
  }
}
try {
  $manifest = Get-Content -LiteralPath (Join-Path $modRoot "manifest.json") `
    -Raw | ConvertFrom-Json
  foreach ($field in @("entry", "options_schema")) {
      $property = $manifest.PSObject.Properties[$field]
      if ($field -eq "options_schema" -and $null -eq $property) { continue }
      $value = if ($null -eq $property) { "" } else { [string]$property.Value }
    if (-not (Test-ModRelativePath $value)) {
      $hits += "manifest.json: $field must be a safe mod-relative path"
    } elseif (-not (Test-Path -LiteralPath (Join-Path $modRoot $value) -PathType Leaf)) {
      $hits += "manifest.json: $field target does not exist: $value"
    }
  }
} catch {
  $hits += "manifest.json: unable to validate sandbox paths: $($_.Exception.Message)"
}
if ($hits.Count -gt 0) {
  throw "Sandbox-incompatible shipped Lua:`n$($hits -join "`n")"
}
Write-Host "Gen2 sandbox verification passed ($luaCount UTF-8 source Lua files; blocked APIs, private-global coupling, unsafe literal/manifest paths, reparse points, native binaries, and bytecode absent)."
