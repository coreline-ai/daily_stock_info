"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

import Sparkline from "@/components/Sparkline";
import type { MarketInsight, MarketOverview, StockCandidate, StockDetail, StrategyKind, StrategyStatus } from "@/lib/types";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";
const USER_KEY = "default";
const DEFAULT_WEIGHTS = { return: 0.4, stability: 0.3, market: 0.3 };

const PRESETS = {
  Balanced: { return: 0.4, stability: 0.3, market: 0.3 },
  Aggressive: { return: 0.6, stability: 0.2, market: 0.2 },
  Defensive: { return: 0.2, stability: 0.6, market: 0.2 },
};

const STRATEGY_LABEL: Record<StrategyKind, string> = {
  premarket: "장전 전략",
  intraday: "장중 단타",
  close: "종가 전략",
};

function asFiniteNumber(value: unknown, fallback: number) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizeWeights(values: { return: number; stability: number; market: number }) {
  const total = values.return + values.stability + values.market;
  if (total <= 0) return DEFAULT_WEIGHTS;
  return {
    return: Number((values.return / total).toFixed(4)),
    stability: Number((values.stability / total).toFixed(4)),
    market: Number((values.market / total).toFixed(4)),
  };
}

function parseTickers(raw: string): string[] {
  return raw
    .split(",")
    .map((t) => t.trim().toUpperCase())
    .filter(Boolean);
}

function toCandidateArray(payload: unknown): StockCandidate[] {
  if (Array.isArray(payload)) {
    return payload as StockCandidate[];
  }
  if (payload && typeof payload === "object") {
    const nested = (payload as { candidates?: unknown }).candidates;
    if (Array.isArray(nested)) {
      return nested as StockCandidate[];
    }
  }
  return [];
}

function sanitizeWeights(values: Partial<{ return: unknown; stability: unknown; market: unknown }> | null | undefined) {
  return normalizeWeights({
    return: Math.max(0, asFiniteNumber(values?.return, DEFAULT_WEIGHTS.return)),
    stability: Math.max(0, asFiniteNumber(values?.stability, DEFAULT_WEIGHTS.stability)),
    market: Math.max(0, asFiniteNumber(values?.market, DEFAULT_WEIGHTS.market)),
  });
}

function deriveOverviewCounts(candidates: StockCandidate[]) {
  const up = candidates.filter((candidate) => Number(candidate.changeRate ?? 0) > 0).length;
  const down = candidates.filter((candidate) => Number(candidate.changeRate ?? 0) < 0).length;
  return { up, down, steady: Math.max(0, candidates.length - up - down) };
}

function getTodayInKstIsoDate(): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = formatter.formatToParts(new Date());
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;
  if (!year || !month || !day) {
    return new Date().toISOString().split("T")[0];
  }
  return `${year}-${month}-${day}`;
}

function detailKey(code: string, strategy: StrategyKind): string {
  return `${strategy}:${code}`;
}

async function readApiError(response: Response): Promise<string> {
  const fallback = `API 요청 실패 (${response.status})`;
  try {
    const payload = (await response.json()) as {
      detail?: string | { message?: string };
      message?: string;
    };
    if (payload?.detail && typeof payload.detail === "string") {
      return payload.detail;
    }
    if (payload?.detail && typeof payload.detail === "object" && typeof payload.detail.message === "string") {
      return payload.detail.message;
    }
    if (payload?.message && typeof payload.message === "string") {
      return payload.message;
    }
  } catch {
    // ignore parse errors and use fallback text
  }
  return fallback;
}

const ProgressBar = ({ label, score, colorClass }: { label: string; score: number; colorClass: string }) => {
  const percentage = (score / 10) * 100;
  return (
    <div className="flex flex-col gap-1 w-full text-xs">
      <div className="flex justify-between text-color-muted">
        <span>{label}</span>
        <span className="font-semibold text-white">{score.toFixed(2)}</span>
      </div>
      <div className="h-1.5 w-full bg-color-progress rounded-full overflow-hidden">
        <div className={`h-full ${colorClass}`} style={{ width: `${Math.max(0, Math.min(100, percentage))}%` }} />
      </div>
    </div>
  );
};

export default function Home() {
  const today = useMemo(() => getTodayInKstIsoDate(), []);
  const [selectedDate, setSelectedDate] = useState(today);
  const [effectiveDate, setEffectiveDate] = useState(today);
  const [strategyStatus, setStrategyStatus] = useState<StrategyStatus | null>(null);
  const [selectedStrategy, setSelectedStrategy] = useState<StrategyKind | null>(null);

  const [weights, setWeights] = useState(DEFAULT_WEIGHTS);
  const [autoRegimeWeights, setAutoRegimeWeights] = useState(true);
  const [enforceExposureCap, setEnforceExposureCap] = useState(true);
  const [maxPerSector, setMaxPerSector] = useState(2);

  const [watchlist, setWatchlist] = useState<string[]>([]);
  const [watchlistInput, setWatchlistInput] = useState("");
  const [watchlistCsv, setWatchlistCsv] = useState<File | null>(null);
  const [watchlistCsvReplace, setWatchlistCsvReplace] = useState(false);
  const [customInput, setCustomInput] = useState("");

  const [marketInfo, setMarketInfo] = useState<MarketOverview | null>(null);
  const [candidates, setCandidates] = useState<StockCandidate[]>([]);
  const [intradayExtraCandidates, setIntradayExtraCandidates] = useState<StockCandidate[]>([]);
  const [showIntradayExtra, setShowIntradayExtra] = useState(true);
  const [intradayExtraError, setIntradayExtraError] = useState<string | null>(null);
  const [insight, setInsight] = useState<MarketInsight | null>(null);
  const [expandedRow, setExpandedRow] = useState<string | null>(null);
  const [detailData, setDetailData] = useState<Record<string, StockDetail>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const safeCandidates = (Array.isArray(candidates) ? candidates : []).filter(
    (candidate): candidate is StockCandidate => !!candidate && typeof candidate === "object",
  );
  const safeIntradayExtraCandidates = (Array.isArray(intradayExtraCandidates) ? intradayExtraCandidates : []).filter(
    (candidate): candidate is StockCandidate => !!candidate && typeof candidate === "object",
  );
  const safeWeights = sanitizeWeights(weights);

  const resolvedCustomTickers = useMemo(() => {
    const adhoc = parseTickers(customInput);
    return Array.from(new Set([...watchlist, ...adhoc]));
  }, [watchlist, customInput]);
  const customTickersQuery = useMemo(() => resolvedCustomTickers.join(","), [resolvedCustomTickers]);
  const availableStrategies = strategyStatus?.availableStrategies ?? [];
  const intradayAvailable = availableStrategies.includes("intraday");
  const strategyMessage = selectedStrategy
    ? strategyStatus?.messages?.[selectedStrategy] ?? ""
    : strategyStatus?.detail ?? strategyStatus?.messages?.premarket ?? strategyStatus?.messages?.intraday ?? strategyStatus?.messages?.close ?? "";
  const nonTradingDay = strategyStatus?.errorCode === "NON_TRADING_DAY" ? strategyStatus?.nonTradingDay ?? null : null;
  const shouldLoadIntradayExtra = Boolean(showIntradayExtra && intradayAvailable && selectedStrategy !== "intraday");

  const fetchWatchlist = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/watchlist?user_key=${USER_KEY}`);
      if (!res.ok) throw new Error("워치리스트 조회에 실패했습니다.");
      const payload = (await res.json()) as { tickers: string[] };
      setWatchlist(payload.tickers ?? []);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchWatchlist();
  }, []);

  useEffect(() => {
    let mounted = true;

    async function refreshStrategyStatus() {
      try {
        const res = await fetch(`${API_BASE}/api/v1/strategy-status?date=${selectedDate}`);
        if (!res.ok) throw new Error(await readApiError(res));
        const status = (await res.json()) as StrategyStatus;
        if (!mounted) return;
        setStrategyStatus(status);
        setSelectedStrategy((prev) => {
          if (prev && (status.availableStrategies ?? []).includes(prev)) {
            return prev;
          }
          return status.defaultStrategy ?? null;
        });
      } catch (statusError) {
        console.error(statusError);
        if (!mounted) return;
        setStrategyStatus(null);
        setSelectedStrategy(null);
        setError(statusError instanceof Error ? statusError.message : "전략 상태 조회에 실패했습니다.");
      }
    }

    refreshStrategyStatus();
    const timer = window.setInterval(refreshStrategyStatus, 60_000);
    return () => {
      mounted = false;
      window.clearInterval(timer);
    };
  }, [selectedDate]);

  useEffect(() => {
    setDetailData({});
    setExpandedRow(null);
    setIntradayExtraCandidates([]);
    setIntradayExtraError(null);
  }, [
    selectedDate,
    selectedStrategy,
    safeWeights.return,
    safeWeights.stability,
    safeWeights.market,
    autoRegimeWeights,
    enforceExposureCap,
    maxPerSector,
    customTickersQuery,
    showIntradayExtra,
  ]);

  useEffect(() => {
    async function fetchData() {
      if (!selectedStrategy) {
        setLoading(false);
        setMarketInfo(null);
        setCandidates([]);
        setIntradayExtraCandidates([]);
        setIntradayExtraError(null);
        setInsight(null);
        setEffectiveDate(selectedDate);
        if (strategyStatus) {
          setError(
            strategyStatus.detail ??
              strategyStatus.messages?.premarket ??
              strategyStatus.messages?.intraday ??
              strategyStatus.messages?.close ??
              "조회 가능한 전략이 없습니다.",
          );
        }
        return;
      }

      setLoading(true);
      setError(null);
      setIntradayExtraError(null);
      try {
        const common = new URLSearchParams({
          date: selectedDate,
          strategy: selectedStrategy,
          w_return: String(safeWeights.return),
          w_stability: String(safeWeights.stability),
          w_market: String(safeWeights.market),
          user_key: USER_KEY,
          custom_tickers: customTickersQuery,
          auto_regime_weights: String(autoRegimeWeights),
          enforce_exposure_cap: String(enforceExposureCap),
          max_per_sector: String(maxPerSector),
          cap_top_n: "5",
        });

        const candidatesQuery = new URLSearchParams(common);
        candidatesQuery.set("include_sparkline", "true");

        const [overviewRes, candidatesRes, insightRes] = await Promise.all([
          fetch(`${API_BASE}/api/v1/market-overview?user_key=${USER_KEY}&date=${selectedDate}&custom_tickers=${customTickersQuery}&strategy=${selectedStrategy}`),
          fetch(`${API_BASE}/api/v1/stock-candidates?${candidatesQuery.toString()}`),
          fetch(`${API_BASE}/api/v1/market-insight?${common.toString()}`),
        ]);

        const failedResponse = [overviewRes, candidatesRes, insightRes].find((res) => !res.ok);
        if (failedResponse) {
          throw new Error(await readApiError(failedResponse));
        }

        const candsPayload = (await candidatesRes.json()) as unknown;
        const cands = toCandidateArray(candsPayload);
        const overviewJson = (await overviewRes.json()) as MarketOverview & { candidateCount?: number };
        const derived = deriveOverviewCounts(cands);
        const overviewTotal = Number(overviewJson?.up ?? 0) + Number(overviewJson?.down ?? 0) + Number(overviewJson?.steady ?? 0);
        const syncedOverview: MarketOverview =
          overviewTotal !== cands.length
            ? { ...overviewJson, up: derived.up, down: derived.down, steady: derived.steady }
            : overviewJson;

        setEffectiveDate(cands?.[0]?.sessionDate ?? cands?.[0]?.realDate ?? selectedDate);
        setMarketInfo(syncedOverview);
        setCandidates(cands);
        setInsight((await insightRes.json()) as MarketInsight);

        if (shouldLoadIntradayExtra) {
          const intradayQuery = new URLSearchParams(common);
          intradayQuery.set("strategy", "intraday");
          intradayQuery.set("include_sparkline", "true");
          const intradayRes = await fetch(`${API_BASE}/api/v1/stock-candidates?${intradayQuery.toString()}`);
          if (!intradayRes.ok) {
            setIntradayExtraCandidates([]);
            setIntradayExtraError(await readApiError(intradayRes));
          } else {
            const intradayPayload = (await intradayRes.json()) as unknown;
            setIntradayExtraCandidates(toCandidateArray(intradayPayload).slice(0, 5));
            setIntradayExtraError(null);
          }
        } else {
          setIntradayExtraCandidates([]);
          setIntradayExtraError(null);
        }
      } catch (fetchError) {
        console.error(fetchError);
        setMarketInfo(null);
        setCandidates([]);
        setIntradayExtraCandidates([]);
        setIntradayExtraError(null);
        setInsight(null);
        setEffectiveDate(selectedDate);
        setError(fetchError instanceof Error ? fetchError.message : "데이터를 불러오지 못했습니다.");
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [
    selectedDate,
    selectedStrategy,
    strategyStatus,
    safeWeights.return,
    safeWeights.stability,
    safeWeights.market,
    autoRegimeWeights,
    enforceExposureCap,
    maxPerSector,
    customTickersQuery,
    shouldLoadIntradayExtra,
  ]);

  const handleWeight = (key: "return" | "stability" | "market", value: number) => {
    setWeights((prev) => normalizeWeights({ ...sanitizeWeights(prev), [key]: value }));
  };

  const addWatchlist = async () => {
    const tickers = parseTickers(watchlistInput);
    if (tickers.length === 0) return;
    try {
      const res = await fetch(`${API_BASE}/api/v1/watchlist`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user_key: USER_KEY, tickers }),
      });
      if (!res.ok) throw new Error("워치리스트 업데이트에 실패했습니다.");
      const payload = (await res.json()) as { tickers: string[] };
      setWatchlist(payload.tickers ?? []);
      setWatchlistInput("");
    } catch (err) {
      console.error(err);
    }
  };

  const uploadWatchlistCsv = async () => {
    if (!watchlistCsv) return;
    const form = new FormData();
    form.append("file", watchlistCsv);
    form.append("user_key", USER_KEY);
    form.append("replace", String(watchlistCsvReplace));
    try {
      const res = await fetch(`${API_BASE}/api/v1/watchlist/upload-csv`, {
        method: "POST",
        body: form,
      });
      if (!res.ok) throw new Error("워치리스트 CSV 업로드에 실패했습니다.");
      const payload = (await res.json()) as { tickers: string[] };
      setWatchlist(payload.tickers ?? []);
      setWatchlistCsv(null);
    } catch (err) {
      console.error(err);
    }
  };

  const removeWatchlist = async (ticker: string) => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/watchlist/${ticker}?user_key=${USER_KEY}`, { method: "DELETE" });
      if (!res.ok) throw new Error("워치리스트 삭제에 실패했습니다.");
      const payload = (await res.json()) as { tickers: string[] };
      setWatchlist(payload.tickers ?? []);
    } catch (err) {
      console.error(err);
    }
  };

  const applyRecommendedWeights = () => {
    const suggested = marketInfo?.regimeRecommendation?.suggestedWeights;
    if (!suggested) return;
    setWeights(sanitizeWeights(suggested));
    setAutoRegimeWeights(false);
  };

  const toggleExpand = async (code: string, strategy: StrategyKind) => {
    if (!strategy) {
      return;
    }
    const key = detailKey(code, strategy);
    if (expandedRow === key) {
      setExpandedRow(null);
      return;
    }
    setExpandedRow(key);
    if (!detailData[key]) {
      const q = new URLSearchParams({
        date: selectedDate,
        strategy,
        w_return: String(safeWeights.return),
        w_stability: String(safeWeights.stability),
        w_market: String(safeWeights.market),
        include_news: "true",
        include_ai: "true",
        user_key: USER_KEY,
        custom_tickers: customTickersQuery,
        auto_regime_weights: String(autoRegimeWeights),
      }).toString();
      try {
        const res = await fetch(`${API_BASE}/api/v1/stocks/${code}/detail?${q}`);
        if (!res.ok) throw new Error("detail fetch failed");
        const data = (await res.json()) as StockDetail;
        setDetailData((prev) => ({ ...prev, [key]: data }));
      } catch (detailError) {
        console.error(detailError);
      }
    }
  };

  return (
    <main className="max-w-6xl mx-auto p-4 md:p-6 pb-20 space-y-6">
      <header className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold flex items-center gap-2">
              <span className="text-blue-400">📈</span>
              DailyStock AI
            </h1>
            <p className="text-color-muted text-sm mt-1">국면 감지, 섹터 캡, 신뢰도, 워치리스트</p>
          </div>
          <div className="flex items-center gap-3">
            <input
              type="date"
              value={selectedDate ?? ""}
              max={today}
              onChange={(e) => setSelectedDate(e.target.value)}
              className="bg-color-card border border-color-card-border rounded px-3 py-1.5 text-white"
            />
            <div className="flex items-center gap-1 rounded border border-[#334155] bg-[#0f172a] p-1">
              {(Object.keys(STRATEGY_LABEL) as StrategyKind[]).map((strategyKey) => {
                const isAvailable = availableStrategies.includes(strategyKey);
                const isActive = selectedStrategy === strategyKey;
                return (
                  <button
                    key={strategyKey}
                    type="button"
                    disabled={!isAvailable}
                    title={strategyStatus?.messages?.[strategyKey] ?? ""}
                    onClick={() => setSelectedStrategy(strategyKey)}
                    className={`px-2.5 py-1 text-xs rounded ${
                      isActive ? "bg-[#2563eb] text-white" : "bg-[#1e293b] text-slate-200"
                    } ${!isAvailable ? "opacity-40 cursor-not-allowed" : "hover:bg-[#334155]"}`}
                  >
                    {STRATEGY_LABEL[strategyKey]}
                  </button>
                );
              })}
            </div>
            <Link href="/history" className="bg-[#123a66] hover:bg-[#1b4f88] rounded px-3 py-1.5 text-sm">
              백테스트 히스토리
            </Link>
          </div>
        </div>
        <div className="text-xs text-color-muted">
          {selectedStrategy ? `활성 전략: ${STRATEGY_LABEL[selectedStrategy]}` : "활성 전략: 없음"}
          {strategyMessage ? ` | ${strategyMessage}` : ""}
        </div>
        {nonTradingDay && (
          <div className="text-xs rounded border border-amber-700/40 bg-amber-950/30 p-2 text-amber-200">
            비거래일 사유: {nonTradingDay.reason}
            {nonTradingDay.holidayName ? ` | 휴일명: ${nonTradingDay.holidayName}` : ""}
            {nonTradingDay.calendarProvider ? ` | 캘린더: ${nonTradingDay.calendarProvider}` : ""}
          </div>
        )}
        {showIntradayExtra && !intradayAvailable && (
          <div className="text-xs rounded border border-sky-700/40 bg-sky-950/30 p-2 text-sky-200">
            장중 단타 추가 추천은 당일 장중(09:05~15:20 KST)에만 노출됩니다.
          </div>
        )}
        {showIntradayExtra && intradayExtraError && (
          <div className="text-xs rounded border border-red-700/40 bg-red-950/30 p-2 text-red-200">
            장중 단타 추가 추천 로드 실패: {intradayExtraError}
          </div>
        )}

        <section className="bg-color-card border border-color-card-border rounded-lg p-4 space-y-3">
          <div className="flex flex-wrap items-center gap-2">
            <strong className="text-sm">가중치 프리셋</strong>
            {(Object.keys(PRESETS) as Array<keyof typeof PRESETS>).map((key) => (
              <button
                key={key}
                className="px-2.5 py-1 text-xs rounded bg-[#1e293b] border border-[#334155] hover:bg-[#334155]"
                onClick={() => setWeights(PRESETS[key])}
                disabled={autoRegimeWeights}
              >
                {key}
              </button>
            ))}
            <label className="ml-2 text-xs flex items-center gap-1">
              <input type="checkbox" checked={Boolean(autoRegimeWeights)} onChange={(e) => setAutoRegimeWeights(e.target.checked)} />
              국면 자동 가중치
            </label>
            <span className="text-xs text-color-muted ml-auto">적용일: {effectiveDate}</span>
          </div>

          <div className="grid md:grid-cols-3 gap-3">
            <label className="text-xs space-y-1">
              <span>수익성 {safeWeights.return.toFixed(2)}</span>
              <input type="range" min={0} max={1} step={0.01} value={safeWeights.return} onChange={(e) => handleWeight("return", Number(e.target.value))} className="w-full" disabled={Boolean(autoRegimeWeights)} />
            </label>
            <label className="text-xs space-y-1">
              <span>안정성 {safeWeights.stability.toFixed(2)}</span>
              <input type="range" min={0} max={1} step={0.01} value={safeWeights.stability} onChange={(e) => handleWeight("stability", Number(e.target.value))} className="w-full" disabled={Boolean(autoRegimeWeights)} />
            </label>
            <label className="text-xs space-y-1">
              <span>시장성 {safeWeights.market.toFixed(2)}</span>
              <input type="range" min={0} max={1} step={0.01} value={safeWeights.market} onChange={(e) => handleWeight("market", Number(e.target.value))} className="w-full" disabled={Boolean(autoRegimeWeights)} />
            </label>
          </div>

          <div className="flex flex-wrap items-center gap-3 text-xs">
            <label className="flex items-center gap-1">
              <input type="checkbox" checked={Boolean(enforceExposureCap)} onChange={(e) => setEnforceExposureCap(e.target.checked)} />
              Top5 섹터 노출 한도 적용
            </label>
            <label className="flex items-center gap-1">
              섹터별 최대
              <select value={asFiniteNumber(maxPerSector, 2)} onChange={(e) => setMaxPerSector(Number(e.target.value))} className="bg-[#0f172a] border border-[#334155] rounded px-1 py-0.5">
                <option value={1}>1</option>
                <option value={2}>2</option>
                <option value={3}>3</option>
              </select>
            </label>
            <label className="flex items-center gap-1">
              <input type="checkbox" checked={Boolean(showIntradayExtra)} onChange={(e) => setShowIntradayExtra(e.target.checked)} />
              장중 단타 추가 추천 표시
            </label>
          </div>
        </section>

        <section className="bg-color-card border border-color-card-border rounded-lg p-4 space-y-2">
          <h3 className="text-sm font-semibold">워치리스트 / 커스텀 티커</h3>
          <div className="rounded border border-[#334155] bg-[#0f172a] p-3 text-xs text-color-muted space-y-1 leading-relaxed">
            <div>
              <strong className="text-white">워치리스트</strong>: 저장되는 목록입니다. 추가/삭제한 종목이 다음 조회에도 유지됩니다.
            </div>
            <div>
              <strong className="text-white">커스텀 티커</strong>: 현재 조회에만 임시 반영됩니다. 새로고침 후에는 저장되지 않습니다.
            </div>
            <div>
              <strong className="text-white">입력 형식</strong>: `005930`, `000660.KS`, `AAPL` (콤마 구분)
            </div>
            <div>
              <strong className="text-white">CSV 업로드</strong>: `ticker` 헤더를 사용하세요. `덮어쓰기`를 체크하면 기존 워치리스트를 교체합니다.
            </div>
          </div>
          <div className="flex gap-2">
            <input
              value={watchlistInput ?? ""}
              onChange={(e) => setWatchlistInput(e.target.value)}
              placeholder="예: 005930, 000660.KS, AAPL"
              className="flex-1 bg-[#0f172a] border border-[#334155] rounded px-3 py-1.5 text-sm"
            />
            <button onClick={addWatchlist} className="bg-[#1d4ed8] hover:bg-[#2563eb] rounded px-3 text-sm">
              워치리스트 추가
            </button>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <input
              type="file"
              accept=".csv,text/csv"
              onChange={(e) => setWatchlistCsv(e.target.files?.[0] ?? null)}
              className="text-xs"
            />
            <label className="text-xs flex items-center gap-1">
              <input type="checkbox" checked={Boolean(watchlistCsvReplace)} onChange={(e) => setWatchlistCsvReplace(e.target.checked)} />
              CSV로 기존 목록 덮어쓰기
            </label>
            <button onClick={uploadWatchlistCsv} className="bg-[#0ea5e9] hover:bg-[#0284c7] rounded px-2.5 py-1 text-xs">
              CSV 업로드
            </button>
          </div>
          <div className="flex gap-2 flex-wrap">
            {watchlist.map((ticker) => (
              <button
                key={ticker}
                onClick={() => removeWatchlist(ticker)}
                className="text-xs px-2 py-1 rounded bg-[#1e293b] border border-[#334155] hover:bg-[#334155]"
                title="클릭 시 제거"
              >
                {ticker} x
              </button>
            ))}
          </div>
          <input
            value={customInput ?? ""}
            onChange={(e) => setCustomInput(e.target.value)}
            placeholder="이번 조회에만 반영할 커스텀 티커 입력 (콤마 구분)"
            className="w-full bg-[#0f172a] border border-[#334155] rounded px-3 py-1.5 text-sm"
          />
        </section>
      </header>

      {error && <div className="rounded border border-red-900 bg-red-950/40 p-3 text-red-300 text-sm">{error}</div>}

      {loading ? (
        <div className="animate-pulse text-color-muted">로딩 중...</div>
      ) : (
        <>
          <section className="bg-color-card border border-color-card-border rounded-lg p-4 space-y-3">
            <h2 className="text-sm font-semibold">시장 개요</h2>
            <div className="grid grid-cols-3 gap-3 text-center">
              <div className="bg-[#1c2128] rounded p-3">
                <div className="text-red-400 text-2xl font-bold">{marketInfo?.down ?? 0}</div>
                <div className="text-xs text-color-muted">하락</div>
              </div>
              <div className="bg-[#1c2128] rounded p-3">
                <div className="text-gray-300 text-2xl font-bold">{marketInfo?.steady ?? 0}</div>
                <div className="text-xs text-color-muted">보합</div>
              </div>
              <div className="bg-[#1c2128] rounded p-3">
                <div className="text-green-500 text-2xl font-bold">{marketInfo?.up ?? 0}</div>
                <div className="text-xs text-color-muted">상승</div>
              </div>
            </div>
            <div className="flex flex-wrap gap-2 text-xs">
              {Array.isArray(marketInfo?.indices) &&
                marketInfo.indices.map((idx) => (
                <div key={idx.name} className="px-2 py-1 bg-[#0f172a] border border-[#1e293b] rounded">
                  {idx.name}: {idx.value.toLocaleString()} ({idx.changeRate > 0 ? "+" : ""}
                  {idx.changeRate}%)
                </div>
              ))}
            </div>
            {marketInfo?.regimeRecommendation && (
              <div className="bg-[#0f172a] border border-[#1e293b] rounded p-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="text-sm">
                    국면: <strong>{marketInfo.regimeRecommendation.label}</strong> (신뢰도 {marketInfo.regimeRecommendation.confidence}%)
                  </div>
                  <button onClick={applyRecommendedWeights} className="px-2.5 py-1 rounded bg-[#2563eb] hover:bg-[#3b82f6] text-xs">
                    추천 가중치 적용
                  </button>
                </div>
                <div className="text-xs text-color-muted mt-1">{marketInfo.regimeRecommendation.reason}</div>
                <div className="text-xs mt-1">
                  추천: R {marketInfo.regimeRecommendation.suggestedWeights.return} / S {marketInfo.regimeRecommendation.suggestedWeights.stability} / M {marketInfo.regimeRecommendation.suggestedWeights.market}
                </div>
              </div>
            )}
          </section>

          {showIntradayExtra && safeIntradayExtraCandidates.length > 0 && (
            <section>
              <h2 className="text-lg font-bold mb-2">장중 단타 추가 추천</h2>
              <div className="border border-color-card-border rounded overflow-hidden">
                <div className="grid grid-cols-[40px_1fr_90px_90px_110px_90px_44px] gap-2 px-3 py-2 text-xs bg-[#1c2128] text-color-muted">
                  <span>#</span>
                  <span>종목</span>
                  <span className="text-right">점수</span>
                  <span className="text-right">등락률</span>
                  <span className="text-center">섹터</span>
                  <span className="text-center">스파크</span>
                  <span />
                </div>
                {safeIntradayExtraCandidates.map((cand, idx) => {
                  const rowStrategy: StrategyKind = "intraday";
                  const rowKey = detailKey(cand.code, rowStrategy);
                  const detail = detailData[rowKey];
                  const score = Number(cand.score ?? 0);
                  const changeRate = Number(cand.changeRate ?? 0);
                  const price = Number(cand.price ?? 0);
                  const targetPrice = Number(cand.targetPrice ?? 0);
                  const stopLoss = Number(cand.stopLoss ?? 0);
                  const rawReturn = Number(cand.details?.raw?.return ?? 0);
                  const rawStability = Number(cand.details?.raw?.stability ?? 0);
                  const rawMarket = Number(cand.details?.raw?.market ?? 0);
                  const weightedReturn = Number(cand.details?.weighted?.return ?? 0);
                  const weightedStability = Number(cand.details?.weighted?.stability ?? 0);
                  const weightedMarket = Number(cand.details?.weighted?.market ?? 0);
                  return (
                    <div key={`intraday-${cand.code}-${cand.rank ?? idx}`} className="border-t border-[#2d333b] bg-[#111827]">
                      <button
                        className="w-full grid grid-cols-[40px_1fr_90px_90px_110px_90px_44px] gap-2 px-3 py-3 items-center text-left hover:bg-white/5"
                        onClick={() => toggleExpand(cand.code, rowStrategy)}
                      >
                        <span className="text-sm font-bold text-blue-300">{cand.rank}</span>
                        <span>
                          <div className="font-semibold">{cand.name}</div>
                          <div className="text-xs text-color-muted">{cand.code}</div>
                        </span>
                        <span className="text-right text-sky-300">{score.toFixed(1)}</span>
                        <span className={`text-right ${changeRate > 0 ? "text-red-400" : changeRate < 0 ? "text-blue-400" : "text-gray-400"}`}>
                          {changeRate > 0 ? "+" : ""}
                          {changeRate}%
                        </span>
                        <span className="text-center text-xs">
                          <span className="px-2 py-1 rounded bg-[#1e293b] border border-[#334155]">{cand.sector ?? "-"}</span>
                          {cand.exposureDeferred && <span className="block text-[10px] text-amber-300 mt-1">캡 적용</span>}
                        </span>
                        <span className="flex justify-center">
                          <Sparkline points={cand.sparkline60} />
                        </span>
                        <span className="text-center text-color-muted">{expandedRow === rowKey ? "v" : ">"}</span>
                      </button>

                      {expandedRow === rowKey && (
                        <div className="px-4 pb-4 grid gap-4">
                          <div className="text-sm bg-black/30 rounded p-3 border border-white/10">
                            <strong className="text-blue-300">AI 요약</strong> {detail?.aiReport?.summary ?? cand.summary}
                          </div>
                          <div className="grid md:grid-cols-2 gap-4">
                            <div className="space-y-2">
                              <ProgressBar label="Raw Return" score={rawReturn} colorClass="bg-blue-500" />
                              <ProgressBar label="Raw Stability" score={rawStability} colorClass="bg-emerald-500" />
                              <ProgressBar label="Raw Market" score={rawMarket} colorClass="bg-amber-500" />
                            </div>
                            <div className="bg-[#1f2937]/50 rounded p-3 text-sm space-y-1 border border-[#334155]">
                              <div>현재가: {detail?.currentPrice?.toLocaleString() ?? price.toLocaleString()} KRW</div>
                              <div>목표가: {detail?.targetPrice?.toLocaleString() ?? targetPrice.toLocaleString()} KRW</div>
                              <div>손절가: {detail?.stopLoss?.toLocaleString() ?? stopLoss.toLocaleString()} KRW</div>
                              <div>예상 수익률: {detail?.expectedReturn ?? 0}%</div>
                              <div>섹터: {detail?.sector ?? cand.sector ?? "-"}</div>
                              <div className="text-xs text-color-muted">
                                가중 점수: R {weightedReturn.toFixed(2)} / S {weightedStability.toFixed(2)} / M {weightedMarket.toFixed(2)}
                              </div>
                              {cand.details?.intradaySignals && (
                                <div className="text-xs text-color-muted border border-[#334155] rounded p-2 bg-[#0b1220]">
                                  <div>장중 모드: {cand.details.intradaySignals.mode}</div>
                                  <div>ORB: {Number(cand.details.intradaySignals.orbProxyScore ?? 0).toFixed(2)}</div>
                                  <div>VWAP: {Number(cand.details.intradaySignals.vwapProxyScore ?? 0).toFixed(2)}</div>
                                  <div>RVOL: {Number(cand.details.intradaySignals.rvolScore ?? 0).toFixed(2)}</div>
                                </div>
                              )}
                              {detail?.positionSizing && (
                                <div className="text-xs mt-2 border border-[#334155] rounded p-2 bg-[#111827]">
                                  <div>매수 수량: {detail.positionSizing.shares.toLocaleString()}</div>
                                  <div>필요 자금: {detail.positionSizing.capitalRequired.toLocaleString()} KRW</div>
                                  <div>위험 금액: {detail.positionSizing.riskAmount.toLocaleString()} KRW</div>
                                </div>
                              )}
                            </div>
                          </div>

                          <div className="grid md:grid-cols-2 gap-4">
                            <div className="bg-[#0f172a] p-3 rounded border border-[#1e293b]">
                              <h3 className="text-xs text-color-muted mb-2">주요 뉴스 3줄</h3>
                              <ul className="text-sm space-y-1 list-disc list-inside">
                                {(detail?.newsSummary3 ?? ["뉴스를 불러오는 중...", "", ""]).map((line, i) => (
                                  <li key={`${cand.code}-intraday-summary-${i}`}>{line}</li>
                                ))}
                              </ul>
                              <div className="flex gap-2 mt-2 flex-wrap">
                                {(detail?.themes ?? []).map((theme) => (
                                  <span key={`${cand.code}-intraday-theme-${theme}`} className="text-xs px-2 py-1 rounded bg-[#1e293b] border border-[#334155]">
                                    #{theme}
                                  </span>
                                ))}
                              </div>
                            </div>
                            <div className="bg-[#0f172a] p-3 rounded border border-[#1e293b]">
                              <h3 className="text-xs text-color-muted mb-2">LLM 결론</h3>
                              <p className="text-sm">{detail?.aiReport?.conclusion ?? "리포트 생성 중..."}</p>
                              <ul className="mt-2 text-xs list-disc list-inside text-color-muted">
                                {(detail?.aiReport?.riskFactors ?? []).map((rf) => (
                                  <li key={`${cand.code}-intraday-${rf.id}`}>{rf.description}</li>
                                ))}
                              </ul>
                              {detail?.aiReport?.confidence && (
                                <div className="mt-2 text-xs border border-[#334155] rounded p-2 bg-[#111827]">
                                  <div>신뢰도: {detail.aiReport.confidence.score} ({detail.aiReport.confidence.level})</div>
                                  {(Array.isArray(detail.aiReport.confidence.warnings) ? detail.aiReport.confidence.warnings : []).map((w, idx2) => (
                                    <div key={`${cand.code}-intraday-warn-${idx2}`} className="text-amber-300">- {w}</div>
                                  ))}
                                </div>
                              )}
                              {detail?.aiReport?.fallbackReason && (
                                <div className="mt-2 text-xs text-amber-200">대체 문구 사용: {detail.aiReport.fallbackReason}</div>
                              )}
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </section>
          )}

          <section>
            <h2 className="text-lg font-bold mb-2">
              추천 종목 {selectedStrategy ? `(${STRATEGY_LABEL[selectedStrategy]})` : ""}
            </h2>
            <div className="border border-color-card-border rounded overflow-hidden">
              <div className="grid grid-cols-[40px_1fr_90px_90px_110px_90px_44px] gap-2 px-3 py-2 text-xs bg-[#1c2128] text-color-muted">
                <span>#</span>
                <span>종목</span>
                <span className="text-right">점수</span>
                <span className="text-right">등락률</span>
                <span className="text-center">섹터</span>
                <span className="text-center">스파크</span>
                <span />
              </div>
              {safeCandidates.map((cand, idx) => {
                const rowStrategy = (cand.strategy ?? selectedStrategy ?? "close") as StrategyKind;
                const rowKey = detailKey(cand.code, rowStrategy);
                const detail = detailData[rowKey];
                const score = Number(cand.score ?? 0);
                const changeRate = Number(cand.changeRate ?? 0);
                const price = Number(cand.price ?? 0);
                const targetPrice = Number(cand.targetPrice ?? 0);
                const stopLoss = Number(cand.stopLoss ?? 0);
                const rawReturn = Number(cand.details?.raw?.return ?? 0);
                const rawStability = Number(cand.details?.raw?.stability ?? 0);
                const rawMarket = Number(cand.details?.raw?.market ?? 0);
                const weightedReturn = Number(cand.details?.weighted?.return ?? 0);
                const weightedStability = Number(cand.details?.weighted?.stability ?? 0);
                const weightedMarket = Number(cand.details?.weighted?.market ?? 0);
                return (
                  <div key={`${cand.code}-${cand.rank ?? idx}`} className="border-t border-[#2d333b] bg-[#111827]">
                    <button className="w-full grid grid-cols-[40px_1fr_90px_90px_110px_90px_44px] gap-2 px-3 py-3 items-center text-left hover:bg-white/5" onClick={() => toggleExpand(cand.code, rowStrategy)}>
                      <span className="text-sm font-bold text-blue-300">{cand.rank}</span>
                      <span>
                        <div className="font-semibold">{cand.name}</div>
                        <div className="text-xs text-color-muted">{cand.code}</div>
                      </span>
                      <span className="text-right text-sky-300">{score.toFixed(1)}</span>
                      <span className={`text-right ${changeRate > 0 ? "text-red-400" : changeRate < 0 ? "text-blue-400" : "text-gray-400"}`}>
                        {changeRate > 0 ? "+" : ""}
                        {changeRate}%
                      </span>
                      <span className="text-center text-xs">
                        <span className="px-2 py-1 rounded bg-[#1e293b] border border-[#334155]">{cand.sector ?? "-"}</span>
                        {cand.exposureDeferred && <span className="block text-[10px] text-amber-300 mt-1">캡 적용</span>}
                      </span>
                      <span className="flex justify-center">
                        <Sparkline points={cand.sparkline60} />
                      </span>
                      <span className="text-center text-color-muted">{expandedRow === rowKey ? "v" : ">"}</span>
                    </button>

                    {expandedRow === rowKey && (
                      <div className="px-4 pb-4 grid gap-4">
                        <div className="text-sm bg-black/30 rounded p-3 border border-white/10">
                          <strong className="text-blue-300">AI 요약</strong> {detail?.aiReport?.summary ?? cand.summary}
                        </div>
                        <div className="grid md:grid-cols-2 gap-4">
                          <div className="space-y-2">
                            <ProgressBar label="Raw Return" score={rawReturn} colorClass="bg-blue-500" />
                            <ProgressBar label="Raw Stability" score={rawStability} colorClass="bg-emerald-500" />
                            <ProgressBar label="Raw Market" score={rawMarket} colorClass="bg-amber-500" />
                          </div>
                          <div className="bg-[#1f2937]/50 rounded p-3 text-sm space-y-1 border border-[#334155]">
                            <div>현재가: {detail?.currentPrice?.toLocaleString() ?? price.toLocaleString()} KRW</div>
                            <div>목표가: {detail?.targetPrice?.toLocaleString() ?? targetPrice.toLocaleString()} KRW</div>
                            <div>손절가: {detail?.stopLoss?.toLocaleString() ?? stopLoss.toLocaleString()} KRW</div>
                            <div>예상 수익률: {detail?.expectedReturn ?? 0}%</div>
                            <div>섹터: {detail?.sector ?? cand.sector ?? "-"}</div>
                            <div className="text-xs text-color-muted">
                              가중 점수: R {weightedReturn.toFixed(2)} / S {weightedStability.toFixed(2)} / M {weightedMarket.toFixed(2)}
                            </div>
                            {cand.details?.premarketSignals && (
                              <div className="text-xs text-color-muted border border-[#334155] rounded p-2 bg-[#0b1220]">
                                <div>장전 뉴스 감성: {Number(cand.details.premarketSignals.newsSentiment ?? 0).toFixed(2)}</div>
                                <div>야간 프록시: {Number(cand.details.premarketSignals.overnightProxy ?? 0).toFixed(2)}</div>
                                <div>뉴스 집계 구간: {cand.details.premarketSignals.newsWindowStart} ~ {cand.details.premarketSignals.newsWindowEnd}</div>
                              </div>
                            )}
                            {cand.details?.intradaySignals && (
                              <div className="text-xs text-color-muted border border-[#334155] rounded p-2 bg-[#0b1220]">
                                <div>장중 모드: {cand.details.intradaySignals.mode}</div>
                                <div>ORB: {Number(cand.details.intradaySignals.orbProxyScore ?? 0).toFixed(2)}</div>
                                <div>VWAP: {Number(cand.details.intradaySignals.vwapProxyScore ?? 0).toFixed(2)}</div>
                                <div>RVOL: {Number(cand.details.intradaySignals.rvolScore ?? 0).toFixed(2)}</div>
                              </div>
                            )}
                            {detail?.positionSizing && (
                              <div className="text-xs mt-2 border border-[#334155] rounded p-2 bg-[#111827]">
                                <div>매수 수량: {detail.positionSizing.shares.toLocaleString()}</div>
                                <div>필요 자금: {detail.positionSizing.capitalRequired.toLocaleString()} KRW</div>
                                <div>위험 금액: {detail.positionSizing.riskAmount.toLocaleString()} KRW</div>
                              </div>
                            )}
                          </div>
                        </div>

                        <div className="grid md:grid-cols-2 gap-4">
                          <div className="bg-[#0f172a] p-3 rounded border border-[#1e293b]">
                            <h3 className="text-xs text-color-muted mb-2">주요 뉴스 3줄</h3>
                            <ul className="text-sm space-y-1 list-disc list-inside">
                              {(detail?.newsSummary3 ?? ["뉴스를 불러오는 중...", "", ""]).map((line, i) => (
                                <li key={`${cand.code}-summary-${i}`}>{line}</li>
                              ))}
                            </ul>
                            <div className="flex gap-2 mt-2 flex-wrap">
                              {(detail?.themes ?? []).map((theme) => (
                                <span key={`${cand.code}-theme-${theme}`} className="text-xs px-2 py-1 rounded bg-[#1e293b] border border-[#334155]">
                                  #{theme}
                                </span>
                              ))}
                            </div>
                          </div>
                          <div className="bg-[#0f172a] p-3 rounded border border-[#1e293b]">
                            <h3 className="text-xs text-color-muted mb-2">LLM 결론</h3>
                            <p className="text-sm">{detail?.aiReport?.conclusion ?? "리포트 생성 중..."}</p>
                            <ul className="mt-2 text-xs list-disc list-inside text-color-muted">
                              {(detail?.aiReport?.riskFactors ?? []).map((rf) => (
                                <li key={`${cand.code}-${rf.id}`}>{rf.description}</li>
                              ))}
                            </ul>
                            {detail?.aiReport?.confidence && (
                              <div className="mt-2 text-xs border border-[#334155] rounded p-2 bg-[#111827]">
                                <div>신뢰도: {detail.aiReport.confidence.score} ({detail.aiReport.confidence.level})</div>
                                {(Array.isArray(detail.aiReport.confidence.warnings) ? detail.aiReport.confidence.warnings : []).map((w, idx) => (
                                  <div key={`${cand.code}-warn-${idx}`} className="text-amber-300">- {w}</div>
                                ))}
                              </div>
                            )}
                            {detail?.aiReport?.fallbackReason && (
                              <div className="mt-2 text-xs text-amber-200">대체 문구 사용: {detail.aiReport.fallbackReason}</div>
                            )}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </section>

          {insight && (
            <section className="bg-gradient-to-br from-[#0b1120] to-black border border-[#1f2937] rounded-lg p-4">
              <h2 className="text-base font-bold mb-2">시장 결론</h2>
              <p className="text-sm">{insight.conclusion}</p>
              <ul className="list-disc list-inside text-xs mt-2 text-color-muted">
                {(Array.isArray(insight.riskFactors) ? insight.riskFactors : []).map((r) => (
                  <li key={r.id}>{r.description}</li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}
    </main>
  );
}
