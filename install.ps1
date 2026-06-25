<#
.SYNOPSIS
  hyeok-plugins cross-host governance installer (Windows / PowerShell 5.1+).

  Wires caveman + ponytail + typst-korean + insane-search governance into Claude Code,
  Codex CLI, and Grok Build. Local writes only by default (configs + GOVERNANCE merge +
  typst skill copy).

  Pass -UpstreamInstall to ALSO perform network/opt-in steps: run caveman's official
  installer, and vendor the insane-search engine (git clone fivetaku/insane-search, pip
  install curl_cffi/bs4/pyyaml) into Codex/Grok so web/data/research search works there.

  Guarantees: merge-safe (never clobbers your AGENTS.md / config.json), idempotent
  (re-runnable, sentinel-guarded, tag-marker vendor), fail-open (a missing host/tool is
  skipped, never fatal), NO global environment variables (no setx).

.PARAMETER UpstreamInstall
  Enable opt-in network steps: caveman remote installer + insane-search engine vendoring
  for Codex/Grok. Off by default. A default run touches the network ZERO times.

.PARAMETER CavemanMode  Default caveman intensity pinned via config.json. Default: ultra.
.PARAMETER PonytailMode Default ponytail intensity pinned via config.json. Default: full.
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
$BEGIN  = '<!-- BEGIN hyeok-gov -->'
$END    = '<!-- END hyeok-gov -->'
$IBEGIN = '<!-- BEGIN hyeok-insane-search -->'
$IEND   = '<!-- END hyeok-insane-search -->'
$IHBEGIN = '<!-- BEGIN hyeok-insane-search-host -->'
$IHEND   = '<!-- END hyeok-insane-search-host -->'
$IS_TAG  = 'v0.8.2'
$IS_REPO = 'https://github.com/fivetaku/insane-search'
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
  try {
    $check = (Get-Content -Raw -Path $path | ConvertFrom-Json).defaultMode
    if ($check -ne $mode) { Warn "$tool defaultMode verify mismatch: got '$check'" }
    else { Info "$tool defaultMode=$mode  ($path)" }
  } catch { Warn "$tool config re-read failed" }
}

# Sentinel merge. Takes the BEGIN/END pair so governance and insane-search blocks coexist.
# The pristine backup is taken only when NEITHER hyeok sentinel is present, so a re-run that
# adds the 2nd block never captures the 1st into the backup (keeps uninstall reversal correct).
function Merge-Sentinel($path, $body, $begin, $end) {
  if (-not $begin) { $begin = $BEGIN; $end = $END }
  $block = "$begin`n$body`n$end"
  $content = ''
  if (Test-Path $path) {
    $content = Get-Content -Raw -Encoding UTF8 -Path $path
    $bak = "$path.pre-hyeok.bak"
    if ((-not (Test-Path $bak)) -and ($content -notmatch 'hyeok-gov') -and ($content -notmatch 'hyeok-insane-search')) {
      Copy-Item $path $bak -Force
    }
    $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
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

# ---- insane-search helpers (all fail-open: warn + return, never throw out) ----

# Resolve a REAL Python 3 (reject the Windows MS-Store stub at WindowsApps, rc=49). Abs path or $null.
function Resolve-Python {
  $cands = @(@('python3'), @('python'), @('py','-3'))
  foreach ($c in $cands) {
    try {
      $name = $c[0]
      if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { continue }
      $verArgs = @(); if ($c.Count -gt 1) { $verArgs += $c[1] }; $verArgs += '--version'
      $ver = (& $name @verArgs 2>$null | Out-String).Trim()
      if ($LASTEXITCODE -ne 0 -or $ver -notmatch '^Python 3') { continue }
      $exArgs = @(); if ($c.Count -gt 1) { $exArgs += $c[1] }; $exArgs += @('-c','import sys;print(sys.executable)')
      $abs = (& $name @exArgs 2>$null | Out-String).Trim()
      if ($LASTEXITCODE -ne 0 -or -not $abs) { continue }
      if ($abs -match 'WindowsApps') { continue }
      return $abs
    } catch { continue }
  }
  return $null
}

# Clone+vendor engine to $dest/engine (+ SKILL.md). Idempotent via .hyeok-vendor tag marker.
function Vendor-InsaneSearch($dest, $tag) {
  $marker = Join-Path $dest '.hyeok-vendor'
  $mainpy = Join-Path $dest 'engine\__main__.py'
  if ((Test-Path $mainpy) -and (Test-Path $marker) -and ((Get-Content -Raw $marker).Trim() -eq $tag)) { return $true }
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Warn 'git not found; insane-search not vendored'; return $false }
  $tmp = Join-Path $env:TEMP ('hyeok-is-' + [guid]::NewGuid().ToString('N').Substring(0,8))
  try {
    & git clone --depth 1 --branch $tag --quiet $IS_REPO $tmp
    if ($LASTEXITCODE -ne 0) { Warn "git clone failed (rc=$LASTEXITCODE)"; return $false }
    $srcEngine = Join-Path $tmp 'skills\insane-search\engine'
    $srcSkill  = Join-Path $tmp 'skills\insane-search\SKILL.md'
    if (-not (Test-Path (Join-Path $srcEngine '__main__.py'))) { Warn 'engine/__main__.py missing in clone'; return $false }
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
    $dstEngine = Join-Path $dest 'engine'
    if (Test-Path $dstEngine) { Remove-Item -Recurse -Force $dstEngine }
    Copy-Item -Recurse -Force $srcEngine $dstEngine
    if (Test-Path $srcSkill) { Copy-Item -Force $srcSkill (Join-Path $dest 'SKILL.md') }
    if (-not (Test-Path (Join-Path $dstEngine '__main__.py'))) { Warn 'vendor copy failed'; return $false }
    Write-NoBom $marker $tag
    return $true
  } catch { Warn "vendor failed: $($_.Exception.Message)"; return $false }
  finally { if (Test-Path $tmp) { try { Remove-Item -Recurse -Force $tmp } catch {} } }
}

# Install engine deps into the resolved interpreter (no -U; --only-binary fails fast). Returns $true if importable.
function Install-EngineDeps($py) {
  try { & $py -c 'import curl_cffi,bs4,yaml' 2>$null; if ($LASTEXITCODE -eq 0) { return $true } } catch {}
  try {
    & $py -m pip install --only-binary=:all: 'curl_cffi>=0.11' beautifulsoup4 pyyaml -q
    if ($LASTEXITCODE -ne 0) { Warn "pip install failed (rc=$LASTEXITCODE); phases 1-2 disabled"; }
  } catch { Warn "pip errored: $($_.Exception.Message)" }
  try { & $py -m pip install yt-dlp -q 2>$null } catch {}
  try { & $py -c 'import curl_cffi,bs4,yaml' 2>$null; return ($LASTEXITCODE -eq 0) } catch { return $false }
}

# Write run-engine.cmd (CRLF) + run-engine.sh (LF), interpreter baked in. Returns the .cmd path (Windows).
function Write-Launcher($dir, $py) {
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $cmd = "@echo off`r`ncd /d `"%~dp0`"`r`n`"$py`" -m engine %*`r`n"
  [System.IO.File]::WriteAllText((Join-Path $dir 'run-engine.cmd'), $cmd, (New-Object System.Text.UTF8Encoding($false)))
  $sh = "#!/usr/bin/env sh`ncd `"`$(dirname `"`$0`")`" || exit 1`nexec `"$py`" -m engine `"`$@`"`n"
  [System.IO.File]::WriteAllText((Join-Path $dir 'run-engine.sh'), $sh, (New-Object System.Text.UTF8Encoding($false)))
  Note (Join-Path $dir 'run-engine.cmd')
  return (Join-Path $dir 'run-engine.cmd')
}

function Test-EngineSmoke($launcher) {
  try { & $launcher --help 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) } catch { return $false }
}

# Vendor + deps + launcher + smoke. Returns @{ok;launcher;deps} ; ok=$false if engine unusable.
function Provision-InsaneSearch($dest) {
  $py = Resolve-Python
  if (-not $py) { Warn 'no real Python 3 found (python3/python/py -3); insane-search skipped on this host'; return @{ ok=$false } }
  if (-not (Vendor-InsaneSearch $dest $IS_TAG)) { return @{ ok=$false } }
  $deps = Install-EngineDeps $py
  $launcher = Write-Launcher $dest $py
  if (-not (Test-EngineSmoke $launcher)) { Warn 'engine smoke (--help) failed; not wiring insane-search here'; return @{ ok=$false } }
  return @{ ok=$true; launcher=$launcher; deps=$deps }
}

# ---- locate canonical governance body ----
$GovPath = Join-Path $PSScriptRoot 'plugins\hyeok-governance\GOVERNANCE.md'
if (-not (Test-Path $GovPath)) { throw "GOVERNANCE.md not found at $GovPath — run from the repo root." }
$Gov = Get-Content -Raw -Encoding UTF8 -Path $GovPath
$SkillSrc = Join-Path $PSScriptRoot 'plugins\typst-korean\skills\typst-korean\SKILL.md'

# ---- host detection ----
function Have($name, $dir) {
  if (Test-Path (Join-Path $Home_ $dir)) { return $true }
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}
$hasClaude = Have 'claude' '.claude'
$hasCodex  = Have 'codex'  '.codex'
$hasGrok   = (Have 'grok' '.grok') -or (Test-Path (Join-Path $Home_ '.grok-build'))
Info ("hosts detected -> claude:{0} codex:{1} grok:{2}" -f $hasClaude,$hasCodex,$hasGrok)

# ---- intensity pins ----
Set-DefaultMode 'caveman'  $CavemanMode
Set-DefaultMode 'ponytail' $PonytailMode

# ---- Claude Code ----
if ($hasClaude) {
  $flag = Join-Path $Home_ '.claude\.caveman-active'
  try { Write-NoBom $flag $CavemanMode; Note $flag; Info "caveman flag -> $CavemanMode" } catch { Warn 'flag write skipped' }
  $node = Get-Command node -ErrorAction SilentlyContinue
  if ($node) {
    $hook = Join-Path $PSScriptRoot 'plugins\hyeok-governance\hooks\inject-governance.js'
    try {
      $out = '' | & node $hook full 2>$null
      if ($out -match 'additionalContext') { Info 'Claude hook smoke test OK' } else { Warn 'Claude hook produced no context (still fail-open)' }
    } catch { Warn 'Claude hook smoke test errored (fail-open)' }
  } else { Warn 'node not on PATH — Claude governance hook no-ops until node available' }
  Info 'Claude: governance + insane-search ship via the plugin (dependency auto-install).'
}

# ---- Codex CLI ----
if ($hasCodex) {
  $codexOverride = Join-Path $Home_ '.codex\AGENTS.override.md'
  $codexTarget = if (Test-Path $codexOverride) { $codexOverride } else { Join-Path $Home_ '.codex\AGENTS.md' }
  Merge-Sentinel $codexTarget $Gov $BEGIN $END
  Info "Codex: governance merged into $codexTarget (content preserved)."

  if ($UpstreamInstall) {
    $isDir = Join-Path $Home_ '.codex\tools\insane-search'
    $p = Provision-InsaneSearch $isDir
    if ($p.ok) {
      $main = Join-Path $isDir 'engine\__main__.py'
      $lines = @(
        '## insane-search (web/data/research retrieval — enforced by THIS instruction)',
        'Codex has NO skill auto-activation, so this paragraph is the only lever — honor it as a',
        'standing order, same strength as the governance block above.',
        '',
        'For ANY web search / data lookup / research, and ALWAYS when a fetch returns 402/403/blocked/',
        'CAPTCHA/WAF or targets X, Reddit, YouTube, GitHub, Naver, Coupang, LinkedIn, Medium, Substack,',
        'Stack Overflow, Mastodon, Threads, Hacker News: route through insane-search instead of giving',
        'up on a blocked plain fetch. Use it by default, do NOT ask.',
        '',
        'HOW TO RUN (use the launcher; it fixes cwd, shell, and interpreter):',
        ('  "' + $p.launcher + '" "<URL>" [--selector "<CSS>"] [--device auto|desktop|mobile] [--trace] [--json]'),
        'Add --no-playwright on this host (the browser phase is not available here).',
        'Exit 0 = ok, 1 = all attempts failed (read the trace), 2 = bad args.',
        'Do NOT, on a 403/402/blocked, fall back to a plain fetch/curl — invoke the engine.',
        '',
        ('AVAILABILITY: if "' + $main + '" does not exist, insane-search was NOT vendored — say so and'),
        'use the host best search. Do not pretend the engine ran.',
        '',
        'PHASES: Phase 0 (official APIs) + Phases 1-2 (curl_cffi TLS impersonation) run on Codex.',
        'Phase 3 (headless browser) is NOT available transparently; the engine exits 1 with a',
        '"must_invoke_playwright_mcp = TRUE" summary — treat as browser unavailable, return the best',
        'Phase 0-2 result, do not loop.'
      )
      Merge-Sentinel $codexTarget ($lines -join "`n") $IBEGIN $IEND
      $dmsg = if ($p.deps) { 'phases 1-2 live' } else { 'deps MISSING — phases 1-2 disabled' }
      Info "Codex: insane-search vendored ($isDir); $dmsg."
    } else { Info 'Codex: insane-search not wired (see warning above); governance still active.' }
  } else { Info 'Codex: insane-search skipped (-UpstreamInstall vendors the engine).' }
}

# ---- Grok Build ----
if ($hasGrok) {
  $govFm = "---`nname: hyeok-governance`ndescription: Task routing and priority - caveman (chat style) / ponytail (code policy) / typst-korean (Korean docs) / insane-search (search). Applies on code work, PDF/slide/report work, web/data/research search, or when roles overlap.`n---`n`n"
  $govSkill = Join-Path $Home_ '.agents\skills\hyeok-governance\SKILL.md'
  Write-NoBom $govSkill ($govFm + $Gov); Note $govSkill
  if (Test-Path $SkillSrc) {
    Write-NoBom (Join-Path $Home_ '.agents\skills\typst-korean\SKILL.md') (Get-Content -Raw -Encoding UTF8 -Path $SkillSrc); Note (Join-Path $Home_ '.agents\skills\typst-korean\SKILL.md')
    $refSrc = Join-Path (Split-Path $SkillSrc) 'reference.md'
    if (Test-Path $refSrc) { Write-NoBom (Join-Path $Home_ '.agents\skills\typst-korean\reference.md') (Get-Content -Raw -Encoding UTF8 -Path $refSrc) }
  }
  Info 'Grok: governance + typst-korean installed as user skills (~/.agents/skills/).'

  if ($UpstreamInstall) {
    $isSkill = Join-Path $Home_ '.agents\skills\insane-search'
    $skillMd = Join-Path $isSkill 'SKILL.md'
    # Foreign-dir guard: an existing skill with no marker is user-owned -> back up before overwrite.
    if ((Test-Path $skillMd) -and (-not (Test-Path (Join-Path $isSkill '.hyeok-vendor'))) -and (-not (Test-Path "$skillMd.pre-hyeok.bak"))) {
      Copy-Item $skillMd "$skillMd.pre-hyeok.bak" -Force; Warn 'existing insane-search skill backed up to SKILL.md.pre-hyeok.bak'
    }
    $p = Provision-InsaneSearch $isSkill
    if ($p.ok -and (Test-Path $skillMd)) {
      $body = Get-Content -Raw -Encoding UTF8 -Path $skillMd
      $body = [regex]::Replace($body, [regex]::Escape('python3 -m engine'), { param($m) '"' + $p.launcher + '" ' })
      $hpat = '(?s)' + [regex]::Escape($IHBEGIN) + '.*?' + [regex]::Escape($IHEND) + '\r?\n?'
      $body = [regex]::Replace($body, $hpat, '')
      $hostNote = @(
        $IHBEGIN,
        'HOST NOTE (Grok Build) — READ FIRST, overrides the shell examples below.',
        'Invoke the engine ONLY via this launcher (sets cwd + the correct Python for you):',
        ('  "' + $p.launcher + '" "<URL>" [--selector "<CSS>"] [--device auto|desktop|mobile] [--trace] [--json]'),
        'IGNORE every literal `python3 -m engine`, `/tmp/...`, and `2>/dev/null` below — POSIX/Claude',
        'examples that fail here. Phases 0-2 (official APIs + curl_cffi TLS impersonation) work fully.',
        'Phase 3 uses Playwright via MCP: the engine only SIGNALS must_invoke_playwright_mcp=TRUE; if',
        'Grok Playwright tool names differ, Phase 3 degrades to the best Phase 0-2 result (do not loop).',
        $IHEND
      ) -join "`n"
      Write-NoBom $skillMd ($hostNote + "`n`n" + $body)
      $dmsg = if ($p.deps) { 'phases 1-2 live' } else { 'deps MISSING — degraded' }
      Info "Grok: insane-search vendored as user skill ($isSkill); $dmsg."
    } elseif ($p.ok) { Info 'Grok: engine vendored but SKILL.md absent; skill not patched.' }
    else { Info 'Grok: insane-search not wired (see warning); governance still active.' }
  } else { Info 'Grok: insane-search skipped (-UpstreamInstall vendors the engine).' }

  Info '      Grok Build is Claude-compatible: install the hyeok-governance PLUGIN for hook'
  Info '      injection too. Verify everything loaded with: grok inspect'
}

# ---- optional upstream remote installers (opt-in) ----
if ($UpstreamInstall) {
  Info 'Running caveman official installer (remote exec)...'
  try { irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex }
  catch { Warn "caveman upstream installer failed: $($_.Exception.Message)" }
  Set-DefaultMode 'caveman' $CavemanMode
} else {
  Info 'Skipped remote installers (-UpstreamInstall enables caveman + insane-search vendoring).'
}

# ---- summary ----
Write-Host ''
Info '=== DONE. Touched: ==='
$Touched | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
Write-Host ''
Info 'Optional plugin commands:'
Write-Host '  caveman : irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex'
Write-Host '  ponytail (Claude): /plugin marketplace add DietrichGebert/ponytail ; /plugin install ponytail@ponytail'
Write-Host '  hyeok    (Claude): /plugin marketplace add hyeok8055/hyeok-plugins ; /plugin install hyeok-governance@hyeok8055-hyeok-plugins'
Write-Host '             (insane-search auto-installs on Claude as a plugin dependency)'
Write-Host ''
Info 'Undo anytime: .\uninstall.ps1'
