---
description: 시스템에 프리텐다드 폰트가 설치되어 있는지 확인합니다
---

# 프리텐다드 폰트 확인

다음 명령어를 실행해서 프리텐다드 폰트 설치 여부를 확인하세요:

```bash
typst fonts | grep -i pretendard
```

## 결과 해석
- 폰트가 나오면: "프리텐다드 폰트가 설치되어 있습니다" 출력
- 폰트가 없으면: 설치 방법 안내
  1. https://github.com/orioncactus/pretendard/releases 에서 다운로드
  2. 시스템 폰트 폴더에 설치하거나
  3. `typst compile --font-path ./fonts` 옵션 사용 안내
