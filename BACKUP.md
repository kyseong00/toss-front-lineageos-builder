# 토스 프론트 1.5세대 백업 방법

이 문서는 **토스 프론트 1.5세대(PLF02WH)** 전용입니다. PLF00WH(1세대)와 2세대에는 이 방법을 사용하지 마세요. RKDevTool의 버튼 이름은 버전에 따라 조금 다를 수 있습니다.

## 필요한 파일

- [RKDevTool v2.96 다운로드](https://dl.radxa.com/tools/windows/RKDevTool_Release_v2.96_zh.zip)
- [DriverAssistant v5.14 다운로드](https://dl.radxa.com/tools/windows/DriverAssitant_v5.14.zip)
- [Radxa의 RKDevTool 안내 문서](https://docs.radxa.com/en/template/module/radxa-os/low-level-dev/rkdevtool)

두 ZIP 파일을 각각 압축 해제합니다. 먼저 DriverAssistant 폴더의 `DriverInstall.exe`를 실행하고 `Install Driver`를 누르세요. 이전 Rockchip 드라이버가 설치되어 있다면 `Uninstall Driver`를 누른 뒤 다시 설치합니다.

## 중국어를 영어로 바꾸기

1. RKDevTool을 완전히 종료합니다.
2. `RKDevTool.exe`와 같은 폴더에 있는 `config.ini`를 메모장으로 엽니다.
3. `[Language]` 아래의 `Selected=1`을 `Selected=2`로 바꿉니다.
4. 같은 부분에 `Lang2File=English.ini`가 있는지 확인합니다.
5. `Language\English.ini` 파일이 있는지 확인한 뒤 `config.ini`를 저장하고 RKDevTool을 다시 실행합니다.

`config.ini`는 UTF-16 LE 형식입니다. 저장 형식을 바꾸면 `Loading config file failed!` 오류가 날 수 있습니다. 오류가 생기면 ZIP을 새 폴더에 다시 압축 해제하고 `Selected=1` 한 줄만 메모장에서 수정하세요.

## 백업 전 확인

- 펌웨어를 바꾸기 전에 백업하세요.
- 기기가 `LOADER` 또는 `MASKROM`으로 안정적으로 인식되는지 확인하세요.
- 백업 중에는 쓰기나 삭제와 관련된 버튼을 누르지 마세요.

## 확인된 PLF02WH 파티션 표

주소와 크기는 512바이트 LBA 단위입니다. 다른 모델에는 이 값을 사용하지 마세요.

| 파일명 | Start | Count | 기대 크기 |
|---|---:|---:|---:|
| EFI_part.img | `0x00000000` | `0x00002000` | 4 MiB |
| security.img | `0x00002000` | `0x00002000` | 4 MiB |
| uboot.img | `0x00004000` | `0x00002000` | 4 MiB |
| trust.img | `0x00006000` | `0x00002000` | 4 MiB |
| misc.img | `0x00008000` | `0x00002000` | 4 MiB |
| dtbo.img | `0x0000A000` | `0x00002000` | 4 MiB |
| vbmeta.img | `0x0000C000` | `0x00000800` | 1 MiB |
| boot.img | `0x0000C800` | `0x00014000` | 40 MiB |
| recovery.img | `0x00020800` | `0x0003C000` | 120 MiB |
| backup.img | `0x0005C800` | `0x000C0000` | 384 MiB |
| cache.img | `0x0011C800` | `0x000C0000` | 384 MiB |
| metadata.img | `0x001DC800` | `0x00008000` | 16 MiB |
| baseparameter.img | `0x001E4800` | `0x00000800` | 1 MiB |
| super.img | `0x001E5000` | `0x00400000` | 2 GiB |
| userdata.img | `0x005E5000` | `0x0173AFC0` | 약 11.62 GiB |

## 파티션 백업하기

자세한 백업 방법은 [디시인사이드의 `토스 프론트 관련 메모 4`](https://gall.dcinside.com/mgallery/board/view/?id=sff&no=1722898)를 참고해 주세요. 이 글은 토스 프론트 1.5세대를 기준으로 `rkDumper`와 RKDevTool을 함께 사용하는 과정을 설명합니다. 아래 내용은 작업 중 빠르게 확인할 수 있도록 핵심 순서만 정리한 것입니다.

1. 기기를 Loader/MaskROM 상태로 연결하고 창 아래쪽의 장치 인식 문구를 확인합니다.
2. `Advanced Function` 탭에서 `TestDevice`를 누르고 성공 메시지가 나오는지 확인합니다.
3. `ReadCapability`를 눌러 `ReadLBA: Enable`인지 확인합니다. `Disable`이면 중단하세요.
4. `ExportImage`의 `Start`와 `Count`에 위 표의 값을 입력합니다.
5. `ExportImage`를 눌러 파티션을 하나씩 읽습니다.
6. `Output` 폴더에 생성된 파일을 표에 나온 파일명으로 바로 바꿉니다.
7. 4~6번을 반복해 필요한 파티션을 백업합니다. 가능하면 표에 있는 파티션을 모두 보관하세요.

최소한 `parameter` 화면 캡처와 `super.img`, `boot.img`, 복구 관련 파티션은 보관하는 것이 좋습니다. `vendor`와 `odm`은 `super.img` 안에 들어 있습니다. `userdata.img`에는 개인정보가 들어 있을 수 있으므로 필요할 때만 백업하고 공개하지 마세요.
