---
description: 목차, 페이지 번호, 머리글/바닥글이 포함된 한글 보고서 템플릿을 생성합니다 (폰트 선택 가능)
---

# 한글 보고서 템플릿 생성

사용자가 지정한 파일명으로 보고서용 Typst 문서를 생성합니다.

## 인자 처리
- `$ARGUMENTS`에서 파일명 추출 (`.typ` 확장자 자동 추가)
- 파일명이 없으면 `report.typ` 사용

## 폰트 선택

사용자에게 다음 중 선택하도록 물어보세요 (선택 안 하면 **Pretendard** 기본값):

| 폰트 | 추천 용도 |
|------|-----------|
| **Pretendard** (기본값) | 일반 보고서, 비즈니스 문서 |
| **Noto Sans KR** | 공식 보고서, 정부 문서 |
| **Noto Serif KR** | 학술 보고서, 연구 보고서 |
| **IBM Plex Sans KR** | 기술 보고서, 프레젠테이션 |

## 생성할 템플릿

선택한 폰트로 다음 템플릿을 생성하세요:

```typst
// 보고서 설정
#let 제목 = "보고서 제목"
#let 저자 = "작성자"
#let 날짜 = datetime.today().display("[year]년 [month]월 [day]일")

// 폰트 설정 (선택한 폰트 + fallback)
#set text(
  font: ("선택한폰트", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
  size: 11pt,
)

// 페이지 설정
#set page(
  paper: "a4",
  margin: (top: 3cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 9pt, fill: gray)
      #제목
      #h(1fr)
      #저자
    ]
  },
  footer: context {
    set align(center)
    set text(size: 9pt)
    [#counter(page).display("1")]
  },
)

// 문단 설정 (CJK 권장)
#set par(
  leading: 1.5em,
  first-line-indent: 1em,
  justify: true,
)

// 제목 스타일
#show heading.where(level: 1): it => {
  set text(size: 1.4em, weight: "bold")
  v(1em)
  it
  v(0.5em)
}

#show heading.where(level: 2): it => {
  set text(size: 1.2em, weight: "bold")
  v(0.8em)
  it
  v(0.4em)
}

// 표지
#align(center)[
  #v(5cm)
  #text(size: 24pt, weight: "bold")[#제목]
  #v(2cm)
  #text(size: 14pt)[#저자]
  #v(1cm)
  #text(size: 12pt)[#날짜]
]

#pagebreak()

// 목차
#outline(
  title: [목차],
  indent: auto,
)

#pagebreak()

// 본문 시작
= 서론

여기에 서론 내용을 작성하세요.

== 배경

== 목적

= 본론

== 첫 번째 주제

== 두 번째 주제

= 결론

= 참고문헌

```

### 폰트별 fallback 설정

| 선택 폰트 | fallback 순서 |
|-----------|---------------|
| Pretendard | `("Pretendard", "Noto Sans KR", "Malgun Gothic")` |
| Noto Sans KR | `("Noto Sans KR", "Pretendard", "Malgun Gothic")` |
| Noto Serif KR | `("Noto Serif KR", "Batang", "AppleMyungjo")` |
| IBM Plex Sans KR | `("IBM Plex Sans KR", "Noto Sans KR", "Malgun Gothic")` |

## 다른 템플릿 안내

- `/new` - 기본 문서
- `/new-slide` - 슬라이드/장표

## 실행 후
- 파일 생성 완료 메시지 출력
- `제목`, `저자` 변수 수정 안내
- 폰트가 없으면 `/install-font` 안내
