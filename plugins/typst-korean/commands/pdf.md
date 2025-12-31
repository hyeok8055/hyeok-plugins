---
description: Typst 파일을 PDF로 컴파일합니다
---

# Typst → PDF 변환

`$ARGUMENTS`로 전달받은 경로의 Typst 파일을 PDF로 컴파일하세요.

## 처리 순서

1. 경로가 없으면 사용자에게 `.typ` 파일 경로를 물어보세요
2. 다음 명령어로 PDF 컴파일 실행:

```bash
typst compile "파일경로.typ"
```

3. 프리텐다드 폰트를 찾지 못하면 `--font-path` 옵션 안내:

```bash
typst compile --font-path ./fonts "파일경로.typ"
```

## 출력 파일
- 기본: 같은 위치에 `.pdf` 확장자로 생성
- 예: `document.typ` → `document.pdf`

## 에러 처리
- typst가 설치되지 않은 경우: 설치 방법 안내 (`cargo install typst-cli` 또는 패키지 매니저)
- 폰트를 찾지 못한 경우: `--font-path` 옵션 또는 폰트 설치 안내
- 문법 오류: 에러 메시지 해석해서 수정 방법 안내

## 완료 후
- 생성된 PDF 파일 경로 출력
