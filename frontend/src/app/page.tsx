"use client";

import { useEffect, useState } from 'react';

interface Warning {
  type: 'warning' | 'error';
  message: string;
}

interface MarketOverview {
  up: number;
  steady: number;
  down: number;
  warnings: Warning[];
  indices?: { name: string; value: number; changeRate: number; }[];
}

interface StockCandidate {
  rank: number;
  name: string;
  code: string;
  score: number;
  changeRate: number;
  price: number;
  targetPrice: number;
  stopLoss: number;
  tags: string[];
  summary: string;
  details: {
    return: number;
    stability: number;
    market: number;
  };
  realDate?: string;
}

interface MarketInsight {
  date: string;
  riskFactors: { id: string; description: string }[];
  conclusion: string;
}

interface StockDetail {
  ticker: string;
  name: string;
  currentPrice: number;
  targetPrice: number;
  stopLoss: number;
  high60: number;
  low10: number;
  expectedReturn: number;
  tags: string[];
  signals: { type: string, message: string }[];
}

// ProgressBar Component
const ProgressBar = ({ label, score, colorClass }: { label: string, score: number, colorClass: string }) => {
  const percentage = (score / 10) * 100;
  return (
    <div className="flex flex-col gap-1 w-full text-xs">
      <div className="flex justify-between text-color-muted">
        <span>{label}</span>
        <span className="font-semibold text-white">{score.toFixed(1)}/10</span>
      </div>
      <div className="h-1.5 w-full bg-color-progress rounded-full overflow-hidden">
        <div className={`h-full ${colorClass}`} style={{ width: `${percentage}%` }}></div>
      </div>
    </div>
  );
};

export default function Home() {
  const today = new Date().toISOString().split('T')[0];
  const [selectedDate, setSelectedDate] = useState(today);
  const [effectiveDate, setEffectiveDate] = useState<string>(today);

  const [marketInfo, setMarketInfo] = useState<MarketOverview | null>(null);
  const [candidates, setCandidates] = useState<StockCandidate[]>([]);
  const [insight, setInsight] = useState<MarketInsight | null>(null);

  const [expandedRow, setExpandedRow] = useState<string | null>(null);
  const [detailData, setDetailData] = useState<Record<string, StockDetail>>({});

  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      setLoading(true);
      try {
        const query = `?date=${selectedDate}`;
        const [marketRes, candidatesRes, insightRes] = await Promise.all([
          fetch(`http://localhost:8000/api/v1/market-overview${query}`),
          fetch(`http://localhost:8000/api/v1/stock-candidates${query}`),
          fetch(`http://localhost:8000/api/v1/market-insight${query}`)
        ]);

        const cands = await candidatesRes.json();
        if (cands.length > 0 && cands[0].realDate) {
          setEffectiveDate(cands[0].realDate);
        } else {
          setEffectiveDate(selectedDate);
        }

        setMarketInfo(await marketRes.json());
        setCandidates(cands);
        setInsight(await insightRes.json());
      } catch (err) {
        console.error('Error fetching data:', err);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [selectedDate]);

  const handlePrevDay = () => {
    const d = new Date(selectedDate);
    // Rough calculation: skip weekends
    do {
      d.setDate(d.getDate() - 1);
    } while (d.getDay() === 0 || d.getDay() === 6);
    setSelectedDate(d.toISOString().split('T')[0]);
  };

  const handleNextDay = () => {
    const d = new Date(selectedDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Don't go past today
    if (d >= today) return;

    do {
      d.setDate(d.getDate() + 1);
    } while (d.getDay() === 0 || d.getDay() === 6);

    if (d <= today) {
      setSelectedDate(d.toISOString().split('T')[0]);
    }
  };

  const toggleExpand = async (code: string) => {
    if (expandedRow === code) {
      setExpandedRow(null);
      return;
    }

    setExpandedRow(code);
    if (!detailData[code]) {
      try {
        const res = await fetch(`http://localhost:8000/api/v1/stocks/${code}/detail?date=${selectedDate}`);
        const data = await res.json();
        setDetailData(prev => ({ ...prev, [code]: data }));
      } catch (err) {
        console.error(err);
      }
    }
  };

  if (loading) return (
    <div className="max-w-4xl mx-auto p-4 md:p-6 pb-20 space-y-8 animate-pulse">
      {/* Header Skeleton */}
      <div className="flex items-start justify-between">
        <div className="space-y-2">
          <div className="h-8 bg-gray-800 rounded w-48"></div>
          <div className="h-4 bg-gray-800 rounded w-64"></div>
        </div>
        <div className="flex gap-3">
          <div className="h-8 bg-gray-800 rounded w-32"></div>
          <div className="h-8 bg-gray-800 rounded w-40"></div>
        </div>
      </div>

      {/* Overview Skeleton */}
      <div className="bg-color-card border border-color-card-border rounded-lg p-5">
        <div className="h-5 bg-gray-800 rounded w-32 mb-4"></div>
        <div className="grid grid-cols-3 gap-3">
          <div className="h-20 bg-gray-800 rounded"></div>
          <div className="h-20 bg-gray-800 rounded"></div>
          <div className="h-20 bg-gray-800 rounded"></div>
        </div>
      </div>

      {/* List Skeleton */}
      <div className="space-y-2">
        <div className="flex justify-between">
          <div className="h-6 bg-gray-800 rounded w-40"></div>
          <div className="h-4 bg-gray-800 rounded w-20"></div>
        </div>
        <div className="h-10 bg-gray-800 rounded"></div>
        {[1, 2, 3, 4, 5].map(i => (
          <div key={i} className="h-16 bg-gray-800 border border-gray-700 rounded"></div>
        ))}
      </div>
    </div>
  );

  return (
    <main className="max-w-4xl mx-auto p-4 md:p-6 pb-20 space-y-8">

      {/* 1. Header & Controls */}
      <div className="flex flex-col gap-4">
        {/* Title and Top Badge Row */}
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-2xl font-bold flex items-center gap-2">
              <span className="text-blue-500">📈</span> 종가 전략 AI
            </h1>
            <p className="text-color-muted text-sm mt-1">DailyStock - AI 기반 종가 검색</p>
          </div>

          <div className="flex items-center gap-3">
            <div className="bg-color-card border border-color-card-border rounded px-3 py-1.5 flex items-center gap-2 text-sm relative">
              <span>📅</span>
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                className="bg-transparent border-none outline-none text-white cursor-pointer"
              />
              {effectiveDate && effectiveDate !== selectedDate && (
                <span className="absolute -top-6 left-0 bg-yellow-900/80 text-yellow-200 text-xs px-2 py-1 rounded whitespace-nowrap">
                  휴장일이므로 {effectiveDate} 기준 실 데이터를 불러왔습니다
                </span>
              )}
            </div>
            <div className="bg-[#0f1924] border border-[#1a2d42] text-[#3b82f6] text-[11px] px-2.5 py-1 rounded">
              <span className="font-semibold text-[#0ea5e9]">현행유지 배당율 20.0%</span> | 기대수익 12.87%
            </div>
          </div>
        </div>

        {/* Date Navigation Bar */}
        <div className="flex items-center justify-between text-sm py-2 px-1 text-color-muted border-t border-color-card-border/50">
          <button onClick={handlePrevDay} className="hover:text-white px-2 py-1 rounded bg-color-card border border-color-card-border opacity-70 hover:opacity-100">&lt;</button>
          <div className="font-medium text-gray-300">
            {new Date(selectedDate).toLocaleDateString('ko-KR', { month: 'long', day: 'numeric', weekday: 'short' })}
          </div>
          <button onClick={handleNextDay} className="hover:text-white px-2 py-1 rounded bg-color-card border border-color-card-border opacity-70 hover:opacity-100">&gt;</button>
        </div>
      </div>

      {/* 2. Market Overview */}
      <section className="bg-color-card border border-color-card-border rounded-lg p-5 mt-2">
        <h2 className="text-xs font-semibold mb-3 text-color-muted flex items-center gap-2">
          <span>📊</span> Market Overview
        </h2>
        <div className="text-[10px] text-gray-500 mb-3 block">해당일 ({effectiveDate}) 시장 종합 지표</div>

        <div className="grid grid-cols-3 gap-3 mb-4 text-center">
          <div className="bg-[#1c2128] border border-[#2d333b] rounded py-4">
            <div className="text-red-400 text-2xl font-bold">{marketInfo?.down}종목</div>
            <div className="text-[11px] text-gray-500 mt-1">하락</div>
          </div>
          <div className="bg-[#1c2128] border border-[#2d333b] rounded py-4">
            <div className="text-gray-400 text-2xl font-bold">{marketInfo?.steady}종목</div>
            <div className="text-[11px] text-gray-500 mt-1">보합</div>
          </div>
          <div className="bg-[#1c2128] border border-[#2d333b] rounded py-4">
            <div className="text-green-500 text-2xl font-bold">{marketInfo?.up}종목</div>
            <div className="text-[11px] text-gray-500 mt-1">상승</div>
          </div>
        </div>

        {/* Index Summary Bar */}
        {marketInfo?.indices && marketInfo.indices.length > 0 && (
          <div className="flex items-center justify-around py-2 border-t border-[#2d333b] pt-4 mt-2">
            {marketInfo.indices.map((idx, i) => (
              <div key={i} className="flex items-center gap-2 text-[11px]">
                <span className="font-semibold text-gray-400">{idx.name}</span>
                <span className="font-mono text-gray-300">{idx.value.toLocaleString()}</span>
                <span className={`${idx.changeRate > 0 ? 'text-green-500' : idx.changeRate < 0 ? 'text-red-400' : 'text-gray-500'}`}>
                  {idx.changeRate > 0 ? '▲' : idx.changeRate < 0 ? '▼' : ''} {Math.abs(idx.changeRate)}%
                </span>
              </div>
            ))}
          </div>
        )}

        {marketInfo?.warnings.map((w, i) => (
          <div key={i} className={`text-sm p-3 rounded mt-2 border ${w.type === 'error' ? 'bg-red-900/20 border-red-800/50 text-red-400' : 'bg-yellow-900/20 border-yellow-800/50 text-yellow-400'}`}>
            <span className="mr-2">⚠️</span>{w.message}
          </div>
        ))}
      </section>

      {/* 3. Stock Candidates List */}
      <section>
        <h2 className="text-lg font-bold mb-3 flex items-center justify-between">
          <span>오늘의 종가 전략 후보 Top 15</span>
          <span className="text-xs font-normal text-color-muted">스코어 순 정렬</span>
        </h2>

        {/* Table Header Match */}
        <div className="flex items-center justify-between text-[11px] text-[#6b7280] px-4 py-2 bg-[#1c2128] border-b border-[#2d333b] rounded-t">
          <div className="flex items-center gap-10">
            <span className="w-6 text-center">#</span>
            <span className="w-32">종목명</span>
          </div>
          <div className="flex items-center justify-end gap-10 flex-1">
            <span className="w-16 text-center">상태</span>
            <span className="w-20 text-right">점수</span>
            <span className="w-20 text-right">등락률</span>
            <span className="w-12 text-center">액션</span>
          </div>
        </div>

        <div className="flex flex-col gap-1 rounded-b overflow-hidden border border-t-0 border-color-card-border">
          {candidates.map((cand) => (
            <div key={cand.code} className="bg-[#121820] border-b border-[#2d333b] last:border-0 overflow-hidden">
              {/* List Row */}
              <div
                className="p-3 flex items-center justify-between cursor-pointer hover:bg-white/[0.02] transition-colors"
                onClick={() => toggleExpand(cand.code)}
              >
                <div className="flex items-center gap-10">
                  <div className={`w-6 text-center text-[13px] font-bold ${cand.rank <= 3 ? 'text-[#3b82f6]' : 'text-[#9ca3af]'}`}>
                    {cand.rank}
                  </div>
                  <div className="w-32">
                    <div className="font-semibold text-[14px] flex items-center gap-2">
                      <span className="bg-[#1f2937] text-[#9ca3af] rounded text-[10px] w-[18px] h-[18px] flex items-center justify-center font-normal border border-[#374151]">
                        {cand.tags[0]?.[0] || '모'}
                      </span>
                      {cand.name}
                    </div>
                    <div className="text-[10px] text-[#6b7280] mt-0.5">{cand.price.toLocaleString()} · {cand.code}</div>
                  </div>
                </div>

                <div className="flex items-center justify-end gap-10 flex-1">
                  {/* Status Indicator */}
                  <div className="w-16 text-center text-[11px] font-medium text-[#9ca3af] bg-[#1f2937]/50 rounded px-1 py-0.5 border border-[#374151]/50">
                    {cand.tags[0] || '-'}
                  </div>

                  {/* Score */}
                  <div className="w-20 text-right font-medium text-[#60a5fa] text-[13px]">{cand.score.toFixed(1)}</div>

                  {/* Change Rate */}
                  <div className={`w-20 text-right text-[13px] font-medium ${cand.changeRate > 0 ? 'text-[#ef4444]' : cand.changeRate < 0 ? 'text-[#3b82f6]' : 'text-gray-400'}`}>
                    {cand.changeRate > 0 ? '+' : ''}{cand.changeRate}%
                  </div>

                  {/* Action */}
                  <div className="w-12 text-center">
                    <div className="inline-flex items-center justify-center w-6 h-6 rounded border border-[#374151] text-[#9ca3af] hover:text-white hover:bg-[#374151] transition-colors relative">
                      {expandedRow === cand.code ? 'v' : '>'}
                    </div>
                  </div>
                </div>
              </div>

              {/* Expanded Details */}
              {expandedRow === cand.code && (
                <div className="bg-[#1c2128] p-5 border-t border-[#2a313a] text-sm flex flex-col gap-5">
                  <div className="text-[13px] text-gray-300 bg-black/30 p-4 rounded-lg border border-white/5 leading-relaxed">
                    <span className="text-blue-400 font-bold mr-2">AI Summary</span>
                    {cand.summary}
                    {detailData[cand.code] && (
                      <span className="ml-2 text-gray-400">{detailData[cand.code].signals[0]?.message}</span>
                    )}
                  </div>

                  <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
                    {/* Left: Progress Bars (Scores) */}
                    <div className="lg:col-span-4 flex flex-col gap-4 justify-center">
                      <ProgressBar label="수익성 팩터 (MACD/RSI/MA)" score={cand.details.return} colorClass="bg-blue-500" />
                      <ProgressBar label="안정성 팩터 (MDD/변동성)" score={cand.details.stability} colorClass="bg-blue-500" />
                      <ProgressBar label="시장성 팩터 (절대거래대금)" score={cand.details.market} colorClass="bg-blue-500" />
                    </div>

                    {/* Right: Stock Detail Data (4-box Grid) */}
                    <div className="lg:col-span-8">
                      {detailData[cand.code] ? (
                        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
                          <div className="bg-[#1c2128]/50 rounded-lg p-3 border border-[#2d333b]/50">
                            <div className="text-[11px] text-[#9ca3af] mb-1 flex items-center gap-1">
                              <div className="w-1.5 h-1.5 rounded-full bg-blue-500"></div> 현재가 / 60일 고가
                            </div>
                            <div className="font-mono text-[13px] mt-1">
                              <span className="text-white font-bold text-[14px]">{detailData[cand.code].currentPrice.toLocaleString()}원</span>
                              <br /><span className="text-[#6b7280] text-[10px]">Max: {detailData[cand.code].high60.toLocaleString()}원</span>
                            </div>
                          </div>

                          <div className="bg-[#1c2128]/50 rounded-lg p-3 border border-[#2d333b]/50">
                            <div className="text-[11px] text-[#9ca3af] mb-1 flex items-center gap-1">
                              <div className="w-1.5 h-1.5 rounded-full bg-green-500"></div> 기대수익 <span className="text-[10px] text-[#6b7280]">(목표가 도달 시)</span>
                            </div>
                            <div className="font-mono text-[13px] mt-1">
                              <span className="text-[#22c55e] font-bold text-[14px]">+{detailData[expandedRow].expectedReturn}%</span>
                              <br /><span className="text-[#6b7280] text-[10px]">수익 창출 구간</span>
                            </div>
                          </div>

                          <div className="bg-[#1c2128]/50 rounded-lg p-3 border border-yellow-900/20">
                            <div className="text-[11px] text-[#9ca3af] mb-1 flex items-center gap-1">
                              <div className="w-1.5 h-1.5 rounded-full bg-yellow-500"></div> 목표액 <span className="text-[10px] text-[#6b7280]">(Target Price)</span>
                            </div>
                            <div className="font-mono text-[13px] mt-1">
                              <span className="text-[#eab308] font-bold text-[14px]">{detailData[cand.code].targetPrice.toLocaleString()}원</span>
                              <br /><span className="text-[#6b7280] text-[10px]">ATR 기반 동적 계산</span>
                            </div>
                          </div>

                          <div className="bg-[#1c2128]/50 rounded-lg p-3 border border-red-900/20">
                            <div className="text-[11px] text-[#9ca3af] mb-1 flex items-center gap-1">
                              <div className="w-1.5 h-1.5 rounded-full bg-red-500"></div> 손절액 <span className="text-[10px] text-[#6b7280]">(Stop Loss)</span>
                            </div>
                            <div className="font-mono text-[13px] mt-1">
                              <span className="text-[#ef4444] font-bold text-[14px]">{detailData[cand.code].stopLoss.toLocaleString()}원</span>
                              <br /><span className="text-[#6b7280] text-[10px]">리스크 한도</span>
                            </div>
                          </div>
                        </div>
                      ) : (
                        <div className="h-full min-h-[80px] flex items-center justify-center border border-[#2d333b] rounded-lg bg-[#15191e]">
                          <span className="text-xs text-color-muted animate-pulse">상세 데이터 분석 중...</span>
                        </div>
                      )}
                    </div>
                  </div>
                  {/* Tags */}
                  {detailData[cand.code] && detailData[cand.code].tags?.length > 0 && (
                    <div className="flex gap-2">
                      {detailData[cand.code].tags.map(t => (
                        <span key={t} className="bg-gray-800 text-gray-300 px-2 py-1 rounded text-[10px] border border-gray-700">{t}</span>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      </section>

      {/* 4. Insight Summary */}
      {insight && (
        <section className="bg-gradient-to-br from-gray-900 to-black border border-gray-800 rounded-lg p-5">
          <h2 className="text-base font-bold mb-4 flex items-center gap-2">
            <span>🧠</span> 데이터 기반 전략 결론
          </h2>

          <div className="flex flex-col gap-4">
            <div className="bg-black/40 rounded p-4 border border-white/5">
              <h3 className="text-xs font-semibold text-gray-400 uppercase mb-2">실시간 시장 위험요소 (Risk Factors)</h3>
              <ul className="list-disc list-inside text-sm text-gray-300 space-y-1">
                {insight.riskFactors.map(rf => (
                  <li key={rf.id}>{rf.description}</li>
                ))}
              </ul>
            </div>

            <div className="bg-blue-950/20 rounded p-4 border border-blue-900/30">
              <h3 className="text-xs font-semibold text-blue-400 uppercase mb-2">Conclusion (AI 투자 전략 요약)</h3>
              <p className="text-sm leading-relaxed text-blue-100">
                {insight.conclusion}
              </p>
            </div>
          </div>
        </section>
      )}

    </main>
  );
}
