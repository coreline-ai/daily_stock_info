"""
Backward-compatible wrappers.
This module remains to avoid breaking imports while routing to scoring_service.
"""

from services.scoring_service import (  # noqa: F401
    DEFAULT_WEIGHTS,
    TICKERS,
    fetch_and_score_stocks,
    get_strategy_status,
    get_latest_trading_date,
    get_previous_trading_date,
    get_non_trading_day_info,
    get_trading_calendar_runtime_status,
    get_market_indices,
    get_market_overview,
    validate_strategy_request,
    validate_recommendation_request_date,
    normalize_weights,
)
