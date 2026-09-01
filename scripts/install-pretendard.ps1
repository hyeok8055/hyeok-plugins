<#
.SYNOPSIS
  Install optimized Pretendard (4 static OTF weights) for typst-korean on Windows.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Continue'
$Ver = 'v1.3.9'
$Base = "https://cdn.jsdelivr.net/gh/orioncactus/pretendard@$Ver/packages/pretendard/dist/public/static"
$Weights = @('Regular','Medium','SemiBold','Bold')
$Marker = '.hyeok-installed'
$Cache = if ($env:HYEOK_FONT_CACHE) { $env:HYEOK_FONT_CACHE } else { Join-Path $env:USERPROFILE '.hyeok\fonts\pretendard' }
$Dest = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$RegPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

function Info($m) { Write-Host "[hyeok-font] $m" }
function Warn($m) { Write-Host "[hyeok-font] WARN: $m" }

New-Item -ItemType Directory -Force -Path $Cache | Out-Null
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }

$need = $Force.IsPresent
foreach ($w in $Weights) {
  if (-not (Test-Path (Join-Path $Cache "Pretendard-$w.otf"))) { $need = $true; break }
}

if ($need) {
  Info "Downloading Pretendard $Ver (4 weights)..."
  foreach ($w in $Weights) {
    $f = "Pretendard-$w.otf"
    $out = Join-Path $Cache $f
    $partial = "$out.partial"
    try {
      Invoke-WebRequest -Uri "$Base/$f" -OutFile $partial -UseBasicParsing
      Move-Item -Force $partial $out
      Info ("got {0} ({1} bytes)" -f $f, (Get-Item $out).Length)
    } catch {
      Warn "download failed: $f — $_"
      Remove-Item $partial -ErrorAction SilentlyContinue
    }
  }
  Set-Content -Path (Join-Path $Cache $Marker) -Value $Ver -NoNewline
} else {
  Info "cache hit: $Cache"
}

$copied = 0
foreach ($w in $Weights) {
  $f = "Pretendard-$w.otf"
  $src = Join-Path $Cache $f
  if (-not (Test-Path $src)) { continue }
  $dst = Join-Path $Dest $f
  Copy-Item -Force $src $dst
  $display = "Pretendard $w (TrueType)"
  try {
    New-ItemProperty -Path $RegPath -Name $display -PropertyType String -Value $dst -Force | Out-Null
  } catch {
    Warn "registry register failed for $f — file still copied to $Dest"
  }
  $copied++
}

# repo-local fonts for --font-path
$repoFonts = Join-Path $PSScriptRoot '..\plugins\typst-korean\fonts'
if (Test-Path (Join-Path $PSScriptRoot '..\plugins\typst-korean')) {
  New-Item -ItemType Directory -Force -Path $repoFonts | Out-Null
  foreach ($w in $Weights) {
    $f = "Pretendard-$w.otf"
    $src = Join-Path $Cache $f
    if (Test-Path $src) { Copy-Item -Force $src (Join-Path $repoFonts $f) }
  }
  Set-Content -Path (Join-Path $repoFonts $Marker) -Value $Ver -NoNewline
}

if ($copied -gt 0) {
  Info "Installed $copied files -> $Dest (user fonts)"
} else {
  Warn 'no font files installed'
  exit 1
}
