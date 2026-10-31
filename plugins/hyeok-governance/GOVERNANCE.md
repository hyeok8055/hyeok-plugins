# Hyeok governance — OpenAI / Codex

Codex의 작업 흐름 정본은 [hyeok-governance 스킬](skills/hyeok-governance/SKILL.md)이다.
스킬 폴더만 설치해도 사용할 수 있도록 실행 지침과 참고 자료를 그 안에 함께 둔다.

- 복합 작업: [요구사항 → 근거 → 설계 → 구현 → 검증 → 정리 → 전달](skills/hyeok-governance/references/codex-flow.md)
- 모델 역할: [GPT-6.1 Sol / GPT-6 Luna](skills/hyeok-governance/references/model-routing.md)
- 도구 선택: [기존 스킬과 플러그인, MCP](skills/hyeok-governance/references/tool-routing.md)
- 필요한 기능 확장: [공식 스킬 제작기, Context7, MCP 구성](skills/hyeok-governance/references/skill-and-mcp-setup.md)
- 공모전과 평가: [주최측 규정 적용](skills/hyeok-governance/references/organizer-rules.md)
- 시각화 유형: [시각화 목록](skills/hyeok-governance/references/viz-catalog.md)

실행 코드에는 필요한 최소 변경과 필수 검증을 유지한다. 일반 보고서와 신규 PDF 보고서는 사용자의 기본 선호인
Typst를 사용한다. 명시된 제출 형식과 기존 문서 형식은 우선한다. 시각화는 목적에 맞는 스킬을 선택한다.
한국어 보고서, 제안서, 이력서는 `juhyeoknizer`로 작성하고 점검한다. 일반 채팅은 제외한다.

기본 지원 대상은 OpenAI/Codex다. Claude, Grok 전용 훅, 명령은 Codex의 기능으로 가정하지 않는다.
모델과 권한은 임의로 바꾸지 않는다. 필요한 MCP 설정은 사용자 요청 범위에서 수행하고
설정 저장과 실제 연결 검증을 구분한다. 주최측 규정과 현재 플랫폼의 제한을 우선한다.
스킬의 지침은 하드 보안 장치가 아니다. 실제 실행 여부와 검증 결과를 구분해서 보고한다.
