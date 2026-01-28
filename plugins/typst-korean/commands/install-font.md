---
description: 한글 폰트를 다운로드하고 설치합니다 (기본값: 프리텐다드)
---

# 한글 폰트 설치

한글 폰트를 다운로드하고 Typst에서 사용할 수 있도록 설정합니다.

## 폰트 선택

`$ARGUMENTS`가 없거나 폰트명이 지정되지 않으면, 사용자에게 다음 중 선택하도록 물어보세요:

| 폰트 | 특징 | 용도 |
|------|------|------|
| **Pretendard** (기본값) | Apple SF, Inter 스타일의 현대적 고딕 | 일반 문서, UI |
| **Noto Sans KR** | Google Fonts, 다양한 굵기 | 일반 문서, 웹 |
| **Noto Serif KR** | Google Fonts 명조체 | 논문, 서적 |
| **NanumGothicCoding** | 네이버 개발자용 고정폭 | 코드, 기술 문서 |
| **D2Coding** | 네이버 개발자용 고정폭 | 코드, 기술 문서 |
| **IBM Plex Sans KR** | IBM 디자인, 세련된 고딕 | 프레젠테이션 |
| **Spoqa Han Sans Neo** | 스포카 제공, 깔끔한 고딕 | UI, 웹 |

**모든 폰트는 SIL OFL 또는 동등한 라이선스로 상업적 사용이 무료입니다.**

## 설치 과정

### 1. 폰트 디렉토리 생성

```bash
mkdir -p fonts
```

### 2. 선택한 폰트 다운로드

#### Pretendard (기본값)
```bash
curl -L -o fonts/Pretendard.zip "https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip"
cd fonts && unzip -o Pretendard.zip -d Pretendard && rm Pretendard.zip && cd ..
```

#### Noto Sans KR
```bash
curl -L -o fonts/NotoSansKR.zip "https://fonts.google.com/download?family=Noto%20Sans%20KR"
cd fonts && unzip -o NotoSansKR.zip -d NotoSansKR && rm NotoSansKR.zip && cd ..
```

#### Noto Serif KR
```bash
curl -L -o fonts/NotoSerifKR.zip "https://fonts.google.com/download?family=Noto%20Serif%20KR"
cd fonts && unzip -o NotoSerifKR.zip -d NotoSerifKR && rm NotoSerifKR.zip && cd ..
```

#### NanumGothicCoding
```bash
curl -L -o fonts/NanumGothicCoding.zip "https://github.com/naver/nanumfont/releases/download/VER2.5/NanumGothicCoding-2.5.zip"
cd fonts && unzip -o NanumGothicCoding.zip -d NanumGothicCoding && rm NanumGothicCoding.zip && cd ..
```

#### D2Coding
```bash
curl -L -o fonts/D2Coding.zip "https://github.com/naver/d2codingfont/releases/download/VER1.3.2/D2Coding-Ver1.3.2-20180524.zip"
cd fonts && unzip -o D2Coding.zip -d D2Coding && rm D2Coding.zip && cd ..
```

#### IBM Plex Sans KR
```bash
curl -L -o fonts/IBMPlexSansKR.zip "https://fonts.google.com/download?family=IBM%20Plex%20Sans%20KR"
cd fonts && unzip -o IBMPlexSansKR.zip -d IBMPlexSansKR && rm IBMPlexSansKR.zip && cd ..
```

#### Spoqa Han Sans Neo
```bash
curl -L -o fonts/SpoqaHanSansNeo.zip "https://github.com/spoqa/spoqa-han-sans/releases/download/v3.3.0/SpoqaHanSansNeo_all.zip"
cd fonts && unzip -o SpoqaHanSansNeo.zip -d SpoqaHanSansNeo && rm SpoqaHanSansNeo.zip && cd ..
```

### 3. 설치 확인

```bash
typst fonts --font-path ./fonts | grep -iE "(pretendard|noto|nanum|d2coding|plex|spoqa)"
```

## 시스템 전역 설치 (선택)

### macOS
```bash
cp fonts/*/*.otf ~/Library/Fonts/ 2>/dev/null
cp fonts/*/*.ttf ~/Library/Fonts/ 2>/dev/null
```

### Linux
```bash
mkdir -p ~/.local/share/fonts
cp fonts/*/*.otf ~/.local/share/fonts/ 2>/dev/null
cp fonts/*/*.ttf ~/.local/share/fonts/ 2>/dev/null
fc-cache -fv
```

## 사용법

```bash
typst compile --font-path ./fonts document.typ
```

## 완료 후

- 설치된 폰트 목록 출력
- Typst 문서에서 사용하는 방법 안내:
  ```typst
  #set text(font: "선택한폰트명")
  ```
