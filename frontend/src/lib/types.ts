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
      orbProxyScore: number;
      vwapProxyScore: number;
      rvolScore: number;
      openPrice: number;
      dayHigh: number;
      dayLow: number;
      vwapProxyPrice: number;
      rvolRatio: number;
    };
  };
  realDate?: string;
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
  entryPrice: number;
  retT1: number | null;
  retT3: number | null;
  retT5: number | null;
  netRetT1?: number | null;
  netRetT3?: number | null;
  netRetT5?: number | null;
}
