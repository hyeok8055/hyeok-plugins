<#
.SYNOPSIS
  Reverse install.ps1: strip governance sentinel blocks, restore pre-install backups,
  remove the caveman/ponytail defaultMode pin, delete the caveman flag + copied skill.
  Idempotent and fail-open. Prints status of every location.
#>
[CmdletBinding()] param()
$ErrorActionPreference = 'Continue'
$BEGIN = '<!-- BEGIN hyeok-gov -->'
$END   = '<!-- END hyeok-gov -->'
$Home_ = $env:USERPROFILE

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
    $pattern = '(?s)\r?\n?' + [regex]::Escape($BEGIN) + '.*?' + [regex]::Escape($END) + '\r?\n?'
    $c = [regex]::Replace($c, $pattern, '')
    if ([string]::IsNullOrWhiteSpace($c)) { Remove-Item $path -Force; Info "removed $path (was only governance)" }
    else { Write-NoBom $path $c; Info "stripped governance block from $path" }
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
        Info "${tool}: removed defaultMode pin (reverts to built-in default)"
      }
    } catch { Info "${tool}: config.json unreadable, left as-is" }
  }
}

# Codex: governance may live in either the override or the base global file.
Restore-Or-Strip (Join-Path $Home_ '.codex\AGENTS.override.md')
Restore-Or-Strip (Join-Path $Home_ '.codex\AGENTS.md')
# Legacy locations from earlier installs (harmless if absent).
Restore-Or-Strip (Join-Path $Home_ '.grok\GROK.md')
Restore-Or-Strip (Join-Path $Home_ 'AGENTS.override.md')
Remove-DefaultMode 'caveman'
Remove-DefaultMode 'ponytail'

$flag = Join-Path $Home_ '.claude\.caveman-active'
if (Test-Path $flag) { Remove-Item $flag -Force; Info "removed caveman flag" }
foreach ($s in @('.agents\skills\hyeok-governance\SKILL.md','.agents\skills\typst-korean\SKILL.md','.agents\skills\typst-korean\reference.md')) {
  $p = Join-Path $Home_ $s
  if (Test-Path $p) { Remove-Item $p -Force; Info "removed grok skill file $s" }
}

Info 'Uninstall complete. (Plugin itself: /plugin uninstall hyeok-governance@... ; caveman/ponytail keep their own uninstallers.)'
