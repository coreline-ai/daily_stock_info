"""
stock_service.py
Handles fetching stock data and running the scoring algorithm using pandas and pandas_ta.
"""
import yfinance as yf
import pandas as pd
import pandas_ta as ta
import numpy as np
from datetime import datetime, timedelta

# Mock list of Top Korean Stocks for quick testing.
# .KS for KOSPI, .KQ for KOSDAQ
TICKERS = {
    '005930.KS': '삼성전자',
    '000660.KS': 'SK하이닉스',
    '373220.KS': 'LG에너지솔루션',
    '207940.KS': '삼성바이오로직스',
    '005380.KS': '현대차',
    '000270.KS': '기아',
    '068270.KS': '셀트리온',
    '005490.KS': 'POSCO홀딩스',
    '035420.KS': 'NAVER',
    '051910.KS': 'LG화학',
    '028260.KS': '삼성물산',
    '035720.KS': '카카오',
    '105560.KS': 'KB금융',
    '012330.KS': 'HD현대모비스', 
    '066570.KS': 'LG전자',
    '042660.KS': '현대건설기계'
}

def get_latest_trading_date(target_date_str: str = None) -> str:
    """Return the valid trading date (excluding weekends)."""
    if target_date_str:
        dt = datetime.strptime(target_date_str, '%Y-%m-%d')
    else:
        dt = datetime.today()
        
    # Standardize to nearest previous weekday if Saturday/Sunday
    if dt.weekday() == 5: # Saturday
        dt -= timedelta(days=1)
    elif dt.weekday() == 6: # Sunday
        dt -= timedelta(days=2)
        
    return dt.strftime('%Y-%m-%d')

def fetch_and_score_stocks(date_str: str = None):
    valid_date = get_latest_trading_date(date_str)
    # Fetch 6 months of data to cover 60-day MDD and 20-day MAs
    end_date = datetime.strptime(valid_date, '%Y-%m-%d') + timedelta(days=1)
    start_date = end_date - timedelta(days=180)
    
    candidates = []
    
    for ticker_symbol, name in TICKERS.items():
        try:
            df = yf.download(ticker_symbol, start=start_date.strftime('%Y-%m-%d'), end=end_date.strftime('%Y-%m-%d'), progress=False)
            if df.empty or len(df) < 60:
                continue
            
            if isinstance(df.columns, pd.MultiIndex):
                df.columns = df.columns.droplevel(1)
                
            close = df['Close']
            volume = df['Volume']
            high = df['High']
            low = df['Low']
            
            current_price = float(close.iloc[-1])
            prev_price = float(close.iloc[-2]) if len(close) > 1 else current_price
            change_rate = round(((current_price - prev_price) / prev_price) * 100, 2)
            
            # --- 1. Return Factor ---
            df.ta.macd(close='Close', append=True)
            df.ta.rsi(close='Close', length=14, append=True)
            sma5 = ta.sma(close, length=5)
            sma20 = ta.sma(close, length=20)
            
            rsi_val = df['RSI_14'].iloc[-1]
            macd_val = df['MACD_12_26_9'].iloc[-1]
            
            ma_score = 10 if (sma5.iloc[-1] > sma20.iloc[-1]) else 4
            rsi_score = 10 if 40 <= rsi_val <= 70 else (5 if rsi_val > 70 else 8)
            macd_score = 10 if macd_val > 0 else 5
            return_score = round((ma_score * 0.4) + (rsi_score * 0.3) + (macd_score * 0.3), 1)

            # --- 2. Stability Factor ---
            rolling_max = close.rolling(window=60, min_periods=1).max()
            drawdown = (close / rolling_max) - 1.0
            mdd = drawdown.min()
            
            daily_returns = close.pct_change().dropna()
            volatility = daily_returns.rolling(window=60).std().iloc[-1] * np.sqrt(252)
            
            mdd_score = max(0, 10 - (abs(mdd) * 100 / 3))
            vol_score = max(0, 10 - (volatility * 10))
            stability_score = round((mdd_score * 0.6) + (vol_score * 0.4), 1)

            # --- 3. Market Factor ---
            avg_vol_20 = volume.rolling(20).mean().iloc[-1]
            market_score = min(10.0, avg_vol_20 / 1000000.0 * 10)
            market_score = round(max(1.0, market_score), 1)
            
            total_score = round((return_score * 0.4) + (stability_score * 0.3) + (market_score * 0.3), 1)

            # Target & Stop Loss Calculation (ATR based)
            df.ta.atr(high=high, low=low, close=close, length=14, append=True)
            atr_val = df['ATRr_14'].iloc[-1] if 'ATRr_14' in df.columns else (current_price * 0.05)
            
            target_price = round(current_price + (atr_val * 2))
            stop_loss = round(current_price - (atr_val * 1.5))
            
            # Additional metrics for detail card
            high_60 = float(high.rolling(window=60, min_periods=1).max().iloc[-1])
            low_10 = float(low.rolling(window=10, min_periods=1).min().iloc[-1])

            summary = f"RSI 지표가 {rsi_val:.1f}로 나타나며 최근 {'긍정적인 모멘텀' if macd_val > 0 else '보수적인 접근이 필요한 모멘텀'}을 보이고 있습니다. 고점 대비 하락률(MDD)은 {abs(mdd)*100:.1f}% 수준입니다."
            
            code = ticker_symbol.replace('.KS', '').replace('.KQ', '')

            candidates.append({
                "name": name,
                "code": code,
                "score": total_score,
                "changeRate": change_rate,
                "price": current_price,
                "targetPrice": target_price,
                "stopLoss": stop_loss,
                "high60": high_60,
                "low10": low_10,
                "tags": ["가치주"] if stability_score > 8 else (["기술적 반등"] if rsi_val < 40 else ["모멘텀"]),
                "summary": summary,
                "details": {
                    "return": return_score,
                    "stability": stability_score,
                    "market": market_score
                }
            })
            
        except Exception as e:
            print(f"Error processing {ticker_symbol}: {e}")
            continue
            
    candidates.sort(key=lambda x: x["score"], reverse=True)
    
    for i, item in enumerate(candidates):
        item["rank"] = i + 1
        
    return {
        "date": valid_date,
        "candidates": candidates
    }

def get_market_indices(date_str: str) -> list:
    """Fetch KOSPI, KOSDAQ, and S&P 500 summary data for the UI bar."""
    
    indices = {
        '^KS11': 'KOSPI',
        '^KQ11': 'KOSDAQ',
        '^GSPC': 'S&P 500'
    }
    
    end_date = datetime.strptime(date_str, '%Y-%m-%d') + timedelta(days=1)
    start_date = end_date - timedelta(days=7) # Small window to get the most recent valid day
    
    result = []
    
    for ticker, name in indices.items():
        try:
            df = yf.download(ticker, start=start_date.strftime('%Y-%m-%d'), end=end_date.strftime('%Y-%m-%d'), progress=False)
            if df.empty:
                continue
            
            if isinstance(df.columns, pd.MultiIndex):
                df.columns = df.columns.droplevel(1)
                
            close = df['Close']
            if len(close) < 2:
                continue
                
            current_idx = float(close.iloc[-1])
            prev_idx = float(close.iloc[-2])
            change_rate = round(((current_idx - prev_idx) / prev_idx) * 100, 2)
            
            result.append({
                "name": name,
                "value": round(current_idx, 2),
                "changeRate": change_rate
            })
        except Exception as e:
            print(f"Error fetching index {ticker}: {e}")
            
    return result

def get_market_overview(candidates: list) -> dict:
    up = 0
    steady = 0
    down = 0
    
    for c in candidates:
        if c["changeRate"] > 0:
            up += 1
        elif c["changeRate"] < 0:
            down += 1
        else:
            steady +=1
            
    warnings = []
    if down > (up + steady) * 1.5:
        warnings.append({"type": "error", "message": "시장 전반에 강한 매도세가 출회 중이므로 신규 진입을 매우 보수적으로 접근하세요."})
    elif down > up:
        warnings.append({"type": "warning", "message": "투자 심리가 둔화되고 있습니다. 수익성이 확보된 편입 종목 위주로 관리하세요."})
        
    return {
        "up": up,
        "steady": steady,
        "down": down,
        "warnings": warnings,
        "indices": [] # Handled dynamically at higher level
    }
