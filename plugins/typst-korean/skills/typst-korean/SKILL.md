---
name: typst-korean
description: 주혁의 일반 보고서와 신규 PDF 보고서를 Typst로 작성하고 한글 폰트, 조판, 표와 출처, 컴파일을 검증한다. Typst 지정 또는 .typ 수정에도 사용한다. Word나 Markdown 등 지정 형식과 주최측 서식이 우선하며, 기존 PDF 편집이나 일반 대화에는 자동 적용하지 않는다.
metadata:
  file-patterns: ["**/*.typ"]
---

# Typst Korean - 한글 문서 작성 지원

Typst로 한글 문서를 작성할 때 도움을 제공합니다.

## Codex CLI 실행 범위

현재 세션에 있는 파일 편집 도구와 셸만 사용한다. 로드한 `SKILL.md`의 폴더를 기준으로
참조와 템플릿 경로를 찾고, 산출물은 사용자의 작업 폴더에 저장한다. 서버에서 `typst --version`과
`typst fonts`를 확인한다. 실행기가 없으면 현재 규정에서 허용하는 공개 배포본을 작업 폴더에
설치할 수 있는지 확인한다. 설치가 불가능하면 소스만 작성하고 컴파일 미실행을 알린다.
제공된 Codex와 사용자 홈 설정을 바꾸거나 없는 스킬과 slash 명령을 호출하지 않는다.
시험에서는 주최측 조건이 우선하며, 금지된 Computer Use와 자동 브라우저 검사를 수행하지 않는다.

## 역할 (hyeok-governance 계층 2)

- **활성 조건**: 일반 보고서 요청과 신규 PDF 보고서는 Typst를 기본으로 사용한다.
  Typst 명시 요청과 `.typ` 수정에도 적용한다. Word, Markdown 등 지정 형식과 주최측 서식은
  이 기본값보다 우선한다. 기존 PDF 편집과 슬라이드는 해당 형식 도구를 사용한다.
- **담당(활성 시)**: Typst 한글 **문서 생산**. 코드 파일 안의 Typst/Markdown 마크업 리터럴도 소관.
- **비담당**: 실행 코드, 시스템 맵, 일반 도식. 요청한 산출물과 현재 사용 가능한 도구에 따라 처리한다.
- 기존 문서의 폰트나 사용자 선택을 재사용한다. 필수 폰트가 없어서 결과에 영향을 줄 때만 확인한다.

## 보고서 작성 흐름

[보고서 작성과 검증](references/report-workflow.md)을 읽고 근거 확인 → 본문 작성 → 조판 →
컴파일 → 결과 검증 순서로 진행한다. 현재 제공된 `juhyeoknizer`가 있으면 작성 단계에 적용한다.
주장에 필요한 숫자나 출처를 만들지 않는다. 가운데점 구분자와 점 모양 목록 기호를 쓰지 않으며,
Typst 목록은 `#set list(marker: [-])`로 설정한다.

## 지원 폰트 (상업적 사용 무료)

지정이 없으면 사용 가능한 **Pretendard**를 기본으로 한다. 서버에 설치된 한글 폰트를 확인하고,
아래 이름이나 Windows/macOS fallback이 Linux에도 있다고 가정하지 않는다.

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

폰트가 없으면 실제 사용 가능한 한글 폰트나 사용자가 허용한 프로젝트의 폰트 파일을 사용한다.
프로젝트 폰트가 있는 경우에만 실제 경로를 `--font-path`로 전달한다. `/install-font`는 Codex CLI
명령이 아니며 이 스킬 설치가 폰트를 설치하지 않는다. 사용할 한글 폰트가 없으면 소스와 제한을 전달한다.

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

스킬 폴더에 포함된 템플릿을 작업 폴더로 복사한 뒤 요청한 내용과 폰트로 수정한다.
각 예시의 제목, 저자와 본문은 사용자 자료가 아니므로 실제 내용으로 교체한다.

- [document.typ](assets/document.typ) - 기본 문서
- [report.typ](assets/report.typ) - 별도 `main.typ`에서 불러오는 보고서 함수. 표지와 목차는 선택하며 표, 출처와 머리글/바닥글을 지원한다.
- [slides.typ](assets/slides.typ) - 슬라이드/장표 (16:9 프레젠테이션)

이 파일들은 템플릿 자원이며 `/new`, `/new-report`, `/new-slide` 같은 CLI 명령을 등록하지 않는다.

## Typst 문법 참조

자세한 문법 정보는 [reference.md](reference.md)를 참조하세요.

## 주의사항

- 사용자가 특별히 요청하지 않는 한 문서 구조나 서식을 강제하지 마세요
- 사용자의 기존 스타일을 존중하고, 필요한 부분만 수정하세요
- 폰트 선택을 안 하면 사용 가능한 Pretendard를 우선하고 실제 서버 폰트로 대체하세요
- 줄간격(`leading`)은 문서 종류에 따라 조절하세요:
  - 일반 문서: 1.5em
  - 슬라이드: 1.2em (컴팩트하게)
