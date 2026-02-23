from __future__ import annotations

from typing import Iterable

THEME_RULES = {
    "반도체": ["반도체", "semiconductor", "chip", "hbm", "memory"],
    "2차전지": ["2차전지", "배터리", "battery", "cathode", "anode"],
    "AI": ["ai", "인공지능", "llm", "gpu", "데이터센터"],
    "자동차": ["자동차", "ev", "전기차", "차량", "mobility"],
    "바이오": ["바이오", "bio", "신약", "제약", "임상"],
    "플랫폼": ["플랫폼", "portal", "광고", "콘텐츠", "ecommerce"],
}


def extract_themes(texts: Iterable[str], max_items: int = 3) -> list[str]:
    joined = " ".join(texts).lower()
    matched: list[str] = []
    for theme, keywords in THEME_RULES.items():
        if any(keyword in joined for keyword in keywords):
            matched.append(theme)
    if not matched:
        return ["일반"]
    return matched[:max_items]
