#!/usr/bin/env sh
# hyeok-plugins cross-host installer (macOS / Linux / WSL).
#
# User-scope install for Claude Code, Codex CLI, and Grok Build:
#   1) skill trees → ~/.claude|~/.codex|~/.grok|~/.agents/skills
#   2) official CLI plugin marketplace + install when host CLI is present
#   3) governance merge (Codex AGENTS.md), ponytail defaultMode pin
#
# Guarantees: merge-safe, idempotent, fail-open, NO global env exports.
#
# Usage: ./install.sh [--skip-cli-plugins] [--skip-fonts] [--ponytail-mode full]

set -u

BEGIN='<!-- BEGIN hyeok-gov -->'
END='<!-- END hyeok-gov -->'
MARKER='.hyeok-installed'
MARKET='hyeok-plugins'
PONYTAIL_MODE='full'; SKIP_CLI=0; SKIP_FONTS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-cli-plugins) SKIP_CLI=1 ;;
    --skip-fonts) SKIP_FONTS=1 ;;
    --ponytail-mode) PONYTAIL_MODE="$2"; shift ;;
    --upstream|--caveman-mode)
      echo "[hyeok] WARN: $1 removed (caveman/insane-search no longer shipped); ignoring"
      [ "$1" = "--caveman-mode" ] && shift
      ;;
    *) echo "[hyeok] unknown arg: $1" ;;
  esac
  shift
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GOV="$SCRIPT_DIR/plugins/hyeok-governance/GOVERNANCE.md"
TYPST_DIR="$SCRIPT_DIR/plugins/typst-korean/skills/typst-korean"
DIAGRAM_DIR="$SCRIPT_DIR/plugins/diagram-design/skills/diagram-design"
ARCHIFY_DIR="$SCRIPT_DIR/plugins/archify/skills/archify"
HUMANIZE_DIR="$SCRIPT_DIR/plugins/humanize-korean/skills/humanize-korean"
HUMANIZE_LIGHT_DIR="$SCRIPT_DIR/plugins/humanize-korean/skills/humanize"
HUMANIZE_REDO_DIR="$SCRIPT_DIR/plugins/humanize-korean/skills/humanize-redo"
LIEFLAT_DIR="$SCRIPT_DIR/plugins/lieflat-charts/skills/lieflat-charts"
[ -f "$GOV" ] || { echo "[hyeok] ERROR: GOVERNANCE.md not found at $GOV — run from repo root."; exit 1; }

info() { echo "[hyeok] $1"; }
warn() { echo "[hyeok] WARN: $1"; }

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
open(p,"a").write("\n")
PY
  else
    if [ -f "$path" ]; then warn "no node/python to merge $tool config.json; left as-is"
    else printf '{\n  "defaultMode": "%s"\n}\n' "$mode" > "$path"; info "$tool defaultMode=$mode ($path)"; fi
  fi
}

merge_sentinel() {
  path="$1"; bodyfile="$2"; b="$3"; e="$4"
  mkdir -p "$(dirname "$path")"
  if [ -f "$path" ]; then
    if [ ! -f "$path.pre-hyeok.bak" ] && ! grep -q 'hyeok-gov' "$path"; then cp "$path" "$path.pre-hyeok.bak"; fi
    tmp=$(mktemp)
    awk -v b="$b" -v e="$e" 'BEGIN{skip=0} $0==b{skip=1} skip==0{print} $0==e{skip=0}' "$path" > "$tmp"
    printf '%s\n' "$(cat "$tmp")" > "$path"; rm -f "$tmp"
    { printf '\n%s\n' "$b"; cat "$bodyfile"; printf '%s\n' "$e"; } >> "$path"
  else
    { printf '%s\n' "$b"; cat "$bodyfile"; printf '%s\n' "$e"; } > "$path"
  fi
  info "governance merged -> $path"
}

# Collect skill roots for this machine into $SKILL_ROOTS (newline-separated).
collect_skill_roots() {
  SKILL_ROOTS=""
  add_root() {
    r="$1"
    case "$SKILL_ROOTS" in
      *"$r"*) ;;
      *) SKILL_ROOTS="${SKILL_ROOTS}${r}
" ;;
    esac
  }
  add_root "$HOME/.agents/skills"
  [ "$has_claude" = 1 ] && add_root "$HOME/.claude/skills"
  [ "$has_codex" = 1 ] && { add_root "$HOME/.codex/skills"; add_root "$HOME/.agents/skills"; }
  [ "$has_grok" = 1 ] && { add_root "$HOME/.grok/skills"; add_root "$HOME/.agents/skills"; }
  if [ -z "$(printf '%s' "$SKILL_ROOTS" | tr -d '[:space:]')" ]; then
    add_root "$HOME/.agents/skills"
  fi
}

# Install a skill directory tree into every skill root. Marks with .hyeok-installed.
install_skill_tree() {
  name="$1"; src="$2"; note="${3:-}"
  [ -d "$src" ] || { warn "skill source missing: $src"; return 1; }
  [ -f "$src/SKILL.md" ] || { warn "no SKILL.md in $src"; return 1; }
  # Resolve to absolute path (src may be a temp dir)
  src=$(CDPATH= cd -- "$src" && pwd)
  collect_skill_roots
  printf '%s' "$SKILL_ROOTS" | while IFS= read -r root; do
    [ -n "$root" ] || continue
    dest="$root/$name"
    mkdir -p "$root"
    if [ -d "$dest" ]; then
      if [ -f "$dest/$MARKER" ] || [ ! -f "$dest/SKILL.md" ]; then
        rm -rf "$dest"
      else
        if [ ! -e "$dest.pre-hyeok.bak" ]; then
          mv "$dest" "$dest.pre-hyeok.bak" 2>/dev/null || { cp -R "$dest" "$dest.pre-hyeok.bak"; rm -rf "$dest"; }
          warn "backed up existing skill $dest"
        else
          rm -rf "$dest"
        fi
      fi
    fi
    # Full-directory clone (portable): mkdir dest then tar stream contents
    mkdir -p "$dest"
    (cd "$src" && tar cf - .) | (cd "$dest" && tar xf -)
    {
      printf 'name=%s\nsource=%s\ninstalled=%s\n' "$name" "$src" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
      [ -n "$note" ] && printf 'note=%s\n' "$note"
    } > "$dest/$MARKER"
    [ -f "$dest/SKILL.md" ] || { warn "SKILL.md missing after copy into $dest"; continue; }
    info "skill $name -> $dest"
  done
}

install_governance_skill() {
  tmp=$(mktemp -d)
  {
    cat <<'FM'
---
name: hyeok-governance
description: >
  Task routing/priority — ponytail (code policy), typst-korean (Korean Typst docs, explicit only),
  diagram-design (editorial HTML+SVG), archify (interactive system maps),
  lieflat-charts (numeric HTML charts, PolyForm Noncommercial),
  humanize-korean/im-not-ai (REQUIRED Korean prose humanizer for writing/docs).
---

FM
    cat "$GOV"
  } > "$tmp/SKILL.md"
  install_skill_tree hyeok-governance "$tmp" governance-inlined
  rm -rf "$tmp"
}

install_cli_plugins() {
  [ "$SKIP_CLI" = 1 ] && { info "CLI plugin install skipped (--skip-cli-plugins)"; return 0; }

  if [ "$has_claude" = 1 ] && command -v claude >/dev/null 2>&1; then
    if ! claude plugin marketplace add "$SCRIPT_DIR" --scope user >/dev/null 2>&1; then
      claude plugin marketplace add hyeok8055/hyeok-plugins --scope user >/dev/null 2>&1 || true
    fi
    for p in hyeok-governance typst-korean diagram-design archify humanize-korean lieflat-charts; do
      if claude plugin install "${p}@${MARKET}" -s user >/dev/null 2>&1; then
        info "Claude plugin installed: ${p}@${MARKET} (user)"
      else
        warn "Claude plugin install failed: ${p}@${MARKET} (skills still installed)"
      fi
    done
  elif [ "$has_claude" = 1 ]; then
    info "Claude dir present but claude CLI not on PATH — skills installed."
  fi

  if [ "$has_codex" = 1 ] && command -v codex >/dev/null 2>&1; then
    if ! codex plugin marketplace add "$SCRIPT_DIR" --json >/dev/null 2>&1; then
      codex plugin marketplace add hyeok8055/hyeok-plugins --json >/dev/null 2>&1 || true
    fi
    for p in hyeok-governance typst-korean diagram-design archify humanize-korean lieflat-charts; do
      if codex plugin add "${p}@${MARKET}" --json >/dev/null 2>&1; then
        info "Codex plugin installed: ${p}@${MARKET}"
      elif codex plugin add "$p" --marketplace "$MARKET" --json >/dev/null 2>&1; then
        info "Codex plugin installed: ${p}@${MARKET}"
      else
        warn "Codex plugin add failed: ${p}@${MARKET} (skills still installed)"
      fi
    done
  elif [ "$has_codex" = 1 ]; then
    info "Codex dir present but codex CLI not on PATH — skills + AGENTS.md installed."
  fi

  if [ "$has_grok" = 1 ] && command -v grok >/dev/null 2>&1; then
    if ! grok plugin marketplace add "$SCRIPT_DIR" >/dev/null 2>&1; then
      grok plugin marketplace add hyeok8055/hyeok-plugins >/dev/null 2>&1 || true
    fi
    for rel in plugins/hyeok-governance plugins/typst-korean plugins/diagram-design plugins/archify plugins/humanize-korean plugins/lieflat-charts; do
      src="$SCRIPT_DIR/$rel"
      if grok plugin install "$src" --trust >/dev/null 2>&1; then
        info "Grok plugin installed: $src"
      elif grok plugin install "hyeok8055/hyeok-plugins#${rel}" --trust >/dev/null 2>&1; then
        info "Grok plugin installed: hyeok8055/hyeok-plugins#${rel}"
      else
        warn "Grok plugin install failed: $src (skills still installed)"
      fi
    done
  elif [ "$has_grok" = 1 ]; then
    info "Grok dir present but grok CLI not on PATH — skills installed."
  fi
}

# ---- host detection ----
has_claude=0; has_codex=0; has_grok=0
{ [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; } && has_claude=1
{ [ -d "$HOME/.codex" ]  || command -v codex  >/dev/null 2>&1; } && has_codex=1
{ [ -d "$HOME/.grok" ] || [ -d "$HOME/.grok-build" ] || command -v grok >/dev/null 2>&1; } && has_grok=1
info "hosts -> claude:$has_claude codex:$has_codex grok:$has_grok"

# ---- intensity pins ----
set_default_mode ponytail "$PONYTAIL_MODE"

# ---- user-global skill trees ----
info "Installing user-global skill trees..."
install_governance_skill
[ -d "$TYPST_DIR" ] && install_skill_tree typst-korean "$TYPST_DIR" || warn "typst-korean skill missing"
[ -d "$DIAGRAM_DIR" ] && install_skill_tree diagram-design "$DIAGRAM_DIR" "upstream:cathrynlavery/diagram-design" || warn "diagram-design skill missing"
[ -d "$ARCHIFY_DIR" ] && install_skill_tree archify "$ARCHIFY_DIR" "upstream:tt-a1i/archify" || warn "archify skill missing"
[ -d "$HUMANIZE_DIR" ] && install_skill_tree humanize-korean "$HUMANIZE_DIR" "upstream:epoko77-ai/im-not-ai" || warn "humanize-korean skill missing"
[ -d "$HUMANIZE_LIGHT_DIR" ] && install_skill_tree humanize "$HUMANIZE_LIGHT_DIR" "upstream:epoko77-ai/im-not-ai" || true
# humanize-redo: vendored but not auto-installed (wrapper only; prefer humanize-korean re-run)
[ -d "$LIEFLAT_DIR" ] && install_skill_tree lieflat-charts "$LIEFLAT_DIR" "upstream:larashero3-dotcom/lieflat-charts" || warn "lieflat-charts skill missing"

# ---- Claude ----
if [ "$has_claude" = 1 ]; then
  if command -v node >/dev/null 2>&1; then
    if printf '' | node "$SCRIPT_DIR/plugins/hyeok-governance/hooks/inject-governance.js" full 2>/dev/null | grep -q additionalContext; then info "Claude hook smoke test OK"; else warn "Claude hook produced no context (fail-open)"; fi
  else warn "node not on PATH — Claude governance hook no-ops until node available"; fi
fi

# ---- Codex ----
if [ "$has_codex" = 1 ]; then
  if [ -f "$HOME/.codex/AGENTS.override.md" ]; then codex_target="$HOME/.codex/AGENTS.override.md"; else codex_target="$HOME/.codex/AGENTS.md"; fi
  merge_sentinel "$codex_target" "$GOV" "$BEGIN" "$END"
fi


# ---- Pretendard fonts (typst-korean default) ----
if [ "$SKIP_FONTS" = 1 ]; then
  info "Pretendard font install skipped (--skip-fonts)"
else
  if [ -f "$SCRIPT_DIR/scripts/install-pretendard.sh" ]; then
    sh "$SCRIPT_DIR/scripts/install-pretendard.sh" || warn "Pretendard font install failed (Typst can still use --font-path later)"
  else
    warn "scripts/install-pretendard.sh missing"
  fi
fi

# ---- CLI plugins ----
install_cli_plugins

echo ""
info "=== DONE ==="
info "Verify:"
echo "  Claude: claude plugin list ; ls ~/.claude/skills"
echo "  Codex:  codex plugin list  ; ls ~/.agents/skills ~/.codex/skills"
echo "  Grok:   grok plugin list   ; ls ~/.grok/skills ~/.agents/skills"
echo ""
info "Undo anytime: ./uninstall.sh"
