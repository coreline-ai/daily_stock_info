import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:dio/dio.dart';

class DashboardLoadResult {
  const DashboardLoadResult({
    required this.strategyStatus,
    required this.selectedStrategy,
    required this.marketOverview,
    required this.candidates,
    required this.validation,
    required this.marketInsight,
    required this.intradayExtra,
  });

  final StrategyStatus strategyStatus;
  final StrategyKind selectedStrategy;
  final MarketOverview marketOverview;
  final List<StockCandidate> candidates;
  final StrategyValidation? validation;
  final MarketInsight? marketInsight;
  final List<StockCandidate> intradayExtra;
}

abstract class DashboardRepository {
  Future<DashboardLoadResult> loadDashboard({
    required String date,
    required StrategyKind preferredStrategy,
    required StrategyWeights weights,
    required bool includeIntradayExtra,
    required bool forceRefresh,
    String userKey = 'default',
    List<String> customTickers = const [],
    String? refreshToken,
    CancelToken? cancelToken,
  });

  Future<StockDetail> loadStockDetail({
    required String ticker,
    required String date,
    required StrategyKind strategy,
    required StrategyWeights weights,
    String userKey = 'default',
    List<String> customTickers = const [],
    CancelToken? cancelToken,
  });
}
