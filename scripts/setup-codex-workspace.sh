#!/bin/sh
# Project-only Codex CLI setup. Requires only POSIX shell utilities.
# Usage: sh /path/to/hyeok-plugins/scripts/setup-codex-workspace.sh
#        [--workspace /existing/project] [--fallback-file NAME] [--check]
# No network, CLI installation, home/config writes, or exam actions.
# Resources: https://learn.chatgpt.com/docs/build-skills
#            https://learn.chatgpt.com/docs/agent-configuration/agents-md
set -eu
info() { printf '[hyeok-workspace] %s\n' "$*"; }
die() { info "ERROR: $*" >&2; exit 1; }
warn() { info "WARNING: $*" >&2; }
WORKSPACE=$(pwd -L)
CHECK=0
FALLBACK_FILE=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --workspace) [ "$#" -ge 2 ] || die '--workspace needs an absolute directory'; WORKSPACE=$2; shift ;;
    --fallback-file) [ "$#" -ge 2 ] && [ -n "$2" ] || die '--fallback-file needs the existing active fallback filename'; FALLBACK_FILE=$2; shift ;;
    --check) CHECK=1 ;;
    --help|-h) printf '%s\n' 'Usage: sh setup-codex-workspace.sh [--workspace /existing/project] [--fallback-file NAME] [--check]' 'Default: current directory. --check performs read-only preflight.' '--fallback-file: existing first non-empty filename from the effective project_doc_fallback_filenames, used only when standard AGENTS files are empty or absent. Verify the active filename before running; no configuration is changed.'; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
  shift
done
plain_path() (
  p=$1
  case "$p" in /*) : ;; *) die "Absolute path required: $p" ;; esac
  case "$p" in *'
'*|*"$(printf '\r')"*|*/../*|*/./*|*/..|*/.) die "Ambiguous path: $p" ;; esac
  while [ "$p" != / ]; do
    [ ! -L "$p" ] || die "Symlink path refused: $p"
    p=${p%/*}; [ -n "$p" ] || p=/
  done
)
plain_tree() (
  plain_path "$1"
  [ ! -e "$1" ] || [ -d "$1" ] || die "Expected directory: $1"
  [ -d "$1" ] || exit 0
  special=$(find "$1" ! -type d ! -type f -print)
  [ -z "$special" ] || die "Symlink or special file refused: $1"
  invalid=$(find "$1" -exec sh -c 'for p do case "$p" in *"
"*|*"$(printf "\r")"*) printf invalid ;; esac; done' sh {} +)
  [ -z "$invalid" ] || die "Line break in filename: $1"
)
directory() { plain_path "$1"; [ -d "$1" ] || mkdir -p "$1"; }
plain_path "$WORKSPACE"
[ -d "$WORKSPACE" ] || die "Workspace must already exist: $WORKSPACE"
WORKSPACE=$(CDPATH= cd "$WORKSPACE" && pwd -P)
[ "$WORKSPACE" != / ] || die 'The filesystem root is not a workspace'
script=$0
while [ "${script#./}" != "$script" ]; do script=${script#./}; done
case "$script" in /*) : ;; *) script=$(pwd -P)/$script ;; esac
# Resolve the script directory, but refuse source aliases before resolving it.
script_dir=${script%/*}
# A normal invocation using ./scripts/... is allowed; inspect each source tree below.
[ ! -L "$script" ] || die 'Run the original script, not a symlink'
REPO=$(CDPATH= cd "$script_dir/.." && pwd -P)
plain_path "$script_dir" # rejects aliased directories and dot path segments
SKILLS='hyeok-governance typst-korean diagram-design archify lieflat-charts juhyeoknizer'
ROOT=$WORKSPACE/.agents/skills
STATE=$WORKSPACE/.hyeok/workspace-setup
plain_tree "$STATE"
plain_path "$WORKSPACE/.hyeok/backups"
plain_path "$ROOT"
for d in "$WORKSPACE/.agents" "$ROOT" "$WORKSPACE/.hyeok" "$WORKSPACE/.hyeok/backups"; do
  [ ! -e "$d" ] || [ -d "$d" ] || die "Expected directory: $d"
done
for f in "$STATE/owner" "$STATE/manifest"; do
  [ ! -e "$f" ] || [ -f "$f" ] || die "Expected state file: $f"
done
# Standard repository discovery stops at the nearest .git directory or worktree file.
# Without a repository, only the workspace participates in project discovery.
PROJECT_ROOT=$WORKSPACE
ancestor=$WORKSPACE
while :; do
  if [ -e "$ancestor/.git" ]; then PROJECT_ROOT=$ancestor; break; fi
  [ "$ancestor" != / ] || break
  ancestor=${ancestor%/*}; [ -n "$ancestor" ] || ancestor=/
done
# Only detect declarations, without parsing/printing effective configuration.
# CLI/profile/cloud overrides cannot be inferred by this standalone script.
FALLBACK_DECLARED=0
fallback_config() {
  if [ -f "$1" ] && grep -Eq "^[[:space:]]*['\"]?project_doc_fallback_filenames['\"]?[[:space:]]*=" "$1"; then
    FALLBACK_DECLARED=1
  fi
}
fallback_config "${CODEX_HOME:-${HOME:-}/.codex}/config.toml"
fallback_config /etc/codex/config.toml
ancestor=$WORKSPACE
while :; do
  fallback_config "$ancestor/.codex/config.toml"
  if [ "$ancestor" != "$WORKSPACE" ]; then
    for name in $SKILLS humanize-korean humanize humanize-redo; do
      for skill_root in "$ancestor/.agents/skills" "$ancestor/.codex/skills"; do
        [ ! -f "$skill_root/$name/SKILL.md" ] || die "Duplicate/legacy parent repository skill: $skill_root/$name. Resolve discovery overlap before setup; no files changed."
      done
    done
  fi
  [ "$ancestor" != "$PROJECT_ROOT" ] || break
  ancestor=${ancestor%/*}; [ -n "$ancestor" ] || ancestor=/
done
for candidate in "$WORKSPACE/AGENTS.override.md" "$WORKSPACE/AGENTS.md"; do
  plain_path "$candidate"
  [ ! -e "$candidate" ] || [ -f "$candidate" ] || die "Expected file: $candidate"
done
nonempty() { [ -f "$1" ] && grep -q '[^[:space:]]' "$1"; }
AGENTS=$WORKSPACE/AGENTS.md
if nonempty "$WORKSPACE/AGENTS.override.md"; then
  AGENTS=$WORKSPACE/AGENTS.override.md
  info 'Using existing AGENTS.override.md because it takes precedence over AGENTS.md.'
fi
if nonempty "$AGENTS"; then
  [ -z "$FALLBACK_FILE" ] || die '--fallback-file would be hidden by a non-empty standard AGENTS file; no files changed'
elif [ -n "$FALLBACK_FILE" ]; then
  case "$FALLBACK_FILE" in
    .|..|*/*|*'\'*|*'
'*|*"$(printf '\r')"*|AGENTS.md|AGENTS.override.md) die '--fallback-file must name an existing non-empty fallback in the workspace' ;;
  esac
  AGENTS=$WORKSPACE/$FALLBACK_FILE
  plain_path "$AGENTS"
  nonempty "$AGENTS" || die '--fallback-file must name an existing non-empty fallback in the workspace'
  info "Using explicitly selected active fallback: $FALLBACK_FILE"
elif [ "$FALLBACK_DECLARED" = 1 ]; then
  die 'A project_doc_fallback_filenames declaration may affect instruction discovery. Verify effective settings and use --fallback-file NAME for the active fallback; no files changed. If none is active, preserve the task guidance in AGENTS.md first.'
fi
plain_path "$AGENTS"
[ ! -e "$AGENTS" ] || [ -f "$AGENTS" ] || die "Expected file: $AGENTS"
if [ -f "$AGENTS" ] && [ "$(wc -c < "$AGENTS")" -ge 32000 ]; then
  warn 'Instruction file approaches the default combined 32 KiB project_doc_max_bytes limit; appended governance may be truncated. Verify active guidance, including global/parent files; settings are unchanged.'
fi
BEGIN='<!-- BEGIN hyeok-gov -->'
END='<!-- END hyeok-gov -->'
if [ -f "$AGENTS" ]; then
  awk -v BINMODE=3 -v b="$BEGIN" -v e="$END" '
    { line=$0; sub(/\r$/, "", line)
      if ((index(line,b) && line!=b) || (index(line,e) && line!=e)) bad=1
      if (line==b) { n++; if (inside) bad=1; inside=1 }
      if (line==e) { m++; if (!inside) bad=1; inside=0 }
    }
    END { if (bad || inside || n!=m || n>1) exit 1 }
  ' "$AGENTS" || die 'Malformed or repeated governance markers; no files changed'
fi
if [ -e "$STATE/owner" ]; then
  [ "$(cat "$STATE/owner")" = 'hyeok-workspace-v1' ] || die 'Foreign workspace setup ownership state'
fi
# User roots are inspected only. They are never written or automatically removed.
for global in "${HOME:-}/.agents/skills" "${HOME:-}/.codex/skills" "${CODEX_HOME:-${HOME:-}/.codex}/skills"; do
  if [ -d "$global" ]; then
    canonical=$(CDPATH= cd "$global" && pwd -P)
    [ "$canonical" != "$ROOT" ] || die 'Workspace resolves to a global skill root; choose a project directory'
    for name in $SKILLS humanize-korean humanize humanize-redo; do
      [ ! -e "$global/$name/SKILL.md" ] || die "Global duplicate/legacy skill: $global/$name. Resolve discovery overlap before setup; no files changed."
    done
  fi
done
if [ -n "${HOME:-}" ] && [ -d "$HOME" ]; then
  [ "$WORKSPACE" != "$(CDPATH= cd "$HOME" && pwd -P)" ] || die 'HOME is not a project workspace'
fi
for profile in "${HOME:-}/.codex" "${CODEX_HOME:-${HOME:-}/.codex}"; do
  case "$WORKSPACE/" in "$profile/"*) die 'Workspace must be outside the Codex profile' ;; esac
  if [ -f "$profile/config.toml" ] && grep -q 'hyeok-plugins' "$profile/config.toml"; then
    warn 'A global hyeok plugin configuration exists. Check for duplicate enabled plugins; configuration is unchanged.'
  fi
done
[ ! -f "${HOME:-}/.hyeok/codex-plugins-installed" ] || warn 'Global plugin receipt found; check enabled plugins for duplicate discovery.'
# Validate every copy operation before writing anything.
for name in $SKILLS; do
  src=$REPO/plugins/$name/skills/$name
  dst=$ROOT/$name
  [ -f "$src/SKILL.md" ] || die "Missing source: $src/SKILL.md"
  plain_tree "$src"; plain_tree "$dst"
  case "$dst/" in "$src/"*) die 'Source/destination overlap' ;; esac
  case "$src/" in "$dst/"*) die 'Source/destination overlap' ;; esac
  find "$src" -print | while IFS= read -r entry; do
    rel=${entry#"$src"}; target=$dst$rel
    plain_path "$target"
    if [ -e "$target" ]; then
      if [ -d "$entry" ]; then [ -d "$target" ] || die "Directory/file conflict: $target"
      else [ -f "$target" ] || die "File/directory conflict: $target"; fi
    fi
  done
  [ ! -f "$WORKSPACE/.codex/skills/$name/SKILL.md" ] || die "Duplicate workspace skill in .codex/skills/$name"
done
for name in humanize-korean humanize humanize-redo; do
  [ ! -f "$ROOT/$name/SKILL.md" ] || die "Legacy workspace writing skill: $name. Preserve it outside discovery before setup."
done
if command -v codex >/dev/null 2>&1; then
  if version=$(codex --version 2>/dev/null); then info "Available CLI: $version"
  else warn 'Codex --version failed. CLI and settings are unchanged.'; fi
else warn 'Codex CLI is absent from PATH. No installation or upgrade will be attempted.'; fi
if [ "$CHECK" = 1 ]; then info "Preflight passed for $WORKSPACE (6 skills); no files written."; exit 0; fi

BACKUP=$WORKSPACE/.hyeok/backups/workspace-$(date -u +%Y%m%dT%H%M%S)-$$
# Writes preserve hard-link targets by replacing the directory entry after backup.
put_file() (
  source=$1; target=$2
  [ ! -e "$target" ] || [ -f "$target" ] || die "Expected file: $target"
  [ ! -f "$target" ] || ! cmp -s "$source" "$target" || exit 0
  plain_path "$target"
  if [ -f "$target" ]; then
    saved=$BACKUP/${target#"$WORKSPACE/"}
    directory "${saved%/*}"
    [ ! -e "$saved" ] || die "Backup collision: $saved"
    cp -p "$target" "$saved"
  fi
  directory "${target%/*}"
  # A unique sibling avoids truncating a destination hard link.
  scratch=$target.hyeok-$$
  [ ! -e "$scratch" ] && [ ! -L "$scratch" ] || die "Temporary path collision: $scratch"
  trap 'rm -f "$scratch"' 0
  cp -p "$source" "$scratch"
  mv -f "$scratch" "$target"
)
directory "$STATE"
TMP=$STATE/.pending-$$
(umask 077; mkdir "$TMP") || die 'Temporary state directory collision'
trap 'rm -f "$TMP/agents" "$TMP/block" "$TMP/owner" "$TMP/manifest"; rmdir "$TMP"' 0
printf '%s\n' 'hyeok-workspace-v1' > "$TMP/owner"
printf 'source=%s\n' "$REPO" > "$TMP/manifest"
printf '%s\n' "$BEGIN" \
  'Use .agents/skills/hyeok-governance/SKILL.md to route work through available skills and tools.' \
  'Read its references only when needed. Follow user and repository instructions and organizer rules.' \
  'Use only the provided Codex CLI and permitted capabilities; this setup does not configure models or MCP.' \
  "$END" > "$TMP/block"
if [ -f "$AGENTS" ]; then
  awk -v BINMODE=3 -v b="$BEGIN" -v e="$END" -v block="$TMP/block" '
    function emit() { while ((getline text < block)>0) print text; close(block) }
    { line=$0; sub(/\r$/, "", line)
      if (line==b) { emit(); inside=1; found=1; next }
      if (line==e) { inside=0; next }
      if (!inside) print
    }
    END { if (!found) { if (NR) print ""; emit() } }
  ' "$AGENTS" > "$TMP/agents"
else cp "$TMP/block" "$TMP/agents"; fi
for name in $SKILLS; do
  src=$REPO/plugins/$name/skills/$name; dst=$ROOT/$name
  find "$src" -type d -print | while IFS= read -r entry; do directory "$dst${entry#"$src"}"; done
  find "$src" -type f -print | while IFS= read -r entry; do
    target=$dst${entry#"$src"}
    put_file "$entry" "$target"
    printf '%s\n' "${target#"$WORKSPACE/"}" >> "$TMP/manifest"
  done
done
printf 'managed-block=%s\n' "${AGENTS#"$WORKSPACE/"}" >> "$TMP/manifest"
put_file "$TMP/agents" "$AGENTS"
put_file "$TMP/owner" "$STATE/owner"
put_file "$TMP/manifest" "$STATE/manifest"
info "Installed 6 complete skills in $ROOT. Ownership: $STATE. Skills are detected automatically. Use the provided reload flow; a new CLI session loads project instructions. Do not stop managed processes."
