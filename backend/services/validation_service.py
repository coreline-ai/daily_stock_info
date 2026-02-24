from __future__ import annotations

import json
import logging
import math
import os
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from services.scoring_service import (
    DEFAULT_WEIGHTS,
    fetch_and_score_stocks,
    get_latest_trading_date,
    get_price_series_for_ticker,
    is_krx_trading_day,
    normalize_weights,
)

_ALLOWED_STRATEGIES = {"premarket", "intraday", "close"}
_ALLOWED_INTRADAY_BRANCHES = {"baseline", "phase2"}
_LOGGER = logging.getLogger(__name__)


def _env_flag(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}

VALIDATION_TRAIN_MONTHS = max(1, int(os.getenv("VALIDATION_TRAIN_MONTHS", "6")))
VALIDATION_TEST_MONTHS = max(1, int(os.getenv("VALIDATION_TEST_MONTHS", "1")))
VALIDATION_TRADING_DAYS_PER_MONTH = max(10, int(os.getenv("VALIDATION_TRADING_DAYS_PER_MONTH", "21")))
VALIDATION_EMBARGO_SESSIONS = max(0, int(os.getenv("VALIDATION_EMBARGO_SESSIONS", "1")))
VALIDATION_COST_BPS = max(0.0, float(os.getenv("VALIDATION_COST_BPS", "20")))
VALIDATION_COST_IS_ROUND_TRIP = _env_flag("VALIDATION_COST_IS_ROUND_TRIP", True)
VALIDATION_MIN_SAMPLE_SIZE = max(1, int(os.getenv("VALIDATION_MIN_SAMPLE_SIZE", "60")))
VALIDATION_MIN_NET_SHARPE = float(os.getenv("VALIDATION_MIN_NET_SHARPE", "0.5"))
VALIDATION_MAX_PBO = max(0.0, min(1.0, float(os.getenv("VALIDATION_MAX_PBO", "0.2"))))
VALIDATION_MIN_DSR = float(os.getenv("VALIDATION_MIN_DSR", "0.0"))
VALIDATION_SOFT_PENALTY = max(0.0, float(os.getenv("VALIDATION_SOFT_PENALTY", "0.35")))
VALIDATION_MAX_WINDOWS = max(1, int(os.getenv("VALIDATION_MAX_WINDOWS", "2")))
VALIDATION_LOOKBACK_DAYS = max(120, int(os.getenv("VALIDATION_LOOKBACK_DAYS", "420")))
VALIDATION_MONITOR_ENABLED = _env_flag("VALIDATION_MONITOR_ENABLED", True)
VALIDATION_MONITOR_LOG_PATH = Path(
    os.getenv(
        "VALIDATION_MONITOR_LOG_PATH",
        "/tmp/daily_stock_validation_metrics.jsonl",
    )
)
VALIDATION_ALERT_MAX_PBO = max(0.0, min(1.0, float(os.getenv("VALIDATION_ALERT_MAX_PBO", "0.30"))))
VALIDATION_ALERT_MIN_DSR = float(os.getenv("VALIDATION_ALERT_MIN_DSR", "-0.10"))
VALIDATION_ALERT_MIN_NET_SHARPE = float(os.getenv("VALIDATION_ALERT_MIN_NET_SHARPE", "0.00"))

_GATE_MODE_ENV = (os.getenv("VALIDATION_GATE_MODE", "soft").strip().lower() or "soft")
VALIDATION_GATE_MODE = _GATE_MODE_ENV if _GATE_MODE_ENV in {"off", "observe", "soft", "hard"} else "soft"
_enabled_raw = os.getenv("VALIDATION_ENABLED_STRATEGIES", "intraday")
VALIDATION_ENABLED_STRATEGIES = {
    token.strip().lower()
    for token in _enabled_raw.split(",")
    if token.strip()
}
if not VALIDATION_ENABLED_STRATEGIES:
    VALIDATION_ENABLED_STRATEGIES = {"intraday"}


def get_validation_config() -> dict[str, Any]:
    return {
        "gateMode": VALIDATION_GATE_MODE,
        "enabledStrategies": sorted(VALIDATION_ENABLED_STRATEGIES),
        "trainMonths": VALIDATION_TRAIN_MONTHS,
        "testMonths": VALIDATION_TEST_MONTHS,
        "tradingDaysPerMonth": VALIDATION_TRADING_DAYS_PER_MONTH,
        "embargoSessions": VALIDATION_EMBARGO_SESSIONS,
        "costBps": VALIDATION_COST_BPS,
        "costIsRoundTrip": VALIDATION_COST_IS_ROUND_TRIP,
        "minSampleSize": VALIDATION_MIN_SAMPLE_SIZE,
        "minNetSharpe": VALIDATION_MIN_NET_SHARPE,
        "maxPbo": VALIDATION_MAX_PBO,
        "minDsr": VALIDATION_MIN_DSR,
        "softPenalty": VALIDATION_SOFT_PENALTY,
        "maxWindows": VALIDATION_MAX_WINDOWS,
        "lookbackDays": VALIDATION_LOOKBACK_DAYS,
        "monitorEnabled": VALIDATION_MONITOR_ENABLED,
        "monitorLogPath": str(VALIDATION_MONITOR_LOG_PATH),
        "alertMaxPbo": VALIDATION_ALERT_MAX_PBO,
        "alertMinDsr": VALIDATION_ALERT_MIN_DSR,
        "alertMinNetSharpe": VALIDATION_ALERT_MIN_NET_SHARPE,
    }


def _normalize_strategy(strategy: str) -> str:
    value = (strategy or "close").strip().lower()
    return value if value in _ALLOWED_STRATEGIES else "close"


def _normalize_intraday_signal_branch(value: Any) -> str:
    branch = str(value or os.getenv("INTRADAY_SIGNAL_BRANCH", "phase2")).strip().lower()
    return branch if branch in _ALLOWED_INTRADAY_BRANCHES else "phase2"


def _to_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return False


def _normalize_branch_for_compare(value: Any) -> str:
    branch = str(value or "").strip().lower()
    return branch if branch in _ALLOWED_INTRADAY_BRANCHES else "phase2"


def resolve_intraday_branch_by_validation(
    as_of_date: str | None,
    universe: list[str] | None,
    params: dict[str, Any] | None,
) -> str:
    payload = run_walk_forward_validation(
        strategy="intraday",
        universe=universe,
        params={
            **(params or {}),
            "intradaySignalBranch": "phase2",
            "compareBranches": True,
            "emitMonitoring": False,
        },
        as_of_date=as_of_date,
    )
    comparison = payload.get("branchComparison", {}) if isinstance(payload.get("branchComparison"), dict) else {}
    return _normalize_branch_for_compare(comparison.get("recommendedBranch"))


def _cost_pct(cost_bps: float) -> float:
    normalized = max(0.0, float(cost_bps))
    if VALIDATION_COST_IS_ROUND_TRIP:
        return normalized / 100.0
    return (normalized * 2.0) / 100.0


def _build_monitor_alerts(metrics: dict[str, Any]) -> list[str]:
    alerts: list[str] = []
    pbo = float(metrics.get("pbo", 1.0) or 1.0)
    dsr = float(metrics.get("dsr", 0.0) or 0.0)
    sharpe = float(metrics.get("netSharpe", 0.0) or 0.0)
    if pbo > VALIDATION_ALERT_MAX_PBO:
        alerts.append(f"pbo>{VALIDATION_ALERT_MAX_PBO:.2f}")
    if dsr < VALIDATION_ALERT_MIN_DSR:
        alerts.append(f"dsr<{VALIDATION_ALERT_MIN_DSR:.2f}")
    if sharpe < VALIDATION_ALERT_MIN_NET_SHARPE:
        alerts.append(f"netSharpe<{VALIDATION_ALERT_MIN_NET_SHARPE:.2f}")
    return alerts


def _emit_validation_monitor(summary: dict[str, Any]) -> tuple[bool, list[str]]:
    if not VALIDATION_MONITOR_ENABLED:
        return False, []

    metrics = summary.get("metrics", {}) if isinstance(summary.get("metrics"), dict) else {}
    protocol = summary.get("protocol", {}) if isinstance(summary.get("protocol"), dict) else {}
    thresholds = summary.get("thresholds", {}) if isinstance(summary.get("thresholds"), dict) else {}
    alerts = _build_monitor_alerts(metrics)
    payload = {
        "loggedAtUtc": datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
        "strategy": summary.get("strategy"),
        "asOfDate": summary.get("asOfDate"),
        "mode": summary.get("mode"),
        "gateStatus": summary.get("gateStatus"),
        "gatePassed": summary.get("gatePassed"),
        "insufficientData": summary.get("insufficientData"),
        "protocol": protocol,
        "thresholds": thresholds,
        "metrics": metrics,
        "alerts": alerts,
    }
    try:
        VALIDATION_MONITOR_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with VALIDATION_MONITOR_LOG_PATH.open("a", encoding="utf-8") as f:
            f.write(json.dumps(payload, ensure_ascii=False) + "\n")
        if alerts:
            _LOGGER.warning("validation monitor alert: %s", ",".join(alerts))
        return True, alerts
    except Exception as exc:
        _LOGGER.warning("validation monitor write failed: %s", exc)
        return False, alerts


def _collect_trading_sessions(as_of_date: str, lookback_days: int) -> list[str]:
    end_date = datetime.strptime(as_of_date, "%Y-%m-%d").date()
    start_date = end_date - timedelta(days=max(lookback_days, 1))
    sessions: list[str] = []
    cursor = start_date
    while cursor <= end_date:
        day = cursor.isoformat()
        if is_krx_trading_day(day):
            sessions.append(day)
        cursor += timedelta(days=1)
    return sessions


def _compute_forward_return_t1(close: pd.Series, trade_date: str) -> float | None:
    if close.empty:
        return None
    close = close.sort_index()
    trade_day = datetime.strptime(trade_date, "%Y-%m-%d").date()
    entry_pos = None
    for idx, ts in enumerate(close.index):
        idx_date = ts.date() if hasattr(ts, "date") else pd.Timestamp(ts).date()
        if idx_date >= trade_day:
            entry_pos = idx
            break
    if entry_pos is None:
        return None
    next_pos = entry_pos + 1
    if next_pos >= len(close):
        return None
    entry_price = float(close.iloc[entry_pos])
    next_price = float(close.iloc[next_pos])
    if entry_price == 0:
        return None
    return ((next_price - entry_price) / entry_price) * 100.0


def _compute_basic_metrics(net_returns: list[float], turnover_steps: int) -> dict[str, float]:
    if not net_returns:
        return {
            "netSharpe": 0.0,
            "maxDrawdown": 0.0,
            "hitRate": 0.0,
            "turnover": 0.0,
            "sampleSize": 0.0,
        }

    arr = np.asarray(net_returns, dtype=float)
    mean_ret = float(np.mean(arr))
    std_ret = float(np.std(arr, ddof=1)) if len(arr) > 1 else 0.0
    net_sharpe = 0.0 if std_ret <= 1e-9 else float((mean_ret / std_ret) * math.sqrt(252))
    equity = np.cumprod(1.0 + (arr / 100.0))
    peak = np.maximum.accumulate(equity)
    drawdown = (equity / np.maximum(peak, 1e-12)) - 1.0
    mdd = float(np.min(drawdown)) * 100.0 if len(drawdown) else 0.0
    hit_rate = float(np.mean(arr > 0.0) * 100.0)
    turnover = 0.0 if len(arr) <= 1 else float((turnover_steps / max(1, len(arr) - 1)) * 100.0)
    return {
        "netSharpe": round(net_sharpe, 4),
        "maxDrawdown": round(mdd, 4),
        "hitRate": round(hit_rate, 2),
        "turnover": round(turnover, 2),
        "sampleSize": float(len(arr)),
    }


def _evaluate_sessions(
    *,
    sessions: list[str],
    strategy: str,
    universe: list[str] | None,
    weights: dict[str, float],
    cost_bps: float,
    intraday_signal_branch: str,
) -> dict[str, Any]:
    round_trip_cost_pct = _cost_pct(cost_bps)
    net_returns: list[float] = []
    picked_codes: list[str] = []

    for session_date in sessions:
        try:
            payload = fetch_and_score_stocks(
                date_str=session_date,
                strategy=strategy,
                session_date_str=session_date,
                include_sparkline=False,
                custom_tickers=universe,
                weights=weights,
                enforce_exposure_cap=False,
                intraday_signal_branch=intraday_signal_branch,
            )
            candidates = payload.get("candidates", [])
            if not candidates:
                continue
            top = candidates[0]
            code = str(top.get("code", ""))
            if not code:
                continue
            close = get_price_series_for_ticker(code=code, trade_date=session_date, future_days=3)
            raw_ret = _compute_forward_return_t1(close=close, trade_date=session_date)
            if raw_ret is None:
                continue
            net_returns.append(float(raw_ret) - round_trip_cost_pct)
            picked_codes.append(code)
        except Exception:
            continue

    turnover_steps = 0
    for idx in range(1, len(picked_codes)):
        if picked_codes[idx] != picked_codes[idx - 1]:
            turnover_steps += 1

    metrics = _compute_basic_metrics(net_returns=net_returns, turnover_steps=turnover_steps)
    metrics["sampleSize"] = int(metrics["sampleSize"])
    return {
        "metrics": metrics,
        "netReturns": net_returns,
    }


def compute_pbo_cs_cv(results: list[dict[str, float]]) -> float:
    if not results:
        return 1.0
    overfit_count = 0
    usable = 0
    for item in results:
        train = float(item.get("trainSharpe", 0.0))
        test = float(item.get("testSharpe", 0.0))
        if not np.isfinite(train) or not np.isfinite(test):
            continue
        usable += 1
        if test < 0.0 or test < (train * 0.5):
            overfit_count += 1
    if usable == 0:
        return 1.0
    return round(overfit_count / usable, 4)


def compute_deflated_sharpe(returns: list[float], trials: int) -> float:
    if len(returns) < 2:
        return 0.0
    arr = np.asarray(returns, dtype=float)
    mean_ret = float(np.mean(arr))
    std_ret = float(np.std(arr, ddof=1))
    if std_ret <= 1e-9:
        return 0.0
    sharpe = (mean_ret / std_ret) * math.sqrt(252.0)
    n = float(len(arr))
    trial_term = math.sqrt(max(0.0, (2.0 * math.log(max(1, trials))) / n))
    return round(float(sharpe - trial_term), 4)


def run_walk_forward_validation(
    strategy: str,
    universe: list[str] | None,
    params: dict[str, Any] | None,
    as_of_date: str | None,
) -> dict[str, Any]:
    normalized_strategy = _normalize_strategy(strategy)
    reference_date = get_latest_trading_date(as_of_date)
    conf = get_validation_config()
    params = params or {}
    intraday_signal_branch = _normalize_intraday_signal_branch(params.get("intradaySignalBranch"))
    compare_branches = _to_bool(params.get("compareBranches")) and normalized_strategy == "intraday"
    emit_monitoring = _to_bool(params.get("emitMonitoring", True))

    if normalized_strategy not in VALIDATION_ENABLED_STRATEGIES:
        disabled_result: dict[str, Any] = {
            "strategy": normalized_strategy,
            "asOfDate": reference_date,
            "mode": conf["gateMode"],
            "gateStatus": "warn",
            "gatePassed": False,
            "insufficientData": True,
            "validationPenalty": 0.0,
            "protocol": {
                "trainSessions": 0,
                "testSessions": 0,
                "embargoSessions": 0,
                "costBps": conf["costBps"],
                "windows": 0,
                "intradaySignalBranch": intraday_signal_branch,
            },
            "thresholds": {
                "pboMax": conf["maxPbo"],
                "dsrMin": conf["minDsr"],
                "sampleSizeMin": conf["minSampleSize"],
                "netSharpeMin": conf["minNetSharpe"],
            },
            "metrics": {
                "netSharpe": 0.0,
                "maxDrawdown": 0.0,
                "hitRate": 0.0,
                "turnover": 0.0,
                "pbo": 1.0,
                "dsr": 0.0,
                "sampleSize": 0,
            },
            "note": "validation-disabled-for-strategy",
        }
        logged, alerts = _emit_validation_monitor(disabled_result) if emit_monitoring else (False, [])
        disabled_result["monitoring"] = {"logged": logged, "alerts": alerts}
        return disabled_result

    weights = normalize_weights(
        params.get("w_return", DEFAULT_WEIGHTS["return"]),
        params.get("w_stability", DEFAULT_WEIGHTS["stability"]),
        params.get("w_market", DEFAULT_WEIGHTS["market"]),
    )
    train_sessions = int(params.get("trainSessions", conf["trainMonths"] * conf["tradingDaysPerMonth"]))
    test_sessions = int(params.get("testSessions", conf["testMonths"] * conf["tradingDaysPerMonth"]))
    embargo_sessions = int(params.get("embargoSessions", conf["embargoSessions"]))
    max_windows = int(params.get("maxWindows", conf["maxWindows"]))
    lookback_days = int(params.get("lookbackDays", conf["lookbackDays"]))
    cost_bps = float(params.get("costBps", conf["costBps"]))
    min_sample = int(params.get("minSampleSize", conf["minSampleSize"]))
    min_sharpe = float(params.get("minNetSharpe", conf["minNetSharpe"]))
    max_pbo = float(params.get("maxPbo", conf["maxPbo"]))
    min_dsr = float(params.get("minDsr", conf["minDsr"]))

    sessions = _collect_trading_sessions(reference_date, lookback_days=lookback_days)
    required_sessions = train_sessions + test_sessions + embargo_sessions
    if len(sessions) < required_sessions:
        insufficient_result: dict[str, Any] = {
            "strategy": normalized_strategy,
            "asOfDate": reference_date,
            "mode": conf["gateMode"],
            "gateStatus": "warn",
            "gatePassed": False,
            "insufficientData": True,
            "validationPenalty": 0.0,
            "protocol": {
                "trainSessions": train_sessions,
                "testSessions": test_sessions,
                "embargoSessions": embargo_sessions,
                "costBps": cost_bps,
                "windows": 0,
                "intradaySignalBranch": intraday_signal_branch,
            },
            "thresholds": {
                "pboMax": max_pbo,
                "dsrMin": min_dsr,
                "sampleSizeMin": min_sample,
                "netSharpeMin": min_sharpe,
            },
            "metrics": {
                "netSharpe": 0.0,
                "maxDrawdown": 0.0,
                "hitRate": 0.0,
                "turnover": 0.0,
                "pbo": 1.0,
                "dsr": 0.0,
                "sampleSize": 0,
            },
        }
        logged, alerts = _emit_validation_monitor(insufficient_result) if emit_monitoring else (False, [])
        insufficient_result["monitoring"] = {"logged": logged, "alerts": alerts}
        return insufficient_result

    window_results: list[dict[str, float]] = []
    aggregate_returns: list[float] = []
    aggregate_turnover_steps = 0

    cursor = train_sessions + test_sessions
    evaluated_windows = 0
    while cursor <= len(sessions) and evaluated_windows < max_windows:
        train_slice = sessions[cursor - test_sessions - train_sessions : cursor - test_sessions]
        test_slice = sessions[cursor - test_sessions : cursor]
        eval_slice = test_slice[embargo_sessions:] if embargo_sessions < len(test_slice) else []
        if not train_slice or not eval_slice:
            cursor += test_sessions
            continue

        train_eval = _evaluate_sessions(
            sessions=train_slice[-min(len(train_slice), test_sessions) :],
            strategy=normalized_strategy,
            universe=universe,
            weights=weights,
            cost_bps=cost_bps,
            intraday_signal_branch=intraday_signal_branch,
        )
        test_eval = _evaluate_sessions(
            sessions=eval_slice,
            strategy=normalized_strategy,
            universe=universe,
            weights=weights,
            cost_bps=cost_bps,
            intraday_signal_branch=intraday_signal_branch,
        )
        train_sharpe = float(train_eval["metrics"].get("netSharpe", 0.0))
        test_sharpe = float(test_eval["metrics"].get("netSharpe", 0.0))
        window_results.append({"trainSharpe": train_sharpe, "testSharpe": test_sharpe})
        aggregate_returns.extend(test_eval["netReturns"])
        sample_size = int(test_eval["metrics"].get("sampleSize", 0))
        turnover_rate = float(test_eval["metrics"].get("turnover", 0.0))
        if sample_size > 1:
            aggregate_turnover_steps += int(round((turnover_rate / 100.0) * (sample_size - 1)))
        evaluated_windows += 1
        cursor += test_sessions

    core_metrics = _compute_basic_metrics(net_returns=aggregate_returns, turnover_steps=aggregate_turnover_steps)
    sample_size = int(core_metrics["sampleSize"])
    pbo = compute_pbo_cs_cv(window_results)
    dsr = compute_deflated_sharpe(aggregate_returns, trials=max(1, len(window_results)))
    insufficient_data = sample_size < min_sample

    gate_passed = (not insufficient_data) and (
        pbo <= max_pbo
        and dsr > min_dsr
        and float(core_metrics["netSharpe"]) >= min_sharpe
    )

    gate_mode = conf["gateMode"]
    if gate_mode == "off":
        gate_status = "pass"
    elif gate_passed:
        gate_status = "pass"
    elif insufficient_data:
        gate_status = "warn"
    elif gate_mode == "hard":
        gate_status = "fail"
    else:
        gate_status = "warn"

    penalty = VALIDATION_SOFT_PENALTY if gate_mode == "soft" and gate_status != "pass" and not insufficient_data else 0.0
    result: dict[str, Any] = {
        "strategy": normalized_strategy,
        "asOfDate": reference_date,
        "mode": gate_mode,
        "gateStatus": gate_status,
        "gatePassed": gate_passed,
        "insufficientData": insufficient_data,
        "validationPenalty": round(penalty, 4),
        "protocol": {
            "trainSessions": train_sessions,
            "testSessions": test_sessions,
            "embargoSessions": embargo_sessions,
            "costBps": cost_bps,
            "windows": len(window_results),
            "intradaySignalBranch": intraday_signal_branch,
        },
        "thresholds": {
            "pboMax": max_pbo,
            "dsrMin": min_dsr,
            "sampleSizeMin": min_sample,
            "netSharpeMin": min_sharpe,
        },
        "metrics": {
            "netSharpe": round(float(core_metrics["netSharpe"]), 4),
            "maxDrawdown": round(float(core_metrics["maxDrawdown"]), 4),
            "hitRate": round(float(core_metrics["hitRate"]), 2),
            "turnover": round(float(core_metrics["turnover"]), 2),
            "pbo": pbo,
            "dsr": dsr,
            "sampleSize": sample_size,
        },
    }
    if compare_branches:
        shared_params = dict(params)
        shared_params["compareBranches"] = False
        baseline_summary = run_walk_forward_validation(
            strategy=normalized_strategy,
            universe=universe,
            params={**shared_params, "intradaySignalBranch": "baseline", "emitMonitoring": False},
            as_of_date=reference_date,
        )
        phase2_summary = run_walk_forward_validation(
            strategy=normalized_strategy,
            universe=universe,
            params={**shared_params, "intradaySignalBranch": "phase2", "emitMonitoring": False},
            as_of_date=reference_date,
        )
        baseline_metrics = baseline_summary.get("metrics", {}) if isinstance(baseline_summary.get("metrics"), dict) else {}
        phase2_metrics = phase2_summary.get("metrics", {}) if isinstance(phase2_summary.get("metrics"), dict) else {}
        baseline_sharpe = float(baseline_metrics.get("netSharpe", 0.0) or 0.0)
        phase2_sharpe = float(phase2_metrics.get("netSharpe", 0.0) or 0.0)
        recommended_branch = "phase2" if phase2_sharpe >= baseline_sharpe else "baseline"
        result["branchComparison"] = {
            "baseline": {
                "gateStatus": baseline_summary.get("gateStatus"),
                "netSharpe": baseline_metrics.get("netSharpe", 0.0),
                "pbo": baseline_metrics.get("pbo", 1.0),
                "dsr": baseline_metrics.get("dsr", 0.0),
                "sampleSize": baseline_metrics.get("sampleSize", 0),
            },
            "phase2": {
                "gateStatus": phase2_summary.get("gateStatus"),
                "netSharpe": phase2_metrics.get("netSharpe", 0.0),
                "pbo": phase2_metrics.get("pbo", 1.0),
                "dsr": phase2_metrics.get("dsr", 0.0),
                "sampleSize": phase2_metrics.get("sampleSize", 0),
            },
            "recommendedBranch": recommended_branch,
            "selectedBranch": intraday_signal_branch,
        }
    logged, alerts = _emit_validation_monitor(result) if emit_monitoring else (False, [])
    result["monitoring"] = {"logged": logged, "alerts": alerts}
    return result
