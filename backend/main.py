from __future__ import annotations

import csv
import hashlib
import io
import json
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Any, Dict, Optional

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import func, select

from db.models import AIReport, BacktestResult, UserWatchlist
from db.session import init_db, is_db_enabled, session_scope
from services.backtest_service import backfill_snapshots, get_backtest_history, get_backtest_summary
from services.llm_service import (
    bootstrap_llm_runtime,
    ensure_ai_report_shape,
    generate_ai_report,
    get_llm_runtime_status,
)
from services.news_service import get_news_and_themes
from services.scoring_service import (
    DEFAULT_WEIGHTS,
    TICKERS,
    detect_market_regime,
    fetch_and_score_stocks,
    get_strategy_status,
    get_trading_calendar_runtime_status,
    get_market_indices,
    get_market_overview,
    now_in_kst,
    normalize_weights,
    validate_strategy_request,
    validate_recommendation_request_date,
)


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    bootstrap_llm_runtime(probe=True)
    yield


app = FastAPI(title="DailyStock AI API", version="2.1.0", lifespan=lifespan)

_CACHE: Dict[str, Any] = {}
_WATCHLIST: Dict[str, set[str]] = {}
_MIN_CANDIDATE_CACHE_COUNT = max(6, int(len(TICKERS) * 0.75))

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class BackfillRequest(BaseModel):
    start_date: str
    end_date: str


class WatchlistRequest(BaseModel):
    user_key: str = "default"
    tickers: list[str] = Field(default_factory=list)


def _build_cache_key(prefix: str, **kwargs: Any) -> str:
    ordered = "&".join(f"{k}={kwargs[k]}" for k in sorted(kwargs.keys()))
    return f"{prefix}:{ordered}"


def _intraday_cache_bucket(strategy: str, session_date: str) -> str:
    if strategy != "intraday":
        return ""
    now = now_in_kst()
    if session_date != now.date().isoformat():
        return ""
    floored = now.replace(minute=(now.minute // 5) * 5, second=0, microsecond=0)
    return floored.strftime("%Y%m%d%H%M")


def _is_candidate_cache_valid(candidates: Any) -> bool:
    return isinstance(candidates, list) and len(candidates) >= _MIN_CANDIDATE_CACHE_COUNT


def _fetch_candidates_best_effort(
    *,
    date: Optional[str],
    weights: dict[str, float],
    include_sparkline: bool,
    strategy: str,
    session_date: str,
    custom_tickers: list[str],
    enforce_exposure_cap: bool,
    max_per_sector: int,
    cap_top_n: int,
    attempts: int = 2,
) -> dict[str, Any]:
    best_payload: dict[str, Any] | None = None
    for _ in range(max(1, attempts)):
        payload = fetch_and_score_stocks(
            date_str=date,
            weights=weights,
            include_sparkline=include_sparkline,
            strategy=strategy,
            session_date_str=session_date,
            custom_tickers=custom_tickers,
            enforce_exposure_cap=enforce_exposure_cap,
            max_per_sector=max_per_sector,
            cap_top_n=cap_top_n,
        )
        if best_payload is None or len(payload["candidates"]) > len(best_payload["candidates"]):
            best_payload = payload
        if _is_candidate_cache_valid(payload["candidates"]):
            break
    return (
        best_payload
        if best_payload is not None
        else {"date": date, "sessionDate": session_date, "signalDate": date, "strategy": strategy, "candidates": []}
    )


def _decorate_candidates_for_response(
    *,
    candidates: list[dict[str, Any]],
    session_date: str,
    effective_date: str,
    resolved_strategy: str,
    strategy_reason: str,
    weights: dict[str, float],
    regime_name: str | None,
) -> list[dict[str, Any]]:
    decorated: list[dict[str, Any]] = []
    for candidate in candidates:
        item = dict(candidate)
        item["realDate"] = session_date
        item["strategy"] = resolved_strategy
        item["sessionDate"] = session_date
        item["signalDate"] = effective_date
        item["strategyReason"] = strategy_reason
        item["appliedWeights"] = weights
        if regime_name:
            item["regime"] = regime_name
        else:
            item.pop("regime", None)
        decorated.append(item)
    return decorated


def _parse_ticker_csv(raw: Optional[str]) -> list[str]:
    if not raw:
        return []
    items = [t.strip().upper() for t in raw.split(",")]
    return [item for item in items if item]


def _normalize_input_ticker(ticker: str) -> str:
    return ticker.strip().upper()


def _get_watchlist_tickers(user_key: str) -> list[str]:
    user_key = user_key or "default"
    if is_db_enabled():
        with session_scope() as session:
            rows = session.scalars(select(UserWatchlist).where(UserWatchlist.user_key == user_key)).all()
            return [row.ticker for row in rows]
    return sorted(list(_WATCHLIST.get(user_key, set())))


def _add_watchlist_tickers(user_key: str, tickers: list[str]) -> list[str]:
    user_key = user_key or "default"
    normalized = [_normalize_input_ticker(t) for t in tickers if t.strip()]
    if is_db_enabled():
        with session_scope() as session:
            existing = {
                row.ticker
                for row in session.scalars(select(UserWatchlist).where(UserWatchlist.user_key == user_key)).all()
            }
            for ticker in normalized:
                if ticker in existing:
                    continue
                session.add(UserWatchlist(user_key=user_key, ticker=ticker))
            session.flush()
            rows = session.scalars(select(UserWatchlist).where(UserWatchlist.user_key == user_key)).all()
            return sorted([row.ticker for row in rows])

    bucket = _WATCHLIST.setdefault(user_key, set())
    for ticker in normalized:
        bucket.add(ticker)
    return sorted(list(bucket))


def _set_watchlist_tickers(user_key: str, tickers: list[str]) -> list[str]:
    user_key = user_key or "default"
    normalized = sorted({_normalize_input_ticker(t) for t in tickers if t.strip()})
    if is_db_enabled():
        with session_scope() as session:
            rows = session.scalars(select(UserWatchlist).where(UserWatchlist.user_key == user_key)).all()
            for row in rows:
                session.delete(row)
            session.flush()
            for ticker in normalized:
                session.add(UserWatchlist(user_key=user_key, ticker=ticker))
            session.flush()
            rows = session.scalars(select(UserWatchlist).where(UserWatchlist.user_key == user_key)).all()
            return sorted([row.ticker for row in rows])

    _WATCHLIST[user_key] = set(normalized)
    return normalized


def _remove_watchlist_ticker(user_key: str, ticker: str) -> list[str]:
    user_key = user_key or "default"
    ticker = _normalize_input_ticker(ticker)
    if is_db_enabled():
        with session_scope() as session:
            row = session.scalar(
                select(UserWatchlist).where(
                    UserWatchlist.user_key == user_key,
                    UserWatchlist.ticker == ticker,
                )
            )
            if row:
                session.delete(row)
            session.flush()
            rows = session.scalars(select(UserWatchlist).where(UserWatchlist.user_key == user_key)).all()
            return sorted([r.ticker for r in rows])

    bucket = _WATCHLIST.setdefault(user_key, set())
    bucket.discard(ticker)
    return sorted(list(bucket))


def _parse_tickers_from_csv_bytes(content: bytes) -> tuple[list[str], list[dict[str, Any]]]:
    text = content.decode("utf-8-sig", errors="ignore")
    reader = csv.reader(io.StringIO(text))
    rows = [row for row in reader if row and any(cell.strip() for cell in row)]
    if not rows:
        return [], []

    header = [h.strip().lower() for h in rows[0]]
    ticker_col = None
    for idx, name in enumerate(header):
        if name in {"ticker", "code", "symbol", "종목코드", "종목"}:
            ticker_col = idx
            break

    data_rows = rows[1:] if ticker_col is not None else rows
    tickers: list[str] = []
    invalid_rows: list[dict[str, Any]] = []
    for line, row in enumerate(data_rows, start=2 if ticker_col is not None else 1):
        value = row[ticker_col].strip() if ticker_col is not None and ticker_col < len(row) else row[0].strip()
        if not value:
            invalid_rows.append({"line": line, "reason": "빈 티커 값"})
            continue
        tickers.append(value.upper())
    return tickers, invalid_rows


def _resolve_custom_tickers(user_key: str, custom_tickers_csv: Optional[str]) -> list[str]:
    watchlist = _get_watchlist_tickers(user_key)
    adhoc = _parse_ticker_csv(custom_tickers_csv)
    merged = []
    seen = set()
    for ticker in watchlist + adhoc:
        t = _normalize_input_ticker(ticker)
        if t in seen:
            continue
        seen.add(t)
        merged.append(t)
    return merged


def _resolve_weights(
    date: Optional[str],
    custom_tickers: list[str],
    w_return: float,
    w_stability: float,
    w_market: float,
    auto_regime_weights: bool,
) -> tuple[dict[str, float], dict[str, Any] | None]:
    if not auto_regime_weights:
        try:
            return normalize_weights(w_return, w_stability, w_market), None
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc

    baseline = fetch_and_score_stocks(
        date_str=date,
        weights=DEFAULT_WEIGHTS,
        include_sparkline=False,
        custom_tickers=custom_tickers,
        enforce_exposure_cap=False,
    )
    indices = get_market_indices(baseline["date"])
    regime = detect_market_regime(baseline["candidates"], indices)
    suggested = regime["suggestedWeights"]
    return normalize_weights(
        suggested["return"],
        suggested["stability"],
        suggested["market"],
    ), regime


def _ensure_recommendation_date_allowed(date: Optional[str]) -> str:
    effective_date, error = validate_recommendation_request_date(date)
    if error:
        raise HTTPException(status_code=400, detail=error)
    return effective_date


def _strategy_error(code: str, message: str) -> HTTPException:
    return HTTPException(status_code=400, detail={"code": code, "message": message})


def _ensure_strategy_allowed(date: Optional[str], strategy: Optional[str]) -> dict[str, Any]:
    resolved = validate_strategy_request(requested_strategy=strategy, requested_date_str=date)
    error_code = resolved.get("errorCode")
    if error_code:
        detail = str(resolved.get("detail") or "요청한 전략을 사용할 수 없습니다.")
        raise _strategy_error(str(error_code), detail)
    return resolved


def _find_candidate(
    ticker: str,
    date: Optional[str],
    weights: dict[str, float],
    strategy: str,
    session_date: str,
    custom_tickers: list[str],
) -> tuple[dict[str, Any], str]:
    payload = fetch_and_score_stocks(
        date_str=date,
        weights=weights,
        include_sparkline=True,
        strategy=strategy,
        session_date_str=session_date,
        custom_tickers=custom_tickers,
        enforce_exposure_cap=False,
    )
    for candidate in payload["candidates"]:
        if candidate["code"] == ticker:
            return candidate, payload["date"]
    raise HTTPException(status_code=404, detail="현재 분석 후보에서 해당 종목을 찾을 수 없습니다.")


@app.get("/api/v1/watchlist")
def get_watchlist(user_key: str = Query(default="default")) -> dict[str, Any]:
    return {"userKey": user_key, "tickers": _get_watchlist_tickers(user_key)}


@app.post("/api/v1/watchlist")
def upsert_watchlist(payload: WatchlistRequest) -> dict[str, Any]:
    tickers = _add_watchlist_tickers(payload.user_key, payload.tickers)
    return {"userKey": payload.user_key, "tickers": tickers}


@app.post("/api/v1/watchlist/upload")
def upload_watchlist(payload: WatchlistRequest) -> dict[str, Any]:
    tickers = _add_watchlist_tickers(payload.user_key, payload.tickers)
    return {"userKey": payload.user_key, "tickers": tickers}


@app.post("/api/v1/watchlist/upload-csv")
async def upload_watchlist_csv(
    file: UploadFile = File(...),
    user_key: str = Form(default="default"),
    replace: bool = Form(default=False),
) -> dict[str, Any]:
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="CSV 파일이 비어 있습니다.")

    tickers, invalid_rows = _parse_tickers_from_csv_bytes(content)
    if not tickers:
        raise HTTPException(status_code=400, detail="CSV에서 티커 행을 찾지 못했습니다.")

    if replace:
        merged = _set_watchlist_tickers(user_key=user_key, tickers=tickers)
    else:
        merged = _add_watchlist_tickers(user_key=user_key, tickers=tickers)
    return {
        "userKey": user_key,
        "tickers": merged,
        "uploadedCount": len(tickers),
        "invalidRows": invalid_rows,
        "mode": "replace" if replace else "append",
    }


@app.delete("/api/v1/watchlist/{ticker}")
def delete_watchlist_ticker(
    ticker: str,
    user_key: str = Query(default="default"),
) -> dict[str, Any]:
    tickers = _remove_watchlist_ticker(user_key=user_key, ticker=ticker)
    return {"userKey": user_key, "tickers": tickers}


@app.get("/api/v1/strategy-status")
def strategy_status(
    date: Optional[str] = None,
) -> dict[str, Any]:
    status = get_strategy_status(requested_date_str=date)
    if status.get("errorCode") == "INVALID_DATE":
        raise _strategy_error(str(status["errorCode"]), str(status.get("detail") or "유효하지 않은 날짜 형식입니다."))
    return {
        "timezone": status["timezone"],
        "nowKst": status["nowKst"],
        "requestedDate": status["requestedDate"],
        "availableStrategies": status["availableStrategies"],
        "defaultStrategy": status["defaultStrategy"],
        "messages": status["messages"],
        "errorCode": status.get("errorCode"),
        "detail": status.get("detail"),
        "nonTradingDay": status.get("nonTradingDay"),
    }


@app.get("/api/v1/weights/recommendation")
def weights_recommendation(
    date: Optional[str] = None,
    user_key: str = Query(default="default"),
    custom_tickers: Optional[str] = Query(default=None),
) -> dict[str, Any]:
    effective_date = _ensure_recommendation_date_allowed(date)
    resolved_custom = _resolve_custom_tickers(user_key=user_key, custom_tickers_csv=custom_tickers)
    payload = fetch_and_score_stocks(
        date_str=effective_date,
        weights=DEFAULT_WEIGHTS,
        include_sparkline=False,
        custom_tickers=resolved_custom,
        enforce_exposure_cap=False,
    )
    indices = get_market_indices(payload["date"])
    regime = detect_market_regime(payload["candidates"], indices)
    return {"date": payload["date"], "customTickers": resolved_custom, "regimeRecommendation": regime}


@app.get("/api/v1/market-overview")
def market_overview(
    date: Optional[str] = None,
    user_key: str = Query(default="default"),
    custom_tickers: Optional[str] = Query(default=None),
    strategy: Optional[str] = Query(default=None),
) -> dict[str, Any]:
    strategy_ctx = _ensure_strategy_allowed(date=date, strategy=strategy)
    effective_date = str(strategy_ctx["signalDate"])
    session_date = str(strategy_ctx["sessionDate"])
    resolved_strategy = str(strategy_ctx["strategy"])
    strategy_reason = str(strategy_ctx.get("strategyReason") or "")
    resolved_custom = _resolve_custom_tickers(user_key=user_key, custom_tickers_csv=custom_tickers)
    cache_key = _build_cache_key(
        "overview",
        date=effective_date,
        session_date=session_date,
        strategy=resolved_strategy,
        intraday_bucket=_intraday_cache_bucket(resolved_strategy, session_date),
        user_key=user_key,
        custom=",".join(sorted(resolved_custom)),
    )
    cached_overview = _CACHE.get(cache_key)
    if isinstance(cached_overview, dict):
        total = int(cached_overview.get("up", 0)) + int(cached_overview.get("down", 0)) + int(cached_overview.get("steady", 0))
        if total >= _MIN_CANDIDATE_CACHE_COUNT:
            return cached_overview

    data = _fetch_candidates_best_effort(
        date=effective_date,
        weights=DEFAULT_WEIGHTS,
        include_sparkline=False,
        strategy=resolved_strategy,
        session_date=session_date,
        custom_tickers=resolved_custom,
        enforce_exposure_cap=False,
        max_per_sector=2,
        cap_top_n=5,
    )
    indices = get_market_indices(data["date"])
    overview = get_market_overview(data["candidates"], indices=indices)
    overview["candidateCount"] = len(data["candidates"])
    overview["strategy"] = resolved_strategy
    overview["sessionDate"] = session_date
    overview["signalDate"] = effective_date
    overview["strategyReason"] = strategy_reason
    _CACHE[cache_key] = overview
    return overview


@app.get("/api/v1/stock-candidates")
def stock_candidates(
    date: Optional[str] = None,
    w_return: float = Query(default=0.4),
    w_stability: float = Query(default=0.3),
    w_market: float = Query(default=0.3),
    include_sparkline: bool = Query(default=True),
    user_key: str = Query(default="default"),
    custom_tickers: Optional[str] = Query(default=None),
    strategy: Optional[str] = Query(default=None),
    auto_regime_weights: bool = Query(default=False),
    enforce_exposure_cap: bool = Query(default=False),
    max_per_sector: int = Query(default=2, ge=1, le=5),
    cap_top_n: int = Query(default=5, ge=1, le=20),
) -> list[dict[str, Any]]:
    strategy_ctx = _ensure_strategy_allowed(date=date, strategy=strategy)
    effective_date = str(strategy_ctx["signalDate"])
    session_date = str(strategy_ctx["sessionDate"])
    resolved_strategy = str(strategy_ctx["strategy"])
    strategy_reason = str(strategy_ctx.get("strategyReason") or "")
    resolved_custom = _resolve_custom_tickers(user_key=user_key, custom_tickers_csv=custom_tickers)
    weights, regime = _resolve_weights(
        date=effective_date,
        custom_tickers=resolved_custom,
        w_return=w_return,
        w_stability=w_stability,
        w_market=w_market,
        auto_regime_weights=auto_regime_weights,
    )
    cache_key = _build_cache_key(
        "candidates",
        date=effective_date,
        session_date=session_date,
        strategy=resolved_strategy,
        intraday_bucket=_intraday_cache_bucket(resolved_strategy, session_date),
        user_key=user_key,
        custom=",".join(sorted(resolved_custom)),
        w_return=weights["return"],
        w_stability=weights["stability"],
        w_market=weights["market"],
        include_sparkline=include_sparkline,
        cap=enforce_exposure_cap,
        max_per_sector=max_per_sector,
        cap_top_n=cap_top_n,
        auto=auto_regime_weights,
    )
    cached_candidates = _CACHE.get(cache_key)
    if _is_candidate_cache_valid(cached_candidates):
        return _decorate_candidates_for_response(
            candidates=cached_candidates,
            session_date=session_date,
            effective_date=effective_date,
            resolved_strategy=resolved_strategy,
            strategy_reason=strategy_reason,
            weights=weights,
            regime_name=regime["regime"] if regime else None,
        )

    payload = _fetch_candidates_best_effort(
        date=effective_date,
        weights=weights,
        include_sparkline=include_sparkline,
        strategy=resolved_strategy,
        session_date=session_date,
        custom_tickers=resolved_custom,
        enforce_exposure_cap=enforce_exposure_cap,
        max_per_sector=max_per_sector,
        cap_top_n=cap_top_n,
    )
    fresh = _decorate_candidates_for_response(
        candidates=payload["candidates"],
        session_date=session_date,
        effective_date=effective_date,
        resolved_strategy=resolved_strategy,
        strategy_reason=strategy_reason,
        weights=weights,
        regime_name=regime["regime"] if regime else None,
    )
    if _is_candidate_cache_valid(fresh):
        _CACHE[cache_key] = fresh
        return fresh

    if isinstance(cached_candidates, list) and len(cached_candidates) > len(fresh):
        return _decorate_candidates_for_response(
            candidates=cached_candidates,
            session_date=session_date,
            effective_date=effective_date,
            resolved_strategy=resolved_strategy,
            strategy_reason=strategy_reason,
            weights=weights,
            regime_name=regime["regime"] if regime else None,
        )
    _CACHE[cache_key] = fresh
    return fresh


@app.get("/api/v1/stocks/{ticker}/detail")
def stock_detail(
    ticker: str,
    date: Optional[str] = None,
    w_return: float = Query(default=0.4),
    w_stability: float = Query(default=0.3),
    w_market: float = Query(default=0.3),
    include_news: bool = Query(default=True),
    include_ai: bool = Query(default=True),
    user_key: str = Query(default="default"),
    custom_tickers: Optional[str] = Query(default=None),
    strategy: Optional[str] = Query(default=None),
    auto_regime_weights: bool = Query(default=False),
    account_size: float = Query(default=10_000_000.0, gt=0),
    risk_per_trade_pct: float = Query(default=1.0, gt=0, le=10),
) -> dict[str, Any]:
    strategy_ctx = _ensure_strategy_allowed(date=date, strategy=strategy)
    effective_date = str(strategy_ctx["signalDate"])
    session_date = str(strategy_ctx["sessionDate"])
    resolved_strategy = str(strategy_ctx["strategy"])
    strategy_reason = str(strategy_ctx.get("strategyReason") or "")
    resolved_custom = _resolve_custom_tickers(user_key=user_key, custom_tickers_csv=custom_tickers)
    weights, _ = _resolve_weights(
        date=effective_date,
        custom_tickers=resolved_custom,
        w_return=w_return,
        w_stability=w_stability,
        w_market=w_market,
        auto_regime_weights=auto_regime_weights,
    )
    candidate, trade_date = _find_candidate(
        ticker=ticker,
        date=effective_date,
        weights=weights,
        strategy=resolved_strategy,
        session_date=session_date,
        custom_tickers=resolved_custom,
    )
    content_trade_date = session_date if resolved_strategy == "premarket" else trade_date

    result = {
        "ticker": ticker,
        "name": candidate["name"],
        "strategy": resolved_strategy,
        "sessionDate": session_date,
        "signalDate": effective_date,
        "strategyReason": strategy_reason,
        "currentPrice": candidate["price"],
        "targetPrice": candidate["targetPrice"],
        "stopLoss": candidate["stopLoss"],
        "high60": candidate.get("high60", candidate["price"]),
        "low10": candidate.get("low10", candidate["price"]),
        "expectedReturn": round(((candidate["targetPrice"] - candidate["price"]) / candidate["price"]) * 100, 2),
        "tags": candidate.get("tags", []),
        "sector": candidate.get("sector", "기타"),
        "signals": [{"type": "buy" if candidate["score"] > 5 else "sell", "message": candidate["summary"]}],
        "newsItems": [],
        "newsSummary3": [],
        "themes": [],
        "aiReport": None,
        "positionSizing": None,
    }

    stop_distance = max(float(candidate["price"] - candidate["stopLoss"]), float(candidate["price"] * 0.01))
    risk_budget = account_size * (risk_per_trade_pct / 100.0)
    shares = int(max(1, risk_budget // stop_distance))
    result["positionSizing"] = {
        "accountSize": round(account_size, 2),
        "riskPerTradePct": round(risk_per_trade_pct, 4),
        "stopDistance": round(stop_distance, 4),
        "shares": shares,
        "capitalRequired": round(shares * float(candidate["price"]), 2),
        "riskAmount": round(shares * stop_distance, 2),
    }

    news_items: list[dict[str, str]] = []
    news_summary: list[str] = []
    themes: list[str] = []
    if include_news:
        news_items, news_summary, themes = get_news_and_themes(code=ticker, trade_date=content_trade_date)
        result["newsItems"] = news_items
        result["newsSummary3"] = news_summary
        result["themes"] = themes

    if include_ai:
        cache_hit = None
        prompt_hash = hashlib.sha256(
            json.dumps(
                {
                    "ticker": ticker,
                    "date": content_trade_date,
                    "summary": candidate["summary"],
                    "news": news_summary,
                    "themes": themes,
                },
                ensure_ascii=False,
                sort_keys=True,
            ).encode("utf-8")
        ).hexdigest()

        if is_db_enabled():
            with session_scope() as session:
                cache_hit = session.scalar(
                    select(AIReport).where(
                        AIReport.ticker == ticker,
                        AIReport.trade_date == datetime.strptime(content_trade_date, "%Y-%m-%d").date(),
                        AIReport.prompt_hash == prompt_hash,
                    )
                )

        if cache_hit:
            result["aiReport"] = ensure_ai_report_shape(
                cache_hit.report,
                stock=candidate,
                news_summary=news_summary,
                themes=themes,
            )
        else:
            ai_report = generate_ai_report(
                stock=candidate,
                news_summary=news_summary,
                themes=themes,
                trade_date=content_trade_date,
            )
            normalized_report = ensure_ai_report_shape(
                ai_report,
                stock=candidate,
                news_summary=news_summary,
                themes=themes,
            )
            result["aiReport"] = normalized_report
            if is_db_enabled():
                with session_scope() as session:
                    session.add(
                        AIReport(
                            ticker=ticker,
                            trade_date=datetime.strptime(content_trade_date, "%Y-%m-%d").date(),
                            provider=normalized_report["provider"],
                            model=normalized_report["model"],
                            prompt_hash=prompt_hash,
                            report=normalized_report,
                        )
                    )
    return result


@app.get("/api/v1/market-insight")
def market_insight(
    date: Optional[str] = None,
    w_return: float = Query(default=0.4),
    w_stability: float = Query(default=0.3),
    w_market: float = Query(default=0.3),
    user_key: str = Query(default="default"),
    custom_tickers: Optional[str] = Query(default=None),
    strategy: Optional[str] = Query(default=None),
    auto_regime_weights: bool = Query(default=False),
    enforce_exposure_cap: bool = Query(default=False),
    max_per_sector: int = Query(default=2, ge=1, le=5),
    cap_top_n: int = Query(default=5, ge=1, le=20),
) -> dict[str, Any]:
    strategy_ctx = _ensure_strategy_allowed(date=date, strategy=strategy)
    effective_date = str(strategy_ctx["signalDate"])
    session_date = str(strategy_ctx["sessionDate"])
    resolved_strategy = str(strategy_ctx["strategy"])
    strategy_reason = str(strategy_ctx.get("strategyReason") or "")
    resolved_custom = _resolve_custom_tickers(user_key=user_key, custom_tickers_csv=custom_tickers)
    weights, regime = _resolve_weights(
        date=effective_date,
        custom_tickers=resolved_custom,
        w_return=w_return,
        w_stability=w_stability,
        w_market=w_market,
        auto_regime_weights=auto_regime_weights,
    )
    candidates = stock_candidates(
        date=session_date,
        w_return=weights["return"],
        w_stability=weights["stability"],
        w_market=weights["market"],
        include_sparkline=False,
        user_key=user_key,
        custom_tickers=",".join(resolved_custom) if resolved_custom else None,
        strategy=resolved_strategy,
        auto_regime_weights=False,
        enforce_exposure_cap=enforce_exposure_cap,
        max_per_sector=max_per_sector,
        cap_top_n=cap_top_n,
    )
    overview = get_market_overview(candidates)
    up = overview.get("up", 0)
    down = overview.get("down", 0)

    risk_factors: list[dict[str, str]] = []
    if down > up * 2:
        risk_factors.append({"id": "Risk 1", "description": "시장 전반 하락 압력이 높아 보수적인 진입이 유효합니다."})
        conclusion = "안정성 비중을 높이고 손절 규칙을 엄격히 유지하는 전략이 필요합니다."
    elif up > down * 2:
        risk_factors.append({"id": "Risk 1", "description": "상승 탄력이 강하지만 단기 과열 가능성에 주의해야 합니다."})
        conclusion = "수익 구간 분할 매도와 추세 추종을 병행하는 전략이 유효합니다."
    else:
        risk_factors.append({"id": "Risk 1", "description": "종목별 차별화 장세가 이어져 선택적 접근이 필요합니다."})
        conclusion = "가중치를 활용해 선호 팩터 중심으로 후보를 압축해 접근하는 것이 좋습니다."

    if regime:
        risk_factors.append(
            {
                "id": "Regime",
                "description": f"현재 국면은 {regime['label']}로 판단되며 추천 가중치는 {regime['suggestedWeights']} 입니다.",
            }
        )

    return {
        "date": session_date,
        "strategy": resolved_strategy,
        "sessionDate": session_date,
        "signalDate": effective_date,
        "strategyReason": strategy_reason,
        "riskFactors": risk_factors,
        "conclusion": conclusion,
    }


@app.post("/api/v1/backtest/snapshots/backfill")
def backtest_snapshots_backfill(req: BackfillRequest) -> dict[str, Any]:
    if not is_db_enabled():
        raise HTTPException(status_code=503, detail="데이터베이스가 설정되지 않았습니다. DATABASE_URL을 먼저 설정하세요.")
    inserted = backfill_snapshots(req.start_date, req.end_date)
    return {"inserted": inserted, "startDate": req.start_date, "endDate": req.end_date}


@app.get("/api/v1/backtest/summary")
def backtest_summary(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    fee_bps: float = Query(default=10.0, ge=0),
    slippage_bps: float = Query(default=5.0, ge=0),
) -> dict[str, Any]:
    if not is_db_enabled():
        raise HTTPException(status_code=503, detail="데이터베이스가 설정되지 않았습니다. DATABASE_URL을 먼저 설정하세요.")
    return get_backtest_summary(
        start_date=start_date,
        end_date=end_date,
        fee_bps=fee_bps,
        slippage_bps=slippage_bps,
    )


@app.get("/api/v1/backtest/history")
def backtest_history(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    page: int = Query(default=1, ge=1),
    size: int = Query(default=20, ge=1, le=200),
    fee_bps: float = Query(default=10.0, ge=0),
    slippage_bps: float = Query(default=5.0, ge=0),
) -> dict[str, Any]:
    if not is_db_enabled():
        raise HTTPException(status_code=503, detail="데이터베이스가 설정되지 않았습니다. DATABASE_URL을 먼저 설정하세요.")
    return get_backtest_history(
        start_date=start_date,
        end_date=end_date,
        page=page,
        size=size,
        fee_bps=fee_bps,
        slippage_bps=slippage_bps,
    )


@app.get("/api/v1/health")
def health() -> dict[str, Any]:
    llm_status = get_llm_runtime_status()
    calendar_status = get_trading_calendar_runtime_status()
    warnings = list(llm_status.get("warnings", []))
    if not calendar_status.get("ready"):
        warnings.append(
            f"거래일 캘린더 외부 소스를 사용할 수 없어({calendar_status.get('reason')}), yfinance 보조 로직으로 동작합니다."
        )

    if not is_db_enabled():
        warnings.append("데이터베이스가 비활성화되어 있습니다. 영속 저장을 사용하려면 DATABASE_URL을 설정하세요.")
        return {
            "ok": True,
            "database": "disabled",
            "tradingCalendar": calendar_status,
            "llm": llm_status,
            "warnings": warnings,
        }
    with session_scope() as session:
        count = session.scalar(select(func.count(BacktestResult.id))) or 0
        watchlist_count = session.scalar(select(func.count(UserWatchlist.id))) or 0
    return {
        "ok": True,
        "database": "enabled",
        "backtestRows": count,
        "watchlistRows": watchlist_count,
        "tradingCalendar": calendar_status,
        "llm": llm_status,
        "warnings": warnings,
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
