from __future__ import annotations

from pathlib import Path
import sys

import pandas as pd

sys.path.append(str(Path(__file__).resolve().parents[1]))

import services.validation_service as validation_service


def test_compute_pbo_cs_cv_reproducible() -> None:
    results = [
        {"trainSharpe": 1.2, "testSharpe": 0.7},
        {"trainSharpe": 1.0, "testSharpe": -0.1},
        {"trainSharpe": 0.8, "testSharpe": 0.2},
        {"trainSharpe": 1.4, "testSharpe": 0.4},
    ]
    assert validation_service.compute_pbo_cs_cv(results) == 0.75


def test_compute_deflated_sharpe_positive_on_consistent_returns() -> None:
    dsr = validation_service.compute_deflated_sharpe([0.8, 0.7, 0.9, 1.1, 0.6, 0.75], trials=2)
    assert dsr > 0


def test_cost_pct_uses_round_trip_total_bps(monkeypatch) -> None:
    monkeypatch.setattr(validation_service, "VALIDATION_COST_IS_ROUND_TRIP", True)
    assert validation_service._cost_pct(20.0) == 0.2


def test_run_walk_forward_validation_insufficient_data(monkeypatch) -> None:
    monkeypatch.setattr(validation_service, "_collect_trading_sessions", lambda as_of_date, lookback_days: ["2026-02-19", "2026-02-20"])
    monkeypatch.setattr(validation_service, "VALIDATION_ENABLED_STRATEGIES", {"intraday"})
    out = validation_service.run_walk_forward_validation(
        strategy="intraday",
        universe=[],
        params={},
        as_of_date="2026-02-20",
    )
    assert out["insufficientData"] is True
    assert out["gateStatus"] == "warn"
    assert out["metrics"]["sampleSize"] == 0


def test_run_walk_forward_validation_returns_metrics(monkeypatch) -> None:
    sessions = pd.date_range("2025-11-01", periods=90, freq="B").strftime("%Y-%m-%d").tolist()
    monkeypatch.setattr(validation_service, "_collect_trading_sessions", lambda as_of_date, lookback_days: sessions)
    monkeypatch.setattr(validation_service, "VALIDATION_ENABLED_STRATEGIES", {"intraday"})
    monkeypatch.setattr(
        validation_service,
        "fetch_and_score_stocks",
        lambda **kwargs: {
            "candidates": [
                {
                    "code": "005930",
                }
            ]
        },
    )

    def _fake_close(code: str, trade_date: str, future_days: int = 3):
        dt = pd.to_datetime([trade_date, pd.Timestamp(trade_date) + pd.Timedelta(days=1)])
        return pd.Series([100.0, 101.0], index=dt)

    monkeypatch.setattr(validation_service, "get_price_series_for_ticker", _fake_close)

    out = validation_service.run_walk_forward_validation(
        strategy="intraday",
        universe=[],
        params={
            "trainSessions": 20,
            "testSessions": 5,
            "embargoSessions": 1,
            "maxWindows": 1,
            "minSampleSize": 3,
        },
        as_of_date="2026-02-20",
    )
    assert out["insufficientData"] is False
    assert out["metrics"]["sampleSize"] >= 3
    assert "pbo" in out["metrics"]
    assert "dsr" in out["metrics"]


def test_run_walk_forward_validation_branch_compare(monkeypatch) -> None:
    sessions = pd.date_range("2025-11-01", periods=90, freq="B").strftime("%Y-%m-%d").tolist()
    monkeypatch.setattr(validation_service, "_collect_trading_sessions", lambda as_of_date, lookback_days: sessions)
    monkeypatch.setattr(validation_service, "VALIDATION_ENABLED_STRATEGIES", {"intraday"})

    def _fake_fetch(**kwargs):
        branch = kwargs.get("intraday_signal_branch")
        picked = "005930" if branch == "phase2" else "000660"
        return {"candidates": [{"code": picked}]}

    def _fake_close(code: str, trade_date: str, future_days: int = 3):
        dt = pd.to_datetime([trade_date, pd.Timestamp(trade_date) + pd.Timedelta(days=1)])
        if code == "005930":
            return pd.Series([100.0, 102.0], index=dt)
        return pd.Series([100.0, 99.0], index=dt)

    monkeypatch.setattr(validation_service, "fetch_and_score_stocks", _fake_fetch)
    monkeypatch.setattr(validation_service, "get_price_series_for_ticker", _fake_close)

    out = validation_service.run_walk_forward_validation(
        strategy="intraday",
        universe=[],
        params={
            "trainSessions": 20,
            "testSessions": 5,
            "embargoSessions": 1,
            "maxWindows": 1,
            "minSampleSize": 3,
            "intradaySignalBranch": "phase2",
            "compareBranches": True,
        },
        as_of_date="2026-02-20",
    )
    assert out["protocol"]["intradaySignalBranch"] == "phase2"
    assert "branchComparison" in out
    assert out["branchComparison"]["recommendedBranch"] == "phase2"


def test_resolve_intraday_branch_by_validation(monkeypatch) -> None:
    monkeypatch.setattr(
        validation_service,
        "run_walk_forward_validation",
        lambda strategy, universe, params, as_of_date: {
            "branchComparison": {"recommendedBranch": "baseline"}
        },
    )
    branch = validation_service.resolve_intraday_branch_by_validation(
        as_of_date="2026-02-20",
        universe=[],
        params={},
    )
    assert branch == "baseline"


def test_run_walk_forward_validation_strategy_disabled(monkeypatch) -> None:
    monkeypatch.setattr(validation_service, "VALIDATION_ENABLED_STRATEGIES", {"intraday"})
    out = validation_service.run_walk_forward_validation(
        strategy="close",
        universe=[],
        params={},
        as_of_date="2026-02-20",
    )
    assert out["insufficientData"] is True
    assert out.get("note") == "validation-disabled-for-strategy"
