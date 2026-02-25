import 'package:coreline_stock_ai/core/error/app_exception.dart';
import 'package:coreline_stock_ai/core/network/api_endpoints.dart';
import 'package:coreline_stock_ai/features/history/domain/entities/history_models.dart';
import 'package:coreline_stock_ai/features/history/domain/repository/history_repository.dart';
import 'package:dio/dio.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<BacktestSummaryModel> fetchSummary({
    String? startDate,
    String? endDate,
    double feeBps = 10,
    double slippageBps = 5,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Object>(
        ApiEndpoints.backtestSummary,
        queryParameters: {
          if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
          if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
          'fee_bps': feeBps,
          'slippage_bps': slippageBps,
        },
        cancelToken: cancelToken,
      );
      return BacktestSummaryModel.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
    }
  }

  @override
  Future<BacktestHistoryPage> fetchHistory({
    String? startDate,
    String? endDate,
    int page = 1,
    int size = 20,
    double feeBps = 10,
    double slippageBps = 5,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Object>(
        ApiEndpoints.backtestHistory,
        queryParameters: {
          if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
          if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
          'page': page,
          'size': size,
          'fee_bps': feeBps,
          'slippage_bps': slippageBps,
        },
        cancelToken: cancelToken,
      );
      return BacktestHistoryPage.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || error.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw AppException.fromDio(error);
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
}
