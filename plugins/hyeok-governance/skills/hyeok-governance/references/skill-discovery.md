# 필요한 공개 스킬을 빠르게 찾기

기능에 맞는 스킬을 찾아 쓰려는 요청, 현재 도구의 기능 부족, 전문 디자인이나 구현 지침이
필요한 경우에 읽는다. 단순 수정마다 외부 검색을 반복하지 않는다. 사용자가 준 저장소 URL이
있으면 그 원본부터 확인한다. 목적은 필요한 스킬을 찾아 적용하는 것이며 목록 확장 자체가 아니다.

## 먼저 볼 경로

| 출처와 성격 | 실제 탐색 위치 | 잘 맞는 작업 |
|---|---|---|
| [OpenAI plugins](https://github.com/openai/plugins), OpenAI 운영 카탈로그 | `plugins/<plugin>/skills/<skill>/SKILL.md`. 개별 공급자는 별도 확인 | Codex 작업, 제품 연동, 문서와 웹 구현 |
| [Vercel agent-skills](https://github.com/vercel-labs/agent-skills), Vercel 공식 모음 | `skills/react-best-practices`, `skills/composition-patterns`, `skills/web-design-guidelines` | React/Next.js 성능, 컴포넌트 설계, 웹 UI 품질 |
| [Anthropic skills](https://github.com/anthropics/skills), Anthropic 공식 모음 | `skills/frontend-design`, `skills/canvas-design`, `skills/mcp-builder` | 프런트엔드 시각 설계, 정적 디자인, MCP 구현 참고 |
| [Anthropic plugins](https://github.com/anthropics/claude-plugins-official), Anthropic 운영 카탈로그 | `plugins/<plugin>/skills/<skill>/SKILL.md`, 연결된 외부 원본 | 공식 스킬과 플러그인 내부의 재사용 가능한 지침 |
| [GitHub awesome-copilot](https://github.com/github/awesome-copilot), GitHub 조직의 커뮤니티 기여 모음 | `skills/<skill>/SKILL.md`, 필요하면 `.github/skills` | GitHub Actions, 테스트, 코드 리뷰, 언어와 프레임워크별 작업 |
| [skills.sh](https://skills.sh/), 공개 스킬 검색 인덱스 | 기능 키워드 검색 후 원본 GitHub 저장소로 이동 | 공급자를 모를 때 여러 경로에서 후보 발견 |
| [Vercel find-skills](https://github.com/vercel-labs/skills/blob/main/skills/find-skills/SKILL.md), 공식 탐색 스킬 | `vercel-labs/skills`의 `skills/find-skills/SKILL.md` | 스킬을 찾는 방법과 CLI 검색. 제공돼 있으면 활용 |
| [taste-skill](https://github.com/Leonxlnx/taste-skill), 개인 공개 원본 | `skills/taste-skill/SKILL.md`, 선언 이름 `design-taste-frontend` | 웹사이트와 앱 화면의 시각 방향, 상투적인 UI 개선 |

카탈로그 운영 주체와 개별 스킬 작성자를 구분한다. GitHub에 있다는 이유만으로 GitHub 공식
스킬이라 부르지 않는다. [GitHub Skills](https://github.com/skills)는 GitHub 학습 과정 모음이므로 에이전트 스킬 검색과 혼동하지 않는다.
`openai/skills`는 확인 당시 deprecated이므로 새 탐색의 기본 경로는 `openai/plugins`다.

## 기능에 맞춰 바로 좁히기

- **React/Next.js 성능:** Vercel `react-best-practices`; 컴포넌트 API 설계는 `composition-patterns`.
- **웹 UI 구현과 시각 개선:** Anthropic `frontend-design` 또는 taste-skill 중 목적과 실행 조건에 맞는 하나.
  접근성과 웹 UI 점검은 Vercel `web-design-guidelines`를 해당 검토 단계에서 사용한다.
- **GitHub Actions와 코드 검토:** `github/awesome-copilot/skills`에서 해당 언어와 기능명으로 탐색한다.
  이 저장소의 Copilot 에이전트 설정을 Codex 설정으로 그대로 설치하지 않는다.
- **한글 보고서:** 기존 `juhyeoknizer`와 `typst-korean` 우선. 지정 형식의 기능이 부족할 때만 외부 후보 탐색.
- **도식과 수치 차트:** [현재 시각화 선택](viz-catalog.md) 우선. 디자인 스킬을 데이터 정확성 검사로 대신하지 않는다.
- **새 스킬 제작:** 현재 제공된 OpenAI `skill-creator` 우선. 다른 공급자의 제작기는 필요한 기법만 참고한다.

적합한 후보가 있으면 바로 원문 검토로 넘어간다. 첫 후보가 조건에 맞으면 전 공급자를 훑지 않는다.
구체적인 URL을 받았거나 사용자가 선호하는 스킬이 있으면 브랜드 순위보다 그 선택이 우선한다.
이 표는 탐색 시작점이다. 목록에 없는 공급자는 해당 제품의 공식 문서와 공개 저장소에서
`Agent Skills`, `SKILL.md`, 작업 기능명으로 찾는다. GitHub 밖의 공개 배포 경로도 원본과 이용 조건을 확인해 검토한다.

## 검색 방법

1. 현재 세션의 설치 목록과 기존 프로젝트 스킬을 먼저 확인한다.
2. 위 표에서 작업에 맞는 원본을 열고 README의 목차, 저장소 파일 트리, 해당 `SKILL.md`만 읽는다.
   중첩 플러그인, 숨김 `.github/skills`, 표준 `skills` 경로까지 확인한다.
   파일 트리가 잘렸거나 경로가 옮겨졌으면 해당 하위 폴더나 README의 이동 안내를 따라간다.
3. 원본을 내려받은 경우 아래처럼 실제 파일을 찾는다. `rg`가 없으면 서버의 기본 파일 검색을 쓴다.

```bash
rg --files --hidden -g SKILL.md -g '!.git/**' /path/to/public-repo
rg -n -i 'react|accessibility|frontend|design' /path/to/public-repo --glob SKILL.md --hidden
```

4. 원본을 모르면 `skills.sh` 또는 허용된 검색 도구에서 공개 기능명으로 검색한다.
   예: `site:github.com/vercel-labs "SKILL.md" accessibility`, `site:github.com "SKILL.md" typst`.
   Node/npm과 네트워크 사용이 허용되고 별도 CLI 검색이 유용한 경우에만 Vercel의
   [skills CLI](https://github.com/vercel-labs/skills)를 사용한다. `npx`는 실행 패키지를 내려받을 수 있다.

```bash
npx skills find "react accessibility"
npx skills find "frontend design"
npx skills find react --owner vercel-labs
```

검색은 설치와 별개다. Node가 없으면 파일 트리와 공식 웹 문서로 찾으며, 검색 때문에 실행기를
새로 설치하지 않는다. 인기 순위는 탐색 신호일 뿐이다. 원본의 라이선스, 현재 경로와 실행 조건을 확인한다.
시험 문제, 코드, 파일, 오류 원문을 검색어에 넣지 않는다. 대회에서는 허용된 플랫폼 도구로만 조회한다.
Vercel `find-skills`를 사용할 때도 이 모음집의 설치 범위를 따른다. 원문의 전역 `-g` 설치 예시나
인기 수치 기준을 그대로 강제하지 않는다. 프로젝트 목적과 실제 내용으로 선택하고 필요한 폴더만 설치한다.

## 후보에서 사용까지

후보의 이름, 원본 URL, 정확한 스킬 폴더, 선택 커밋, 라이선스, 필요한 런타임과 외부 호출을 확인하고
[도입 절차](skill-and-mcp-setup.md#공개-스킬을-필요한-시점에-가져오는-흐름)로 연결한다.
전체 모음 대신 필요한 폴더와 자원만 프로젝트에 설치한다. 같은 문제를 해결하는 스킬을 겹쳐 로드하지 않는다.
허용된 일반 공개 도입마다 사용자에게 재확인을 요구하지 않는다. 인증, 비용, 권한 확대는 별도 범위다.

Claude용 공개 문서 활용과 Claude 모델/CLI 실행은 별개다. 공급자 이름 때문에 문서 후보를 배제하지 않고,
라이선스와 호환성을 확인한 뒤 Codex에 맞는 지침만 사용한다. Claude 전용 hooks, slash 명령,
도구명과 외부 모델 연결은 자동으로 이식하지 않는다. 공식 카탈로그라도 개별 라이선스가 우선한다.
특히 Anthropic의 docx/pdf/pptx/xlsx는 source-available로 안내되므로 모음 전체를 Apache 2.0으로 취급하지 않는다.

### taste-skill 확인 사항

2026-10-31 원본 커밋 `12af471f627f866411b4bd785b19646d3672784c`에서 실제 경로와 MIT 라이선스를
확인했다. 원본의 전체 실행은 Node 22 이상, Chrome/Edge/Chromium과 브라우저 검사에 의존한다.
사진 검색에는 외부 네트워크가 필요하며 각 이미지의 이용 조건은 코드의 MIT 라이선스와 별개다.

일반 개발에서는 이 조건이 충족될 때 선택 후보로 사용한다. 이번 대회처럼 Computer Use가 금지된
환경에서는 원본의 전체 실행을 활성화하지 않는다. 필요한 디자인 원칙만 참고하거나 브라우저 의존성이
없는 다른 후보를 선택한다. 브라우저 검사를 생략하고 원본 검증을 통과했다고 보고하지 않는다.
원본 README에 이전 스킬의 이동 안내가 있으므로 오래된 설치 이름으로 실패하면 새 저장소와 경로부터 확인한다.

확인 범위: 위 6개 GitHub 원본에서 실제 스킬 경로와 파일 트리를 확인했다. 모든 스킬의 실행을 검증하거나
모든 구성요소의 재배포를 허가한 목록은 아니다. 도입 시 선택한 스킬만 다시 확인한다.
