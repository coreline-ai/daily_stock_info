CREATE TABLE IF NOT EXISTS recommendation_snapshots (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL,
    ticker VARCHAR(16) NOT NULL,
    rank INTEGER NOT NULL,
    price DOUBLE PRECISION NOT NULL,
    score_return DOUBLE PRECISION NOT NULL,
    score_stability DOUBLE PRECISION NOT NULL,
    score_market DOUBLE PRECISION NOT NULL,
    total_score DOUBLE PRECISION NOT NULL,
    target_price DOUBLE PRECISION NOT NULL,
    stop_loss DOUBLE PRECISION NOT NULL,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    sparkline60 JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_snapshot_trade_ticker UNIQUE (trade_date, ticker)
);

CREATE TABLE IF NOT EXISTS backtest_results (
    id SERIAL PRIMARY KEY,
    trade_date DATE NOT NULL,
    ticker VARCHAR(16) NOT NULL,
    entry_price DOUBLE PRECISION NOT NULL,
    ret_t1 DOUBLE PRECISION,
    ret_t3 DOUBLE PRECISION,
    ret_t5 DOUBLE PRECISION,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_backtest_trade_ticker UNIQUE (trade_date, ticker)
);

CREATE TABLE IF NOT EXISTS stock_news_cache (
    id SERIAL PRIMARY KEY,
    ticker VARCHAR(16) NOT NULL,
    trade_date DATE NOT NULL,
    news_items JSONB NOT NULL DEFAULT '[]'::jsonb,
    summary3 JSONB NOT NULL DEFAULT '[]'::jsonb,
    themes JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_news_ticker_date UNIQUE (ticker, trade_date)
);

CREATE TABLE IF NOT EXISTS ai_reports (
    id SERIAL PRIMARY KEY,
    ticker VARCHAR(16) NOT NULL,
    trade_date DATE NOT NULL,
    provider VARCHAR(64) NOT NULL,
    model VARCHAR(128) NOT NULL,
    prompt_hash VARCHAR(64) NOT NULL,
    report JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_ai_report_ticker_date_prompt UNIQUE (ticker, trade_date, prompt_hash)
);

CREATE TABLE IF NOT EXISTS user_watchlists (
    id SERIAL PRIMARY KEY,
    user_key VARCHAR(64) NOT NULL DEFAULT 'default',
    ticker VARCHAR(32) NOT NULL,
    alias VARCHAR(128),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_watchlist_user_ticker UNIQUE (user_key, ticker)
);
