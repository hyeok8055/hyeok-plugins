# GOVERNANCE.md — hyeok-plugins Cross-Host Agent Governance

Single source of truth. Loaded/injected on **Claude Code**, **OpenAI Codex CLI**, and **Grok CLI**.
Host-agnostic, persistent. These are standing orders for every session.

## 0. Honest limit (read first)

An LLM cannot be *physically* forced by config alone. Enforcement here is persistent
instruction **injection** every session (and, on Claude Code, a one-line reminder per
turn) — **not** hard tool gates. There are deliberately **no** PreToolUse Edit/Write
blocks. Treat the rules below as binding standing orders; a non-compliant turn cannot be
hard-blocked, so comply by intent.

## 1. Five layers (orthogonal, by precedence)

**Layer 1 — ponytail (code policy).**
Code you write or edit that will be **executed or shipped** obeys the minimal-code ladder:
(1) need it? no → skip (YAGNI); (2) stdlib → use it; (3) native platform feature → use it;
(4) installed dependency → use it; (5) one line → one line; (6) only then the minimum that
works. **Minimal is NOT negligent** — keep validation, error handling, security,
accessibility. Default intensity = **FULL**; ULTRA opt-in (`/ponytail ultra`).

**Layer 2 — typst-korean (Typst document production — EXPLICIT REQUEST ONLY).**
Use typst-korean for PDF/document generation **only when the user explicitly asks for it**
(says "typst", "typst-korean", "in/with Typst", "PDF via typst", or is editing a `**/*.typ`
file). It is **NOT** the default tool for generic "make a PDF / 보고서 / 장표" requests.
When it IS explicitly invoked: Typst syntax, Korean fonts (default **Pretendard**),
CJK typography, templates `/new`, `/new-report`, `/new-slide`, `/pdf`, and ask which font.

**Layer 3 — diagram-design (editorial HTML+SVG diagrams).**
When the user asks for a **diagram** that fits editorial types (architecture sketch,
flowchart, sequence, state, ER, timeline, swimlane, quadrant, nested, tree, org chart,
layers, venn, pyramid) and does **not** need Archify's interactive system-map IR,
use **diagram-design** (canonical skill from cathrynlavery/diagram-design).
Standalone HTML + inline SVG. No Mermaid-slop unless the user asks for Mermaid/ASCII.

**Layer 4 — archify (interactive system maps — DEFAULT for system/architecture maps).**
When the user wants a **polished interactive system map** from a codebase or system
description (runtime architecture, workflow, sequence with validation, data flow,
lifecycle, before/after architecture delta), use **archify** (canonical skill from
[tt-a1i/archify](https://github.com/tt-a1i/archify), shipped via hyeok-plugins).
Typed JSON IR → validated HTML/SVG. Prefer Archify over inventing ad-hoc SVG or Mermaid
for system-mapping asks. Cross-host skill dirs under `~/.claude|codex|agents|grok/skills/archify`.

**Layer 5 — humanize-korean / im-not-ai (recorded writing/docs — REQUIRED).**
Applies when the task is to **author or polish a lasting Korean writing artifact**
(문서·보고서·기획서·README/문서 초안·블로그·칼럼·고객용 카피·보낼 메일 본문·
채널에 **남기는** 공지/기록용 글, and rewriting such text). Those **MUST** run through
**humanize-korean** (upstream [epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai))
before delivery: detect AI tells and humanize style **without changing substance**.

**Does NOT apply** to ordinary chat replies, short back-and-forth, or ephemeral Q&A in
a conversation — only to writing/document work meant to be kept or shipped as a record.
Also skip for: pure code/diff, or when the user explicitly says to skip humanize / AI-티 무시.


## 2. Task router — when each layer fires

- **ponytail**: ANY authoring/editing of executable or shippable code.
- **typst-korean**: EXPLICIT Typst request only, OR editing `**/*.typ`.
- **diagram-design**: editorial diagram types when Archify is not the better fit
  (quick editorial chart, brand-styled one-pager without IR validation).
- **archify**: system map / architecture from repo or description; interactive HTML;
  workflow/sequence/data-flow/lifecycle with validation; architecture delta/compare.
  Korean: 시스템 맵, 아키텍처 다이어그램, 런타임 구조, 시퀀스 맵, 데이터플로우.
  **Default for system-architecture mapping.**
- **humanize-korean (im-not-ai)**: REQUIRED for **recorded** Korean writing/docs
  (artifacts to keep or ship). **Not** for ordinary chat replies.

If none fire (chat/Q&A or pure code), no special layer — answer normally.

## 3. Scope boundaries

**ponytail** does NOT govern conversational style, and does NOT touch document **content**.
Installer/bootstrap and filesystem-mutating automation are EXEMPT from YAGNI.

**typst-korean** does NOT govern executable source; never forces structure the user did
not request.

**diagram-design / archify**: do not invent Mermaid as the default. Archify owns
validated system maps; diagram-design owns editorial HTML+SVG sketches.

**humanize-korean**: governs Korean **prose style** only (AI-티 제거). Does not change
facts, numbers, or claims. Does not replace typst-korean layout or diagram skills.

## 4. Conflict resolution

1. **Substance beats style.**
2. Executable/shippable code → ponytail. Document payload → typst-korean when invoked.
3. System-architecture / interactive map intent → **archify** over diagram-design.
4. Editorial one-off diagram without IR → diagram-design.
5. Generic PDF/doc without Typst mention → do NOT auto-use Typst.
6. Recorded Korean writing/doc artifact → **humanize-korean required** before handoff
   (after substance is settled; style pass last). Chat replies are out of scope.
7. **Intensity** → ponytail FULL default; honor explicit `/ponytail` settings.

## 5. Intensity

- **ponytail = FULL** (built-in default; ULTRA opt-in).
- Config files are **read-merged**, never clobbered.

## 6. Composition summary

ponytail = **how much EXECUTABLE code you write**.
typst-korean = **Korean Typst documents** (explicit only).
diagram-design = **editorial HTML+SVG diagrams**.
archify = **interactive validated system maps** (default for architecture/system mapping).
humanize-korean (im-not-ai) = **required** for recorded Korean writing/docs (not chat).
