from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

import pandas as pd
from sqlalchemy import and_, func, select

from db.models import BacktestResult, RecommendationSnapshot
from db.session import session_scope
from services.scoring_service import DEFAULT_WEIGHTS, fetch_and_score_stocks, get_price_series_for_ticker, resolve_company_name


def compute_forward_returns(close: pd.Series, trade_date: str) -> dict[str, float | None]:
    if close.empty:
        return {"ret_t1": None, "ret_t3": None, "ret_t5": None}

    close = close.sort_index()
    trade_day = datetime.strptime(trade_date, "%Y-%m-%d").date()
    entry_pos = None
    for idx, ts in enumerate(close.index):
        idx_date = ts.date() if hasattr(ts, "date") else pd.Timestamp(ts).date()
        if idx_date >= trade_day:
            entry_pos = idx
            break
    if entry_pos is None:
        return {"ret_t1": None, "ret_t3": None, "ret_t5": None}

    entry_price = float(close.iloc[entry_pos])

    def _ret(offset: int) -> float | None:
        pos = entry_pos + offset
        if pos >= len(close):
            return None
        future_price = float(close.iloc[pos])
        return round(((future_price - entry_price) / entry_price) * 100, 4)

    return {"ret_t1": _ret(1), "ret_t3": _ret(3), "ret_t5": _ret(5)}


def _daterange(start_date: str, end_date: str) -> list[str]:
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")
    out: list[str] = []
    while start <= end:
        if start.weekday() < 5:
            out.append(start.strftime("%Y-%m-%d"))
        start += timedelta(days=1)
    return out


def _upsert_snapshot(session, trade_date: str, candidate: dict[str, Any]) -> None:
    d = datetime.strptime(trade_date, "%Y-%m-%d").date()
    existing = session.scalar(
        select(RecommendationSnapshot).where(
            RecommendationSnapshot.trade_date == d,
            RecommendationSnapshot.ticker == candidate["code"],
        )
    )
    if existing:
        existing.rank = int(candidate["rank"])
        existing.price = float(candidate["price"])
        existing.score_return = float(candidate["details"]["raw"]["return"])
        existing.score_stability = float(candidate["details"]["raw"]["stability"])
        existing.score_market = float(candidate["details"]["raw"]["market"])
        existing.total_score = float(candidate["score"])
        existing.target_price = float(candidate["targetPrice"])
        existing.stop_loss = float(candidate["stopLoss"])
        existing.tags = candidate.get("tags", [])
        existing.sparkline60 = candidate.get("sparkline60", [])
        return

    session.add(
        RecommendationSnapshot(
            trade_date=d,
            ticker=candidate["code"],
            rank=int(candidate["rank"]),
            price=float(candidate["price"]),
            score_return=float(candidate["details"]["raw"]["return"]),
            score_stability=float(candidate["details"]["raw"]["stability"]),
            score_market=float(candidate["details"]["raw"]["market"]),
            total_score=float(candidate["score"]),
            target_price=float(candidate["targetPrice"]),
            stop_loss=float(candidate["stopLoss"]),
            tags=candidate.get("tags", []),
            sparkline60=candidate.get("sparkline60", []),
        )
    )


def _upsert_backtest(session, trade_date: str, candidate: dict[str, Any]) -> None:
    d = datetime.strptime(trade_date, "%Y-%m-%d").date()
    close_series = get_price_series_for_ticker(candidate["code"], trade_date=trade_date, future_days=7)
    returns = compute_forward_returns(close_series, trade_date=trade_date)
    existing = session.scalar(
        select(BacktestResult).where(
            BacktestResult.trade_date == d,
            BacktestResult.ticker == candidate["code"],
        )
    )
    if existing:
        existing.entry_price = float(candidate["price"])
        existing.ret_t1 = returns["ret_t1"]
        existing.ret_t3 = returns["ret_t3"]
        existing.ret_t5 = returns["ret_t5"]
        return

    session.add(
        BacktestResult(
            trade_date=d,
            ticker=candidate["code"],
            entry_price=float(candidate["price"]),
            ret_t1=returns["ret_t1"],
            ret_t3=returns["ret_t3"],
            ret_t5=returns["ret_t5"],
        )
    )


def backfill_snapshots(start_date: str, end_date: str) -> int:
    inserted = 0
    for day in _daterange(start_date, end_date):
        scored = fetch_and_score_stocks(date_str=day, weights=DEFAULT_WEIGHTS, include_sparkline=True)
        trade_date = scored["date"]
        top5 = scored["candidates"][:5]
        with session_scope() as session:
            for candidate in top5:
                _upsert_snapshot(session, trade_date, candidate)
                _upsert_backtest(session, trade_date, candidate)
                inserted += 1
    return inserted


def _date_filter(model_field, start_date: str | None, end_date: str | None):
    conditions = []
    if start_date:
        conditions.append(model_field >= datetime.strptime(start_date, "%Y-%m-%d").date())
    if end_date:
        conditions.append(model_field <= datetime.strptime(end_date, "%Y-%m-%d").date())
    if not conditions:
        return None
    return and_(*conditions)


def _net_return(value: float | None, fee_bps: float, slippage_bps: float) -> float | None:
    if value is None:
        return None
    round_trip_cost_pct = ((fee_bps + slippage_bps) * 2) / 100.0
    return round(value - round_trip_cost_pct, 4)


def get_backtest_summary(
    start_date: str | None,
    end_date: str | None,
    fee_bps: float = 10.0,
    slippage_bps: float = 5.0,
) -> dict[str, Any]:
    where_cond = _date_filter(BacktestResult.trade_date, start_date, end_date)
    with session_scope() as session:
        query = select(BacktestResult)
        if where_cond is not None:
            query = query.where(where_cond)
        rows = session.scalars(query).all()

    def _avg(values: list[float | None]) -> float:
        valid = [v for v in values if v is not None]
        return round(sum(valid) / len(valid), 4) if valid else 0.0

    def _win(values: list[float | None]) -> float:
        valid = [v for v in values if v is not None]
        return round((len([v for v in valid if v > 0]) / len(valid)) * 100, 2) if valid else 0.0

    def _mdd(values: list[float | None]) -> float:
        valid = [v for v in values if v is not None]
        return round(min(valid), 4) if valid else 0.0

    ret_t1 = [r.ret_t1 for r in rows]
    ret_t3 = [r.ret_t3 for r in rows]
    ret_t5 = [r.ret_t5 for r in rows]
    net_t1 = [_net_return(v, fee_bps=fee_bps, slippage_bps=slippage_bps) for v in ret_t1]
    net_t3 = [_net_return(v, fee_bps=fee_bps, slippage_bps=slippage_bps) for v in ret_t3]
    net_t5 = [_net_return(v, fee_bps=fee_bps, slippage_bps=slippage_bps) for v in ret_t5]
    return {
        "startDate": start_date,
        "endDate": end_date,
        "count": len(rows),
        "assumptions": {"feeBps": fee_bps, "slippageBps": slippage_bps},
        "metrics": {
            "avgRetT1": _avg(ret_t1),
            "avgRetT3": _avg(ret_t3),
            "avgRetT5": _avg(ret_t5),
            "avgNetRetT1": _avg(net_t1),
            "avgNetRetT3": _avg(net_t3),
            "avgNetRetT5": _avg(net_t5),
            "winRateT1": _win(ret_t1),
            "winRateT3": _win(ret_t3),
            "winRateT5": _win(ret_t5),
            "netWinRateT1": _win(net_t1),
            "netWinRateT3": _win(net_t3),
            "netWinRateT5": _win(net_t5),
            "mddT1": _mdd(ret_t1),
            "mddT3": _mdd(ret_t3),
            "mddT5": _mdd(ret_t5),
            "netMddT1": _mdd(net_t1),
            "netMddT3": _mdd(net_t3),
            "netMddT5": _mdd(net_t5),
        },
    }


def get_backtest_history(
    start_date: str | None,
    end_date: str | None,
    page: int,
    size: int,
    fee_bps: float = 10.0,
    slippage_bps: float = 5.0,
) -> dict[str, Any]:
    where_cond = _date_filter(BacktestResult.trade_date, start_date, end_date)
    offset = (page - 1) * size
    with session_scope() as session:
        total_query = select(func.count(BacktestResult.id))
        data_query = select(BacktestResult).order_by(BacktestResult.trade_date.desc(), BacktestResult.ticker.asc())
        if where_cond is not None:
            total_query = total_query.where(where_cond)
            data_query = data_query.where(where_cond)
        total = session.scalar(total_query) or 0
        rows = session.scalars(data_query.offset(offset).limit(size)).all()

    items = [
        {
            "tradeDate": r.trade_date.isoformat(),
            "ticker": r.ticker,
            "companyName": resolve_company_name(r.ticker),
            "entryPrice": r.entry_price,
            "retT1": r.ret_t1,
            "retT3": r.ret_t3,
            "retT5": r.ret_t5,
            "netRetT1": _net_return(r.ret_t1, fee_bps=fee_bps, slippage_bps=slippage_bps),
            "netRetT3": _net_return(r.ret_t3, fee_bps=fee_bps, slippage_bps=slippage_bps),
            "netRetT5": _net_return(r.ret_t5, fee_bps=fee_bps, slippage_bps=slippage_bps),
        }
        for r in rows
    ]
    return {
        "items": items,
        "page": page,
        "size": size,
        "total": int(total),
        "assumptions": {"feeBps": fee_bps, "slippageBps": slippage_bps},
    }
