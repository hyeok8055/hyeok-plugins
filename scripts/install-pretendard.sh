#!/usr/bin/env sh
# Install optimized Pretendard (4 static OTF weights) for typst-korean.
# macOS -> ~/Library/Fonts
# Linux -> ~/.local/share/fonts/hyeok-pretendard + fc-cache
# Also caches under $CACHE (default: ~/.hyeok/fonts/pretendard)
#
# Usage: ./scripts/install-pretendard.sh [--force]
set -u

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

VER=v1.3.9
BASE="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@${VER}/packages/pretendard/dist/public/static"
WEIGHTS="Regular Medium SemiBold Bold"
MARKER=".hyeok-installed"
CACHE="${HYEOK_FONT_CACHE:-$HOME/.hyeok/fonts/pretendard}"

info() { echo "[hyeok-font] $1"; }
warn() { echo "[hyeok-font] WARN: $1"; }

uname_s=$(uname -s 2>/dev/null || echo unknown)
case "$uname_s" in
  Darwin) DEST="$HOME/Library/Fonts" ;;
  Linux|*) DEST="$HOME/.local/share/fonts/hyeok-pretendard" ;;
esac

mkdir -p "$CACHE" "$DEST"

need_download=0
for w in $WEIGHTS; do
  f="Pretendard-${w}.otf"
  if [ ! -f "$CACHE/$f" ]; then need_download=1; break; fi
done

if [ "$need_download" = 1 ] || [ "$FORCE" = 1 ]; then
  info "Downloading Pretendard ${VER} (4 weights)..."
  for w in $WEIGHTS; do
    f="Pretendard-${w}.otf"
    url="$BASE/$f"
    if ! curl -fsSL -o "$CACHE/$f.partial" "$url"; then
      warn "download failed: $f"; rm -f "$CACHE/$f.partial"; continue
    fi
    mv "$CACHE/$f.partial" "$CACHE/$f"
    info "got $f ($(wc -c < "$CACHE/$f" | tr -d ' ') bytes)"
  done
  printf '%s\n' "$VER" > "$CACHE/$MARKER"
else
  info "cache hit: $CACHE"
fi

copied=0
for w in $WEIGHTS; do
  f="Pretendard-${w}.otf"
  [ -f "$CACHE/$f" ] || continue
  cp -f "$CACHE/$f" "$DEST/$f"
  copied=$((copied + 1))
done
# marker in DEST so uninstall only removes hyeok-owned copies (esp. shared ~/Library/Fonts)
if [ "$copied" -gt 0 ]; then
  printf '%s\n' "$VER" > "$DEST/$MARKER"
fi

# optional repo-local fonts for --font-path (when run from repo)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_FONTS="$SCRIPT_DIR/../plugins/typst-korean/fonts"
if [ -d "$SCRIPT_DIR/../plugins/typst-korean" ]; then
  mkdir -p "$REPO_FONTS"
  for w in $WEIGHTS; do
    f="Pretendard-${w}.otf"
    [ -f "$CACHE/$f" ] && cp -f "$CACHE/$f" "$REPO_FONTS/$f"
  done
  printf '%s\n' "$VER" > "$REPO_FONTS/$MARKER"
  # do not commit binaries by default — keep a README pointer
fi

case "$uname_s" in
  Linux)
    if command -v fc-cache >/dev/null 2>&1; then
      fc-cache -f "$DEST" >/dev/null 2>&1 || true
      info "fc-cache refreshed"
    fi
    ;;
esac

if [ "$copied" -gt 0 ]; then
  info "Installed $copied files -> $DEST"
  if command -v typst >/dev/null 2>&1; then
    if typst fonts 2>/dev/null | grep -qi pretendard; then
      info "typst sees Pretendard"
    else
      info "typst installed but Pretendard not listed yet — try: typst fonts --font-path $DEST"
    fi
  fi
else
  warn "no font files installed"
  exit 1
fi
