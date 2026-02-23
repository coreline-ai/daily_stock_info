from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

import yfinance as yf
from sqlalchemy import select

from db.models import StockNewsCache
from db.session import is_db_enabled, session_scope
from services.theme_service import extract_themes


def _to_iso_timestamp(raw_ts: Any) -> str:
    if isinstance(raw_ts, (int, float)):
        return datetime.utcfromtimestamp(raw_ts).strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(raw_ts, str) and raw_ts:
        return raw_ts
    return datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")


def _ticker_candidates(code: str) -> list[str]:
    if "." in code:
        return [code]
    return [f"{code}.KS", f"{code}.KQ"]


def fetch_stock_news_items(code: str, max_items: int = 10) -> list[dict[str, str]]:
    seen_urls: set[str] = set()
    parsed: list[dict[str, str]] = []

    for ticker in _ticker_candidates(code):
        try:
            raw_items = yf.Ticker(ticker).news or []
        except Exception:
            raw_items = []

        for item in raw_items:
            content = item.get("content") if isinstance(item, dict) else {}
            title = ""
            url = ""
            published = ""
            if isinstance(content, dict):
                title = str(content.get("title", "")).strip()
                url = str(content.get("canonicalUrl", {}).get("url", "")).strip()
                published = _to_iso_timestamp(content.get("pubDate"))
            if not title:
                title = str(item.get("title", "")).strip() if isinstance(item, dict) else ""
            if not url:
                url = str(item.get("link", "")).strip() if isinstance(item, dict) else ""
            if not published:
                published = _to_iso_timestamp(item.get("providerPublishTime", "")) if isinstance(item, dict) else ""

            if not title:
                continue
            if url and url in seen_urls:
                continue
            if url:
                seen_urls.add(url)
            parsed.append({"title": title, "url": url, "publishedAt": published})
            if len(parsed) >= max_items:
                return parsed
    return parsed[:max_items]


def summarize_news_3_lines(news_items: list[dict[str, str]]) -> list[str]:
    lines: list[str] = []
    for item in news_items[:3]:
        title = item.get("title", "").strip()
        if not title:
            continue
        if len(title) > 100:
            title = f"{title[:97]}..."
        lines.append(title)
    while len(lines) < 3:
        lines.append("추가 확인 가능한 핵심 뉴스가 부족해 기술 지표 중심으로 판단합니다.")
    return lines


def _prefer_recent(news_items: list[dict[str, str]], trade_date: str) -> list[dict[str, str]]:
    try:
        d = datetime.strptime(trade_date, "%Y-%m-%d")
    except Exception:
        return news_items[:5]
    start = (d - timedelta(days=1)).strftime("%Y-%m-%d")
    end = (d + timedelta(days=1)).strftime("%Y-%m-%d")

    recent = [
        item
        for item in news_items
        if start <= item.get("publishedAt", "0000-00-00")[:10] <= end
    ]
    return (recent or news_items)[:5]


def get_news_and_themes(code: str, trade_date: str) -> tuple[list[dict[str, str]], list[str], list[str]]:
    if is_db_enabled():
        with session_scope() as session:
            cached = session.scalar(
                select(StockNewsCache).where(
                    StockNewsCache.ticker == code,
                    StockNewsCache.trade_date == datetime.strptime(trade_date, "%Y-%m-%d").date(),
                )
            )
            if cached:
                return cached.news_items, cached.summary3, cached.themes

    news_items = _prefer_recent(fetch_stock_news_items(code), trade_date=trade_date)
    summary3 = summarize_news_3_lines(news_items)
    themes = extract_themes([item.get("title", "") for item in news_items] + summary3)

    if is_db_enabled():
        with session_scope() as session:
            session.merge(
                StockNewsCache(
                    ticker=code,
                    trade_date=datetime.strptime(trade_date, "%Y-%m-%d").date(),
                    news_items=news_items,
                    summary3=summary3,
                    themes=themes,
                )
            )

    return news_items, summary3, themes
