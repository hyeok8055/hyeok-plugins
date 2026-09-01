---
name: hyeok-governance
description: >
  작업 라우팅·우선순위 규칙. ponytail(코드 최소화)·typst-korean(한글 Typst)·
  diagram-design(에디토리얼 다이어그램)·archify(인터랙티브 시스템 맵)·
  humanize-korean/im-not-ai(글·문서 윤문 필수) 중 무엇이 맡는지 정한다.
  코드 작성/수정, PDF·문서, 다이어그램/아키텍처 맵, 한국어 글·문서 산출 시 적용.
---

# hyeok-governance

자세한 규칙은 `GOVERNANCE.md`를 따른다. 요약:

| 계층 | 스킬 | 역할 |
|------|------|------|
| 1 | ponytail | 실행·배포 코드 양 (최소, 부실 금지) |
| 2 | typst-korean | Typst 한글 문서 (명시 요청 시만) |
| 3 | diagram-design | Editorial HTML+SVG 다이어그램 |
| 4 | archify | 인터랙티브 시스템 맵 (아키텍처 기본) |
| 5 | humanize-korean | 한글 AI 티 제거 — **글·문서 작업 필수** |

시스템/런타임 아키텍처·검증된 시퀀스·데이터플로우 맵 → **archify**.
가벼운 에디토리얼 도식 → **diagram-design**.
한국어 글·문서(슬랙/메일/보고서/카피 등) 전달 전 → **humanize-korean** (im-not-ai).
