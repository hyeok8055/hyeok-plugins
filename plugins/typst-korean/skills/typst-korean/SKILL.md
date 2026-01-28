---
name: typst-korean
description: Typst 문서 작성을 도와줍니다. 다양한 한글 폰트를 선택할 수 있고 (기본값: 프리텐다드), 한글 문서에 적합한 설정을 안내합니다. Typst 문법, 폰트 설정, 페이지 레이아웃 관련 질문에 사용합니다.
allowed-tools: Read, Write, Edit, Bash, Glob
file-patterns: ["**/*.typ"]
---

# Typst Korean - 한글 문서 작성 지원

Typst로 한글 문서를 작성할 때 도움을 제공합니다.

## 지원 폰트 (상업적 사용 무료)

문서 생성 시 사용자에게 폰트를 선택하도록 물어보세요. 기본값은 **Pretendard**입니다.

| 폰트 | 특징 | 추천 용도 |
|------|------|-----------|
| **Pretendard** (기본값) | Apple SF, Inter 스타일 | 일반 문서, UI |
| **Noto Sans KR** | Google Fonts 고딕 | 일반 문서, 웹 |
| **Noto Serif KR** | Google Fonts 명조 | 논문, 서적 |
| **NanumGothicCoding** | 네이버 고정폭 | 코드, 기술 문서 |
| **D2Coding** | 네이버 고정폭 | 코드, 기술 문서 |
| **IBM Plex Sans KR** | IBM 디자인 고딕 | 프레젠테이션 |
| **Spoqa Han Sans Neo** | 스포카 고딕 | UI, 웹 |

## 기본 폰트 설정 (Fallback 포함)

```typst
#set text(
  font: ("Pretendard", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
  size: 11pt,
)
```

### 폰트별 fallback 설정

| 선택 폰트 | fallback 순서 |
|-----------|---------------|
| Pretendard | `("Pretendard", "Noto Sans KR", "Malgun Gothic")` |
| Noto Sans KR | `("Noto Sans KR", "Pretendard", "Malgun Gothic")` |
| Noto Serif KR | `("Noto Serif KR", "Batang", "AppleMyungjo")` |
| IBM Plex Sans KR | `("IBM Plex Sans KR", "Noto Sans KR", "Malgun Gothic")` |
| Spoqa Han Sans Neo | `("Spoqa Han Sans Neo", "Noto Sans KR", "Malgun Gothic")` |

### 폰트 설치

폰트가 없는 경우 `/install-font` 명령어를 안내하세요.

```bash
typst compile --font-path ./fonts document.typ
```

### 폰트 확인

```bash
typst fonts | grep -i pretendard
```

## 한글 타이포그래피 권장 설정

### CJK 문서에 적합한 문단 설정

```typst
#set par(
  leading: 1.5em,           // CJK 권장 줄간격 (기본 0.65em보다 넓게)
  first-line-indent: 1em,   // 문단 들여쓰기
  justify: true,            // 양쪽 정렬
)
```

### 페이지 설정

```typst
#set page(
  paper: "a4",
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm),
)
```

## 문서 템플릿

다양한 용도의 템플릿을 제공합니다:

- `/new` - 기본 문서
- `/new-report` - 보고서 (목차, 머리글/바닥글 포함)
- `/new-slide` - 슬라이드/장표 (16:9 프레젠테이션)

## Typst 문법 참조

자세한 문법 정보는 [reference.md](reference.md)를 참조하세요.

## 주의사항

- 사용자가 특별히 요청하지 않는 한 문서 구조나 서식을 강제하지 마세요
- 사용자의 기존 스타일을 존중하고, 필요한 부분만 수정하세요
- 폰트 선택을 안 하면 Pretendard를 기본값으로 사용하세요
- 줄간격(`leading`)은 문서 종류에 따라 조절하세요:
  - 일반 문서: 1.5em
  - 슬라이드: 1.2em (컴팩트하게)
