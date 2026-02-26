import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/value_objects/strategy_weights.dart';

class DashboardQuery {
  const DashboardQuery({
    required this.date,
    required this.strategy,
    required this.weights,
    this.customTickers = const [],
    this.includeIntradayExtra = true,
    this.strictRealData = false,
    this.forceRefresh = false,
  });

  final String date;
  final StrategyKind strategy;
  final StrategyWeights weights;
  final List<String> customTickers;
  final bool includeIntradayExtra;
  final bool strictRealData;
  final bool forceRefresh;
}

class ValidationQuery {
  const ValidationQuery({
    required this.strategy,
    required this.asOfDate,
    required this.weights,
    this.customTickers = const [],
  });

  final StrategyKind strategy;
  final String asOfDate;
  final StrategyWeights weights;
  final List<String> customTickers;
}

class BacktestQuery {
  const BacktestQuery({required this.startDate, required this.endDate});

  final String? startDate;
  final String? endDate;
}

class BacktestHistoryQuery {
  const BacktestHistoryQuery({
    required this.startDate,
    required this.endDate,
    required this.page,
    required this.size,
  });

  final String? startDate;
  final String? endDate;
  final int page;
  final int size;
}

class AiReportQuery {
  const AiReportQuery({
    required this.ticker,
    required this.companyName,
    required this.summary,
    required this.newsSummary,
    required this.themes,
  });

  final String ticker;
  final String companyName;
  final String summary;
  final List<String> newsSummary;
  final List<String> themes;
}
