#!/usr/bin/env sh
# hyeok-plugins cross-host installer (macOS / Linux / WSL).
#
# User-scope install for Claude Code, Codex CLI, and Grok Build:
#   1) skill trees → ~/.claude|~/.codex|~/.grok|~/.agents/skills
#   2) official CLI plugin marketplace + install when host CLI is present
#   3) governance merge (Codex AGENTS.md), caveman/ponytail defaultMode pins
#   4) optional --upstream: caveman remote installer + insane-search engine
#
# Guarantees: merge-safe, idempotent, fail-open, NO global env exports.
#
# Usage: ./install.sh [--upstream] [--skip-cli-plugins]
#                    [--caveman-mode ultra] [--ponytail-mode full]

set -u

BEGIN='<!-- BEGIN hyeok-gov -->'
END='<!-- END hyeok-gov -->'
IBEGIN='<!-- BEGIN hyeok-insane-search -->'
IEND='<!-- END hyeok-insane-search -->'
IHBEGIN='<!-- BEGIN hyeok-insane-search-host -->'
IHEND='<!-- END hyeok-insane-search-host -->'
IS_TAG='v0.8.2'
IS_REPO='https://github.com/fivetaku/insane-search'
MARKER='.hyeok-installed'
MARKET='hyeok-plugins'
CAVEMAN_MODE='ultra'; PONYTAIL_MODE='full'; UPSTREAM=0; SKIP_CLI=0

while [ $# -gt 0 ]; do
  case "$1" in
    --upstream) UPSTREAM=1 ;;
    --skip-cli-plugins) SKIP_CLI=1 ;;
    --caveman-mode) CAVEMAN_MODE="$2"; shift ;;
    --ponytail-mode) PONYTAIL_MODE="$2"; shift ;;
    *) echo "[hyeok] unknown arg: $1" ;;
  esac
  shift
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GOV="$SCRIPT_DIR/plugins/hyeok-governance/GOVERNANCE.md"
TYPST_DIR="$SCRIPT_DIR/plugins/typst-korean/skills/typst-korean"
DIAGRAM_DIR="$SCRIPT_DIR/plugins/diagram-design/skills/diagram-design"
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
    if [ ! -f "$path.pre-hyeok.bak" ] && ! grep -q 'hyeok-gov' "$path" && ! grep -q 'hyeok-insane-search' "$path"; then cp "$path" "$path.pre-hyeok.bak"; fi
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
  Task routing/priority — caveman (chat style), ponytail (code policy),
  typst-korean (Korean Typst docs, explicit only), insane-search (web/data/research),
  diagram-design (editorial HTML+SVG diagrams). Code work, PDF/doc, diagrams, search, role overlap.
---

FM
    cat "$GOV"
  } > "$tmp/SKILL.md"
  install_skill_tree hyeok-governance "$tmp" governance-inlined
  rm -rf "$tmp"
}

# ---- insane-search helpers ----
resolve_python() {
  for cand in python3 python; do
    command -v "$cand" >/dev/null 2>&1 || continue
    v=$("$cand" --version 2>&1) || continue
    case "$v" in Python\ 3*) ;; *) continue ;; esac
    abs=$("$cand" -c 'import sys;print(sys.executable)' 2>/dev/null) || continue
    case "$abs" in *WindowsApps*) continue ;; esac
    [ -n "$abs" ] && { printf '%s' "$abs"; return 0; }
  done
  return 1
}

vendor_insane_search() {
  dest="$1"; tag="$2"
  if [ -f "$dest/engine/__main__.py" ] && [ -f "$dest/.hyeok-vendor" ] && [ "$(cat "$dest/.hyeok-vendor" 2>/dev/null)" = "$tag" ]; then return 0; fi
  command -v git >/dev/null 2>&1 || { warn "git not found; insane-search not vendored"; return 1; }
  tmp=$(mktemp -d)
  if ! git clone --depth 1 --branch "$tag" --quiet "$IS_REPO" "$tmp" 2>/dev/null; then warn "git clone failed"; rm -rf "$tmp"; return 1; fi
  if [ ! -f "$tmp/skills/insane-search/engine/__main__.py" ]; then warn "engine missing in clone"; rm -rf "$tmp"; return 1; fi
  mkdir -p "$dest"; rm -rf "$dest/engine"
  cp -R "$tmp/skills/insane-search/engine" "$dest/engine"
  [ -f "$tmp/skills/insane-search/SKILL.md" ] && cp "$tmp/skills/insane-search/SKILL.md" "$dest/SKILL.md"
  rm -rf "$tmp"
  [ -f "$dest/engine/__main__.py" ] || { warn "vendor copy failed"; return 1; }
  printf '%s' "$tag" > "$dest/.hyeok-vendor"
  return 0
}

install_engine_deps() {
  py="$1"
  "$py" -c 'import curl_cffi,bs4,yaml' 2>/dev/null && return 0
  userflag=""
  em=$("$py" -c 'import sysconfig,os;print(os.path.exists(os.path.join(sysconfig.get_path("stdlib"),"EXTERNALLY-MANAGED")))' 2>/dev/null)
  [ "$em" = "True" ] && userflag="--user"
  "$py" -m pip install --only-binary=:all: "curl_cffi>=0.11" beautifulsoup4 pyyaml -q $userflag 2>/dev/null || warn "pip install failed; phases 1-2 disabled"
  "$py" -m pip install yt-dlp -q $userflag 2>/dev/null || true
  "$py" -c 'import curl_cffi,bs4,yaml' 2>/dev/null && return 0 || return 1
}

write_launcher() {
  dir="$1"; py="$2"; mkdir -p "$dir"
  printf '#!/usr/bin/env sh\ncd "$(dirname "$0")" || exit 1\nexec "%s" -m engine "$@"\n' "$py" > "$dir/run-engine.sh"
  chmod +x "$dir/run-engine.sh"
  printf '@echo off\r\ncd /d "%%~dp0"\r\n"%s" -m engine %%*\r\n' "$py" > "$dir/run-engine.cmd"
  printf '%s' "$dir/run-engine.sh"
}

provision_insane_search() {
  dest="$1"
  py=$(resolve_python) || { warn "no real Python 3; insane-search skipped"; return 1; }
  vendor_insane_search "$dest" "$IS_TAG" || return 1
  if install_engine_deps "$py"; then DEPS_OK=1; else DEPS_OK=0; fi
  LAUNCHER=$(write_launcher "$dest" "$py")
  if ! "$LAUNCHER" --help >/dev/null 2>&1; then warn "engine smoke failed"; return 1; fi
  return 0
}

install_cli_plugins() {
  [ "$SKIP_CLI" = 1 ] && { info "CLI plugin install skipped (--skip-cli-plugins)"; return 0; }

  if [ "$has_claude" = 1 ] && command -v claude >/dev/null 2>&1; then
    if ! claude plugin marketplace add "$SCRIPT_DIR" --scope user >/dev/null 2>&1; then
      claude plugin marketplace add hyeok8055/hyeok-plugins --scope user >/dev/null 2>&1 || true
    fi
    for p in hyeok-governance typst-korean diagram-design; do
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
    for p in hyeok-governance typst-korean diagram-design; do
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
    for rel in plugins/hyeok-governance plugins/typst-korean plugins/diagram-design; do
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
set_default_mode caveman  "$CAVEMAN_MODE"
set_default_mode ponytail "$PONYTAIL_MODE"

# ---- user-global skill trees ----
info "Installing user-global skill trees..."
install_governance_skill
[ -d "$TYPST_DIR" ] && install_skill_tree typst-korean "$TYPST_DIR" || warn "typst-korean skill missing"
[ -d "$DIAGRAM_DIR" ] && install_skill_tree diagram-design "$DIAGRAM_DIR" "upstream:cathrynlavery/diagram-design" || warn "diagram-design skill missing"

# ---- Claude ----
if [ "$has_claude" = 1 ]; then
  mkdir -p "$HOME/.claude"; printf '%s' "$CAVEMAN_MODE" > "$HOME/.claude/.caveman-active"
  info "caveman flag -> $CAVEMAN_MODE"
  if command -v node >/dev/null 2>&1; then
    if printf '' | node "$SCRIPT_DIR/plugins/hyeok-governance/hooks/inject-governance.js" full 2>/dev/null | grep -q additionalContext; then info "Claude hook smoke test OK"; else warn "Claude hook produced no context (fail-open)"; fi
  else warn "node not on PATH — Claude governance hook no-ops until node available"; fi
fi

# ---- Codex ----
if [ "$has_codex" = 1 ]; then
  if [ -f "$HOME/.codex/AGENTS.override.md" ]; then codex_target="$HOME/.codex/AGENTS.override.md"; else codex_target="$HOME/.codex/AGENTS.md"; fi
  merge_sentinel "$codex_target" "$GOV" "$BEGIN" "$END"
  if [ "$UPSTREAM" = 1 ]; then
    isdir="$HOME/.codex/tools/insane-search"
    if provision_insane_search "$isdir"; then
      main="$isdir/engine/__main__.py"
      blk=$(mktemp)
      cat > "$blk" <<EOF
## insane-search (web/data/research retrieval — enforced by THIS instruction)
Codex has NO skill auto-activation, so this paragraph is the only lever — honor it as a
standing order, same strength as the governance block above.

For ANY web search / data lookup / research, and ALWAYS when a fetch returns 402/403/blocked/
CAPTCHA/WAF or targets X, Reddit, YouTube, GitHub, Naver, Coupang, LinkedIn, Medium, Substack,
Stack Overflow, Mastodon, Threads, Hacker News: route through insane-search instead of giving
up on a blocked plain fetch. Use it by default, do NOT ask.

HOW TO RUN (use the launcher; it fixes cwd, shell, and interpreter):
  "$LAUNCHER" "<URL>" [--selector "<CSS>"] [--device auto|desktop|mobile] [--trace] [--json]
Add --no-playwright on this host (the browser phase is not available here).
Exit 0 = ok, 1 = all attempts failed (read the trace), 2 = bad args.
Do NOT, on a 403/402/blocked, fall back to a plain fetch/curl — invoke the engine.

AVAILABILITY: if "$main" does not exist, insane-search was NOT vendored — say so and use the
host best search. Do not pretend the engine ran.

PHASES: Phase 0 (official APIs) + Phases 1-2 (curl_cffi TLS impersonation) run on Codex.
Phase 3 (headless browser) is NOT available transparently; the engine exits 1 with a
"must_invoke_playwright_mcp = TRUE" summary — treat as browser unavailable, return the best
Phase 0-2 result, do not loop.
EOF
      merge_sentinel "$codex_target" "$blk" "$IBEGIN" "$IEND"; rm -f "$blk"
      if [ "$DEPS_OK" = 1 ]; then info "Codex: insane-search vendored ($isdir); phases 1-2 live."; else info "Codex: insane-search vendored; deps MISSING."; fi
    else info "Codex: insane-search not wired; governance still active."; fi
  else info "Codex: insane-search skipped (--upstream vendors the engine)."; fi
fi

# ---- Grok insane-search ----
if [ "$has_grok" = 1 ]; then
  if [ "$UPSTREAM" = 1 ]; then
    isskill="$HOME/.agents/skills/insane-search"; skillmd="$isskill/SKILL.md"
    if [ -f "$skillmd" ] && [ ! -f "$isskill/.hyeok-vendor" ] && [ ! -f "$skillmd.pre-hyeok.bak" ]; then cp "$skillmd" "$skillmd.pre-hyeok.bak"; warn "existing insane-search skill backed up"; fi
    if provision_insane_search "$isskill" && [ -f "$skillmd" ]; then
      tmp=$(mktemp)
      sed "s#python3 -m engine#\"$LAUNCHER\"#g" "$skillmd" | awk -v b="$IHBEGIN" -v e="$IHEND" 'BEGIN{skip=0} $0==b{skip=1} skip==0{print} $0==e{skip=0}' > "$tmp"
      { cat <<EOF
$IHBEGIN
HOST NOTE (Grok Build) — READ FIRST, overrides the shell examples below.
Invoke the engine ONLY via this launcher (sets cwd + the correct Python for you):
  "$LAUNCHER" "<URL>" [--selector "<CSS>"] [--device auto|desktop|mobile] [--trace] [--json]
IGNORE every literal 'python3 -m engine', '/tmp/...', and '2>/dev/null' below — POSIX/Claude
examples that fail here. Phases 0-2 (official APIs + curl_cffi TLS impersonation) work fully.
Phase 3 uses Playwright via MCP: the engine only SIGNALS must_invoke_playwright_mcp=TRUE; if
Grok Playwright tool names differ, Phase 3 degrades to the best Phase 0-2 result (do not loop).
$IHEND

EOF
        cat "$tmp"; } > "$skillmd"
      rm -f "$tmp"
      if [ "$DEPS_OK" = 1 ]; then info "Grok: insane-search vendored ($isskill); phases 1-2 live."; else info "Grok: insane-search vendored; deps MISSING."; fi
    else info "Grok: insane-search not wired."; fi
  else info "Grok: insane-search skipped (--upstream vendors the engine)."; fi
fi

# ---- CLI plugins ----
install_cli_plugins

# ---- optional upstream ----
if [ "$UPSTREAM" = 1 ]; then
  info "Running caveman official installer (remote exec)..."
  curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash || warn "caveman upstream installer failed"
  set_default_mode caveman "$CAVEMAN_MODE"
else
  info "Skipped remote installers (--upstream enables caveman + insane-search vendoring)."
fi

echo ""
info "=== DONE ==="
info "Verify:"
echo "  Claude: claude plugin list ; ls ~/.claude/skills"
echo "  Codex:  codex plugin list  ; ls ~/.agents/skills ~/.codex/skills"
echo "  Grok:   grok plugin list   ; ls ~/.grok/skills ~/.agents/skills"
echo ""
info "Undo anytime: ./uninstall.sh"
