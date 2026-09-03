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
See **§1.1**. When the user asks for a **diagram** that fits editorial types (architecture sketch,
flowchart, sequence, state, ER, timeline, swimlane, quadrant, nested, tree, org chart,
layers, venn, pyramid) and does **not** need Archify's interactive system-map IR,
use **diagram-design** (canonical skill from cathrynlavery/diagram-design).
Standalone HTML + inline SVG. No Mermaid-slop unless the user asks for Mermaid/ASCII.

**Layer 4 — archify (interactive system maps — DEFAULT for system/architecture maps).**
See **§1.1**. When the user wants a **polished interactive system map** from a codebase or system
description (runtime architecture, workflow, sequence with validation, data flow,
lifecycle, before/after architecture delta), use **archify** (canonical skill from
[tt-a1i/archify](https://github.com/tt-a1i/archify), shipped via hyeok-plugins).
Typed JSON IR → validated HTML/SVG. Prefer Archify over inventing ad-hoc SVG or Mermaid
for system-mapping asks. Cross-host skill dirs under `~/.claude|codex|agents|grok/skills/archify`.


## 1.1 Visualization group — pick ONE skill, then ONE type, **before any draw tool**

These three are a **group**, not three defaults. Do not open a skill or call its
tools until this section has named both **skill** and **type**. Do not mix
skills in a single deliverable. Split mixed asks into two artifacts.

**Decision order (one pass):**
1. Numeric table / CSV / KPI / “그래프로 보여줘” → **lieflat-charts** (external).
   If not installed: tell the user to install it, or fall back to diagram-design
   **Bar / Line / Scatter only** (diagram-grade, not a dashboard).
2. System / codebase / infra / cloud-security topology / validated runtime map → **archify**.
3. Everything else conceptual / process / editorial → **diagram-design**.
4. Tie-break: system-map intent → archify > diagram-design. Numeric charts → lieflat only.
   One request, two intents → **two files**, one skill each.

| Intent cue | Skill | In tree? |
|---|---|---|
| 시스템맵, 아키텍처, 인프라, 런타임, 시퀀스/데이터플로우 IR | **archify** | yes (MIT) |
| 플로우·ER·여정·UML·개념 도식 | **diagram-design** | yes (MIT) |
| 표·수치 → 편집 HTML 차트/리포트 | **lieflat-charts** | **no** — PolyForm Noncommercial. https://github.com/larashero3-dotcom/lieflat-charts |

### archify — 5 IR types (pick exactly one)

Read only the matching schema after this pick. Do not invent Mermaid/SVG for these.

| Type | Use when showing… | Cue |
|---|---|---|
| `architecture` | Components, services, cloud/security boundaries, infrastructure | 시스템맵, 토폴로지, 컴포넌트 |
| `workflow` | Processes, approval gates, tool calls, runbooks, CI/CD | 워크플로, 런북, 승인 |
| `sequence` | API call chains, request lifecycles, async traces, returns | API 시퀀스, 호출 사슬 |
| `dataflow` | Pipelines, ETL/ELT, lineage, governance, consumers | 파이프라인, 리니지 |
| `lifecycle` | State/status transitions, retries, waiting and terminal states | 상태머신, 라이프사이클 |

Mermaid in: flowchart/graph → `workflow` (or `architecture` if component map);
`sequenceDiagram` → `sequence`; `stateDiagram` → `lifecycle`.

### diagram-design — 39 visual types (pick exactly one)

Load `references/type-*.md` for the chosen type only. Prefer this over archify when
the ask is editorial/conceptual, not a validated system IR.

**Structure / system (prefer archify if it is a real runtime map)**
- Architecture · IT current-state · High-Level · Deployment · DP integration · DP security matrix · Layer stack · Nested

**Process / time**
- Flowchart · Sequence · State machine · Swimlane · Process · Timeline · Gantt · Kanban · User journey · Story map

**Data model**
- ER / data model · Database schema · UML class · Data flow · Medallion

**Hierarchy / sets**
- Tree · Org chart · Venn · Pyramid / funnel · Treemap · Loop / flywheel

**Position / analysis**
- Quadrant · Radar / spider · Polar · Wardley map · Fishbone · Sankey · Dependency graph

**Quantitative (diagram-grade only — real measured series go to lieflat)**
- Bar · Line (incl. slope / ridgeline / bump) · Scatter (incl. bubble / beeswarm)

Do **not** use for unicode sketches, bullet lists, or one-shape “diagrams”.

### lieflat-charts — 63 templates (external; pick by **data shape**)

Not vendored. If the skill is missing, stop and give the install URL — do not
reimplement 63 types in diagram-design.

**Output mode:** default = **chart**. Report templates R01–R12 only when the user
explicitly asks 보고서/연보/월보/화이트페이퍼/포스터/brief/notebook.

**Family priority:** Lupi Editorial (L) → Lupi Basics (F) → Glance (G).
Glance only if L+F cannot encode the data, or the user asks dashboard / 3-second read.
Maps (M) and Interactive (B) **only if asked**.

Main roster L1–L15 + F1–F13. Backup L16–L20 / F14–F17 / G19–G22 only when the main
set cannot encode honestly — except these shapes, which skip straight to backup:
OHLC → F17; box+outliers → F15; 3–6 continuous dims/entity → L20;
year calendar 52×7 → L17; stacked composition over continuous time → F16.

| Data shape | First candidates |
|---|---|
| Few-category compare (≤8) | F1 Rung Bars / F5 Tick Rows / L2 Dot Cascade (G3 if Glance) |
| Multi-select % (items independent) | L15 Ballot Tally / G3 |
| 100% composition | F4 Tick Donut / L14 Hundred Field / G4 Dot Waffle |
| Stacked composition by category | F7 Stacked Rungs |
| Signed +/- categories | G10 Diverging Bar |
| Before/after per category | F12 Dumbbell / F6 Paired Rungs |
| Daily series ≤30d | F2 Hairline Line |
| Daily series 30–90d | F3 Hairline Area / L3 Barcode Lollipop |
| Funnel / stage drop-off | L13 Hourglass Stream |
| Waterfall / P&L bridge | F9 Rung Waterfall |
| Single progress 0–100 | F11 Tick Gauge |
| 2-D scatter ≤20 | F8 Plumb Scatter |
| Histogram / binned counts | F14 Rung Histogram |
| Grouped distribution | F15 Tick Box / G15 Jitter / G19 Violin |
| Matrix category×category | L4 Arc Matrix / L9 Almanac (backup L16 / G20) |
| Week×hour load | F10 Dot Heat / G14 Single Axis |
| Many-to-one membership | L5 Radial Convergence / L12 Type Colonnade |
| Hierarchy + share | F13 Nested Treemap (relation-only → G7 Tree LR) |
| Network | ≤15: G6/G11; larger / inspect: B1 circular / B2 force; paths: B3 Threads |
| Rank over discrete time | L11 Trend Lineage / G21 Rank Strip (race: G16) |
| Event lifetime | L11 Trend Lineage |
| Birth-time + current size | L1 Launch Fan |
| Bipolar scale | L7 Brand Spectrum |
| Choropleth | M1 US / M2 World — **only if user asked for a map** |

Glance extras (dashboard / motion): G5 pictorial bar, G8 dual-area, G9 scatter morph,
G12 stagger wave, G13 dual-encode pie, G16 bar race, G17 live stream, G18 draw-in counter,
G22 aggregate Sankey.

Do **not** use lieflat for architecture / flowchart / ER / UML / journey maps.

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
- **Visualization group (§1.1)** — pick one:
  - **archify**: system/architecture maps (IR). Korean: 시스템맵, 아키텍처, 런타임, 시퀀스/데이터플로우.
  - **diagram-design**: editorial HTML+SVG diagrams (flow, ER, timeline, …).
  - **lieflat-charts** (external): numeric data → HTML charts. Not vendored (Noncommercial).
- **humanize-korean (im-not-ai)**: REQUIRED for **recorded** Korean writing/docs
  (artifacts to keep or ship). **Not** for ordinary chat replies.

If none fire (chat/Q&A or pure code), no special layer — answer normally.

## 3. Scope boundaries

**ponytail** does NOT govern conversational style, and does NOT touch document **content**.
Installer/bootstrap and filesystem-mutating automation are EXEMPT from YAGNI.

**typst-korean** does NOT govern executable source; never forces structure the user did
not request.

**diagram-design / archify / lieflat-charts**: do not invent Mermaid as the default.
Archify owns validated system maps (5 IR types). diagram-design owns editorial
HTML+SVG (39 types). lieflat-charts (external) owns numeric HTML charts (63 types).
Pick skill+type from §1.1 **before** opening any of those skills.

**humanize-korean**: governs Korean **prose style** only (AI-티 제거). Does not change
facts, numbers, or claims. Does not replace typst-korean layout or diagram skills.

## 4. Conflict resolution

1. **Substance beats style.**
2. Executable/shippable code → ponytail. Document payload → typst-korean when invoked.
3. Numeric table/CSV/KPI chart → **lieflat-charts** (external); never archify/diagram IR.
4. System-architecture / interactive map intent → **archify** over diagram-design.
5. Editorial one-off diagram without IR → diagram-design.
6. Generic PDF/doc without Typst mention → do NOT auto-use Typst.
7. Recorded Korean writing/doc artifact → **humanize-korean required** before handoff
   (after substance is settled; style pass last). Chat replies are out of scope.
8. **Intensity** → ponytail FULL default; honor explicit `/ponytail` settings.

## 5. Intensity

- **ponytail = FULL** (built-in default; ULTRA opt-in).
- Config files are **read-merged**, never clobbered.

## 6. Composition summary

ponytail = **how much EXECUTABLE code you write**.
typst-korean = **Korean Typst documents** (explicit only).
diagram-design = **editorial HTML+SVG diagrams**.
archify = **interactive validated system maps** (default for architecture/system mapping).
humanize-korean (im-not-ai) = **required** for recorded Korean writing/docs (not chat).
