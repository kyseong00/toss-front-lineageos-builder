# Third-party notices

이 프로젝트는 제3자 바이너리를 저장소에 포함하지 않고 원본 배포처에서 사용자의 PC로 받는다.

## LineageOS GSI

- 파일: `lineage-18.1-20240121-UNOFFICIAL-arm64_bvS.img.xz`
- 배포처: [Andy Yan GSI - SourceForge](https://sourceforge.net/projects/andyyan-gsi/files/lineage-18.x/)
- 고정 SHA-256: `EE126763EE3A03518D829C9AE08204A535342C062936B3124BD0E93E623FF941`

Android/LineageOS와 이미지에 포함된 각 구성요소의 라이선스가 적용된다. 이 프로젝트의 MIT 라이선스가 해당 이미지에 적용되는 것은 아니다.

## OpenGApps

- 파일: `open_gapps-arm64-11.0-pico-20220503.zip`
- 배포처: [OpenGApps - SourceForge](https://sourceforge.net/projects/opengapps/files/arm64/20220503/)
- 고정 SHA-256: `11C4FF4DB8CE7A7876F7D30BEC46D853E52B82CC702AA717B421A2602988112B`
- 조건: [OpenGApps README의 License 절](https://github.com/opengapps/opengapps#license)

OpenGApps 사전 빌드 패키지와 그 안의 Google 앱은 개인 사용 용도이며 공개 미러링 대상이 아니다. 빌더 실행 시 `-AcceptOpenGAppsPersonalUse`를 명시해야 한다. 생성된 Google 앱 포함 `super.img`를 공개 저장소나 릴리스에 첨부하지 않는다.

## Android logical-partition tools

- 배포처: [lpunpack_and_lpmake_cmake release 220922](https://github.com/thka2016/lpunpack_and_lpmake_cmake/releases/tag/220922)
- 사용하는 파일: `lpmake.exe`, `lpunpack.exe`, `simg2img.exe`, `cygwin1.dll`

`Setup-Tools.ps1`은 릴리스 파일을 고정 SHA-256으로 검증한다. 각 바이너리와 소스에는 업스트림의 조건이 적용된다.

## Cygwin

- 배포처: [Cygwin](https://cygwin.com/)
- 사용하는 패키지: `e2fsprogs`, `lzip`, `xz`와 필요한 런타임 의존성

설치 프로그램의 Authenticode 서명과 서명자 이름을 확인한 뒤 프로젝트 내부 `.tools`에 비관리자 방식으로 설치한다. Cygwin 및 개별 패키지의 라이선스가 적용된다.

## PLF02WH 순정 이미지와 생성 결과

순정 `super.img`는 사용자가 소유한 장치에서 직접 백업해야 한다. 이 저장소는 순정 이미지, 전체 펌웨어, 개인 데이터 또는 생성된 `super.img`의 배포 권한을 부여하지 않는다.
