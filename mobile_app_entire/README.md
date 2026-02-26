# Coreline Stock AI - Mobile Entire

Flutter 단독(Android/iOS) 앱이며, `frontend`/`backend`에 의존하지 않는 무서버 구조입니다.

## Key Principles
- Clean Architecture: `presentation -> application -> domain <- data`
- Domain 계층은 Flutter/Dio/DB 의존 금지
- BYOK: `TwelveData`, `Finnhub`, `GLM` 키를 앱 설정에서 직접 입력
- 디자인 기준: `../docs/design/code.html`, `../docs/design/screen.png`

## Project Structure
```text
lib/
  app/
  core/
  domain/
  application/
  data/
  features/
  shared/
```

## Quick Start
```bash
cd mobile_app_entire
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

## Quality Gates
```bash
cd mobile_app_entire
./tool/check_architecture_boundaries.sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --no-codesign
```

## Notes
- API 키 미입력 시 dashboard/AI는 deterministic fallback 데이터로 동작합니다.
- 백테스트/검증은 단말 로컬 캐시를 기반으로 경량 계산합니다.
