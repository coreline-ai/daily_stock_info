class BacktestSummaryModel {
  const BacktestSummaryModel({
    required this.startDate,
    required this.endDate,
    required this.count,
    required this.metrics,
  });

  final String? startDate;
  final String? endDate;
  final int count;
  final Map<String, double> metrics;

  factory BacktestSummaryModel.fromJson(Map<String, dynamic> json) {
    final metricsRaw = (json['metrics'] as Map<String, dynamic>? ?? const {});
    final metrics = <String, double>{};
    for (final entry in metricsRaw.entries) {
      metrics[entry.key] = (entry.value as num?)?.toDouble() ?? 0;
    }
    return BacktestSummaryModel(
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      metrics: metrics,
    );
  }
}

class BacktestHistoryItemModel {
  const BacktestHistoryItemModel({
    required this.tradeDate,
    required this.ticker,
    required this.companyName,
    required this.entryPrice,
    required this.dayOpen,
    required this.dayClose,
    required this.currentPrice,
    required this.currentPriceDate,
    required this.retT1,
    required this.retT3,
    required this.retT5,
    required this.netRetT1,
    required this.netRetT3,
    required this.netRetT5,
  });

  final String tradeDate;
  final String ticker;
  final String companyName;
  final double entryPrice;
  final double? dayOpen;
  final double? dayClose;
  final double? currentPrice;
  final String? currentPriceDate;
  final double? retT1;
  final double? retT3;
  final double? retT5;
  final double? netRetT1;
  final double? netRetT3;
  final double? netRetT5;

  factory BacktestHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return BacktestHistoryItemModel(
      tradeDate: (json['tradeDate'] ?? '').toString(),
      ticker: (json['ticker'] ?? '').toString(),
      companyName: (json['companyName'] ?? '').toString(),
      entryPrice: (json['entryPrice'] as num?)?.toDouble() ?? 0,
      dayOpen: (json['dayOpen'] as num?)?.toDouble(),
      dayClose: (json['dayClose'] as num?)?.toDouble(),
      currentPrice: (json['currentPrice'] as num?)?.toDouble(),
      currentPriceDate: json['currentPriceDate']?.toString(),
      retT1: (json['retT1'] as num?)?.toDouble(),
      retT3: (json['retT3'] as num?)?.toDouble(),
      retT5: (json['retT5'] as num?)?.toDouble(),
      netRetT1: (json['netRetT1'] as num?)?.toDouble(),
      netRetT3: (json['netRetT3'] as num?)?.toDouble(),
      netRetT5: (json['netRetT5'] as num?)?.toDouble(),
    );
  }
}

class BacktestHistoryPage {
  const BacktestHistoryPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  final List<BacktestHistoryItemModel> items;
  final int page;
  final int size;
  final int total;

  factory BacktestHistoryPage.fromJson(Map<String, dynamic> json) {
    return BacktestHistoryPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => BacktestHistoryItemModel.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      size: (json['size'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
