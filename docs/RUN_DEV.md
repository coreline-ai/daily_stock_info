# Run Dev Servers

`run-dev.ps1` starts/stops frontend and backend together on Windows.

## Commands

```powershell
# start both
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-dev.ps1 start

# stop both
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-dev.ps1 stop

# restart both
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-dev.ps1 restart

# status
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-dev.ps1 status

# logs
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-dev.ps1 logs

# logs (follow)
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-dev.ps1 logs -Follow
```

## Options

- `-Target frontend|backend|all` (default: `all`)
- `-Action start|stop|restart|status|logs`

## Notes

- Frontend: `http://127.0.0.1:3000`
- Backend health: `http://127.0.0.1:8000/api/v1/health`
- `health.tradingCalendar` shows KRX calendar provider status (`exchange_calendars` or fallback)
- Strategy status: `http://127.0.0.1:8000/api/v1/strategy-status?date=YYYY-MM-DD`
- `strategy-status.nonTradingDay` includes reason details for non-trading days (weekend/holiday name/session)
- Strategy windows (KST):
  - `08:00-15:29`: `premarket` only
  - `15:30+`: `close` 기본 + `premarket` 리플레이 조회 가능
  - before `08:00`: both locked for today
- Candidate selection defaults:
  - Expanded base universe includes large/mid-cap KRX names
  - Market factor uses log-scaled liquidity score (less large-cap saturation)
  - Top ranking uses diversified sampling by sector + market-cap bucket
- Manual boundary check (same runtime logic used by API):
  - `powershell -NoProfile -Command "cd backend; .\venv\Scripts\python.exe scripts\check_strategy_boundary.py"`
  - Optional date: `powershell -NoProfile -Command "cd backend; .\venv\Scripts\python.exe scripts\check_strategy_boundary.py --date 2026-02-23"`
- PID/log files are stored in:
  - `%TEMP%\web_stock_trainning_dev_state`
