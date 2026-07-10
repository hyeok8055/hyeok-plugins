# hyeok-plugins

hyeok8055의 크로스호스트 에이전트 플러그인 마켓플레이스.

| 플러그인 | 역할 |
|----------|------|
| **hyeok-governance** | caveman · ponytail · typst-korean · insane-search · diagram-design **우선순위·역할 분배** |
| **typst-korean** | Typst 한글 문서(PDF·장표·보고서) |
| **diagram-design** | Editorial HTML+SVG 다이어그램 — 정본 [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) |
| **insane-search** | 차단/소셜/JS 우회 검색 (외부: fivetaku/insane-search, Claude dependency) |

Claude Code · Codex CLI · Grok Build **user 단위 전역 설치**를 `install.ps1` / `install.sh` 한 번으로 처리한다.

---

# 설치 (권장 — user 전역)

레포 클론 후:

```bash
# macOS / Linux / WSL
./install.sh
./install.sh --upstream          # caveman 공식 설치기 + insane-search 엔진 벤더
./install.sh --skip-cli-plugins  # 스킬 트리만 (claude/codex/grok plugin CLI 생략)

# Windows PowerShell
./install.ps1
./install.ps1 -UpstreamInstall
./install.ps1 -SkipCliPlugins
```

### 설치기가 하는 일

1. **user skill 트리 복사** (호스트 감지 후 해당 경로 전부):
   - Claude → `~/.claude/skills/{hyeok-governance,typst-korean,diagram-design}/`
   - Codex → `~/.codex/skills/…` + `~/.agents/skills/…`
   - Grok → `~/.grok/skills/…` + `~/.agents/skills/…`
   - 공통 → 항상 `~/.agents/skills/` (Codex USER + Grok 공용 표준)
   - 마킹: 각 스킬 디렉터리에 `.hyeok-installed` (uninstall 시 안전 제거)
2. **호스트 CLI 플러그인 설치** (PATH에 CLI 있을 때):
   - `claude plugin marketplace add <repo> --scope user` + `plugin install …@hyeok-plugins -s user`
   - `codex plugin marketplace add <repo>` + `plugin add …@hyeok-plugins`
   - `grok plugin marketplace add <repo>` + `plugin install <local-plugin> --trust`
3. **거버넌스 핀**
   - caveman `defaultMode=ultra`, ponytail `defaultMode=full` (config.json, BOM 없음)
   - Codex: 실제 읽히는 `AGENTS.override.md` 또는 `AGENTS.md`에 sentinel 병합
4. **`--upstream` / `-UpstreamInstall` (옵션)**
   - caveman 공식 설치기 실행
   - insane-search engine git clone + pip deps + 런처 (Codex/Grok)

### 확인

```bash
# 스킬 파일
ls ~/.claude/skills ~/.codex/skills ~/.agents/skills ~/.grok/skills

# 플러그인
claude plugin list
codex plugin list
grok plugin list
```

### 되돌리기

```bash
./uninstall.sh      # Windows: ./uninstall.ps1
```

sentinel 제거, 백업 복원, `defaultMode` 핀 제거, `.hyeok-installed` 스킬 삭제, CLI 플러그인 uninstall 시도.

---

# Claude 플러그인만 (수동)

```bash
/plugin marketplace add hyeok8055/hyeok-plugins
/plugin install hyeok-governance@hyeok-plugins
/plugin install typst-korean@hyeok-plugins
/plugin install diagram-design@hyeok-plugins
```

또는 CLI:

```bash
claude plugin marketplace add hyeok8055/hyeok-plugins --scope user
claude plugin install hyeok-governance@hyeok-plugins -s user
claude plugin install typst-korean@hyeok-plugins -s user
claude plugin install diagram-design@hyeok-plugins -s user
```

---

# hyeok-governance — 크로스호스트 거버넌스

## 무엇을 하나

| 계층 | 스킬 | 맡는 것 | 강도 |
|------|------|---------|------|
| 1 | **caveman** | 대화 **말투** (간결) — 항상 켜짐 | **ULTRA** |
| 2 | **ponytail** | **실행·배포 코드** 양 (최소-단 부실 금지) | FULL |
| 3 | **typst-korean** | Typst 한글 문서 (**명시 요청 시만**) | 옵트인 |
| 4 | **insane-search** | 웹·자료·리서치 **검색** | 기본 사용 |
| 5 | **diagram-design** | 기술/제품 **다이어그램** (HTML+SVG) | 다이어그램 요청 시 기본 |

**핵심: substance > style.** caveman은 말투만. 코드 블록·디스크 파일·커밋/PR·보안·문서·필수 질문은
압축 안 함. diagram-design은 Mermaid 슬롭 대신 editorial HTML+SVG. 전체 규칙:
`plugins/hyeok-governance/GOVERNANCE.md`.

### insane-search (요약)

- **Claude**: `dependencies: ["insane-search"]` → 마켓플레이스 자동 전이설치.
- **Codex / Grok**: `install --upstream` 필요 (Python3 + git + pip).

### 정직한 한계

LLM은 설정만으로 100% 물리적 강제 불가. "강제" = 컨텍스트 자동 주입. 하드 게이트 없음.

---

# diagram-design

정본: [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) (MIT).  
이 마켓의 `plugins/diagram-design/` 은 그 스킬 트리를 벤더링한 것 — `SOURCE.md` 에 핀된 커밋.

14 타입: architecture, flowchart, sequence, state, ER, timeline, swimlane, quadrant, nested, tree, org chart, layers, venn, pyramid.  
standalone HTML + inline SVG. 스타일 가이드 온보딩 지원.

사용 예:

```
아키텍처 다이어그램 그려줘: frontend, backend, redis, postgres
Make a sequence diagram of the OAuth handshake
```

갤러리: `plugins/diagram-design/skills/diagram-design/assets/index.html`

---

# typst-korean

Claude Code 플러그인 - Typst 한글 문서 작성 지원.

### 빠른 시작

```bash
/plugin install typst-korean@hyeok-plugins
/install-font
/new mydocument
/pdf mydocument.typ
```

| 커맨드 | 설명 |
|--------|------|
| `/new [파일명]` | 기본 한글 문서 |
| `/new-report [파일명]` | 보고서 템플릿 |
| `/new-slide [파일명]` | 슬라이드/장표 |
| `/pdf [파일명]` | Typst → PDF |
| `/convert [파일명]` | Markdown → Typst |
| `/check-font` | 폰트 확인 |
| `/install-font` | 폰트 설치 |

기본 폰트: **Pretendard** (상업 무료). 요구: Typst >= 0.11.0.

---

# 표준 준수

- **Claude**: `.claude-plugin/marketplace.json` + 플러그인별 `plugin.json`, hooks `${CLAUDE_PLUGIN_ROOT}`.
- **Codex**: `.agents/plugins/marketplace.json` + 플러그인별 `.codex-plugin/plugin.json`, user skills `~/.agents/skills` / `~/.codex/skills`.
- **Grok Build**: Claude 호환 + `~/.grok/skills` / `~/.agents/skills`, `grok plugin install --trust`.

# 라이선스

- hyeok-governance / typst-korean / 설치 스크립트: MIT
- diagram-design: MIT (upstream Cathryn Lavery — 원본 LICENSE 포함)
- insane-search: 해당 업스트림 라이선스
