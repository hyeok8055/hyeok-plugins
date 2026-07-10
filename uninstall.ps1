<#
.SYNOPSIS
  Reverse install.ps1: strip governance sentinels, restore backups, remove
  defaultMode pins, remove hyeok-marked user skills, and attempt CLI plugin uninstall.
  Idempotent and fail-open.
#>
[CmdletBinding()] param()
$ErrorActionPreference = 'Continue'
$BEGIN = '<!-- BEGIN hyeok-gov -->'
$END   = '<!-- END hyeok-gov -->'
$IBEGIN = '<!-- BEGIN hyeok-insane-search -->'
$IEND   = '<!-- END hyeok-insane-search -->'
$MARKER = '.hyeok-installed'
$Home_ = $env:USERPROFILE
$MarketName = 'hyeok-plugins'
$SkillNames = @('hyeok-governance','typst-korean','diagram-design')

function Info($m) { Write-Host "[hyeok] $m" }
function Write-NoBom($path, $text) {
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Restore-Or-Strip($path) {
  $bak = "$path.pre-hyeok.bak"
  if (Test-Path $bak) {
    Copy-Item $bak $path -Force; Remove-Item $bak -Force
    Info "restored $path from backup"
  } elseif (Test-Path $path) {
    $c = Get-Content -Raw -Encoding UTF8 -Path $path
    foreach ($pair in @(@($BEGIN,$END), @($IBEGIN,$IEND))) {
      $pattern = '(?s)\r?\n?' + [regex]::Escape($pair[0]) + '.*?' + [regex]::Escape($pair[1]) + '\r?\n?'
      $c = [regex]::Replace($c, $pattern, '')
    }
    if ([string]::IsNullOrWhiteSpace($c)) { Remove-Item $path -Force; Info "removed $path (was only hyeok blocks)" }
    else { Write-NoBom $path $c; Info "stripped hyeok blocks from $path" }
  }
}

function Remove-Vendor($dir) {
  if ((Test-Path (Join-Path $dir '.hyeok-vendor'))) {
    try { Remove-Item -Recurse -Force $dir; Info "removed vendored dir $dir" } catch { Info "could not remove $dir" }
  } elseif (Test-Path (Join-Path $dir 'SKILL.md.pre-hyeok.bak')) {
    Copy-Item (Join-Path $dir 'SKILL.md.pre-hyeok.bak') (Join-Path $dir 'SKILL.md') -Force
    Remove-Item (Join-Path $dir 'SKILL.md.pre-hyeok.bak') -Force
    Info "restored user-owned SKILL.md in $dir"
  }
}

function Remove-DefaultMode($tool) {
  if ($env:XDG_CONFIG_HOME) { $dir = Join-Path $env:XDG_CONFIG_HOME $tool }
  else { $base = $env:APPDATA; if (-not $base) { $base = Join-Path $Home_ 'AppData\Roaming' }; $dir = Join-Path $base $tool }
  $path = Join-Path $dir 'config.json'
  if (Test-Path $path) {
    try {
      $obj = Get-Content -Raw -Path $path | ConvertFrom-Json
      if ($obj.PSObject.Properties.Name -contains 'defaultMode') {
        $obj.PSObject.Properties.Remove('defaultMode')
        Write-NoBom $path (($obj | ConvertTo-Json -Depth 20))
        Info "${tool}: removed defaultMode pin"
      }
    } catch { Info "${tool}: config.json unreadable, left as-is" }
  }
}

function Remove-MarkedSkill($root, $name) {
  $dest = Join-Path $root $name
  $marker = Join-Path $dest $MARKER
  $bak = "$dest.pre-hyeok.bak"
  if (Test-Path $marker) {
    try { Remove-Item -Recurse -Force $dest; Info "removed skill $dest" } catch { Info "could not remove $dest" }
    if (Test-Path $bak) {
      try { Move-Item $bak $dest -Force; Info "restored pre-hyeok skill $dest" } catch {}
    }
  } elseif (Test-Path $bak) {
    # Installer moved foreign skill to bak but left our tree without marker somehow
    try {
      if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
      Move-Item $bak $dest -Force
      Info "restored pre-hyeok skill from $bak"
    } catch {}
  }
}

# Codex AGENTS
Restore-Or-Strip (Join-Path $Home_ '.codex\AGENTS.override.md')
Restore-Or-Strip (Join-Path $Home_ '.codex\AGENTS.md')
Restore-Or-Strip (Join-Path $Home_ '.grok\GROK.md')
Restore-Or-Strip (Join-Path $Home_ 'AGENTS.override.md')
Remove-DefaultMode 'caveman'
Remove-DefaultMode 'ponytail'

$flag = Join-Path $Home_ '.claude\.caveman-active'
if (Test-Path $flag) { Remove-Item $flag -Force; Info "removed caveman flag" }

# User skill trees (marker-guarded)
$skillRoots = @(
  (Join-Path $Home_ '.agents\skills'),
  (Join-Path $Home_ '.claude\skills'),
  (Join-Path $Home_ '.codex\skills'),
  (Join-Path $Home_ '.grok\skills')
) | Select-Object -Unique
foreach ($root in $skillRoots) {
  if (-not (Test-Path $root)) { continue }
  foreach ($n in $SkillNames) { Remove-MarkedSkill $root $n }
}

# insane-search vendors
Remove-Vendor (Join-Path $Home_ '.codex\tools\insane-search')
Remove-Vendor (Join-Path $Home_ '.agents\skills\insane-search')
Info 'Note: pip packages (curl_cffi/bs4/pyyaml) are intentionally NOT uninstalled.'

# Best-effort CLI plugin uninstall
foreach ($pair in @(
  @('claude', { param($p) & claude plugin uninstall "${p}@${MarketName}" 2>$null }),
  @('codex',  { param($p) & codex plugin remove "${p}@${MarketName}" 2>$null; & codex plugin remove $p --marketplace $MarketName 2>$null }),
  @('grok',   { param($p) & grok plugin uninstall $p --confirm 2>$null })
)) {
  $cli = $pair[0]; $fn = $pair[1]
  if (-not (Get-Command $cli -ErrorAction SilentlyContinue)) { continue }
  foreach ($p in $SkillNames) {
    try { & $fn $p | Out-Null; Info "$cli: attempted plugin uninstall $p" } catch {}
  }
}

Info 'Uninstall complete. (caveman/ponytail keep their own uninstallers.)'
