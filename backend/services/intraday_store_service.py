from __future__ import annotations

import os
from datetime import datetime
from pathlib import Path
from typing import Callable

import pandas as pd

_STORE_MODE = (os.getenv("INTRADAY_STORE_MODE", "parquet").strip().lower() or "parquet")
INTRADAY_STORE_MODE = _STORE_MODE if _STORE_MODE in {"off", "parquet"} else "parquet"
INTRADAY_STORE_DIR = Path(
    os.getenv(
        "INTRADAY_STORE_DIR",
        str(Path(__file__).resolve().parents[1] / "data" / "intraday"),
    )
)


def _normalized_symbol(symbol: str) -> str:
    return (symbol or "").strip().upper().replace("/", "_")


def _store_path(symbol: str, interval: str) -> Path:
    file_name = f"{_normalized_symbol(symbol)}_{(interval or '5m').lower()}.parquet"
    return INTRADAY_STORE_DIR / file_name


def _read_parquet(path: Path) -> pd.DataFrame | None:
    if not path.exists():
        return None
    try:
        frame = pd.read_parquet(path)
    except Exception:
        return None
    if frame.empty:
        return frame
    if not isinstance(frame.index, pd.DatetimeIndex):
        frame.index = pd.to_datetime(frame.index, errors="coerce")
        frame = frame[~frame.index.isna()]
    return frame.sort_index()


def _write_parquet(path: Path, frame: pd.DataFrame) -> bool:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        frame.to_parquet(path)
        return True
    except Exception:
        return False


def _clip_by_range(frame: pd.DataFrame, start_date: datetime, end_date: datetime) -> pd.DataFrame:
    if frame.empty:
        return frame
    if not isinstance(frame.index, pd.DatetimeIndex):
        return pd.DataFrame(columns=frame.columns)
    idx = frame.index
    if idx.tz is not None:
        start_ts = pd.Timestamp(start_date, tz=idx.tz)
        end_ts = pd.Timestamp(end_date, tz=idx.tz)
    else:
        start_ts = pd.Timestamp(start_date)
        end_ts = pd.Timestamp(end_date)
    clipped = frame[(idx >= start_ts) & (idx < end_ts)]
    return clipped.sort_index()


def load_cached_intraday_frame(
    symbol: str,
    start_date: datetime,
    end_date: datetime,
    interval: str = "5m",
) -> pd.DataFrame:
    if INTRADAY_STORE_MODE != "parquet":
        return pd.DataFrame()
    path = _store_path(symbol, interval=interval)
    frame = _read_parquet(path)
    if frame is None:
        return pd.DataFrame()
    return _clip_by_range(frame, start_date=start_date, end_date=end_date)


def upsert_intraday_frame(symbol: str, frame: pd.DataFrame, interval: str = "5m") -> bool:
    if INTRADAY_STORE_MODE != "parquet":
        return False
    if frame.empty:
        return False

    path = _store_path(symbol, interval=interval)
    existing = _read_parquet(path)
    if existing is None or existing.empty:
        merged = frame.copy()
    else:
        merged = pd.concat([existing, frame]).sort_index()
        merged = merged[~merged.index.duplicated(keep="last")]
    return _write_parquet(path, merged)


def fetch_intraday_with_store(
    symbol: str,
    start_date: datetime,
    end_date: datetime,
    interval: str,
    fetcher: Callable[[str, datetime, datetime, str], pd.DataFrame],
) -> pd.DataFrame:
    cached = load_cached_intraday_frame(symbol, start_date=start_date, end_date=end_date, interval=interval)
    if not cached.empty:
        return cached

    fetched = fetcher(symbol, start_date, end_date, interval)
    if fetched.empty:
        return fetched
    upsert_intraday_frame(symbol=symbol, frame=fetched, interval=interval)
    return fetched
