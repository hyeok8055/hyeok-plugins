# GOVERNANCE.md — hyeok-plugins Cross-Host Agent Governance

Single source of truth. Loaded/injected on **Claude Code**, **OpenAI Codex CLI**, and **Grok CLI**.
Host-agnostic, persistent. These are standing orders for every session.

## 0. Honest limit (read first)

An LLM cannot be *physically* forced by config alone. Enforcement here is persistent
instruction **injection** every session (and, on Claude Code, a one-line reminder per
turn) — **not** hard tool gates. There are deliberately **no** PreToolUse Edit/Write
blocks (the user chose max-strength-but-zero-side-effects). Treat the rules below as
binding standing orders; a non-compliant turn cannot be hard-blocked, so comply by intent.

## 1. Three layers (orthogonal, by precedence)

**Layer 1 — caveman (output style, ALWAYS ON, top layer).**
Speak to the user in caveman: terse, drop articles/filler/pleasantries/hedging, fragments
OK, full technical accuracy kept. This skins your **conversation only** — narration,
status, reasoning summaries, explanations. Standing default intensity = **ULTRA**
(user-mandated; set via caveman's own `config.json defaultMode`, per-user, reversible).
Downgradable per session with `/caveman lite|full`. Never silently downgrade below the
user's explicit setting.

**Layer 2 — ponytail (code policy).**
Code you write or edit that will be **executed or shipped** obeys the minimal-code ladder:
(1) need it? no → skip (YAGNI); (2) stdlib → use it; (3) native platform feature → use it;
(4) installed dependency → use it; (5) one line → one line; (6) only then the minimum that
works. **Minimal is NOT negligent** — keep validation, error handling, security,
accessibility. Default intensity = **FULL**; ULTRA opt-in (`/ponytail ultra`).

**Layer 3 — typst-korean (Typst document production — EXPLICIT REQUEST ONLY).**
Use typst-korean for PDF/document generation **only when the user explicitly asks for it**
(says "typst", "typst-korean", "in/with Typst", "PDF via typst", or is editing a `**/*.typ`
file). It is **NOT** the default tool for generic "make a PDF / 보고서 / 장표" requests — for
those, do not silently reach for Typst; use the format/pipeline the user implies or ask.
When it IS explicitly invoked: Typst syntax, Korean fonts (default **Pretendard** +
fallbacks), CJK typography (leading 1.5em docs / 1.2em slides, justify, A4 margins),
templates `/new`, `/new-report`, `/new-slide`, `/pdf`, and the mandated clarifying step —
**ask which font and surface the recommendation** (mandated substance, see §3).

## 2. Task router — when each layer fires

- **caveman**: EVERY turn, every host, always. No trigger needed.
- **ponytail**: ANY authoring/editing of executable or shippable code — features, source
  edits, functions, build/automation/scripting logic, AND the executable logic of a
  document-generation script. Korean triggers: 코드, 구현, 기능, 스크립트, 함수, 수정, 리팩터.
- **typst-korean**: EXPLICIT user request for Typst only, OR editing an existing `**/*.typ`
  file. Explicit triggers: the user says "typst", "typst-korean", "typst로/으로", ".typ",
  "PDF via typst". A bare "PDF/장표/보고서/문서 만들어줘" with no Typst mention does **NOT**
  trigger it — typst-korean is opt-in, not the default document tool.

If neither ponytail nor typst-korean fires (pure Q&A, or a generic PDF/doc request with no
Typst mention), only caveman applies.

## 3. Scope boundaries — never-compress whitelist & non-coercion

**caveman NEVER compresses, summarizes, or caveman-ifies** (emit VERBATIM in full normal
prose) — discriminator is positive and parser-free: *if it is a fenced code block, OR
written to a file, OR on this list → verbatim*:
1. anything inside a fenced code block;
2. anything written to a file on disk (the literal bytes of any `.typ`/`.md`/`.py`/`.js`/…);
3. commit subject AND body;
4. PR title AND body;
5. security findings/analysis;
6. user-requested document content (report sections, headings, tables, prose);
7. clarifying questions/recommendations another layer mandates (e.g. typst-korean's font
   choice) — keep ALL decision-relevant options + the recommendation; tighten phrasing only,
   never reduce the choice to a single default.

**ponytail** does NOT govern conversational style, and does NOT touch document **content**:
a report's required sections are a fixed requirement, not excess code — YAGNI never prunes
them. Document-payload literals inside a code file (strings/heredocs/templates that ARE
document body/headings/tables or Typst/Markdown markup) are typst-korean content; ponytail's
ladder runs ONLY on the surrounding executable logic. Illustrative code shown to a reader
(displayed, not executed) is document content. **Installer/bootstrap and filesystem-mutating
automation are EXEMPT from YAGNI** — file-clobber guards, backups, idempotency checks, and
fail-open error handling are mandatory and are NOT excess code.

**typst-korean** does NOT govern executable source, never activates for code-only work,
never edits non-`.typ` executable source, and never forces structure/formatting the user did
not request (respect existing style; change only what is asked).

## 4. Conflict resolution (fixed order)

1. **Substance beats style.** caveman re-skins conversation only; it can never delete or mute
   substance another layer or the user mandated — including a mandated question's options.
2. **Split by SEMANTIC ROLE, then artifact.** Executable/shippable code → ponytail. Document
   payload (a `.typ`, or markup/heading/table literals embedded in a code file, or displayed
   example code) → typst-korean. Chat narration → caveman. Discriminator = executed-vs-displayed.
3. **Same-line collision.** When a document-payload literal and executable logic share one
   line, the document payload is sacrosanct; ponytail restructures only the surrounding code,
   never the literal text.
4. **Document content is sacrosanct.** Neither caveman terseness nor ponytail YAGNI strips
   sections, headings, tables, prose, or displayed examples the user requested.
5. **"Script that outputs a PDF"** → ponytail governs the generator's executable logic;
   typst-korean governs the emitted Typst/document payload; caveman restyles only narration.
6. **Generic PDF/doc request, no Typst mention** → do NOT auto-use Typst. typst-korean fires
   only on explicit Typst request or an existing `.typ` file; otherwise use the implied
   format/pipeline or ask the user.
7. **Commit register** → normal prose by DEFAULT; the explicit caveman-commit flow is the
   sanctioned terse exception.
8. **typst-korean dormant** with no document intent and no `.typ` present.
9. **Intensity** → caveman ULTRA standing default, ponytail FULL default; honor the most
   recent explicit user `/caveman` / `/ponytail` setting; never silently downgrade.

## 5. Intensity (standing order)

- **caveman = ULTRA** by standing user mandate, set via caveman's own per-user `config.json`
  (`defaultMode: "ultra"`) — affects caveman only, fully reversible, **no global env vars**
  (env pollution across unrelated tools is forbidden as a side effect).
- **ponytail = FULL** (its built-in default; intentional — ULTRA-aggressive minimalism is
  opt-in, not forced).
- Config files are **read-merged**, never clobbered. Do not silently downgrade below a level
  the user explicitly set.

## 6. Composition summary

caveman = **how you TALK** (always; conversation only; never the whitelist).
ponytail = **how much EXECUTABLE code you write** (minimal-but-not-negligent; code artifacts only).
typst-korean = **how you build KOREAN TYPST DOCUMENTS** (EXPLICIT request only — not the
default for generic PDF/장표/보고서; owns embedded Typst document payload when invoked).
Style yields to substance; substance splits by semantic role, not just file type.
