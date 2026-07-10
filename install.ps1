<#
.SYNOPSIS
  hyeok-plugins cross-host installer (Windows / PowerShell 5.1+).

  User-scope install for Claude Code, Codex CLI, and Grok Build:
    1) skill trees → host skill dirs (~/.claude|~/.codex|~/.grok|~/.agents/skills)
    2) official CLI plugin marketplace + install when the host CLI is present
    3) governance merge (Codex AGENTS.md), caveman/ponytail defaultMode pins
    4) optional -UpstreamInstall: caveman remote installer + insane-search engine

  Guarantees: merge-safe, idempotent, fail-open, NO global env vars (no setx).

.PARAMETER UpstreamInstall
  Opt-in network steps: caveman installer + insane-search vendoring for Codex/Grok.

.PARAMETER SkipCliPlugins
  Skip `claude|codex|grok plugin ...` calls; still install skill trees + configs.

.PARAMETER CavemanMode  Default: ultra
.PARAMETER PonytailMode Default: full
#>
[CmdletBinding()]
param(
  [switch]$UpstreamInstall,
  [switch]$SkipCliPlugins,
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
$MARKER  = '.hyeok-installed'
$Home_   = $env:USERPROFILE
$Touched = New-Object System.Collections.ArrayList
$MarketName = 'hyeok-plugins'

function Info($m)  { Write-Host "[hyeok] $m" }
function Warn($m)  { Write-Host "[hyeok] WARN: $m" -ForegroundColor Yellow }
function Note($p)  { [void]$Touched.Add($p) }

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
      Warn "$tool config.json unparseable; backed up"
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

function Merge-Sentinel($path, $body, $begin, $end) {
  if (-not $begin) { $begin = $BEGIN; $end = $END }
  if ($null -eq $body) { $body = '' }
  $block = "$begin`n$body`n$end"
  $content = ''
  if (Test-Path $path) {
    $raw = Get-Content -Raw -Encoding UTF8 -Path $path -ErrorAction SilentlyContinue
    if ($null -eq $raw) { $raw = '' }
    $content = [string]$raw
    $bak = "$path.pre-hyeok.bak"
    if ((-not (Test-Path $bak)) -and ($content -notmatch 'hyeok-gov') -and ($content -notmatch 'hyeok-insane-search') -and ($content.Length -gt 0)) {
      Copy-Item $path $bak -Force
    }
    $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
    if ($content.Length -gt 0 -and [regex]::IsMatch($content, $pattern)) {
      $content = [regex]::Replace($content, $pattern, { param($m) $block })
    } elseif ($content.Length -gt 0) {
      $content = $content.TrimEnd() + "`n`n" + $block + "`n"
    } else {
      $content = $block + "`n"
    }
  } else {
    $content = $block + "`n"
  }
  Write-NoBom $path $content
  Note $path
}

# ---- skill install (user-global, multi-host) ----

function Get-SkillTargets {
  # Returns unique absolute skill roots that should receive user skills on this machine.
  $roots = New-Object System.Collections.Generic.List[string]
  $add = {
    param($p)
    if (-not $p) { return }
    if (-not $roots.Contains($p)) { [void]$roots.Add($p) }
  }
  # Shared agents skills dir — Codex USER scope + Grok discovery
  & $add (Join-Path $Home_ '.agents\skills')
  if ($script:hasClaude) { & $add (Join-Path $Home_ '.claude\skills') }
  if ($script:hasCodex)  {
    & $add (Join-Path $Home_ '.codex\skills')
    & $add (Join-Path $Home_ '.agents\skills')
  }
  if ($script:hasGrok) {
    & $add (Join-Path $Home_ '.grok\skills')
    & $add (Join-Path $Home_ '.agents\skills')
  }
  # Always seed agents + claude/codex/grok if any host present, so re-runs stay complete
  return @($roots | Select-Object -Unique)
}

function Copy-Tree($src, $dest) {
  # Prefer robocopy on Windows (handles re-runs / locked files better than Copy-Item).
  if (Get-Command robocopy -ErrorAction SilentlyContinue) {
    # /E copy subdirs incl empty; /IS /IT re-copy same/tweaked files; /PURGE remove extras in dest
    $null = & robocopy $src $dest /E /IS /IT /PURGE /NFL /NDL /NJH /NJS /nc /ns /np
    $rc = $LASTEXITCODE
    # robocopy: 0-7 = success with various copy counts; >=8 = failure
    if ($rc -ge 8) { throw "robocopy failed rc=$rc ($src -> $dest)" }
    return
  }
  if (Test-Path $dest) {
    Get-ChildItem -Force -LiteralPath $dest | ForEach-Object {
      Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
  } else {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
  }
  Get-ChildItem -Force -LiteralPath $src | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dest $_.Name) -Recurse -Force -ErrorAction Stop
  }
}

function Install-SkillTree($name, $srcDir, $extraNote) {
  if (-not (Test-Path -LiteralPath $srcDir)) { Warn "skill source missing: $srcDir"; return }
  $skillMd = Join-Path $srcDir 'SKILL.md'
  if (-not (Test-Path -LiteralPath $skillMd)) { Warn "no SKILL.md in $srcDir"; return }
  $srcDir = (Resolve-Path -LiteralPath $srcDir).Path
  $targets = @(Get-SkillTargets)
  if ($targets.Count -eq 0) {
    $targets = @((Join-Path $Home_ '.agents\skills'))
  }
  foreach ($root in $targets) {
    if ([string]::IsNullOrWhiteSpace($root)) { continue }
    $dest = Join-Path $root $name
    $bak  = "$dest.pre-hyeok.bak"
    try {
      if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Force -Path $root | Out-Null
      }
      # Foreign skill (has SKILL.md, no our marker): backup once before overwrite
      if ((Test-Path -LiteralPath $dest) `
          -and -not (Test-Path -LiteralPath (Join-Path $dest $MARKER)) `
          -and (Test-Path -LiteralPath (Join-Path $dest 'SKILL.md')) `
          -and -not (Test-Path -LiteralPath $bak)) {
        Rename-Item -LiteralPath $dest -NewName (Split-Path $bak -Leaf) -Force
        Warn "backed up existing foreign skill -> $bak"
      }
      if (-not (Test-Path -LiteralPath $dest)) {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
      }
      Copy-Tree $srcDir $dest
      $stamp = "name=$name`nsource=$srcDir`ninstalled=$(Get-Date -Format o)`n"
      if ($extraNote) { $stamp += "note=$extraNote`n" }
      Write-NoBom (Join-Path $dest $MARKER) $stamp
      if (-not (Test-Path -LiteralPath (Join-Path $dest 'SKILL.md'))) {
        throw "SKILL.md missing after copy into $dest"
      }
      Note $dest
      Info "skill $name -> $dest"
    } catch {
      Warn "skill $name install failed at $dest : $($_.Exception.Message)"
    }
  }
}

function Install-GovernanceSkill($govBody) {
  $fm = @(
    '---',
    'name: hyeok-governance',
    'description: >',
    '  Task routing/priority — caveman (chat style), ponytail (code policy),',
    '  typst-korean (Korean Typst docs, explicit only), insane-search (web/data/research),',
    '  diagram-design (editorial HTML+SVG diagrams). Code work, PDF/doc, diagrams, search, role overlap.',
    '---',
    '',
    ''
  ) -join "`n"
  $tmp = Join-Path $env:TEMP ('hyeok-gov-skill-' + [guid]::NewGuid().ToString('N').Substring(0,8))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  try {
    Write-NoBom (Join-Path $tmp 'SKILL.md') ($fm + $govBody)
    Install-SkillTree 'hyeok-governance' $tmp 'governance-inlined'
  } finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  }
}

# ---- insane-search helpers ----

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

function Install-EngineDeps($py) {
  try { & $py -c 'import curl_cffi,bs4,yaml' 2>$null; if ($LASTEXITCODE -eq 0) { return $true } } catch {}
  try {
    & $py -m pip install --only-binary=:all: 'curl_cffi>=0.11' beautifulsoup4 pyyaml -q
    if ($LASTEXITCODE -ne 0) { Warn "pip install failed (rc=$LASTEXITCODE); phases 1-2 disabled" }
  } catch { Warn "pip errored: $($_.Exception.Message)" }
  try { & $py -m pip install yt-dlp -q 2>$null } catch {}
  try { & $py -c 'import curl_cffi,bs4,yaml' 2>$null; return ($LASTEXITCODE -eq 0) } catch { return $false }
}

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

function Provision-InsaneSearch($dest) {
  $py = Resolve-Python
  if (-not $py) { Warn 'no real Python 3; insane-search skipped'; return @{ ok=$false } }
  if (-not (Vendor-InsaneSearch $dest $IS_TAG)) { return @{ ok=$false } }
  $deps = Install-EngineDeps $py
  $launcher = Write-Launcher $dest $py
  if (-not (Test-EngineSmoke $launcher)) { Warn 'engine smoke failed'; return @{ ok=$false } }
  return @{ ok=$true; launcher=$launcher; deps=$deps }
}

# ---- host CLI plugin install (user scope) ----

function Install-CliPlugins {
  if ($SkipCliPlugins) { Info 'CLI plugin install skipped (-SkipCliPlugins)'; return }
  $root = $PSScriptRoot

  # Claude Code: marketplace + user-scope plugin install
  if ($script:hasClaude -and (Get-Command claude -ErrorAction SilentlyContinue)) {
    try {
      & claude plugin marketplace add $root --scope user 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) {
        # Fallback: GitHub remote marketplace
        & claude plugin marketplace add hyeok8055/hyeok-plugins --scope user 2>&1 | Out-Null
      }
      foreach ($p in @('hyeok-governance','typst-korean','diagram-design')) {
        $id = "${p}@${MarketName}"
        try {
          & claude plugin install $id -s user 2>&1 | Out-Null
          if ($LASTEXITCODE -eq 0) { Info "Claude plugin installed: $id (user)" }
          else { Warn "Claude plugin install failed: $id (skills still installed)" }
        } catch { Warn "Claude plugin install errored: $id" }
      }
    } catch { Warn "Claude marketplace/plugin CLI failed: $($_.Exception.Message)" }
  } elseif ($script:hasClaude) {
    Info 'Claude dir present but `claude` CLI not on PATH — skills installed; run plugin install manually if needed.'
  }

  # Codex CLI: marketplace + plugin add
  if ($script:hasCodex -and (Get-Command codex -ErrorAction SilentlyContinue)) {
    try {
      & codex plugin marketplace add $root --json 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) {
        & codex plugin marketplace add hyeok8055/hyeok-plugins --json 2>&1 | Out-Null
      }
      foreach ($p in @('hyeok-governance','typst-korean','diagram-design')) {
        $id = "${p}@${MarketName}"
        try {
          & codex plugin add $id --json 2>&1 | Out-Null
          if ($LASTEXITCODE -eq 0) { Info "Codex plugin installed: $id" }
          else {
            # Alternate marketplace name (flattened from path/url)
            & codex plugin add $p --marketplace $MarketName --json 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Info "Codex plugin installed: $p@$MarketName" }
            else { Warn "Codex plugin add failed: $id (skills still installed)" }
          }
        } catch { Warn "Codex plugin add errored: $id" }
      }
    } catch { Warn "Codex marketplace/plugin CLI failed: $($_.Exception.Message)" }
  } elseif ($script:hasCodex) {
    Info 'Codex dir present but `codex` CLI not on PATH — skills + AGENTS.md installed.'
  }

  # Grok Build: marketplace + trusted plugin install (local paths preferred)
  if ($script:hasGrok -and (Get-Command grok -ErrorAction SilentlyContinue)) {
    # marketplace add may fail if already configured — that is OK
    try { & grok plugin marketplace add $root 2>&1 | Out-Null } catch {}
    try { & grok plugin marketplace add hyeok8055/hyeok-plugins 2>&1 | Out-Null } catch {}
    foreach ($rel in @('plugins\hyeok-governance','plugins\typst-korean','plugins\diagram-design')) {
      $src = Join-Path $root $rel
      try {
        $out = & grok plugin install $src --trust 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $out -match 'already|installed|updated|enabled') {
          Info "Grok plugin installed: $src"
        } else {
          $gh = "hyeok8055/hyeok-plugins#$($rel -replace '\\','/')"
          $out2 = & grok plugin install $gh --trust 2>&1 | Out-String
          if ($LASTEXITCODE -eq 0 -or $out2 -match 'already|installed|updated|enabled') {
            Info "Grok plugin installed: $gh"
          } else { Warn "Grok plugin install failed: $src (skills still installed)" }
        }
      } catch {
        # "already configured/installed" is fine
        if ($_.Exception.Message -match 'already') { Info "Grok plugin already present: $src" }
        else { Warn "Grok plugin install errored: $src — $($_.Exception.Message)" }
      }
    }
  } elseif ($script:hasGrok) {
    Info 'Grok dir present but `grok` CLI not on PATH — skills installed to ~/.grok/skills + ~/.agents/skills.'
  }
}

# ---- locate bodies ----
$GovPath = Join-Path $PSScriptRoot 'plugins\hyeok-governance\GOVERNANCE.md'
if (-not (Test-Path $GovPath)) { throw "GOVERNANCE.md not found at $GovPath — run from the repo root." }
$Gov = Get-Content -Raw -Encoding UTF8 -Path $GovPath
$TypstSkillDir = Join-Path $PSScriptRoot 'plugins\typst-korean\skills\typst-korean'
$DiagramSkillDir = Join-Path $PSScriptRoot 'plugins\diagram-design\skills\diagram-design'

# ---- host detection ----
function Have($name, $dir) {
  if (Test-Path (Join-Path $Home_ $dir)) { return $true }
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}
$script:hasClaude = Have 'claude' '.claude'
$script:hasCodex  = Have 'codex'  '.codex'
$script:hasGrok   = (Have 'grok' '.grok') -or (Test-Path (Join-Path $Home_ '.grok-build'))
Info ("hosts detected -> claude:{0} codex:{1} grok:{2}" -f $script:hasClaude,$script:hasCodex,$script:hasGrok)

# ---- intensity pins ----
Set-DefaultMode 'caveman'  $CavemanMode
Set-DefaultMode 'ponytail' $PonytailMode

# ---- user-global skill trees (all hosts) ----
Info 'Installing user-global skill trees...'
Install-GovernanceSkill $Gov
if (Test-Path $TypstSkillDir) { Install-SkillTree 'typst-korean' $TypstSkillDir }
else { Warn "typst-korean skill missing at $TypstSkillDir" }
if (Test-Path $DiagramSkillDir) { Install-SkillTree 'diagram-design' $DiagramSkillDir 'upstream:cathrynlavery/diagram-design' }
else { Warn "diagram-design skill missing at $DiagramSkillDir" }

# ---- Claude flag + hook smoke ----
if ($script:hasClaude) {
  $flag = Join-Path $Home_ '.claude\.caveman-active'
  try { Write-NoBom $flag $CavemanMode; Note $flag; Info "caveman flag -> $CavemanMode" } catch { Warn 'flag write skipped' }
  $node = Get-Command node -ErrorAction SilentlyContinue
  if ($node) {
    $hook = Join-Path $PSScriptRoot 'plugins\hyeok-governance\hooks\inject-governance.js'
    try {
      $out = '' | & node $hook full 2>$null
      if ($out -match 'additionalContext') { Info 'Claude hook smoke test OK' } else { Warn 'Claude hook produced no context (fail-open)' }
    } catch { Warn 'Claude hook smoke test errored (fail-open)' }
  } else { Warn 'node not on PATH — Claude governance hook no-ops until node available' }
}

# ---- Codex AGENTS merge ----
if ($script:hasCodex) {
  $codexOverride = Join-Path $Home_ '.codex\AGENTS.override.md'
  $codexTarget = if (Test-Path $codexOverride) { $codexOverride } else { Join-Path $Home_ '.codex\AGENTS.md' }
  Merge-Sentinel $codexTarget $Gov $BEGIN $END
  Info "Codex: governance merged into $codexTarget"

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
    } else { Info 'Codex: insane-search not wired (see warning); governance still active.' }
  } else { Info 'Codex: insane-search skipped (-UpstreamInstall vendors the engine).' }
}

# ---- Grok insane-search vendor (skills already installed above) ----
if ($script:hasGrok -and $UpstreamInstall) {
  $isSkill = Join-Path $Home_ '.agents\skills\insane-search'
  $skillMd = Join-Path $isSkill 'SKILL.md'
  if ((Test-Path $skillMd) -and (-not (Test-Path (Join-Path $isSkill '.hyeok-vendor'))) -and (-not (Test-Path "$skillMd.pre-hyeok.bak"))) {
    Copy-Item $skillMd "$skillMd.pre-hyeok.bak" -Force; Warn 'existing insane-search skill backed up'
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
  } elseif ($p.ok) { Info 'Grok: engine vendored but SKILL.md absent.' }
  else { Info 'Grok: insane-search not wired (see warning).' }
} elseif ($script:hasGrok) {
  Info 'Grok: insane-search skipped (-UpstreamInstall vendors the engine).'
}

# ---- CLI plugin install (user scope) ----
Install-CliPlugins

# ---- optional upstream ----
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
Info '=== DONE. Touched (sample): ==='
$Touched | Sort-Object -Unique | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" }
if ($Touched.Count -gt 40) { Write-Host ("  ... +{0} more" -f ($Touched.Count - 40)) }
Write-Host ''
Info 'Verify:'
Write-Host '  Claude: claude plugin list'
Write-Host '  Codex:  codex plugin list   (and ls ~/.agents/skills ~/.codex/skills)'
Write-Host '  Grok:   grok plugin list    (and ls ~/.grok/skills ~/.agents/skills)'
Write-Host ''
Info 'Undo anytime: .\uninstall.ps1'
