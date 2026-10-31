# Typst Korean 로컬 적용

2026-10-31 CLI 이식성 검토: 기존 `commands/new*.md`의 Typst 코드 블록을 스킬 내부 `assets/`로 묶어 단독 복사 시에도 템플릿을 제공한다. 기본 폰트 자리를 Pretendard로 채우고 새 문서의 가운데점 구분자를 슬래시로 변경했다. 부재한 ponytail, Claude 도구명과 slash 명령 의존성을 제거하고 실제 서버의 실행기와 폰트를 확인하도록 했다. 템플릿은 런타임에서 컴파일 검증한 경우에만 컴파일 성공으로 보고한다.

사용자 선호에 따라 일반 보고서와 신규 PDF 보고서의 기본 도구로 변경했다. 지정 제출 형식은 우선한다.
보고서 템플릿은 별도 본문에서 import하는 함수로 구성하고 선택 표지와 목차, 반복 표 머리행,
여러 페이지 표, 캡션과 출처 표기 흐름을 추가했다. Typst 공식 표와 페이지 문서를 참고했다.
문장 생성은 주혁나이저에 연결하며 실제 자료 검증과 로컬 PDF 확인 절차를 분리했다.

Typst 0.15.1, Noto Sans KR에서 기본 문서 1쪽, 슬라이드 11쪽, 보고서 1쪽과 긴 표 보고서 5쪽을
실제 컴파일했다. 보고서의 80개 합성 행 순서와 반복 머리행, 가운데점 부재를 추출 텍스트로 검사하고
보고서 각 페이지를 로컬 PNG로 확인했다. 대회 서버에서의 실행이나 외부 MCP 연결을 검증한 결과는 아니다.

- https://typst.app/docs/guides/tables/
- https://typst.app/docs/reference/layout/page/
- https://typst.app/docs/reference/model/figure/
