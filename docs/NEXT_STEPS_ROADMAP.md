# DailyStock Next Steps Roadmap

## Implemented in this cycle
- Custom ticker CSV upload endpoint: `POST /api/v1/watchlist/upload-csv`
- Watchlist append/replace mode with invalid row reporting
- Market regime auto-detection + suggested weight application
- Sector exposure cap for top picks
- AI report confidence and fallback metadata (`fallbackReason`)
- Position sizing block in stock detail
- Backtest transaction cost assumptions (`fee_bps`, `slippage_bps`) with net metrics
- LLM startup model probe + health warning/autocorrect (`GLM4.7 -> GLM-4.7`)

## Additional items status check
1. GLM model-id validation and auto-fallback
- Status: Done
- Output: startup probe, candidate scan, auto-correct, `/api/v1/health` warning exposure

2. Background job split for heavy endpoints
- Status: Planned
- Move `backfill` and AI generation to async jobs (RQ/Celery/Arq).
- Keep API responsive with job status polling endpoint.
- API design draft:
  - `POST /api/v1/jobs/backfill`
  - `POST /api/v1/jobs/ai-report`
  - `GET /api/v1/jobs/{job_id}`

3. Watchlist CSV quality controls
- Status: Planned
- Add max row limit, duplicate reporting, and strict ticker format validation.
- Return downloadable error CSV for invalid rows.
- API design draft:
  - `POST /api/v1/watchlist/upload-csv` response에 `duplicates`, `rejectedRowsCsvUrl`, `maxRowsExceeded` 확장

4. Backtest realism upgrades
- Status: Planned
- Add liquidity filter at entry date.
- Add stop-loss / target hit simulation with OHLC path checks.
- Add benchmark-relative metrics (alpha, information ratio).
- API design draft:
  - `GET /api/v1/backtest/summary`에 `alpha`, `beta`, `informationRatio` 추가
  - `GET /api/v1/backtest/history`에 `exitReason(stop/target/time)` 추가

5. AI observability
- Status: Planned
- Persist per-call latency/error type/token usage.
- Dashboard card for AI success rate and fallback rate.
- Schema draft:
  - `ai_call_logs(id, trade_date, ticker, provider, model, latency_ms, token_in, token_out, error_type, is_fallback, created_at)`

## Acceptance criteria for next cycle
- End-to-end runbook documented (`docker compose up`, backend, frontend).
- Real HTTP smoke script passes in CI for core APIs.
- GLM path tested with at least one successful non-fallback response.
