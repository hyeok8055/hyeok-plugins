---
description: 프리텐다드 폰트와 한글 설정이 적용된 새 Typst 문서를 생성합니다
---

# Typst 한글 문서 생성

사용자가 지정한 파일명으로 새 Typst 문서를 생성하세요.

## 파일명 처리
- `$ARGUMENTS`가 있으면 해당 이름 사용 (`.typ` 확장자 자동 추가)
- 없으면 `document.typ` 사용

## 생성할 템플릿

```typst
#set text(
  font: "Pretendard",
  lang: "ko",
  region: "KR",
)

#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
)

#set par(
  justify: true,
  leading: 0.8em,
)

// 문서 내용을 여기에 작성하세요

```

## 실행 후
- 파일 생성 완료 메시지 출력
- 사용자에게 문서 작성을 시작하라고 안내
