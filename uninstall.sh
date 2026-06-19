#!/usr/bin/env sh
# Reverse install.sh: strip governance sentinel blocks, restore pre-install backups,
# remove the caveman/ponytail defaultMode pin, delete the caveman flag + copied skill.
# Idempotent, fail-open.

set -u
BEGIN='<!-- BEGIN hyeok-gov -->'
END='<!-- END hyeok-gov -->'
info() { echo "[hyeok] $1"; }

restore_or_strip() {
  path="$1"
  if [ -f "$path.pre-hyeok.bak" ]; then
    cp "$path.pre-hyeok.bak" "$path"; rm -f "$path.pre-hyeok.bak"
    info "restored $path from backup"
  elif [ -f "$path" ]; then
    tmp=$(mktemp)
    sed "/$BEGIN/,/$END/d" "$path" > "$tmp"
    if [ -s "$tmp" ] && grep -q '[^[:space:]]' "$tmp"; then
      printf '%s\n' "$(cat "$tmp")" > "$path"; info "stripped governance block from $path"
    else
      rm -f "$path"; info "removed $path (was only governance)"
    fi
    rm -f "$tmp"
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

info "Uninstall complete. (Plugin: /plugin uninstall hyeok-governance@... ; caveman/ponytail keep their own uninstallers.)"
