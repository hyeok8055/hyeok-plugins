#!/usr/bin/env sh
# hyeok-plugins cross-host governance installer (macOS / Linux / WSL).
#
# Wires caveman + ponytail + typst-korean + insane-search governance into Claude Code, Codex
# CLI, and Grok Build. Local writes only by default. Pass --upstream for opt-in network steps:
# caveman's official installer AND vendoring the insane-search engine (git clone + pip) into
# Codex/Grok so web/data/research search works there.
#
# Guarantees: merge-safe (never clobbers AGENTS.md / config.json), idempotent (sentinel +
# tag-marker), fail-open (absent host/tool = skip), NO global env exports.
#
# Usage: ./install.sh [--upstream] [--caveman-mode ultra] [--ponytail-mode full]

set -u

BEGIN='<!-- BEGIN hyeok-gov -->'
END='<!-- END hyeok-gov -->'
IBEGIN='<!-- BEGIN hyeok-insane-search -->'
IEND='<!-- END hyeok-insane-search -->'
IHBEGIN='<!-- BEGIN hyeok-insane-search-host -->'
IHEND='<!-- END hyeok-insane-search-host -->'
IS_TAG='v0.8.2'
IS_REPO='https://github.com/fivetaku/insane-search'
CAVEMAN_MODE='ultra'; PONYTAIL_MODE='full'; UPSTREAM=0

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

# merge_sentinel <path> <bodyfile> <begin> <end> : backup-once (only when NEITHER hyeok sentinel
# present), strip THIS marker region, append fresh. Coexists with the other hyeok block.
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

# ---- insane-search helpers (fail-open) ----
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

# provision_insane_search <dest> : sets globals LAUNCHER + DEPS_OK; returns 0 if usable.
provision_insane_search() {
  dest="$1"
  py=$(resolve_python) || { warn "no real Python 3 (python3/python); insane-search skipped on this host"; return 1; }
  vendor_insane_search "$dest" "$IS_TAG" || return 1
  if install_engine_deps "$py"; then DEPS_OK=1; else DEPS_OK=0; fi
  LAUNCHER=$(write_launcher "$dest" "$py")
  if ! "$LAUNCHER" --help >/dev/null 2>&1; then warn "engine smoke (--help) failed; not wiring insane-search here"; return 1; fi
  return 0
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

# ---- Claude Code ----
if [ "$has_claude" = 1 ]; then
  mkdir -p "$HOME/.claude"; printf '%s' "$CAVEMAN_MODE" > "$HOME/.claude/.caveman-active"
  info "caveman flag -> $CAVEMAN_MODE"
  if command -v node >/dev/null 2>&1; then
    if printf '' | node "$SCRIPT_DIR/plugins/hyeok-governance/hooks/inject-governance.js" full 2>/dev/null | grep -q additionalContext; then info "Claude hook smoke test OK"; else warn "Claude hook produced no context (fail-open)"; fi
  else warn "node not on PATH — Claude governance hook no-ops until node available"; fi
  info "Claude: governance + insane-search ship via the plugin (dependency auto-install)."
fi

# ---- Codex CLI ----
if [ "$has_codex" = 1 ]; then
  if [ -f "$HOME/.codex/AGENTS.override.md" ]; then codex_target="$HOME/.codex/AGENTS.override.md"; else codex_target="$HOME/.codex/AGENTS.md"; fi
  merge_sentinel "$codex_target" "$GOV" "$BEGIN" "$END"
  info "Codex: governance merged into $codex_target."
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
      if [ "$DEPS_OK" = 1 ]; then info "Codex: insane-search vendored ($isdir); phases 1-2 live."; else info "Codex: insane-search vendored; deps MISSING — phases 1-2 disabled."; fi
    else info "Codex: insane-search not wired (see warning); governance still active."; fi
  else info "Codex: insane-search skipped (--upstream vendors the engine)."; fi
fi

# ---- Grok Build ----
if [ "$has_grok" = 1 ]; then
  gov_skill="$HOME/.agents/skills/hyeok-governance/SKILL.md"; mkdir -p "$(dirname "$gov_skill")"
  { printf -- '---\nname: hyeok-governance\ndescription: Task routing/priority - caveman/ponytail/typst-korean/insane-search. Code work, PDF/doc, web/data/research search, role overlap.\n---\n\n'; cat "$GOV"; } > "$gov_skill"
  info "Grok: governance user skill -> $gov_skill"
  if [ -f "$SKILL_SRC" ]; then
    mkdir -p "$HOME/.agents/skills/typst-korean"
    cp "$SKILL_SRC" "$HOME/.agents/skills/typst-korean/SKILL.md"
    [ -f "$(dirname "$SKILL_SRC")/reference.md" ] && cp "$(dirname "$SKILL_SRC")/reference.md" "$HOME/.agents/skills/typst-korean/reference.md"
    info "Grok: typst-korean skill copied."
  fi
  if [ "$UPSTREAM" = 1 ]; then
    isskill="$HOME/.agents/skills/insane-search"; skillmd="$isskill/SKILL.md"
    if [ -f "$skillmd" ] && [ ! -f "$isskill/.hyeok-vendor" ] && [ ! -f "$skillmd.pre-hyeok.bak" ]; then cp "$skillmd" "$skillmd.pre-hyeok.bak"; warn "existing insane-search skill backed up"; fi
    if provision_insane_search "$isskill" && [ -f "$skillmd" ]; then
      tmp=$(mktemp)
      # replace dead 'python3 -m engine' with the launcher; strip any old host-note region.
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
      if [ "$DEPS_OK" = 1 ]; then info "Grok: insane-search vendored as user skill ($isskill); phases 1-2 live."; else info "Grok: insane-search vendored; deps MISSING — degraded."; fi
    else info "Grok: insane-search not wired (see warning); governance still active."; fi
  else info "Grok: insane-search skipped (--upstream vendors the engine)."; fi
  info "      Grok Build is Claude-compatible: also install the hyeok-governance PLUGIN. Verify: grok inspect"
fi

# ---- optional upstream remote installer (opt-in) ----
if [ "$UPSTREAM" = 1 ]; then
  info "Running caveman official installer (remote exec)..."
  curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash || warn "caveman upstream installer failed"
  set_default_mode caveman "$CAVEMAN_MODE"
else
  info "Skipped remote installers (--upstream enables caveman + insane-search vendoring)."
fi

echo ""
info "=== DONE ==="
info "Optional plugin commands:"
echo "  caveman : curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash"
echo "  ponytail(Claude): /plugin marketplace add DietrichGebert/ponytail ; /plugin install ponytail@ponytail"
echo "  hyeok(Claude):    /plugin marketplace add hyeok8055/hyeok-plugins ; /plugin install hyeok-governance@hyeok8055-hyeok-plugins"
echo "                    (insane-search auto-installs on Claude as a plugin dependency)"
echo ""
info "Undo anytime: ./uninstall.sh"
