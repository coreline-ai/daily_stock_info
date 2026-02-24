from __future__ import annotations

import os
from pathlib import Path
import sys
from datetime import datetime

import pandas as pd

sys.path.append(str(Path(__file__).resolve().parents[1]))

import services.backtest_service as backtest_service
import services.llm_service as llm_service
import services.scoring_service as scoring_service
from services.backtest_service import compute_forward_returns
from services.llm_service import generate_ai_report
from services.news_service import summarize_news_3_lines
from services.scoring_service import (
    BALANCE_TOP_N,
    apply_sector_exposure_cap,
    apply_diversified_sampling,
    detect_market_regime,
    fetch_and_score_stocks,
    get_latest_trading_date,
    get_non_trading_day_info,
    get_strategy_status,
    normalize_weights,
    validate_recommendation_request_date,
    validate_strategy_request,
)
from services.scoring_service import _build_universe
from services.sparkline_service import build_sparkline60
from services.theme_service import extract_themes


def test_normalize_weights_success() -> None:
    normalized = normalize_weights(0.6, 0.2, 0.2)
    assert round(normalized["return"], 2) == 0.6
    assert round(normalized["stability"], 2) == 0.2
    assert round(normalized["market"], 2) == 0.2


def test_normalize_weights_invalid() -> None:
    try:
        normalize_weights(0, 0, 0)
        assert False, "zero-sum must fail"
    except ValueError:
        assert True

    try:
        normalize_weights(-0.1, 0.6, 0.5)
        assert False, "negative must fail"
    except ValueError:
        assert True


def test_sparkline_length_and_flat() -> None:
    points = build_sparkline60([100.0] * 80)
    assert len(points) == 60
    assert len(set(points)) == 1


def test_news_summary_fixed_3_lines() -> None:
    lines = summarize_news_3_lines([{"title": "A"}, {"title": "B"}])
    assert len(lines) == 3
    assert lines[0] == "A"
    assert lines[1] == "B"


def test_theme_extraction() -> None:
    themes = extract_themes(["반도체 공급망 개선", "AI 서버 수요 증가"])
    assert "반도체" in themes
    assert "AI" in themes


def test_llm_fallback_report() -> None:
    os.environ.pop("ZHIPU_API_KEY", None)
    os.environ.pop("OPENAI_API_KEY", None)
    report = generate_ai_report(
        stock={"name": "테스트", "summary": "요약", "changeRate": 1.2},
        news_summary=["뉴스1", "뉴스2", "뉴스3"],
        themes=["반도체"],
        trade_date="2026-02-20",
    )
    assert report["provider"] in {"deterministic-fallback", "zhipu"}
    assert "summary" in report
    assert "conclusion" in report
    assert "confidence" in report
    assert "score" in report["confidence"]


def test_llm_startup_probe_autocorrect(monkeypatch) -> None:
    llm_service.reset_llm_runtime_status()
    monkeypatch.setenv("ZHIPU_API_KEY", "dummy")
    monkeypatch.setenv("ZHIPU_MODEL", "GLM4.7")
    monkeypatch.setenv("ZHIPU_MODEL_CANDIDATES", "glm-4.7,GLM-4.7")
    monkeypatch.setenv("LLM_PROBE_ON_STARTUP", "true")

    def fake_probe(*, api_key, model, base_url, timeout_sec):
        if model.lower() == "glm-4.7":
            return True, "zai-openai", None
        return False, "zai-openai", "invalid-model"

    monkeypatch.setattr(llm_service, "_probe_llm_model", fake_probe)
    status = llm_service.bootstrap_llm_runtime(probe=True, force=True)
    assert status["validated"] is True
    assert status["effectiveModel"].lower() == "glm-4.7"
    assert status["autoCorrected"] is True
    assert "auto-corrected" in " ".join(status["warnings"]).lower()


def test_llm_startup_probe_missing_key_warning(monkeypatch) -> None:
    llm_service.reset_llm_runtime_status()
    monkeypatch.delenv("ZHIPU_API_KEY", raising=False)
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    status = llm_service.bootstrap_llm_runtime(probe=True, force=True)
    assert status["validated"] is False
    assert any("missing" in warning.lower() for warning in status["warnings"])


def test_backtest_returns_t1_t3_t5() -> None:
    idx = pd.to_datetime(["2026-02-10", "2026-02-11", "2026-02-12", "2026-02-13", "2026-02-16", "2026-02-17"])
    close = pd.Series([100.0, 102.0, 101.0, 104.0, 103.0, 106.0], index=idx)
    rets = compute_forward_returns(close, trade_date="2026-02-10")
    assert rets["ret_t1"] == 2.0
    assert rets["ret_t3"] == 4.0
    assert rets["ret_t5"] == 6.0


def test_backfill_daterange_skips_non_trading_day(monkeypatch) -> None:
    monkeypatch.setattr(backtest_service, "is_krx_trading_day", lambda day: day != "2026-02-17")
    dates = backtest_service._daterange("2026-02-16", "2026-02-18")
    assert dates == ["2026-02-16", "2026-02-18"]


def test_backfill_inserted_counts_only_new_candidates(monkeypatch) -> None:
    monkeypatch.setattr(backtest_service, "_daterange", lambda start_date, end_date: ["2026-02-20", "2026-02-21"])
    monkeypatch.setattr(
        backtest_service,
        "fetch_and_score_stocks",
        lambda date_str, weights, include_sparkline: {
            "date": date_str,
            "candidates": [{"code": "005930", "rank": 1}],
        },
    )
    monkeypatch.setattr(backtest_service, "_upsert_snapshot", lambda session, trade_date, candidate: False)
    monkeypatch.setattr(backtest_service, "_upsert_backtest", lambda session, trade_date, candidate: False)

    class DummySession:
        pass

    class DummySessionScope:
        def __enter__(self):
            return DummySession()

        def __exit__(self, exc_type, exc, tb):
            return False

    monkeypatch.setattr(backtest_service, "session_scope", lambda: DummySessionScope())
    inserted = backtest_service.backfill_snapshots("2026-02-20", "2026-02-21")
    assert inserted == 0


def test_market_regime_recommendation() -> None:
    candidates = [
        {"changeRate": 1.2},
        {"changeRate": 0.8},
        {"changeRate": 0.5},
        {"changeRate": -0.1},
    ]
    indices = [{"changeRate": 1.1}, {"changeRate": 0.9}]
    regime = detect_market_regime(candidates, indices)
    assert regime["regime"] in {"bull", "sideways", "bear"}
    assert "suggestedWeights" in regime
    assert "confidence" in regime


def test_sector_exposure_cap_applies_to_top5() -> None:
    cands = [
        {"code": "A1", "sector": "반도체", "score": 10, "rank": 1},
        {"code": "A2", "sector": "반도체", "score": 9, "rank": 2},
        {"code": "A3", "sector": "반도체", "score": 8, "rank": 3},
        {"code": "B1", "sector": "자동차", "score": 7, "rank": 4},
        {"code": "C1", "sector": "금융", "score": 6, "rank": 5},
        {"code": "D1", "sector": "바이오", "score": 5, "rank": 6},
    ]
    capped = apply_sector_exposure_cap(cands, top_n=5, max_per_sector=2)
    top5 = capped[:5]
    assert len([c for c in top5 if c["sector"] == "반도체"]) <= 2


def test_build_universe_skips_duplicate_code_variants() -> None:
    universe = _build_universe(custom_tickers=["005930", "005930.KQ", "AAPL", "aapl"])
    samsung_symbols = [symbol for symbol in universe.keys() if symbol.startswith("005930.")]
    assert len(samsung_symbols) == 1
    assert "AAPL" in universe


def test_validate_recommendation_request_date_blocks_before_close(monkeypatch) -> None:
    monkeypatch.setattr(
        scoring_service,
        "now_in_kst",
        lambda: datetime(2026, 2, 20, 14, 0, tzinfo=scoring_service.KST),
    )
    monkeypatch.setattr(scoring_service, "is_krx_trading_day", lambda _: True)
    _, error = validate_recommendation_request_date("2026-02-20")
    assert error is not None
    assert "사용할 수 없습니다" in error


def test_get_latest_trading_date_skips_non_trading_day(monkeypatch) -> None:
    monkeypatch.setattr(scoring_service, "is_krx_trading_day", lambda day: day == "2026-02-16")
    assert get_latest_trading_date("2026-02-17") == "2026-02-16"


def test_strategy_status_today_premarket_window(monkeypatch) -> None:
    monkeypatch.setattr(
        scoring_service,
        "now_in_kst",
        lambda: datetime(2026, 2, 20, 8, 10, tzinfo=scoring_service.KST),
    )
    monkeypatch.setattr(scoring_service, "is_krx_trading_day", lambda _: True)
    status = get_strategy_status("2026-02-20")
    assert status["availableStrategies"] == ["premarket"]
    assert status["defaultStrategy"] == "premarket"


def test_strategy_status_today_close_window(monkeypatch) -> None:
    monkeypatch.setattr(
        scoring_service,
        "now_in_kst",
        lambda: datetime(2026, 2, 20, 15, 40, tzinfo=scoring_service.KST),
    )
    monkeypatch.setattr(scoring_service, "is_krx_trading_day", lambda _: True)
    status = get_strategy_status("2026-02-20")
    assert status["availableStrategies"] == ["premarket", "close"]
    assert status["defaultStrategy"] == "close"


def test_strategy_status_today_intraday_window(monkeypatch) -> None:
    monkeypatch.setattr(
        scoring_service,
        "now_in_kst",
        lambda: datetime(2026, 2, 20, 10, 0, tzinfo=scoring_service.KST),
    )
    monkeypatch.setattr(scoring_service, "is_krx_trading_day", lambda _: True)
    status = get_strategy_status("2026-02-20")
    assert status["availableStrategies"] == ["premarket", "intraday"]
    assert status["defaultStrategy"] == "intraday"
    assert "장중 단타" in status["messages"]["intraday"]


def test_strategy_auto_fails_before_0800(monkeypatch) -> None:
    monkeypatch.setattr(
        scoring_service,
        "now_in_kst",
        lambda: datetime(2026, 2, 20, 7, 50, tzinfo=scoring_service.KST),
    )
    monkeypatch.setattr(scoring_service, "is_krx_trading_day", lambda _: True)
    resolved = validate_strategy_request(None, "2026-02-20")
    assert resolved["errorCode"] == "STRATEGY_NOT_AVAILABLE"
    assert resolved.get("strategy") is None


def test_strategy_intraday_is_blocked_after_intraday_close(monkeypatch) -> None:
    monkeypatch.setattr(
        scoring_service,
        "now_in_kst",
        lambda: datetime(2026, 2, 20, 15, 25, tzinfo=scoring_service.KST),
    )
    monkeypatch.setattr(scoring_service, "is_krx_trading_day", lambda _: True)
    resolved = validate_strategy_request("intraday", "2026-02-20")
    assert resolved["errorCode"] == "STRATEGY_NOT_AVAILABLE"
    assert "intraday" in str(resolved.get("detail", "")).lower()


def test_premarket_scoring_contains_signal_block(monkeypatch) -> None:
    idx = pd.date_range("2025-10-01", periods=120, freq="B")
    base = pd.DataFrame(
        {
            "Open": [100 + i * 0.2 for i in range(len(idx))],
            "High": [101 + i * 0.2 for i in range(len(idx))],
            "Low": [99 + i * 0.2 for i in range(len(idx))],
            "Close": [100 + i * 0.2 for i in range(len(idx))],
            "Volume": [1_500_000 for _ in range(len(idx))],
        },
        index=idx,
    )

    monkeypatch.setattr(scoring_service, "_download_frame", lambda ticker_symbol, start_date, end_date: base)
    monkeypatch.setattr(scoring_service, "_build_universe", lambda custom_tickers=None: {"005930.KS": "Samsung Electronics"})
    monkeypatch.setattr(scoring_service, "get_previous_trading_date", lambda target_date_str, max_lookback_days=14: "2026-02-19")
    monkeypatch.setattr(scoring_service, "fetch_stock_news_items", lambda code, max_items=20: [])

    payload = fetch_and_score_stocks(
        date_str="2026-02-20",
        strategy="premarket",
        session_date_str="2026-02-20",
        include_sparkline=False,
    )
    assert payload["strategy"] == "premarket"
    assert payload["signalDate"] == "2026-02-19"
    assert payload["candidates"]
    cand = payload["candidates"][0]
    signals = cand["details"]["premarketSignals"]
    assert 1.0 <= cand["details"]["raw"]["return"] <= 10.0
    assert 1.0 <= cand["details"]["raw"]["market"] <= 10.0
    assert "newsSentiment" in signals
    assert "overnightProxy" in signals


def test_premarket_overnight_proxy_is_reused_once(monkeypatch) -> None:
    idx = pd.date_range("2025-10-01", periods=120, freq="B")
    base = pd.DataFrame(
        {
            "Open": [100 + i * 0.2 for i in range(len(idx))],
            "High": [101 + i * 0.2 for i in range(len(idx))],
            "Low": [99 + i * 0.2 for i in range(len(idx))],
            "Close": [100 + i * 0.2 for i in range(len(idx))],
            "Volume": [1_500_000 for _ in range(len(idx))],
        },
        index=idx,
    )
    calls = {"count": 0}

    def fake_proxy(session_date: str) -> float:
        calls["count"] += 1
        return 6.0

    monkeypatch.setattr(scoring_service, "_download_frame", lambda ticker_symbol, start_date, end_date: base)
    monkeypatch.setattr(
        scoring_service,
        "_build_universe",
        lambda custom_tickers=None: {"005930.KS": "Samsung Electronics", "000660.KS": "SK Hynix"},
    )
    monkeypatch.setattr(scoring_service, "get_previous_trading_date", lambda target_date_str, max_lookback_days=14: "2026-02-19")
    monkeypatch.setattr(scoring_service, "fetch_stock_news_items", lambda code, max_items=20: [])
    monkeypatch.setattr(scoring_service, "_compute_overnight_proxy_score", fake_proxy)

    payload = fetch_and_score_stocks(
        date_str="2026-02-20",
        strategy="premarket",
        session_date_str="2026-02-20",
        include_sparkline=False,
    )
    assert calls["count"] == 1
    assert len(payload["candidates"]) == 2
    for cand in payload["candidates"]:
        assert cand["details"]["premarketSignals"]["overnightProxy"] == 6.0


def test_intraday_scoring_contains_signal_block(monkeypatch) -> None:
    idx = pd.date_range("2025-10-01", periods=120, freq="B")
    base = pd.DataFrame(
        {
            "Open": [100 + i * 0.15 for i in range(len(idx))],
            "High": [101 + i * 0.15 for i in range(len(idx))],
            "Low": [99 + i * 0.15 for i in range(len(idx))],
            "Close": [100 + i * 0.15 for i in range(len(idx))],
            "Volume": [2_000_000 for _ in range(len(idx))],
        },
        index=idx,
    )
    monkeypatch.setattr(scoring_service, "_download_frame", lambda ticker_symbol, start_date, end_date: base)
    monkeypatch.setattr(scoring_service, "_build_universe", lambda custom_tickers=None: {"005930.KS": "Samsung Electronics"})
    monkeypatch.setattr(scoring_service, "INTRADAY_MODE", "proxy")
    payload = fetch_and_score_stocks(
        date_str="2026-02-20",
        strategy="intraday",
        session_date_str="2026-02-20",
        include_sparkline=False,
    )
    assert payload["strategy"] == "intraday"
    assert payload["candidates"]
    cand = payload["candidates"][0]
    signals = cand["details"]["intradaySignals"]
    assert signals["mode"] == "proxy"
    assert "orbProxyScore" in signals
    assert "vwapProxyScore" in signals
    assert "rvolScore" in signals


def test_is_krx_trading_day_respects_external_calendar_holiday(monkeypatch) -> None:
    scoring_service._TRADING_DAY_CACHE.clear()
    monkeypatch.setattr(scoring_service, "_is_krx_open_by_external_calendar", lambda target_date: False)
    monkeypatch.setattr(
        scoring_service,
        "now_in_kst",
        lambda: datetime(2026, 2, 16, 9, 0, tzinfo=scoring_service.KST),
    )

    assert scoring_service.is_krx_trading_day("2026-02-16") is False


def test_is_krx_trading_day_today_fallback_when_calendar_unavailable(monkeypatch) -> None:
    scoring_service._TRADING_DAY_CACHE.clear()
    monkeypatch.setattr(scoring_service, "_is_krx_open_by_external_calendar", lambda target_date: None)
    monkeypatch.setattr(
        scoring_service,
        "now_in_kst",
        lambda: datetime(2026, 2, 23, 9, 0, tzinfo=scoring_service.KST),
    )

    def fail_download(*args, **kwargs):
        raise AssertionError("today fallback should not call yfinance probe")

    monkeypatch.setattr(scoring_service, "_download_frame", fail_download)
    assert scoring_service.is_krx_trading_day("2026-02-23") is True


def test_non_trading_day_info_holiday_reason(monkeypatch) -> None:
    monkeypatch.setattr(scoring_service, "_is_krx_open_by_external_calendar", lambda target_date: False)
    monkeypatch.setattr(scoring_service, "_get_kr_holiday_name", lambda target_date: "설날")
    monkeypatch.setattr(
        scoring_service,
        "get_trading_calendar_runtime_status",
        lambda: {"provider": "exchange_calendars", "calendar": "XKRX"},
    )
    info = get_non_trading_day_info(datetime(2026, 2, 17).date())
    assert info["reasonType"] == "holiday"
    assert info["holidayName"] == "설날"
    assert "설날" in info["reason"]


def test_strategy_status_includes_non_trading_day_details(monkeypatch) -> None:
    monkeypatch.setattr(scoring_service, "now_in_kst", lambda: datetime(2026, 2, 23, 8, 30, tzinfo=scoring_service.KST))
    monkeypatch.setattr(scoring_service, "is_krx_trading_day", lambda _: False)
    monkeypatch.setattr(
        scoring_service,
        "get_non_trading_day_info",
        lambda target_date: {
            "date": target_date.isoformat(),
            "reasonType": "holiday",
            "reason": "공휴일(설날)",
            "holidayName": "설날",
            "weekday": "화",
            "sessionOpen": False,
            "calendarProvider": "exchange_calendars",
            "calendar": "XKRX",
        },
    )
    status = get_strategy_status("2026-02-17")
    assert status["errorCode"] == "NON_TRADING_DAY"
    assert status["nonTradingDay"]["holidayName"] == "설날"


def test_universe_expanded_default_count() -> None:
    assert len(scoring_service.TICKERS) >= 40


def test_market_score_is_log_scaled_not_saturated() -> None:
    close = pd.Series([100 + i * 0.2 for i in range(120)])
    vol_medium = pd.Series([1_000_000 for _ in range(120)])
    vol_high = pd.Series([10_000_000 for _ in range(120)])

    medium_raw, _ = scoring_service._compute_scores(close=close, volume=vol_medium)
    high_raw, _ = scoring_service._compute_scores(close=close, volume=vol_high)

    assert medium_raw["market"] < 8.0
    assert high_raw["market"] > medium_raw["market"]
    assert high_raw["market"] <= 10.0


def test_diversified_sampling_balances_top_window() -> None:
    candidates: list[dict[str, object]] = []
    for idx in range(8):
        candidates.append(
            {
                "code": f"M{idx}",
                "sector": "Semiconductor",
                "marketCapBucket": "mega",
                "score": 10 - idx * 0.1,
            }
        )
    for idx in range(8):
        candidates.append(
            {
                "code": f"L{idx}",
                "sector": "Financial",
                "marketCapBucket": "large",
                "score": 8 - idx * 0.1,
            }
        )
    for idx in range(8):
        candidates.append(
            {
                "code": f"D{idx}",
                "sector": "Defense",
                "marketCapBucket": "mid",
                "score": 7 - idx * 0.1,
            }
        )

    balanced = apply_diversified_sampling(candidates, top_n=BALANCE_TOP_N, max_per_sector=2, max_per_market_cap_bucket=4)
    top = balanced[:BALANCE_TOP_N]

    assert len([item for item in top if item["sector"] == "Semiconductor"]) <= 4
    assert len([item for item in top if item["sector"] == "Financial"]) <= 4
    assert len([item for item in top if item["marketCapBucket"] == "mega"]) <= 4
