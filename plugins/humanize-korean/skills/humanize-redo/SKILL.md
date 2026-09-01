---
name: humanize-redo
description: >
  최근 humanize-korean 윤문 결과를 2차로 다시 다듬는다. 구 v2.1 멀티에이전트 파이프라인
  (korean-style-rewriter 등)은 쓰지 않는다. 기존 run_id를 재사용해 humanize-korean v2.3
  heavy 경로로 승급·재실행한다. 트리거 — "/humanize-redo", "2차 윤문", "이 카테고리만 다시".
argument-hint: "[조정 지시 — 예: \"번역투만 다시\" \"이 문단만\" \"강도 낮춰\"]"
disable-model-invocation: true
---

# /humanize-redo — 2차 윤문 (humanize-korean v2.3)

**구 파이프라인 금지.** `korean-style-rewriter` · `content-fidelity-auditor` · 옛 Phase B/C/D
에이전트 체인을 호출하지 않는다.

## 사용자 지시
$ARGUMENTS

## 동작 (v2.3)
1. `Glob`으로 `_workspace/YYYY-MM-DD-*/01_input.txt`(또는 `final.md`)를 매칭해 최신 `run_id` 식별.
   없으면 "`/humanize-korean`으로 먼저 실행하세요" 안내 후 종료.
2. **humanize-korean** 스킬을 연다. 부분 재실행으로 취급:
   - 기존 `run_id` 재사용
   - 경로를 **heavy**로 승급 (`--strict` / 정밀 모드와 동일)
   - 사용자 지시(카테고리·문단·강도)를 윤문 입력 제약으로 전달
3. humanize-korean SKILL.md의 Phase 0→결과 전달을 따른다 (shim · route_hint · verify_gates).
4. 산출물은 같은 `_workspace/{run_id}/` 아래에 버전 구분 파일로 남긴다 (`final.md` 백업 후 갱신).

## 루프 한도
최대 round 3. 그 이상이면 사람 검토 권고.

## 참고
- 풀 신규 실행: `/humanize-korean` 또는 `/humanize`
- 분류 체계: `humanize-korean/references/ai-tell-taxonomy.md`
