<#
.SYNOPSIS
  Install hyeok skills for Codex (PowerShell 5.1+).
.DESCRIPTION
  Default standalone skills mode: copy complete skill trees to ~/.agents/skills,
  then merge a small governance bootstrap into the active Codex AGENTS file.
  Do not also enable these skills through the Codex Plugins UI. The installer
  does not install fonts or change model/provider/auth/MCP
  configuration. Existing unrelated files are retained; changed files are
  backed up outside skill discovery, under ~/.hyeok/backups/.
  Legacy duplicate skills in ~/.codex/skills must be resolved before installing.
  -Mode plugins uses the official Codex plugin CLI instead of copying skills
  or writing a bootstrap. Only plugin/marketplace settings are managed by it.
  Sources: https://learn.chatgpt.com/docs/build-skills
           https://learn.chatgpt.com/docs/agent-configuration/agents-md
.PARAMETER TargetHome
  An existing home directory. When supplied, both skill and bootstrap writes
  stay in this directory; CODEX_HOME is ignored for an isolated installation.
  Otherwise use the current home and respect CODEX_HOME for the bootstrap.
.PARAMETER Mode
  skills (default) or plugins. These installation modes are mutually exclusive.
.PARAMETER SkipCliPlugins
  Compatibility switch. Use with skills mode only.
.PARAMETER SkipFonts
  Compatibility switch. Font installation is always disabled.
.PARAMETER PonytailMode
  Compatibility option. Accepted without changing any tool configuration.
.EXAMPLE
  ./install.ps1 -TargetHome C:\Temp\codex-install-test
#>
[CmdletBinding()]
param(
  [string]$TargetHome,
  [ValidateSet('skills','plugins')]
  [string]$Mode = 'skills',
  [switch]$SkipCliPlugins,
  [switch]$SkipFonts,
  [ValidateSet('off','lite','full','ultra','wenyan-lite','wenyan','wenyan-full','wenyan-ultra')]
  [string]$PonytailMode
)

$ErrorActionPreference = 'Stop'
$BeginTag = '<!-- BEGIN hyeok-gov -->'
$EndTag = '<!-- END hyeok-gov -->'
$Marker = '.hyeok-installed'
$ChangedFiles = 0
$BackupRoot = $null

function Info([string]$Message) { Write-Host "[hyeok] $Message" }

function Get-ContentHash([string]$Path) {
  $hash = [System.Security.Cryptography.SHA256]::Create()
  $stream = [System.IO.File]::OpenRead($Path)
  try { return [BitConverter]::ToString($hash.ComputeHash($stream)) }
  finally { $stream.Dispose(); $hash.Dispose() }
}

function Assert-PlainPath([string]$Path) {
  $candidate = [System.IO.Path]::GetFullPath($Path)
  while ($candidate) {
    $item = Get-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue
    if ($null -ne $item) {
      if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "Refusing a symlink or junction in install path: $candidate"
      }
    }
    $candidate = Split-Path -Parent $candidate
  }
}

function Assert-PlainTree([string]$Path) {
  Assert-PlainPath $Path
  if (Test-Path -LiteralPath $Path -PathType Container) {
    foreach ($item in Get-ChildItem -LiteralPath $Path -Force) {
      if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "Refusing a symlink or junction in skill tree: $($item.FullName)"
      }
      if ($item.PSIsContainer) { Assert-PlainTree $item.FullName }
    }
  }
}

function Ensure-Directory([string]$Path) {
  Assert-PlainPath $Path
  if (Test-Path -LiteralPath $Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
      throw "Expected a directory, found a file: $Path"
    }
  } else {
    [void][System.IO.Directory]::CreateDirectory($Path)
  }
}

function Backup-File([string]$Path, [string]$RelativePath) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Refusing to replace a directory with a file: $Path"
  }
  if (-not $script:BackupRoot) {
    $runId = (Get-Date -Format 'yyyyMMddTHHmmss') + '-' + [guid]::NewGuid().ToString('N')
    $script:BackupRoot = Join-Path $UserHome ".hyeok/backups/codex-$runId"
  }
  $backup = Join-Path $script:BackupRoot $RelativePath
  Ensure-Directory (Split-Path -Parent $backup)
  if (-not (Test-Path -LiteralPath $backup)) {
    Copy-Item -LiteralPath $Path -Destination $backup -ErrorAction Stop
  }
}

function Write-ManagedText([string]$Path, [string]$Text, [string]$RelativePath) {
  Assert-PlainPath $Path
  $encoding = New-Object System.Text.UTF8Encoding($false)
  $bytes = $encoding.GetBytes($Text)
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $oldBytes = [System.IO.File]::ReadAllBytes($Path)
    if ([Convert]::ToBase64String($oldBytes) -ceq [Convert]::ToBase64String($bytes)) { return }
  }
  Backup-File $Path $RelativePath
  Ensure-Directory (Split-Path -Parent $Path)
  [System.IO.File]::WriteAllBytes($Path, $bytes)
  $script:ChangedFiles++
}

function Copy-SkillTree([string]$Source, [string]$Destination, [string]$RelativePath) {
  Ensure-Directory $Destination
  foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
    $dest = Join-Path $Destination $item.Name
    $relative = Join-Path $RelativePath $item.Name
    Assert-PlainPath $dest
    if ($item.PSIsContainer) {
      Copy-SkillTree $item.FullName $dest $relative
    } else {
      if (Test-Path -LiteralPath $dest -PathType Leaf) {
        if ((Get-ContentHash $item.FullName) -eq (Get-ContentHash $dest)) { continue }
      }
      Backup-File $dest $relative
      Copy-Item -LiteralPath $item.FullName -Destination $dest -Force -ErrorAction Stop
      $script:ChangedFiles++
    }
  }
}

$isolated = $PSBoundParameters.ContainsKey('TargetHome')
if ($isolated) {
  if ([string]::IsNullOrWhiteSpace($TargetHome)) { throw 'TargetHome must not be empty.' }
  $UserHome = $TargetHome
} elseif ($env:USERPROFILE) {
  $UserHome = $env:USERPROFILE
} else {
  $UserHome = $HOME
}
if (-not [System.IO.Path]::IsPathRooted($UserHome) -or $UserHome -match '[\r\n]') {
  throw 'The target home must be an absolute path without line breaks.'
}
$UserHome = [System.IO.Path]::GetFullPath($UserHome)
Assert-PlainPath $UserHome
if (-not (Test-Path -LiteralPath $UserHome -PathType Container)) {
  throw "The target home must already exist: $UserHome"
}
$SkillsRoot = Join-Path $UserHome '.agents/skills'
$CodexDirectory = if (-not $isolated -and $env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $UserHome '.codex' }
if (-not [System.IO.Path]::IsPathRooted($CodexDirectory) -or $CodexDirectory -match '[\r\n]') {
  throw 'CODEX_HOME must be an absolute path without line breaks.'
}
$CodexDirectory = [System.IO.Path]::GetFullPath($CodexDirectory)
Assert-PlainPath $SkillsRoot
Assert-PlainPath $CodexDirectory
Assert-PlainPath (Join-Path $UserHome '.hyeok/backups')
$override = Join-Path $CodexDirectory 'AGENTS.override.md'
$AgentsPath = if (Test-Path -LiteralPath $override -PathType Leaf) { $override } else { Join-Path $CodexDirectory 'AGENTS.md' }
Assert-PlainPath $AgentsPath

$SkillSources = [ordered]@{
  'hyeok-governance' = 'plugins/hyeok-governance/skills/hyeok-governance'
  'typst-korean' = 'plugins/typst-korean/skills/typst-korean'
  'diagram-design' = 'plugins/diagram-design/skills/diagram-design'
  'archify' = 'plugins/archify/skills/archify'
  'lieflat-charts' = 'plugins/lieflat-charts/skills/lieflat-charts'
}
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'plugins/juhyeoknizer/skills/juhyeoknizer/SKILL.md') -PathType Leaf) {
  $SkillSources['juhyeoknizer'] = 'plugins/juhyeoknizer/skills/juhyeoknizer'
}
$PluginReceipt = Join-Path $UserHome '.hyeok/codex-plugins-installed'
Assert-PlainPath $PluginReceipt
foreach ($legacyName in @('humanize-korean','humanize','humanize-redo')) {
  foreach ($root in @($SkillsRoot, (Join-Path $UserHome '.codex/skills'), (Join-Path $CodexDirectory 'skills'))) {
    $legacy = Join-Path $root "$legacyName/SKILL.md"
    if (Test-Path -LiteralPath $legacy) {
      throw "Legacy writing skill at $legacy. Preserve or disable that copy before installing juhyeoknizer as the single writing skill."
    }
  }
}
if ($Mode -eq 'plugins') {
  if ($SkipCliPlugins) { throw '-SkipCliPlugins conflicts with -Mode plugins.' }
  foreach ($name in $SkillSources.Keys) {
    foreach ($root in @($SkillsRoot, (Join-Path $UserHome '.codex/skills'), (Join-Path $CodexDirectory 'skills'))) {
      if (Test-Path -LiteralPath (Join-Path $root "$name/SKILL.md")) {
        throw "Standalone skill at $root/$name. Uninstall or disable that copy before using plugins mode."
      }
    }
  }
  $codex = Get-Command codex -ErrorAction Stop
  $config = Join-Path $CodexDirectory 'config.toml'
  Assert-PlainPath $config
  $previousCodexHome = $env:CODEX_HOME
  try {
    $env:CODEX_HOME = $CodexDirectory
    & $codex plugin add --help | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'This Codex does not support plugin add. Use skills mode; the installer never updates Codex.' }
    & $codex plugin marketplace add --help | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'This Codex does not support local plugin marketplaces. Use skills mode.' }
    Backup-File $config 'plugin-config/config.toml'
    $receiptText = "installer=codex-plugins-v1`n"
    if (Test-Path -LiteralPath $PluginReceipt -PathType Leaf) {
      $previousReceipt = [System.IO.File]::ReadAllText($PluginReceipt)
      if ($previousReceipt -match '(?m)^installer=codex-plugins-v1\r?$') { $receiptText = $previousReceipt }
    }
    foreach ($name in $SkillSources.Keys) {
      if ($receiptText -notmatch ('(?m)^plugin=' + [regex]::Escape($name) + '\r?$')) { $receiptText += "plugin=$name`n" }
    }
    Write-ManagedText $PluginReceipt $receiptText 'plugin-config/receipt'
    & $codex plugin marketplace add $PSScriptRoot --json | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Codex could not add the local marketplace.' }
    foreach ($name in $SkillSources.Keys) {
      & $codex plugin add "$name@hyeok-plugins" --json | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "Codex could not install $name@hyeok-plugins." }
      Info "plugin $name@hyeok-plugins installed"
    }
  } finally {
    $env:CODEX_HOME = $previousCodexHome
  }
  Info 'Done in plugins mode. No standalone skills or AGENTS bootstrap were copied.'
  if ($BackupRoot) { Info "Previous file contents -> $BackupRoot" }
  return
}
if (Test-Path -LiteralPath $PluginReceipt) {
  throw 'This pack has a plugins-mode receipt. Uninstall that mode before using standalone skills mode.'
}

# Preflight every tree before writing anything. Do not migrate or delete older
# installs automatically: those may contain foreign files or be plugin-managed.
foreach ($name in $SkillSources.Keys) {
  $source = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $SkillSources[$name]))
  if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md') -PathType Leaf)) {
    throw "Skill source missing: $source/SKILL.md"
  }
  Assert-PlainTree $source
  $destination = Join-Path $SkillsRoot $name
  Assert-PlainTree $destination
  $separator = [System.IO.Path]::DirectorySeparatorChar
  if ($destination.StartsWith($source.TrimEnd($separator) + $separator, [System.StringComparison]::OrdinalIgnoreCase) -or
      $source.StartsWith($destination.TrimEnd($separator) + $separator, [System.StringComparison]::OrdinalIgnoreCase) -or
      $source -eq $destination) {
    throw "Source and destination overlap: $source -> $destination"
  }
  foreach ($legacyRoot in @((Join-Path $UserHome '.codex/skills'), (Join-Path $CodexDirectory 'skills'))) {
    $legacy = Join-Path $legacyRoot "$name/SKILL.md"
    if (Test-Path -LiteralPath $legacy) {
      throw "Duplicate skill at $legacy. Resolve the old installation before using standalone skills mode."
    }
  }
  if (Test-Path -LiteralPath (Join-Path $SkillsRoot "$name.pre-hyeok.bak/SKILL.md")) {
    throw "An old backup of $name is in the skill discovery root. Preserve it outside that root before installing."
  }
}

$content = if (Test-Path -LiteralPath $AgentsPath -PathType Leaf) { [System.IO.File]::ReadAllText($AgentsPath) } else { '' }
$pattern = '(?ms)^' + [regex]::Escape($BeginTag) + '\r?\n.*?^' + [regex]::Escape($EndTag) + '(?=\r?$)'
$beginCount = [regex]::Matches($content, [regex]::Escape($BeginTag)).Count
$endCount = [regex]::Matches($content, [regex]::Escape($EndTag)).Count
if ($beginCount -ne $endCount -or $beginCount -gt 1 -or
    ($beginCount -eq 1 -and -not [regex]::IsMatch($content, $pattern))) {
  throw "Malformed or repeated hyeok governance markers in $AgentsPath; left unchanged."
}

Info "Codex standalone skills mode -> $SkillsRoot"
Info 'Use either standalone skills or the Codex Plugins UI for this pack, not both.'
if ($PSBoundParameters.ContainsKey('PonytailMode')) {
  Write-Warning '-PonytailMode is retained for compatibility and no longer writes tool settings.'
}
foreach ($name in $SkillSources.Keys) {
  $source = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $SkillSources[$name]))
  $dest = Join-Path $SkillsRoot $name
  $state = Join-Path $UserHome ".hyeok/state/skills/$name"
  Ensure-Directory $state
  $entry = Join-Path $dest 'SKILL.md'
  $existingMarker = Join-Path $dest $Marker
  $owned = (Test-Path -LiteralPath $existingMarker -PathType Leaf) -and
    ([System.IO.File]::ReadAllLines($existingMarker) -contains 'installer=codex-skills-v1')
  $original = Join-Path $state 'original/SKILL.md'
  Assert-PlainPath $original
  if (-not $owned -and (Test-Path -LiteralPath $entry -PathType Leaf) -and -not (Test-Path -LiteralPath $original)) {
    Ensure-Directory (Split-Path -Parent $original)
    Copy-Item -LiteralPath $entry -Destination $original
  }
  Copy-SkillTree $source $dest "skills/$name"
  $stateFile = Join-Path $state 'SKILL.md'
  Assert-PlainPath $stateFile
  if (-not (Test-Path -LiteralPath $stateFile -PathType Leaf) -or
      (Get-ContentHash $entry) -ne (Get-ContentHash $stateFile)) {
    Backup-File $stateFile "state/skills/$name/SKILL.md"
    Copy-Item -LiteralPath $entry -Destination $stateFile -Force
  }
  Write-ManagedText (Join-Path $dest $Marker) "installer=codex-skills-v1`nname=$name`nsource=$source`n" "skills/$name/$Marker"
  Info "skill $name -> $dest"
}

$nl = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
$governancePath = (Join-Path $SkillsRoot 'hyeok-governance/SKILL.md').Replace('\', '/')
$body = @(
  $BeginTag,
  'Use the installed hyeok-governance skill to route Codex work through the appropriate skills and available tools.',
  "Start with <$governancePath> and read its references only when the task needs them.",
  'Follow the user and repository instructions and the capabilities of the current Codex session.',
  $EndTag
) -join $nl
if ($beginCount -eq 1) {
  $updated = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $body })
} elseif ($content.Length -eq 0) {
  $updated = $body + $nl
} else {
  $gap = if ($content.EndsWith("`n")) { $nl } else { $nl + $nl }
  $updated = $content + $gap + $body + $nl
}
Write-ManagedText $AgentsPath $updated ('instructions/' + (Split-Path -Leaf $AgentsPath))
Info "Governance bootstrap -> $AgentsPath"
Info "Done. $ChangedFiles files changed. No CLI, font, or dependency installation was run."
if ($BackupRoot) { Info "Previous file contents -> $BackupRoot" }
