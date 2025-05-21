
# Porcupine Flutter 데모

이 프로젝트는 Flutter를 사용하여 Picovoice의 Porcupine 음성 키워드 감지 엔진을 구현한 데모 애플리케이션입니다.

## 소개

Porcupine은 모바일 기기에서 효율적으로 작동하는 온디바이스 음성 키워드 감지 엔진입니다. 이 데모는 Flutter 앱에서 어떻게 음성 키워드 감지 기능을 구현할 수 있는지 보여줍니다.

## 기능

- 음성 키워드를 통한 앱 활성화
- 다양한 내장 키워드 지원
- 실시간 음성 감지
- 다양한 플랫폼(Android, iOS) 지원

## 설치 방법

1. Flutter 개발 환경 설정
```bash
flutter pub get
```

2. 애플리케이션 실행
```bash
flutter run
```

## 요구사항

- Flutter 3.7.2 이상
- Android: minSdk 21 이상, NDK 27.0.12077973
- iOS: iOS 11.0 이상
- Picovoice 액세스 키 필요 (코드에서 액세스 키를 자신의 키로 변경해야 합니다)

## 사용 방법

1. 앱을 시작하면 키워드 선택 화면이 표시됩니다.
2. 원하는 키워드를 선택합니다.
3. "Start" 버튼을 눌러 음성 감지를 시작합니다.
4. 선택한 키워드를 말하면 앱이 반응합니다.

## 문제 해결

- 마이크 접근 권한을 허용해야 합니다.
- 일부 기기에서는 오디오 설정을 조정해야 할 수 있습니다.

## 라이센스

이 프로젝트는 Picovoice 라이센스를 따릅니다. 자세한 내용은 [Picovoice 웹사이트](https://picovoice.ai/docs/licensing/)를 참조하세요.
