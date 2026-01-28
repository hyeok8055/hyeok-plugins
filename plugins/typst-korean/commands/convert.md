---
description: 마크다운 파일을 한글 설정이 적용된 Typst 파일로 변환합니다 (폰트 선택 가능)
---

# 마크다운 → Typst 변환

`$ARGUMENTS`로 전달받은 경로의 마크다운 파일을 Typst 파일로 변환하세요.

## 처리 순서

1. 경로가 없으면 사용자에게 파일 경로를 물어보세요
2. 해당 마크다운 파일을 읽습니다
3. 마크다운 내용을 Typst 문법으로 변환합니다
4. 같은 위치에 `.typ` 확장자로 저장합니다

## 폰트 선택

사용자에게 폰트를 선택하도록 물어보세요 (선택 안 하면 **Pretendard** 기본값):

| 폰트 | 특징 |
|------|------|
| **Pretendard** (기본값) | 현대적 고딕 |
| **Noto Sans KR** | Google 고딕 |
| **Noto Serif KR** | Google 명조 |
| **IBM Plex Sans KR** | IBM 고딕 |
| **Spoqa Han Sans Neo** | 스포카 고딕 |

## 변환 규칙

| Markdown | Typst |
|----------|-------|
| `# 제목` | `= 제목` |
| `## 제목` | `== 제목` |
| `### 제목` | `=== 제목` |
| `**굵게**` | `*굵게*` |
| `*기울임*` | `_기울임_` |
| `` `코드` `` | `` `코드` `` (동일) |
| `- 목록` | `- 목록` (동일) |
| `1. 번호` | `+ 번호` 또는 `1.` |
| `[링크](url)` | `#link("url")[링크]` |
| `![이미지](path)` | `#image("path")` |
| ` ```언어 ` 코드블록 | ` ```언어 ` (동일) |

## 생성할 파일 헤더

선택한 폰트로 다음 설정을 추가하세요:

```typst
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
  margin: (x: 2.5cm, y: 2.5cm),
)

// 문단 설정 (CJK 권장)
#set par(
  leading: 1.5em,
  first-line-indent: 1em,
  justify: true,
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

## 완료 후
- 생성된 파일 경로 출력
- PDF 변환이 필요하면 `/pdf` 명령어 안내
- 폰트가 없으면 `/install-font` 안내
