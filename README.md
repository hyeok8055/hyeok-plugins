# hyeok-plugins

hyeok8055의 Claude 플러그인 마켓플레이스. 두 플러그인 제공:

- **typst-korean** — Typst 한글 문서(PDF·장표·보고서) 작성 지원.
- **hyeok-governance** — caveman(출력 스타일) · ponytail(코드 최소화) · typst-korean(한글 문서)
  세 스킬의 **우선순위·역할을 충돌 없이 분배**하고 Claude Code / Codex CLI / Grok CLI 전반에
  걸쳐 강제하는 크로스호스트 거버넌스 계층.

---

# hyeok-governance — 크로스호스트 거버넌스

## 무엇을 하나

세 도구를 **직교(orthogonal)** 계층으로 분리해 서로 겹치지 않게 한다:

| 계층 | 스킬 | 맡는 것 | 강도 |
|------|------|---------|------|
| 1 | **caveman** | 대화 **말투** (간결) — 항상 켜짐 | **ULTRA** (기본) |
| 2 | **ponytail** | **실행·배포 코드** 양 (최소-단 부실 금지) | FULL (기본) |
| 3 | **typst-korean** | Typst 한글 문서 생산 (**명시 요청 시만**) | 옵트인 |

**핵심 원칙: substance > style.** caveman은 말투만 바꾼다 — 코드 블록, 디스크에 쓰는 파일,
커밋/PR 텍스트, 보안 분석, 사용자가 요청한 문서 내용, 다른 계층이 강제한 필수 질문은
**절대 압축·생략 안 함**. ponytail은 실행 코드에만 적용되고 문서 내용은 못 깎는다.
typst-korean은 코드를 건드리지 않는다. 전체 규칙: `plugins/hyeok-governance/GOVERNANCE.md`.

## 정직한 한계

LLM은 설정만으로 100% 물리적 강제 불가. 여기서 "강제" = 매 세션(Claude는 매 턴) 규칙을
**컨텍스트로 자동 주입**하는 것 — 하드 게이트(코드 편집 차단) 없음(부작용 없는 최강 방식,
사용자 선택). 비순응 턴을 물리적으로 막진 못하니 의도로 따른다.

## 설치

### 1) Claude Code (플러그인)

```bash
/plugin marketplace add hyeok8055/hyeok-plugins
/plugin install hyeok-governance@hyeok8055-hyeok-plugins
/plugin install typst-korean@hyeok8055-hyeok-plugins
```

설치하면 SessionStart 훅이 `GOVERNANCE.md` 전체를, UserPromptSubmit 훅이 매 턴 한 줄
리마인더를 주입한다. 훅은 fail-open(에러나면 빈 컨텍스트, 턴 절대 안 막음).

### 2) Codex CLI · Grok CLI (설치 스크립트)

레포 클론 후:

```bash
# macOS / Linux / WSL
./install.sh                 # 로컬 설정만 (기본)
./install.sh --upstream      # caveman 공식 설치기도 자동 실행

# Windows PowerShell
./install.ps1
./install.ps1 -UpstreamInstall
```

스크립트가 하는 일 (공식 표준 준수):
- 호스트 자동 감지(claude/codex/grok) — 없는 건 건너뜀.
- caveman `config.json` `defaultMode=ultra`, ponytail `defaultMode=full` 설정
  (BOM 없이 기록 — Node `JSON.parse` 호환). **전역 환경변수 안 씀**.
- **Codex**: Codex가 실제 읽는 전역 파일에 `GOVERNANCE.md`를 sentinel 블록으로 병합.
  Codex는 `~/.codex/AGENTS.override.md`가 있으면 그걸, 없으면 `~/.codex/AGENTS.md`를 읽고
  (override가 base를 *대체*함) → 우린 그중 **실제 읽히는 파일**에 병합해 유저 내용 보존.
  최초 1회 `.pre-hyeok.bak` 백업, 재실행해도 중복 없음(idempotent), 한글 보존(UTF-8).
- **Grok (xAI Grok Build, 공식)**: Grok Build는 Claude 컨벤션 호환(`docs.x.ai/build`,
  config `~/.grok`)이라 **상시주입 최강 경로 = 이 `hyeok-governance` 플러그인 그대로 설치**
  → SessionStart 훅이 매 세션 주입. 설치기는 보조로 user 스킬
  `~/.agents/skills/{hyeok-governance,typst-korean}/SKILL.md` + config(ultra/full)도 깔아둠.
  설치 후 `grok inspect`로 로드 확인.

### 강도 정책

- **caveman = ULTRA** (사용자 지정). caveman 자체 `config.json defaultMode`로 고정 →
  caveman에만 영향, 되돌리기 가능, 환경 오염 없음. 세션 중 `/caveman full`로 낮출 수 있음.
- **ponytail = FULL** (기본; 과도한 최소화는 opt-in). `/ponytail ultra`로 올릴 수 있음.

### 되돌리기

```bash
./uninstall.sh      # 또는 Windows: ./uninstall.ps1
```

sentinel 블록 제거, 백업 복원, `defaultMode` 핀 제거, flag·복사 스킬 삭제.

### 표준 준수 검증 (공식 문서 대조)

- **Claude**: `plugin.json`은 `.claude-plugin/plugin.json`(공식 위치), 컴포넌트는 플러그인
  루트(`skills/`, `hooks/`). 훅은 `hooks/hooks.json` 자동 발견, `${CLAUDE_PLUGIN_ROOT}`
  공식 변수, 훅 출력 `hookSpecificOutput.additionalContext` 계약 준수. `claude plugin validate`로
  확인 가능.
- **Codex**: 전역 지침은 `~/.codex/AGENTS.md`(override 있으면 그게 *대체*). 우린 실제 읽히는
  파일에 병합 → 유저 전역 지침 안 잃음.
- **Grok Build (xAI)**: Claude 호환 확인(`docs.x.ai/build`, 공식 발표). config `~/.grok` 확인.
  플러그인(훅) 경로로 상시주입. `grok inspect`로 실제 로드 확인.

### 알려진 한계 (residual risks)

- LLM은 설정만으로 100% 강제 불가 — 상시 주입이 최강(하드 게이트 없음).
- **Codex**: 전역 SessionStart 훅은 공식 보장 안 됨 → 정적 `AGENTS.md` 로드 의존
  (아주 긴 세션에선 규칙이 컨텍스트에서 밀릴 수 있음).
- **Grok Build**: 공식 docs(`docs.x.ai/build`)의 deep 페이지(skills/AGENTS 정확 경로)는
  JS 렌더라 직접 못 박음 → config `~/.grok` + "Claude 컨벤션 호환" 공식 명시에 근거해
  **플러그인 경로**를 1순위로 씀(검증된 Claude 플러그인 구조 그대로). 보조 user 스킬은
  버전에 따라 안 잡힐 수 있음(그래서 플러그인이 1순위). `grok inspect`로 확인 권장.
- **superagent grok-cli**(다른 제품): `~/.grok` + `~/.agents/skills/` 확인됨. 설치기가 그 경로도 깔아 호환.

---

# typst-korean

Claude Code 플러그인 - Typst 한글 문서 작성 지원

## 빠른 시작

### 1. 플러그인 설치

Claude Code에서 다음 명령어를 실행하세요:

```bash
# 마켓플레이스 추가
/plugin marketplace add hyeok8055/hyeok-plugins

# 플러그인 설치
/plugin install typst-korean@hyeok8055-hyeok-plugins
```

### 설치 확인

```bash
# 설치된 플러그인 목록 확인
/plugin
```

설치 후:
- `.typ` 파일을 열면 자동으로 typst-korean 스킬이 활성화됩니다
- `/new` 입력 시 자동완성에 커맨드가 표시됩니다

### 2. 폰트 설치

```bash
/install-font
```

### 3. 새 문서 생성

```bash
/new mydocument
```

### 4. PDF로 변환

```bash
/pdf mydocument.typ
```

## 커맨드 사용법

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `/new [파일명]` | 기본 한글 문서 생성 | `/new report` |
| `/new-report [파일명]` | 보고서 템플릿 | `/new-report quarterly` |
| `/new-slide [파일명]` | 슬라이드/장표 템플릿 | `/new-slide presentation` |
| `/pdf [파일명]` | Typst → PDF 변환 | `/pdf document.typ` |
| `/convert [파일명]` | Markdown → Typst 변환 | `/convert README.md` |
| `/check-font` | 폰트 설치 확인 | `/check-font` |
| `/install-font` | 폰트 다운로드/설치 | `/install-font` |

## 지원 폰트

모든 폰트는 **상업적 사용이 무료**입니다 (SIL OFL 또는 동등 라이선스).

| 폰트 | 특징 | 추천 용도 |
|------|------|-----------|
| **Pretendard** (기본값) | Apple SF, Inter 스타일 | 일반 문서, UI |
| **Noto Sans KR** | Google Fonts 고딕 | 일반 문서, 웹 |
| **Noto Serif KR** | Google Fonts 명조 | 논문, 서적 |
| **NanumGothicCoding** | 네이버 고정폭 | 코드, 기술 문서 |
| **D2Coding** | 네이버 고정폭 | 코드, 기술 문서 |
| **IBM Plex Sans KR** | IBM 디자인 고딕 | 프레젠테이션 |
| **Spoqa Han Sans Neo** | 스포카 고딕 | UI, 웹 |

문서 생성 시 폰트를 선택할 수 있으며, 기본값은 Pretendard입니다.

## 기능

- 다양한 한글 폰트 선택 및 fallback 지원
- 한글 문서에 적합한 타이포그래피 설정 (CJK 권장 줄간격, 들여쓰기)
- 다양한 템플릿 제공 (기본, 보고서, 슬라이드)
- Typst 기본 문법 레퍼런스
- `.typ` 파일 작업 시 자동 활성화

## 폰트 설치

### 프로젝트 폴더에 설치 (권장)

```bash
# 폰트 디렉토리 생성
mkdir -p fonts

# Pretendard 다운로드
curl -L -o fonts/Pretendard.zip "https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip"
cd fonts && unzip -o Pretendard.zip -d Pretendard && rm Pretendard.zip && cd ..

# 컴파일 시 폰트 경로 지정
typst compile --font-path ./fonts document.typ
```

### 시스템 전역 설치

```bash
# macOS
cp fonts/*/*.otf ~/Library/Fonts/

# Linux
mkdir -p ~/.local/share/fonts
cp fonts/*/*.otf ~/.local/share/fonts/
fc-cache -fv
```

## 문제 해결

### 폰트 인식 안 될 때

```bash
# 설치된 폰트 확인
typst fonts | grep -i pretendard

# 폰트 경로 지정하여 컴파일
typst compile --font-path ./fonts document.typ
```

### typst 설치

```bash
# Cargo (Rust)
cargo install typst-cli

# Homebrew (macOS)
brew install typst

# Scoop (Windows)
scoop install typst
```

### 한글 깨짐

폰트가 없거나 `lang` 설정이 누락된 경우 발생합니다:

```typst
#set text(
  font: ("Pretendard", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
)
```

## 권장 설정

### 한글 문서 기본 설정

```typst
// 폰트 (fallback 포함)
#set text(
  font: ("Pretendard", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
  size: 11pt,
)

// 페이지
#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
)

// 문단 (CJK 권장)
#set par(
  leading: 1.5em,
  first-line-indent: 1em,
  justify: true,
)
```

## 플러그인 관리

```bash
# 플러그인 비활성화
/plugin disable typst-korean@hyeok8055-hyeok-plugins

# 플러그인 활성화
/plugin enable typst-korean@hyeok8055-hyeok-plugins

# 플러그인 제거
/plugin uninstall typst-korean@hyeok8055-hyeok-plugins

# 마켓플레이스 제거
/plugin marketplace remove hyeok8055-hyeok-plugins
```

## 요구 사항

- Typst >= 0.11.0
- Claude Code

## 라이선스

MIT
