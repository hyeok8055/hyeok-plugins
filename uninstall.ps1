<#
.SYNOPSIS
  Remove the Codex installation made by install.ps1.
.DESCRIPTION
  Default skills mode deactivates only marked, unmodified SKILL.md entry points
  and removes the owned AGENTS bootstrap. Resource files and all backups remain.
  Modified entry points and foreign skills are preserved. Original foreign
  SKILL.md files, when recorded by this installer, are restored.
  -Mode plugins calls only the official Codex plugin remove command for names
  in the install receipt; it retains marketplace registration and other plugins.
  Does not modify model/provider/auth/permissions/MCP or other hosts' settings.
.PARAMETER TargetHome
  Existing isolated home; CODEX_HOME is ignored when this is supplied.
#>
[CmdletBinding()]
param(
  [string]$TargetHome,
  [ValidateSet('skills','plugins')]
  [string]$Mode = 'skills'
)
$ErrorActionPreference = 'Stop'
function Info([string]$Message) { Write-Host "[hyeok] $Message" }
function Get-ContentHash([string]$Path) {
  $hash = [Security.Cryptography.SHA256]::Create()
  $stream = [IO.File]::OpenRead($Path)
  try { return [BitConverter]::ToString($hash.ComputeHash($stream)) }
  finally { $stream.Dispose(); $hash.Dispose() }
}
function Assert-PlainPath([string]$Path) {
  $candidate = [IO.Path]::GetFullPath($Path)
  while ($candidate) {
    $item = Get-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue
    if ($null -ne $item) {
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Refusing a symlink or junction: $candidate"
      }
    }
    $candidate = Split-Path -Parent $candidate
  }
}
$isolated = $PSBoundParameters.ContainsKey('TargetHome')
$UserHome = if ($isolated) { $TargetHome } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
if ([string]::IsNullOrWhiteSpace($UserHome) -or -not [IO.Path]::IsPathRooted($UserHome)) { throw 'An absolute target home is required.' }
$UserHome = [IO.Path]::GetFullPath($UserHome)
Assert-PlainPath $UserHome
if (-not (Test-Path -LiteralPath $UserHome -PathType Container)) { throw 'The target home must already exist.' }
$CodexDirectory = if (-not $isolated -and $env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $UserHome '.codex' }
if (-not [IO.Path]::IsPathRooted($CodexDirectory)) { throw 'CODEX_HOME must be absolute.' }
Assert-PlainPath $CodexDirectory
$BackupRoot = Join-Path $UserHome ('.hyeok/backups/uninstall-' + [guid]::NewGuid().ToString('N'))
function Backup-File([string]$Path, [string]$Relative) {
  $dest = Join-Path $BackupRoot $Relative
  Assert-PlainPath $Path
  Assert-PlainPath $dest
  [void][IO.Directory]::CreateDirectory((Split-Path -Parent $dest))
  Copy-Item -LiteralPath $Path -Destination $dest -ErrorAction Stop
}
if ($Mode -eq 'plugins') {
  $receipt = Join-Path $UserHome '.hyeok/codex-plugins-installed'
  Assert-PlainPath $receipt
  if (-not (Test-Path -LiteralPath $receipt -PathType Leaf)) { Info 'No plugins-mode receipt. Nothing removed.'; return }
  $lines = [IO.File]::ReadAllLines($receipt)
  if ($lines -notcontains 'installer=codex-plugins-v1') { throw 'Foreign plugin receipt; left unchanged.' }
  $allowed = @('hyeok-governance','typst-korean','diagram-design','archify','lieflat-charts','juhyeoknizer')
  $names = @($lines | Where-Object { $_ -like 'plugin=*' } | ForEach-Object { $_.Substring(7) })
  foreach ($name in $names) { if ($allowed -notcontains $name) { throw "Unexpected plugin receipt entry: $name" } }
  $codex = Get-Command codex -ErrorAction Stop
  $config = Join-Path $CodexDirectory 'config.toml'
  Assert-PlainPath $config
  if (Test-Path -LiteralPath $config -PathType Leaf) { Backup-File $config 'plugin-config/config.toml' }
  $previousCodexHome = $env:CODEX_HOME
  try {
    $env:CODEX_HOME = $CodexDirectory
    foreach ($name in $names) {
      & $codex plugin remove "$name@hyeok-plugins" --json | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "Codex could not remove $name@hyeok-plugins. Receipt retained for retry." }
      Info "Removed plugin $name@hyeok-plugins"
    }
  } finally { $env:CODEX_HOME = $previousCodexHome }
  Backup-File $receipt 'plugin-config/receipt'
  Remove-Item -LiteralPath $receipt -Force
  return
}
foreach ($name in @('hyeok-governance','typst-korean','diagram-design','archify','lieflat-charts','juhyeoknizer')) {
  $skillDir = Join-Path $UserHome ".agents/skills/$name"
  $entry = Join-Path $skillDir 'SKILL.md'
  $marker = Join-Path $skillDir '.hyeok-installed'
  $state = Join-Path $UserHome ".hyeok/state/skills/$name"
  Assert-PlainPath $marker
  Assert-PlainPath $entry
  Assert-PlainPath $state
  if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { continue }
  if (([IO.File]::ReadAllLines($marker) -notcontains 'installer=codex-skills-v1') -or
      ([IO.File]::ReadAllLines($marker) -notcontains "name=$name")) { continue }
  $recorded = Join-Path $state 'SKILL.md'
  Assert-PlainPath $recorded
  if ((Test-Path -LiteralPath $entry -PathType Leaf) -and (Test-Path -LiteralPath $recorded -PathType Leaf) -and
      (Get-ContentHash $entry) -eq (Get-ContentHash $recorded)) {
    Backup-File $entry "skills/$name/SKILL.md"
    $original = Join-Path $state 'original/SKILL.md'
    Assert-PlainPath $original
    if (Test-Path -LiteralPath $original -PathType Leaf) { Copy-Item -LiteralPath $original -Destination $entry -Force }
    else { Remove-Item -LiteralPath $entry -Force }
    Backup-File $marker "skills/$name/.hyeok-installed"
    Remove-Item -LiteralPath $marker -Force
    Info "Deactivated skill $name; resources and backups retained."
  } else { Info "Preserved modified or unrecorded skill: $entry" }
}
foreach ($file in @('AGENTS.override.md','AGENTS.md')) {
  $path = Join-Path $CodexDirectory $file
  Assert-PlainPath $path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
  $text = [IO.File]::ReadAllText($path)
  $pattern = '(?ms)^<!-- BEGIN hyeok-gov -->\r?\n.*?^<!-- END hyeok-gov -->(?:\r?\n|$)'
  $blocks = [regex]::Matches($text, $pattern)
  if ($blocks.Count -eq 0) { continue }
  if ($blocks.Count -ne 1 -or [regex]::Matches($text, '<!-- BEGIN hyeok-gov -->').Count -ne 1 -or
      [regex]::Matches($text, '<!-- END hyeok-gov -->').Count -ne 1 -or
      $blocks[0].Value -notmatch 'Use the installed hyeok-governance skill') {
    Info "Preserved unrecognized governance block: $path"; continue
  }
  Backup-File $path "instructions/$file"
  [IO.File]::WriteAllText($path, [regex]::Replace($text, $pattern, ''), (New-Object Text.UTF8Encoding($false)))
}
Info 'Codex uninstall finished. Foreign files, resource files and backups were retained.'
