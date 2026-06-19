#!/usr/bin/env sh
# hyeok-plugins cross-host governance installer (macOS / Linux / WSL).
#
# Wires caveman + ponytail + typst-korean governance into Claude Code, Codex CLI, Grok CLI.
# Local writes only by default; pass --upstream to also run caveman's official installer.
#
# Guarantees: merge-safe (never clobbers your AGENTS.md / config.json), idempotent
# (sentinel-guarded, re-runnable), fail-open (absent host = skip), NO global env exports
# (no edits to ~/.bashrc/.zshrc/.profile — env pollution across tools is forbidden).
#
# Usage: ./install.sh [--upstream] [--caveman-mode ultra] [--ponytail-mode full]

set -u

BEGIN='<!-- BEGIN hyeok-gov -->'
END='<!-- END hyeok-gov -->'
CAVEMAN_MODE='ultra'
PONYTAIL_MODE='full'
UPSTREAM=0

while [ $# -gt 0 ]; do
  case "$1" in
    --upstream) UPSTREAM=1 ;;
    --caveman-mode) CAVEMAN_MODE="$2"; shift ;;
    --ponytail-mode) PONYTAIL_MODE="$2"; shift ;;
    *) echo "[hyeok] unknown arg: $1" ;;
  esac
  shift
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GOV="$SCRIPT_DIR/plugins/hyeok-governance/GOVERNANCE.md"
SKILL_SRC="$SCRIPT_DIR/plugins/typst-korean/skills/typst-korean/SKILL.md"
[ -f "$GOV" ] || { echo "[hyeok] ERROR: GOVERNANCE.md not found at $GOV — run from repo root."; exit 1; }

info() { echo "[hyeok] $1"; }
warn() { echo "[hyeok] WARN: $1"; }

# read-merge config.json: set ONLY defaultMode, preserve other keys, NO BOM.
set_default_mode() {
  tool="$1"; mode="$2"
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then dir="$XDG_CONFIG_HOME/$tool"; else dir="$HOME/.config/$tool"; fi
  path="$dir/config.json"; mkdir -p "$dir"
  if command -v node >/dev/null 2>&1; then
    node -e 'const fs=require("fs");const p=process.argv[1],m=process.argv[2];let o={};try{o=JSON.parse(fs.readFileSync(p,"utf8"))}catch(e){}o.defaultMode=m;fs.writeFileSync(p,JSON.stringify(o,null,2)+"\n")' "$path" "$mode" \
      && info "$tool defaultMode=$mode ($path)" || warn "$tool config merge failed"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$path" "$mode" <<'PY' && info "$tool defaultMode set" || warn "$tool config merge failed"
import json,sys
p,m=sys.argv[1],sys.argv[2]
try: o=json.load(open(p))
except Exception: o={}
o["defaultMode"]=m
json.dump(o,open(p,"w"),indent=2)
PY
  else
    if [ -f "$path" ]; then warn "no node/python to merge $tool config.json; left as-is"
    else printf '{\n  "defaultMode": "%s"\n}\n' "$mode" > "$path"; info "$tool defaultMode=$mode ($path)"; fi
  fi
}

# sentinel merge into a markdown instruction file: backup once, strip old region, append fresh.
merge_sentinel() {
  path="$1"
  mkdir -p "$(dirname "$path")"
  if [ -f "$path" ]; then
    # Back up only a PRISTINE file (no sentinel yet) so a re-run never captures our own block.
    if [ ! -f "$path.pre-hyeok.bak" ] && ! grep -q "$BEGIN" "$path"; then cp "$path" "$path.pre-hyeok.bak"; fi
    tmp=$(mktemp)
    sed "/$BEGIN/,/$END/d" "$path" > "$tmp"
    printf '%s\n' "$(cat "$tmp")" > "$path"
    rm -f "$tmp"
    printf '\n%s\n%s\n%s\n' "$BEGIN" "$(cat "$GOV")" "$END" >> "$path"
  else
    printf '%s\n%s\n%s\n' "$BEGIN" "$(cat "$GOV")" "$END" > "$path"
  fi
  info "governance merged -> $path"
}

# ---- host detection ----
has_claude=0; has_codex=0; has_grok=0
{ [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; } && has_claude=1
{ [ -d "$HOME/.codex" ]  || command -v codex  >/dev/null 2>&1; } && has_codex=1
# Grok: official xAI Grok Build uses ~/.grok (docs.x.ai); some docs reference ~/.grok-build.
{ [ -d "$HOME/.grok" ] || [ -d "$HOME/.grok-build" ] || command -v grok >/dev/null 2>&1; } && has_grok=1
info "hosts -> claude:$has_claude codex:$has_codex grok:$has_grok"

# ---- intensity pins (no env exports) ----
set_default_mode caveman  "$CAVEMAN_MODE"
set_default_mode ponytail "$PONYTAIL_MODE"

# ---- Claude Code ----
if [ "$has_claude" = 1 ]; then
  mkdir -p "$HOME/.claude"
  printf '%s' "$CAVEMAN_MODE" > "$HOME/.claude/.caveman-active"
  info "caveman flag -> $CAVEMAN_MODE"
  if command -v node >/dev/null 2>&1; then
    if printf '' | node "$SCRIPT_DIR/plugins/hyeok-governance/hooks/inject-governance.js" full 2>/dev/null | grep -q additionalContext; then
      info "Claude hook smoke test OK"
    else warn "Claude hook produced no context (still fail-open)"; fi
  else warn "node not on PATH — Claude governance hook no-ops until node available"; fi
  info "Claude: governance ships via the hyeok-governance plugin (SessionStart + UserPromptSubmit)."
fi

# ---- Codex CLI ----
# Codex reads ~/.codex/AGENTS.override.md IF PRESENT, ELSE ~/.codex/AGENTS.md (override REPLACES
# base). Merge into whichever Codex actually loads, preserving content.
if [ "$has_codex" = 1 ]; then
  if [ -f "$HOME/.codex/AGENTS.override.md" ]; then codex_target="$HOME/.codex/AGENTS.override.md"; else codex_target="$HOME/.codex/AGENTS.md"; fi
  merge_sentinel "$codex_target"
  info "Codex: merged into $codex_target (the file Codex actually loads)."
fi

# ---- Grok CLI ----
# Confirmed mechanism = user skills at ~/.agents/skills/<name>/SKILL.md. Grok's AGENTS.md is
# project-scoped (git-root->cwd), not a home-global file, so we ship governance as a
# self-contained user skill rather than guessing a home GROK.md/AGENTS.md.
if [ "$has_grok" = 1 ]; then
  gov_skill="$HOME/.agents/skills/hyeok-governance/SKILL.md"
  mkdir -p "$(dirname "$gov_skill")"
  { printf -- '---\nname: hyeok-governance\ndescription: 작업 라우팅·우선순위 - caveman(말투)/ponytail(코드)/typst-korean(한글문서) 역할 분배. 코드 작성·수정, PDF·장표·보고서, 또는 역할이 겹칠 때 항상 적용.\n---\n\n'; cat "$GOV"; } > "$gov_skill"
  info "Grok: governance user skill -> $gov_skill"
  if [ -f "$SKILL_SRC" ]; then
    mkdir -p "$HOME/.agents/skills/typst-korean"
    cp "$SKILL_SRC" "$HOME/.agents/skills/typst-korean/SKILL.md"
    [ -f "$(dirname "$SKILL_SRC")/reference.md" ] && cp "$(dirname "$SKILL_SRC")/reference.md" "$HOME/.agents/skills/typst-korean/reference.md"
    info "Grok: typst-korean skill copied to ~/.agents/skills/."
  fi
  info "      xAI Grok Build is Claude-compatible: install the hyeok-governance PLUGIN for"
  info "      always-on SessionStart hook injection (most reliable). Verify with: grok inspect"
fi

# ---- optional upstream remote installer (opt-in) ----
if [ "$UPSTREAM" = 1 ]; then
  info "Running caveman official installer (remote exec)..."
  curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash || warn "caveman upstream installer failed"
  set_default_mode caveman "$CAVEMAN_MODE"   # re-pin after upstream
else
  info "Skipped remote installers (--upstream to enable)."
fi

echo ""
info "=== DONE ==="
info "Optional plugin commands (give you /caveman, /ponytail-review etc.):"
echo "  caveman : curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash"
echo "  ponytail(Claude): /plugin marketplace add DietrichGebert/ponytail ; /plugin install ponytail@ponytail"
echo "  ponytail(Codex):  codex plugin marketplace add DietrichGebert/ponytail  (then /plugins, trust hooks)"
echo "  hyeok(Claude):    /plugin marketplace add hyeok8055/hyeok-plugins ; /plugin install hyeok-governance@hyeok8055-hyeok-plugins"
echo ""
info "Undo anytime: ./uninstall.sh"
