export interface Warning {
  type: "warning" | "error";
  message: string;
}

export type StrategyKind = "premarket" | "intraday" | "close";

export interface StrategyStatus {
  timezone: string;
  nowKst: string;
  requestedDate: string;
  availableStrategies: StrategyKind[];
  defaultStrategy: StrategyKind | null;
  messages: {
    premarket: string;
    intraday: string;
    close: string;
  };
  strategyAdvisories?: Partial<
    Record<
      StrategyKind,
      {
        recommended: boolean;
        gateStatus: "pass" | "warn" | "fail";
        mode: string;
        reason: string;
        intradaySignalBranch?: "baseline" | "phase2" | string | null;
      }
    >
  >;
  errorCode?: string | null;
  detail?: string | null;
  nonTradingDay?: {
    date: string;
    reasonType: "weekend" | "holiday" | "closed_session" | "unknown_closed";
    reason: string;
    holidayName?: string | null;
    weekday?: string;
    sessionOpen?: boolean | null;
    calendarProvider?: string | null;
    calendar?: string | null;
  } | null;
}

export interface MarketOverview {
  up: number;
  steady: number;
  down: number;
  warnings: Warning[];
  indices?: { name: string; value: number; changeRate: number }[];
  strategy?: StrategyKind;
  sessionDate?: string;
  signalDate?: string;
  strategyReason?: string;
  regimeRecommendation?: {
    regime: "bull" | "sideways" | "bear";
    label: string;
    confidence: number;
    suggestedWeights: {
      return: number;
      stability: number;
      market: number;
    };
    reason: string;
  };
}

export interface StockCandidate {
  rank: number;
  name: string;
  code: string;
  score: number;
  changeRate: number;
  price: number;
  targetPrice: number;
  stopLoss: number;
  tags: string[];
  sector?: string;
  exposureDeferred?: boolean;
  strongRecommendation?: boolean;
  validationPenalty?: number;
  summary: string;
  sparkline60: number[];
  appliedWeights?: {
    return: number;
    stability: number;
    market: number;
  };
  strategy?: StrategyKind;
  sessionDate?: string;
  signalDate?: string;
  strategyReason?: string;
  regime?: string;
  details: {
    raw: {
      return: number;
      stability: number;
      market: number;
    };
    weighted: {
      return: number;
      stability: number;
      market: number;
    };
    premarketSignals?: {
      newsSentiment: number;
      overnightProxy: number;
      newsWindowStart: string;
      newsWindowEnd: string;
      usedPrimaryWindow: boolean;
      analyzedNewsCount: number;
    };
    intradaySignals?: {
      mode: string;
      signalBranch?: "baseline" | "phase2" | string;
      orbProxyScore: number;
      vwapProxyScore: number;
      rvolScore: number;
      openPrice: number;
      dayHigh: number;
      dayLow: number;
      vwapProxyPrice: number;
      rvolRatio: number;
      orbHigh?: number;
      orbLow?: number;
      vwapPrice?: number;
      inPlayScore?: number;
      intradayMomentumScore?: number;
      overnightReversalScore?: number;
      rvolProfileRatio?: number;
      overnightReturnPct?: number;
      intradayReturnPct?: number;
    };
    validation?: {
      gatePassed: boolean;
      gateStatus: "pass" | "warn" | "fail";
      insufficientData: boolean;
      pbo: number;
      dsr: number;
      netSharpe: number;
      asOfDate: string;
      mode: string;
    };
  };
  realDate?: string;
}

export interface StrategyValidationResponse {
  strategy: StrategyKind;
  requestedDate?: string | null;
  asOfDate: string;
  mode: string;
  gateStatus: "pass" | "warn" | "fail";
  gatePassed: boolean;
  insufficientData: boolean;
  validationPenalty: number;
  thresholds: {
    pboMax: number;
    dsrMin: number;
    sampleSizeMin: number;
    netSharpeMin: number;
  };
  protocol: {
    trainSessions: number;
    testSessions: number;
    embargoSessions: number;
    costBps: number;
    windows: number;
    intradaySignalBranch?: "baseline" | "phase2" | string;
  };
  metrics: {
    netSharpe: number;
    maxDrawdown: number;
    hitRate: number;
    turnover: number;
    pbo: number;
    dsr: number;
    sampleSize: number;
  };
  weights?: {
    return: number;
    stability: number;
    market: number;
  };
  customTickers?: string[];
  branchComparison?: {
    baseline: {
      gateStatus: "pass" | "warn" | "fail";
      netSharpe: number;
      pbo: number;
      dsr: number;
      sampleSize: number;
    };
    phase2: {
      gateStatus: "pass" | "warn" | "fail";
      netSharpe: number;
      pbo: number;
      dsr: number;
      sampleSize: number;
    };
    recommendedBranch: "baseline" | "phase2";
    selectedBranch: "baseline" | "phase2" | string;
  };
  monitoring?: {
    logged: boolean;
    alerts: string[];
  };
}

export interface WebVitalPayload {
  id: string;
  name: "FCP" | "LCP" | "CLS" | "INP" | "TTFB" | string;
  value: number;
  rating: "good" | "needs-improvement" | "poor" | string;
  path: string;
  ts: number;
}

export interface MarketInsight {
  date: string;
  strategy?: StrategyKind;
  sessionDate?: string;
  signalDate?: string;
  strategyReason?: string;
  riskFactors: { id: string; description: string }[];
  conclusion: string;
}

export interface AiReport {
  provider: string;
  model: string;
  generatedAt: string;
  summary: string;
  conclusion: string;
  riskFactors: { id: string; description: string }[];
  fallbackReason?: string;
  promptVersion?: string;
  promptHash?: string;
  confidence?: {
    score: number;
    level: "high" | "medium" | "low";
    warnings: string[];
  };
}

export interface StockDetail {
  ticker: string;
  name: string;
  strategy?: StrategyKind;
  sessionDate?: string;
  signalDate?: string;
  strategyReason?: string;
  currentPrice: number;
  targetPrice: number;
  stopLoss: number;
  high60: number;
  low10: number;
  expectedReturn: number;
  tags: string[];
  signals: { type: string; message: string }[];
  sector?: string;
  newsItems: { title: string; url: string; publishedAt: string }[];
  newsSummary3: string[];
  themes: string[];
  aiReport: AiReport | null;
  positionSizing?: {
    accountSize: number;
    riskPerTradePct: number;
    stopDistance: number;
    shares: number;
    capitalRequired: number;
    riskAmount: number;
  } | null;
}

export interface BacktestSummary {
  startDate: string | null;
  endDate: string | null;
  count: number;
  metrics: {
    avgRetT1: number;
    avgRetT3: number;
    avgRetT5: number;
    avgNetRetT1?: number;
    avgNetRetT3?: number;
    avgNetRetT5?: number;
    winRateT1: number;
    winRateT3: number;
    winRateT5: number;
    netWinRateT1?: number;
    netWinRateT3?: number;
    netWinRateT5?: number;
    mddT1: number;
    mddT3: number;
    mddT5: number;
    netMddT1?: number;
    netMddT3?: number;
    netMddT5?: number;
  };
}

export interface BacktestHistoryItem {
  tradeDate: string;
  ticker: string;
  companyName?: string;
  dayOpen?: number | null;
  dayClose?: number | null;
  currentPrice?: number | null;
  currentPriceDate?: string | null;
  entryPrice: number;
  retT1: number | null;
  retT3: number | null;
  retT5: number | null;
  netRetT1?: number | null;
  netRetT3?: number | null;
  netRetT5?: number | null;
}
