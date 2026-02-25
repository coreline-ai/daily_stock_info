import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/repository/dashboard_repository.dart';
import 'package:dio/dio.dart';

class LoadDashboardUsecase {
  const LoadDashboardUsecase(this._repository);

  final DashboardRepository _repository;

  Future<DashboardLoadResult> call({
    required String date,
    required StrategyKind preferredStrategy,
    required StrategyWeights weights,
    required bool includeIntradayExtra,
    required bool forceRefresh,
    String userKey = 'default',
    List<String> customTickers = const [],
    String? refreshToken,
    CancelToken? cancelToken,
  }) {
    return _repository.loadDashboard(
      date: date,
      preferredStrategy: preferredStrategy,
      weights: weights,
      includeIntradayExtra: includeIntradayExtra,
      forceRefresh: forceRefresh,
      userKey: userKey,
      customTickers: customTickers,
      refreshToken: refreshToken,
      cancelToken: cancelToken,
    );
  }
}
