# 전략 검증 모니터링 운영 가이드

## 로그 경로
- 기본값: `/tmp/daily_stock_validation_metrics.jsonl`
- 환경 변수: `VALIDATION_MONITOR_LOG_PATH`

## 관련 환경 변수
- `VALIDATION_MONITOR_ENABLED=true|false`
- `VALIDATION_ALERT_MAX_PBO` (기본 `0.30`)
- `VALIDATION_ALERT_MIN_DSR` (기본 `-0.10`)
- `VALIDATION_ALERT_MIN_NET_SHARPE` (기본 `0.00`)

## 브랜치 자동 승격
- `INTRADAY_BRANCH_ROLLOUT_MODE=auto` 설정 시 검증 결과 기반으로 `baseline/phase2` 브랜치를 자동 선택합니다.
