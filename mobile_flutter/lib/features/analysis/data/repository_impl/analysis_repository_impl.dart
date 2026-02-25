import 'package:coreline_stock_ai/core/error/app_exception.dart';
import 'package:coreline_stock_ai/core/network/api_endpoints.dart';
import 'package:coreline_stock_ai/features/analysis/domain/repository/analysis_repository.dart';
import 'package:coreline_stock_ai/features/dashboard/domain/entities/dashboard_models.dart';
import 'package:dio/dio.dart';

class AnalysisRepositoryImpl implements AnalysisRepository {
  AnalysisRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<StrategyValidation> getValidation({
    required StrategyKind strategy,
    required String date,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Object>(
        ApiEndpoints.strategyValidation,
        queryParameters: {
          'strategy': strategy.value,
          'date': date,
          'user_key': 'default',
          'compare_branches': true,
          'compute_if_missing': true,
        },
        cancelToken: cancelToken,
      );
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map
              ? data.map((key, dynamic value) => MapEntry(key.toString(), value))
              : <String, dynamic>{});
      return StrategyValidation.fromJson(map);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
    }
  }
}
