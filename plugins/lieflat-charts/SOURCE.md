# lieflat-charts — source of truth

This plugin packages the **canonical** skill from:

- **Upstream:** https://github.com/larashero3-dotcom/lieflat-charts
- **Pinned commit at vendoring:** `222a78c1bc81e201959c390690217eda751031ff`
- **License:** PolyForm Noncommercial 1.0.0 (see `LICENSE`) — **not MIT**. Commercial use / paid redistribution of this tree is not granted by upstream.
- **Omitted from vendor:** `docs/` (preview assets ~18MB). Templates + catalogs are enough to generate charts.

Skill root: `skills/lieflat-charts/` (`SKILL.md` + `catalog.md` + `templates/` + …).

Treat upstream as 정본. Refresh by replacing `skills/lieflat-charts` from a fresh clone (skip `docs/`) and updating the pin above.

## Codex adaptation (2026-10-31)

The local SKILL.md adds a Codex execution note: respect organizer restrictions, use available tools, and distinguish CLI validation from browser inspection. The upstream renderer and templates are unchanged. User language and established styling take precedence over unnecessary setup questions. The upstream license remains in effect.

CLI portability review: move `agents/openai.yaml` inside the skill, validate the distributed runtime without omitted upstream preview assets, normalize validator paths, and resolve authored output separately from packaged resources.
