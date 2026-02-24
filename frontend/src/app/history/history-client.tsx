"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import type { BacktestHistoryItem, BacktestSummary } from "@/lib/types";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

const initialSummary: BacktestSummary = {
  startDate: null,
  endDate: null,
  count: 0,
  metrics: {
    avgRetT1: 0,
    avgRetT3: 0,
    avgRetT5: 0,
    winRateT1: 0,
    winRateT3: 0,
    winRateT5: 0,
    mddT1: 0,
    mddT3: 0,
    mddT5: 0,
  },
};

function toNumber(value: unknown, fallback = 0): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

async function readApiError(response: Response): Promise<string> {
  const fallback = `백테스트 API 오류 (${response.status})`;
  try {
    const payload = (await response.json()) as { detail?: string; message?: string };
    if (typeof payload?.detail === "string" && payload.detail.trim()) {
      return payload.detail.trim();
    }
    if (typeof payload?.message === "string" && payload.message.trim()) {
      return payload.message.trim();
    }
  } catch {
    // fall through
  }
  return fallback;
}

export default function HistoryPage() {
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [summary, setSummary] = useState<BacktestSummary>(initialSummary);
  const [items, setItems] = useState<BacktestHistoryItem[]>([]);
  const [page, setPage] = useState(1);
  const [size] = useState(20);
  const [total, setTotal] = useState(0);
  const [feeBps, setFeeBps] = useState(10);
  const [slippageBps, setSlippageBps] = useState(5);
  const [error, setError] = useState<string | null>(null);

  const fetchData = async (nextPage: number) => {
    setError(null);
    const summaryParams = new URLSearchParams({ fee_bps: String(feeBps), slippage_bps: String(slippageBps) });
    const historyParams = new URLSearchParams({ page: String(nextPage), size: String(size), fee_bps: String(feeBps), slippage_bps: String(slippageBps) });
    if (startDate) {
      summaryParams.set("start_date", startDate);
      historyParams.set("start_date", startDate);
    }
    if (endDate) {
      summaryParams.set("end_date", endDate);
      historyParams.set("end_date", endDate);
    }

    try {
      const healthRes = await fetch(`${API_BASE}/api/v1/health`);
      if (healthRes.ok) {
        const health = (await healthRes.json()) as { database?: string };
        if (health.database === "disabled") {
          setSummary(initialSummary);
          setItems([]);
          setTotal(0);
          setPage(1);
          setError("데이터베이스가 설정되지 않아 백테스트 히스토리를 사용할 수 없습니다. 서버의 DATABASE_URL 설정 후 다시 시도하세요.");
          return;
        }
      }

      const [summaryRes, historyRes] = await Promise.all([
        fetch(`${API_BASE}/api/v1/backtest/summary?${summaryParams.toString()}`),
        fetch(`${API_BASE}/api/v1/backtest/history?${historyParams.toString()}`),
      ]);

      if (!summaryRes.ok || !historyRes.ok) {
        const failedResponse = !summaryRes.ok ? summaryRes : historyRes;
        const detail = await readApiError(failedResponse);
        const isDbNotConfigured = failedResponse.status === 503 && detail.includes("DATABASE_URL");
        if (isDbNotConfigured) {
          setSummary(initialSummary);
          setItems([]);
          setTotal(0);
          setPage(1);
          setError("데이터베이스가 설정되지 않아 백테스트 히스토리를 사용할 수 없습니다. 서버의 DATABASE_URL 설정 후 다시 시도하세요.");
          return;
        }
        throw new Error(detail || "백테스트 API 오류");
      }

      const summaryJson = (await summaryRes.json()) as Partial<BacktestSummary> & { metrics?: Record<string, unknown> };
      const historyJson = (await historyRes.json()) as {
        items?: unknown;
        total?: unknown;
        count?: unknown;
        page?: unknown;
      };

      const metrics = (summaryJson.metrics ?? {}) as Record<string, unknown>;
      setSummary({
        startDate: typeof summaryJson.startDate === "string" ? summaryJson.startDate : null,
        endDate: typeof summaryJson.endDate === "string" ? summaryJson.endDate : null,
        count: toNumber(summaryJson.count, 0),
        metrics: {
          avgRetT1: toNumber(metrics.avgRetT1, 0),
          avgRetT3: toNumber(metrics.avgRetT3, 0),
          avgRetT5: toNumber(metrics.avgRetT5, 0),
          avgNetRetT1: toNumber(metrics.avgNetRetT1, 0),
          avgNetRetT3: toNumber(metrics.avgNetRetT3, 0),
          avgNetRetT5: toNumber(metrics.avgNetRetT5, 0),
          winRateT1: toNumber(metrics.winRateT1, 0),
          winRateT3: toNumber(metrics.winRateT3, 0),
          winRateT5: toNumber(metrics.winRateT5, 0),
          netWinRateT1: toNumber(metrics.netWinRateT1, 0),
          netWinRateT3: toNumber(metrics.netWinRateT3, 0),
          netWinRateT5: toNumber(metrics.netWinRateT5, 0),
          mddT1: toNumber(metrics.mddT1, 0),
          mddT3: toNumber(metrics.mddT3, 0),
          mddT5: toNumber(metrics.mddT5, 0),
          netMddT1: toNumber(metrics.netMddT1, 0),
          netMddT3: toNumber(metrics.netMddT3, 0),
          netMddT5: toNumber(metrics.netMddT5, 0),
        },
      });
      setItems(Array.isArray(historyJson.items) ? (historyJson.items as BacktestHistoryItem[]) : []);
      setTotal(toNumber(historyJson.total ?? historyJson.count, 0));
      setPage(toNumber(historyJson.page, nextPage));
    } catch (fetchError) {
      const message = fetchError instanceof Error ? fetchError.message : "백테스트 데이터를 불러오지 못했습니다.";
      setError(message || "백테스트 데이터를 불러오지 못했습니다. DB 설정과 backfill 실행 여부를 확인하세요.");
    }
  };

  useEffect(() => {
    fetchData(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const maxPage = Math.max(1, Math.ceil(total / size));

  return (
    <main className="max-w-6xl mx-auto p-4 md:p-6 pb-20 space-y-4">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">백테스트 히스토리</h1>
          <p className="text-sm text-color-muted">Top5 추천 기준 T+1 / T+3 / T+5 성과</p>
        </div>
        <Link href="/" className="bg-[#123a66] hover:bg-[#1b4f88] rounded px-3 py-1.5 text-sm">
          메인으로
        </Link>
      </header>

      <section className="bg-color-card border border-color-card-border rounded p-4">
        <div className="flex flex-wrap gap-2 items-end">
          <label className="text-xs flex flex-col gap-1">
            시작일
            <input type="date" aria-label="백테스트 시작일" value={startDate} onChange={(e) => setStartDate(e.target.value)} className="bg-[#0f172a] border border-[#334155] rounded px-2 py-1" />
          </label>
          <label className="text-xs flex flex-col gap-1">
            종료일
            <input type="date" aria-label="백테스트 종료일" value={endDate} onChange={(e) => setEndDate(e.target.value)} className="bg-[#0f172a] border border-[#334155] rounded px-2 py-1" />
          </label>
          <label className="text-xs flex flex-col gap-1">
            수수료(bps)
            <input type="number" min={0} aria-label="수수료 bps" value={feeBps} onChange={(e) => setFeeBps(Number(e.target.value))} className="bg-[#0f172a] border border-[#334155] rounded px-2 py-1 w-24" />
          </label>
          <label className="text-xs flex flex-col gap-1">
            슬리피지(bps)
            <input type="number" min={0} aria-label="슬리피지 bps" value={slippageBps} onChange={(e) => setSlippageBps(Number(e.target.value))} className="bg-[#0f172a] border border-[#334155] rounded px-2 py-1 w-24" />
          </label>
          <button className="px-3 py-1.5 text-sm rounded bg-[#1e40af] hover:bg-[#1d4ed8]" onClick={() => fetchData(1)} aria-label="백테스트 조회">
            조회
          </button>
        </div>
      </section>

      {error && <div className="rounded border border-red-900 bg-red-950/30 p-3 text-red-300 text-sm">{error}</div>}

      <section className="grid md:grid-cols-3 gap-3">
        <div className="bg-[#111827] border border-[#1f2937] rounded p-3">
          <div className="text-xs text-color-muted">평균 수익률</div>
          <div className="mt-1 text-sm">T+1 {summary.metrics.avgRetT1}%</div>
          <div className="text-sm">T+3 {summary.metrics.avgRetT3}%</div>
          <div className="text-sm">T+5 {summary.metrics.avgRetT5}%</div>
          <div className="mt-2 text-xs text-[#93c5fd]">순수익 T+1 {summary.metrics.avgNetRetT1 ?? 0}%</div>
          <div className="text-xs text-[#93c5fd]">순수익 T+3 {summary.metrics.avgNetRetT3 ?? 0}%</div>
          <div className="text-xs text-[#93c5fd]">순수익 T+5 {summary.metrics.avgNetRetT5 ?? 0}%</div>
        </div>
        <div className="bg-[#111827] border border-[#1f2937] rounded p-3">
          <div className="text-xs text-color-muted">승률</div>
          <div className="mt-1 text-sm">T+1 {summary.metrics.winRateT1}%</div>
          <div className="text-sm">T+3 {summary.metrics.winRateT3}%</div>
          <div className="text-sm">T+5 {summary.metrics.winRateT5}%</div>
        </div>
        <div className="bg-[#111827] border border-[#1f2937] rounded p-3">
          <div className="text-xs text-color-muted">MDD(최저 수익률)</div>
          <div className="mt-1 text-sm">T+1 {summary.metrics.mddT1}%</div>
          <div className="text-sm">T+3 {summary.metrics.mddT3}%</div>
          <div className="text-sm">T+5 {summary.metrics.mddT5}%</div>
        </div>
      </section>

      <section className="border border-color-card-border rounded overflow-hidden">
        <div className="grid grid-cols-7 gap-2 px-3 py-2 text-xs bg-[#1c2128] text-color-muted">
          <span>날짜</span>
          <span>종목</span>
          <span className="text-right">시가 / 종가</span>
          <span className="text-right">현재가 (기준일)</span>
          <span className="text-right">진입가</span>
          <span className="text-right">T+1 / T+3</span>
          <span className="text-right">T+5</span>
        </div>
        {items.map((item) => (
          <div key={`${item.tradeDate}-${item.ticker}`} className="grid grid-cols-7 gap-2 px-3 py-2 text-sm border-t border-[#2d333b] bg-[#0f172a]">
            <span>{item.tradeDate}</span>
            <span>
              <div>{item.companyName ?? item.ticker}</div>
              <div className="text-[11px] text-color-muted">{item.ticker}</div>
            </span>
            <span className="text-right">
              {(item.dayOpen ?? item.entryPrice ?? 0).toLocaleString()} / {(item.dayClose ?? item.entryPrice ?? 0).toLocaleString()}
            </span>
            <span className="text-right">
              {(item.currentPrice ?? item.dayClose ?? item.entryPrice ?? 0).toLocaleString()}
              <div className="text-[11px] text-color-muted">{item.currentPriceDate ?? item.tradeDate}</div>
            </span>
            <span className="text-right">{item.entryPrice.toLocaleString()}</span>
            <span className="text-right">
              {(item.retT1 ?? 0).toFixed(2)}% / {(item.retT3 ?? 0).toFixed(2)}%
            </span>
            <span className="text-right">
              {(item.retT5 ?? 0).toFixed(2)}%
              {item.netRetT5 !== undefined && <div className="text-[11px] text-[#93c5fd]">net {(item.netRetT5 ?? 0).toFixed(2)}%</div>}
            </span>
          </div>
        ))}
      </section>

      <div className="flex items-center justify-end gap-2">
        <button disabled={page <= 1} onClick={() => fetchData(page - 1)} className="px-2 py-1 rounded bg-[#1e293b] disabled:opacity-40" aria-label="이전 페이지">
          이전
        </button>
        <span className="text-sm text-color-muted">
          {page} / {maxPage}
        </span>
        <button disabled={page >= maxPage} onClick={() => fetchData(page + 1)} className="px-2 py-1 rounded bg-[#1e293b] disabled:opacity-40" aria-label="다음 페이지">
          다음
        </button>
      </div>
    </main>
  );
}
