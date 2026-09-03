# hyeok-plugins

hyeok8055의 크로스호스트 에이전트 플러그인 마켓플레이스.

| 플러그인 | 역할 |
|----------|------|
| **hyeok-governance** | ponytail · typst-korean · diagram-design · archify · humanize-korean **우선순위·역할 분배** |
| **typst-korean** | Typst 한글 문서(PDF·장표·보고서) |
| **diagram-design** | Editorial HTML+SVG 다이어그램 — 정본 [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) |
| **archify** | 인터랙티브 시스템 맵 — 정본 [tt-a1i/archify](https://github.com/tt-a1i/archify) |
| **humanize-korean** | 한글 AI 티 제거(윤문) — 정본 [epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai). **기록용 글·문서 필수** (채팅 제외) |

Claude Code · Codex CLI · Grok Build **user 단위 전역 설치**를 `install.ps1` / `install.sh` 한 번으로 처리한다.

---

# 설치 (권장 — user 전역)

레포 클론 후:

```bash
# macOS / Linux / WSL
./install.sh
./install.sh --skip-cli-plugins  # 스킬 트리만
./install.sh --skip-fonts         # Pretendard 자동설치 생략

# Windows PowerShell
./install.ps1
./install.ps1 -SkipCliPlugins
```

### 설치기가 하는 일

1. **user skill 트리 복사** (호스트 감지 후 해당 경로 전부):
   - Claude → `~/.claude/skills/{hyeok-governance,typst-korean,diagram-design,archify,humanize-korean}/`
   - Codex → `~/.codex/skills/…` + `~/.agents/skills/…`
   - Grok → `~/.grok/skills/…` + `~/.agents/skills/…`
   - 공통 → 항상 `~/.agents/skills/`
   - 마킹: 각 스킬 디렉터리에 `.hyeok-installed` (uninstall 시 안전 제거)
2. **호스트 CLI 플러그인 설치** (PATH에 CLI 있을 때):
   - `claude plugin marketplace add <repo> --scope user` + `plugin install …@hyeok-plugins -s user`
   - `codex plugin marketplace add <repo>` + `plugin add …@hyeok-plugins`
   - `grok plugin marketplace add <repo>` + `plugin install <local-plugin> --trust`
3. **Pretendard 폰트** (typst-korean 기본)
   - Regular·Medium·SemiBold·Bold OTF 4개만 CDN에서 받아 OS 사용자 폰트 경로에 설치 (~6MB)
   - macOS `~/Library/Fonts`, Linux `~/.local/share/fonts/hyeok-pretendard`, Windows 사용자 Fonts
4. **거버넌스 핀**
   - ponytail `defaultMode=full` (config.json, BOM 없음)
   - Codex: `AGENTS.override.md` 또는 `AGENTS.md`에 sentinel 병합

### 확인

```bash
ls ~/.claude/skills ~/.codex/skills ~/.agents/skills ~/.grok/skills
claude plugin list
codex plugin list
grok plugin list
```

### 되돌리기

```bash
./uninstall.sh      # Windows: ./uninstall.ps1
```

---

# Claude 플러그인만 (수동)

```bash
/plugin marketplace add hyeok8055/hyeok-plugins
/plugin install hyeok-governance@hyeok-plugins
/plugin install typst-korean@hyeok-plugins
/plugin install diagram-design@hyeok-plugins
/plugin install archify@hyeok-plugins
/plugin install humanize-korean@hyeok-plugins
```

---

# hyeok-governance — 크로스호스트 거버넌스

| 계층 | 스킬 | 맡는 것 | 강도 |
|------|------|---------|------|
| 1 | **ponytail** | **실행·배포 코드** 양 (최소-단 부실 금지) | FULL |
| 2 | **typst-korean** | Typst 한글 문서 (**명시 요청 시만**) | 옵트인 |
| 3–4 | **시각화 그룹** | §1.1 결정표로 스킬. 타입은 `references/viz-catalog.md` | 도식/차트 요청 시 |
| 5 | **humanize-korean** | 기록용 한글 글·문서 AI 티 제거 | 기록물 필수 |

전체 규칙: `plugins/hyeok-governance/GOVERNANCE.md`.

### 시각화 그룹 — 스킬을 열기 전에 고른다

한 산출물에 스킬 하나. 타입 상세는 `plugins/hyeok-governance/skills/hyeok-governance/references/viz-catalog.md`.

| 먼저 이건가? | 스킬 |
|---|---|
| 표·CSV·KPI를 그래프로 | **lieflat-charts** *(벤더 안 함, PolyForm Noncommercial)* https://github.com/larashero3-dotcom/lieflat-charts |
| 시스템·인프라·런타임 맵 | **archify** |
| 그 외 개념·프로세스 도식 | **diagram-design** |

충돌: 시스템맵 archify > diagram. 수치 차트 lieflat only. 둘이면 파일 둘. 사용자가 스킬을 지정하면 그걸 따른다.

### 정직한 한계

LLM은 설정만으로 100% 물리적 강제 불가. "강제" = 컨텍스트 자동 주입. 하드 게이트 없음.

---

# archify

정본: [tt-a1i/archify](https://github.com/tt-a1i/archify) (MIT).  
`plugins/archify/` 은 그 스킬 트리를 벤더링한 것 — `SOURCE.md` 에 핀된 커밋.

Architecture · Workflow · Sequence · Data Flow · Lifecycle. Typed JSON IR → validated HTML/SVG.

```
이 레포 런타임 아키텍처를 archify로 그려줘
Browser -> API -> Redis -> Postgres 시스템 맵
```

---


# humanize-korean (im-not-ai)

정본: [epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai) (MIT).  
`plugins/humanize-korean/` 벤더 — `SOURCE.md` 핀.

거버넌스: **남기는** 한국어 글·문서(보고서/메일 본문/공지/카피 등)는 전달 전 이 스킬로 AI 티 제거가 **필수**. 짧은 채팅 답은 비대상.

# diagram-design

정본: [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) (MIT).  
`plugins/diagram-design/` 벤더 — `SOURCE.md` 핀.

---

# typst-korean

```bash
/plugin install typst-korean@hyeok-plugins
/install-font
/new mydocument
/pdf mydocument.typ
```

기본 폰트: **Pretendard**. 요구: Typst >= 0.11.0.

---

# 표준 준수

- **Claude**: `.claude-plugin/marketplace.json` + 플러그인별 `plugin.json`
- **Codex**: `.agents/plugins/marketplace.json` + `.codex-plugin/plugin.json`
- **Grok Build**: Claude 호환 + `~/.grok/skills` / `~/.agents/skills`

# 라이선스

- hyeok-governance / typst-korean / 설치 스크립트: MIT
- diagram-design: MIT (upstream Cathryn Lavery)
- archify: MIT (upstream tt-a1i/archify)
- humanize-korean: MIT (upstream epoko77-ai/im-not-ai)
- lieflat-charts: **not in this repo**. Upstream PolyForm Noncommercial 1.0.0 — commercial redistribute 금지. 별도 설치.
