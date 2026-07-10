#!/usr/bin/env sh
# Reverse install.sh: strip governance sentinels, restore backups, remove
# defaultMode pins, remove hyeok-marked user skills, best-effort CLI plugin uninstall.
# Idempotent, fail-open.

set -u
BEGIN='<!-- BEGIN hyeok-gov -->'
END='<!-- END hyeok-gov -->'
IBEGIN='<!-- BEGIN hyeok-insane-search -->'
IEND='<!-- END hyeok-insane-search -->'
MARKER='.hyeok-installed'
MARKET='hyeok-plugins'
info() { echo "[hyeok] $1"; }

restore_or_strip() {
  path="$1"
  if [ -f "$path.pre-hyeok.bak" ]; then
    cp "$path.pre-hyeok.bak" "$path"; rm -f "$path.pre-hyeok.bak"
    info "restored $path from backup"
  elif [ -f "$path" ]; then
    tmp=$(mktemp)
    awk -v b="$BEGIN" -v e="$END" 'BEGIN{s=0} $0==b{s=1} s==0{print} $0==e{s=0}' "$path" \
      | awk -v b="$IBEGIN" -v e="$IEND" 'BEGIN{s=0} $0==b{s=1} s==0{print} $0==e{s=0}' > "$tmp"
    if [ -s "$tmp" ] && grep -q '[^[:space:]]' "$tmp"; then
      printf '%s\n' "$(cat "$tmp")" > "$path"; info "stripped hyeok blocks from $path"
    else
      rm -f "$path"; info "removed $path (was only hyeok blocks)"
    fi
    rm -f "$tmp"
  fi
}

remove_vendor() {
  dir="$1"
  if [ -f "$dir/.hyeok-vendor" ]; then
    rm -rf "$dir" && info "removed vendored dir $dir"
  elif [ -f "$dir/SKILL.md.pre-hyeok.bak" ]; then
    cp "$dir/SKILL.md.pre-hyeok.bak" "$dir/SKILL.md"; rm -f "$dir/SKILL.md.pre-hyeok.bak"
    info "restored user-owned SKILL.md in $dir"
  fi
}

remove_default_mode() {
  tool="$1"
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then path="$XDG_CONFIG_HOME/$tool/config.json"; else path="$HOME/.config/$tool/config.json"; fi
  [ -f "$path" ] || return 0
  if command -v node >/dev/null 2>&1; then
    node -e 'const fs=require("fs");const p=process.argv[1];let o=null;try{o=JSON.parse(fs.readFileSync(p,"utf8"))}catch(e){}if(o){delete o.defaultMode;fs.writeFileSync(p,JSON.stringify(o,null,2)+"\n")}' "$path" \
      && info "$tool: removed defaultMode pin"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$path" <<'PY' && info "$tool: removed defaultMode pin"
import json,sys
p=sys.argv[1]
try: o=json.load(open(p))
except Exception: sys.exit(0)
o.pop("defaultMode",None)
json.dump(o,open(p,"w"),indent=2)
open(p,"a").write("\n")
PY
  else
    info "$tool: no node/python; left config.json as-is"
  fi
}

remove_marked_skill() {
  root="$1"; name="$2"
  dest="$root/$name"
  bak="$dest.pre-hyeok.bak"
  if [ -f "$dest/$MARKER" ]; then
    rm -rf "$dest" && info "removed skill $dest"
    if [ -e "$bak" ]; then mv "$bak" "$dest" 2>/dev/null && info "restored pre-hyeok skill $dest"; fi
  elif [ -e "$bak" ]; then
    rm -rf "$dest" 2>/dev/null
    mv "$bak" "$dest" 2>/dev/null && info "restored pre-hyeok skill from $bak"
  fi
}

restore_or_strip "$HOME/.codex/AGENTS.override.md"
restore_or_strip "$HOME/.codex/AGENTS.md"
restore_or_strip "$HOME/.grok/GROK.md"
restore_or_strip "$HOME/AGENTS.override.md"
remove_default_mode caveman
remove_default_mode ponytail

[ -f "$HOME/.claude/.caveman-active" ] && { rm -f "$HOME/.claude/.caveman-active"; info "removed caveman flag"; }

for root in "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.grok/skills"; do
  [ -d "$root" ] || continue
  for n in hyeok-governance typst-korean diagram-design; do
    remove_marked_skill "$root" "$n"
  done
done

remove_vendor "$HOME/.codex/tools/insane-search"
remove_vendor "$HOME/.agents/skills/insane-search"
info "Note: pip packages (curl_cffi/bs4/pyyaml) are intentionally NOT uninstalled."

# Best-effort CLI plugin uninstall
if command -v claude >/dev/null 2>&1; then
  for p in hyeok-governance typst-korean diagram-design; do
    claude plugin uninstall "${p}@${MARKET}" >/dev/null 2>&1 && info "Claude: uninstalled ${p}@${MARKET}" || true
  done
fi
if command -v codex >/dev/null 2>&1; then
  for p in hyeok-governance typst-korean diagram-design; do
    codex plugin remove "${p}@${MARKET}" >/dev/null 2>&1 || true
    codex plugin remove "$p" --marketplace "$MARKET" >/dev/null 2>&1 || true
    info "Codex: attempted remove $p"
  done
fi
if command -v grok >/dev/null 2>&1; then
  for p in hyeok-governance typst-korean diagram-design; do
    grok plugin uninstall "$p" --confirm >/dev/null 2>&1 && info "Grok: uninstalled $p" || true
  done
fi

info "Uninstall complete. (caveman/ponytail keep their own uninstallers.)"
