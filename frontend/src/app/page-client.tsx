"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState, useTransition } from "react";

import type {
  MarketInsight,
  MarketOverview,
  StockCandidate,
  StockDetail,
  StrategyKind,
  StrategyStatus,
  StrategyValidationResponse,
} from "@/lib/types";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";
const USER_KEY = "default";
const DEFAULT_WEIGHTS = { return: 0.4, stability: 0.3, market: 0.3 };
const LOCAL_CACHE_KEY = "dailystock:latestDashboardPayload";
const Sparkline = dynamic(() => import("@/components/Sparkline"), {
  ssr: false,
});
const INTRADAY_START_MINUTES = 9 * 60 + 5;
const INTRADAY_END_MINUTES = 15 * 60 + 20;

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

function buildLocalInsight(
  overview: MarketOverview,
  strategy: StrategyKind,
  sessionDate: string,
  signalDate: string,
  strategyReason: string,
): MarketInsight {
  const up = Number(overview.up ?? 0);
  const down = Number(overview.down ?? 0);
  const riskFactors: { id: string; description: string }[] = [];
  let conclusion = "";

  if (down > up * 2) {
    riskFactors.push({ id: "Risk 1", description: "시장 전반 하락 압력이 높아 보수적인 진입이 유효합니다." });
    conclusion = "안정성 비중을 높이고 손절 규칙을 엄격히 유지하는 전략이 필요합니다.";
  } else if (up > down * 2) {
    riskFactors.push({ id: "Risk 1", description: "상승 탄력이 강하지만 단기 과열 가능성에 주의해야 합니다." });
    conclusion = "수익 구간 분할 매도와 추세 추종을 병행하는 전략이 유효합니다.";
  } else {
    riskFactors.push({ id: "Risk 1", description: "종목별 차별화 장세가 이어져 선택적 접근이 필요합니다." });
    conclusion = "가중치를 활용해 선호 팩터 중심으로 후보를 압축해 접근하는 것이 좋습니다.";
  }

  if (overview.regimeRecommendation?.label && overview.regimeRecommendation?.suggestedWeights) {
    const suggested = overview.regimeRecommendation.suggestedWeights;
    riskFactors.push({
      id: "Regime",
      description: `현재 국면은 ${overview.regimeRecommendation.label}로 판단되며 추천 가중치는 R ${suggested.return}, S ${suggested.stability}, M ${suggested.market} 입니다.`,
    });
  }

  return {
    date: sessionDate,
    strategy,
    sessionDate,
    signalDate,
    strategyReason,
    riskFactors,
    conclusion,
  };
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

function isStrongTopPick(candidate: StockCandidate): boolean {
  if (typeof candidate.strongRecommendation === "boolean") {
    return candidate.strongRecommendation;
  }
  const rank = Number(candidate.rank ?? 0);
  return Number.isFinite(rank) && rank > 0 && rank <= 5;
}

function getNowKstMinutes(): number {
  const formatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Seoul",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = formatter.formatToParts(new Date());
  const hour = Number(parts.find((part) => part.type === "hour")?.value ?? "0");
  const minute = Number(parts.find((part) => part.type === "minute")?.value ?? "0");
  return hour * 60 + minute;
}

function isWithinIntradayWindow(): boolean {
  const minutes = getNowKstMinutes();
  return minutes >= INTRADAY_START_MINUTES && minutes <= INTRADAY_END_MINUTES;
}

function validationGateLabel(status: "pass" | "warn" | "fail" | undefined): string {
  if (status === "pass") return "검증통과";
  if (status === "fail") return "미통과";
  return "주의";
}

function validationGateClass(status: "pass" | "warn" | "fail" | undefined): string {
  if (status === "pass") return "border-emerald-500/70 bg-emerald-500/15 text-emerald-200";
  if (status === "fail") return "border-red-500/70 bg-red-500/15 text-red-200";
  return "border-amber-500/70 bg-amber-500/15 text-amber-200";
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

async function fetchWithTimeout(
  input: RequestInfo | URL,
  init: RequestInit & { timeoutMs?: number } = {},
): Promise<Response> {
  const { timeoutMs = 15000, ...rest } = init;
  const timeoutController = new AbortController();
  const upstreamSignal = rest.signal;
  const abortOnce = (reason: DOMException) => {
    if (!timeoutController.signal.aborted) {
      timeoutController.abort(reason);
    }
  };
  const onUpstreamAbort = () => {
    abortOnce(new DOMException("요청이 취소되었습니다.", "AbortError"));
  };
  if (upstreamSignal) {
    if (upstreamSignal.aborted) {
      onUpstreamAbort();
    } else {
      upstreamSignal.addEventListener("abort", onUpstreamAbort, { once: true });
    }
  }
  const timer = setTimeout(() => abortOnce(new DOMException("요청 시간이 초과되었습니다.", "TimeoutError")), timeoutMs);
  try {
    return await fetch(input, { ...rest, signal: timeoutController.signal });
  } finally {
    clearTimeout(timer);
    if (upstreamSignal) {
      upstreamSignal.removeEventListener("abort", onUpstreamAbort);
    }
  }
}

function isAbortLikeError(error: unknown): boolean {
  if (error instanceof DOMException) {
    return error.name === "AbortError" || error.name === "TimeoutError";
  }
  if (error instanceof Error) {
    const message = error.message.toLowerCase();
    return message.includes("aborted") || message.includes("aborterror") || message.includes("timeout");
  }
  return false;
}

function toUserErrorMessage(error: unknown): string {
  if (error instanceof DOMException && (error.name === "AbortError" || error.name === "TimeoutError")) {
    return "요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.";
  }
  if (error instanceof TypeError) {
    return `네트워크 연결 오류입니다. 백엔드 주소(${API_BASE})와 CORS/CSP 설정을 확인해주세요.`;
  }
  if (error instanceof Error) {
    return error.message;
  }
  return "데이터를 불러오지 못했습니다.";
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
  const [hasHydrated, setHasHydrated] = useState(false);
  const [watchlistLoaded, setWatchlistLoaded] = useState(false);
  const [strategyStatus, setStrategyStatus] = useState<StrategyStatus | null>(null);
  const [selectedStrategy, setSelectedStrategy] = useState<StrategyKind | null>(null);
  const [strategyValidation, setStrategyValidation] = useState<StrategyValidationResponse | null>(null);
  const [lastUserTriggerAt, setLastUserTriggerAt] = useState<string | null>(null);
  const [lastUserTriggerDate, setLastUserTriggerDate] = useState<string | null>(today);
  const [reloadTriggerId, setReloadTriggerId] = useState(1);
  const [isPending, startTransition] = useTransition();
  const lastProcessedReloadTriggerRef = useRef(0);

  const [weights, setWeights] = useState(DEFAULT_WEIGHTS);
  const [autoRegimeWeights, setAutoRegimeWeights] = useState(true);
  const [enforceExposureCap, setEnforceExposureCap] = useState(true);
  const [maxPerSector, setMaxPerSector] = useState(2);
  const [autoReloadMinutes, setAutoReloadMinutes] = useState(0);

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
  const [strategyNotice, setStrategyNotice] = useState<string | null>(null);
  const safeCandidates = useMemo(
    () =>
      (Array.isArray(candidates) ? candidates : []).filter(
        (candidate): candidate is StockCandidate => !!candidate && typeof candidate === "object",
      ),
    [candidates],
  );
  const safeIntradayExtraCandidates = useMemo(
    () =>
      (Array.isArray(intradayExtraCandidates) ? intradayExtraCandidates : []).filter(
        (candidate): candidate is StockCandidate => !!candidate && typeof candidate === "object",
      ),
    [intradayExtraCandidates],
  );
  const safeWeights = sanitizeWeights(weights);
  const customInputDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const previousCustomInputRef = useRef(customInput);
  const strategyNoticeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const resolvedCustomTickers = useMemo(() => {
    const adhoc = parseTickers(customInput);
    return Array.from(new Set([...watchlist, ...adhoc]));
  }, [watchlist, customInput]);
  const customTickersQuery = useMemo(() => resolvedCustomTickers.join(","), [resolvedCustomTickers]);
  const availableStrategies = useMemo(
    () => strategyStatus?.availableStrategies ?? [],
    [strategyStatus?.availableStrategies],
  );
  const intradayAvailable = availableStrategies.includes("intraday");
  const strategyMessage = selectedStrategy
    ? strategyStatus?.messages?.[selectedStrategy] ?? ""
    : strategyStatus?.detail ?? strategyStatus?.messages?.premarket ?? strategyStatus?.messages?.intraday ?? strategyStatus?.messages?.close ?? "";
  const selectedStrategyAdvisory = selectedStrategy ? strategyStatus?.strategyAdvisories?.[selectedStrategy] : undefined;
  const nonTradingDay = strategyStatus?.errorCode === "NON_TRADING_DAY" ? strategyStatus?.nonTradingDay ?? null : null;
  const shouldLoadIntradayExtra = Boolean(showIntradayExtra && intradayAvailable && selectedStrategy !== "intraday");
  const lastTriggerLabel = useMemo(() => {
    if (!hasHydrated || !lastUserTriggerAt) return "-";
    const formattedAt = new Date(lastUserTriggerAt).toLocaleString("ko-KR", {
      timeZone: "Asia/Seoul",
      hour12: false,
    });
    return `${lastUserTriggerDate ?? selectedDate} ${formattedAt}`;
  }, [hasHydrated, lastUserTriggerAt, lastUserTriggerDate, selectedDate]);

  const recordUserTrigger = useCallback((triggerDate?: string) => {
    const resolvedDate = triggerDate ?? selectedDate;
    setLastUserTriggerAt(new Date().toISOString());
    setLastUserTriggerDate(resolvedDate);
    setReloadTriggerId((prev) => prev + 1);
  }, [selectedDate]);

  const showStrategyNotice = useCallback((message: string) => {
    if (strategyNoticeTimerRef.current) {
      clearTimeout(strategyNoticeTimerRef.current);
    }
    setStrategyNotice(message);
    strategyNoticeTimerRef.current = setTimeout(() => {
      setStrategyNotice(null);
      strategyNoticeTimerRef.current = null;
    }, 5000);
  }, []);

  const handleStrategyButtonClick = useCallback(
    async (strategyKey: StrategyKind) => {
      let latestStatus: StrategyStatus | null = null;
      try {
        const statusRes = await fetchWithTimeout(`${API_BASE}/api/v1/strategy-status?date=${selectedDate}`, { timeoutMs: 8000 });
        if (statusRes.ok) {
          latestStatus = (await statusRes.json()) as StrategyStatus;
          setStrategyStatus(latestStatus);
        }
      } catch {
        // Keep current status snapshot when refresh fails.
      }

      const statusSnapshot = latestStatus ?? strategyStatus;
      const available = (statusSnapshot?.availableStrategies ?? availableStrategies).includes(strategyKey);
      if (!available) {
        const message =
          statusSnapshot?.messages?.[strategyKey] ??
          `${STRATEGY_LABEL[strategyKey]}은(는) 현재 시간에는 조회할 수 없습니다.`;
        showStrategyNotice(message);
        return;
      }
      setStrategyNotice(null);
      setError(null);
      setSelectedStrategy(strategyKey);
      recordUserTrigger();
    },
    [availableStrategies, recordUserTrigger, selectedDate, showStrategyNotice, strategyStatus],
  );

  const fetchWatchlist = async () => {
    try {
      const res = await fetchWithTimeout(`${API_BASE}/api/v1/watchlist?user_key=${USER_KEY}`, { timeoutMs: 8000 });
      if (!res.ok) throw new Error("워치리스트 조회에 실패했습니다.");
      const payload = (await res.json()) as { tickers: string[] };
      setWatchlist(payload.tickers ?? []);
    } catch (err) {
      if (!isAbortLikeError(err)) {
        console.error(err);
      }
    } finally {
      setWatchlistLoaded(true);
    }
  };

  useEffect(() => {
    setHasHydrated(true);
  }, []);

  useEffect(() => {
    return () => {
      if (strategyNoticeTimerRef.current) {
        clearTimeout(strategyNoticeTimerRef.current);
      }
    };
  }, []);

  useEffect(() => {
    void fetchWatchlist();
  }, []);

  useEffect(() => {
    let mounted = true;
    const controller = new AbortController();

    async function refreshStrategyStatus() {
      try {
        const res = await fetchWithTimeout(`${API_BASE}/api/v1/strategy-status?date=${selectedDate}`, {
          signal: controller.signal,
          timeoutMs: 12000,
        });
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
        if (controller.signal.aborted || isAbortLikeError(statusError)) return;
        console.error(statusError);
        if (!mounted) return;
        setStrategyStatus(null);
        setSelectedStrategy(null);
        setError(toUserErrorMessage(statusError) || "전략 상태 조회에 실패했습니다.");
      }
    }

    refreshStrategyStatus();
    return () => {
      mounted = false;
      controller.abort();
    };
  }, [selectedDate]);

  useEffect(() => {
    if (autoReloadMinutes <= 0) {
      return;
    }
    if (selectedDate !== today) {
      return;
    }
    const timer = window.setInterval(() => {
      if (document.visibilityState !== "visible") {
        return;
      }
      if (!isWithinIntradayWindow()) {
        return;
      }
      recordUserTrigger(selectedDate);
    }, autoReloadMinutes * 60_000);
    return () => {
      window.clearInterval(timer);
    };
  }, [autoReloadMinutes, selectedDate, today, recordUserTrigger]);

  useEffect(() => {
    setDetailData({});
    setExpandedRow(null);
    setIntradayExtraCandidates([]);
    setIntradayExtraError(null);
    setStrategyValidation(null);
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
    if (previousCustomInputRef.current === customInput) {
      return;
    }
    previousCustomInputRef.current = customInput;
    if (customInputDebounceRef.current) {
      clearTimeout(customInputDebounceRef.current);
    }
    customInputDebounceRef.current = setTimeout(() => {
      recordUserTrigger();
    }, 350);
    return () => {
      if (customInputDebounceRef.current) {
        clearTimeout(customInputDebounceRef.current);
      }
    };
  }, [customInput, recordUserTrigger]);

  useEffect(() => {
    const controller = new AbortController();

    async function fetchData() {
      if (!watchlistLoaded) {
        return;
      }
      if (strategyStatus?.requestedDate && strategyStatus.requestedDate !== selectedDate) {
        return;
      }
      if (lastUserTriggerDate && lastUserTriggerDate !== selectedDate) {
        return;
      }
      if (lastProcessedReloadTriggerRef.current === reloadTriggerId) {
        return;
      }
      if (!selectedStrategy) {
        if (!strategyStatus) {
          setLoading(false);
          return;
        }
        lastProcessedReloadTriggerRef.current = reloadTriggerId;
        setLoading(false);
        setMarketInfo(null);
        setCandidates([]);
        setIntradayExtraCandidates([]);
        setIntradayExtraError(null);
        setStrategyValidation(null);
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

      lastProcessedReloadTriggerRef.current = reloadTriggerId;
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
          include_validation: "false",
        });
        const shouldForceRefreshMainIntraday =
          reloadTriggerId >= 1 && selectedDate === today && selectedStrategy === "intraday";
        if (shouldForceRefreshMainIntraday) {
          common.set("force_refresh", "true");
          common.set("refresh_token", String(reloadTriggerId));
        }

        const candidatesQuery = new URLSearchParams(common);
        candidatesQuery.set("include_sparkline", "true");
        const validationQuery = new URLSearchParams({
          strategy: selectedStrategy,
          date: selectedDate,
          user_key: USER_KEY,
          custom_tickers: customTickersQuery,
          w_return: String(safeWeights.return),
          w_stability: String(safeWeights.stability),
          w_market: String(safeWeights.market),
          compare_branches: String(selectedStrategy === "intraday"),
          compute_if_missing: "false",
        });

        let candidatesRes: Response;
        try {
          candidatesRes = await fetchWithTimeout(`${API_BASE}/api/v1/stock-candidates?${candidatesQuery.toString()}`, {
            signal: controller.signal,
            timeoutMs: 70000,
          });
        } catch (candidateError) {
          // If intraday force-refresh is slow, retry once with cache-friendly params.
          if (shouldForceRefreshMainIntraday && isAbortLikeError(candidateError)) {
            const fallbackQuery = new URLSearchParams(candidatesQuery);
            fallbackQuery.delete("force_refresh");
            fallbackQuery.delete("refresh_token");
            candidatesRes = await fetchWithTimeout(`${API_BASE}/api/v1/stock-candidates?${fallbackQuery.toString()}`, {
              signal: controller.signal,
              timeoutMs: 20000,
            });
          } else {
            throw candidateError;
          }
        }
        if (!candidatesRes.ok) {
          throw new Error(await readApiError(candidatesRes));
        }

        const candsPayload = (await candidatesRes.json()) as unknown;
        const cands = toCandidateArray(candsPayload);
        const derived = deriveOverviewCounts(cands);
        const resolvedEffectiveDate = cands?.[0]?.sessionDate ?? cands?.[0]?.realDate ?? selectedDate;
        const syncedOverview: MarketOverview = {
          up: derived.up,
          down: derived.down,
          steady: derived.steady,
          warnings: [],
          strategy: selectedStrategy,
          sessionDate: resolvedEffectiveDate,
          signalDate: cands?.[0]?.signalDate ?? selectedDate,
          strategyReason: cands?.[0]?.strategyReason ?? "",
        };
        setEffectiveDate(resolvedEffectiveDate);
        setMarketInfo(syncedOverview);
        setCandidates(cands);
        const localInsight = buildLocalInsight(
          syncedOverview,
          selectedStrategy,
          resolvedEffectiveDate,
          cands?.[0]?.signalDate ?? selectedDate,
          cands?.[0]?.strategyReason ?? "",
        );
        setInsight(localInsight);
        setStrategyValidation(null);
        setIntradayExtraCandidates([]);
        setIntradayExtraError(null);

        void (async () => {
          try {
            const validationRes = await fetchWithTimeout(`${API_BASE}/api/v1/strategy-validation?${validationQuery.toString()}`, {
              signal: controller.signal,
              timeoutMs: 12000,
            });
            if (!validationRes.ok) return;
            const validationJson = (await validationRes.json()) as StrategyValidationResponse;
            if (!controller.signal.aborted) {
              setStrategyValidation(validationJson);
            }
          } catch {
            // Optional block: ignore validation API transient errors.
          }
        })();

        if (shouldLoadIntradayExtra) {
          void (async () => {
            try {
              const intradayQuery = new URLSearchParams(common);
              intradayQuery.set("strategy", "intraday");
              intradayQuery.set("include_sparkline", "true");
              if (selectedDate === today) {
                intradayQuery.set("force_refresh", "true");
                intradayQuery.set("refresh_token", String(reloadTriggerId));
              }
              const intradayRes = await fetchWithTimeout(`${API_BASE}/api/v1/stock-candidates?${intradayQuery.toString()}`, {
                signal: controller.signal,
                timeoutMs: 15000,
              });
              if (!intradayRes.ok) {
                if (!controller.signal.aborted) {
                  setIntradayExtraCandidates([]);
                  setIntradayExtraError(await readApiError(intradayRes));
                }
                return;
              }
              const intradayPayload = (await intradayRes.json()) as unknown;
              if (!controller.signal.aborted) {
                setIntradayExtraCandidates(toCandidateArray(intradayPayload).slice(0, 5));
                setIntradayExtraError(null);
              }
            } catch {
              // Optional block: ignore intraday extra API transient errors.
            }
          })();
        }
        localStorage.setItem(
          LOCAL_CACHE_KEY,
            JSON.stringify({
              strategy: selectedStrategy,
              selectedDate,
              effectiveDate: resolvedEffectiveDate,
              marketInfo: syncedOverview,
              candidates: cands,
              intradayExtraCandidates: [],
              insight: localInsight,
            }),
        );
      } catch (fetchError) {
        if (controller.signal.aborted) {
          return;
        }
        if (!isAbortLikeError(fetchError)) {
          console.error(fetchError);
        }
        const cachedRaw = localStorage.getItem(LOCAL_CACHE_KEY);
        if (cachedRaw) {
          try {
            const cached = JSON.parse(cachedRaw) as {
              strategy?: StrategyKind;
              selectedDate?: string;
              effectiveDate?: string;
              marketInfo?: MarketOverview;
              candidates?: StockCandidate[];
              intradayExtraCandidates?: StockCandidate[];
              insight?: MarketInsight | null;
            };
            const sameContext =
              cached.strategy === selectedStrategy &&
              cached.selectedDate === selectedDate;
            if (!sameContext) {
              throw new Error("stale cache context");
            }
            setMarketInfo(cached.marketInfo ?? null);
            setCandidates(Array.isArray(cached.candidates) ? cached.candidates : []);
            setIntradayExtraCandidates(Array.isArray(cached.intradayExtraCandidates) ? cached.intradayExtraCandidates : []);
            setInsight(cached.insight ?? null);
            setEffectiveDate(cached.effectiveDate ?? selectedDate);
            setError("네트워크 오류로 최근 캐시 데이터를 표시합니다.");
          } catch {
            setMarketInfo(null);
            setCandidates([]);
            setIntradayExtraCandidates([]);
            setIntradayExtraError(null);
            setInsight(null);
            setEffectiveDate(selectedDate);
            setError(toUserErrorMessage(fetchError));
          }
        } else {
          setMarketInfo(null);
          setCandidates([]);
          setIntradayExtraCandidates([]);
          setIntradayExtraError(null);
          setInsight(null);
          setEffectiveDate(selectedDate);
          setError(toUserErrorMessage(fetchError));
        }
      } finally {
        if (!controller.signal.aborted) {
          setLoading(false);
        }
      }
    }
    void fetchData();
    return () => {
      controller.abort();
    };
  }, [
    watchlistLoaded,
    reloadTriggerId,
    lastUserTriggerDate,
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
    today,
  ]);

  const handleWeight = (key: "return" | "stability" | "market", value: number) => {
    startTransition(() => {
      setWeights((prev) => normalizeWeights({ ...sanitizeWeights(prev), [key]: value }));
    });
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
      recordUserTrigger();
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
      recordUserTrigger();
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
      recordUserTrigger();
    } catch (err) {
      console.error(err);
    }
  };

  const applyRecommendedWeights = () => {
    const suggested = marketInfo?.regimeRecommendation?.suggestedWeights;
    if (!suggested) return;
    setWeights(sanitizeWeights(suggested));
    setAutoRegimeWeights(false);
    recordUserTrigger();
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
              Coreline Stock AI
            </h1>
            <p className="text-color-muted text-sm mt-1">국면 감지, 섹터 캡, 신뢰도, 워치리스트</p>
          </div>
          <div className="flex items-center gap-3">
            <input
              type="date"
              value={selectedDate ?? ""}
              max={today}
              onChange={(e) => {
                const nextDate = e.target.value;
                setSelectedDate(nextDate);
                recordUserTrigger(nextDate);
              }}
              className="bg-color-card border border-color-card-border rounded px-3 py-1.5 text-white"
              aria-label="조회 날짜 선택"
            />
            <div className="flex items-center gap-1 rounded border border-[#334155] bg-[#0f172a] p-1">
              {(Object.keys(STRATEGY_LABEL) as StrategyKind[]).map((strategyKey) => {
                const isAvailable = availableStrategies.includes(strategyKey);
                const isActive = selectedStrategy === strategyKey;
                return (
                  <button
                    key={strategyKey}
                    type="button"
                    title={strategyStatus?.messages?.[strategyKey] ?? ""}
                    onClick={() => {
                      void handleStrategyButtonClick(strategyKey);
                    }}
                    aria-pressed={isActive}
                    className={`px-2.5 py-1 text-xs rounded ${
                      isActive ? "bg-[#2563eb] text-white" : "bg-[#1e293b] text-slate-200"
                    } ${!isAvailable ? "opacity-70 hover:bg-[#263247] cursor-pointer" : "hover:bg-[#334155]"}`}
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
          {` | 마지막 입력 트리거: ${lastTriggerLabel}`}
          {isPending ? " | 업데이트 중..." : ""}
        </div>
        {selectedStrategyAdvisory && !selectedStrategyAdvisory.recommended && (
          <div className="text-xs rounded border border-rose-700/40 bg-rose-950/30 p-2 text-rose-200">
            현재 전략은 비권장 상태입니다. ({selectedStrategyAdvisory.reason})
          </div>
        )}
        {nonTradingDay && (
          <div className="text-xs rounded border border-amber-700/40 bg-amber-950/30 p-2 text-amber-200">
            비거래일 사유: {nonTradingDay.reason}
            {nonTradingDay.holidayName ? ` | 휴일명: ${nonTradingDay.holidayName}` : ""}
            {nonTradingDay.calendarProvider ? ` | 캘린더: ${nonTradingDay.calendarProvider}` : ""}
          </div>
        )}
        {strategyNotice && (
          <div className="text-xs rounded border border-sky-700/40 bg-sky-950/30 p-2 text-sky-200">
            안내: {strategyNotice}
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
                onClick={() => {
                  setWeights(PRESETS[key]);
                  recordUserTrigger();
                }}
                disabled={autoRegimeWeights}
              >
                {key}
              </button>
            ))}
            <label className="ml-2 text-xs flex items-center gap-1">
              <input
                type="checkbox"
                checked={Boolean(autoRegimeWeights)}
                onChange={(e) => {
                  setAutoRegimeWeights(e.target.checked);
                  recordUserTrigger();
                }}
              />
              국면 자동 가중치
            </label>
            <span className="text-xs text-color-muted ml-auto">적용일: {effectiveDate}</span>
          </div>

          <div className="grid md:grid-cols-3 gap-3">
            <label className="text-xs space-y-1">
              <span>수익성 {safeWeights.return.toFixed(2)}</span>
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={safeWeights.return}
                onChange={(e) => handleWeight("return", Number(e.target.value))}
                onMouseUp={() => recordUserTrigger()}
                onTouchEnd={() => recordUserTrigger()}
                onKeyUp={() => recordUserTrigger()}
                className="w-full"
                disabled={Boolean(autoRegimeWeights)}
              />
            </label>
            <label className="text-xs space-y-1">
              <span>안정성 {safeWeights.stability.toFixed(2)}</span>
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={safeWeights.stability}
                onChange={(e) => handleWeight("stability", Number(e.target.value))}
                onMouseUp={() => recordUserTrigger()}
                onTouchEnd={() => recordUserTrigger()}
                onKeyUp={() => recordUserTrigger()}
                className="w-full"
                disabled={Boolean(autoRegimeWeights)}
              />
            </label>
            <label className="text-xs space-y-1">
              <span>시장성 {safeWeights.market.toFixed(2)}</span>
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={safeWeights.market}
                onChange={(e) => handleWeight("market", Number(e.target.value))}
                onMouseUp={() => recordUserTrigger()}
                onTouchEnd={() => recordUserTrigger()}
                onKeyUp={() => recordUserTrigger()}
                className="w-full"
                disabled={Boolean(autoRegimeWeights)}
              />
            </label>
          </div>

          <div className="flex flex-wrap items-center gap-3 text-xs">
            <label className="flex items-center gap-1">
              <input
                type="checkbox"
                checked={Boolean(enforceExposureCap)}
                onChange={(e) => {
                  setEnforceExposureCap(e.target.checked);
                  recordUserTrigger();
                }}
              />
              Top5 섹터 노출 한도 적용
            </label>
            <label className="flex items-center gap-1">
              섹터별 최대
              <select
                value={asFiniteNumber(maxPerSector, 2)}
                onChange={(e) => {
                  setMaxPerSector(Number(e.target.value));
                  recordUserTrigger();
                }}
                className="bg-[#0f172a] border border-[#334155] rounded px-1 py-0.5"
              >
                <option value={1}>1</option>
                <option value={2}>2</option>
                <option value={3}>3</option>
              </select>
            </label>
            <label className="flex items-center gap-1">
              <input
                type="checkbox"
                checked={Boolean(showIntradayExtra)}
                onChange={(e) => {
                  setShowIntradayExtra(e.target.checked);
                  recordUserTrigger();
                }}
              />
              장중 단타 추가 추천 표시
            </label>
            <label className="flex items-center gap-1">
              자동 리로드
              <select
                value={autoReloadMinutes}
                onChange={(e) => {
                  setAutoReloadMinutes(Number(e.target.value));
                  recordUserTrigger();
                }}
                className="bg-[#0f172a] border border-[#334155] rounded px-1 py-0.5"
              >
                <option value={0}>끔(수동만)</option>
                <option value={10}>10분</option>
                <option value={20}>20분</option>
                <option value={30}>30분</option>
              </select>
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
            <button onClick={addWatchlist} className="bg-[#1d4ed8] hover:bg-[#2563eb] rounded px-3 text-sm" aria-label="워치리스트 종목 추가">
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
            <button onClick={uploadWatchlistCsv} className="bg-[#0ea5e9] hover:bg-[#0284c7] rounded px-2.5 py-1 text-xs" aria-label="워치리스트 CSV 업로드">
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
            onChange={(e) => {
              setCustomInput(e.target.value);
            }}
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

          {strategyValidation && (
            <section className="bg-color-card border border-color-card-border rounded-lg p-4 space-y-3">
              <div className="flex items-center justify-between gap-2">
                <h2 className="text-sm font-semibold">전략 검증 요약</h2>
                <span className={`text-[11px] px-2 py-0.5 rounded border ${validationGateClass(strategyValidation.gateStatus)}`}>
                  {validationGateLabel(strategyValidation.gateStatus)}
                </span>
              </div>
              <div className="text-xs text-color-muted">
                기준일 {strategyValidation.asOfDate} | 모드 {strategyValidation.mode}
                {strategyValidation.insufficientData ? " | 데이터 부족" : ""}
                {strategyValidation.protocol?.intradaySignalBranch ? ` | 브랜치 ${strategyValidation.protocol.intradaySignalBranch}` : ""}
              </div>
              <div className="grid md:grid-cols-4 gap-2 text-xs">
                <div className="bg-[#0f172a] border border-[#1e293b] rounded p-2">Net Sharpe: {Number(strategyValidation.metrics.netSharpe ?? 0).toFixed(2)}</div>
                <div className="bg-[#0f172a] border border-[#1e293b] rounded p-2">PBO: {Number(strategyValidation.metrics.pbo ?? 0).toFixed(2)}</div>
                <div className="bg-[#0f172a] border border-[#1e293b] rounded p-2">DSR: {Number(strategyValidation.metrics.dsr ?? 0).toFixed(2)}</div>
                <div className="bg-[#0f172a] border border-[#1e293b] rounded p-2">표본수: {Number(strategyValidation.metrics.sampleSize ?? 0).toLocaleString()}</div>
              </div>
              <div className="text-[11px] text-color-muted">
                임계값: Sharpe &gt;= {Number(strategyValidation.thresholds.netSharpeMin ?? 0).toFixed(2)}, PBO &lt;= {Number(strategyValidation.thresholds.pboMax ?? 0).toFixed(2)}, DSR &gt; {Number(strategyValidation.thresholds.dsrMin ?? 0).toFixed(2)}, 표본수 &gt;= {Number(strategyValidation.thresholds.sampleSizeMin ?? 0).toLocaleString()}
              </div>
              {strategyValidation.monitoring && (
                <div className="text-[11px] rounded border border-[#334155] bg-[#0b1220] p-2">
                  모니터링: {strategyValidation.monitoring.logged ? "로그 기록됨" : "로그 미기록"}
                  {Array.isArray(strategyValidation.monitoring.alerts) && strategyValidation.monitoring.alerts.length > 0
                    ? ` | 알림: ${strategyValidation.monitoring.alerts.join(", ")}`
                    : " | 알림 없음"}
                </div>
              )}
              {strategyValidation.branchComparison && (
                <div className="text-xs border border-[#334155] rounded p-3 bg-[#0b1220] space-y-1">
                  <div>
                    브랜치 비교: 선택 `{strategyValidation.branchComparison.selectedBranch}` / 추천 `{strategyValidation.branchComparison.recommendedBranch}`
                  </div>
                  <div>
                    baseline: Sharpe {Number(strategyValidation.branchComparison.baseline.netSharpe ?? 0).toFixed(2)}, PBO {Number(strategyValidation.branchComparison.baseline.pbo ?? 0).toFixed(2)}, DSR {Number(strategyValidation.branchComparison.baseline.dsr ?? 0).toFixed(2)}
                  </div>
                  <div>
                    phase2: Sharpe {Number(strategyValidation.branchComparison.phase2.netSharpe ?? 0).toFixed(2)}, PBO {Number(strategyValidation.branchComparison.phase2.pbo ?? 0).toFixed(2)}, DSR {Number(strategyValidation.branchComparison.phase2.dsr ?? 0).toFixed(2)}
                  </div>
                </div>
              )}
            </section>
          )}

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
                  const strongTopPick = isStrongTopPick(cand);
                  return (
                    <div
                      key={`intraday-${cand.code}-${cand.rank ?? idx}`}
                      className={`border-t border-[#2d333b] ${strongTopPick ? "bg-[#1b2537]" : "bg-[#111827]"}`}
                    >
                      <button
                        className="w-full grid grid-cols-[40px_1fr_90px_90px_110px_90px_44px] gap-2 px-3 py-3 items-center text-left hover:bg-white/5"
                        onClick={() => toggleExpand(cand.code, rowStrategy)}
                        aria-expanded={expandedRow === rowKey}
                      >
                        <span className="text-sm font-bold text-blue-300">{cand.rank}</span>
                        <span>
                          <div className="font-semibold flex items-center gap-2">
                            <span>{cand.name}</span>
                            {strongTopPick && (
                              <span className="text-[10px] px-1.5 py-0.5 rounded border border-amber-400/70 bg-amber-500/20 text-amber-200">
                                강력추천 TOP5
                              </span>
                            )}
                          </div>
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
                          {cand.details?.validation && (
                            <div className="text-xs">
                              <span className={`inline-flex items-center px-2 py-1 rounded border ${validationGateClass(cand.details.validation.gateStatus)}`}>
                                {validationGateLabel(cand.details.validation.gateStatus)}
                              </span>
                              <span className="ml-2 text-color-muted">
                                Sharpe {Number(cand.details.validation.netSharpe ?? 0).toFixed(2)} | PBO {Number(cand.details.validation.pbo ?? 0).toFixed(2)} | DSR {Number(cand.details.validation.dsr ?? 0).toFixed(2)}
                              </span>
                            </div>
                          )}
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
                                  <div>브랜치: {cand.details.intradaySignals.signalBranch ?? "-"}</div>
                                  <div>ORB: {Number(cand.details.intradaySignals.orbProxyScore ?? 0).toFixed(2)}</div>
                                  <div>VWAP: {Number(cand.details.intradaySignals.vwapProxyScore ?? 0).toFixed(2)}</div>
                                  <div>RVOL: {Number(cand.details.intradaySignals.rvolScore ?? 0).toFixed(2)}</div>
                                  {typeof cand.details.intradaySignals.inPlayScore === "number" && (
                                    <div>In-Play: {Number(cand.details.intradaySignals.inPlayScore).toFixed(2)}</div>
                                  )}
                                  {typeof cand.details.intradaySignals.intradayMomentumScore === "number" && (
                                    <div>장중 모멘텀: {Number(cand.details.intradaySignals.intradayMomentumScore).toFixed(2)}</div>
                                  )}
                                  {typeof cand.details.intradaySignals.overnightReversalScore === "number" && (
                                    <div>오버나잇 반전: {Number(cand.details.intradaySignals.overnightReversalScore).toFixed(2)}</div>
                                  )}
                                  {typeof cand.details.intradaySignals.overnightReturnPct === "number" && (
                                    <div>오버나잇 수익률: {Number(cand.details.intradaySignals.overnightReturnPct).toFixed(2)}%</div>
                                  )}
                                  {typeof cand.details.intradaySignals.intradayReturnPct === "number" && (
                                    <div>장중 수익률: {Number(cand.details.intradaySignals.intradayReturnPct).toFixed(2)}%</div>
                                  )}
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
                const strongTopPick = isStrongTopPick(cand);
                return (
                  <div
                    key={`${cand.code}-${cand.rank ?? idx}`}
                    className={`border-t border-[#2d333b] ${strongTopPick ? "bg-[#1b2537]" : "bg-[#111827]"}`}
                  >
                    <button
                      className="w-full grid grid-cols-[40px_1fr_90px_90px_110px_90px_44px] gap-2 px-3 py-3 items-center text-left hover:bg-white/5"
                      onClick={() => toggleExpand(cand.code, rowStrategy)}
                      aria-expanded={expandedRow === rowKey}
                    >
                      <span className="text-sm font-bold text-blue-300">{cand.rank}</span>
                      <span>
                        <div className="font-semibold flex items-center gap-2">
                          <span>{cand.name}</span>
                          {strongTopPick && (
                            <span className="text-[10px] px-1.5 py-0.5 rounded border border-amber-400/70 bg-amber-500/20 text-amber-200">
                              강력추천 TOP5
                            </span>
                          )}
                        </div>
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
                        {cand.details?.validation && (
                          <div className="text-xs">
                            <span className={`inline-flex items-center px-2 py-1 rounded border ${validationGateClass(cand.details.validation.gateStatus)}`}>
                              {validationGateLabel(cand.details.validation.gateStatus)}
                            </span>
                            <span className="ml-2 text-color-muted">
                              Sharpe {Number(cand.details.validation.netSharpe ?? 0).toFixed(2)} | PBO {Number(cand.details.validation.pbo ?? 0).toFixed(2)} | DSR {Number(cand.details.validation.dsr ?? 0).toFixed(2)}
                            </span>
                          </div>
                        )}
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
                                <div>브랜치: {cand.details.intradaySignals.signalBranch ?? "-"}</div>
                                <div>ORB: {Number(cand.details.intradaySignals.orbProxyScore ?? 0).toFixed(2)}</div>
                                <div>VWAP: {Number(cand.details.intradaySignals.vwapProxyScore ?? 0).toFixed(2)}</div>
                                <div>RVOL: {Number(cand.details.intradaySignals.rvolScore ?? 0).toFixed(2)}</div>
                                {typeof cand.details.intradaySignals.inPlayScore === "number" && (
                                  <div>In-Play: {Number(cand.details.intradaySignals.inPlayScore).toFixed(2)}</div>
                                )}
                                {typeof cand.details.intradaySignals.intradayMomentumScore === "number" && (
                                  <div>장중 모멘텀: {Number(cand.details.intradaySignals.intradayMomentumScore).toFixed(2)}</div>
                                )}
                                {typeof cand.details.intradaySignals.overnightReversalScore === "number" && (
                                  <div>오버나잇 반전: {Number(cand.details.intradaySignals.overnightReversalScore).toFixed(2)}</div>
                                )}
                                {typeof cand.details.intradaySignals.overnightReturnPct === "number" && (
                                  <div>오버나잇 수익률: {Number(cand.details.intradaySignals.overnightReturnPct).toFixed(2)}%</div>
                                )}
                                {typeof cand.details.intradaySignals.intradayReturnPct === "number" && (
                                  <div>장중 수익률: {Number(cand.details.intradaySignals.intradayReturnPct).toFixed(2)}%</div>
                                )}
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
