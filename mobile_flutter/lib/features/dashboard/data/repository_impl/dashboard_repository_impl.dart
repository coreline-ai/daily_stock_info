import 'package:coreline_stock_ai/core/error/app_exception.dart';
import 'package:coreline_stock_ai/core/network/api_endpoints.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/repository/dashboard_repository.dart';
import 'package:dio/dio.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
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
  }) async {
    try {
      final statusResp = await _dio.get<Object>(
        ApiEndpoints.strategyStatus,
        queryParameters: {'date': date},
        cancelToken: cancelToken,
      );
      final status = StrategyStatus.fromJson(_asMap(statusResp.data));
      final resolvedStrategy = _resolveStrategy(status: status, preferred: preferredStrategy);
      final base = _queryBase(
        date: date,
        userKey: userKey,
        customTickers: customTickers,
        strategy: resolvedStrategy,
      );

      final overviewFuture = _dio.get<Object>(
        ApiEndpoints.marketOverview,
        queryParameters: {
          ...base,
          'force_refresh': forceRefresh,
        },
        cancelToken: cancelToken,
      );
      final candidatesFuture = _dio.get<Object>(
        ApiEndpoints.stockCandidates,
        queryParameters: {
          ...base,
          'w_return': weights.returnWeight,
          'w_stability': weights.stabilityWeight,
          'w_market': weights.marketWeight,
          'include_sparkline': true,
          'include_validation': true,
          'force_refresh': forceRefresh,
          if (refreshToken != null && refreshToken.isNotEmpty) 'refresh_token': refreshToken,
        },
        cancelToken: cancelToken,
      );
      final validationFuture = _tryGetMap(
        ApiEndpoints.strategyValidation,
        queryParameters: {
          ...base,
          'w_return': weights.returnWeight,
          'w_stability': weights.stabilityWeight,
          'w_market': weights.marketWeight,
          'compute_if_missing': true,
        },
        cancelToken: cancelToken,
      );
      final insightFuture = _tryGetMap(
        ApiEndpoints.marketInsight,
        queryParameters: {
          ...base,
          'w_return': weights.returnWeight,
          'w_stability': weights.stabilityWeight,
          'w_market': weights.marketWeight,
        },
        cancelToken: cancelToken,
      );

      final results = await Future.wait<Object?>([
        overviewFuture,
        candidatesFuture,
        validationFuture,
        insightFuture,
      ]);

      final overviewResp = results[0] as Response<Object>;
      final candidatesResp = results[1] as Response<Object>;
      final validationMap = results[2] as Map<String, dynamic>?;
      final insightMap = results[3] as Map<String, dynamic>?;

      final marketOverview = MarketOverview.fromJson(_asMap(overviewResp.data));
      final candidates = _asList(candidatesResp.data)
          .map((item) => StockCandidate.fromJson(item))
          .toList(growable: false);

      List<StockCandidate> intradayExtra = const [];
      if (includeIntradayExtra && resolvedStrategy != StrategyKind.intraday) {
        final canUseIntraday = status.availableStrategies.contains(StrategyKind.intraday);
        if (canUseIntraday) {
          final intradayResp = await _dio.get<Object>(
            ApiEndpoints.stockCandidates,
            queryParameters: {
              ..._queryBase(
                date: date,
                userKey: userKey,
                customTickers: customTickers,
                strategy: StrategyKind.intraday,
              ),
              'w_return': weights.returnWeight,
              'w_stability': weights.stabilityWeight,
              'w_market': weights.marketWeight,
              'cap_top_n': 5,
              'include_validation': true,
            },
            cancelToken: cancelToken,
          );
          intradayExtra = _asList(intradayResp.data)
              .map((item) => StockCandidate.fromJson(item))
              .toList(growable: false);
        }
      }

      return DashboardLoadResult(
        strategyStatus: status,
        selectedStrategy: resolvedStrategy,
        marketOverview: marketOverview,
        candidates: candidates,
        validation: validationMap == null ? null : StrategyValidation.fromJson(validationMap),
        marketInsight: insightMap == null ? null : MarketInsight.fromJson(insightMap),
        intradayExtra: intradayExtra,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<StockDetail> loadStockDetail({
    required String ticker,
    required String date,
    required StrategyKind strategy,
    required StrategyWeights weights,
    String userKey = 'default',
    List<String> customTickers = const [],
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Object>(
        ApiEndpoints.stockDetail(ticker),
        queryParameters: {
          ..._queryBase(
            date: date,
            userKey: userKey,
            customTickers: customTickers,
            strategy: strategy,
          ),
          'w_return': weights.returnWeight,
          'w_stability': weights.stabilityWeight,
          'w_market': weights.marketWeight,
          'include_news': true,
          'include_ai': true,
        },
        cancelToken: cancelToken,
      );
      return StockDetail.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
    }
  }

  Map<String, dynamic> _queryBase({
    required String date,
    required String userKey,
    required List<String> customTickers,
    required StrategyKind strategy,
  }) {
    return {
      'date': date,
      'user_key': userKey,
      'strategy': strategy.value,
      if (customTickers.isNotEmpty) 'custom_tickers': customTickers.join(','),
    };
  }

  StrategyKind _resolveStrategy({
    required StrategyStatus status,
    required StrategyKind preferred,
  }) {
    if (status.availableStrategies.contains(preferred)) {
      return preferred;
    }
    if (status.defaultStrategy != null) {
      return status.defaultStrategy!;
    }
    if (status.availableStrategies.isNotEmpty) {
      return status.availableStrategies.first;
    }
    return preferred;
  }

  Future<Map<String, dynamic>?> _tryGetMap(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Object>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      return null;
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Object>()
        .map((item) => item is Map<String, dynamic>
            ? item
            : (item is Map
                ? item.map((key, dynamic v) => MapEntry(key.toString(), v))
                : <String, dynamic>{}))
        .toList(growable: false);
  }
}
