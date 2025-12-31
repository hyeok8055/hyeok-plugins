# typst-korean

Claude Code 플러그인 - Typst 한글 문서 작성 지원

## 설치

```bash
# Claude Code에서 플러그인 설치
/plugin install /path/to/typst-korean
```

또는 `.claude/skills/` 폴더에 직접 복사:

```bash
cp -r skills/typst-korean ~/.claude/skills/
```

## 기능

- 프리텐다드(Pretendard) 폰트 기본 설정 안내
- Typst 기본 문법 레퍼런스
- 한글 문서에 적합한 설정 권장

## 프리텐다드 폰트

[Pretendard](https://github.com/orioncactus/pretendard) - Apple SF, Inter를 참고한 한글 폰트

```bash
# 폰트 다운로드
curl -L -o pretendard.zip "https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip"
```

## 라이선스

MIT
