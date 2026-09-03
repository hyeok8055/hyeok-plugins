---
name: hyeok-governance
description: >
  작업 라우팅·우선순위 규칙. ponytail(코드 최소화)·typst-korean(한글 Typst)·
  시각화 그룹(archify 시스템맵 / diagram-design 에디토리얼 도식 / lieflat-charts 수치차트)·
  humanize-korean/im-not-ai(기록용 글·문서 윤문 필수, 채팅 제외) 중 무엇이 맡는지 정한다.
  코드 작성/수정, PDF·문서, 다이어그램/아키텍처 맵/수치 차트, 남기는 한국어 글·문서 작업 시 적용.
---

# hyeok-governance

자세한 규칙은 `GOVERNANCE.md`를 따른다. 요약:

| 계층 | 스킬 | 역할 |
|------|------|------|
| 1 | ponytail | 실행·배포 코드 양 (최소, 부실 금지) |
| 2 | typst-korean | Typst 한글 문서 (명시 요청 시만) |
| 3–4 | **시각화 그룹** | 스킬+타입을 **도구 호출 전에** 고른다. 표는 `GOVERNANCE.md` §1.1 |
| 5 | humanize-korean | 한글 AI 티 제거 — **기록용 글·문서 필수** (채팅 제외) |

시각화 그룹(하나만, 타입까지 고르고 스킬 연다):
1. 수치 표/CSV/지표 차트 → **lieflat-charts** (외부, Noncommercial, 63형)
2. 시스템·런타임 맵 → **archify** (5 IR: architecture / workflow / sequence / dataflow / lifecycle)
3. 그 외 개념·프로세스 도식 → **diagram-design** (39형)

겹치면 시스템맵은 archify > diagram. 수치 차트는 lieflat only.
남기는 한국어 글·문서 전달 전 → **humanize-korean**. 짧은 채팅 답은 비대상.
