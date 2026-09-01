# typst-korean fonts (local cache)

`install.sh` / `install.ps1` (또는 `scripts/install-pretendard.*`)가
Pretendard **Regular · Medium · SemiBold · Bold** OTF 4개만 내려받아 여기에 채운다.

- 출처: [orioncactus/pretendard](https://github.com/orioncactus/pretendard) `v1.3.9`
- CDN: jsDelivr (전체 46MB zip 대신 파일 단위)
- OS 설치 위치
  - macOS: `~/Library/Fonts`
  - Linux: `~/.local/share/fonts/hyeok-pretendard`
  - Windows: `%LOCALAPPDATA%\Microsoft\Windows\Fonts` + HKCU Fonts

Typst:

```bash
typst fonts | grep -i pretendard
typst compile --font-path ./plugins/typst-korean/fonts doc.typ
```

`*.otf`는 용량 때문에 git에 넣지 않는다 (`.gitignore`).

Uninstall only removes Pretendard from shared OS font dirs when `.hyeok-installed` is present (written by install-pretendard).
