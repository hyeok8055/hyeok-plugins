<#
.SYNOPSIS
  hyeok-plugins cross-host governance installer (Windows / PowerShell 5.1+).

  Wires caveman + ponytail + typst-korean governance into Claude Code, Codex CLI, and
  Grok CLI. Local writes only by default (configs + GOVERNANCE merge + typst skill copy).
  Pass -UpstreamInstall to also run caveman's official remote installer.

  Guarantees: merge-safe (never clobbers your AGENTS.md / config.json), idempotent
  (re-runnable, sentinel-guarded), fail-open (a missing host is skipped, not fatal),
  NO global environment variables (no setx — env pollution across tools is forbidden).

.PARAMETER UpstreamInstall
  Also run caveman's official `irm install.ps1 | iex`. Off by default (opt-in remote exec).

.PARAMETER CavemanMode
  Default caveman intensity to pin via config.json. Default: ultra (user mandate).

.PARAMETER PonytailMode
  Default ponytail intensity to pin via config.json. Default: full.
#>
[CmdletBinding()]
param(
  [switch]$UpstreamInstall,
  [ValidateSet('off','lite','full','ultra','wenyan-lite','wenyan','wenyan-full','wenyan-ultra')]
  [string]$CavemanMode = 'ultra',
  [ValidateSet('off','lite','full','ultra')]
  [string]$PonytailMode = 'full'
)

$ErrorActionPreference = 'Stop'
$BEGIN = '<!-- BEGIN hyeok-gov -->'
$END   = '<!-- END hyeok-gov -->'
$Home_ = $env:USERPROFILE
$Touched = New-Object System.Collections.ArrayList

function Info($m)  { Write-Host "[hyeok] $m" }
function Warn($m)  { Write-Host "[hyeok] WARN: $m" -ForegroundColor Yellow }
function Note($p)  { [void]$Touched.Add($p) }

# UTF-8 WITHOUT BOM — caveman/ponytail read config.json via Node JSON.parse, which a BOM breaks.
function Write-NoBom($path, $text) {
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Config-Dir($tool) {
  if ($env:XDG_CONFIG_HOME) { return (Join-Path $env:XDG_CONFIG_HOME $tool) }
  $base = $env:APPDATA; if (-not $base) { $base = Join-Path $Home_ 'AppData\Roaming' }
  return (Join-Path $base $tool)
}

# Read-merge: set ONLY defaultMode, preserve every other key. Skips silently on parse error
# of an existing file is NOT acceptable here (would lose the pin) — so on unreadable existing
# file we back it up and start fresh rather than clobber blindly.
function Set-DefaultMode($tool, $mode) {
  $path = Join-Path (Config-Dir $tool) 'config.json'
  $obj = $null
  if (Test-Path $path) {
    try { $obj = Get-Content -Raw -Path $path | ConvertFrom-Json } catch {
      Copy-Item $path "$path.pre-hyeok.bak" -Force
      Warn "$tool config.json unparseable; backed up to config.json.pre-hyeok.bak"
      $obj = $null
    }
  }
  if ($null -eq $obj) { $obj = [PSCustomObject]@{} }
  $obj | Add-Member -NotePropertyName 'defaultMode' -NotePropertyValue $mode -Force
  Write-NoBom $path (($obj | ConvertTo-Json -Depth 20))
  Note $path
  # deterministic verify (re-read from disk)
  try {
    $check = (Get-Content -Raw -Path $path | ConvertFrom-Json).defaultMode
    if ($check -ne $mode) { Warn "$tool defaultMode verify mismatch: got '$check'" }
    else { Info "$tool defaultMode=$mode  ($path)" }
  } catch { Warn "$tool config re-read failed" }
}

# Sentinel merge into a markdown instruction file. Backs up once, replaces region if present
# else appends. Never touches content outside the sentinels.
function Merge-Sentinel($path, $body) {
  $block = "$BEGIN`n$body`n$END"
  $content = ''
  if (Test-Path $path) {
    $content = Get-Content -Raw -Encoding UTF8 -Path $path
    $bak = "$path.pre-hyeok.bak"
    # Back up only a PRISTINE file (no sentinel yet) so a re-run never captures our own block.
    if ((-not (Test-Path $bak)) -and ($content -notmatch [regex]::Escape($BEGIN))) { Copy-Item $path $bak -Force }
    $pattern = '(?s)' + [regex]::Escape($BEGIN) + '.*?' + [regex]::Escape($END)
    if ([regex]::IsMatch($content, $pattern)) {
      $content = [regex]::Replace($content, $pattern, { param($m) $block })
    } else {
      $content = $content.TrimEnd() + "`n`n" + $block + "`n"
    }
  } else {
    $content = $block + "`n"
  }
  Write-NoBom $path $content
  Note $path
}

# ---- locate canonical governance body ----
$GovPath = Join-Path $PSScriptRoot 'plugins\hyeok-governance\GOVERNANCE.md'
if (-not (Test-Path $GovPath)) { throw "GOVERNANCE.md not found at $GovPath — run from the repo root." }
# -Encoding UTF8 is REQUIRED: PowerShell 5.1 Get-Content defaults to ANSI and would corrupt
# the Korean text in these files (and an em-dash) when re-written.
$Gov = Get-Content -Raw -Encoding UTF8 -Path $GovPath
$SkillSrc = Join-Path $PSScriptRoot 'plugins\typst-korean\skills\typst-korean\SKILL.md'

# ---- host detection (each independent; absent = skip, never fatal) ----
function Have($name, $dir) {
  if (Test-Path (Join-Path $Home_ $dir)) { return $true }
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}
$hasClaude = Have 'claude' '.claude'
$hasCodex  = Have 'codex'  '.codex'
# Grok: official xAI Grok Build uses ~/.grok (per docs.x.ai); some builds/3rd-party docs use
# ~/.grok-build. Detect either, plus `grok` on PATH.
$hasGrok   = (Have 'grok' '.grok') -or (Test-Path (Join-Path $Home_ '.grok-build'))
Info ("hosts detected -> claude:{0} codex:{1} grok:{2}" -f $hasClaude,$hasCodex,$hasGrok)

# ---- intensity pins (caveman/ponytail config.json; read-merge; no env vars) ----
Set-DefaultMode 'caveman'  $CavemanMode
Set-DefaultMode 'ponytail' $PonytailMode

# ---- Claude Code ----
if ($hasClaude) {
  $flag = Join-Path $Home_ '.claude\.caveman-active'
  try { Write-NoBom $flag $CavemanMode; Note $flag; Info "caveman flag -> $CavemanMode" } catch { Warn "flag write skipped" }
  # hook smoke test — only meaningful if node present
  $node = Get-Command node -ErrorAction SilentlyContinue
  if ($node) {
    $hook = Join-Path $PSScriptRoot 'plugins\hyeok-governance\hooks\inject-governance.js'
    try {
      $out = '' | & node $hook full 2>$null
      if ($out -match 'additionalContext') { Info 'Claude hook smoke test OK' } else { Warn 'Claude hook produced no context (still fail-open)' }
    } catch { Warn 'Claude hook smoke test errored (fail-open; turn never blocked)' }
  } else { Warn 'node not on PATH — Claude governance hook will no-op until node available' }
  Info 'Claude: governance ships via the hyeok-governance plugin (SessionStart + UserPromptSubmit).'
}

# ---- Codex CLI ----
# Codex reads ~/.codex/AGENTS.override.md IF PRESENT, ELSE ~/.codex/AGENTS.md (override REPLACES
# base, not merges). So we merge into whichever file Codex actually reads, preserving its content.
if ($hasCodex) {
  $codexOverride = Join-Path $Home_ '.codex\AGENTS.override.md'
  $codexTarget = if (Test-Path $codexOverride) { $codexOverride } else { Join-Path $Home_ '.codex\AGENTS.md' }
  Merge-Sentinel $codexTarget $Gov
  Info "Codex: governance merged into $codexTarget (the file Codex actually loads; content preserved)."
}

# ---- Grok CLI ----
# Confirmed grok mechanism = user-level skills at ~/.agents/skills/<name>/SKILL.md (both
# superagent grok-cli and xAI Grok Build). Grok's AGENTS.md is project-scoped (git-root->cwd),
# NOT a home-global file, so we do NOT guess a home AGENTS/GROK.md. Governance ships as a
# self-contained user skill; always-on rules come via the plugin on Grok Build (Claude-compatible).
if ($hasGrok) {
  # Frontmatter kept ASCII on purpose: a Korean literal inside this .ps1 would itself be
  # corrupted by PS 5.1's ANSI script parsing. The Korean governance text comes from $Gov
  # (read with -Encoding UTF8), so the skill body is correct Korean.
  $govFm = "---`nname: hyeok-governance`ndescription: Task routing and priority - caveman (chat style) / ponytail (code policy) / typst-korean (Korean docs). Applies on code work, PDF/slide/report (장표/보고서) work, or when their roles overlap.`n---`n`n"
  $govSkill = Join-Path $Home_ '.agents\skills\hyeok-governance\SKILL.md'
  Write-NoBom $govSkill ($govFm + $Gov); Note $govSkill
  if (Test-Path $SkillSrc) {
    $skillDst = Join-Path $Home_ '.agents\skills\typst-korean\SKILL.md'
    Write-NoBom $skillDst (Get-Content -Raw -Encoding UTF8 -Path $SkillSrc); Note $skillDst
    $refSrc = Join-Path (Split-Path $SkillSrc) 'reference.md'
    if (Test-Path $refSrc) { Write-NoBom (Join-Path $Home_ '.agents\skills\typst-korean\reference.md') (Get-Content -Raw -Encoding UTF8 -Path $refSrc) }
  }
  Info 'Grok: governance + typst-korean installed as user skills (~/.agents/skills/).'
  Info '      xAI Grok Build is Claude-compatible: install the hyeok-governance PLUGIN for'
  Info '      always-on SessionStart hook injection (most reliable). Then verify with: grok inspect'
}

# ---- optional upstream remote installers (opt-in) ----
if ($UpstreamInstall) {
  Info 'Running caveman official installer (remote exec)...'
  try { irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex }
  catch { Warn "caveman upstream installer failed: $($_.Exception.Message)" }
  # re-pin after caveman installer (it may write its own config default)
  Set-DefaultMode 'caveman' $CavemanMode
} else {
  Info 'Skipped remote installers (-UpstreamInstall to enable). Manual one-liners below.'
}

# ---- summary ----
Write-Host ''
Info '=== DONE. Touched: ==='
$Touched | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
Write-Host ''
Info 'Optional plugin commands (give you /caveman, /ponytail-review etc.):'
Write-Host '  caveman : irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex'
Write-Host '  ponytail (Claude): /plugin marketplace add DietrichGebert/ponytail ; /plugin install ponytail@ponytail'
Write-Host '  ponytail (Codex):  codex plugin marketplace add DietrichGebert/ponytail  (then /plugins, trust hooks)'
Write-Host '  hyeok    (Claude): /plugin marketplace add hyeok8055/hyeok-plugins ; /plugin install hyeok-governance@hyeok8055-hyeok-plugins'
Write-Host ''
Info 'Undo anytime: .\uninstall.ps1'
