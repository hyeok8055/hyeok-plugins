# hyeok-plugins

hyeok8055의 크로스호스트 에이전트 플러그인 마켓플레이스.

| 플러그인 | 역할 |
|----------|------|
| **hyeok-governance** | ponytail · typst-korean · diagram-design · archify · humanize-korean **우선순위·역할 분배** |
| **typst-korean** | Typst 한글 문서(PDF·장표·보고서) |
| **diagram-design** | Editorial HTML+SVG 다이어그램 — 정본 [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) |
| **archify** | 인터랙티브 시스템 맵 — 정본 [tt-a1i/archify](https://github.com/tt-a1i/archify) |
| **humanize-korean** | 한글 AI 티 제거(윤문) — 정본 [epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai). **글·문서 작업 필수** |

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
| 3 | **diagram-design** | 에디토리얼 HTML+SVG 다이어그램 | 도식 요청 시 |
| 4 | **archify** | 인터랙티브 시스템 맵 (아키텍처 기본) | 시스템맵 요청 시 기본 |

전체 규칙: `plugins/hyeok-governance/GOVERNANCE.md`.

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

거버넌스: 한국어 **글·문서** 산출물(슬랙/메일/보고서/카피 등)은 전달 전 이 스킬로 AI 티 제거가 **필수**.

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
