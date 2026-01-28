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

---

## 한글 특화 예제

### 한글 날짜 서식

```typst
// 현재 날짜 (한글 형식)
#let 오늘 = datetime.today()
#오늘.display("[year]년 [month]월 [day]일")

// 요일 포함
#let 요일 = ("일", "월", "화", "수", "목", "금", "토")
#오늘.display("[year]년 [month]월 [day]일") (#요일.at(오늘.weekday()))요일
```

### 한국식 문서 번호 체계

```typst
// 가, 나, 다 순서 리스트
#let 가나다 = ("가", "나", "다", "라", "마", "바", "사", "아", "자", "차", "카", "타", "파", "하")

#for (i, 항목) in (("첫 번째", "두 번째", "세 번째")).enumerate() {
  [#가나다.at(i). #항목 #linebreak()]
}

// ㄱ, ㄴ, ㄷ 순서 (하위 항목용)
#let ㄱㄴㄷ = ("ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ")
```

### 한글 제목 번호 매기기

```typst
// 제1장, 제2장 형식
#set heading(numbering: (..nums) => {
  let n = nums.pos()
  if n.len() == 1 {
    "제" + str(n.first()) + "장 "
  } else if n.len() == 2 {
    str(n.at(0)) + "." + str(n.at(1)) + " "
  } else {
    numbering("1.1.1", ..n)
  }
})
```

### 원 숫자

```typst
#let 원숫자 = ("①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩")

#for i in range(5) {
  [#원숫자.at(i) 항목 #(i + 1) #linebreak()]
}
```

---

## 대체 폰트 프리셋

### Noto Sans KR (고딕)

Google Fonts에서 제공하는 범용 고딕체:

```typst
#set text(
  font: ("Noto Sans KR", "Pretendard", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
)
```

### Noto Serif KR (명조)

논문, 서적 등 명조체가 필요한 경우:

```typst
#set text(
  font: ("Noto Serif KR", "Batang", "AppleMyungjo"),
  lang: "ko",
  region: "KR",
)
```

### IBM Plex Sans KR

프레젠테이션이나 세련된 문서용:

```typst
#set text(
  font: ("IBM Plex Sans KR", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
)
```

### Spoqa Han Sans Neo

스타트업/IT 업계에서 인기 있는 폰트:

```typst
#set text(
  font: ("Spoqa Han Sans Neo", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
)
```

### 코드용 고정폭 폰트

코드 블록이나 기술 문서용:

```typst
// D2Coding
#show raw: set text(font: ("D2Coding", "Noto Sans Mono CJK KR", "Consolas"))

// 또는 NanumGothicCoding
#show raw: set text(font: ("NanumGothicCoding", "D2Coding", "Consolas"))
```

---

## 에러 해결 FAQ

### 폰트 인식 안 될 때

**증상**: `unknown font family: Pretendard`

**해결 방법**:

1. 설치된 폰트 확인:
```bash
typst fonts | grep -i pretendard
```

2. 폰트 경로 지정:
```bash
typst compile --font-path ./fonts document.typ
```

3. 대체 폰트 사용 (fallback 설정):
```typst
#set text(font: ("Pretendard", "Noto Sans KR", "Malgun Gothic"))
```

### typst 설치 안 됐을 때

**증상**: `command not found: typst`

**해결 방법**:

```bash
# Cargo (Rust)
cargo install typst-cli

# Homebrew (macOS)
brew install typst

# Scoop (Windows)
scoop install typst

# Arch Linux
pacman -S typst

# 또는 바이너리 직접 다운로드
# https://github.com/typst/typst/releases
```

### 한글 깨짐 문제

**증상**: 한글이 □□□로 표시됨

**원인**: 폰트가 없거나 `lang` 설정 누락

**해결 방법**:

```typst
// 1. lang, region 설정 추가
#set text(
  font: ("Pretendard", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
)

// 2. 시스템에 한글 폰트가 있는지 확인
```

```bash
# 사용 가능한 한글 폰트 확인
typst fonts | grep -iE "(noto|malgun|gothic|batang|gulim|dotum)"
```

### PDF 출력 시 이미지 깨짐

**증상**: 이미지 품질이 낮음

**해결 방법**:

```bash
# PPI 설정 (기본 144, 인쇄용은 300 권장)
typst compile --ppi 300 document.typ
```

### 컴파일 에러 디버깅

**일반적인 문법 에러**:

```typst
// 잘못된 예: 괄호 불일치
#set text(font: "Pretendard"  // ) 누락

// 잘못된 예: 콤마 누락
#set page(
  paper: "a4"    // , 누락
  margin: 2cm
)
```

에러 메시지의 줄 번호를 확인하고 해당 부분의 문법을 점검하세요.
