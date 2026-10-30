# diagram-design — source of truth

This plugin packages the **canonical** skill from:

- **Upstream:** https://github.com/cathrynlavery/diagram-design
- **Pinned commit at vendoring:** `b52a33bfeef85d43995193ee52c13b485154b7b4`
- **License:** MIT (see `LICENSE`)

Skill root: `skills/diagram-design/` (`SKILL.md` + `references/` + `assets/`).

Treat upstream as 정본. Do not casually rewrite the skill body.

To refresh:

```bash
git clone --depth 1 https://github.com/cathrynlavery/diagram-design.git /tmp/diagram-design
# replace skills/diagram-design, LICENSE, .claude-plugin/plugin.json, .codex-plugin/plugin.json
# update the pinned commit above
```

## Codex adaptation (2026-10-31)

The local SKILL.md adds a Codex execution note: respect organizer restrictions, use available tools, and distinguish CLI validation from browser inspection. The upstream renderer and templates are unchanged. User language and established styling take precedence over unnecessary setup questions. The upstream license remains in effect.
