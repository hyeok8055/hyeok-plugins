# Visualization type catalog

Read this **after** `GOVERNANCE.md` §1.1 has named the skill, **before** opening
archify / diagram-design / lieflat-charts or calling their tools. Pick exactly
one type. Mixed intents → two files.

Collision (same as GOVERNANCE): system-map → archify > diagram-design.
Numeric chart → lieflat only. User-named skill/type wins.

---

## archify — 5 IR types

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

---

## diagram-design — 39 visual types

Load that skill's `references/type-*.md` for the chosen type only.

**Structure / system** (prefer archify if it is a real runtime map)
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

---

## lieflat-charts — 63 templates (external)

Not vendored. License: **PolyForm Noncommercial 1.0**.
Install: https://github.com/larashero3-dotcom/lieflat-charts
If missing: stop and give that URL — do not reimplement 63 types in diagram-design.

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
