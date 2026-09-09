# 토스 프론트 1.5세대용 LineageOS 18.1 + Pico GApps 빌더

[![ZIP 다운로드](https://img.shields.io/badge/ZIP-다운로드-2ea44f?style=for-the-badge&logo=github)](https://github.com/kyseong00/toss-front-lineageos-builder/archive/refs/heads/main.zip)

토스 프론트 **1.5세대 PLF02WH 전용** PowerShell 빌더입니다. 직접 백업한 순정 `super.img`를 이용해 LineageOS 18.1과 Google 앱이 포함된 펌웨어를 만듭니다.

> PLF00WH(1세대)와 2세대에는 사용할 수 없습니다.

## 준비

- Windows 10/11 64비트
- PowerShell 5.1 이상
- C: 드라이브 여유 공간 14 GiB 이상
- 본인 PLF02WH에서 읽은 순정 `super.img`
- 인터넷 연결(도구와 공개 입력을 자동 다운로드할 때)

먼저 [BACKUP.md](BACKUP.md)를 참고해 순정 `super.img`를 백업한 뒤 `input\stock-super.img`에 넣어 주세요. 스크립트가 올바른 파일인지 자동으로 확인합니다.

## 실행

`Build.bat`을 더블클릭한 뒤, 안내에 따라 `super.img` 파일을 창으로 끌어다 놓고 Enter 키를 누릅니다. 필요한 도구 설치와 빌드가 자동으로 진행됩니다.

빌드가 끝나면 아래 두 파일이 생성됩니다.

```text
output\super_PLF02WH_lineage18.1_gapps_pico.img
output\super_PLF02WH_lineage18.1_gapps_pico.img.manifest.json
```

스크립트가 필요한 파일을 내려받고 이미지를 만든 뒤 오류 여부까지 확인합니다.

## 펌웨어 설치

빌드된 펌웨어를 플래싱할 때는 **`super` 파티션 하나만** 선택합니다. RKDevTool에서 장치가 `Found One LOADER Device`로 인식되면 `Download Image` 표의 `super` 행에 결과 파일을 지정하고, 해당 행만 선택한 상태에서 `Run`을 누릅니다.

처음 부팅되지 않으면 사용자 데이터 초기화가 필요할 수 있습니다. 초기화하면 모든 데이터가 지워지므로 백업 후 진행해 주세요. 부팅 화면에서 10분 이상 멈추면 다른 파티션을 추가로 플래싱하지 말고 로그와 백업 상태를 확인해 주세요.

## 복구

부팅에 실패하더라도 출처가 불분명한 이미지를 추가로 쓰지 마세요. Loader/MaskROM 진입 여부를 확인한 뒤, 본인 장치에서 백업한 순정 이미지와 파티션 정보를 이용해 복구해야 합니다. 백업 방법은 [BACKUP.md](BACKUP.md)에 정리해 두었습니다.

## 라이선스

이 저장소에서 직접 작성한 스크립트와 문서는 [MIT License](LICENSE)로 배포합니다. 입력 파일, 다운로드되는 도구, LineageOS, OpenGApps, 순정 펌웨어와 생성 결과에는 각각 별도의 라이선스와 이용 조건이 적용됩니다.
