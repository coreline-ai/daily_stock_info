from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from typing import Optional
from services.stock_service import fetch_and_score_stocks, get_market_overview as get_overview, get_market_indices

app = FastAPI(title="DailyStock AI API", version="1.0.0")

# Cache to prevent repetitive Yahoo Finance pulling
_CACHE = {}

# Configure CORS for Next.js frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/v1/market-overview")
def get_market_overview(date: Optional[str] = None):
    # Determine cache key
    cache_key = f"overview_{date}"
    if cache_key in _CACHE:
        return _CACHE[cache_key]

    # Process candidates to derive market overview
    data = fetch_and_score_stocks(date)
    overview = get_overview(data["candidates"])
    
    # Also fetch external indices
    indices = get_market_indices(data["date"])
    overview["indices"] = indices
    
    _CACHE[cache_key] = overview
    return overview

@app.get("/api/v1/stock-candidates")
def get_stock_candidates(date: Optional[str] = None):
    cache_key = f"candidates_{date}"
    if cache_key in _CACHE:
        return _CACHE[cache_key]
        
    data = fetch_and_score_stocks(date)
    # We return the candidates array directly so the frontend mapping works
    # But ideally frontend could consume { date, candidates }
    # To not break the current frontend we inject the realDate inside each candidate
    for c in data["candidates"]:
        c["realDate"] = data["date"]
        
    _CACHE[cache_key] = data["candidates"]
    return data["candidates"]

@app.get("/api/v1/stocks/{ticker}/detail")
def get_stock_detail(ticker: str, date: Optional[str] = None):
    # Get all candidates for the date using our existing cached endpoint
    all_candidates = get_stock_candidates(date)
    for c in all_candidates:
        if c["code"] == ticker:
            return {
                "ticker": ticker,
                "name": c["name"],
                "currentPrice": c["price"],
                "targetPrice": c["targetPrice"],
                "stopLoss": c["stopLoss"],
                "high60": c.get("high60", c["price"]),
                "low10": c.get("low10", c["price"]),
                "expectedReturn": round(((c["targetPrice"] - c["price"]) / c["price"]) * 100, 2),
                "tags": c.get("tags", []),
                "signals": [
                    {"type": "buy" if c["score"] > 5 else "sell", "message": c["summary"]}
                ]
            }
    # Fallback if not found in our top tickers
    return {"error": "Stock not found in current analysis pool."}

@app.get("/api/v1/market-insight")
def get_market_insight(date: Optional[str] = None):
    # Dynamically generate insight based on our overview data
    overview = get_market_overview(date)
    up = overview.get("up", 0)
    down = overview.get("down", 0)
    
    risk_factors = []
    if down > up * 2:
        risk_factors.append({"id": "Risk 1", "description": "시장 전반적인 하락 압력이 거세어 리스크 관리가 강하게 요구되는 시점입니다."})
        conclusion = "전체적으로 보수적인 포트폴리오 접근이 필요하며, 개별 종목의 안정성(MDD, Volatility) 지표를 철저히 검증해야 합니다."
    elif up > down * 2:
        risk_factors.append({"id": "Risk 1", "description": "단기 과열 양상으로 인한 차익 매물 출회 가능성에 유의해야 합니다."})
        conclusion = "상승 모멘텀을 타되, 목표가에 도달한 종목은 분할 매도하여 수익을 실현하는 방어적 전략이 유효합니다."
    else:
        risk_factors.append({"id": "Risk 1", "description": "뚜렷한 방향성이 매일 변동하는 종목별 테마 장세가 이어지고 있습니다."})
        conclusion = "각 종목의 RSI, MACD 지표를 복합적으로 참조하며 철저히 개별 모멘텀에 집중한 트레이딩이 추천됩니다."

    # Grab the real date from one of the candidates if available
    cands = get_stock_candidates(date)
    real_target_date = cands[0]["realDate"] if cands else date
    
    return {
        "date": real_target_date,
        "riskFactors": risk_factors,
        "conclusion": conclusion
    }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
