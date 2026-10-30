# 검토한 참고 소스

작업에 필요한 기능이 없을 때만 확인한다. 이 표는 설치 목록이 아니다.
제3자 코드는 해당 라이선스와 확인한 버전을 기록한 뒤 필요한 범위만 도입한다.

| 출처 | 사용할 상황 | 적용 방식 |
|---|---|---|
| [OpenAI 플러그인 예제](https://github.com/openai/plugins) | 패키징, 스킬 구조, 작업 인계 개선 | 최신 공식 문서와 함께 해당 예제만 확인. 구성요소별 라이선스 확인 |
| [공식 Build skills](https://learn.chatgpt.com/docs/build-skills)와 현재 `skill-creator` | 새 스킬 또는 호출 조건, 참조 구조 개선 | 제작기 사용, 짧은 진입점, 관련 자료만 읽기, 형식 검증 |
| [OpenAI Agents SDK의 code-change-verification](https://github.com/openai/openai-agents-python/blob/main/.agents/skills/code-change-verification/SKILL.md) | 코드 변경에 맞는 검사 설계 | 프로젝트에 맞는 명령과 실제 결과 기록 방식만 참고. SDK 설치 불필요 |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | 다수 요구사항, 우선순위, 수용 기준 정리 | [로컬 추적표](requirements-trace.md)로 필요한 구조만 사용. 전체 CLI 도입 불필요 |
| [Context7](https://github.com/upstash/context7) | 라이브러리 API와 버전 문서 | [MCP 구성](skill-and-mcp-setup.md)에 따라 현재 제공된 도구를 먼저 사용 |

`openai/skills`는 확인 당시 deprecated 상태로 새 설치의 기본 카탈로그로 쓰지 않는다.
`rupria/SK-AI-`는 대회를 언급한 개인 규칙서이며 주최측 지침이나 검증된 모델 성능 자료가 아니다.
라이선스가 확인되지 않은 코드는 복사하지 않는다. 현재 확인 범위에서 2차 예선 전용 고품질 스킬이
다수 공개됐다는 근거는 확보하지 못했다.

## 애니메이션과 3D 확장 후보

아래는 공개 원본과 MIT 라이선스를 확인한 선택 후보다. Codex에서 실제 실행 호환성은
검증하지 않았고 기본 설치에 포함하지 않았다. 필요한 상황에서 해당 스킬만 읽고
[도입 절차](skill-and-mcp-setup.md)로 검증한 뒤 사용한다. Claude용 설치 명령을 실행하지 않는다.

| 필요한 작업 | 참고 소스 | 가져올 내용과 조건 |
|---|---|---|
| CSV를 움직이는 차트나 인포그래픽으로 제작 | [iart-ai/data-animation-skills](https://github.com/iart-ai/data-animation-skills) | 데이터와 표현을 분리하고 수치, 단위, 최종 상태를 검증하는 방식. 시험에서는 자동 브라우저 렌더와 캡처 제외 |
| UI 모션과 데이터 전환 개선 | [dylantarre/animation-principles](https://github.com/dylantarre/animation-principles) | 필요한 모션 유형만 참고. 가독성, 동작 감소 설정과 축의 일관성 우선. 대규모 스킬 묶음 전체 설치 불필요 |
| 명시적인 Three.js 3D 구현 또는 성능 문제 | [CloudAI-X/threejs-skills](https://github.com/CloudAI-X/threejs-skills) | 프로젝트의 실제 Three.js 버전과 대조하고 필요한 geometry, performance 등의 스킬만 확인. 일반 차트나 문서에 3D 추가 금지 |

Threads 등 소셜 글은 후보 발견에만 사용한다. 실제 채택 전 공식 문서나 원본 저장소로 확인한다.
좋아요 목록, 개인 계정 정보, 비공개 게시물 내용을 배포 저장소에 넣지 않는다.

확인일: 2026-10-31. 유지 상태는 도입 시 다시 확인한다.
