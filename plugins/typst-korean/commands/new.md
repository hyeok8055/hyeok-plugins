---
description: 한글 설정이 적용된 새 Typst 문서를 생성합니다 (폰트 선택 가능, 기본값: 프리텐다드)
---

# Typst 한글 문서 생성

사용자가 지정한 파일명으로 새 Typst 문서를 생성하세요.

## 인자 처리
- `$ARGUMENTS`에서 파일명 추출 (`.typ` 확장자 자동 추가)
- 파일명이 없으면 `document.typ` 사용

## 폰트 선택

`$ARGUMENTS`에 폰트명이 없으면, 사용자에게 다음 중 선택하도록 물어보세요:

| 폰트 | 특징 |
|------|------|
| **Pretendard** (기본값) | 현대적 고딕, 일반 문서용 |
| **Noto Sans KR** | Google 고딕, 다양한 굵기 |
| **Noto Serif KR** | Google 명조, 논문/서적용 |
| **IBM Plex Sans KR** | IBM 고딕, 세련됨 |
| **Spoqa Han Sans Neo** | 스포카 고딕, 깔끔함 |

사용자가 선택하지 않으면 **Pretendard**를 기본값으로 사용합니다.

## 생성할 템플릿

선택한 폰트에 맞게 템플릿을 생성하세요:

```typst
// 폰트 설정 (대체 폰트 포함)
#set text(
  font: ("선택한폰트", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
  size: 11pt,
)

// 페이지 설정
#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
)

// 문단 설정 (CJK 권장)
#set par(
  leading: 1.5em,
  first-line-indent: 1em,
  justify: true,
)

// 문서 내용을 여기에 작성하세요

```

### 폰트별 fallback 설정

| 선택 폰트 | fallback 순서 |
|-----------|---------------|
| Pretendard | `("Pretendard", "Noto Sans KR", "Malgun Gothic")` |
| Noto Sans KR | `("Noto Sans KR", "Pretendard", "Malgun Gothic")` |
| Noto Serif KR | `("Noto Serif KR", "Batang", "AppleMyungjo")` |
| IBM Plex Sans KR | `("IBM Plex Sans KR", "Noto Sans KR", "Malgun Gothic")` |
| Spoqa Han Sans Neo | `("Spoqa Han Sans Neo", "Noto Sans KR", "Malgun Gothic")` |

## 다른 템플릿 안내

- `/new-report` - 보고서 템플릿
- `/new-slide` - 슬라이드/장표 템플릿

## 실행 후
- 파일 생성 완료 메시지 출력
- 선택한 폰트가 설치되어 있는지 확인 안내
- 폰트가 없으면 `/install-font` 안내
