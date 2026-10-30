#!/usr/bin/env sh
# Match install.sh: Codex only. Default skills mode removes only marked,
# unmodified SKILL.md entry points and the owned AGENTS bootstrap. Resources
# and backups remain. Restore a recorded foreign SKILL.md when one exists.
# --mode plugins removes only plugins listed in this installer's receipt.
# No marketplace removal or model/provider/auth/permissions/MCP configuration.
# Usage: ./uninstall.sh [--mode skills|plugins] [--target-home /existing/home]
set -eu
info() { printf '[hyeok] %s\n' "$*"; }
die() { printf '[hyeok] ERROR: %s\n' "$*" >&2; exit 1; }
TARGET_HOME=${HOME:?HOME must be set}; ISOLATED=0; MODE=skills
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-home) [ "$#" -ge 2 ] || die '--target-home needs a path'; TARGET_HOME=$2; ISOLATED=1; shift ;;
    --mode) [ "$#" -ge 2 ] || die '--mode needs a value'; MODE=$2; shift ;;
    --help|-h) printf '%s\n' 'Usage: ./uninstall.sh [--mode skills|plugins] [--target-home /existing/home]'; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
  shift
done
case "$MODE" in skills|plugins) : ;; *) die 'Invalid --mode' ;; esac
assert_plain_path() (
  candidate=$1
  while [ -n "$candidate" ]; do
    [ ! -L "$candidate" ] || die "Refusing a symlink: $candidate"
    [ "$candidate" != / ] || break
    parent=${candidate%/*}; [ -n "$parent" ] || parent=/
    [ "$parent" != "$candidate" ] || break
    candidate=$parent; [ "$candidate" != . ] || break
  done
)
case "$TARGET_HOME" in /*) : ;; *) die 'An absolute target home is required' ;; esac
assert_plain_path "$TARGET_HOME"
[ -d "$TARGET_HOME" ] || die 'The target home must already exist'
TARGET_HOME=$(CDPATH= cd -- "$TARGET_HOME" && pwd -P)
if [ "$ISOLATED" = 0 ] && [ -n "${CODEX_HOME:-}" ]; then CODEX_DIR=$CODEX_HOME; else CODEX_DIR=$TARGET_HOME/.codex; fi
case "$CODEX_DIR" in /*) : ;; *) die 'CODEX_HOME must be absolute' ;; esac
assert_plain_path "$CODEX_DIR"
BACKUP_ROOT=$TARGET_HOME/.hyeok/backups/uninstall-$(date -u +%Y%m%dT%H%M%S)-$$
backup_file() (
  dest=$BACKUP_ROOT/$2
  assert_plain_path "$1"; assert_plain_path "$dest"
  mkdir -p "$(dirname "$dest")"
  [ ! -e "$dest" ] || die "Backup already exists: $dest"
  cp -p "$1" "$dest"
)
if [ "$MODE" = plugins ]; then
  receipt=$TARGET_HOME/.hyeok/codex-plugins-installed
  assert_plain_path "$receipt"
  [ -f "$receipt" ] || { info 'No plugins-mode receipt. Nothing removed.'; exit 0; }
  grep -qx 'installer=codex-plugins-v1' "$receipt" || die 'Foreign plugin receipt; left unchanged'
  names=$(sed -n 's/^plugin=//p' "$receipt")
  for name in $names; do
    case "$name" in hyeok-governance|typst-korean|diagram-design|archify|lieflat-charts|juhyeoknizer) : ;; *) die "Unexpected plugin receipt entry: $name" ;; esac
  done
  command -v codex >/dev/null 2>&1 || die 'Codex CLI is required for plugins mode'
  assert_plain_path "$CODEX_DIR/config.toml"
  [ ! -f "$CODEX_DIR/config.toml" ] || backup_file "$CODEX_DIR/config.toml" 'plugin-config/config.toml'
  for name in $names; do
    CODEX_HOME="$CODEX_DIR" codex plugin remove "$name@hyeok-plugins" --json >/dev/null || die "Could not remove $name; receipt retained for retry"
    info "Removed plugin $name@hyeok-plugins"
  done
  backup_file "$receipt" 'plugin-config/receipt'
  rm -f "$receipt"
  exit 0
fi
for name in hyeok-governance typst-korean diagram-design archify lieflat-charts juhyeoknizer; do
  skill_dir=$TARGET_HOME/.agents/skills/$name
  entry=$skill_dir/SKILL.md; marker=$skill_dir/.hyeok-installed
  state=$TARGET_HOME/.hyeok/state/skills/$name
  assert_plain_path "$entry"; assert_plain_path "$marker"; assert_plain_path "$state"
  [ -f "$marker" ] || continue
  grep -qx 'installer=codex-skills-v1' "$marker" || continue
  grep -qx "name=$name" "$marker" || continue
  assert_plain_path "$state/SKILL.md"
  if [ -f "$entry" ] && [ -f "$state/SKILL.md" ] && cmp -s "$entry" "$state/SKILL.md"; then
    backup_file "$entry" "skills/$name/SKILL.md"
    assert_plain_path "$state/original/SKILL.md"
    if [ -f "$state/original/SKILL.md" ]; then cp -p "$state/original/SKILL.md" "$entry"; else rm -f "$entry"; fi
    backup_file "$marker" "skills/$name/.hyeok-installed"
    rm -f "$marker"
    info "Deactivated skill $name; resources and backups retained."
  else
    info "Preserved modified or unrecorded skill: $entry"
  fi
done
for file in AGENTS.override.md AGENTS.md; do
  path=$CODEX_DIR/$file
  assert_plain_path "$path"
  [ -f "$path" ] || continue
  grep -q 'Use the installed hyeok-governance skill' "$path" || continue
  tmp=$(mktemp "${TMPDIR:-/tmp}/hyeok-uninstall.XXXXXX")
  trap 'rm -f "$tmp"' 0
  trap 'exit 1' 1 2 15
  if awk -v BINMODE=3 '
    { line=$0; sub(/\r$/, "", line)
      if (line=="<!-- BEGIN hyeok-gov -->") { begin++; if (inside) bad=1; inside=1; next }
      if (line=="<!-- END hyeok-gov -->") { end++; if (!inside) bad=1; inside=0; next }
      if (inside && index(line,"Use the installed hyeok-governance skill")) owned=1
      if (!inside) print
    }
    END { if (bad || inside || begin!=1 || end!=1 || !owned) exit 1 }
  ' "$path" > "$tmp"; then
    backup_file "$path" "instructions/$file"
    cp "$tmp" "$path"
  else
    info "Preserved unrecognized governance block: $path"
  fi
  rm -f "$tmp"
done
info 'Codex uninstall finished. Foreign files, resource files and backups were retained.'
