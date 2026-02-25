class ApiEndpoints {
  const ApiEndpoints._();

  static const String health = '/api/v1/health';
  static const String strategyStatus = '/api/v1/strategy-status';
  static const String marketOverview = '/api/v1/market-overview';
  static const String stockCandidates = '/api/v1/stock-candidates';
  static const String strategyValidation = '/api/v1/strategy-validation';
  static const String marketInsight = '/api/v1/market-insight';

  static String stockDetail(String ticker) => '/api/v1/stocks/$ticker/detail';

  static const String watchlist = '/api/v1/watchlist';
  static String watchlistItem(String ticker) => '/api/v1/watchlist/$ticker';
  static const String watchlistUploadCsv = '/api/v1/watchlist/upload-csv';

  static const String backtestSummary = '/api/v1/backtest/summary';
  static const String backtestHistory = '/api/v1/backtest/history';
}
