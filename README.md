# typst-korean

Claude Code 플러그인 - Typst 한글 문서 작성 지원

## 빠른 시작

### 1. 플러그인 설치

Claude Code에서 다음 명령어를 실행하세요:

```bash
# 마켓플레이스 추가
/plugin marketplace add hyeok8055/hyeok-plugins

# 플러그인 설치
/plugin install typst-korean@hyeok8055-hyeok-plugins
```

### 설치 확인

```bash
# 설치된 플러그인 목록 확인
/plugin
```

설치 후:
- `.typ` 파일을 열면 자동으로 typst-korean 스킬이 활성화됩니다
- `/new` 입력 시 자동완성에 커맨드가 표시됩니다

### 2. 폰트 설치

```bash
/install-font
```

### 3. 새 문서 생성

```bash
/new mydocument
```

### 4. PDF로 변환

```bash
/pdf mydocument.typ
```

## 커맨드 사용법

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `/new [파일명]` | 기본 한글 문서 생성 | `/new report` |
| `/new-report [파일명]` | 보고서 템플릿 | `/new-report quarterly` |
| `/new-slide [파일명]` | 슬라이드/장표 템플릿 | `/new-slide presentation` |
| `/pdf [파일명]` | Typst → PDF 변환 | `/pdf document.typ` |
| `/convert [파일명]` | Markdown → Typst 변환 | `/convert README.md` |
| `/check-font` | 폰트 설치 확인 | `/check-font` |
| `/install-font` | 폰트 다운로드/설치 | `/install-font` |

## 지원 폰트

모든 폰트는 **상업적 사용이 무료**입니다 (SIL OFL 또는 동등 라이선스).

| 폰트 | 특징 | 추천 용도 |
|------|------|-----------|
| **Pretendard** (기본값) | Apple SF, Inter 스타일 | 일반 문서, UI |
| **Noto Sans KR** | Google Fonts 고딕 | 일반 문서, 웹 |
| **Noto Serif KR** | Google Fonts 명조 | 논문, 서적 |
| **NanumGothicCoding** | 네이버 고정폭 | 코드, 기술 문서 |
| **D2Coding** | 네이버 고정폭 | 코드, 기술 문서 |
| **IBM Plex Sans KR** | IBM 디자인 고딕 | 프레젠테이션 |
| **Spoqa Han Sans Neo** | 스포카 고딕 | UI, 웹 |

문서 생성 시 폰트를 선택할 수 있으며, 기본값은 Pretendard입니다.

## 기능

- 다양한 한글 폰트 선택 및 fallback 지원
- 한글 문서에 적합한 타이포그래피 설정 (CJK 권장 줄간격, 들여쓰기)
- 다양한 템플릿 제공 (기본, 보고서, 슬라이드)
- Typst 기본 문법 레퍼런스
- `.typ` 파일 작업 시 자동 활성화

## 폰트 설치

### 프로젝트 폴더에 설치 (권장)

```bash
# 폰트 디렉토리 생성
mkdir -p fonts

# Pretendard 다운로드
curl -L -o fonts/Pretendard.zip "https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip"
cd fonts && unzip -o Pretendard.zip -d Pretendard && rm Pretendard.zip && cd ..

# 컴파일 시 폰트 경로 지정
typst compile --font-path ./fonts document.typ
```

### 시스템 전역 설치

```bash
# macOS
cp fonts/*/*.otf ~/Library/Fonts/

# Linux
mkdir -p ~/.local/share/fonts
cp fonts/*/*.otf ~/.local/share/fonts/
fc-cache -fv
```

## 문제 해결

### 폰트 인식 안 될 때

```bash
# 설치된 폰트 확인
typst fonts | grep -i pretendard

# 폰트 경로 지정하여 컴파일
typst compile --font-path ./fonts document.typ
```

### typst 설치

```bash
# Cargo (Rust)
cargo install typst-cli

# Homebrew (macOS)
brew install typst

# Scoop (Windows)
scoop install typst
```

### 한글 깨짐

폰트가 없거나 `lang` 설정이 누락된 경우 발생합니다:

```typst
#set text(
  font: ("Pretendard", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
)
```

## 권장 설정

### 한글 문서 기본 설정

```typst
// 폰트 (fallback 포함)
#set text(
  font: ("Pretendard", "Noto Sans KR", "Malgun Gothic"),
  lang: "ko",
  region: "KR",
  size: 11pt,
)

// 페이지
#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
)

// 문단 (CJK 권장)
#set par(
  leading: 1.5em,
  first-line-indent: 1em,
  justify: true,
)
```

## 플러그인 관리

```bash
# 플러그인 비활성화
/plugin disable typst-korean@hyeok8055-hyeok-plugins

# 플러그인 활성화
/plugin enable typst-korean@hyeok8055-hyeok-plugins

# 플러그인 제거
/plugin uninstall typst-korean@hyeok8055-hyeok-plugins

# 마켓플레이스 제거
/plugin marketplace remove hyeok8055-hyeok-plugins
```

## 요구 사항

- Typst >= 0.11.0
- Claude Code

## 라이선스

MIT
