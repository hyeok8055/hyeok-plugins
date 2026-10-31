# hyeok-plugins

윤주혁이 실제 작업 서버의 Codex CLI에서 사용하는 작업 모음집.
조사, 구현, 검증, 문서와 시각화 작업에 맞는 스킬을 선택하고,
MCP가 필요하면 대상 서버의 설정 수단과 권한에 맞게 구성한다.
데스크톱 앱, Aside, Windows 경로, 개인 PC에 설치된 런타임을 전제로 하지 않는다.

| 구성 | 역할 |
|---|---|
| `hyeok-governance` | 작업 단계, Sol/Luna 인계, 스킬 선택, 필요한 MCP 구성, 주최측 규정 적용 |
| `juhyeoknizer` / 주혁나이저 | 주혁의 보고서, 제안서, 이력서, 개인 글 작성과 교정. 가운데점 금지, 사실 보존 |
| `archify` | 아키텍처, 워크플로, 호출 순서, 데이터 흐름, 상태 맵 |
| `diagram-design` | 개념과 프로세스 도식 |
| `lieflat-charts` | 수치 차트와 명시 요청한 보고서. PolyForm Noncommercial 적용 |
| `typst-korean` | 일반 보고서와 신규 PDF 보고서의 기본 도구. 한글 조판과 표, 출처, PDF 검증. Word/Markdown 등 지정 제출 형식 우선 |

기존 `humanize-korean`은 주혁나이저로 대체했다. 두 스킬을 함께 설치하지 않는다.
Claude와 Grok 설치, 전용 훅 자동 실행은 기본 경로에서 제외했다.

## 제공 서버에서 시작

공개 저장소의 최신 버전을 실제 과제 작업 폴더의 터미널에서 내려받아 실행한다.
시험 환경에서는 주최측의 공개 자료 반입 조건과 제공 Codex 버전을 먼저 확인한다.

```sh
# 현재 위치는 실제 과제 작업 폴더
codex --version
toolkit_dir="$(mktemp -d)"
git clone --depth 1 https://github.com/hyeok8055/hyeok-plugins.git "$toolkit_dir"
sh "$toolkit_dir/scripts/setup-codex-workspace.sh" --workspace "$PWD"
```

일반 서버에서는 설치한 작업 폴더에서 `codex`를 실행한다. 대회 플랫폼에 Codex 세션이 이미 열려 있으면
그 세션을 사용하고 안내된 재로딩 절차를 따른다. 관리 프로세스를 종료하거나 별도 인증을 시작하지 않는다.

새 설치기는 작업 폴더의 `.agents/skills`에 6개 스킬과 자원을 복사하고 프로젝트의
AGENTS 안내에 작은 블록을 병합한다. 기존 과제 지침은 보존하고 변경 파일은 작업 폴더의
`.hyeok/backups`에 백업한다. 홈 디렉터리와 Codex 설정, 모델, 인증, MCP, 권한, 버전은 변경하지 않는다.
설치 자체에는 POSIX 셸과 기본 파일 명령만 필요하며 Python이나 Node.js는 필요하지 않다.
빈 override 파일이 기존 지침을 가리지 않게 처리한다. 별도 fallback 지침을 사용하는 서버는
[서버 CLI 가이드의 `--fallback-file` 절차](plugins/hyeok-governance/skills/hyeok-governance/references/server-cli.md)를 따른다.

최신 Codex는 스킬 변경을 자동 감지한다. `/skills`나 `$` 목록에서 확인하고,
AGENTS 지침은 새 세션에 반영되는지도 확인한다. 구버전이나 관리형 세션에서 갱신되지 않으면 다음처럼 요청한다.
기능이 없다는 이유로 Codex를 업데이트하지 않는다.

```text
현재 과제의 README와 적용되는 AGENTS 지침, 주최측 안내를 먼저 읽어줘.
.agents/skills/hyeok-governance/SKILL.md를 읽고 이 과제에 필요한 스킬만 사용해줘.
현재 허용된 모델과 도구를 확인하고, 구현과 검증 결과를 구분해서 기록해줘.
MCP가 필요하면 기존 연결을 먼저 확인하고, 없으면 플랫폼이 허용한 설정 방법으로 필요한 항목을 준비해줘.
```

| 서버에서 확인할 항목 | 사용하는 기능 | 없을 때 |
|---|---|---|
| 제공된 Codex와 모델 목록 | Sol/Luna 작업 흐름 | 현재 허용 모델로 수행. 개인 키나 외부 모델로 대체하지 않음 |
| Node.js | Archify와 JS 검증기 | 필요한 런타임의 설치 허용 여부 확인. 실행하지 않은 검증은 미실행으로 기록 |
| Python 3 | 주혁나이저와 도식 검사기 | 실제 설치된 실행기 탐색. 개인 PC의 실행 경로를 복사하지 않음 |
| 공식 skill-creator, openai-docs | 스킬 작성과 공식 문서 확인 | 제공 여부부터 확인. 공식 문서와 허용된 공개 자원으로 보완 |
| 서브에이전트 기능 | 독립 작업의 병렬 위임 | 같은 Codex에서 역할을 순서대로 수행 |
| MCP와 외부 문서 접근 | 필요한 최신 문서나 데이터 | 허용된 설정 수단 확인. 시험 자료를 외부로 전송하지 않음 |
| GUI나 브라우저 자동화 | 일반 환경의 선택적 화면 검증 | CLI와 정적 검증. 시험에서는 자동 UI 조작 대신 참가자가 플랫폼 Browser로 확인 |

자세한 적용 순서: [서버 CLI 가이드](plugins/hyeok-governance/skills/hyeok-governance/references/server-cli.md).

프로젝트 설치로 활성화되는 것은 6개 **스킬의 파일과 안내 지침**이다. 플러그인 설치, MCP 연결,
모델 전환, 서브에이전트 생성은 각각 별도 동작이며 설치만으로 실행되지 않는다.

## 일반 개발 환경의 다른 설치 방식

모든 프로젝트에서 쓸 개인 전역 설치는 `sh install.sh` 또는 Windows의 `install.ps1`을 사용한다.
이 방식은 `~/.agents/skills`와 Codex의 사용자 AGENTS를 갱신한다. 제공 서버의 기본 안내는 위의 프로젝트 설치다.
플러그인 CLI가 지원되면 `sh install.sh --mode plugins`도 선택할 수 있다.
프로젝트 스킬, 전역 스킬, 플러그인 중 같은 모음집을 중복 설치하지 않는다.
기존 전역 설치의 제거는 같은 모드의 `uninstall.sh` 또는 `uninstall.ps1`을 사용한다.

## 작업 흐름

요구사항 확인 → 근거 수집 → 설계 → 구현 → 검증 → 산출물 정리 → 전달.
작은 수정에 이 단계를 모두 강제하지 않는다.

- 새 스킬이나 개선 요청: 현재 제공된 공식 `skill-creator`를 읽고 작성 및 검증한다.
- 라이브러리 API와 버전 문서: 기존 Context7 연결 또는 공식 문서를 사용한다.
- Codex와 OpenAI 설정: `openai-docs`로 공식 문서와 실제 지원 범위를 확인한다.
- 공개 스킬 도입: 출처와 라이선스, 중복을 검토하고 제공되는 `skill-installer`를 사용한다.
- 필요한 MCP가 없을 때: 서버 공식 안내와 현재 CLI 옵션을 확인하고 해당 연결만 구성한다.
- 산출물: 현재 제공되는 Word, PDF, 슬라이드, 시트 스킬을 형식에 맞게 사용한다.
- 일반 보고서와 신규 PDF 보고서: 주혁나이저로 본문을 정리하고 `typst-korean`으로 조판한다. Word나 Markdown 제출을 지정하면 해당 형식이 우선한다.

보고서 템플릿은 짧은 문서에 표지와 목차를 강제하지 않는다. 긴 표의 반복 머리행과 페이지 넘김,
캡션, 출처와 본문 참조를 지원한다. 컴파일 후 한글, 누락된 행, 여백과 가운데점 부재를 로컬에서 확인한다.
절차와 예시는 [Typst 보고서 작성](plugins/typst-korean/skills/typst-korean/references/report-workflow.md)에 있다.

부족한 기능에 맞는 공개 스킬은 원본, 라이선스, 실행 코드와 외부 전송을 확인한 뒤 필요한 폴더만
과제의 `.agents/skills`에 추가할 수 있다. 선택 커밋과 출처, 사용 범위, 로컬 검증 결과를 기록한다.
항상 전체 묶음을 설치하거나 매 작업마다 업데이트하지 않는다.

공개 스킬을 빠르게 찾는 경로는 [기능별 스킬 탐색](plugins/hyeok-governance/skills/hyeok-governance/references/skill-discovery.md)에 있다.
OpenAI, Vercel, Anthropic의 배포처, GitHub 커뮤니티 모음과 skills.sh에서 실제 `SKILL.md`를 찾고
필요한 항목만 적용한다. 개인 공개 `taste-skill`도 웹 UI 디자인 후보로 포함했다.
공식 카탈로그와 개인 소스, Claude용 문서 활용과 Claude 실행은 구분한다. 시험의 실행 제한은 그대로 우선한다.

선택적인 MCP를 모든 작업의 필수 의존성으로 묶지 않는다. 인증이나 비용, 권한 확대가 필요한
부분만 사용자에게 요청한다. 설정 저장, 도구 연결, 실제 호출 성공은 각각 확인한다.

GPT-6.1 Sol과 GPT-6 Luna의 역할은 [모델 배분](plugins/hyeok-governance/skills/hyeok-governance/references/model-routing.md)에 정리했다.
이는 작업 정책이며 성능 보증이나 자동 모델 전환 설정이 아니다. 실제 세션에서 허용된 모델을 사용한다.

## MCP 적용 흐름

기존 연결 확인 → 현재 작업에 필요한 기능 판단 → 공식 설정 확인 → 해당 환경에 저장 → 도구 호출 검증.

| 상황 | 설정 방법 | 완료 확인 |
|---|---|---|
| 대회 제공 서버 | 실제 MCP 탭의 JSON 형식을 확인하고 필요한 항목을 작성. 참가자가 UI에서 저장 | 플랫폼의 재로딩 절차 후 도구 노출과 공개 정보 읽기 확인 |
| 일반 서버의 프로젝트 연결 | 신뢰된 프로젝트의 `.codex/config.toml`에 해당 MCP 항목만 병합 | 새 세션의 `/mcp`와 작은 읽기 호출 |
| 일반 서버의 사용자 연결 | 지원되는 `codex mcp add` 사용. 사용자 프로필에 저장됨 | 구성 목록과 실제 호출을 각각 확인 |
| 이미 연결됐거나 필요 없음 | 기존 도구 또는 로컬 기능 사용 | 추가 설정 없이 해당 작업 검증 |

OpenAI 설정은 공식 문서와 OpenAI Docs MCP, 라이브러리 API는 Context7 또는 해당 공식 문서를 사용한다.
문서 스킬과 MCP 서버는 별도 구성이다. `codex mcp list` 성공만으로 연결 완료라고 보고하지 않는다.
일반 개발용 개인 키와 OAuth 예시는 대회에 그대로 적용하지 않는다.
세부 예시와 적용 조건은 [스킬과 MCP 구성](plugins/hyeok-governance/skills/hyeok-governance/references/skill-and-mcp-setup.md)을 따른다.

## 주혁나이저

보고서는 배경의 명사구, 한계의 개조식, 기술 설명의 현재형을 구분한다.
계층 기호, 보충 근거, 연도 축약, 배경과 목적의 마감문을 문서에 맞게 적용한다.
이력서는 경험마다 다른 비중과 문장 길이를 살리고 행동과 확인된 결과를 구체적으로 적는다.

새로 쓰는 본문에는 가운데점을 쓰지 않는다. 원문 인용, URL, 코드 등 정확성이 필요한 부분은
보존하고 필요한 경우 간접 인용한다. 없는 수치, 경력, 법령, 서비스 결함을 만들지 않는다.
`check_prose.py`는 기호와 문장 문제를 찾는 읽기 전용 검사기이며 AI 작성 여부를 판정하지 않는다.

```text
주혁나이저로 이 메모를 기획서 초안으로 정리해줘.
확인된 사실만 사용하고 필요한 근거는 별도로 표시해줘.
```

## 공모전과 감독형 평가

주최측의 최신 안내, 과제 README, 제공 환경의 제한을 우선한다.
SK하이닉스 2차 예선용 준비에서는 제공된 Codex와 허용 모델을 사용한다.
공개 스킬과 도구의 허용이 외부 AI, 문제 반출, Computer Use의 허용을 뜻하지 않는다.
AI 사용이 금지된 후속 서술형 단계에는 주혁나이저도 사용하지 않는다.
사용자가 제공한 `[general rule]`이 모델 권장 목록보다 우선한다. 권장 목록은 Sol 6.1,
Terra 5.6, Luna 6, Sol 6.0이며 Astra 제한과 제공 환경의 실제 접근 권한을 함께 확인한다.
외부 스킬과 일부 알고리즘 활용은 가능하지만 외부 완성본으로 결과물 전체를 대체하지 않는다.

개인 PC의 비공개 스킬 업로드는 허용되지 않는다. 사용할 변경본이 공개 저장소에서
내려받을 수 있는 상태인지 확인한다. 이 설치기는 공개 게시나 Git push를 하지 않는다.

세부 적용: [주최측 규정](plugins/hyeok-governance/skills/hyeok-governance/references/organizer-rules.md).
개인 접속 링크, 원본 안내 PDF, 응시 정보는 이 저장소에 포함하지 않는다.

## 검증과 출처

2026-10-31 공식 문서 재검토에서 실제 설치 동작과 설정 범위를 수정했다.

| 이전 상태 | 반영 결과 |
|---|---|
| 빈 override가 기존 과제 지침을 가릴 수 있었음 | 첫 번째 비어 있지 않은 지침 선택, fallback 파일 보존 옵션 |
| 상위 저장소의 동일 스킬을 놓칠 수 있었음 | Git 루트까지 중복 검사 |
| MCP 사용자/프로젝트/플랫폼 설정 경계가 불명확했음 | 저장 범위와 프로젝트 신뢰 조건, 실제 호출 검증 분리 |
| 스킬 밖의 Typst 템플릿, 잘못 배치된 차트 메타데이터 | 독립 스킬 복사에 필요한 자원을 스킬 내부에 포함 |
| 보고서에 Typst를 명시해야 했음 | 일반 보고서와 신규 PDF의 기본 흐름으로 지정. 제출 형식 우선 |

프로젝트 스킬 복사와 `.codex-plugin/plugin.json` 호환 패키징은 공식 지원 구조를 유지한다.
최신 portable plugin 형식으로 바꾸는 것만을 목적으로 제공 CLI의 버전을 올리지 않는다.

```bash
python3 scripts/check-codex-packaging.py
python3 -m unittest discover -s scripts -p 'test_*.py'
node scripts/test-install-codex.cjs
node scripts/test-workspace-setup.cjs
```

Node.js가 없는 Linux/WSL 개발 환경에서는 `python3 -B scripts/test_workspace_setup.py`로
프로젝트 설치, 지침 보존, 중복 방지와 실제 스킬 자원 복사를 검증할 수 있다.

Python은 실제 설치된 Python 3 실행기를 지정한다. 공식 `skill-creator`의
`quick_validate.py`로 스킬 형식도 별도 검사한다. 패키징 검사 통과가 모든 실행 환경의 동작을 보증하지는 않는다.

이번 검토에서는 Linux 테스트 69개, 실제 스킬 자원 380개 복사와 공식 스킬 형식 검사 6개가 통과했다.
Typst 0.15.1과 Noto Sans KR로 짧은 보고서 1쪽, 긴 표 보고서 5쪽을 컴파일하고 로컬에서 확인했다.
긴 표의 합성 자료 80행과 반복 머리행을 검사했다. 대회 서버의 실제 실행과 MCP 연결은 별도 확인 대상이다.

개발 환경에서 현재 Codex CLI의 MCP 저장 범위와 문서 예시를 확인하려면
`python3 scripts/check-codex-mcp-config.py`를 실행한다. Python 3.11 이상과 Codex CLI가 필요하다.
이 검사는 임시 프로필에서 설정의 저장, 해석, 프로젝트 신뢰 조건만 확인하며 실제 MCP에 연결하지 않는다.
관리형 대회 세션에서 실행하는 설치 절차가 아니다.

각 외부 구성의 `SOURCE.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md`를 유지한다.
`lieflat-charts`는 비상업 라이선스이므로 모든 공모전과 업무에 적용 가능하다고 단정하지 않는다.
적합성을 확인하지 못한 상황은 허용되는 일반 차트 도구로 작성한다.

- [공식 스킬 작성 안내](https://learn.chatgpt.com/docs/build-skills)
- [공식 MCP 설정](https://learn.chatgpt.com/docs/extend/mcp)
- [공식 플러그인 패키징](https://developers.openai.com/plugins/build/plugins)
- [필요한 스킬과 MCP 구성](plugins/hyeok-governance/skills/hyeok-governance/references/skill-and-mcp-setup.md)
- [검토한 참고 소스](plugins/hyeok-governance/skills/hyeok-governance/references/source-catalog.md)
