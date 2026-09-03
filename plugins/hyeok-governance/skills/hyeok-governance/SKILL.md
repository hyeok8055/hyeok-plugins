---
name: hyeok-governance
description: >
  작업 라우팅·우선순위 규칙. ponytail(코드 최소화)·typst-korean(한글 Typst)·
  시각화 그룹(archify 시스템맵 / diagram-design 에디토리얼 도식 / lieflat-charts 수치차트, Noncommercial)·
  humanize-korean/im-not-ai(기록용 글·문서 윤문 필수, 채팅 제외) 중 무엇이 맡는지 정한다.
  코드 작성/수정, PDF·문서, 다이어그램/아키텍처 맵/수치 차트, 남기는 한국어 글·문서 작업 시 적용.
---

# hyeok-governance

자세한 규칙은 `GOVERNANCE.md`를 따른다. 요약:

| 계층 | 스킬 | 역할 |
|------|------|------|
| 1 | ponytail | 실행·배포 코드 양 (최소, 부실 금지) |
| 2 | typst-korean | Typst 한글 문서 (명시 요청 시만) |
| 3–4 | **시각화 그룹** | 스킬은 `GOVERNANCE.md` §1.1. 타입은 `references/viz-catalog.md` (도구 호출 전) |
| 5 | humanize-korean | 한글 AI 티 제거 — **기록용 글·문서 필수** (채팅 제외) |

시각화: 수치 → **lieflat-charts**(벤더, Noncommercial) / 시스템맵 → **archify** / 그 외 도식 → **diagram-design**.
충돌: 시스템맵 archify>diagram, 수치 lieflat only, 둘이면 파일 둘. 사용자가 스킬을 지정하면 그걸 따른다.
타입 목록은 세션 주입하지 않음. 그릴 때만 `references/viz-catalog.md`를 연다.
남기는 한국어 글·문서 전달 전 → **humanize-korean**. 짧은 채팅 답은 비대상.
