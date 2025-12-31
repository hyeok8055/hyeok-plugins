# Typst 문법 레퍼런스

공식 문서: https://typst.app/docs

## 기본 문법

### 마크업 모드

```typst
= 제목 1
== 제목 2
=== 제목 3

*굵게*
_기울임_
`인라인 코드`

- 순서 없는 목록
- 항목 2

+ 순서 있는 목록
+ 항목 2

/ 용어: 설명
```

### 코드 모드

`#`으로 코드 표현식 시작:

```typst
#let 변수 = "값"
#let 함수(x) = x * 2

#if 조건 {
  [참일 때]
} else {
  [거짓일 때]
}

#for i in range(5) {
  [항목 #i]
}
```

### 주석

```typst
// 한 줄 주석
/* 여러 줄
   주석 */
```

## 텍스트 설정

```typst
#set text(
  font: "Pretendard",      // 폰트 (배열로 대체 폰트 지정 가능)
  size: 11pt,              // 크기
  weight: "regular",       // 굵기: thin, light, regular, medium, bold, black
  lang: "ko",              // 언어 코드
  region: "KR",            // 지역 코드
)
```

### 폰트 굵기 값

| 이름 | 값 |
|------|-----|
| thin | 100 |
| extralight | 200 |
| light | 300 |
| regular | 400 |
| medium | 500 |
| semibold | 600 |
| bold | 700 |
| extrabold | 800 |
| black | 900 |

## 페이지 설정

```typst
#set page(
  paper: "a4",                    // 용지 크기
  margin: (x: 2.5cm, y: 2.5cm),   // 여백
  header: [머리글],
  footer: [바닥글],
  numbering: "1",                 // 페이지 번호
)
```

### 용지 크기

`"a4"`, `"a5"`, `"us-letter"`, `"us-legal"` 등

### 여백 설정

```typst
margin: 2cm                       // 모든 방향
margin: (x: 2cm, y: 3cm)          // 좌우, 상하
margin: (top: 2cm, bottom: 3cm, left: 2cm, right: 2cm)
```

## 문단 설정

```typst
#set par(
  leading: 0.8em,         // 줄 간격
  justify: true,          // 양쪽 정렬
  first-line-indent: 1em, // 첫 줄 들여쓰기
)
```

## 제목 스타일링

```typst
#show heading.where(level: 1): it => {
  set text(size: 1.4em, weight: "bold")
  it
}
```

## 이미지

```typst
#image("path/to/image.png", width: 50%)
```

## 표

```typst
#table(
  columns: 3,
  [헤더1], [헤더2], [헤더3],
  [셀1], [셀2], [셀3],
)
```

## 수식

```typst
인라인: $E = m c^2$

블록:
$ sum_(k=0)^n k = (n(n+1))/2 $
```

## 링크

```typst
#link("https://example.com")[링크 텍스트]
```

## 참조

```typst
= 소개 <intro>

@intro 에서 설명한 것처럼...
```

## 함수 정의

```typst
#let 카드(제목, 내용) = block(
  stroke: 1pt,
  inset: 1em,
  radius: 4pt,
)[
  *#제목*
  #내용
]

#카드("제목", "내용입니다")
```
