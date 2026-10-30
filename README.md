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
| `typst-korean` | Typst를 지정한 한글 문서와 `.typ` 파일 |

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
codex
```

새 설치기는 작업 폴더의 `.agents/skills`에 6개 스킬과 자원을 복사하고 프로젝트의
AGENTS 안내에 작은 블록을 병합한다. 기존 과제 지침은 보존하고 변경 파일은 작업 폴더의
`.hyeok/backups`에 백업한다. 홈 디렉터리와 Codex 설정, 모델, 인증, MCP, 권한, 버전은 변경하지 않는다.
설치 자체에는 POSIX 셸과 기본 파일 명령만 필요하며 Python이나 Node.js는 필요하지 않다.

현재 `/skills`나 `$` 목록에서 확인한다. 구버전 CLI에 해당 탐색 기능이 없으면
`.agents/skills/hyeok-governance/SKILL.md`를 읽도록 요청한다. 기능이 없다는 이유로 Codex를 업데이트하지 않는다.

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

선택적인 MCP를 모든 작업의 필수 의존성으로 묶지 않는다. 인증이나 비용, 권한 확대가 필요한
부분만 사용자에게 요청한다. 설정 저장, 도구 연결, 실제 호출 성공은 각각 확인한다.

GPT-6.1 Sol과 GPT-6 Luna의 역할은 [모델 배분](plugins/hyeok-governance/skills/hyeok-governance/references/model-routing.md)에 정리했다.
이는 작업 정책이며 성능 보증이나 자동 모델 전환 설정이 아니다. 실제 세션에서 허용된 모델을 사용한다.

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

개인 PC의 비공개 스킬 업로드는 허용되지 않는다. 사용할 변경본이 공개 저장소에서
내려받을 수 있는 상태인지 확인한다. 이 설치기는 공개 게시나 Git push를 하지 않는다.

세부 적용: [주최측 규정](plugins/hyeok-governance/skills/hyeok-governance/references/organizer-rules.md).
개인 접속 링크, 원본 안내 PDF, 응시 정보는 이 저장소에 포함하지 않는다.

## 검증과 출처

```bash
python3 scripts/check-codex-packaging.py
python3 -m unittest discover -s scripts -p 'test_*.py'
node scripts/test-install-codex.cjs
node scripts/test-workspace-setup.cjs
```

Python은 실제 설치된 Python 3 실행기를 지정한다. 공식 `skill-creator`의
`quick_validate.py`로 스킬 형식도 별도 검사한다. 패키징 검사 통과가 모든 실행 환경의 동작을 보증하지는 않는다.

각 외부 구성의 `SOURCE.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md`를 유지한다.
`lieflat-charts`는 비상업 라이선스이므로 모든 공모전과 업무에 적용 가능하다고 단정하지 않는다.
적합성을 확인하지 못한 상황은 허용되는 일반 차트 도구로 작성한다.

- [공식 스킬 작성 안내](https://learn.chatgpt.com/docs/build-skills)
- [공식 MCP 설정](https://learn.chatgpt.com/docs/extend/mcp)
- [공식 플러그인 패키징](https://developers.openai.com/plugins/build/plugins)
- [필요한 스킬과 MCP 구성](plugins/hyeok-governance/skills/hyeok-governance/references/skill-and-mcp-setup.md)
- [검토한 참고 소스](plugins/hyeok-governance/skills/hyeok-governance/references/source-catalog.md)
