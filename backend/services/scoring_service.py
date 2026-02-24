from __future__ import annotations

import os
from datetime import date, datetime, time, timedelta
from typing import Any, Literal
from zoneinfo import ZoneInfo

import numpy as np
import pandas as pd
import yfinance as yf

try:
    import exchange_calendars as xcals
except Exception:  # pragma: no cover - optional dependency
    xcals = None

try:
    import holidays as holiday_lib
except Exception:  # pragma: no cover - optional dependency
    holiday_lib = None

from services.news_service import fetch_stock_news_items
from services.sparkline_service import build_sparkline60
from services.intraday_store_service import fetch_intraday_with_store

StrategyKind = Literal["premarket", "close", "intraday"]

TICKERS = {
    "005930.KS": "삼성전자",
    "000660.KS": "SK하이닉스",
    "373220.KS": "LG에너지솔루션",
    "207940.KS": "삼성바이오로직스",
    "005380.KS": "현대차",
    "000270.KS": "기아",
    "068270.KS": "셀트리온",
    "005490.KS": "POSCO홀딩스",
    "035420.KS": "NAVER",
    "051910.KS": "LG화학",
    "028260.KS": "삼성물산",
    "035720.KS": "카카오",
    "105560.KS": "KB금융",
    "012330.KS": "현대모비스",
    "066570.KS": "LG전자",
    "042660.KS": "한화오션",
    "006400.KS": "삼성SDI",
    "003550.KS": "LG",
    "096770.KS": "SK이노베이션",
    "034730.KS": "SK",
    "086790.KS": "하나금융지주",
    "055550.KS": "신한지주",
    "316140.KS": "우리금융지주",
    "032830.KS": "삼성생명",
    "017670.KS": "SK텔레콤",
    "015760.KS": "한국전력",
    "010950.KS": "S-Oil",
    "011200.KS": "HMM",
    "009540.KS": "HD한국조선해양",
    "329180.KS": "HD현대중공업",
    "267260.KS": "HD현대일렉트릭",
    "298040.KS": "효성중공업",
    "003490.KS": "대한항공",
    "010130.KS": "고려아연",
    "018260.KS": "삼성에스디에스",
    "086280.KS": "현대글로비스",
    "161390.KS": "한국타이어앤테크놀로지",
    "251270.KS": "넷마블",
    "036570.KS": "엔씨소프트",
    "302440.KS": "SK바이오사이언스",
    "006280.KS": "녹십자",
    "079550.KS": "LIG넥스원",
    "000720.KS": "현대건설",
    "003670.KS": "포스코퓨처엠",
    "010140.KS": "삼성중공업",
    "047050.KS": "포스코인터내셔널",
}

CODE_TO_NAME = {
    symbol.replace(".KS", "").replace(".KQ", ""): name
    for symbol, name in TICKERS.items()
}

SECTOR_BY_CODE = {
    "005930": "Semiconductor",
    "000660": "Semiconductor",
    "373220": "Battery",
    "207940": "Bio",
    "005380": "Automotive",
    "000270": "Automotive",
    "068270": "Bio",
    "005490": "Materials",
    "035420": "Internet",
    "051910": "Chemical",
    "028260": "Holdings",
    "035720": "Internet",
    "105560": "Financial",
    "012330": "Automotive",
    "066570": "Electronics",
    "042660": "Industrial",
    "006400": "Battery",
    "003550": "Holdings",
    "096770": "Energy",
    "034730": "Holdings",
    "086790": "Financial",
    "055550": "Financial",
    "316140": "Financial",
    "032830": "Financial",
    "017670": "Telecom",
    "015760": "Utilities",
    "010950": "Energy",
    "011200": "Shipping",
    "009540": "Industrial",
    "329180": "Industrial",
    "267260": "Industrial",
    "298040": "Industrial",
    "003490": "Transport",
    "010130": "Materials",
    "018260": "ITService",
    "086280": "Transport",
    "161390": "Automotive",
    "251270": "Entertainment",
    "036570": "Entertainment",
    "302440": "Bio",
    "006280": "Bio",
    "079550": "Defense",
    "000720": "Construction",
    "003670": "Battery",
    "010140": "Shipbuilding",
    "047050": "Trading",
}

MARKET_CAP_BUCKET_BY_CODE = {
    "005930": "mega",
    "000660": "mega",
    "373220": "mega",
    "207940": "mega",
    "005380": "mega",
    "000270": "mega",
    "068270": "large",
    "005490": "large",
    "035420": "mega",
    "051910": "mega",
    "028260": "large",
    "035720": "large",
    "105560": "large",
    "012330": "large",
    "066570": "large",
    "042660": "mid",
    "006400": "large",
    "003550": "large",
    "096770": "large",
    "034730": "large",
    "086790": "large",
    "055550": "large",
    "316140": "large",
    "032830": "large",
    "017670": "large",
    "015760": "large",
    "010950": "large",
    "011200": "mid",
    "009540": "large",
    "329180": "large",
    "267260": "mid",
    "298040": "mid",
    "003490": "large",
    "010130": "large",
    "018260": "large",
    "086280": "mid",
    "161390": "mid",
    "251270": "mid",
    "036570": "mid",
    "302440": "mid",
    "006280": "mid",
    "079550": "mid",
    "000720": "mid",
    "003670": "large",
    "010140": "mid",
    "047050": "mid",
}

BALANCE_TOP_N = 10
BALANCE_MAX_PER_SECTOR = 2
BALANCE_MAX_PER_MARKET_CAP_BUCKET = 4

DEFAULT_WEIGHTS = {"return": 0.4, "stability": 0.3, "market": 0.3}
REGIME_TO_WEIGHTS = {
    "bull": {"return": 0.55, "stability": 0.2, "market": 0.25},
    "sideways": {"return": 0.35, "stability": 0.4, "market": 0.25},
    "bear": {"return": 0.2, "stability": 0.6, "market": 0.2},
}

KST = ZoneInfo("Asia/Seoul")
MARKET_PREMARKET_START_TIME = time(hour=8, minute=0)
MARKET_INTRADAY_START_TIME = time(hour=9, minute=5)
MARKET_INTRADAY_END_TIME = time(hour=15, minute=20)
MARKET_CLOSE_STRATEGY_START_TIME = time(hour=15, minute=0)
MARKET_CLOSE_TIME = time(hour=15, minute=30)
INTRADAY_MODE = (os.getenv("INTRADAY_MODE", "proxy").strip().lower() or "proxy")
INTRADAY_SIGNAL_BRANCH = (os.getenv("INTRADAY_SIGNAL_BRANCH", "phase2").strip().lower() or "phase2")

_TRADING_DAY_CACHE: dict[str, bool] = {}
_KRX_CALENDAR: Any | None = None
_KRX_CALENDAR_ATTEMPTED = False
_KRX_CALENDAR_ERROR: str | None = None
_KR_HOLIDAY_CACHE: dict[tuple[int, str], Any] = {}

_POSITIVE_NEWS_KEYWORDS = (
    "beat",
    "upgrade",
    "growth",
    "record",
    "partnership",
    "contract",
    "approval",
    "surge",
    "gain",
    "strong",
    "expansion",
    "ai",
    "new order",
    "raised guidance",
)

_NEGATIVE_NEWS_KEYWORDS = (
    "miss",
    "downgrade",
    "lawsuit",
    "probe",
    "delay",
    "cut",
    "drop",
    "recall",
    "weak",
    "decline",
    "loss",
    "risk",
    "guidance cut",
)


def resolve_company_name(code: str) -> str:
    normalized = (code or "").strip().upper().replace(".KS", "").replace(".KQ", "")
    if not normalized:
        return ""
    return CODE_TO_NAME.get(normalized, normalized)


def _code_from_symbol(symbol: str) -> str:
    return (symbol or "").strip().upper().replace(".KS", "").replace(".KQ", "")


def _clamp_score(value: float) -> float:
    return round(max(1.0, min(10.0, float(value))), 3)


def normalize_weights(
    w_return: float | None = None,
    w_stability: float | None = None,
    w_market: float | None = None,
) -> dict[str, float]:
    values = {
        "return": DEFAULT_WEIGHTS["return"] if w_return is None else float(w_return),
        "stability": DEFAULT_WEIGHTS["stability"] if w_stability is None else float(w_stability),
        "market": DEFAULT_WEIGHTS["market"] if w_market is None else float(w_market),
    }
    if any(v < 0 for v in values.values()):
        raise ValueError("가중치는 음수가 될 수 없습니다.")
    total = sum(values.values())
    if total <= 0:
        raise ValueError("가중치 합계는 0보다 커야 합니다.")
    return {k: round(v / total, 6) for k, v in values.items()}


def get_latest_trading_date(target_date_str: str | None = None) -> str:
    base_date = datetime.strptime(target_date_str, "%Y-%m-%d").date() if target_date_str else now_in_kst().date()
    cursor = base_date
    for _ in range(31):
        iso = cursor.isoformat()
        if is_krx_trading_day(iso):
            return iso
        cursor -= timedelta(days=1)

    # Fallback to previous weekday when calendar probing is unavailable.
    dt = datetime.combine(base_date, time.min)
    if dt.weekday() == 5:
        dt -= timedelta(days=1)
    elif dt.weekday() == 6:
        dt -= timedelta(days=2)
    return dt.strftime("%Y-%m-%d")


def now_in_kst() -> datetime:
    return datetime.now(tz=KST)


def _download_frame(ticker_symbol: str, start_date: datetime, end_date: datetime) -> pd.DataFrame:
    frame = yf.download(
        ticker_symbol,
        start=start_date.strftime("%Y-%m-%d"),
        end=end_date.strftime("%Y-%m-%d"),
        progress=False,
        auto_adjust=False,
    )
    if isinstance(frame.columns, pd.MultiIndex):
        frame.columns = frame.columns.droplevel(1)
    return frame


def _download_intraday_frame(
    ticker_symbol: str,
    start_date: datetime,
    end_date: datetime,
    interval: str = "5m",
) -> pd.DataFrame:
    def _fetch_from_yf(symbol: str, start_dt: datetime, end_dt: datetime, tf: str) -> pd.DataFrame:
        frame = yf.download(
            symbol,
            start=start_dt.strftime("%Y-%m-%d"),
            end=end_dt.strftime("%Y-%m-%d"),
            interval=tf,
            progress=False,
            auto_adjust=False,
            prepost=False,
        )
        if isinstance(frame.columns, pd.MultiIndex):
            frame.columns = frame.columns.droplevel(1)
        return frame

    return fetch_intraday_with_store(
        symbol=ticker_symbol,
        start_date=start_date,
        end_date=end_date,
        interval=interval,
        fetcher=_fetch_from_yf,
    )


def _to_kst_datetime_index(index: Any) -> pd.DatetimeIndex:
    parsed = pd.to_datetime(index, errors="coerce")
    if not isinstance(parsed, pd.DatetimeIndex):
        parsed = pd.DatetimeIndex([])
    if parsed.tz is None:
        return parsed.tz_localize(KST, nonexistent="shift_forward", ambiguous="NaT")
    return parsed.tz_convert(KST)


def _between_time_inclusive(frame: pd.DataFrame, start: str, end: str) -> pd.DataFrame:
    try:
        return frame.between_time(start, end, inclusive="both")
    except TypeError:
        return frame.between_time(start, end, include_start=True, include_end=True)


def _load_krx_exchange_calendar() -> Any | None:
    global _KRX_CALENDAR, _KRX_CALENDAR_ATTEMPTED, _KRX_CALENDAR_ERROR
    if _KRX_CALENDAR_ATTEMPTED:
        return _KRX_CALENDAR
    _KRX_CALENDAR_ATTEMPTED = True

    if xcals is None:
        _KRX_CALENDAR_ERROR = "exchange_calendars package is not installed."
        return None

    for calendar_code in ("XKRX", "KRX"):
        try:
            _KRX_CALENDAR = xcals.get_calendar(calendar_code)
            _KRX_CALENDAR_ERROR = None
            return _KRX_CALENDAR
        except Exception as exc:
            _KRX_CALENDAR_ERROR = f"{type(exc).__name__}: {exc}"
    return None


def _is_krx_open_by_external_calendar(target_date: date) -> bool | None:
    calendar = _load_krx_exchange_calendar()
    if calendar is None:
        return None
    try:
        return bool(calendar.is_session(pd.Timestamp(target_date.isoformat())))
    except Exception:
        return None


def _get_kr_holiday_name(target_date: date) -> str | None:
    if holiday_lib is None:
        return None
    for language in ("ko", "en_US"):
        key = (target_date.year, language)
        holiday_calendar = _KR_HOLIDAY_CACHE.get(key)
        if holiday_calendar is None:
            try:
                holiday_calendar = holiday_lib.country_holidays("KR", years=[target_date.year], language=language)
                _KR_HOLIDAY_CACHE[key] = holiday_calendar
            except Exception:
                continue
        try:
            holiday_name = holiday_calendar.get(target_date)
            if holiday_name:
                return str(holiday_name)
        except Exception:
            continue
    return None


def get_non_trading_day_info(target_date: date) -> dict[str, Any]:
    weekday_names = ["월", "화", "수", "목", "금", "토", "일"]
    weekday_index = target_date.weekday()
    session_open = _is_krx_open_by_external_calendar(target_date)
    holiday_name = _get_kr_holiday_name(target_date)
    calendar_status = get_trading_calendar_runtime_status()

    if weekday_index >= 5:
        reason_type = "weekend"
        reason = f"주말({weekday_names[weekday_index]}요일)"
    elif holiday_name:
        reason_type = "holiday"
        reason = f"공휴일({holiday_name})"
    elif session_open is False:
        reason_type = "closed_session"
        reason = "KRX 캘린더상 휴장 세션"
    else:
        reason_type = "unknown_closed"
        reason = "비거래일(캘린더 기준)"

    return {
        "date": target_date.isoformat(),
        "reasonType": reason_type,
        "reason": reason,
        "holidayName": holiday_name,
        "weekday": weekday_names[weekday_index],
        "sessionOpen": session_open,
        "calendarProvider": calendar_status.get("provider"),
        "calendar": calendar_status.get("calendar"),
    }


def get_trading_calendar_runtime_status() -> dict[str, Any]:
    calendar = _load_krx_exchange_calendar()
    if calendar is None:
        return {
            "provider": "yfinance-fallback",
            "calendar": "XKRX",
            "ready": False,
            "reason": _KRX_CALENDAR_ERROR or "unknown",
            "holidayProvider": "holidays" if holiday_lib is not None else "none",
        }
    return {
        "provider": "exchange_calendars",
        "calendar": "XKRX",
        "ready": True,
        "timezone": str(getattr(calendar, "tz", "UTC")),
        "holidayProvider": "holidays" if holiday_lib is not None else "none",
    }


def is_krx_trading_day(date_str: str) -> bool:
    cached = _TRADING_DAY_CACHE.get(date_str)
    if cached is not None:
        return cached

    target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    if target_date.weekday() >= 5:
        _TRADING_DAY_CACHE[date_str] = False
        return False

    calendar_decision = _is_krx_open_by_external_calendar(target_date)
    if calendar_decision is not None:
        _TRADING_DAY_CACHE[date_str] = bool(calendar_decision)
        return _TRADING_DAY_CACHE[date_str]

    now_kst_value = now_in_kst()
    # yfinance daily bars for KRX are finalized after close, so "today" can look missing during session.
    # Treat today's weekday as tradable here and let strategy time-window rules handle access.
    if target_date == now_kst_value.date():
        _TRADING_DAY_CACHE[date_str] = True
        return True

    start_date = datetime.combine(target_date - timedelta(days=2), time.min)
    end_date = datetime.combine(target_date + timedelta(days=2), time.min)

    try:
        frame = _download_frame("^KS11", start_date, end_date)
        if frame.empty:
            raise ValueError("empty index frame")
        idx = pd.to_datetime(frame.index)
        exists = any(pd.Timestamp(ts).date() == target_date for ts in idx)
        _TRADING_DAY_CACHE[date_str] = bool(exists)
    except Exception:
        # Fallback keeps service available if index probing fails.
        _TRADING_DAY_CACHE[date_str] = True
    return _TRADING_DAY_CACHE[date_str]


def get_previous_trading_date(target_date_str: str, max_lookback_days: int = 14) -> str:
    cursor = datetime.strptime(target_date_str, "%Y-%m-%d").date() - timedelta(days=1)
    for _ in range(max_lookback_days):
        iso = cursor.isoformat()
        if is_krx_trading_day(iso):
            return iso
        cursor -= timedelta(days=1)
    return get_latest_trading_date((datetime.strptime(target_date_str, "%Y-%m-%d") - timedelta(days=1)).strftime("%Y-%m-%d"))


def _base_status(
    requested_date: str,
    now_kst_value: datetime,
) -> dict[str, Any]:
    return {
        "timezone": "Asia/Seoul",
        "nowKst": now_kst_value.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "requestedDate": requested_date,
        "availableStrategies": [],
        "defaultStrategy": None,
        "messages": {
            "premarket": "",
            "close": "",
            "intraday": "",
        },
        "errorCode": None,
        "detail": None,
        "nonTradingDay": None,
    }


def get_strategy_status(requested_date_str: str | None, now_kst_value: datetime | None = None) -> dict[str, Any]:
    now_kst_value = now_kst_value or now_in_kst()
    now_date = now_kst_value.date()

    try:
        target_date = datetime.strptime(requested_date_str, "%Y-%m-%d").date() if requested_date_str else now_date
    except ValueError:
        status = _base_status(requested_date="", now_kst_value=now_kst_value)
        status["errorCode"] = "INVALID_DATE"
        status["detail"] = "날짜 형식은 YYYY-MM-DD 이어야 합니다."
        status["messages"]["premarket"] = status["detail"]
        status["messages"]["close"] = status["detail"]
        status["messages"]["intraday"] = status["detail"]
        return status

    requested_date = target_date.isoformat()
    status = _base_status(requested_date=requested_date, now_kst_value=now_kst_value)

    if target_date > now_date:
        msg = f"요청한 날짜({requested_date})는 미래 날짜입니다."
        status["errorCode"] = "DATE_IN_FUTURE"
        status["detail"] = msg
        status["messages"]["premarket"] = msg
        status["messages"]["close"] = msg
        status["messages"]["intraday"] = msg
        return status

    if not is_krx_trading_day(requested_date):
        non_trading_day = get_non_trading_day_info(target_date)
        msg = f"요청한 날짜({requested_date})는 KRX 비거래일입니다. ({non_trading_day['reason']})"
        status["errorCode"] = "NON_TRADING_DAY"
        status["detail"] = msg
        status["messages"]["premarket"] = msg
        status["messages"]["close"] = msg
        status["messages"]["intraday"] = msg
        status["nonTradingDay"] = non_trading_day
        return status

    if target_date < now_date:
        status["availableStrategies"] = ["premarket", "close"]
        status["defaultStrategy"] = "close"
        status["messages"]["premarket"] = "과거 거래일은 장전 전략 리플레이 조회가 가능합니다."
        status["messages"]["close"] = "과거 거래일은 종가 전략 리플레이 조회가 가능합니다."
        status["messages"]["intraday"] = "장중 단타 전략은 당일 장중 시간(09:05~15:20 KST)에만 조회할 수 있습니다."
        return status

    now_time = now_kst_value.time()
    if now_time < MARKET_PREMARKET_START_TIME:
        status["messages"]["premarket"] = "장전 전략은 08:00(KST)부터 조회할 수 있습니다."
        status["messages"]["close"] = "종가 전략은 15:00(KST) 이후 조회할 수 있습니다."
        status["messages"]["intraday"] = "장중 단타 전략은 09:05(KST)부터 15:20(KST)까지 조회할 수 있습니다."
        return status

    if now_time < MARKET_INTRADAY_START_TIME:
        status["availableStrategies"] = ["premarket"]
        status["defaultStrategy"] = "premarket"
        status["messages"]["premarket"] = "현재 장전 전략 조회 가능 시간입니다."
        status["messages"]["close"] = "종가 전략은 15:00(KST) 이후 조회할 수 있습니다."
        status["messages"]["intraday"] = "장중 단타 전략은 09:05(KST)부터 조회할 수 있습니다."
        return status

    if now_time < MARKET_CLOSE_STRATEGY_START_TIME:
        status["availableStrategies"] = ["premarket", "intraday"]
        status["defaultStrategy"] = "intraday"
        status["messages"]["premarket"] = "당일 장전 전략 결과는 리플레이 조회가 가능합니다."
        status["messages"]["close"] = "종가 전략은 15:00(KST) 이후 조회할 수 있습니다."
        status["messages"]["intraday"] = "현재 장중 단타 전략 조회 가능 시간입니다."
        return status

    if now_time <= MARKET_INTRADAY_END_TIME:
        status["availableStrategies"] = ["premarket", "intraday", "close"]
        status["defaultStrategy"] = "intraday"
        status["messages"]["premarket"] = "당일 장전 전략 결과는 리플레이 조회가 가능합니다."
        status["messages"]["close"] = "현재 종가 전략 조회 가능 시간입니다."
        status["messages"]["intraday"] = "현재 장중 단타 전략 조회 가능 시간입니다."
        return status

    if now_time < MARKET_CLOSE_TIME:
        status["availableStrategies"] = ["premarket", "close"]
        status["defaultStrategy"] = "close"
        status["messages"]["premarket"] = "당일 장전 전략 결과는 리플레이 조회가 가능합니다."
        status["messages"]["close"] = "현재 종가 전략 조회 가능 시간입니다."
        status["messages"]["intraday"] = "장중 단타 전략은 15:20(KST)에 마감되었습니다."
        return status

    status["availableStrategies"] = ["premarket", "close"]
    status["defaultStrategy"] = "close"
    status["messages"]["premarket"] = "당일 장전 전략 결과는 리플레이 조회가 가능합니다."
    status["messages"]["close"] = "현재 종가 전략 조회 가능 시간입니다."
    status["messages"]["intraday"] = "장중 단타 전략은 15:20(KST)에 마감되었습니다."
    return status


def validate_strategy_request(
    requested_strategy: str | None,
    requested_date_str: str | None,
    now_kst_value: datetime | None = None,
) -> dict[str, Any]:
    status = get_strategy_status(requested_date_str=requested_date_str, now_kst_value=now_kst_value)
    if status.get("errorCode"):
        return status

    strategy = (requested_strategy or "").strip().lower() if requested_strategy else None
    if strategy and strategy not in {"premarket", "close", "intraday"}:
        status["errorCode"] = "INVALID_STRATEGY"
        status["detail"] = "strategy 값은 premarket, intraday 또는 close 여야 합니다."
        return status

    selected = strategy or status.get("defaultStrategy")
    if not selected:
        status["errorCode"] = "STRATEGY_NOT_AVAILABLE"
        status["detail"] = "요청한 날짜/시간에는 조회 가능한 전략이 없습니다."
        return status

    available = status.get("availableStrategies", [])
    if selected not in available:
        status["errorCode"] = "STRATEGY_NOT_AVAILABLE"
        status["detail"] = (
            f"전략 '{selected}'은(는) {status['requestedDate']}에 사용할 수 없습니다. "
            f"사용 가능 전략: {', '.join(available) if available else '없음'}."
        )
        return status

    session_date = str(status["requestedDate"])
    signal_date = get_previous_trading_date(session_date) if selected == "premarket" else session_date

    if requested_strategy:
        strategy_reason = f"explicit:{selected}"
    elif session_date < (now_kst_value or now_in_kst()).date().isoformat():
        strategy_reason = "auto:past-date-default-close"
    else:
        strategy_reason = f"auto:current-session-{selected}"

    status["strategy"] = selected
    status["sessionDate"] = session_date
    status["signalDate"] = signal_date
    status["strategyReason"] = strategy_reason
    return status


def validate_recommendation_request_date(requested_date_str: str | None) -> tuple[str, str | None]:
    # Backward-compatible wrapper for legacy close-only checks.
    resolved = validate_strategy_request("close", requested_date_str)
    if resolved.get("errorCode"):
        return str(resolved.get("requestedDate") or ""), str(resolved.get("detail") or "request is not allowed")
    return str(resolved["sessionDate"]), None


def _normalize_ticker(raw: str) -> list[str]:
    ticker = raw.strip().upper()
    if not ticker:
        return []
    if "." in ticker:
        return [ticker]
    if ticker.isdigit() and len(ticker) == 6:
        return [f"{ticker}.KS", f"{ticker}.KQ"]
    return [ticker]


def _build_universe(
    custom_tickers: list[str] | None = None,
    restrict_symbols: list[str] | None = None,
) -> dict[str, str]:
    if restrict_symbols:
        restricted = [symbol for symbol in restrict_symbols if symbol in TICKERS]
        universe = {symbol: TICKERS[symbol] for symbol in restricted}
        if not universe:
            universe = dict(TICKERS)
    else:
        universe = dict(TICKERS)
    existing_codes = {_code_from_symbol(symbol) for symbol in universe.keys()}
    if not custom_tickers:
        return universe
    for raw in custom_tickers:
        for symbol in _normalize_ticker(raw):
            if symbol in universe:
                continue
            code = _code_from_symbol(symbol)
            if not code or code in existing_codes:
                continue
            universe[symbol] = resolve_company_name(code)
            existing_codes.add(code)
    return universe


def _infer_sector(code: str) -> str:
    return SECTOR_BY_CODE.get(code, "Other")


def _infer_market_cap_bucket(code: str, avg_vol_20: float | None = None) -> str:
    predefined = MARKET_CAP_BUCKET_BY_CODE.get(code)
    if predefined:
        return predefined
    if avg_vol_20 is None:
        return "mid"
    if avg_vol_20 >= 8_000_000:
        return "mega"
    if avg_vol_20 >= 2_500_000:
        return "large"
    return "mid"


def _sma(series: pd.Series, length: int) -> pd.Series:
    return series.rolling(length, min_periods=1).mean()


def _ema(series: pd.Series, span: int) -> pd.Series:
    return series.ewm(span=span, adjust=False).mean()


def _rsi(close: pd.Series, length: int = 14) -> pd.Series:
    delta = close.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.ewm(alpha=1 / length, min_periods=length, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1 / length, min_periods=length, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    rsi = 100 - (100 / (1 + rs))
    return rsi.fillna(50.0)


def _macd(close: pd.Series) -> pd.Series:
    ema12 = _ema(close, 12)
    ema26 = _ema(close, 26)
    return ema12 - ema26


def _atr(high: pd.Series, low: pd.Series, close: pd.Series, length: int = 14) -> pd.Series:
    prev_close = close.shift(1)
    tr = pd.concat(
        [
            (high - low).abs(),
            (high - prev_close).abs(),
            (low - prev_close).abs(),
        ],
        axis=1,
    ).max(axis=1)
    return tr.ewm(alpha=1 / length, min_periods=length, adjust=False).mean()


def _compute_scores(close: pd.Series, volume: pd.Series) -> tuple[dict[str, float], dict[str, float]]:
    sma5 = _sma(close, length=5)
    sma20 = _sma(close, length=20)
    rsi_series = _rsi(close, length=14)
    macd_series = _macd(close)

    rsi_val = float(rsi_series.iloc[-1])
    macd_val = float(macd_series.iloc[-1])

    ma_score = 10.0 if sma5.iloc[-1] > sma20.iloc[-1] else 4.0
    rsi_score = 10.0 if 40 <= rsi_val <= 70 else (5.0 if rsi_val > 70 else 8.0)
    macd_score = 10.0 if macd_val > 0 else 5.0
    return_score = round((ma_score * 0.4) + (rsi_score * 0.3) + (macd_score * 0.3), 1)

    rolling_max = close.rolling(window=60, min_periods=1).max()
    drawdown = (close / rolling_max) - 1.0
    mdd = float(drawdown.min())
    daily_returns = close.pct_change().dropna()
    volatility = float(daily_returns.rolling(window=60).std().iloc[-1] * np.sqrt(252)) if not daily_returns.empty else 0.0
    mdd_score = max(0.0, 10.0 - (abs(mdd) * 100 / 3))
    vol_score = max(0.0, 10.0 - (volatility * 10))
    stability_score = round((mdd_score * 0.6) + (vol_score * 0.4), 1)

    avg_vol_20 = float(volume.rolling(20).mean().iloc[-1])
    # Use a log scale so high-liquidity large caps no longer saturate the market factor too easily.
    log_volume = float(np.log10(max(avg_vol_20, 1.0)))
    market_score = 1.0 + (((log_volume - 4.5) / 3.0) * 9.0)
    market_score = round(max(1.0, min(10.0, market_score)), 1)
    return (
        {
            "return": return_score,
            "stability": stability_score,
            "market": market_score,
        },
        {"rsi": rsi_val, "macd": macd_val, "mdd": mdd, "volatility": volatility, "avgVol20": avg_vol_20},
    )


def _compute_news_sentiment_score(titles: list[str]) -> float:
    if not titles:
        return 5.0
    pos_count = 0
    neg_count = 0
    for title in titles:
        lowered = title.lower()
        pos_count += sum(1 for kw in _POSITIVE_NEWS_KEYWORDS if kw in lowered)
        neg_count += sum(1 for kw in _NEGATIVE_NEWS_KEYWORDS if kw in lowered)
    raw = (pos_count - neg_count) / max(1, len(titles))
    return _clamp_score(5.0 + (raw * 2.5))


def _collect_news_titles_for_window(
    code: str,
    window_start_kst: datetime,
    window_end_kst: datetime,
) -> tuple[list[str], bool]:
    news_items = fetch_stock_news_items(code, max_items=20)
    primary_titles: list[str] = []
    fallback_titles: list[str] = []
    fallback_start = window_end_kst - timedelta(hours=24)

    for item in news_items:
        title = str(item.get("title", "")).strip()
        if not title:
            continue
        ts = pd.to_datetime(item.get("publishedAt", ""), errors="coerce", utc=True)
        if pd.isna(ts):
            continue
        ts_kst = ts.tz_convert(KST)
        if window_start_kst <= ts_kst <= window_end_kst:
            primary_titles.append(title)
        if fallback_start <= ts_kst <= window_end_kst:
            fallback_titles.append(title)

    if primary_titles:
        return primary_titles[:5], True
    if fallback_titles:
        return fallback_titles[:5], False
    return [], False


def _compute_overnight_proxy_score(session_date: str) -> float:
    indices = ("^GSPC", "^IXIC", "^SOX")
    session_dt = datetime.strptime(session_date, "%Y-%m-%d")
    end_date = session_dt + timedelta(days=1)
    start_date = end_date - timedelta(days=14)
    changes: list[float] = []

    for ticker in indices:
        try:
            frame = _download_frame(ticker, start_date, end_date)
            if frame.empty or len(frame["Close"]) < 2:
                continue
            close = frame["Close"]
            current_val = float(close.iloc[-1])
            prev_val = float(close.iloc[-2])
            if prev_val == 0:
                continue
            changes.append(((current_val - prev_val) / prev_val) * 100)
        except Exception:
            continue

    if not changes:
        return 5.0

    avg_change = float(np.mean(changes))
    return _clamp_score(5.0 + (avg_change * 1.8))


def _apply_premarket_adjustments(
    *,
    code: str,
    raw_scores: dict[str, float],
    score_weights: dict[str, float],
    tags: list[str],
    session_date: str,
    signal_date: str,
    overnight_proxy: float | None = None,
) -> tuple[dict[str, float], dict[str, float], float, dict[str, Any], list[str]]:
    session_dt = datetime.strptime(session_date, "%Y-%m-%d")
    signal_dt = datetime.strptime(signal_date, "%Y-%m-%d")
    window_start = datetime.combine(signal_dt.date(), MARKET_CLOSE_TIME, tzinfo=KST)
    window_end = datetime.combine(session_dt.date(), MARKET_PREMARKET_START_TIME, tzinfo=KST)

    titles, used_primary_window = _collect_news_titles_for_window(
        code=code,
        window_start_kst=window_start,
        window_end_kst=window_end,
    )
    news_sentiment = _compute_news_sentiment_score(titles)
    resolved_overnight_proxy = overnight_proxy if overnight_proxy is not None else _compute_overnight_proxy_score(session_date)

    adjusted_raw = {
        "return": _clamp_score((raw_scores["return"] * 0.65) + (news_sentiment * 0.35)),
        "stability": _clamp_score(raw_scores["stability"]),
        "market": _clamp_score((raw_scores["market"] * 0.70) + (resolved_overnight_proxy * 0.30)),
    }
    adjusted_weighted = {
        "return": round(adjusted_raw["return"] * score_weights["return"], 3),
        "stability": round(adjusted_raw["stability"] * score_weights["stability"], 3),
        "market": round(adjusted_raw["market"] * score_weights["market"], 3),
    }
    total_score = round(sum(adjusted_weighted.values()), 1)

    merged_tags = ["PREMARKET", *tags] if "PREMARKET" not in tags else tags[:]
    premarket_signals = {
        "newsSentiment": round(news_sentiment, 3),
        "overnightProxy": round(resolved_overnight_proxy, 3),
        "newsWindowStart": window_start.isoformat(),
        "newsWindowEnd": window_end.isoformat(),
        "usedPrimaryWindow": used_primary_window,
        "analyzedNewsCount": len(titles),
    }
    return adjusted_raw, adjusted_weighted, total_score, premarket_signals, merged_tags


def _compute_intraday_bars_signals(
    *,
    code: str,
    session_date: str,
) -> dict[str, float] | None:
    try:
        session_day = datetime.strptime(session_date, "%Y-%m-%d").date()
    except ValueError:
        return None

    symbols = _normalize_ticker(code)
    if not symbols:
        return None

    for symbol in symbols:
        try:
            intraday_end = datetime.combine(session_day + timedelta(days=1), time.min)
            intraday_start = intraday_end - timedelta(days=14)
            bars = _download_intraday_frame(
                symbol,
                start_date=intraday_start,
                end_date=intraday_end,
                interval="5m",
            )
            if bars.empty:
                continue
            required_cols = {"Open", "High", "Low", "Close", "Volume"}
            if not required_cols.issubset(set(str(col) for col in bars.columns)):
                continue

            bars = bars.copy()
            bars.index = _to_kst_datetime_index(bars.index)
            bars = bars[~bars.index.isna()]
            if bars.empty:
                continue

            bars = _between_time_inclusive(bars, "09:00", "15:20")
            if bars.empty:
                continue

            session_bars = bars[[idx.date() == session_day for idx in bars.index]]
            if session_bars.empty or len(session_bars) < 3:
                continue

            first_range = session_bars.iloc[:3]
            orb_high = float(first_range["High"].max())
            orb_low = float(first_range["Low"].min())
            session_open = float(session_bars["Open"].iloc[0])
            last_close = float(session_bars["Close"].iloc[-1])
            session_high = float(session_bars["High"].max())
            session_low = float(session_bars["Low"].min())

            volume = pd.to_numeric(session_bars["Volume"], errors="coerce").fillna(0.0).clip(lower=0.0)
            cum_volume = volume.cumsum()
            if cum_volume.empty or float(cum_volume.iloc[-1]) <= 0:
                continue
            typical_price = (session_bars["High"] + session_bars["Low"] + session_bars["Close"]) / 3.0
            vwap_series = ((typical_price * volume).cumsum() / cum_volume.replace(0, np.nan)).ffill()
            vwap_val = float(vwap_series.iloc[-1]) if not vwap_series.empty and pd.notna(vwap_series.iloc[-1]) else last_close

            orb_mid = (orb_high + orb_low) / 2.0
            orb_span = max(orb_high - orb_low, max(session_open * 0.002, 0.01))
            orb_breakout = (last_close - orb_mid) / orb_span
            orb_score = _clamp_score(5.0 + (orb_breakout * 2.4))

            vwap_dev_pct = ((last_close - vwap_val) / vwap_val) * 100 if vwap_val else 0.0
            vwap_score = _clamp_score(5.0 + (vwap_dev_pct * 2.0))

            current_ts = session_bars.index[-1]
            current_tod = current_ts.time()
            current_cum_volume = float(cum_volume.iloc[-1])

            history = bars[[idx.date() < session_day for idx in bars.index]]
            rvol_profile_ratio = 1.0
            if not history.empty:
                hist_vol = pd.to_numeric(history["Volume"], errors="coerce").fillna(0.0).clip(lower=0.0)
                history = history.copy()
                history["_volume"] = hist_vol
                historical_cums: list[float] = []
                for _, day_frame in history.groupby(history.index.date):
                    sliced = day_frame[[ts.time() <= current_tod for ts in day_frame.index]]
                    if sliced.empty:
                        continue
                    historical_cums.append(float(sliced["_volume"].sum()))
                baseline = float(np.mean(historical_cums)) if historical_cums else 0.0
                if baseline > 0:
                    rvol_profile_ratio = current_cum_volume / baseline

            rvol_score = _clamp_score(5.0 + ((rvol_profile_ratio - 1.0) * 3.2))

            daily_end = datetime.combine(session_day + timedelta(days=1), time.min)
            daily_start = daily_end - timedelta(days=60)
            daily_frame = _download_frame(symbol, daily_start, daily_end)
            prev_close = 0.0
            if not daily_frame.empty and "Close" in daily_frame:
                daily_frame = daily_frame.copy()
                daily_frame.index = pd.to_datetime(daily_frame.index, errors="coerce")
                daily_frame = daily_frame[~daily_frame.index.isna()]
                prev_close_series = daily_frame[[idx.date() < session_day for idx in daily_frame.index]]["Close"]
                if not prev_close_series.empty and pd.notna(prev_close_series.iloc[-1]):
                    prev_close = float(prev_close_series.iloc[-1])

            overnight_return_pct = ((session_open - prev_close) / prev_close) * 100 if prev_close else 0.0
            intraday_return_pct = ((last_close - session_open) / session_open) * 100 if session_open else 0.0
            intraday_momentum_score = _clamp_score(5.0 + (intraday_return_pct * 2.4))

            is_reversal = overnight_return_pct * intraday_return_pct < 0
            reversal_mag = min(abs(overnight_return_pct), abs(intraday_return_pct))
            overnight_reversal_score = _clamp_score(
                5.0 + (2.0 if is_reversal else -1.0) + (reversal_mag * 1.1)
            )

            session_range_pct = ((session_high - session_low) / max(session_open, 1e-9)) * 100
            in_play_score = _clamp_score(4.5 + (session_range_pct * 1.1) + ((rvol_profile_ratio - 1.0) * 2.0))

            return {
                "orbScore": round(orb_score, 3),
                "vwapScore": round(vwap_score, 3),
                "rvolScore": round(rvol_score, 3),
                "orbHigh": round(orb_high, 3),
                "orbLow": round(orb_low, 3),
                "vwap": round(vwap_val, 3),
                "lastPrice": round(last_close, 3),
                "rvolProfileRatio": round(rvol_profile_ratio, 3),
                "inPlayScore": round(in_play_score, 3),
                "intradayMomentumScore": round(intraday_momentum_score, 3),
                "overnightReversalScore": round(overnight_reversal_score, 3),
                "overnightReturnPct": round(overnight_return_pct, 3),
                "intradayReturnPct": round(intraday_return_pct, 3),
            }
        except Exception:
            continue
    return None


def _apply_intraday_proxy_adjustments(
    *,
    code: str,
    raw_scores: dict[str, float],
    score_weights: dict[str, float],
    tags: list[str],
    open_price: float,
    current_price: float,
    day_high: float,
    day_low: float,
    today_volume: float,
    avg_vol_20: float,
    session_date: str,
    mode: str,
    signal_branch: str,
) -> tuple[dict[str, float], dict[str, float], float, dict[str, Any], list[str]]:
    resolved_mode = mode if mode in {"proxy", "bars"} else "proxy"
    resolved_branch = signal_branch if signal_branch in {"baseline", "phase2"} else "phase2"
    bar_signals = (
        _compute_intraday_bars_signals(code=code, session_date=session_date)
        if resolved_mode == "bars" and resolved_branch == "phase2"
        else None
    )

    # Proxy fallback blends opening-range drift, proxy-VWAP deviation and relative volume.
    range_span = max(day_high - day_low, max(current_price * 0.005, 1.0))
    range_position = max(0.0, min(1.0, (current_price - day_low) / range_span))
    open_drift_pct = ((current_price - open_price) / open_price) * 100 if open_price else 0.0
    orb_proxy_score = _clamp_score(5.0 + (open_drift_pct * 1.4) + ((range_position - 0.5) * 5.0))

    vwap_proxy_price = (day_high + day_low + current_price) / 3.0
    vwap_dev_pct = ((current_price - vwap_proxy_price) / vwap_proxy_price) * 100 if vwap_proxy_price else 0.0
    vwap_proxy_score = _clamp_score(5.0 + (vwap_dev_pct * 2.0))

    rvol_ratio = today_volume / max(avg_vol_20, 1.0)
    rvol_score = _clamp_score(5.0 + ((rvol_ratio - 1.0) * 3.0))

    in_play_score = None
    intraday_momentum_score = None
    overnight_reversal_score = None
    rvol_profile_ratio = None
    overnight_return_pct = None
    intraday_return_pct = None
    if bar_signals:
        orb_proxy_score = _clamp_score(float(bar_signals.get("orbScore", orb_proxy_score)))
        vwap_proxy_score = _clamp_score(float(bar_signals.get("vwapScore", vwap_proxy_score)))
        rvol_score = _clamp_score(float(bar_signals.get("rvolScore", rvol_score)))
        in_play_score = _clamp_score(float(bar_signals.get("inPlayScore", 5.0)))
        intraday_momentum_score = _clamp_score(float(bar_signals.get("intradayMomentumScore", orb_proxy_score)))
        overnight_reversal_score = _clamp_score(float(bar_signals.get("overnightReversalScore", 5.0)))
        rvol_profile_ratio = float(bar_signals.get("rvolProfileRatio", rvol_ratio))
        overnight_return_pct = float(bar_signals.get("overnightReturnPct", 0.0))
        intraday_return_pct = float(bar_signals.get("intradayReturnPct", open_drift_pct))
        signal_mode = "bars-phase2"
    else:
        if resolved_mode == "proxy":
            signal_mode = "proxy"
        elif resolved_branch == "phase2":
            signal_mode = "proxy-fallback"
        else:
            signal_mode = "proxy-baseline"

    if bar_signals and resolved_branch == "phase2":
        adjusted_raw = {
            "return": _clamp_score(
                (raw_scores["return"] * 0.35)
                + (orb_proxy_score * 0.25)
                + (vwap_proxy_score * 0.15)
                + (float(intraday_momentum_score or 5.0) * 0.15)
                + (float(in_play_score or 5.0) * 0.10)
            ),
            "stability": _clamp_score(
                (raw_scores["stability"] * 0.55)
                + ((10.0 - abs(vwap_proxy_score - 5.0)) * 0.15)
                + (float(overnight_reversal_score or 5.0) * 0.15)
                + ((10.0 - abs(float(intraday_momentum_score or 5.0) - 5.0)) * 0.15)
            ),
            "market": _clamp_score(
                (raw_scores["market"] * 0.40)
                + (rvol_score * 0.35)
                + (float(in_play_score or 5.0) * 0.25)
            ),
        }
    else:
        adjusted_raw = {
            "return": _clamp_score((raw_scores["return"] * 0.45) + (orb_proxy_score * 0.35) + (vwap_proxy_score * 0.20)),
            "stability": _clamp_score((raw_scores["stability"] * 0.70) + ((10.0 - abs(vwap_proxy_score - 5.0)) * 0.30)),
            "market": _clamp_score((raw_scores["market"] * 0.55) + (rvol_score * 0.45)),
        }
    adjusted_weighted = {
        "return": round(adjusted_raw["return"] * score_weights["return"], 3),
        "stability": round(adjusted_raw["stability"] * score_weights["stability"], 3),
        "market": round(adjusted_raw["market"] * score_weights["market"], 3),
    }
    total_score = round(sum(adjusted_weighted.values()), 1)

    intraday_signals = {
        "mode": signal_mode,
        "signalBranch": resolved_branch,
        "orbProxyScore": round(orb_proxy_score, 3),
        "vwapProxyScore": round(vwap_proxy_score, 3),
        "rvolScore": round(rvol_score, 3),
        "openPrice": round(open_price, 3),
        "dayHigh": round(day_high, 3),
        "dayLow": round(day_low, 3),
        "vwapProxyPrice": round(vwap_proxy_price, 3),
        "rvolRatio": round(rvol_ratio, 3),
    }
    if bar_signals:
        intraday_signals["orbHigh"] = round(float(bar_signals.get("orbHigh", day_high)), 3)
        intraday_signals["orbLow"] = round(float(bar_signals.get("orbLow", day_low)), 3)
        intraday_signals["vwapPrice"] = round(float(bar_signals.get("vwap", vwap_proxy_price)), 3)
    if in_play_score is not None:
        intraday_signals["inPlayScore"] = round(float(in_play_score), 3)
    if intraday_momentum_score is not None:
        intraday_signals["intradayMomentumScore"] = round(float(intraday_momentum_score), 3)
    if overnight_reversal_score is not None:
        intraday_signals["overnightReversalScore"] = round(float(overnight_reversal_score), 3)
    if rvol_profile_ratio is not None:
        intraday_signals["rvolProfileRatio"] = round(float(rvol_profile_ratio), 3)
    if overnight_return_pct is not None:
        intraday_signals["overnightReturnPct"] = round(float(overnight_return_pct), 3)
    if intraday_return_pct is not None:
        intraday_signals["intradayReturnPct"] = round(float(intraday_return_pct), 3)
    merged_tags = ["INTRADAY", *tags] if "INTRADAY" not in tags else tags[:]
    return adjusted_raw, adjusted_weighted, total_score, intraday_signals, merged_tags


def apply_sector_exposure_cap(
    candidates: list[dict[str, Any]],
    top_n: int = 5,
    max_per_sector: int = 2,
) -> list[dict[str, Any]]:
    if not candidates or max_per_sector <= 0:
        return candidates

    selected: list[dict[str, Any]] = []
    deferred: list[dict[str, Any]] = []
    sector_count: dict[str, int] = {}

    for candidate in candidates:
        sector = candidate.get("sector", "Other")
        capped = len(selected) < top_n and sector_count.get(sector, 0) >= max_per_sector
        item = {**candidate, "exposureDeferred": capped}
        if capped:
            deferred.append(item)
            continue
        selected.append(item)
        if len(selected) <= top_n:
            sector_count[sector] = sector_count.get(sector, 0) + 1

    if len(selected) < top_n and deferred:
        need = top_n - len(selected)
        rescued = deferred[:need]
        for item in rescued:
            item["exposureDeferred"] = False
        selected.extend(rescued)
        deferred = deferred[need:]

    final = selected + deferred
    for idx, item in enumerate(final):
        item["rank"] = idx + 1
    return final


def apply_diversified_sampling(
    candidates: list[dict[str, Any]],
    top_n: int = BALANCE_TOP_N,
    max_per_sector: int = BALANCE_MAX_PER_SECTOR,
    max_per_market_cap_bucket: int = BALANCE_MAX_PER_MARKET_CAP_BUCKET,
) -> list[dict[str, Any]]:
    if not candidates:
        return candidates

    def _select_candidate_index(deferred_items: list[dict[str, Any]], strict: bool) -> int | None:
        chosen_idx: int | None = None
        chosen_key: tuple[float, float, float] | None = None
        for idx, item in enumerate(deferred_items):
            sector = str(item.get("sector", "Other"))
            bucket = str(item.get("marketCapBucket", "mid"))
            sector_used = float(sector_count.get(sector, 0))
            bucket_used = float(bucket_count.get(bucket, 0))
            if strict and (sector_used >= max_per_sector or bucket_used >= max_per_market_cap_bucket):
                continue

            score = float(item.get("score", 0.0))
            candidate_key = (sector_used, bucket_used, -score)
            if chosen_key is None or candidate_key < chosen_key:
                chosen_key = candidate_key
                chosen_idx = idx
        return chosen_idx

    selected: list[dict[str, Any]] = []
    deferred: list[dict[str, Any]] = []
    sector_count: dict[str, int] = {}
    bucket_count: dict[str, int] = {}

    for candidate in candidates:
        sector = str(candidate.get("sector", "Other"))
        bucket = str(candidate.get("marketCapBucket", "mid"))
        sector_limited = sector_count.get(sector, 0) >= max_per_sector
        bucket_limited = bucket_count.get(bucket, 0) >= max_per_market_cap_bucket
        should_defer = len(selected) < top_n and (sector_limited or bucket_limited)

        item = {**candidate, "balanceDeferred": should_defer}
        if should_defer:
            deferred.append(item)
            continue

        selected.append(item)
        if len(selected) <= top_n:
            sector_count[sector] = sector_count.get(sector, 0) + 1
            bucket_count[bucket] = bucket_count.get(bucket, 0) + 1

    if len(selected) < top_n and deferred:
        while len(selected) < top_n and deferred:
            pick_idx = _select_candidate_index(deferred, strict=True)
            if pick_idx is None:
                pick_idx = _select_candidate_index(deferred, strict=False)
            if pick_idx is None:
                break

            item = deferred.pop(pick_idx)
            item["balanceDeferred"] = False
            sector = str(item.get("sector", "Other"))
            bucket = str(item.get("marketCapBucket", "mid"))
            sector_count[sector] = sector_count.get(sector, 0) + 1
            bucket_count[bucket] = bucket_count.get(bucket, 0) + 1
            selected.append(item)

    final = selected + deferred
    for idx, item in enumerate(final):
        item["rank"] = idx + 1
    return final


def detect_market_regime(candidates: list[dict[str, Any]], indices: list[dict[str, Any]]) -> dict[str, Any]:
    if not candidates:
        return {
            "regime": "sideways",
            "label": "Sideways",
            "confidence": 35.0,
            "suggestedWeights": DEFAULT_WEIGHTS,
            "reason": "Insufficient breadth data, fallback to default weights.",
        }

    up = len([c for c in candidates if c.get("changeRate", 0) > 0])
    down = len([c for c in candidates if c.get("changeRate", 0) < 0])
    total = len(candidates)
    breadth = (up - down) / max(1, total)
    index_avg = float(np.mean([idx.get("changeRate", 0.0) for idx in indices])) if indices else 0.0
    dispersion = float(np.std([c.get("changeRate", 0.0) for c in candidates])) if len(candidates) > 1 else 0.0

    if breadth >= 0.2 and index_avg >= 0.25:
        regime = "bull"
        label = "Bull"
        reason = "Positive breadth and index momentum are both strong."
    elif breadth <= -0.2 and index_avg <= -0.25:
        regime = "bear"
        label = "Bear"
        reason = "Negative breadth and index momentum are both weak."
    else:
        regime = "sideways"
        label = "Sideways"
        reason = "Breadth and index momentum are mixed."

    raw_conf = 45 + (abs(breadth) * 35) + (abs(index_avg) * 6) - (dispersion * 2)
    confidence = round(max(25.0, min(95.0, raw_conf)), 1)

    return {
        "regime": regime,
        "label": label,
        "confidence": confidence,
        "suggestedWeights": REGIME_TO_WEIGHTS[regime],
        "reason": reason,
    }


def fetch_and_score_stocks(
    date_str: str | None = None,
    weights: dict[str, float] | None = None,
    include_sparkline: bool = True,
    custom_tickers: list[str] | None = None,
    enforce_exposure_cap: bool = False,
    max_per_sector: int = 2,
    cap_top_n: int = 5,
    strategy: StrategyKind = "close",
    session_date_str: str | None = None,
    intraday_signal_branch: str | None = None,
    restrict_symbols: list[str] | None = None,
) -> dict[str, Any]:
    strategy_value = str(strategy).lower()
    if strategy_value == "premarket":
        normalized_strategy: StrategyKind = "premarket"
    elif strategy_value == "intraday":
        normalized_strategy = "intraday"
    else:
        normalized_strategy = "close"

    if normalized_strategy == "premarket":
        session_date = session_date_str or date_str or now_in_kst().date().isoformat()
        signal_date = get_previous_trading_date(session_date)
    elif normalized_strategy == "intraday":
        session_date = session_date_str or date_str or now_in_kst().date().isoformat()
        signal_date = session_date
    else:
        signal_date = get_latest_trading_date(date_str)
        session_date = session_date_str or signal_date

    score_weights = normalize_weights(
        (weights or DEFAULT_WEIGHTS).get("return"),
        (weights or DEFAULT_WEIGHTS).get("stability"),
        (weights or DEFAULT_WEIGHTS).get("market"),
    )
    end_date = datetime.strptime(signal_date, "%Y-%m-%d") + timedelta(days=1)
    start_date = end_date - timedelta(days=180)
    candidates: list[dict[str, Any]] = []

    if restrict_symbols is None:
        universe = _build_universe(custom_tickers=custom_tickers)
    else:
        universe = _build_universe(custom_tickers=custom_tickers, restrict_symbols=restrict_symbols)
    overnight_proxy_cache = _compute_overnight_proxy_score(session_date) if normalized_strategy == "premarket" else None
    intraday_mode = INTRADAY_MODE if INTRADAY_MODE in {"proxy", "bars"} else "proxy"
    resolved_intraday_branch = (
        str(intraday_signal_branch).strip().lower()
        if intraday_signal_branch is not None
        else INTRADAY_SIGNAL_BRANCH
    )
    if resolved_intraday_branch not in {"baseline", "phase2"}:
        resolved_intraday_branch = "phase2"

    for ticker_symbol, name in universe.items():
        try:
            df = _download_frame(ticker_symbol, start_date, end_date)
            if df.empty or len(df) < 60:
                continue

            close = df["Close"]
            volume = df["Volume"]
            high = df["High"]
            low = df["Low"]
            open_ = df["Open"]

            current_price = float(close.iloc[-1])
            prev_price = float(close.iloc[-2]) if len(close) > 1 else current_price
            change_rate = round(((current_price - prev_price) / prev_price) * 100, 2) if prev_price else 0.0

            raw_scores, signals = _compute_scores(close=close, volume=volume)

            code = _code_from_symbol(ticker_symbol)
            sector = _infer_sector(code)
            market_cap_bucket = _infer_market_cap_bucket(code=code, avg_vol_20=float(signals.get("avgVol20", 0.0)))
            tags = ["Value"] if raw_scores["stability"] > 8 else (["TechnicalRebound"] if signals["rsi"] < 40 else ["Momentum"])

            premarket_signals: dict[str, Any] | None = None
            intraday_signals: dict[str, Any] | None = None
            scoring_raw = raw_scores
            if normalized_strategy == "premarket":
                adjusted_raw, adjusted_weighted, total_score, premarket_signals, tags = _apply_premarket_adjustments(
                    code=code,
                    raw_scores=raw_scores,
                    score_weights=score_weights,
                    tags=tags,
                    session_date=session_date,
                    signal_date=signal_date,
                    overnight_proxy=overnight_proxy_cache,
                )
                scoring_raw = adjusted_raw
                weighted_scores = adjusted_weighted
            elif normalized_strategy == "intraday":
                adjusted_raw, adjusted_weighted, total_score, intraday_signals, tags = _apply_intraday_proxy_adjustments(
                    code=code,
                    raw_scores=raw_scores,
                    score_weights=score_weights,
                    tags=tags,
                    open_price=float(open_.iloc[-1]),
                    current_price=current_price,
                    day_high=float(high.iloc[-1]),
                    day_low=float(low.iloc[-1]),
                    today_volume=float(volume.iloc[-1]),
                    avg_vol_20=float(signals.get("avgVol20", 0.0)),
                    session_date=session_date,
                    mode=intraday_mode,
                    signal_branch=resolved_intraday_branch,
                )
                scoring_raw = adjusted_raw
                weighted_scores = adjusted_weighted
            else:
                weighted_scores = {
                    "return": round(scoring_raw["return"] * score_weights["return"], 3),
                    "stability": round(scoring_raw["stability"] * score_weights["stability"], 3),
                    "market": round(scoring_raw["market"] * score_weights["market"], 3),
                }
                total_score = round(sum(weighted_scores.values()), 1)

            atr = _atr(high=high, low=low, close=close, length=14)
            atr_val = float(atr.iloc[-1]) if atr is not None and not atr.empty and pd.notna(atr.iloc[-1]) else current_price * 0.05
            target_price = round(current_price + (atr_val * 2))
            stop_loss = round(current_price - (atr_val * 1.5))

            high_60 = float(high.rolling(window=60, min_periods=1).max().iloc[-1])
            low_10 = float(low.rolling(window=10, min_periods=1).min().iloc[-1])
            summary = (
                f"RSI {signals['rsi']:.1f}, MACD {signals['macd']:.2f}, "
                f"MDD {abs(signals['mdd']) * 100:.1f}%"
            )
            if normalized_strategy == "premarket" and premarket_signals is not None:
                summary = (
                    f"장전 합성 신호(뉴스={premarket_signals['newsSentiment']:.1f}, "
                    f"야간프록시={premarket_signals['overnightProxy']:.1f}). "
                    f"{summary}"
                )
            elif normalized_strategy == "intraday" and intraday_signals is not None:
                summary = (
                    f"장중 단타 신호(ORB={intraday_signals['orbProxyScore']:.1f}, "
                    f"VWAP={intraday_signals['vwapProxyScore']:.1f}, "
                    f"RVOL={intraday_signals['rvolScore']:.1f}, "
                    f"branch={intraday_signals.get('signalBranch', 'phase2')}, "
                    f"mode={intraday_signals['mode']}). "
                    f"{summary}"
                )

            sparkline60 = build_sparkline60(close.tolist(), length=60) if include_sparkline else []

            candidate_payload: dict[str, Any] = {
                "name": name,
                "code": code,
                "score": total_score,
                "changeRate": change_rate,
                "price": current_price,
                "targetPrice": target_price,
                "stopLoss": stop_loss,
                "high60": high_60,
                "low10": low_10,
                "tags": tags,
                "sector": sector,
                "marketCapBucket": market_cap_bucket,
                "summary": summary,
                "sparkline60": sparkline60,
                "strategy": normalized_strategy,
                "sessionDate": session_date,
                "signalDate": signal_date,
                "details": {
                    "raw": scoring_raw,
                    "weighted": weighted_scores,
                },
            }
            if premarket_signals is not None:
                candidate_payload["details"]["premarketSignals"] = premarket_signals
            if intraday_signals is not None:
                candidate_payload["details"]["intradaySignals"] = intraday_signals

            candidates.append(candidate_payload)
        except Exception:
            continue

    deduped_by_code: dict[str, dict[str, Any]] = {}
    for candidate in candidates:
        code = candidate["code"]
        existing = deduped_by_code.get(code)
        if existing is None or float(candidate["score"]) > float(existing["score"]):
            deduped_by_code[code] = candidate
    candidates = list(deduped_by_code.values())

    candidates.sort(key=lambda x: x["score"], reverse=True)
    candidates = apply_diversified_sampling(candidates)
    for item in candidates:
        item["exposureDeferred"] = False

    if enforce_exposure_cap:
        candidates = apply_sector_exposure_cap(candidates, top_n=cap_top_n, max_per_sector=max_per_sector)

    for idx, item in enumerate(candidates):
        rank = int(item.get("rank", idx + 1))
        item["rank"] = rank
        item["strongRecommendation"] = rank <= 5

    return {
        "date": signal_date,
        "sessionDate": session_date,
        "signalDate": signal_date,
        "strategy": normalized_strategy,
        "candidates": candidates,
        "weights": score_weights,
        "exposureCap": {
            "enabled": enforce_exposure_cap,
            "maxPerSector": max_per_sector,
            "topN": cap_top_n,
        },
        "diversification": {
            "enabled": True,
            "topN": BALANCE_TOP_N,
            "maxPerSector": BALANCE_MAX_PER_SECTOR,
            "maxPerMarketCapBucket": BALANCE_MAX_PER_MARKET_CAP_BUCKET,
        },
    }


def get_market_indices(date_str: str) -> list[dict[str, Any]]:
    indices = {"^KS11": "KOSPI", "^KQ11": "KOSDAQ", "^GSPC": "S&P 500"}
    end_date = datetime.strptime(date_str, "%Y-%m-%d") + timedelta(days=1)
    start_date = end_date - timedelta(days=7)
    result: list[dict[str, Any]] = []
    for ticker, name in indices.items():
        try:
            frame = _download_frame(ticker, start_date, end_date)
            if frame.empty or len(frame["Close"]) < 2:
                continue
            close = frame["Close"]
            current_idx = float(close.iloc[-1])
            prev_idx = float(close.iloc[-2])
            if prev_idx == 0:
                continue
            change_rate = round(((current_idx - prev_idx) / prev_idx) * 100, 2)
            result.append({"name": name, "value": round(current_idx, 2), "changeRate": change_rate})
        except Exception:
            continue
    return result


def get_market_overview(candidates: list[dict[str, Any]], indices: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    up = len([c for c in candidates if c.get("changeRate", 0) > 0])
    down = len([c for c in candidates if c.get("changeRate", 0) < 0])
    steady = len(candidates) - up - down
    warnings: list[dict[str, str]] = []
    if down > (up + steady) * 1.5:
        warnings.append({"type": "error", "message": "Broad downside pressure detected; keep entries conservative."})
    elif down > up:
        warnings.append({"type": "warning", "message": "Risk control is advised; consider staggered exits."})

    regime = detect_market_regime(candidates=candidates, indices=indices or [])
    return {
        "up": up,
        "steady": steady,
        "down": down,
        "warnings": warnings,
        "indices": indices or [],
        "regimeRecommendation": regime,
    }


def get_price_series_for_ticker(code: str, trade_date: str, future_days: int = 7) -> pd.Series:
    start = datetime.strptime(trade_date, "%Y-%m-%d") - timedelta(days=2)
    end = datetime.strptime(trade_date, "%Y-%m-%d") + timedelta(days=future_days + 7)
    symbols = [code] if "." in code else [f"{code}.KS", f"{code}.KQ"]
    for symbol in symbols:
        frame = _download_frame(symbol, start, end)
        if not frame.empty:
            return frame["Close"]
    return pd.Series(dtype=float)


def get_trade_day_ohlc_for_ticker(code: str, trade_date: str) -> dict[str, float | None]:
    start = datetime.strptime(trade_date, "%Y-%m-%d") - timedelta(days=2)
    end = datetime.strptime(trade_date, "%Y-%m-%d") + timedelta(days=2)
    target_day = datetime.strptime(trade_date, "%Y-%m-%d").date()
    symbols = [code] if "." in code else [f"{code}.KS", f"{code}.KQ"]

    for symbol in symbols:
        try:
            frame = _download_frame(symbol, start, end)
            if frame.empty:
                continue
            idx = pd.to_datetime(frame.index)
            for pos, ts in enumerate(idx):
                if pd.Timestamp(ts).date() != target_day:
                    continue
                row = frame.iloc[pos]
                return {
                    "open": float(row["Open"]) if pd.notna(row["Open"]) else None,
                    "high": float(row["High"]) if pd.notna(row["High"]) else None,
                    "low": float(row["Low"]) if pd.notna(row["Low"]) else None,
                    "close": float(row["Close"]) if pd.notna(row["Close"]) else None,
                }
        except Exception:
            continue
    return {"open": None, "high": None, "low": None, "close": None}
