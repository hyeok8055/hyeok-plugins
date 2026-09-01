<#
.SYNOPSIS
  hyeok-plugins cross-host installer (Windows / PowerShell 5.1+).

  User-scope install for Claude Code, Codex CLI, and Grok Build:
    1) skill trees → host skill dirs (~/.claude|~/.codex|~/.grok|~/.agents/skills)
    2) official CLI plugin marketplace + install when the host CLI is present
    3) governance merge (Codex AGENTS.md), ponytail defaultMode pin

  Guarantees: merge-safe, idempotent, fail-open, NO global env vars (no setx).


.PARAMETER SkipCliPlugins
  Skip `claude|codex|grok plugin ...` calls; still install skill trees + configs.

.PARAMETER PonytailMode Default: full
#>
[CmdletBinding()]
param(
  [switch]$SkipCliPlugins,
  [switch]$SkipFonts,
  [ValidateSet('off','lite','full','ultra','wenyan-lite','wenyan','wenyan-full','wenyan-ultra')]
  [ValidateSet('off','lite','full','ultra')]
  [string]$PonytailMode = 'full'
)

$ErrorActionPreference = 'Stop'
$BEGIN  = '<!-- BEGIN hyeok-gov -->'
$END    = '<!-- END hyeok-gov -->'
$IS_TAG  = 'v0.8.2'
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
    if ((-not (Test-Path $bak)) -and ($content -notmatch 'hyeok-gov') -and ($content.Length -gt 0)) {
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
    '  Task routing/priority — ponytail (code policy), typst-korean (Korean Typst docs, explicit only),',
    '  diagram-design (editorial HTML+SVG), archify (interactive system maps),',
'  humanize-korean/im-not-ai (REQUIRED Korean prose for writing/docs).',
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
      foreach ($p in @('hyeok-governance','typst-korean','diagram-design','archify','humanize-korean')) {
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

  # Codex CLI: marketplace + plugin add + enable in config.toml
  if ($script:hasCodex -and (Get-Command codex -ErrorAction SilentlyContinue)) {
    # Heal personal marketplace BOM (Codex JSON parser rejects UTF-8 BOM at col 1)
    $personalMp = Join-Path $Home_ '.agents\plugins\marketplace.json'
    if (Test-Path $personalMp) {
      try {
        $bytes = [System.IO.File]::ReadAllBytes($personalMp)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
          $text = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
          Write-NoBom $personalMp $text
          Info 'Codex: stripped UTF-8 BOM from ~/.agents/plugins/marketplace.json'
        }
      } catch { Warn "Codex: could not heal personal marketplace.json: $($_.Exception.Message)" }
    }
    try {
      & codex plugin marketplace add $root --json 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) {
        & codex plugin marketplace add hyeok8055/hyeok-plugins --json 2>&1 | Out-Null
      }
      foreach ($p in @('hyeok-governance','typst-korean','diagram-design','archify','humanize-korean')) {
        $id = "${p}@${MarketName}"
        $added = $false
        try {
          & codex plugin add $id --json 2>&1 | Out-Null
          if ($LASTEXITCODE -eq 0) { $added = $true; Info "Codex plugin installed: $id" }
          else {
            & codex plugin add $p --marketplace $MarketName --json 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $added = $true; Info "Codex plugin installed: $p@$MarketName" }
            else { Warn "Codex plugin add failed: $id (skills still installed)" }
          }
        } catch { Warn "Codex plugin add errored: $id" }
        if ($added) {
          # Ensure enabled = true in ~/.codex/config.toml
          $cfgPath = Join-Path $Home_ '.codex\config.toml'
          try {
            $cfg = if (Test-Path $cfgPath) { Get-Content -Raw -Encoding UTF8 $cfgPath } else { '' }
            if ($null -eq $cfg) { $cfg = '' }
            $section = "[plugins.`"$id`"]"
            if ($cfg -notmatch [regex]::Escape($section)) {
              $cfg = $cfg.TrimEnd() + "`n`n$section`nenabled = true`n"
              Write-NoBom $cfgPath $cfg
              Info "Codex: enabled $id in config.toml"
            } elseif ($cfg -notmatch ([regex]::Escape($section) + '[\s\S]*?enabled\s*=')) {
              # section exists but no enabled line nearby — append enable block anyway if disabled
              if ($cfg -match ([regex]::Escape($section) + '\s*\r?\nenabled\s*=\s*false')) {
                $cfg = [regex]::Replace($cfg, ([regex]::Escape($section) + '\s*\r?\nenabled\s*=\s*false'), "$section`nenabled = true")
                Write-NoBom $cfgPath $cfg
                Info "Codex: flipped $id enabled=true"
              }
            }
          } catch { Warn "Codex: could not enable $id in config.toml" }
        }
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
    foreach ($rel in @('plugins\hyeok-governance','plugins\typst-korean','plugins\diagram-design','plugins\archify','plugins\humanize-korean')) {
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
$ArchifySkillDir = Join-Path $PSScriptRoot 'plugins\archify\skills\archify'
$HumanizeSkillDir = Join-Path $PSScriptRoot 'plugins\humanize-korean\skills\humanize-korean'
$HumanizeLightDir = Join-Path $PSScriptRoot 'plugins\humanize-korean\skills\humanize'
$HumanizeRedoDir = Join-Path $PSScriptRoot 'plugins\humanize-korean\skills\humanize-redo'

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
Set-DefaultMode 'ponytail' $PonytailMode

# ---- user-global skill trees (all hosts) ----
Info 'Installing user-global skill trees...'
Install-GovernanceSkill $Gov
if (Test-Path $TypstSkillDir) { Install-SkillTree 'typst-korean' $TypstSkillDir }
else { Warn "typst-korean skill missing at $TypstSkillDir" }
if (Test-Path $DiagramSkillDir) { Install-SkillTree 'diagram-design' $DiagramSkillDir 'upstream:cathrynlavery/diagram-design' }
else { Warn "diagram-design skill missing at $DiagramSkillDir" }
if (Test-Path $ArchifySkillDir) { Install-SkillTree 'archify' $ArchifySkillDir 'upstream:tt-a1i/archify' }
else { Warn "archify skill missing at $ArchifySkillDir" }
if (Test-Path $HumanizeSkillDir) { Install-SkillTree 'humanize-korean' $HumanizeSkillDir 'upstream:epoko77-ai/im-not-ai' }
else { Warn "humanize-korean skill missing at $HumanizeSkillDir" }
if (Test-Path $HumanizeLightDir) { Install-SkillTree 'humanize' $HumanizeLightDir 'upstream:epoko77-ai/im-not-ai' }
if (Test-Path $HumanizeRedoDir) { Install-SkillTree 'humanize-redo' $HumanizeRedoDir 'upstream:epoko77-ai/im-not-ai' }

# ---- Claude flag + hook smoke ----
if ($script:hasClaude) {
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

}


# ---- Pretendard fonts ----
if ($SkipFonts) { Info 'Pretendard font install skipped (-SkipFonts)' }
else {
  $fontScript = Join-Path $PSScriptRoot 'scripts\install-pretendard.ps1'
  if (Test-Path $fontScript) {
    try { & $fontScript } catch { Warn "Pretendard font install failed: $_" }
  } else { Warn 'scripts/install-pretendard.ps1 missing' }
}

# ---- CLI plugin install (user scope) ----
Install-CliPlugins

# ---- optional upstream ----

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
