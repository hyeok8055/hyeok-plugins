#!/usr/bin/env sh
# Reverse install.sh: strip governance sentinel blocks, restore pre-install backups,
# remove the caveman/ponytail defaultMode pin, delete the caveman flag + copied skill.
# Idempotent, fail-open.

set -u
BEGIN='<!-- BEGIN hyeok-gov -->'
END='<!-- END hyeok-gov -->'
IBEGIN='<!-- BEGIN hyeok-insane-search -->'
IEND='<!-- END hyeok-insane-search -->'
info() { echo "[hyeok] $1"; }

restore_or_strip() {
  path="$1"
  if [ -f "$path.pre-hyeok.bak" ]; then
    cp "$path.pre-hyeok.bak" "$path"; rm -f "$path.pre-hyeok.bak"
    info "restored $path from backup"
  elif [ -f "$path" ]; then
    tmp=$(mktemp)
    # strip BOTH hyeok regions (governance + insane-search) via literal-marker awk
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

# Remove a vendored insane-search dir ONLY if our .hyeok-vendor marker is present.
remove_vendor() {
  dir="$1"
  if [ -f "$dir/.hyeok-vendor" ]; then
    rm -rf "$dir" && info "removed vendored insane-search dir $dir"
  elif [ -f "$dir/SKILL.md.pre-hyeok.bak" ]; then
    cp "$dir/SKILL.md.pre-hyeok.bak" "$dir/SKILL.md"; rm -f "$dir/SKILL.md.pre-hyeok.bak"
    info "restored user-owned insane-search SKILL.md in $dir"
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
PY
  else
    info "$tool: no node/python; left config.json as-is"
  fi
}

# Codex: governance may live in either the override or the base global file.
restore_or_strip "$HOME/.codex/AGENTS.override.md"
restore_or_strip "$HOME/.codex/AGENTS.md"
# Legacy locations from earlier installs (harmless if absent).
restore_or_strip "$HOME/.grok/GROK.md"
restore_or_strip "$HOME/AGENTS.override.md"
remove_default_mode caveman
remove_default_mode ponytail

[ -f "$HOME/.claude/.caveman-active" ] && { rm -f "$HOME/.claude/.caveman-active"; info "removed caveman flag"; }
for s in ".agents/skills/hyeok-governance/SKILL.md" ".agents/skills/typst-korean/SKILL.md" ".agents/skills/typst-korean/reference.md"; do
  [ -f "$HOME/$s" ] && { rm -f "$HOME/$s"; info "removed grok skill file $s"; }
done

# insane-search vendored engines (marker-guarded)
remove_vendor "$HOME/.codex/tools/insane-search"
remove_vendor "$HOME/.agents/skills/insane-search"
info "Note: pip packages (curl_cffi/bs4/pyyaml) are intentionally NOT uninstalled."

info "Uninstall complete. (Plugin: /plugin uninstall hyeok-governance@... ; caveman/ponytail keep their own uninstallers.)"
