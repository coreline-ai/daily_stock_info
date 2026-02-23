from __future__ import annotations

import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.append(str(Path(__file__).resolve().parents[1]))
import main as api_main  # noqa: E402


def _allow_strategy_guard(
    monkeypatch,
    *,
    session_date: str = "2026-02-20",
    strategy: str = "close",
) -> None:
    signal_date = "2026-02-19" if strategy == "premarket" else session_date
    monkeypatch.setattr(
        api_main,
        "validate_strategy_request",
        lambda requested_strategy, requested_date_str: {
            "timezone": "Asia/Seoul",
            "nowKst": "2026-02-20T16:00:00+0900",
            "requestedDate": session_date,
            "availableStrategies": [strategy],
            "defaultStrategy": strategy,
            "messages": {"premarket": "ok", "close": "ok"},
            "errorCode": None,
            "detail": None,
            "strategy": (requested_strategy or strategy),
            "sessionDate": session_date,
            "signalDate": signal_date,
            "strategyReason": "test",
        },
    )


def _mock_candidates(weights):
    first, second = "005930", "000660"
    if weights["return"] > 0.5:
        first, second = second, first
    base = [
        {
            "rank": 1,
            "name": "A",
            "code": first,
            "score": 8.0,
            "changeRate": 1.0,
            "price": 100.0,
            "targetPrice": 110.0,
            "stopLoss": 95.0,
            "high60": 120.0,
            "low10": 90.0,
            "tags": ["모멘텀"],
            "summary": "요약",
            "sparkline60": [10, 30, 40],
            "sector": "반도체",
            "exposureDeferred": False,
            "details": {
                "raw": {"return": 8.0, "stability": 7.0, "market": 6.0},
                "weighted": {"return": 3.2, "stability": 2.1, "market": 1.8},
            },
        },
        {
            "rank": 2,
            "name": "B",
            "code": second,
            "score": 7.0,
            "changeRate": -0.2,
            "price": 90.0,
            "targetPrice": 95.0,
            "stopLoss": 85.0,
            "high60": 100.0,
            "low10": 80.0,
            "tags": ["가치주"],
            "summary": "요약2",
            "sparkline60": [50, 40, 30],
            "sector": "자동차",
            "exposureDeferred": False,
            "details": {
                "raw": {"return": 7.0, "stability": 8.0, "market": 5.0},
                "weighted": {"return": 2.8, "stability": 2.4, "market": 1.5},
            },
        },
    ]
    return {"date": "2026-02-20", "candidates": base}


def test_candidates_weight_parameter_changes_order(monkeypatch) -> None:
    def fake_fetch(
        date_str=None,
        weights=None,
        include_sparkline=True,
        strategy="close",
        session_date_str=None,
        custom_tickers=None,
        enforce_exposure_cap=False,
        max_per_sector=2,
        cap_top_n=5,
        **kwargs,
    ):
        return _mock_candidates(weights)

    monkeypatch.setattr(api_main, "fetch_and_score_stocks", fake_fetch)
    monkeypatch.setattr(api_main, "_get_watchlist_tickers", lambda user_key: [])
    _allow_strategy_guard(monkeypatch)
    client = TestClient(api_main.app)

    res_default = client.get("/api/v1/stock-candidates?date=2026-02-20&w_return=0.4&w_stability=0.3&w_market=0.3")
    res_return_heavy = client.get("/api/v1/stock-candidates?date=2026-02-20&w_return=0.6&w_stability=0.2&w_market=0.2")
    assert res_default.status_code == 200
    assert res_return_heavy.status_code == 200
    assert res_default.json()[0]["code"] != res_return_heavy.json()[0]["code"]


def test_detail_contains_news_theme_ai(monkeypatch) -> None:
    def fake_fetch(
        date_str=None,
        weights=None,
        include_sparkline=True,
        strategy="close",
        session_date_str=None,
        custom_tickers=None,
        enforce_exposure_cap=False,
        max_per_sector=2,
        cap_top_n=5,
        **kwargs,
    ):
        return _mock_candidates(weights)

    monkeypatch.setattr(api_main, "fetch_and_score_stocks", fake_fetch)
    monkeypatch.setattr(api_main, "_get_watchlist_tickers", lambda user_key: [])
    _allow_strategy_guard(monkeypatch)
    monkeypatch.setattr(api_main, "is_db_enabled", lambda: False)
    monkeypatch.setattr(
        api_main,
        "get_news_and_themes",
        lambda code, trade_date: ([{"title": "n1", "url": "", "publishedAt": "2026-02-20"}], ["n1", "n2", "n3"], ["AI"]),
    )
    monkeypatch.setattr(
        api_main,
        "generate_ai_report",
        lambda stock, news_summary, themes, trade_date: {
            "provider": "test",
            "model": "GLM4.7",
            "generatedAt": "2026-02-20T00:00:00Z",
            "summary": "s",
            "conclusion": "c",
            "riskFactors": [{"id": "R1", "description": "d"}],
            "confidence": {"score": 80, "level": "high", "warnings": []},
        },
    )

    client = TestClient(api_main.app)
    res = client.get("/api/v1/stocks/005930/detail?date=2026-02-20")
    assert res.status_code == 200
    data = res.json()
    assert len(data["newsSummary3"]) == 3
    assert data["themes"] == ["AI"]
    assert data["aiReport"]["model"] == "GLM4.7"
    assert data["aiReport"]["confidence"]["score"] == 80


def test_weights_recommendation(monkeypatch) -> None:
    def fake_fetch(
        date_str=None,
        weights=None,
        include_sparkline=True,
        strategy="close",
        session_date_str=None,
        custom_tickers=None,
        enforce_exposure_cap=False,
        max_per_sector=2,
        cap_top_n=5,
        **kwargs,
    ):
        return _mock_candidates(weights)

    monkeypatch.setattr(api_main, "fetch_and_score_stocks", fake_fetch)
    monkeypatch.setattr(api_main, "_get_watchlist_tickers", lambda user_key: ["005930"])
    _allow_strategy_guard(monkeypatch)
    monkeypatch.setattr(api_main, "get_market_indices", lambda date: [{"name": "KOSPI", "changeRate": 1.2, "value": 3000.0}])
    monkeypatch.setattr(
        api_main,
        "detect_market_regime",
        lambda candidates, indices: {
            "regime": "bull",
            "label": "상승장",
            "confidence": 80.0,
            "suggestedWeights": {"return": 0.55, "stability": 0.2, "market": 0.25},
            "reason": "테스트",
        },
    )

    client = TestClient(api_main.app)
    res = client.get("/api/v1/weights/recommendation?date=2026-02-20&user_key=default")
    assert res.status_code == 200
    assert res.json()["regimeRecommendation"]["regime"] == "bull"


def test_watchlist_crud_without_db(monkeypatch) -> None:
    monkeypatch.setattr(api_main, "is_db_enabled", lambda: False)
    api_main._WATCHLIST.clear()
    client = TestClient(api_main.app)

    add_res = client.post("/api/v1/watchlist", json={"user_key": "default", "tickers": ["005930", "000660"]})
    assert add_res.status_code == 200
    assert "005930" in add_res.json()["tickers"]

    get_res = client.get("/api/v1/watchlist?user_key=default")
    assert get_res.status_code == 200
    assert len(get_res.json()["tickers"]) == 2

    del_res = client.delete("/api/v1/watchlist/000660?user_key=default")
    assert del_res.status_code == 200
    assert "000660" not in del_res.json()["tickers"]


def test_backtest_endpoints(monkeypatch) -> None:
    monkeypatch.setattr(api_main, "is_db_enabled", lambda: True)
    monkeypatch.setattr(
        api_main,
        "get_backtest_summary",
        lambda start_date, end_date, fee_bps, slippage_bps: {"count": 1, "metrics": {}, "assumptions": {"feeBps": fee_bps, "slippageBps": slippage_bps}},
    )
    monkeypatch.setattr(
        api_main,
        "get_backtest_history",
        lambda start_date, end_date, page, size, fee_bps, slippage_bps: {
            "items": [{"tradeDate": "2026-02-20", "ticker": "005930", "netRetT5": 0.1}],
            "page": page,
            "size": size,
            "total": 1,
        },
    )

    client = TestClient(api_main.app)
    summary_res = client.get("/api/v1/backtest/summary")
    history_res = client.get("/api/v1/backtest/history?page=1&size=20")
    assert summary_res.status_code == 200
    assert history_res.status_code == 200
    assert history_res.json()["total"] == 1


def test_watchlist_upload_csv(monkeypatch) -> None:
    monkeypatch.setattr(api_main, "is_db_enabled", lambda: False)
    api_main._WATCHLIST.clear()
    client = TestClient(api_main.app)
    csv_content = "ticker\n005930\n000660\n".encode("utf-8")
    res = client.post(
        "/api/v1/watchlist/upload-csv",
        files={"file": ("tickers.csv", csv_content, "text/csv")},
        data={"user_key": "default", "replace": "true"},
    )
    assert res.status_code == 200
    payload = res.json()
    assert payload["uploadedCount"] == 2
    assert "005930" in payload["tickers"]


def test_detail_contains_position_sizing(monkeypatch) -> None:
    def fake_fetch(
        date_str=None,
        weights=None,
        include_sparkline=True,
        strategy="close",
        session_date_str=None,
        custom_tickers=None,
        enforce_exposure_cap=False,
        max_per_sector=2,
        cap_top_n=5,
        **kwargs,
    ):
        return _mock_candidates(weights)

    monkeypatch.setattr(api_main, "fetch_and_score_stocks", fake_fetch)
    monkeypatch.setattr(api_main, "_get_watchlist_tickers", lambda user_key: [])
    _allow_strategy_guard(monkeypatch)
    monkeypatch.setattr(api_main, "is_db_enabled", lambda: False)
    monkeypatch.setattr(api_main, "get_news_and_themes", lambda code, trade_date: ([], ["a", "b", "c"], ["AI"]))
    monkeypatch.setattr(
        api_main,
        "generate_ai_report",
        lambda stock, news_summary, themes, trade_date: {
            "provider": "deterministic-fallback",
            "model": "GLM4.7",
            "generatedAt": "2026-02-20T00:00:00Z",
            "summary": "s",
            "conclusion": "c",
            "riskFactors": [],
            "confidence": {"score": 60, "level": "medium", "warnings": []},
        },
    )
    client = TestClient(api_main.app)
    res = client.get("/api/v1/stocks/005930/detail?date=2026-02-20&account_size=10000000&risk_per_trade_pct=1")
    assert res.status_code == 200
    assert res.json()["positionSizing"]["shares"] >= 1


def test_health_contains_llm_status(monkeypatch) -> None:
    monkeypatch.setattr(api_main, "is_db_enabled", lambda: False)
    monkeypatch.setattr(
        api_main,
        "get_trading_calendar_runtime_status",
        lambda: {"provider": "exchange_calendars", "calendar": "XKRX", "ready": True, "timezone": "Asia/Seoul"},
    )
    monkeypatch.setattr(
        api_main,
        "get_llm_runtime_status",
        lambda: {
            "initialized": True,
            "provider": "zai-openai",
            "configuredModel": "GLM4.7",
            "requestedModel": "GLM-4.7",
            "effectiveModel": "GLM-4.7",
            "validated": True,
            "autoCorrected": True,
            "warnings": ["Model auto-corrected: GLM4.7 -> GLM-4.7"],
        },
    )
    client = TestClient(api_main.app)
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    payload = res.json()
    assert "llm" in payload
    assert payload["tradingCalendar"]["provider"] == "exchange_calendars"
    assert payload["llm"]["effectiveModel"] == "GLM-4.7"
    assert isinstance(payload["warnings"], list)


def test_stock_candidates_rejects_future_date() -> None:
    client = TestClient(api_main.app)
    res = client.get("/api/v1/stock-candidates?date=2099-01-01")
    assert res.status_code == 400
    payload = res.json()
    assert isinstance(payload.get("detail"), dict)
    assert payload["detail"]["code"] == "DATE_IN_FUTURE"


def test_stock_candidates_rejects_weekend_date() -> None:
    client = TestClient(api_main.app)
    res = client.get("/api/v1/stock-candidates?date=2026-02-22")
    assert res.status_code == 400
    payload = res.json()
    assert isinstance(payload.get("detail"), dict)
    assert payload["detail"]["code"] == "NON_TRADING_DAY"


def test_strategy_status_endpoint(monkeypatch) -> None:
    monkeypatch.setattr(
        api_main,
        "get_strategy_status",
        lambda requested_date_str: {
            "timezone": "Asia/Seoul",
            "nowKst": "2026-02-20T08:10:00+0900",
            "requestedDate": "2026-02-20",
            "availableStrategies": ["premarket"],
            "defaultStrategy": "premarket",
            "messages": {"premarket": "active", "close": "locked"},
            "errorCode": None,
            "detail": None,
            "nonTradingDay": None,
        },
    )
    client = TestClient(api_main.app)
    res = client.get("/api/v1/strategy-status?date=2026-02-20")
    assert res.status_code == 200
    assert res.json()["defaultStrategy"] == "premarket"


def test_strategy_status_non_trading_day_details(monkeypatch) -> None:
    monkeypatch.setattr(
        api_main,
        "get_strategy_status",
        lambda requested_date_str: {
            "timezone": "Asia/Seoul",
            "nowKst": "2026-02-23T08:10:00+0900",
            "requestedDate": "2026-02-17",
            "availableStrategies": [],
            "defaultStrategy": None,
            "messages": {"premarket": "closed", "close": "closed"},
            "errorCode": "NON_TRADING_DAY",
            "detail": "Requested date 2026-02-17 is not a KRX trading day. (공휴일(설날))",
            "nonTradingDay": {
                "reasonType": "holiday",
                "reason": "공휴일(설날)",
                "holidayName": "설날",
                "calendarProvider": "exchange_calendars",
            },
        },
    )
    client = TestClient(api_main.app)
    res = client.get("/api/v1/strategy-status?date=2026-02-17")
    assert res.status_code == 200
    assert res.json()["nonTradingDay"]["holidayName"] == "설날"


def test_strategy_guard_error_shape(monkeypatch) -> None:
    monkeypatch.setattr(
        api_main,
        "validate_strategy_request",
        lambda requested_strategy, requested_date_str: {
            "errorCode": "STRATEGY_NOT_AVAILABLE",
            "detail": "Strategy 'close' is not available now.",
        },
    )
    client = TestClient(api_main.app)
    res = client.get("/api/v1/stock-candidates?date=2026-02-20&strategy=close")
    assert res.status_code == 400
    payload = res.json()
    assert payload["detail"]["code"] == "STRATEGY_NOT_AVAILABLE"
