class BacktestSummary {
  const BacktestSummary({
    required this.count,
    required this.avgRetT1,
    required this.avgRetT3,
    required this.avgRetT5,
    required this.winRateT1,
    required this.winRateT3,
    required this.winRateT5,
    required this.mddT1,
    required this.mddT3,
    required this.mddT5,
  });

  final int count;
  final double avgRetT1;
  final double avgRetT3;
  final double avgRetT5;
  final double winRateT1;
  final double winRateT3;
  final double winRateT5;
  final double mddT1;
  final double mddT3;
  final double mddT5;
}

class BacktestItem {
  const BacktestItem({
    required this.tradeDate,
    required this.ticker,
    required this.companyName,
    required this.entryPrice,
    required this.retT1,
    required this.retT3,
    required this.retT5,
    required this.currentPrice,
  });

  final String tradeDate;
  final String ticker;
  final String companyName;
  final double entryPrice;
  final double? retT1;
  final double? retT3;
  final double? retT5;
  final double? currentPrice;
}

class BacktestPage {
  const BacktestPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  final List<BacktestItem> items;
  final int page;
  final int size;
  final int total;
}
