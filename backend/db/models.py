from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import JSON, Date, DateTime, Float, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


def _json_type():
    # Keep JSONB on PostgreSQL while allowing SQLite/local development with generic JSON.
    return JSON().with_variant(JSONB, "postgresql")


class RecommendationSnapshot(Base):
    __tablename__ = "recommendation_snapshots"
    __table_args__ = (UniqueConstraint("trade_date", "ticker", name="uq_snapshot_trade_ticker"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    trade_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    ticker: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    rank: Mapped[int] = mapped_column(Integer, nullable=False)
    price: Mapped[float] = mapped_column(Float, nullable=False)
    score_return: Mapped[float] = mapped_column(Float, nullable=False)
    score_stability: Mapped[float] = mapped_column(Float, nullable=False)
    score_market: Mapped[float] = mapped_column(Float, nullable=False)
    total_score: Mapped[float] = mapped_column(Float, nullable=False)
    target_price: Mapped[float] = mapped_column(Float, nullable=False)
    stop_loss: Mapped[float] = mapped_column(Float, nullable=False)
    tags: Mapped[list[str]] = mapped_column(_json_type(), nullable=False, default=list)
    sparkline60: Mapped[list[float]] = mapped_column(_json_type(), nullable=False, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())


class BacktestResult(Base):
    __tablename__ = "backtest_results"
    __table_args__ = (UniqueConstraint("trade_date", "ticker", name="uq_backtest_trade_ticker"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    trade_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    ticker: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    entry_price: Mapped[float] = mapped_column(Float, nullable=False)
    ret_t1: Mapped[float | None] = mapped_column(Float, nullable=True)
    ret_t3: Mapped[float | None] = mapped_column(Float, nullable=True)
    ret_t5: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())


class StockNewsCache(Base):
    __tablename__ = "stock_news_cache"
    __table_args__ = (UniqueConstraint("ticker", "trade_date", name="uq_news_ticker_date"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ticker: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    trade_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    news_items: Mapped[list[dict]] = mapped_column(_json_type(), nullable=False, default=list)
    summary3: Mapped[list[str]] = mapped_column(_json_type(), nullable=False, default=list)
    themes: Mapped[list[str]] = mapped_column(_json_type(), nullable=False, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())


class AIReport(Base):
    __tablename__ = "ai_reports"
    __table_args__ = (
        UniqueConstraint("ticker", "trade_date", "prompt_hash", name="uq_ai_report_ticker_date_prompt"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ticker: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    trade_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    provider: Mapped[str] = mapped_column(String(64), nullable=False)
    model: Mapped[str] = mapped_column(String(128), nullable=False)
    prompt_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    report: Mapped[dict] = mapped_column(_json_type(), nullable=False, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())


class UserWatchlist(Base):
    __tablename__ = "user_watchlists"
    __table_args__ = (UniqueConstraint("user_key", "ticker", name="uq_watchlist_user_ticker"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_key: Mapped[str] = mapped_column(String(64), nullable=False, index=True, default="default")
    ticker: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    alias: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())
