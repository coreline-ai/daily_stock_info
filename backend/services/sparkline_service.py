from __future__ import annotations

from typing import Iterable, List


def normalize_sparkline(values: Iterable[float]) -> List[float]:
    points = [float(v) for v in values]
    if not points:
        return []
    low = min(points)
    high = max(points)
    if high == low:
        return [50.0 for _ in points]
    scale = high - low
    return [round(((p - low) / scale) * 100, 2) for p in points]


def build_sparkline60(values: Iterable[float], length: int = 60) -> List[float]:
    points = [float(v) for v in values]
    if not points:
        return []
    tail = points[-length:]
    return normalize_sparkline(tail)
