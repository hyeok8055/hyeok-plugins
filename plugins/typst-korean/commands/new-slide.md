---
description: 장표/프레젠테이션 슬라이드 템플릿을 생성합니다 (폰트 선택 가능)
---

# 슬라이드 템플릿 생성

장표/프레젠테이션용 Typst 문서를 생성합니다.

## 인자 처리
- `$ARGUMENTS`에서 파일명 추출 (`.typ` 확장자 자동 추가)
- 파일명이 없으면 `slides.typ` 사용

## 폰트 선택

프레젠테이션에 적합한 폰트를 선택하도록 물어보세요 (선택 안 하면 **Pretendard** 기본값):

| 폰트 | 추천 용도 |
|------|-----------|
| **Pretendard** (기본값) | 깔끔한 비즈니스 발표 |
| **Noto Sans KR** | 공식적인 발표 |
| **IBM Plex Sans KR** | 테크/디자인 발표 |
| **Spoqa Han Sans Neo** | 스타트업/IT 발표 |

## 생성할 템플릿

선택한 폰트로 다음 템플릿을 생성하세요:

```typst
// 슬라이드 설정
#let 발표제목 = "발표 제목"
#let 발표자 = "발표자"
#let 날짜 = datetime.today().display("[year]년 [month]월 [day]일")

// 폰트 설정 (선택한 폰트 + fallback)
#set text(
  font: ("선택한폰트", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
  size: 20pt,
)

// 슬라이드 페이지 설정 (16:9 비율)
#set page(
  paper: "presentation-16-9",
  margin: (x: 2cm, y: 1.5cm),
  footer: context {
    set align(right)
    set text(size: 12pt, fill: gray)
    [#counter(page).display() / #counter(page).final().first()]
  },
)

// 문단 설정
#set par(
  leading: 1.2em,
  justify: false,
)

// 제목 슬라이드 스타일
#let 표지슬라이드(제목, 부제목: none, 발표자: none, 날짜: none) = {
  set page(footer: none)
  align(center + horizon)[
    #text(size: 44pt, weight: "bold")[#제목]
    #if 부제목 != none {
      v(0.5em)
      text(size: 24pt, fill: gray)[#부제목]
    }
    #v(2em)
    #if 발표자 != none {
      text(size: 20pt)[#발표자]
    }
    #if 날짜 != none {
      v(0.3em)
      text(size: 16pt, fill: gray)[#날짜]
    }
  ]
}

// 섹션 구분 슬라이드
#let 섹션슬라이드(제목) = {
  set page(footer: none)
  align(center + horizon)[
    #text(size: 36pt, weight: "bold")[#제목]
  ]
}

// 일반 슬라이드 제목 스타일
#show heading.where(level: 1): it => {
  set text(size: 32pt, weight: "bold")
  v(0.3em)
  it
  v(0.5em)
  line(length: 100%, stroke: 2pt + rgb("#3498db"))
  v(0.5em)
}

#show heading.where(level: 2): it => {
  set text(size: 24pt, weight: "bold")
  v(0.3em)
  it
  v(0.3em)
}

// 강조 박스
#let 강조박스(내용, 색상: rgb("#3498db")) = {
  block(
    fill: 색상.lighten(90%),
    stroke: 2pt + 색상,
    radius: 8pt,
    inset: 1em,
    width: 100%,
  )[#내용]
}

// 2단 레이아웃
#let 이단(왼쪽, 오른쪽) = {
  grid(
    columns: (1fr, 1fr),
    gutter: 1em,
    왼쪽, 오른쪽
  )
}

// 3단 레이아웃
#let 삼단(첫번째, 두번째, 세번째) = {
  grid(
    columns: (1fr, 1fr, 1fr),
    gutter: 1em,
    첫번째, 두번째, 세번째
  )
}

// ===== 표지 =====
#표지슬라이드(
  발표제목,
  부제목: "부제목을 입력하세요",
  발표자: 발표자,
  날짜: 날짜,
)

// ===== 목차 =====
#pagebreak()
= 목차

+ 첫 번째 주제
+ 두 번째 주제
+ 세 번째 주제
+ 요약 및 결론

// ===== 섹션 1 =====
#pagebreak()
#섹션슬라이드([첫 번째 주제])

#pagebreak()
= 슬라이드 제목

- 핵심 포인트 1
- 핵심 포인트 2
- 핵심 포인트 3

#pagebreak()
= 2단 레이아웃 예시

#이단(
  [
    == 왼쪽 내용
    - 항목 1
    - 항목 2
    - 항목 3
  ],
  [
    == 오른쪽 내용
    - 항목 A
    - 항목 B
    - 항목 C
  ]
)

#pagebreak()
= 강조 박스 예시

#강조박스[
  *핵심 메시지*

  여기에 중요한 내용을 강조해서 표시합니다.
]

#v(1em)

일반 텍스트는 이렇게 표시됩니다.

// ===== 섹션 2 =====
#pagebreak()
#섹션슬라이드([두 번째 주제])

#pagebreak()
= 표 예시

#table(
  columns: (auto, 1fr, 1fr),
  inset: 10pt,
  align: horizon,
  [*항목*], [*값 A*], [*값 B*],
  [데이터 1], [100], [200],
  [데이터 2], [150], [250],
  [데이터 3], [200], [300],
)

// ===== 결론 =====
#pagebreak()
#섹션슬라이드([요약 및 결론])

#pagebreak()
= 핵심 요약

#강조박스(색상: rgb("#27ae60"))[
  + *첫 번째 결론*: 설명
  + *두 번째 결론*: 설명
  + *세 번째 결론*: 설명
]

#pagebreak()
= 감사합니다

#align(center + horizon)[
  #text(size: 24pt)[질문이 있으시면 말씀해 주세요]

  #v(1em)

  #text(size: 16pt, fill: gray)[#발표자 · #날짜]
]

```

### 폰트별 fallback 설정

| 선택 폰트 | fallback 순서 |
|-----------|---------------|
| Pretendard | `("Pretendard", "Noto Sans KR", "Malgun Gothic")` |
| Noto Sans KR | `("Noto Sans KR", "Pretendard", "Malgun Gothic")` |
| IBM Plex Sans KR | `("IBM Plex Sans KR", "Noto Sans KR", "Malgun Gothic")` |
| Spoqa Han Sans Neo | `("Spoqa Han Sans Neo", "Noto Sans KR", "Malgun Gothic")` |

## 슬라이드 유틸리티 함수

| 함수 | 용도 |
|------|------|
| `#표지슬라이드(제목, 부제목, 발표자, 날짜)` | 표지 페이지 |
| `#섹션슬라이드(제목)` | 섹션 구분 페이지 |
| `#강조박스(내용, 색상)` | 중요 내용 강조 |
| `#이단(왼쪽, 오른쪽)` | 2단 레이아웃 |
| `#삼단(첫번째, 두번째, 세번째)` | 3단 레이아웃 |

## 다른 템플릿 안내

- `/new` - 기본 문서
- `/new-report` - 보고서

## 실행 후
- 파일 생성 완료 메시지 출력
- `발표제목`, `발표자` 변수 수정 안내
- PDF 변환: `typst compile --font-path ./fonts slides.typ`
- 폰트가 없으면 `/install-font` 안내
