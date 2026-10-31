# archify — source of truth

This plugin packages the **canonical** skill from:

- **Upstream:** https://github.com/tt-a1i/archify
- **Pinned commit at vendoring:** `2bfb47132c057195d8dddb3e25ae966dd7c7a72e`
- **License:** MIT (see `LICENSE`)
- **Upstream version:** see `skills/archify/package.json` / skill-release.json

Skill root: `skills/archify/` (`SKILL.md` + renderers + schemas + bin + …).

Install tip upstream also supports: `npx skills add tt-a1i/archify -g`

Treat upstream as 정본. Refresh by replacing `skills/archify` from a fresh clone of `tt-a1i/archify` (`archify/` subfolder) and updating the pin above.

## Codex adaptation (2026-10-31)

The local SKILL.md adds a Codex execution note: respect organizer restrictions, use available tools, and distinguish CLI validation from browser inspection. The upstream renderer and templates are unchanged. User language and established styling take precedence over unnecessary setup questions. The upstream license remains in effect.

CLI portability review: resolve commands from the loaded skill path, keep artifacts in the task workspace, and condition browser evidence on permission and runtime availability.
