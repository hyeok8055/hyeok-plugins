---
name: hyeok-governance
description: 작업 라우팅·우선순위 규칙. 어떤 일을 caveman(출력 스타일)·ponytail(코드 최소화)·typst-korean(한글 문서)·insane-search(검색) 중 무엇이 맡는지 정한다. 코드 작성/수정, PDF·문서 생성, 웹·자료·리서치 검색, 또는 역할이 겹칠 때 참조. caveman ULTRA 항상, ponytail 모든 코드, typst-korean은 typst 명시 요청 시만(옵트인), insane-search는 모든 검색에 강제(Claude 전용).
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# hyeok-governance — 4계층 작업 거버넌스

세 스킬의 **우선순위와 역할**을 충돌 없이 분배한다. 전체 규칙: 같은 디렉터리 상위의
[`GOVERNANCE.md`](../../GOVERNANCE.md) (세션 시작 시 훅이 컨텍스트로 자동 주입).

## 계층 (직교, 우선순위 순)

| 계층 | 스킬 | 맡는 것 | 안 맡는 것 |
|------|------|---------|-----------|
| 1 | **caveman** (ULTRA, 항상) | 대화 **말투** (간결) | 코드/파일내용/커밋/PR/보안/문서내용/필수질문 = 그대로 |
| 2 | **ponytail** (FULL) | **실행·배포 코드** 양 (최소-단 부실 금지) | 대화 말투, 문서 내용, 표시용 예제코드 |
| 3 | **typst-korean** | Typst 한글 문서 생산 (**명시 요청 시만**) | 실행 코드, 말투, 일반 PDF 자동선택 |
| 4 | **insane-search** | 웹·자료·리서치 **검색** (기본 사용, 크로스호스트) | 코드, 문서 생성, 말투 |

## 라우팅

- **caveman**: 매 턴 항상. 트리거 불필요.
- **ponytail**: 코드/구현/기능/스크립트/함수/수정/리팩터 — 실행·배포될 코드.
- **typst-korean**: 사용자가 **typst를 명시 요청**했거나 `.typ` 파일 작업 시에만. 일반
  "PDF/장표/보고서 만들어줘"(typst 언급 없음)엔 자동으로 안 씀 — 옵트인.
- **insane-search**: 웹/자료/리서치 **검색**(검색·찾아·자료·리서치·조사) — **기본 사용,
  안 물어봄**. 차단/소셜/JS 사이트 자동 우회(`python3 -m engine`). **크로스호스트**: Claude=자동
  플러그인, Grok=user 스킬 자동, Codex=런처+AGENTS.md 지시. Python·engine 없으면 솔직히 말하고
  호스트 기본 검색. phase3(브라우저)는 Claude만 완전, codex/grok은 phase0-2로 축소될 수 있음.

## 충돌 해소 (요약)

1. **substance > style** — caveman은 말투만 바꾼다. 다른 계층/사용자가 요구한 내용은
   절대 삭제·요약·압축 안 함 (필수 질문의 선택지 포함).
2. **역할로 분리** — 실행 코드는 ponytail, 문서 페이로드(`.typ`·코드 내 마크업 리터럴·
   표시용 예제)는 typst-korean, 대화는 caveman. 기준 = 실행되는가 vs 보여지는가.
3. **한 줄 충돌** — 문서 리터럴과 코드가 한 줄에 있으면 문서 리터럴이 신성불가침,
   ponytail은 주변 코드만 정리.
4. **문서 내용 신성불가침** — caveman 간결함도 ponytail YAGNI도 사용자가 요청한 섹션·
   표·산문·예제를 못 깎는다.
5. **"PDF 뽑는 스크립트"** — 생성기 실행 로직 = ponytail, 내보내는 Typst/문서 = typst-korean.
6. **강도** — caveman ULTRA 기본, ponytail FULL 기본. 사용자가 명시 변경하면 그걸 존중,
   조용히 낮추지 않음.

## 설치 강제 (호스트별)

- **Claude Code**: 이 플러그인의 SessionStart 훅이 `GOVERNANCE.md` 전체 주입,
  UserPromptSubmit 훅이 매 턴 한 줄 리마인더 주입. 하드 게이트 없음(fail-open).
- **Codex CLI**: 루트 `install.ps1`/`install.sh` 가 Codex가 실제 읽는 전역 파일
  (`~/.codex/AGENTS.override.md` 있으면 그것, 없으면 `~/.codex/AGENTS.md`)에 sentinel 블록으로
  병합. 기존 내용 보존.
- **Grok CLI**: 거버넌스를 user 스킬 `~/.agents/skills/hyeok-governance/SKILL.md`로 설치.
  Grok Build(Claude 호환)는 이 플러그인을 그대로 설치하면 훅 상시주입도 동작.
- caveman/ponytail 은 각자 설치기로 끌어오고 `config.json defaultMode`로 강도 고정
  (caveman=ultra, ponytail=full).
- **insane-search**: **Claude** = 이 플러그인 `dependencies`로 선언 → 설치 시 마켓플레이스
  (fivetaku/insane-search 소스)에서 **자동 전이설치**. **Codex/Grok** = `install.{ps1,sh} --upstream`이
  engine을 git clone(v0.8.2 핀)·벤더링하고 런처(`run-engine`)+deps(curl_cffi 등) 깔고, Codex는
  AGENTS.md에 호출 지시, Grok은 `~/.agents/skills/insane-search/` 스킬로. Python3 없으면 skip+경고.
