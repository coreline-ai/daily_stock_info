import 'package:mobile_app_entire/domain/entities/market.dart';
import 'package:mobile_app_entire/domain/entities/strategy.dart';
import 'package:mobile_app_entire/domain/value_objects/strategy_weights.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.strategyStatus,
    required this.selectedStrategy,
    required this.weights,
    required this.overview,
    required this.candidates,
    required this.intradayExtra,
    required this.insight,
    required this.lastUpdated,
    required this.dataMode,
    this.warning,
    this.usedInformation = const [],
    this.dataWarnings = const [],
  });

  final StrategyStatus strategyStatus;
  final StrategyKind selectedStrategy;
  final StrategyWeights weights;
  final MarketOverview overview;
  final List<StockCandidate> candidates;
  final List<StockCandidate> intradayExtra;
  final MarketInsight insight;
  final DateTime lastUpdated;
  final String dataMode;
  final String? warning;
  final List<String> usedInformation;
  final List<String> dataWarnings;
}
