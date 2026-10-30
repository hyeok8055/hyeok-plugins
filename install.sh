#!/usr/bin/env sh
# hyeok-plugins: Codex standalone skills installer (macOS / Linux / WSL).
# Copies complete skill trees only to ~/.agents/skills and merges a small
# governance bootstrap into the active Codex AGENTS file. Do not also enable
# this pack through the Codex Plugins UI. No fonts or dependencies are installed;
# hooks, or model/provider/auth/MCP configuration are installed or changed.
# Unrelated destination files are retained. Changed files are backed up under
# ~/.hyeok/backups, outside skill discovery. No directories are deleted/moved.
# Legacy duplicate skills in ~/.codex/skills must be resolved before installing.
# --mode plugins uses the official Codex CLI instead of copying skills or an
# AGENTS bootstrap. It only manages plugin/marketplace settings, with backup.
# Sources: https://learn.chatgpt.com/docs/build-skills
#          https://learn.chatgpt.com/docs/agent-configuration/agents-md
# Usage: ./install.sh [--mode skills|plugins] [--target-home /existing/home]
# Compatibility no-ops: --skip-cli-plugins, --skip-fonts, --ponytail-mode MODE.
# --target-home confines all writes to that home, ignoring CODEX_HOME;
# otherwise CODEX_HOME is respected for the governance bootstrap.

set -eu

info() { printf '[hyeok] %s\n' "$*"; }
die() { printf '[hyeok] ERROR: %s\n' "$*" >&2; exit 1; }

TARGET_HOME=${HOME:?HOME must be set}
ISOLATED=0
MODE=skills
SKIP_CLI=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-home)
      [ "$#" -ge 2 ] && [ -n "$2" ] || die '--target-home needs an existing absolute directory'
      TARGET_HOME=$2; ISOLATED=1; shift ;;
    --mode)
      [ "$#" -ge 2 ] || die '--mode needs skills or plugins'
      case "$2" in skills|plugins) MODE=$2 ;; *) die 'Invalid --mode' ;; esac
      shift ;;
    --skip-cli-plugins) SKIP_CLI=1 ;;
    --skip-fonts) : ;;
    --ponytail-mode)
      [ "$#" -ge 2 ] || die '--ponytail-mode needs a value'
      case "$2" in off|lite|full|ultra|wenyan-lite|wenyan|wenyan-full|wenyan-ultra) : ;; *) die 'Invalid --ponytail-mode' ;; esac
      info '--ponytail-mode is retained for compatibility and no longer writes tool settings.'
      shift ;;
    --help|-h)
      printf '%s\n' 'Usage: ./install.sh [--mode skills|plugins] [--target-home /existing/home]' \
        'Default: Codex standalone skills. Compatibility flags: --skip-cli-plugins --skip-fonts --ponytail-mode full.'
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
  shift
done

assert_plain_path() (
  candidate=$1
  while [ -n "$candidate" ]; do
    [ ! -L "$candidate" ] || die "Refusing a symlink in install path: $candidate"
    [ "$candidate" != / ] || break
    parent=${candidate%/*}
    [ -n "$parent" ] || parent=/
    [ "$parent" != "$candidate" ] || break
    candidate=$parent
    [ "$candidate" != . ] || break
  done
)

assert_plain_tree() (
  assert_plain_path "$1"
  if [ -d "$1" ]; then
    special=$(find "$1" ! -type d ! -type f -print)
    [ -z "$special" ] || die "Refusing symlinks or special files in skill tree: $1"
  fi
)

ensure_directory() {
  assert_plain_path "$1"
  [ ! -e "$1" ] || [ -d "$1" ] || die "Expected a directory, found a file: $1"
  [ -d "$1" ] || mkdir -p "$1"
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
case "$TARGET_HOME" in /*) : ;; *) die 'The target home must be an absolute path' ;; esac
case "$TARGET_HOME" in *'
'*|*"$(printf '\r')"*) die 'The target home must not contain line breaks' ;; esac
assert_plain_path "$TARGET_HOME"
[ -d "$TARGET_HOME" ] || die "The target home must already exist: $TARGET_HOME"
TARGET_HOME=$(CDPATH= cd -- "$TARGET_HOME" && pwd -P)
SKILLS_ROOT=$TARGET_HOME/.agents/skills
if [ "$ISOLATED" = 0 ] && [ -n "${CODEX_HOME:-}" ]; then
  CODEX_DIR=$CODEX_HOME
else
  CODEX_DIR=$TARGET_HOME/.codex
fi
case "$CODEX_DIR" in /*) : ;; *) die 'CODEX_HOME must be an absolute path' ;; esac
case "$CODEX_DIR" in *'
'*|*"$(printf '\r')"*) die 'CODEX_HOME must not contain line breaks' ;; esac
assert_plain_path "$SKILLS_ROOT"
assert_plain_path "$CODEX_DIR"
assert_plain_path "$TARGET_HOME/.hyeok/backups"
AGENTS_PATH=$CODEX_DIR/AGENTS.md
[ ! -f "$CODEX_DIR/AGENTS.override.md" ] || AGENTS_PATH=$CODEX_DIR/AGENTS.override.md
assert_plain_path "$AGENTS_PATH"
BEGIN_TAG='<!-- BEGIN hyeok-gov -->'
END_TAG='<!-- END hyeok-gov -->'
MARKER='.hyeok-installed'
# juhyeoknizer is the single writing skill when present.
SKILLS='hyeok-governance typst-korean diagram-design archify lieflat-charts'
[ ! -f "$SCRIPT_DIR/plugins/juhyeoknizer/skills/juhyeoknizer/SKILL.md" ] || SKILLS="$SKILLS juhyeoknizer"

skill_source() {
  printf '%s/plugins/%s/skills/%s\n' "$SCRIPT_DIR" "$1" "$1"
}

PLUGIN_RECEIPT=$TARGET_HOME/.hyeok/codex-plugins-installed
assert_plain_path "$PLUGIN_RECEIPT"
for legacy_name in humanize-korean humanize humanize-redo; do
  for root in "$SKILLS_ROOT" "$TARGET_HOME/.codex/skills" "$CODEX_DIR/skills"; do
    [ ! -e "$root/$legacy_name/SKILL.md" ] || die "Legacy writing skill at $root/$legacy_name. Preserve or disable it before installing juhyeoknizer as the single writing skill."
  done
done
if [ "$MODE" = plugins ]; then
  [ "$SKIP_CLI" = 0 ] || die '--skip-cli-plugins conflicts with --mode plugins'
  for skill in $SKILLS; do
    for root in "$SKILLS_ROOT" "$TARGET_HOME/.codex/skills" "$CODEX_DIR/skills"; do
      [ ! -e "$root/$skill/SKILL.md" ] || die "Standalone skill at $root/$skill. Uninstall or disable that copy before using plugins mode."
    done
  done
  command -v codex >/dev/null 2>&1 || die 'Codex CLI is required for plugins mode; use skills mode instead'
  assert_plain_path "$CODEX_DIR/config.toml"
  CODEX_HOME="$CODEX_DIR" codex plugin add --help >/dev/null || die 'This Codex does not support plugin add; use skills mode. Codex is never updated.'
  CODEX_HOME="$CODEX_DIR" codex plugin marketplace add --help >/dev/null || die 'This Codex does not support local marketplaces; use skills mode'
fi

# Preflight all inputs before any writes. Older installs are not migrated or
# removed automatically: they may be plugin-managed or contain foreign files.
for skill in $SKILLS; do
  source_dir=$(skill_source "$skill")
  [ -f "$source_dir/SKILL.md" ] || die "Skill source missing: $source_dir/SKILL.md"
  assert_plain_tree "$source_dir"
  destination=$SKILLS_ROOT/$skill
  assert_plain_tree "$destination"
  case "$destination/" in "$source_dir/"*) die "Source and destination overlap: $source_dir -> $destination" ;; esac
  case "$source_dir/" in "$destination/"*) die "Source and destination overlap: $source_dir -> $destination" ;; esac
  for legacy_root in "$TARGET_HOME/.codex/skills" "$CODEX_DIR/skills"; do
    [ ! -e "$legacy_root/$skill/SKILL.md" ] || die "Duplicate skill at $legacy_root/$skill/SKILL.md. Resolve the old installation before using standalone skills mode."
  done
  [ ! -e "$SKILLS_ROOT/$skill.pre-hyeok.bak/SKILL.md" ] || die "An old backup of $skill is in the skill discovery root. Preserve it outside that root before installing."
done

if [ -e "$AGENTS_PATH" ]; then
  [ -f "$AGENTS_PATH" ] || die "Expected an instructions file: $AGENTS_PATH"
  awk -v BINMODE=3 -v b="$BEGIN_TAG" -v e="$END_TAG" '
    { line=$0; sub(/\r$/, "", line)
      if (index(line,b) && line!=b) bad=1
      if (index(line,e) && line!=e) bad=1
      if (line==b) { begins++; if (inside) bad=1; inside=1 }
      if (line==e) { ends++; if (!inside) bad=1; inside=0 }
    }
    END { if (bad || inside || begins!=ends || begins>1) exit 1 }
  ' "$AGENTS_PATH" || die "Malformed or repeated hyeok governance markers in $AGENTS_PATH; left unchanged."
fi

# Reserve a unique backup location outside all skill roots. Create it only when
# overwriting a file; use copy rather than renaming/deleting existing trees.
BACKUP_ROOT=$TARGET_HOME/.hyeok/backups/codex-$(date -u +%Y%m%dT%H%M%S)-$$
backup_file() (
  path=$1; relative=$2
  [ -e "$path" ] || return 0
  [ -f "$path" ] || die "Refusing to replace a directory with a file: $path"
  backup=$BACKUP_ROOT/$relative
  ensure_directory "$(dirname "$backup")"
  [ ! -e "$backup" ] || die "Backup already exists: $backup"
  cp -p "$path" "$backup"
)

if [ "$MODE" = plugins ]; then
  backup_file "$CODEX_DIR/config.toml" 'plugin-config/config.toml'
  ensure_directory "$TARGET_HOME/.hyeok"
  if [ ! -f "$PLUGIN_RECEIPT" ] || ! grep -qx 'installer=codex-plugins-v1' "$PLUGIN_RECEIPT"; then
    backup_file "$PLUGIN_RECEIPT" 'plugin-config/receipt'
    printf 'installer=codex-plugins-v1\n' > "$PLUGIN_RECEIPT"
  fi
  for skill in $SKILLS; do
    if ! grep -qx "plugin=$skill" "$PLUGIN_RECEIPT"; then
      printf 'plugin=%s\n' "$skill" >> "$PLUGIN_RECEIPT"
    fi
  done
  CODEX_HOME="$CODEX_DIR" codex plugin marketplace add "$SCRIPT_DIR" --json >/dev/null || die 'Codex could not add the local marketplace'
  for skill in $SKILLS; do
    CODEX_HOME="$CODEX_DIR" codex plugin add "$skill@hyeok-plugins" --json >/dev/null || die "Codex could not install $skill@hyeok-plugins"
    info "plugin $skill@hyeok-plugins installed"
  done
  info 'Done in plugins mode. No standalone skills or AGENTS bootstrap were copied.'
  [ ! -d "$BACKUP_ROOT" ] || info "Previous file contents -> $BACKUP_ROOT"
  exit 0
fi
[ ! -e "$PLUGIN_RECEIPT" ] || die 'This pack has a plugins-mode receipt. Uninstall that mode before using standalone skills mode.'

copy_skill_tree() (
  skill=$1; source_dir=$2; destination=$SKILLS_ROOT/$skill
  # find includes dotfiles and empty directories. Vendored paths must be plain
  # files/directories; names containing newlines are rejected, not split/copied.
  newline='
'
  bad_names=$(find "$source_dir" -name "*$newline*" -print)
  [ -z "$bad_names" ] || die "Newlines in skill file names are not supported: $source_dir"
  state_dir=$TARGET_HOME/.hyeok/state/skills/$skill
  ensure_directory "$state_dir"
  assert_plain_path "$state_dir/original/SKILL.md"
  if [ -f "$destination/SKILL.md" ] && ! { [ -f "$destination/$MARKER" ] && grep -qx 'installer=codex-skills-v1' "$destination/$MARKER"; } && [ ! -e "$state_dir/original/SKILL.md" ]; then
    ensure_directory "$state_dir/original"
    cp -p "$destination/SKILL.md" "$state_dir/original/SKILL.md"
  fi
  ensure_directory "$destination"
  (cd "$source_dir" && find . -type d -print) | while IFS= read -r relative; do
    ensure_directory "$destination/$relative"
  done
  (cd "$source_dir" && find . -type f -print) | while IFS= read -r relative; do
    source_file=$source_dir/$relative
    dest=$destination/$relative
    assert_plain_path "$dest"
    if [ -f "$dest" ] && cmp -s "$source_file" "$dest"; then continue; fi
    backup_file "$dest" "skills/$skill/$relative"
    cp -p "$source_file" "$dest"
  done
  stamp=$(mktemp "${TMPDIR:-/tmp}/hyeok-stamp.XXXXXX")
  trap 'rm -f "$stamp"' 0
  trap 'exit 1' 1 2 15
  printf 'installer=codex-skills-v1\nname=%s\nsource=%s\n' "$skill" "$source_dir" > "$stamp"
  ensure_directory "$TARGET_HOME/.hyeok/state/skills/$skill"
  state_file=$TARGET_HOME/.hyeok/state/skills/$skill/SKILL.md
  assert_plain_path "$state_file"
  if [ ! -f "$state_file" ] || ! cmp -s "$source_dir/SKILL.md" "$state_file"; then
    backup_file "$state_file" "state/skills/$skill/SKILL.md"
    cp -p "$source_dir/SKILL.md" "$state_file"
  fi
  if [ ! -f "$destination/$MARKER" ] || ! cmp -s "$stamp" "$destination/$MARKER"; then
    backup_file "$destination/$MARKER" "skills/$skill/$MARKER"
    cp "$stamp" "$destination/$MARKER"
  fi
  info "skill $skill -> $destination"
)

info "Codex standalone skills mode -> $SKILLS_ROOT"
info 'Use either standalone skills or the Codex Plugins UI for this pack, not both.'
for skill in $SKILLS; do
  copy_skill_tree "$skill" "$(skill_source "$skill")"
done

# Only the owned sentinel block is replaced. Foreign text remains in place and
# a byte-for-byte backup is made before a changed instructions file is written.
merge_bootstrap() (
  bootstrap=$(mktemp "${TMPDIR:-/tmp}/hyeok-bootstrap.XXXXXX")
  merged=$(mktemp "${TMPDIR:-/tmp}/hyeok-agents.XXXXXX")
  trap 'rm -f "$bootstrap" "$merged"' 0
  trap 'exit 1' 1 2 15
  printf '%s\n' "$BEGIN_TAG" \
    'Use the installed hyeok-governance skill to route Codex work through the appropriate skills and available tools.' \
    "Start with <$SKILLS_ROOT/hyeok-governance/SKILL.md> and read its references only when the task needs them." \
    'Follow the user and repository instructions and the capabilities of the current Codex session.' \
    "$END_TAG" > "$bootstrap"
  if [ -f "$AGENTS_PATH" ]; then
    awk -v BINMODE=3 -v b="$BEGIN_TAG" -v e="$END_TAG" -v body="$bootstrap" '
      function block( line) { while ((getline line < body)>0) print line cr; close(body) }
      NR==1 { if (sub(/\r$/, "", $0)) { cr="\r"; $0=$0 cr } }
      { line=$0; sub(/\r$/, "", line)
        if (line==b) { block(); seen=1; skip=1; next }
        if (line==e) { skip=0; next }
        if (!skip) print
      }
      END { if (!seen) { if (NR>0) print cr; block() } }
    ' "$AGENTS_PATH" > "$merged"
  else
    cp "$bootstrap" "$merged"
  fi
  if [ ! -f "$AGENTS_PATH" ] || ! cmp -s "$merged" "$AGENTS_PATH"; then
    backup_file "$AGENTS_PATH" "instructions/$(basename "$AGENTS_PATH")"
    ensure_directory "$CODEX_DIR"
    cp "$merged" "$AGENTS_PATH"
  fi
)
merge_bootstrap
info "Governance bootstrap -> $AGENTS_PATH"
info 'Done. No CLI, font, or dependency installation was run.'
[ ! -d "$BACKUP_ROOT" ] || info "Previous file contents -> $BACKUP_ROOT"
