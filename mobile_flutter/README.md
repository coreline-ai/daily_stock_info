# Coreline Stock AI Mobile (Flutter)

Flutter 기반 Android/iOS 앱입니다. 기존 FastAPI 백엔드를 재사용하며, 기본 동작은 자동 폴링 없이 **사용자 입력 트리거 기반 로딩**입니다.

## 1) 개발 환경
- Flutter stable (Dart 3.x)
- Android: minSdk 24+
- iOS: 13+

## 2) 실행
```bash
cd mobile_flutter
flutter pub get
flutter run
```

로컬 백엔드 주소를 지정하려면:
```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

에뮬레이터/실기기에서 호스트 접근이 필요하면 환경에 맞게 URL을 바꿔야 합니다.
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://127.0.0.1:8000`

## 2-1) 동일 네트워크(LAN) 실기기 테스트
1. 루트에서 실행:
```bash
./scripts/run-lan-dev.sh
```
2. 출력된 IP를 사용해 모바일 실행:
```bash
cd mobile_flutter
flutter run --dart-define=API_BASE_URL=http://<LAN_IP>:8000
```
3. 브라우저 테스트 URL:
- `http://<LAN_IP>:3000`

실기기 HTTP 테스트를 위해 현재 앱 설정은 아래를 허용합니다.
- Android: `usesCleartextTraffic=true`
- iOS: `NSAppTransportSecurity -> NSAllowsArbitraryLoads=true`

## 3) 아키텍처
- `Riverpod + Clean Architecture` 구조
- 주요 레이어
  - `features/*/domain`: repository 계약, entity
  - `features/*/data`: Dio 기반 repository 구현
  - `features/*/presentation`: 페이지/위젯/상태관리
- 공통
  - 네트워크: `core/network/dio_client.dart`
  - 캐시: `core/storage/local_cache.dart` (Hive)
  - 설정: `shared/models/app_settings.dart`

## 4) 탭 구성
- Home: 전략/추천/상세/장중추가추천/검증요약/인사이트
- Analysis: `/strategy-validation` 기반 검증 패널
- Watchlist: 조회/추가/삭제/CSV 업로드(append/replace)
- Settings: API URL, 테마, 타임아웃, 캐시 초기화, 헬스체크
- Quick Action: 새로고침, Analysis, History, Watchlist 이동
- History(` /history`): 백테스트 요약 + 페이지네이션 히스토리

## 5) 갱신 정책
- 자동 폴링 없음
- 다음 입력에서만 재조회
  - 날짜 변경
  - 전략 변경
  - 프리셋/가중치 변경
  - 수동 새로고침
  - 워치리스트/커스텀 티커 반영
- 마지막 입력 트리거 시각 로컬 저장
- 네트워크 오류 시 대시보드 캐시 fallback

## 6) API 매핑
- `GET /api/v1/strategy-status`
- `GET /api/v1/market-overview`
- `GET /api/v1/stock-candidates`
- `GET /api/v1/stocks/{ticker}/detail`
- `GET /api/v1/strategy-validation`
- `GET /api/v1/market-insight`
- `GET/POST/DELETE /api/v1/watchlist...`
- `POST /api/v1/watchlist/upload-csv`
- `GET /api/v1/backtest/summary`
- `GET /api/v1/backtest/history`
- `GET /api/v1/health`

## 7) 테스트 / 품질
```bash
cd mobile_flutter
flutter analyze
flutter test
```

## 8) CI
루트 CI(`.github/workflows/ci.yml`)에 모바일 job이 추가되어 있습니다.
- `mobile_android`: analyze/test/build apk
- `mobile_ios`: build ios --no-codesign

## 9) 현재 범위 메모
- 인증은 `user_key=default` 단일 사용자 모드
- 푸시/결제/로그인은 1차 범위에서 제외
- 백엔드 `DATABASE_URL` 미설정 시 History API는 안내 메시지로 제한 동작
